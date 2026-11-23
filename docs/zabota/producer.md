# Продюсер `cr2producer_zabota.exe` — «мозги» Заботы

## Роль

Серверный компонент, который исполняет сценарии рассылок. PR2 — это UI, где
пользователь задаёт параметры; продюсер — то, что реально читает базу,
отбирает пациентов, подставляет псевдонимы и отправляет сообщения по каналам.

| Параметр | Значение |
|---|---|
| Файл | `C:\Zabota 2.0\profiles\zabota\server\cr2producer_zabota.exe` |
| Версия | 3.8.112.9414 |
| Конфиг | `server\cr2producer_zabota.ini` |
| Лог | `server\Logs\cr2producer_zabota_YYYYMMDD.log` |
| Клиника | `ClinicID=6062` |
| Окно работы | `WorkTimeStart=08:00`, `WorkTimeEnd=21:50` |

## Конвейер обработки сценария

```
1. Расписание      delivery_schedule_trigger  (дни недели, период, окно времени)
        │
2. Сценарий        deliveries                (текст, каналы, тип, активность)
        │
3. Скрипт отбора   deliv_conditions.Expression (SQL-выборка пациентов)
        │           параметры :IAGE1, :IDAYS, :ISFIRST, :IGEN, ...
4. Значения парам. deliv_params               (значения под конкретный delivery_id)
        │
5. Пациенты        patients / patients_visits / patients_treatment (через view)
        │
6. Псевдонимы      aliases                    ({pn}, {nvs}, {doc}, ...)
        │           подставляются персонально каждому пациенту
        │
7. Задание         deliv_orders               (шапка запуска)
        │
8. Сообщения       messages                   (по одному на пациента/канал)
        │           Message_type = WHATSAPP / EMAIL / ...
        ▼
9. Отправка        HTTP API сервисов Заботы  →  API провайдера
                                                    (WhatsApp, Telegram, Max, SMS)
```

## Что где хранится

### Сценарий — `deliveries`

Одна строка = один сценарий рассылки. Ключевое:

- `dname` — название, `delivery_type` — тип (1 Приглашения, 2 Отзывы, 3 Напоминания, 4 Информация).
- Тексты по каналам: `smstext`, `emailtext`, `whatsapptext`, `maxtext`,
  `maxbot_text`, `telegrampersonaltext`, `calltext`, `chatbot_text`.
- Флаги каналов: `sendsms`, `sendemail`, `sendwhatsapp`, `sendmax`,
  `sendmaxbot`, `sendtelegrampersonal`, `sendchatbot`, `sendcrm`, `sendcascade`.
- Расписание/повтор: `senddate`, `sendtime`, `repeating`, `Interval`,
  `repeatmode`, `Lastpost_dt`, `Stop_dt`, `finish_flag`.
- Служебное: `dactive`, `deleted`, `istemplate`, `code`, `segment_id`,
  `timetolive` (`DeliveryMessageTTL=480` в конфиге).

### Скрипт отбора — `deliv_conditions`

`Expression` — это SQL-запрос, который возвращает пациентов под сценарий.
Внутри используются именованные параметры, которые продюсер подставляет из
`deliv_params`:

| Параметр | Смысл |
|---|---|
| `:DID` | `delivery_id` текущего сценария |
| `:IAGE1`, `:IAGE2` | возраст от / до |
| `:ISFIRST` | 1 — первичные, 2 — повторные, 0 — все |
| `:IGEN` | 1 — жен, 2 — муж, 0 — все |
| `:IDAYS` | дней до/после визита |
| `:IVIS` | минимальное число визитов |
| `:ISUM` | минимальная сумма услуг |
| `:IDAYW` | режим дней недели (0 — все, 1 — ПН–ПТ, 2 — СБ) |
| `:IRES` | порог оценки (для NPS/отзывов) |
| `:IGROUP` | id группы процедур (приглашения; значение в `deliv_params`) |
| `:GROUPID` | id группы процедур (памятки; значение в `deliv_params`) |
| `:IPAT` | сколько пациентов отбирать за один прогон |

> `:IGROUP` и `:GROUPID` — одно и то же по смыслу (id из `procgroups`), но разные
> имена: памятки исторически используют `GROUPID`, приглашения — `IGROUP`.
> Появляются только там, где клиника реально завела группы процедур (см. ниже);
> в большинстве клиник эти параметры не используются.
> Подставляются как текст, поэтому список групп возможен только если в тексте
> сегмента стоит `IN (:IGROUP)`, а не `= :IGROUP`.

Запросы опираются на view: `VPatients`, `VPatients_Recorded`,
`vPatients_NextVisit`, `vPatients_LastVisit1`, `vVisit_Count`, `VMESSAGES`
и функции `dbo.fsIsFirstVisit(...)`.

### Параметры — `deliv_params`

Значения параметров. Есть глобальные (`delivery_id = NULL`, привязка через
`Uni_key`) и переопределения под конкретный `delivery_id`.

### Псевдонимы — `aliases`

Псевдоним в тексте (`{pn}`) → выражение (`[Surname] [Firstname] [Midname]`),
которое вычисляется для каждого пациента при отправке. Примеры:

| Псевдоним | Значение |
|---|---|
| `{cln}` | `[ClinicName]` |
| `{snm}` / `{fnm}` / `{mnm}` | фамилия / имя / отчество |
| `{pn}` | ФИО полностью |
| `{crd}` | номер карты |
| `{lvs}` / `{nvs}` | предыдущий / следующий визит (дата) |
| `{nvt}` | время следующего визита |
| `{doc}` | фамилия и инициалы врача |
| `{dls}` / `{dlf}` | врач предыдущего визита (кратко / полностью) |
| `{cpn}` / `{cml}` / `{car}` / `{clu}` | телефон / почта / адрес / сайт клиники |
| `{pbl}` | баланс |

Плюс функции: `{idt,x1}` — «сегодня + X1 дней» через
`FORMATDATETIME`/`INCDATE`, `STRTOK(...)` для разбора ФИО врача.

### Группы процедур — `procgroups` + `procedurex` (необязательная механика)

**Это не общий стандарт.** В большинстве клиник сегменты просто перечисляют
услуги напрямую (`p.Procedure_id IN (123, 456, ...)`) или строятся вообще не по
услугам (врачи, суммы, визиты). Группы процедур заводят, когда список услуг
большой и часто меняется, чтобы не править SQL в каждом сценарии — так было
удобно на задаче клиники 2523. Если в базе групп нет — это нормально, не надо
их создавать «для порядка».

Есть группы — набор услуг задаётся ими:

| Таблица | Поля | Смысл |
|---|---|---|
| `procgroups` | `id` (IDENTITY), `code` char(6), `name`, `descr` | справочник групп |
| `procedurex` | `id` (IDENTITY), `code`, `exclude` int, `proc_id`, `group_id` | связка «услуга ↔ группа» |

- `proc_id` → `procedures.Procedure_id`; название услуги в `procedures.Descr`
  (`procedures.Name` — GUID из МИС, не название).
- Одна услуга может быть в нескольких группах — удалять/добавлять нужно по паре
  `(group_id, proc_id)`.
- `code` группы по соглашению повторяет код сценария: `IW3`, `PW4`, `PW5.1`.
- Сегмент памятки обычно: `EXISTS (... JOIN procedurex p ON p.proc_id = pt.Procedure_id
  AND p.group_id = :GROUPID AND DATEDIFF(DAY, pt.Treatment_date, GETDATE()) = 0)`.

Как узнать, что используется в конкретной базе: посмотреть текст сегмента и
`deliv_params` (`IGROUP`/`GROUPID`). Если параметров нет, а в SQL перечислены
`Procedure_id` — значит группы не используются.

### Два типа условий: SQL и конструктор

`deliv_conditions.Condition_Type`:

| Тип | Что это | `saved_code` | Как править |
|---|---|---|---|
| `1` | ручной SQL-сегмент (новый стиль) | пусто | можно править `Expression` напрямую — это источник истины |
| `2` | сегмент, собранный конструктором PR2 | JSON `TMultiAction` | править **только в конструкторе**; `Expression` — производное, перезапишется при сохранении |

Перед правкой сегмента всегда смотреть `Condition_Type` и `saved_code`:
если `saved_code` не пуст — правка SQL в базе временная.

### Связь «сценарий ↔ условие»

Явного FK в базе нет. Практически определяется так:

- по совпадению имён (`dname` ↔ `deliv_conditions.Name`, часто с суффиксом `SQL`/`WA`);
- по `deliv_params.delivery_id` — параметры (`IGROUP`, `IPAT`) привязаны к сценарию;
- в условиях типа 2 — по `:DID` внутри текста.

`deliveries.code` содержит звёздочку у активной версии (`PW4*`), а `Parent_id`
указывает на «родительскую» версию (обычно выключенная WA-копия). Рабочая версия —
`dactive = 1 AND deleted = 0`.

### Подводные камни при настройке сценариев

1. **`procedurex.exclude` сам по себе не фильтрует** (там, где группы используются).
   Если сегмент написан руками, без `AND ISNULL(p.exclude, 0) = 0` отключённые
   услуги продолжат срабатывать.
2. **`SELECT TOP 3` вместо `top :IPAT`** — сценарий обработает 3 пациента за прогон
   и «замолчит». Встречается в старых SQL-сегментах.
3. **«Исключить получение услуг 0–N дней» через `IN (...)` вместо `NOT EXISTS`** —
   типичная ошибка: пациент, который был вчера, не исключается, а наоборот попадает.
4. **Исключение по `delivery_id` без даты** (`do.Delivery_id IN (:DID, 542)`) —
   повтор «навсегда» вместо «не чаще раза в 3 месяца»; нужен
   `AND do.Created >= DATEADD(day,-90,GETDATE())`.
5. **Набор услуг шире или уже брифа** — проверять, как он задан в этой базе: группой
   (`procedurex`) или перечислением `Procedure_id` в самом сегменте.
6. **Разные группы в одном сегменте** (если механика групп используется) — если услуг
   две темы (например, чистка и пилинг), нужно либо `IN (:IGROUP)` со списком, либо
   одна группа-объединение. Подстановка списка в `= :IGROUP` даст синтаксическую ошибку.

Подробный чек-лист аудита — [scenarios-audit.md](scenarios-audit.md).

## Каналы и отправка

Продюсер определяет канал по флагам сценария и формирует сообщения в
`messages` (`Message_type`, `Message_state`, `Err_code`/`Err_msg`).

Адреса API берутся из таблицы `config`, секция `urls`:

| Ключ | Адрес | Назначение |
|---|---|---|
| `Delivery` | `http://ptrr.zabota.space` | доставка сообщений |
| `Whatsapp` | `https://wp.zabota.space` | WhatsApp |
| `Max` | `https://messaging.zabota.space` | Max |
| `Cascade` | `https://cascade.zabota.space` | каскадная отправка |
| `Call` | `https://calls.zabota.space` | звонки |
| `Chatbot` | `https://lkbot.zabota.tech` | чат-бот |
| `Aggregator` | `https://aggregator-prod.infra.zabota.space` | агрегатор |
| `LinkShortener` | `https://z20.su` | сокращение ссылок |
| `Response` | `https://cl1.su` | приём ответов |
| `ReviewNPS` | `https://2ap.su` | NPS/отзывы |
| `Attachment` / `Attachments` | `https://cl8.ru`, `https://q.z20.pw` | вложения |

Схема: **продюсер → API сервисов Заботы → API провайдера**
(WhatsApp / Telegram / Max / SMS). То есть напрямую с провайдерами продюсер
не общается — только со своими сервисами.

### Обратная связь по статусам

В логе видны потоки-приёмники статусов:

- `TWhatsAppStatusReceiver`
- `TMaxStatusReceiver`
- `TCascadeStatusReceiver`

Они забирают статусы доставки/прочтения и обновляют `messages.Message_state`.

## Наблюдаемые данные

- `messages.Message_type`: `WHATSAPP` (98 306), `EMAIL` (2 428).
- `messages` — 100 753 строки, `deliv_orders` — 35 328.
- `deliveries` — 153, `deliv_conditions` — 72, `deliv_params` — 64,
  `delivery_schedule_trigger` — 73, `aliases` — 42.

## Типовые ошибки в логах

- `TReviewsCollector ... EConvertError: '' is not a valid integer value` —
  пустое/некорректное значение параметра в конфиге.
- `Qzanswers/Qzforms request failed ... URL:https://q.z20.pw/...` —
  сетевые/SSL-проблемы с сервисом квизов.
- `TWhatsAppStatusReceiver ... 502 Bad Gateway` — недоступность сервиса
  статусов WhatsApp.
- `TMaxStatusReceiver ... HTTP Error: -1` — недоступность Max-сервиса.
