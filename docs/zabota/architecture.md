# Zabota — архитектура и компоненты

## Профиль

Всё развёртывание живёт в `C:\Zabota 2.0\profiles\zabota\`.
Профиль делится на `modules\` (клиентские модули) и `server\` (серверная часть).

```
C:\Zabota 2.0\
├─ profiles\zabota\
│  ├─ modules\
│  │  ├─ PR2.exe              # настольный клиент (см. pr2.md)
│  │  ├─ pr2.ini / z20.ini    # конфиги клиента
│  │  └─ patientreactor\      # актуальный PR2, constructor, Squirrel
│  └─ server\
│     ├─ cr2importer_zabota.exe + .ini   # импорт CSV -> MSSQL
│     ├─ cr2producer_zabota.exe + .ini   # генерация заданий доставки
│     ├─ syncapp\                        # SyncApp.exe, outbox SQLite -> облако
│     ├─ Logs\                           # логи импорта/продюсера/обновлений
│     ├─ migrations\                     # SQL-миграции схемы
│     ├─ In\                             # входящие CSV (сейчас пусто)
│     ├─ Data\                           # рабочие данные (сейчас пусто)
│     ├─ version                         # версия серверной части: 3.8.112
│     └─ updates\, backup\, Archive\
└─ vigruzki\                             # выгрузки
```

## Компоненты

| Компонент | Файл | Версия | Назначение |
|---|---|---|---|
| Экспортёр МИС | `ZabotaMISExporter.exe` + `scripts\*.ns` | — | МИС → наша схема (CSV/БД) |
| Импортёр | `server\cr2importer_zabota.exe` | 1.5.0.146 | CSV из `In\` → `wellness_new` |
| Продюсер | `server\cr2producer_zabota.exe` | 3.8.112.9414 | формирует задания рассылок |
| Клиент | `modules\patientreactor\PR2.exe` | 2.78.224.9013 | UI для работы с БД |
| Конструктор | `modules\patientreactor\constructor.exe` | 1.25.1.271 | настройка сценариев |
| Синхронизация | `server\syncapp\SyncApp.exe` | 1.0.6 | outbox → облако |
| Обновления | `server\zabota-service-updater.exe` | — | автообновление серверной части |

Клиника: `ClinicID=6062` (`cr2producer_zabota.ini`).

## Две ключевые роли

- **PR2 (`modules\patientreactor\PR2.exe`)** — пользовательский интерфейс:
  здесь задают параметры сценариев, тексты и каналы.
- **Продюсер (`server\cr2producer_zabota.exe`)** — «мозги»: смотрит в базу,
  читает расписание сценариев, исполняет SQL-выборки пациентов, подставляет
  псевдонимы и отправляет сообщения по каналам.

Подробно: [producer.md](producer.md).

## Импорт из МИС

Импорт двухступенчатый: `ZabotaMISExporter.exe` через ODBC и SQL-скрипты
`scripts\*.ns` перекладывает данные МИС в нашу схему, затем
`cr2importer_zabota.exe` заливает их в `wellness_new`. Для каждой МИС — свой
банк скриптов. Подробно: [import.md](import.md).

## Поток данных

```
МИС клиники
   │  ODBC / другой провайдер
   ▼
ZabotaMISExporter.exe + scripts\*.ns        (перекладка в нашу схему)
   │  CSV в server\In\  (или прямая запись в БД)
   ▼
server\In\  ──►  cr2importer_zabota.exe  ──►  MSSQL wellness_new
                                                │
     ┌──────────────────────────────────────────┼───────────────────────────┐
     ▼                                          ▼                           ▼
PR2.exe (UI)                     cr2producer_zabota.exe                SyncApp.exe
ввод/правка параметров           «мозги»: расписание + SQL-отбор       outbox SQLite
сценариев и текстов              + псевдонимы + выбор канала                  │
                                          │                                  ▼
                                          ▼                        syncgateway.zabota.space
                              messages / deliv_orders                (облако, micro_db1)
                                          │
                                          ▼
                              API сервисов Заботы (config.urls)
                                          │
                                          ▼
                              WhatsApp / Telegram / Max / SMS (API провайдеров)
```

- Импортёр подключается к МИС и пишет в `wellness_new` (учётка `sa`).
- После импорта при необходимости вызывается `spAfterReplace`.
- Продюсер ежедневно (~08:00) создаёт задания доставки по сценариям.
- PR2 — ручной интерфейс поверх той же базы.
- SyncApp забирает исходящие сообщения/события и отправляет в облако.

## База данных

| Параметр | Значение |
|---|---|
| Сервер | `USERPC\ZABOTASQLSERVER1` |
| СУБД | SQL Server 2017 Express (14.0.1000.169) |
| Аутентификация | SQL-логин `sa` |
| Базы | `wellness_new`, `wellness`, `zabota`, `db4913` |

Основные таблицы и колонки — в скилле `zabota-db`
(`.opencode/skills/zabota-db/references/schema.md`).

## Логи

| Что | Путь |
|---|---|
| Продюсер | `server\Logs\cr2producer_zabota_YYYYMMDD.log` |
| Обновления | `server\Logs\updates_YYYY-MM-DD.log` |
| Импортёр | `server\cr2importer_zabota.log` |
| Синхронизация | `server\syncapp\logs\agent-log-YYYYMMDD.txt` |

## Секреты

Пароли и client secret лежат открытым текстом в `pr2.ini`, `z20.ini`,
`server\*.ini`, `server\credentials.ini`. В документацию и отчёты их не
переносить; при необходимости ссылаться на файл.
