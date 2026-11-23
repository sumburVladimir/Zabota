#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Автоматический валидатор SQL для системы «Забота» (сегменты отбора и патчи модификации БД).

Выполняет:
1. Статический аудит по чек-листу docs/zabota/scenarios-audit.md.
2. Динамическую проверку компиляции и выполнения в MSSQL (wellness_new или tmp_clinic_<id>).

Примеры запуска:
    python tools/verify_sql.py --file docs/zabota/clients/imed-city/birthday/01-shorstov-bez-bonusov-18-99.sql --db tmp_clinic_test_inv
    python tools/verify_sql.py --sql "SELECT TOP 3 * FROM vpatients" --db tmp_clinic_test_inv --mode segment
    python tools/verify_sql.py --file patch.sql --db tmp_clinic_2523 --mode patch --json
"""
import argparse
import configparser
import json
import re
import sys
from pathlib import Path

import pyodbc

ROOT = Path(__file__).resolve().parents[1]
CRED_FILE = ROOT / "credentials.local.ini"

CORE_PATCH_TABLES = (
    "deliv_conditions",
    "deliveries",
    "deliv_params",
    "procgroups",
    "procedurex",
)

PRODUCER_DEFAULT_PARAMS = {
    ":IPAT": "10",
    ":IGROUP": "1",
    ":GROUPID": "1",
    ":DID": "1",
    ":IAGE1": "18",
    ":IAGE2": "99",
    ":ITIME1": "0",
    ":ITIME2": "23",
}


def load_mssql_config() -> dict:
    cfg = configparser.RawConfigParser()
    if not CRED_FILE.is_file():
        raise RuntimeError(f"Не найден файл {CRED_FILE}")
    cfg.read(CRED_FILE, encoding="utf-8")
    sec = cfg["mssql"]
    return {
        "server": sec.get("server", r"USERPC\ZABOTASQLSERVER1"),
        "user": sec.get("user", "sa"),
        "password": sec.get("password", ""),
        "driver": sec.get("driver", "ODBC Driver 17 for SQL Server"),
    }


def connect(db: str = "wellness_new", autocommit: bool = False):
    c = load_mssql_config()
    conn_str = (
        f"DRIVER={{{c['driver']}}};"
        f"SERVER={c['server']};"
        f"UID={c['user']};PWD={c['password']};"
        f"DATABASE={db};"
        "TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str, timeout=20, autocommit=autocommit)


def strip_sql_comments_and_strings(sql: str) -> str:
    """Убирает комментарии /* ... */, -- ... и строковые литералы '...' для точного поиска ключевых слов."""
    pattern = re.compile(
        r"(/\*[\s\S]*?\*/|--[^\r\n]*|N?'(?:''|[^'])*')",
        re.IGNORECASE,
    )

    def repl(match: re.Match) -> str:
        s = match.group(0)
        if s.startswith("'") or s.upper().startswith("N'"):
            return "''"
        return " "

    return pattern.sub(repl, sql)


def detect_mode(sql: str) -> str:
    cleaned = strip_sql_comments_and_strings(sql)
    patch_kw = re.compile(
        r"\b(UPDATE|INSERT|DELETE|INTO|BEGIN\s+TRAN(?:SACTION)?)\b",
        re.IGNORECASE,
    )
    if patch_kw.search(cleaned):
        return "patch"
    return "segment"


def replace_producer_params(sql: str) -> tuple[str, dict]:
    """Заменяет параметры Продюсера (:IPAT, :DID, ...) на тестовые значения вне комментариев и строк."""
    replaced = {}
    token_re = re.compile(
        r"(/\*[\s\S]*?\*/|--[^\r\n]*|N?'(?:''|[^'])*')|(:[A-Za-z_][A-Za-z0-9_]*)",
        re.IGNORECASE,
    )

    def repl(m: re.Match) -> str:
        if m.group(1) is not None:
            return m.group(1)
        param = m.group(2)
        upper_p = param.upper()
        val = PRODUCER_DEFAULT_PARAMS.get(upper_p, "1")
        replaced[param] = val
        return val

    # Особый случай: SELECT TOP :IPAT ... без скобок в T-SQL требует SELECT TOP 10 или SELECT TOP (10)
    out = token_re.sub(repl, sql)
    return out, replaced


def static_audit_segment(sql: str) -> list[dict]:
    checks = []
    cleaned = strip_sql_comments_and_strings(sql)

    # 1. Проверка жесткого SELECT TOP N вместо TOP :IPAT / TOP (:IPAT)
    hard_top = re.search(r"\bSELECT\s+(?:DISTINCT\s+)?TOP\s*\(?\s*(\d+)\s*\)?", cleaned, re.IGNORECASE)
    if hard_top:
        num = hard_top.group(1)
        checks.append({
            "level": "ERROR",
            "code": "SEGMENT_HARDCODED_TOP",
            "message": f"Обнаружен жёсткий лимит `SELECT TOP {num}` вместо параметра `TOP (:IPAT)` / `top :IPAT`.",
        })
    elif re.search(r"\bTOP\s*\(?\s*:IPAT\s*\)?", cleaned, re.IGNORECASE):
        checks.append({
            "level": "OK",
            "code": "SEGMENT_TOP_IPAT",
            "message": "Используется параметризованный лимит `TOP :IPAT`.",
        })
    else:
        checks.append({
            "level": "OK",
            "code": "SEGMENT_NO_HARD_TOP",
            "message": "Жёсткого `SELECT TOP <число>` не обнаружено.",
        })

    # 2. Если используется procedurex, проверить фильтр exclude = 0
    if re.search(r"\bprocedurex\b", cleaned, re.IGNORECASE):
        if re.search(r"\bexclude\b\s*,\s*0\s*\)\s*=\s*0|\bexclude\b\s*=\s*0", cleaned, re.IGNORECASE):
            checks.append({
                "level": "OK",
                "code": "SEGMENT_PROCEDUREX_EXCLUDE",
                "message": "При обращении к `procedurex` присутствует фильтр `ISNULL(exclude, 0) = 0`.",
            })
        else:
            checks.append({
                "level": "WARN",
                "code": "SEGMENT_PROCEDUREX_NO_EXCLUDE",
                "message": "Используется `procedurex`, но нет фильтра `ISNULL(p.exclude, 0) = 0` (отключённые в группе услуги продолжат срабатывать).",
            })

    # 3. Проверка повторов по deliv_orders (Delivery_id) без ограничения по дате
    has_deliv_orders_did = (
        re.search(r"\bdeliv_orders\b", cleaned, re.IGNORECASE)
        and re.search(r"\bDelivery_id\b", cleaned, re.IGNORECASE)
    )
    if has_deliv_orders_did:
        has_date_limit = re.search(
            r"\b(DATEDIFF|DATEADD|Created|Delivery_dt|Send_dt)\b",
            cleaned,
            re.IGNORECASE,
        )
        # Если в самом подзапросе с deliv_orders нет даты, проверим локально вокруг deliv_orders
        # Ищем каждый блок с deliv_orders
        subqueries_without_date = False
        for m in re.finditer(r"SELECT\b[^;]*?\bdeliv_orders\b[\s\S]*?(?=\)\s*(?:AND|OR|WHERE|$)|\Z)", cleaned, re.IGNORECASE):
            block = m.group(0)
            if re.search(r"\bDelivery_id\b", block, re.IGNORECASE):
                if not re.search(r"\b(DATEDIFF|DATEADD|Created|Delivery_dt|Send_dt)\b", block, re.IGNORECASE):
                    subqueries_without_date = True
                    break

        if not has_date_limit or subqueries_without_date:
            checks.append({
                "level": "ERROR",
                "code": "SEGMENT_REPEAT_FOREVER",
                "message": "Проверка `deliv_orders` (`Delivery_id`) без ограничения по дате (`DATEDIFF` / `Created` / `Delivery_dt`) — баг «повтор навсегда».",
            })
        else:
            checks.append({
                "level": "OK",
                "code": "SEGMENT_REPEAT_DATE_OK",
                "message": "Проверка `deliv_orders` (`Delivery_id`) содержит ограничение по дате.",
            })

    # 4. Проверка обращения к таблице patients (не vpatients) без Deleted IS NULL
    uses_vpatients = bool(re.search(r"\b(?:FROM|JOIN)\s+(?:\[?dbo\]?\.)?\[?vpatients\]?\b", cleaned, re.IGNORECASE))
    uses_patients_table = bool(re.search(r"\b(?:FROM|JOIN)\s+(?:\[?dbo\]?\.)?\[?patients\]?\b", cleaned, re.IGNORECASE))
    if uses_patients_table and not uses_vpatients:
        if re.search(r"\bDeleted\s+IS\s+NULL\b|\bISNULL\s*\(\s*(?:\w+\.)?Deleted\s*,\s*0\s*\)\s*=\s*0", cleaned, re.IGNORECASE):
            checks.append({
                "level": "OK",
                "code": "SEGMENT_PATIENTS_DELETED_FILTER",
                "message": "Используется таблица `patients` с фильтром `Deleted IS NULL`.",
            })
        else:
            checks.append({
                "level": "WARN",
                "code": "SEGMENT_PATIENTS_NO_DELETED_FILTER",
                "message": "Запрос обращается напрямую к таблице `patients` (а не к вьюхе `vpatients`), но не содержит фильтра `patients.Deleted IS NULL`.",
            })
    elif uses_vpatients:
        checks.append({
            "level": "OK",
            "code": "SEGMENT_USES_VPATIENTS",
            "message": "Используется вьюха `vpatients` (удалённые пациенты отфильтрованы).",
        })

    return checks


def split_batches(sql: str) -> list[str]:
    batches = re.split(r"^\s*GO\s*$", sql, flags=re.IGNORECASE | re.MULTILINE)
    return [b for b in batches if strip_sql_comments_and_strings(b).strip()]


def static_audit_patch(sql: str) -> list[dict]:
    checks = []
    cleaned = strip_sql_comments_and_strings(sql)

    # 1. UPDATE / DELETE основных таблиц -> обязателен бэкап SELECT * INTO ..._bak_
    modified_core = set()
    for tbl in CORE_PATCH_TABLES:
        pat_upd = rf"\bUPDATE\s+(?:\w+\s+FROM\s+)?(?:\[?dbo\]?\.)?\[?{tbl}\]?\b"
        pat_upd_join = rf"\bUPDATE\b[\s\S]*?\bFROM\s+(?:\[?dbo\]?\.)?\[?{tbl}\]?\b"
        pat_del = rf"\bDELETE\s+(?:FROM\s+)?(?:\w+\s+FROM\s+)?(?:\[?dbo\]?\.)?\[?{tbl}\]?\b"
        if re.search(pat_upd, cleaned, re.IGNORECASE) or re.search(pat_upd_join, cleaned, re.IGNORECASE) or re.search(pat_del, cleaned, re.IGNORECASE):
            modified_core.add(tbl)

    has_bak = bool(re.search(r"\bINTO\s+(?:\[?dbo\]?\.)?\[?\w+_bak_\w*\]?", cleaned, re.IGNORECASE))
    if modified_core:
        if has_bak:
            checks.append({
                "level": "OK",
                "code": "PATCH_BACKUP_PRESENT",
                "message": f"Модификация таблиц ({', '.join(sorted(modified_core))}) сопровождается созданием бэкапа `INTO ..._bak_`.",
            })
        else:
            checks.append({
                "level": "ERROR",
                "code": "PATCH_MISSING_BACKUP",
                "message": f"Обнаружен UPDATE/DELETE таблиц ({', '.join(sorted(modified_core))}), но нет создания бэкапа (`SELECT * INTO ..._bak_YYYYMMDD`)!",
            })

    # 2. UPDATE / INSERT / DELETE -> транзакция + @@ROWCOUNT
    has_dml = bool(re.search(r"\b(UPDATE|INSERT|DELETE)\b", cleaned, re.IGNORECASE))
    if has_dml:
        has_begin_tran = bool(re.search(r"\bBEGIN\s+TRAN(?:SACTION)?\b", cleaned, re.IGNORECASE))
        has_commit_rollback = bool(re.search(r"\b(COMMIT|ROLLBACK)\b", cleaned, re.IGNORECASE))
        has_rowcount = bool(re.search(r"@@ROWCOUNT\b", cleaned, re.IGNORECASE))

        if has_begin_tran and has_commit_rollback and has_rowcount:
            checks.append({
                "level": "OK",
                "code": "PATCH_TRAN_AND_ROWCOUNT",
                "message": "Изменения обёрнуты в транзакцию (`BEGIN TRAN` / `COMMIT` / `ROLLBACK`) с проверкой `@@ROWCOUNT`.",
            })
        else:
            missing = []
            if not has_begin_tran:
                missing.append("BEGIN TRAN")
            if not has_commit_rollback:
                missing.append("COMMIT/ROLLBACK")
            if not has_rowcount:
                missing.append("@@ROWCOUNT")
            checks.append({
                "level": "ERROR",
                "code": "PATCH_MISSING_TRAN_OR_ROWCOUNT",
                "message": f"В скрипте модификации отсутствуют обязательные элементы безопасности: {', '.join(missing)}.",
            })

    # 3. Если есть GO и используются @переменные, проверить DECLARE в каждом батче
    raw_batches = re.split(r"^\s*GO\s*$", sql, flags=re.IGNORECASE | re.MULTILINE)
    if len(raw_batches) > 1:
        undeclared_per_batch = []
        for idx, batch in enumerate(raw_batches, start=1):
            b_clean = strip_sql_comments_and_strings(batch)
            if not b_clean.strip():
                continue
            # Находим все @var (кроме системных @@...)
            all_vars = {m.group(1).lower() for m in re.finditer(r"(?<!@)(@[A-Za-z_][A-Za-z0-9_]*)", b_clean)}
            if not all_vars:
                continue
            declared_vars = set()
            for decl_m in re.finditer(r"\bDECLARE\b([\s\S]*?)(?=\b(?:SELECT|SET|INSERT|UPDATE|DELETE|IF|WHILE|BEGIN|EXEC|PRINT|WITH|DROP|CREATE|ALTER)\b|;|\Z)", b_clean, re.IGNORECASE):
                decl_body = decl_m.group(1)
                for vm in re.finditer(r"(?<!@)(@[A-Za-z_][A-Za-z0-9_]*)", decl_body):
                    declared_vars.add(vm.group(1).lower())
            missing_vars = sorted(all_vars - declared_vars)
            if missing_vars:
                undeclared_per_batch.append(f"батч #{idx}: {', '.join(missing_vars)}")

        if undeclared_per_batch:
            checks.append({
                "level": "WARN",
                "code": "PATCH_GO_UNDECLARED_VARS",
                "message": f"`GO` сбрасывает область видимости переменных. Не объявлены через `DECLARE` в батчах: {'; '.join(undeclared_per_batch)}.",
            })
        else:
            checks.append({
                "level": "OK",
                "code": "PATCH_GO_VARS_OK",
                "message": "Во всех батчах между `GO` переменные объявлены корректно.",
            })

    return checks


def ensure_sandbox_views(cn, db_name: str, checks: list[dict]) -> None:
    """Если БД начинается с tmp_ и нет dbo.vpatients / dbo.vmessages — создаёт (или дополняет) вьюхи-заглушки."""
    if not db_name.lower().startswith("tmp_"):
        return
    cur = cn.cursor()
    cur.execute("""
        SELECT
            CASE WHEN OBJECT_ID(N'dbo.vpatients', N'V') IS NOT NULL THEN 1 ELSE 0 END AS has_vpatients_view,
            CASE WHEN OBJECT_ID(N'dbo.vpatients') IS NOT NULL THEN 1 ELSE 0 END AS has_vpatients_any,
            CASE WHEN OBJECT_ID(N'dbo.patients', N'U') IS NOT NULL THEN 1 ELSE 0 END AS has_patients,
            CASE WHEN COL_LENGTH(N'dbo.vpatients', N'hide') IS NOT NULL THEN 1 ELSE 0 END AS vpatients_has_hide,
            CASE WHEN COL_LENGTH(N'dbo.patients', N'hide') IS NOT NULL THEN 1 ELSE 0 END AS patients_has_hide,
            CASE WHEN COL_LENGTH(N'dbo.patients', N'Exclude') IS NOT NULL THEN 1 ELSE 0 END AS patients_has_exclude,
            CASE WHEN OBJECT_ID(N'dbo.vmessages', N'V') IS NOT NULL THEN 1 ELSE 0 END AS has_vmessages_view,
            CASE WHEN OBJECT_ID(N'dbo.vmessages') IS NOT NULL THEN 1 ELSE 0 END AS has_vmessages_any,
            CASE WHEN OBJECT_ID(N'dbo.messages', N'U') IS NOT NULL AND OBJECT_ID(N'dbo.deliv_orders', N'U') IS NOT NULL THEN 1 ELSE 0 END AS has_msg_tables,
            CASE WHEN COL_LENGTH(N'dbo.vmessages', N'created') IS NOT NULL THEN 1 ELSE 0 END AS vmessages_has_created,
            CASE WHEN COL_LENGTH(N'dbo.messages', N'created') IS NOT NULL THEN 1 ELSE 0 END AS messages_has_created
    """)
    row = cur.fetchone()
    if not row:
        return

    (
        has_vp_view, has_vp_any, has_patients, vp_has_hide, p_has_hide, p_has_excl,
        has_vm_view, has_vm_any, has_msg_tables, vm_has_created, m_has_created
    ) = row

    if has_patients and (not has_vp_any or (has_vp_view and not vp_has_hide)):
        if has_vp_view:
            cur.execute("DROP VIEW dbo.vpatients;")
        extra_p = ", [Exclude] AS [hide]" if not p_has_hide and p_has_excl else ""
        cur.execute(f"CREATE VIEW dbo.vpatients AS SELECT *{extra_p} FROM dbo.patients WHERE Deleted IS NULL;")
        cn.commit()
        checks.append({
            "level": "OK",
            "code": "SANDBOX_VIEW_VPATIENTS_CREATED",
            "message": f"В песочнице `{db_name}` автоматически создана вьюха `dbo.vpatients`.",
        })

    if has_msg_tables and (not has_vm_any or (has_vm_view and not vm_has_created)):
        if has_vm_view:
            cur.execute("DROP VIEW dbo.vmessages;")
        extra_m = [
            "do.[Delivery_id] AS [delivery_id]",
            "do.[Delivery_dt] AS [delivery_dt]",
            "do.[Created] AS [ocreated]",
            "do.[Order_state] AS [order_state]",
        ]
        if not m_has_created:
            extra_m.append("do.[Created] AS [created]")
        cur.execute(f"""
            CREATE VIEW dbo.vmessages AS
            SELECT m.*, {', '.join(extra_m)}
            FROM dbo.messages m
            LEFT JOIN dbo.deliv_orders do ON do.Order_id = m.Order_id;
        """)
        cn.commit()
        checks.append({
            "level": "OK",
            "code": "SANDBOX_VIEW_VMESSAGES_CREATED",
            "message": f"В песочнице `{db_name}` автоматически создана вьюха `dbo.vmessages`.",
        })


def dynamic_verify_segment(sql: str, db_name: str, checks: list[dict]) -> dict:
    exec_info = {
        "database": db_name,
        "substituted_params": {},
        "row_count": None,
        "columns": [],
        "error": None,
    }
    exec_sql, replaced = replace_producer_params(sql)
    exec_info["substituted_params"] = replaced

    try:
        cn = connect(db_name, autocommit=False)
    except Exception as e:
        err_msg = f"Не удалось подключиться к БД `{db_name}`: {e}"
        exec_info["error"] = err_msg
        checks.append({
            "level": "ERROR",
            "code": "MSSQL_CONNECT_ERROR",
            "message": err_msg,
        })
        return exec_info

    try:
        ensure_sandbox_views(cn, db_name, checks)
        cur = cn.cursor()
        try:
            cur.execute(exec_sql)
            cols = [col[0] for col in cur.description] if cur.description else []
            rows = cur.fetchall() if cur.description else []
            exec_info["columns"] = cols
            exec_info["row_count"] = len(rows)
            checks.append({
                "level": "OK",
                "code": "MSSQL_SEGMENT_EXEC_OK",
                "message": f"Запрос успешно выполнен на `{db_name}` (возвращено строк: {len(rows)}, колонок: {len(cols)}).",
            })
        except Exception as e:
            err_msg = str(e)
            exec_info["error"] = err_msg
            checks.append({
                "level": "ERROR",
                "code": "MSSQL_SEGMENT_EXEC_ERROR",
                "message": f"Ошибка выполнения запроса в MSSQL (`{db_name}`): {err_msg}",
            })
        finally:
            try:
                cn.rollback()
            except Exception:
                pass
    finally:
        cn.close()

    return exec_info


def dynamic_verify_patch(sql: str, db_name: str, checks: list[dict]) -> dict:
    batches = split_batches(sql)
    exec_info = {
        "database": db_name,
        "batch_count": len(batches),
        "parseonly_passed": False,
        "executed_in_sandbox": False,
        "error": None,
    }

    try:
        cn = connect(db_name, autocommit=False)
    except Exception as e:
        err_msg = f"Не удалось подключиться к БД `{db_name}`: {e}"
        exec_info["error"] = err_msg
        checks.append({
            "level": "ERROR",
            "code": "MSSQL_CONNECT_ERROR",
            "message": err_msg,
        })
        return exec_info

    try:
        ensure_sandbox_views(cn, db_name, checks)
        cur = cn.cursor()

        # 1. Проверка каждого батча через SET PARSEONLY ON
        parse_ok = True
        for idx, b in enumerate(batches, start=1):
            try:
                cur.execute("SET PARSEONLY ON;")
                cur.execute(b)
                cur.execute("SET PARSEONLY OFF;")
            except Exception as e:
                try:
                    cur.execute("SET PARSEONLY OFF;")
                except Exception:
                    pass
                parse_ok = False
                err_msg = f"Ошибка синтаксиса (PARSEONLY) в батче #{idx}: {e}"
                exec_info["error"] = err_msg
                checks.append({
                    "level": "ERROR",
                    "code": "MSSQL_PATCH_PARSE_ERROR",
                    "message": err_msg,
                })
                break

        if parse_ok:
            exec_info["parseonly_passed"] = True
            checks.append({
                "level": "OK",
                "code": "MSSQL_PATCH_PARSE_OK",
                "message": f"Все батчи ({len(batches)} шт.) успешно прошли `SET PARSEONLY ON`.",
            })

        # 2. Если это песочница tmp_ — реальный прогон батчей с откатом
        if parse_ok and db_name.lower().startswith("tmp_"):
            try:
                # Запоминаем существующие таблицы до запуска патча, чтобы удалить созданные _bak_ таблицы
                cur.execute("SELECT name FROM sys.tables;")
                tables_before = {r[0] for r in cur.fetchall()}

                cur.execute("BEGIN TRAN __verify_sql_outer;")
                for idx, b in enumerate(batches, start=1):
                    cur.execute(b)
                    while cur.nextset():
                        pass

                cur.execute("""
                    IF @@TRANCOUNT > 0
                        ROLLBACK TRAN;
                """)
                cn.rollback()

                # Если внутри батча был свой COMMIT и создалась таблица _bak_, подчистим её
                cur.execute("SELECT name FROM sys.tables;")
                tables_after = {r[0] for r in cur.fetchall()}
                for new_tbl in sorted(tables_after - tables_before):
                    if "_bak_" in new_tbl.lower():
                        cur.execute(f"DROP TABLE [dbo].[{new_tbl}];")
                cn.commit()

                exec_info["executed_in_sandbox"] = True
                checks.append({
                    "level": "OK",
                    "code": "MSSQL_PATCH_SANDBOX_EXEC_OK",
                    "message": f"Патч успешно выполнен в песочнице `{db_name}` и откачен без ошибок.",
                })
            except Exception as e:
                try:
                    cur.execute("IF @@TRANCOUNT > 0 ROLLBACK TRAN;")
                    cn.rollback()
                except Exception:
                    pass
                err_msg = f"Ошибка реального выполнения патча на `{db_name}`: {e}"
                exec_info["error"] = err_msg
                checks.append({
                    "level": "ERROR",
                    "code": "MSSQL_PATCH_EXEC_ERROR",
                    "message": err_msg,
                })
    finally:
        cn.close()

    return exec_info


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    p = argparse.ArgumentParser(description="Валидация SQL-сегментов и патчей для системы «Забота»")
    src = p.add_mutually_exclusive_group(required=True)
    src.add_argument("--file", help="Путь к .sql файлу")
    src.add_argument("--sql", help="Текст SQL-запроса")
    p.add_argument("--db", default="wellness_new", help="Имя базы данных MSSQL (по умолчанию wellness_new или tmp_clinic_<id>)")
    p.add_argument("--mode", choices=["auto", "segment", "patch"], default="auto", help="Режим проверки: auto, segment, patch")
    p.add_argument("--json", action="store_true", help="Вывести отчёт в формате JSON")
    args = p.parse_args()

    if args.file:
        fpath = Path(args.file)
        if not fpath.is_file():
            print(f"ОШИБКА: Файл не найден: {fpath}", file=sys.stderr)
            return 1
        sql_text = fpath.read_text(encoding="utf-8-sig", errors="replace")
        source_label = str(fpath)
    else:
        sql_text = args.sql
        source_label = "<inline --sql>"

    mode = detect_mode(sql_text) if args.mode == "auto" else args.mode

    if mode == "segment":
        checks = static_audit_segment(sql_text)
        exec_info = dynamic_verify_segment(sql_text, args.db, checks)
    else:
        checks = static_audit_patch(sql_text)
        exec_info = dynamic_verify_patch(sql_text, args.db, checks)

    has_error = any(c["level"] == "ERROR" for c in checks) or bool(exec_info.get("error"))
    status = "FAILED" if has_error else "PASSED"

    report = {
        "status": status,
        "mode": mode,
        "source": source_label,
        "database": args.db,
        "checks": checks,
        "execution": exec_info,
    }

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(f"STATUS: {status}")
        print(f"MODE:   {mode}")
        print(f"SOURCE: {source_label}")
        print(f"DB:     {args.db}")
        if mode == "segment" and exec_info.get("substituted_params"):
            params_str = ", ".join(f"{k}={v}" for k, v in exec_info["substituted_params"].items())
            print(f"PARAMS: {params_str}")
        if mode == "segment" and exec_info.get("row_count") is not None:
            cols_preview = ", ".join(exec_info["columns"][:8])
            if len(exec_info["columns"]) > 8:
                cols_preview += f", ... (+{len(exec_info['columns']) - 8})"
            print(f"RESULT: rows={exec_info['row_count']}, columns=[{cols_preview}]")
        print("-" * 60)
        for c in checks:
            print(f"[{c['level']}] ({c['code']}) {c['message']}")

    return 1 if has_error else 0


if __name__ == "__main__":
    raise SystemExit(main())
