# Импорт из МИС

## Роль

Импорт забирает данные из МИС клиники и **перекладывает их в нашу схему**
(`wellness_new`): переименовывает поля, приводит типы, считает производные
значения. Для каждой МИС — свой набор SQL-скриптов (и иногда свой модуль
подключения).

## Два звена

```
МИС клиники
   │  ODBC (или другой провайдер)
   ▼
ZabotaMISExporter.exe  +  scripts\*.ns
   │  каждый .ns = SELECT из МИС, колонки названы как поля Заботы
   ▼
CSV в server\In\        (DirectWriteToZabotaDatabase=0)
   │   или прямая запись в БД (DirectWriteToZabotaDatabase=1)
   ▼
cr2importer_zabota.exe  ──►  MSSQL wellness_new
```

## Компоненты (пример: `ident last`)

`C:\Users\Владимир Капов\Desktop\интеграция\ident last\`

| Файл/папка | Назначение |
|---|---|
| `ZabotaMISExporter.exe` | .NET-экспортёр (v4.0), читает МИС и пишет в нашу схему |
| `z20.ini` | конфиг: тип интеграции, строка подключения к МИС, банк скриптов |
| `SDK.dll` | ядро/SDK экспортёра (Entity Framework, SQLite) |
| `modules\ODBC.dll` | модуль-провайдер для `Type=ODBC` |
| `scripts\*.ns` | SQL-скрипты выборки по таблицам |
| `nssm.exe` | запуск как службы Windows |
| `logs\ZabotaMISExporter_YYYY-MM-DD.log` | лог |
| `history\` | история (при `SaveHistory=1`) |

## Конфиг `z20.ini`

```ini
[Integration]
Type=ODBC
SaveHistory=0
DirectWriteToZabotaDatabase=0
ScriptsBankName=IDENT

[Database]
ConnectionString=Driver={SQL Server};Server=127.0.0.1,15000;Database=PZ;Uid=readonly_user;Pwd=;

[ZabotaDatabase]
Database=
Username=
Password=
HostName=
```

| Ключ | Смысл |
|---|---|
| `Type` | тип провайдера: `ODBC` (для IDENT), бывают другие модули |
| `ScriptsBankName` | имя банка скриптов → папка `scripts\` этой МИС |
| `DirectWriteToZabotaDatabase` | `0` — писать CSV в `In\`; `1` — писать прямо в `wellness_new` (тогда нужен `[ZabotaDatabase]`) |
| `[Database].ConnectionString` | подключение к МИС (в примере — `PZ` на `127.0.0.1,15000`, `readonly_user`) |
| `[ZabotaDatabase]` | наша БД; в примере пустая, т.к. включён режим CSV |
| `SaveHistory` | сохранять историю прогонов |

## Подключение к МИС по Windows-учётке (`UseWinAuth`)

В `[Database]` вместо `Username`/`Password` может стоять `UseWinAuth=1`
(пример — Medialog: `HostName=IVC-SRV-MIS-01`, `Database=medialog`).
Тогда экспортёр подключается к SQL МИС под **той Windows-учёткой, от имени которой
запущен процесс**, а не под учёткой пользователя, сидящего за консолью.

- `LocalSystem` / виртуальная учётка → на SQL МИС приходит `ИМЯПК$` или
  `NT AUTHORITY\ANONYMOUS LOGON` → `Login failed`.
- Нужна учётка, у которой на сервере МИС есть login и права на чтение БД МИС
  (`db_datareader`).
- Домен — доменная учётка. Без домена — локальная учётка с **тем же именем
  и паролем** на обоих серверах (pass-through NTLM).
- Смена учётки: `services.msc` → «Вход в систему» → «С учётной записью»,
  либо `nssm set <служба> ObjectName "ДОМЕН\пользователь" "пароль"`,
  либо `sc.exe config <служба> obj= "ДОМЕН\пользователь" password= "пароль"`.
  Учётке нужно право «Вход в качестве службы».
- Проверка от этой учётки:
  `sqlcmd -S <сервер МИС> -d <БД МИС> -E -Q "SELECT SUSER_SNAME()"`.
- Альтернатива — SQL-логин в МИС: `UseWinAuth=0` + `Username`/`Password`
  (если в МИС включена смешанная аутентификация).

Практика (Медиалог, клиент `3775`, сервер `IVC-SRV-MIS-01`): служба
`cr2importer_zabota` ставится через `nssm.exe` из `server\In\` и запускает
`ZabotaMISExporter.exe` оттуда же (проверяется в
`HKLM\SYSTEM\CurrentControlSet\Services\cr2importer_zabota\Parameters` →
`Application`). Имя службы не совпадает с приложением — не путать.
`sc.exe config ... obj=` учётку меняет, но **не выдаёт право «Вход в качестве
службы»** → `net start` даёт ошибку **1069**. Право выдаётся в `secpol.msc` →
Локальные политики → Назначение прав пользователя → «Вход в качестве службы»
(или через `services.msc` — оснастка выдаёт его сама).

## Банк скриптов

`ScriptsBankName` определяет набор `.ns`-файлов. Каждый файл — один
`SELECT`, который возвращает данные **уже с колонками нашей схемы**.
Файл называется по целевой таблице.

### IDENT — `scripts\*.ns`

| Скрипт | Целевая таблица | Что маппится |
|---|---|---|
| `patients.ns` | `patients` | `persons` + `patients`: ФИО, телефон, email, пол, ДР, баланс, `Exclude` из `smsrejection`, `cust_id` из приёмов, `IsFirst` |
| `patients_visits.ns` | `patients_visits` | `receptions`: визит, врач, длительность, arrived/checkin/checkout, `Visit_state` (N/C), кресло, `cust_id` |
| `patients_treatment.ns` | `patients_treatment` | `orderservicerelation` + `orders` + `serviceitemprices`: услуга, дата, сумма, врач |
| `patients_treatment_teeth.ns` | `patients_treatment_teeth` | битовая маска `TeethLong` → номера зубов (FDI) |
| `patients_diags.ns` | `patients_diags` | `MedicalRecords` + `MedicalRecordTeethAreas`: диагноз, врач, дата |
| `doctors.ns` | `doctors` | `Staffs` + `Persons`: ФИО, код |
| `procedures.ns` | `procedures` | `ServiceItems`: id, название |
| `diagnosis.ns` | `diagnosis` | `Diagnoses`: id, название, описание |
| `queue_types.ns` | `queue_types` | `ProfessionNames`: профессии |

### Пример маппинга (IDENT → наша схема)

```sql
-- patients.ns (сокращённо)
SELECT pat.id_persons        AS 'Patient_ID',
       pat.cardnumber        AS 'Card',
       p.mobilephonestring   AS 'Cellphone',
       p.surname, p.NAME AS 'Firstname', p.patronymic AS 'Midname',
       CASE WHEN p.sex = 1 THEN 'M' ELSE 'F' END AS 'Gender',
       ISNULL(pt.sum,0)      AS 'Amount',
       ...                   AS 'balance',
       CASE WHEN pat.smsrejection = 0 THEN 0 ELSE 1 END AS 'Exclude',
       ...                   AS 'cust_id'
FROM persons p, patients pat
WHERE p.id = pat.id_persons
  AND pat.cardnumber IS NOT NULL
  AND pat.id_archivingreasons IS NULL
```

Ключевые преобразования IDENT:

- `smsrejection` → `patients.Exclude` (отказ от рассылки).
- `cardnumber IS NOT NULL` и отсутствие причины архивации — фильтр «живых».
- `sex` 1 → `M`, иначе `F`.
- Баланс = сумма платежей минус стоимость услуг.
- `TeethLong` — битовая маска зубов, разворачивается в строки по зубам.
- `Visit_state`: нет причины отмены → `N`, есть → `C`.

## Много МИС

У каждой МИС свой банк скриптов (и при необходимости свой модуль в `modules\`).
В `C:\Users\Владимир Капов\Desktop\интеграция\` лежат десятки папок:
`IDENT`, `ident last`, `ident teeth`, `d4w fast`, `ibe_xpert`, `Istom`,
`StomPro`, `DentalPro`, `Infodent`, `1C` и др. При задаче «импорт для МИС X»
сначала ищем папку этой МИС и её `z20.ini` + `scripts\`.

## Типовые ошибки

Из лога `ident last` (2026-03-10):

- `Не установлено соединение с SQL Server ... error: 40` — не запущен/недоступен
  SQL Server МИС (`127.0.0.1,15000`).
- `SQL Server не найден или недоступен` — неверный адрес/порт или служба МИС лежит.
- `Error in initialize` в `ODBC.ODBC.Initialize` — проверить `ConnectionString`
  и `modules\ODBC.dll`.
- `Не удалось инициализировать модуль: ODBC Exporter` — проверить `Type` в
  `z20.ini` и наличие модуля в `modules\`.

## Диагностика

1. Смотреть `logs\ZabotaMISExporter_YYYY-MM-DD.log` — там стадии:
   «Запущена операция», «ODBC Exporter», «Начинается закачка всех данных»,
   затем ошибки подключения.
2. Проверить доступность SQL Server МИС (хост/порт из `ConnectionString`).
3. Проверить, что в `scripts\` есть `.ns` для нужных таблиц.
4. Проверить, куда пишет: `In\` (CSV) или напрямую в БД.
