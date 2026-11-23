---
name: Zabota DB (wellness_new)
description: Локальный тестовый стенд MSSQL wellness_new (слепок/эталон схемы Заботы и песочница для tmp_ баз) + справочник типовых таблиц Заботы. Боевые базы клиник находятся на серверах самих клиентов, а не здесь.
---

# Zabota DB — эталонная схема и локальная песочница

> **ВАЖНО:** База `wellness_new` на `USERPC\ZABOTASQLSERVER1` — это **локальный тестовый слепок** (развёрнут для примера и изучения структуры ПО Заботы).
> - **НЕ ищи здесь данные по задачам конкретных клиник** — у каждой клиники своя БД на её собственном сервере (данные клиник берём из их выгрузок CSV/XLS, папки `docs/zabota/clients/<Zabota_ID>/` или через экран RDP/Ассистента).
> - Используй `USERPC\ZABOTASQLSERVER1` только как:
>   1. **Эталон типовой схемы** таблиц «Заботы» (если у клиники нет кастома).
>   2. **Песочницу** для проверки синтаксиса (`SET PARSEONLY ON`) и создания временных баз (`CREATE DATABASE tmp_...`), куда заливаются выгрузки клиники для тестирования SQL перед отправкой клиенту.

## Реквизиты подключения (локальный стенд)

| Параметр | Значение |
|---|---|
| Сервер | `USERPC\ZABOTASQLSERVER1` |
| СУБД | Microsoft SQL Server 2017 Express (14.0.1000.169) |
| Аутентификация | SQL Server Authentication |
| Логин | `sa` |
| Пароль | в `credentials.local.ini` (файл в `.gitignore`) |
| Базы | `wellness_new` (основная), `wellness`, `zabota`, `db4913` |
| Драйвер | `ODBC Driver 17 for SQL Server` |

## Быстрое подключение

### Python (pyodbc) — предпочтительно

```python
import pyodbc
# Пароль — из credentials.local.ini, не хардкодим в коде.
import configparser
from pathlib import Path
cfg = configparser.ConfigParser()
cfg.read(Path(__file__).resolve().parents[4] / "credentials.local.ini", encoding="utf-8")
m = cfg["mssql"]

cn = pyodbc.connect(
    f"DRIVER={{{m['driver']}}};"
    f"SERVER={m['server']};"
    f"UID={m['user']};PWD={m['password']};"
    f"DATABASE={m['database']};"
    "TrustServerCertificate=yes;",
    timeout=10,
)
cur = cn.cursor()
for row in cur.execute("SELECT TOP 5 Patient_Id, Surname, Firstname FROM patients"):
    print(row)
cn.close()
```

### Готовый helper-скрипт (читает `credentials.local.ini`)

```bash
python .opencode/skills/zabota-db/scripts/db.py -c "SELECT TOP 10 * FROM patients"
python .opencode/skills/zabota-db/scripts/db.py --db zabota -c "SELECT name FROM sys.tables"
python .opencode/skills/zabota-db/scripts/db.py --file query.sql --csv out.csv
```

Пароль/сервер/база берутся из `credentials.local.ini` (секция `[mssql]`) — руками их
подставлять не нужно.

### sqlcmd

```bat
sqlcmd -S "USERPC\ZABOTASQLSERVER1" -U sa -P <пароль из credentials.local.ini> -d wellness_new -Q "SELECT COUNT(*) FROM patients"
```

## Ключевые таблицы

- `patients` (~319k) — пациенты. `Patient_Id` PK, ФИО = `Surname + Firstname + Midname` (поля `fullname` нет), `Cellphone`, `Dob`, `Deleted` (мягкое удаление), `promocode`, `category`.
- `patients_visits` (~13.9k) — визиты. `Visit_Id` PK, `Patient_Id` FK, `Visit_date`, `Doctor_ID`, `Procedure_id`, `status`, `Visit_state`.
- `patients_treatment` (~65k) — оказанные услуги/лечение. `Treatment_id` PK, `Patient_id`, `Procedure_id`, `Treatment_date`, `Total`, `Pay_or_not`.
- `procedures` (~29k) — справочник процедур/услуг. `Procedure_id`, `Name`, `Descr`.
- `doctors` (~1k) — врачи. `Doctor_ID`, `FullName`, `Surname`, `Firstname`.
- `deliveries` (153) — сценарии/рассылки. `delivery_id`, `dname`, `delivery_type`, `smstext`, `emailtext`, флаги каналов (`sendsms`, `sendemail`, `sendwhatsapp`, `sendmax`, `sendtelegrampersonal`).
- `deliv_orders` (~35k) — задания на доставку. `Order_id`, `Delivery_id`, `Delivery_dt`, `Order_state`.
- `messages` (~101k) — сообщения. `Message_id`, `Order_id`, `Patient_id`, `Message_type`, `sent`, `Message_state`, `Err_msg`.
- `delivery_schedule_trigger` (73) — расписания/триггеры рассылок.
- `procgroups` — группы процедур: `id` (IDENTITY), `code` char(6) (`IW3`, `PW4`), `name`, `descr`. **Механика необязательная**: в большинстве клиник не используется, услуги перечисляются в сегменте напрямую (`Procedure_id IN (...)`).
- `procedurex` — связка «услуга ↔ группа»: `id` (IDENTITY), `code`, `exclude`, `proc_id`, `group_id`. Используется только вместе с `procgroups`.
- `deliv_conditions` — сегменты сценариев: `Id`, `Condition_Type` (1 — SQL, 2 — конструктор), `Expression`, `saved_code` (JSON конструктора).
- `deliv_params` — значения параметров сегмента по `delivery_id` (`IGROUP`, `GROUPID`, `IPAT`, `IAGE1`, `DID` …).
- `config` (48) — настройки системы (`section`, `name`, `value`).

Справочник по колонкам: `references/schema.md`.

Стиль написания SQL-сегментов сценариев (`deliv_conditions.Expression`) — `references/sql-segments.md`
(ручной стиль, чище чем генератор `constructor.exe`).

Аудит и правка сценариев по брифу (памятки, приглашения, типовые баги) —
`docs/zabota/scenarios-audit.md`; устройство таблиц — `docs/zabota/producer.md`.

## Правка сценариев: обязательные проверки

1. **`deliv_conditions.saved_code`**: если не пуст (`Condition_Type = 2`) — сегмент
   собран конструктором, правка `Expression` будет перезаписана при сохранении из PR2.
   Править только через конструктор. Пустой `saved_code` (тип 1) — `Expression` и есть
   источник истины.
2. **`procedurex.exclude` не фильтрует сегмент сам по себе** (если группы используются).
   Если в тексте сегмента нет `AND ISNULL(p.exclude, 0) = 0`, отключённые услуги
   продолжат срабатывать.
3. **Набор услуг задаётся по-разному**: группой (параметр `:IGROUP` у приглашений,
   `:GROUPID` у памяток — значение в `deliv_params`) либо перечислением
   `p.Procedure_id IN (...)` прямо в сегменте. Не предполагать группы по умолчанию.
4. **Одна услуга может быть в нескольких группах** — менять состав только по паре
   `(group_id, proc_id)`.
5. **Массовые `UPDATE`/`DELETE`**: сначала
   `SELECT * INTO dbo.<table>_bak_YYYYMMDD FROM dbo.<table> WHERE <фильтр>;`,
   затем блоки в транзакциях с проверкой `@@ROWCOUNT` и идемпотентным `WHERE NOT EXISTS`.
6. **`procgroups.id` и `procedurex.id` — IDENTITY**: восстановление только через
   `SET IDENTITY_INSERT ... ON`. `DELETE FROM procgroups` ничем не защищён (FK нет).

## Проверка SQL перед рабочей базой

1. `SET PARSEONLY ON` — синтаксис (не проверяет существование колонок).
2. Реальный прогон на временной БД: `CREATE DATABASE tmp_...`, копии таблиц, данные из
   выгрузок, выполнить скрипт, проверить результат, `DROP DATABASE`.
3. `PRINT` не принимает подзапрос — считать в переменную; `GO` сбрасывает переменные —
   `DECLARE` в каждом батче.
4. Условия с параметрами прогонять с подставленными значениями (`:IGROUP` → `28`).
5. Выгрузки и кириллицу писать в файл UTF-8 и читать файлом: консоль PowerShell
   ломает кодировку.

## Правила работы

1. **Сначала читать, потом писать.** Любые `UPDATE` / `DELETE` / `INSERT` / `DROP` — только после явного подтверждения пользователя.
2. Всегда ограничивай выборки: `SELECT TOP N` или `WHERE` по ключу/дате. В `patients` 319k строк.
3. Для ФИО используй конкатенацию: `Surname + ' ' + Firstname + ' ' + Midname`.
4. Учитывай мягкое удаление: `patients.Deleted IS NULL` (или `= 0` по смыслу) для «живых» пациентов.
5. Даты — `datetime`; для периодов используй `>= @from AND < @to`, а не `BETWEEN`.
6. Пароль — секрет: не выводи его в отчётах, логах и коммитах.
7. Если задача про `cloud`/`zabota cloud` — это другая (облачная) база, не wellness_new.

## Документация системы

Факты об устройстве Заботы (компоненты, профили, поток данных, приложение PR2)
лежат в `docs/zabota/`:

- `docs/zabota/architecture.md` — архитектура и компоненты
- `docs/zabota/pr2.md` — настольный клиент PR2

Это справочная информация, а не процедура: читай по мере необходимости.
