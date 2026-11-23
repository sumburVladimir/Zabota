# PR2 — настольное приложение Заботы

## Что это

`PR2.exe` — настольный клиент на **Delphi**, который работает напрямую с базой
`wellness_new` и служит интерфейсом для просмотра, ввода и обновления данных
(пациенты, визиты, лечение, рассылки, сообщения). Отдельного API между
приложением и БД нет: изменения из интерфейса сразу попадают в MSSQL.

## Где лежит

| Файл | Версия | Размер | Дата | Роль |
|---|---|---|---|---|
| `modules\PR2.exe` | 1.0.0.0 | 1.76 МБ | 2023-01-11 | старая сборка |
| `modules\patientreactor\PR2.exe` | 2.78.224.9013 | 22.24 МБ | 2026-08-19 | актуальная сборка (Squirrel) |

> Важно: в `modules\z20.ini` секция `[PR2]` указывает
> `BaseDirectory=patientreactor`, `ExeFilename=PR2.exe`, то есть лаунчер
> запускает именно `modules\patientreactor\PR2.exe`, а не `modules\PR2.exe`
> из корня `modules`. Старый `modules\PR2.exe` — вероятно, наследие.

Рядом лежат:

- `modules\patientreactor\constructor.exe` — конструктор (v1.25.1.271).
- `modules\patientreactor\app-2.78.224\` — распакованная версия для Squirrel-обновлений.
- `modules\patientreactor\Update.exe`, `Squirrel-Update.log` — механизм обновления.

## Конфигурация

### `modules\pr2.ini`

```ini
[Database]
Protocol=mssql
UserName=sa
Password=<пароль>
HostName=USERPC\ZABOTASQLSERVER1
Database=wellness_new
```

### `modules\z20.ini`

- `[Database]` — те же параметры подключения к `wellness_new`.
- `[Path]` — привязки к соседним инструментам:
  - `Constructor=constructor.exe`
  - `Analytics=pr.exe`
  - `Answers=./ZabotaAnswers/Zabota-Answers.exe`
  - URL-шаблоны отчётов (`ReviewsAnalyzeUrl`, `NPSAnalyzeUrl`, `DetailedReportUrl`).
- `[PR2]` — `UpdateUrl`, `BaseDirectory`, `ExeFilename`.
- `[Options]` — последние выбранные фильтры/периоды интерфейса.

## Поведение и особенности

- Приложение пишет в БД напрямую (`INSERT`/`UPDATE`), поэтому ручные SQL-правки
  и работа в PR2 конкурируют за одни и те же строки.
- Перед массовыми ручными изменениями лучше закрывать PR2, чтобы не получить
  рассинхрон в открытых формах.
- Обновляется через Squirrel; после обновления активная версия — каталог
  `app-<версия>`.
- Логи обновлений: `server\Logs\updates_YYYY-MM-DD.log`.

## Типовые задачи через PR2

- Найти пациента по ФИО/телефону/карте и открыть его карточку.
- Посмотреть/добавить визит, услуги, оплату.
- Настроить и запустить сценарий рассылки, посмотреть статусы сообщений.

Точные названия экранов и полей стоит уточнять у пользователя — это
пользовательский интерфейс, а не публичный API.
