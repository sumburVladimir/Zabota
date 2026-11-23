#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Распаковщик единого среза базы клиники (00_snapshot_for_agent.sql) в локальную песочницу MSSQL.

Что делает:
1. Читает текст среза из файла (--file) или прямо из буфера обмена Windows (--from-clipboard).
2. Создаёт на локальном MSSQL (USERPC\\ZABOTASQLSERVER1) временную БД tmp_clinic_<id>.
3. По блоку SCHEMA| воссоздаёт ВСЕ таблицы и колонки клиники (включая её кастомные поля!).
4. Заливает туда сценарии (deliveries), сегменты (deliv_conditions), параметры (deliv_params),
   группы (procgroups, procedurex), врачей (doctors) и справочник услуг (procedures).
5. Также сохраняет JSON-карту среза в scratch/snapshot_<id>.json для быстрой работы скриптов.

Примеры запуска:
    python tools/snapshot_to_sandbox.py --from-clipboard --clinic-id 2523
    python tools/snapshot_to_sandbox.py --file scratch/snapshot.txt --clinic-id test
"""
import argparse
import configparser
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

import pyodbc

ROOT = Path(__file__).resolve().parents[1]
CRED_FILE = ROOT / "credentials.local.ini"


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


def connect(db: str = "master", autocommit: bool = False):
    c = load_mssql_config()
    conn_str = (
        f"DRIVER={{{c['driver']}}};"
        f"SERVER={c['server']};"
        f"UID={c['user']};PWD={c['password']};"
        f"DATABASE={db};"
        "TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str, timeout=20, autocommit=autocommit)


def read_clipboard() -> str:
    res = subprocess.run(
        ["powershell", "-NoProfile", "-Command", "[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; Get-Clipboard -Raw"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    )
    return res.stdout


def parse_snapshot(text: str) -> dict:
    data = {
        "meta": "",
        "schema": defaultdict(list),
        "deliveries": [],
        "deliv_params": [],
        "deliv_conditions": [],
        "procgroups": [],
        "procedurex": [],
        "doctors": [],
        "procedures": [],
        "rows": defaultdict(list),
    }

    for raw_line in text.splitlines():
        line = raw_line.strip().lstrip("\ufeff")
        if len(line) >= 2 and line.startswith('"') and line.endswith('"'):
            line = line[1:-1].replace('""', '"')
        if not line:
            continue
        if line.startswith("=== [META]"):
            data["meta"] = line
        elif line.startswith("SCHEMA|"):
            parts = line.split("|")
            if len(parts) >= 9:
                _, tbl, col, typ, max_len, prec, scale, is_null, is_comp = parts[:9]
                data["schema"][tbl].append({
                    "name": col,
                    "type": typ.lower(),
                    "max_length": int(max_len),
                    "precision": int(prec),
                    "scale": int(scale),
                    "is_nullable": is_null == "1",
                    "is_computed": is_comp == "1",
                })
        elif line.startswith("DELIV|"):
            parts = line.split("|", 8)
            if len(parts) == 9:
                data["deliveries"].append({
                    "delivery_id": int(parts[1]),
                    "code": parts[2],
                    "dactive": int(parts[3] or 0),
                    "deleted": int(parts[4] or 0),
                    "delivery_type": int(parts[5] or 0),
                    "Uni_key": parts[6] or None,
                    "Parent_id": int(parts[7]) if parts[7] else None,
                    "dname": parts[8],
                })
        elif line.startswith("PARAM|"):
            parts = line.split("|", 6)
            if len(parts) == 7:
                data["deliv_params"].append({
                    "Id": int(parts[1]),
                    "delivery_id": int(parts[2]) if parts[2] else None,
                    "Uni_key": parts[3] or None,
                    "Name": parts[4],
                    "Value": parts[5],
                    "Value2": parts[6],
                })
        elif line.startswith("COND|"):
            parts = line.split("|", 6)
            if len(parts) == 7:
                expr = parts[6].replace(" {{NL}} ", "\n").replace("{{PIPE}}", "|")
                data["deliv_conditions"].append({
                    "Id": int(parts[1]),
                    "Uni_key": parts[2] or None,
                    "Condition_Type": int(parts[3] or 1),
                    "has_saved_code": parts[4] == "1",
                    "Name": parts[5],
                    "Expression": expr,
                })
        elif line.startswith("GRP|"):
            parts = line.split("|", 4)
            if len(parts) == 5:
                data["procgroups"].append({
                    "id": int(parts[1]),
                    "code": parts[2],
                    "name": parts[3],
                    "descr": parts[4],
                })
        elif line.startswith("GRP_PROC|"):
            parts = line.split("|", 5)
            if len(parts) == 6:
                data["procedurex"].append({
                    "id": int(parts[1]),
                    "group_id": int(parts[2] or 0),
                    "proc_id": int(parts[3] or 0),
                    "exclude": int(parts[4] or 0),
                    "code": parts[5],
                })
        elif line.startswith("DOC|"):
            parts = line.split("|", 2)
            if len(parts) == 3:
                data["doctors"].append({
                    "Doctor_ID": int(parts[1]),
                    "FullName": parts[2],
                })
        elif line.startswith("PROC|"):
            parts = line.split("|", 2)
            if len(parts) == 3:
                data["procedures"].append({
                    "Procedure_id": int(parts[1]),
                    "Descr": parts[2],
                })
        elif line.startswith("ROW|"):
            parts = line.split("|", 2)
            if len(parts) == 3:
                _, tbl, raw_json = parts
                row_obj = None
                try:
                    row_obj = json.loads(raw_json)
                except json.JSONDecodeError:
                    try:
                        row_obj = json.loads(raw_json.replace('""', '"'))
                    except json.JSONDecodeError:
                        pass
                if isinstance(row_obj, dict):
                    data["rows"][tbl].append(row_obj)

    return data


def format_sql_type(col: dict) -> str:
    t = col["type"]
    ml = col["max_length"]
    prec = col["precision"]
    scale = col["scale"]

    # В песочнице все колонки делаем NULL, чтобы можно было вставлять частичные данные без ошибок
    if t in ("timestamp", "rowversion", "varbinary", "binary", "image"):
        return "[nvarchar](MAX) NULL"
    if t in ("varchar", "char"):
        size = "MAX" if ml == -1 or ml > 8000 else str(max(ml, 1))
        return f"[{t}]({size}) NULL"
    if t in ("nvarchar", "nchar"):
        size = "MAX" if ml == -1 or ml > 8000 else str(max(ml // 2, 1))
        return f"[{t}]({size}) NULL"
    if t in ("decimal", "numeric"):
        return f"[{t}]({prec or 18}, {scale or 0}) NULL"
    if t in (
        "int", "bigint", "smallint", "tinyint", "bit", "float", "real",
        "money", "smallmoney", "datetime", "smalldatetime", "date", "time",
        "datetime2", "datetimeoffset", "uniqueidentifier", "text", "ntext",
        "xml", "sql_variant"
    ):
        return f"[{t}] NULL"
    # Для редких/пользовательских типов безопасный фоллбэк:
    return "[nvarchar](MAX) NULL"


def build_sandbox_db(db_name: str, parsed: dict) -> None:
    if not re.match(r"^tmp_[A-Za-z0-9_]+$", db_name):
        raise ValueError(f"Имя песочницы должно начинаться с tmp_: {db_name}")

    cn_master = connect("master", autocommit=True)
    try:
        cur = cn_master.cursor()
        cur.execute(f"""
            IF DB_ID(N'{db_name}') IS NOT NULL
            BEGIN
                ALTER DATABASE [{db_name}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
                DROP DATABASE [{db_name}];
            END
            CREATE DATABASE [{db_name}];
        """)
    finally:
        cn_master.close()

    cn = connect(db_name, autocommit=False)
    try:
        cur = cn.cursor()

        # 1. Создаём все таблицы по схеме клиники
        for tbl, cols in parsed["schema"].items():
            col_defs = []
            seen = set()
            for c in cols:
                cname = c["name"]
                if cname.lower() in seen:
                    continue
                seen.add(cname.lower())
                col_defs.append(f"[{cname}] {format_sql_type(c)}")
            if col_defs:
                ddl = f"CREATE TABLE [dbo].[{tbl}] (\n  " + ",\n  ".join(col_defs) + "\n);"
                cur.execute(ddl)
        cn.commit()

        # 1.1. Создаём стандартные вьюхи Заботы (vpatients, vmessages), если их нет как таблиц
        schema_tables_lower = {t.lower() for t in parsed["schema"].keys()}
        if "patients" in schema_tables_lower and "vpatients" not in schema_tables_lower:
            p_cols_lower = {c["name"].lower() for c in parsed["schema"].get("patients", [])}
            extra_p = ", [Exclude] AS [hide]" if "hide" not in p_cols_lower and "exclude" in p_cols_lower else ""
            cur.execute(f"CREATE VIEW [dbo].[vpatients] AS SELECT *{extra_p} FROM [dbo].[patients] WHERE [Deleted] IS NULL;")
            cn.commit()
        if "messages" in schema_tables_lower and "deliv_orders" in schema_tables_lower and "vmessages" not in schema_tables_lower:
            m_cols_lower = {c["name"].lower() for c in parsed["schema"].get("messages", [])}
            extra_m = [
                "do.[Delivery_id] AS [delivery_id]",
                "do.[Delivery_dt] AS [delivery_dt]",
                "do.[Created] AS [ocreated]",
                "do.[Order_state] AS [order_state]",
            ]
            if "created" not in m_cols_lower:
                extra_m.append("do.[Created] AS [created]")
            cur.execute(f"""
                CREATE VIEW [dbo].[vmessages] AS
                SELECT m.*, {', '.join(extra_m)}
                FROM [dbo].[messages] m
                LEFT JOIN [dbo].[deliv_orders] do ON do.[Order_id] = m.[Order_id];
            """)
            cn.commit()

        # 2. Заполняем таблицы данными из среза
        schema_lower = {
            t.lower(): {c["name"].lower(): c["name"] for c in cols}
            for t, cols in parsed["schema"].items()
        }

        def insert_rows(table_key: str, rows: list, mapping: list[tuple[str, str]], fast: bool = False):
            if not rows or table_key not in schema_lower:
                return
            t_cols = schema_lower[table_key]
            active_Pairs = [(dict_k, t_cols[sql_c.lower()]) for dict_k, sql_c in mapping if sql_c.lower() in t_cols]
            if not active_Pairs:
                return
            col_names = ", ".join(f"[{sql_c}]" for _, sql_c in active_Pairs)
            placeholders = ", ".join("?" for _ in active_Pairs)
            sql = f"INSERT INTO [dbo].[{table_key}] ({col_names}) VALUES ({placeholders})"
            values = [tuple(r.get(dict_k) for dict_k, _ in active_Pairs) for r in rows]
            cur.fast_executemany = fast
            for i in range(0, len(values), 1000):
                cur.executemany(sql, values[i:i + 1000])
            cur.fast_executemany = False
            cn.commit()

        insert_rows("deliveries", parsed["deliveries"], [
            ("delivery_id", "delivery_id"),
            ("code", "code"),
            ("dactive", "dactive"),
            ("deleted", "deleted"),
            ("delivery_type", "delivery_type"),
            ("Uni_key", "Uni_key"),
            ("Parent_id", "Parent_id"),
            ("dname", "dname"),
        ])

        insert_rows("deliv_params", parsed["deliv_params"], [
            ("Id", "Id"),
            ("delivery_id", "delivery_id"),
            ("Uni_key", "Uni_key"),
            ("Name", "Name"),
            ("Value", "Value"),
            ("Value2", "Value2"),
        ])

        # В deliv_conditions добавим saved_code = '{...}' если has_saved_code = True
        for c in parsed["deliv_conditions"]:
            c["saved_code_val"] = '{"stub":1}' if c.get("has_saved_code") else None
        insert_rows("deliv_conditions", parsed["deliv_conditions"], [
            ("Id", "Id"),
            ("Uni_key", "Uni_key"),
            ("Condition_Type", "Condition_Type"),
            ("saved_code_val", "saved_code"),
            ("Name", "Name"),
            ("Expression", "Expression"),
        ])

        insert_rows("procgroups", parsed["procgroups"], [
            ("id", "id"),
            ("code", "code"),
            ("name", "name"),
            ("descr", "descr"),
        ])

        insert_rows("procedurex", parsed["procedurex"], [
            ("id", "id"),
            ("group_id", "group_id"),
            ("proc_id", "proc_id"),
            ("exclude", "exclude"),
            ("code", "code"),
        ])

        insert_rows("doctors", parsed["doctors"], [
            ("Doctor_ID", "Doctor_ID"),
            ("FullName", "FullName"),
        ])

        insert_rows("procedures", parsed["procedures"], [
            ("Procedure_id", "Procedure_id"),
            ("Descr", "Descr"),
        ], fast=True)

        # 3. Заполняем строки расследования (ROW|<table>|<json>)
        for tbl, rows in parsed["rows"].items():
            t_key = tbl.lower()
            if not rows or t_key not in schema_lower:
                continue
            t_cols = schema_lower[t_key]
            all_keys = []
            seen_keys = set()
            for r in rows:
                for k in r.keys():
                    if k.lower() in t_cols and k not in seen_keys:
                        seen_keys.add(k)
                        all_keys.append((k, t_cols[k.lower()]))
            if all_keys:
                insert_rows(t_key, rows, all_keys)
    finally:
        cn.close()


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    p = argparse.ArgumentParser(description="Развернуть срез базы клиники в локальную песочницу tmp_clinic_<id>")
    p.add_argument("--file", help="Путь к файлу со срезом (00_snapshot_for_agent.sql)")
    p.add_argument("--from-clipboard", action="store_true", help="Прочитать срез прямо из буфера обмена Windows")
    p.add_argument("--clinic-id", required=True, help="Код/ID клиники (например, 2523 или test)")
    args = p.parse_args()

    if not args.file and not args.from_clipboard:
        p.error("Укажите --file или --from-clipboard")

    text = read_clipboard() if args.from_clipboard else Path(args.file).read_text(encoding="utf-8", errors="replace")
    parsed = parse_snapshot(text)

    if not parsed["schema"]:
        print("ОШИБКА: В срезе не найден блок SCHEMA|. Проверьте, что скопировали результат 00_snapshot_for_agent.sql.")
        return 1

    safe_id = re.sub(r"[^A-Za-z0-9_]", "_", args.clinic_id)
    db_name = f"tmp_clinic_{safe_id}"

    build_sandbox_db(db_name, parsed)

    scratch_dir = ROOT / "scratch"
    scratch_dir.mkdir(exist_ok=True)
    json_out = scratch_dir / f"snapshot_{safe_id}.json"
    json_out.write_text(
        json.dumps(parsed, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(f"Песочница успешно развёрнута: [{db_name}]")
    print(f"  Мета:             {parsed['meta']}")
    print(f"  Таблиц в схеме:   {len(parsed['schema'])}")
    print(f"  Сценариев:        {len(parsed['deliveries'])}")
    print(f"  Условий отбора:   {len(parsed['deliv_conditions'])}")
    print(f"  Параметров:       {len(parsed['deliv_params'])}")
    print(f"  Групп процедур:   {len(parsed['procgroups'])} (связок procedurex: {len(parsed['procedurex'])})")
    print(f"  Врачей:           {len(parsed['doctors'])}")
    print(f"  Услуг справочника:{len(parsed['procedures'])}")
    total_inv_rows = sum(len(v) for v in parsed["rows"].values())
    inv_details = ", ".join(f"{k}: {len(v)}" for k, v in parsed["rows"].items()) if total_inv_rows else "0"
    print(f"  Строк расслед.:   {total_inv_rows} ({inv_details})")
    print(f"  JSON-слепок:      {json_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
