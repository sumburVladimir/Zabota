# Дайджест: Интегратор

Конспект официальных документов из
`C:\Users\Владимир Капов\Desktop\интеграция\ОИ и новый импорт единая версия\Integrator\Documents`.
При расхождениях с копией `Интегратор новый` приоритет у этой папки.

Общие соглашения, повторяющиеся во всех файлах:

- все параметры размещаются в секциях `IntegrationN` файла `Integrator.sccfg`;
- имена параметров и значений нечувствительны к регистру;
- `Type` — тип интеграции, одновременно выбор модуля и режима;
- для импортёров шаги задаются `ImportN = /D=<тип> /T=<таблица> [аргументы]`;
- шаблоны `.sccfg` в поставке двоичные, формируются `Configurator`;
- секреты в этом конспекте заменены на `<...>`.

---

## IntegratorManual

**Назначение.** `Integrator` — компонент «Забота 2.0 Desktop Backend» для
двунаправленной интеграции с МИС. Импорт: справочники и оперативные данные
(специалисты, пациенты, визиты). Экспорт: итоги взаимодействия (подтверждение
или отмена визита). Настройка — только силами техподдержки.

**Требования.** Windows не ниже 7 SP1, Microsoft .NET 6 Runtime.

**Установка.**

1. Распаковать `Integrator.zip`.
2. Создать каталог `server\Integrator`.
3. Скопировать туда распакованные файлы.

**Настройка.**

1. Настроить через утилиту `Configurator`.
2. Скопировать полученный `Integrator.sccfg` в `server\Integrator`.
3. Справочные материалы: `IntegratorManual.md`, `IntegratorSettings.md`,
   файлы целевой МИС. В документе упомянуты `ExporterMethodsVS.md` и
   `ImporterMethods.md`, но в этой папке их нет.
4. Перед изменением конфигурации остановить службу.

**Служба Windows.** Команды выполняются от администратора; пути и имена с
пробелами — в кавычках.

- создание: `sc create "<ИмяСлужбы>" binPath= "<путь>\Integrator.exe" start= auto`
- запуск: `sc start "<ИмяСлужбы>"`
- остановка: `sc stop "<ИмяСлужбы>"`
- удаление: `sc delete "<ИмяСлужбы>"`

---

## IntegratorSettings

**Файл.** `Integrator.sccfg`, должен лежать рядом с `Integrator.exe` и быть
сформирован `Configurator`. После редактирования — перезапуск Интегратора.
Регистр имён и значений не важен (`NumIntegrations` = `NUMINTEGRATIONS`,
`NO` = `no`).

**Секции:**

- `Common` — общие настройки приложения;
- `IntegrationN` (`Integration1`, `Integration2`, …) — отдельные интеграции;
- `ZabotaDatabase` — подключение к БД «Забота»;
- произвольные секции — общие параметры, на которые ссылается `Config`.

**Правила.** В одной `Integration` допустим только один из `ScheduleDay`,
`ScheduleWeek`, `ScheduleMonth`. `Config` ссылается на секцию с параметрами
интеграции; в ней разрешены все параметры, кроме расписания, `Type` и `Config`.

### Common

| Параметр | Формат / значения | По умолчанию | Смысл |
|---|---|---|---|
| `NumIntegrations` | положительное целое | `1` | число интеграций |
| `SleepDuration` | целое 1–360, минуты | `15` | пауза после цикла; затем интеграции запускаются последовательно при выполнении расписания |
| `WorkTimeStart` | `ЧЧ:ММ` | `9:00` | начало рабочего окна для интеграций без расписания |
| `WorkTimeEnd` | `ЧЧ:ММ` | `18:00` | конец рабочего окна; должен быть больше `WorkTimeStart` |
| `IsWriteLogToConsoleEnabled` | `YES/NO` | `NO` | лог в консоль при запуске из командной строки |
| `IsTraceLevelLogEnabled` | `YES/NO` | `NO` | трассировочный лог |
| `IsDebugLevelLogEnabled` | `YES/NO` | `NO` | отладочный лог |
| `IsWaitGC` | `YES/NO` | `NO` | ждать завершения сборщика мусора |

### Integration

| Параметр | Формат / значения | По умолчанию | Смысл |
|---|---|---|---|
| `Type` | строка типа (`IRenovatio`, `EAltegioVS`, `Stub`…) | — | выбор модуля |
| `Config` | имя секции | — | ссылка на общую секцию параметров |
| `ScheduleDay` | целые 0–23 через пробел | — | запуск в указанные часы ежедневно |
| `ScheduleWeek` | целые 1–7 (1 = Пн) | — | запуск по дням недели |
| `ScheduleMonth` | целые 1–28 | — | запуск по дням месяца |
| `StartTime` | целое 0–23 | `0` | час запуска для `ScheduleWeek`/`ScheduleMonth` |
| `Postprocess` (и `PostprocessN`) | `ИмяПроцедуры /<ПАРАМЕТР>\|<ТИП>\|<ЗНАЧЕНИЕ>` | — | постобработка после успешного импорта |

`Postprocess`: типы `INT` (`-52`), `REAL` (`-12,54` — десятичная запятая),
`BOOL` (`TRUE/FALSE`), `DATETIME` (`2021.10.11 14:34`, `2022.05.20`, `6:55`),
`STRING`; допускается `NULL`. Разделители — `/` и `|` только как разделители.

### ZabotaDatabase

| Параметр | Обязательность | Смысл |
|---|---|---|
| `Hostname` | да | сервер БД |
| `Database` | да | имя базы |
| `Username` | нет | пользователь |
| `Password` / `CPassword` / `CryptPassword` | нет | пароль по способу хранения |
| `StoredProcedureTimeout` | нет | таймаут хранимых процедур, сек., по умолчанию `30` |

### Пример и рекомендации

Пример в документе показывает три интеграции `IRenovatio` с разными
расписаниями и `Postprocess = spReplaceAll /EmptyTmp|INT|0`. Он содержит
реальные ключи и пароли — переносить их нельзя.

- При собственном расписании `Schedule*` рабочее окно не влияет на запуск.
- Большой `SleepDuration` может привести к пропуску запусков.
- После правки `Integrator.sccfg` обязателен перезапуск.

---

## CommunicationStatuses

| Код | Статус |
|---|---|
| 0 | Обработка |
| 1 | Отправлена доставка |
| 2 | Отправлен ответ |
| 3 | Сбой |
| 4 | Пропуск |

Используется в журналах коммуникаций; в `ExporterIdentVS.sql` —
поле `ident_communication_log.status`.

---

## Stub

Пустой трансивер для проверки конфигурации, расписания и службы.

- `Type = Stub` — обязательно;
- `Message` — текст, выводимый в журнал при запуске;
- пример: `[Integration1]`, `Type = Stub`, `Message = Привет мир!`.

---

## Экспортёры

Все описанные экспортёры — экспорт **статуса визита**: поиск новых ответов
пациентов и передача в МИС подтверждения, переноса или отмены. Общие для них
параметры: `StartFrom` (начальная дата поиска, `ГГГГ-ММ-ДД`, по умолчанию
текущая дата) и три переключателя — `IsConfirmationEnabled`,
`IsReschedulationEnabled`, `IsCancellationEnabled` (все по умолчанию `YES`;
написание `Reschedulation` — как в документах).

### ExporterAltegioVS

**Type:** `EAltegioVS`. Экспорт статуса визита в МИС ALTEGIO.

**Обязательные:** `BaseURL` (Web API), `UserLogin`, `UserPassword`,
`PartnerToken`, `CompanyID`.

**Необязательные:**

- `StartFrom` — дата, `ГГГГ-ММ-ДД`;
- `Delay` — пауза между запросами, мс, по умолчанию `300`;
- `TimeCorrection` — коррекция времени ответа, часы, `-12…12`, по умолчанию `0`;
- `Forbidden` — запрещённые статусы: `2` — пациент подтвердил запись,
  `1` — пришёл и получил услуги, `0` — ожидает, `-1` — не пришёл;
- `IsConfirmationEnabled`, `IsReschedulationEnabled`, `IsCancellationEnabled`.

**Особенность:** в примере документа используется `UserEmail`, а в списке
обязательных — `UserLogin`; это несогласованность документа, перед настройкой
уточнять у поставщика.

### ExporterClienticsVS

**Type:** `EClienticsVS`. Экспорт статуса визита в МИС Клиентикс.

**Обязательные:** `BaseURL`, `AccountID`, `UserID`, `Token`.

**Необязательные:** `StartFrom`; `Delay` (по умолчанию `1000` мс);
`TimeCorrection` (`-12…12`); `Forbidden` — список текстовых статусов:
`cancelled`, `in_progress`, `scheduled`, `finished`, `missed`, `confirmed`,
`cancelled_by_sms`, `sms_confirmation_sent`; три `Is*Enabled`.

**Особенность:** статусы в `Forbidden` текстовые, а не числовые, в отличие от
Altegio/Renovatio/Sqns.

### ExporterCsvVS

**Type:** `ECsvVS`. Экспорт статуса визита в CSV-файл.

**Обязательные:** `Route` — полное имя CSV-файла.

**Необязательные:** `StartFrom`; `Expire` — удалять записи старше N дней от
текущей даты (`0` — не удалять, по умолчанию); три `Is*Enabled`.

**Особенность:** единственный экспортёр без внешнего API — файл на диске.

### ExporterIdentVS

**Type:** `EIdentVS`. Экспорт статуса визита в МИС IDENT.

**Обязательные:** `BaseURL`, `ClientUID`, `APIUserID`, `APIUserPassword`,
`TimeZone` (`+|-ЧЧ:ММ`), `DataSource`, `Database`, `DBUserID`,
`DBUserPassword`.

**Необязательные:** `DayShift` — коррекция даты для вычисления начала
извлечения необработанных ответов, целое отрицательное или `0`, по умолчанию
`0`.

**Особенности:**

- модуль работает и с Web API, и с БД МИС (`DataSource`, `Database`);
- в поставке есть `ExporterIdentVS.sql` — таблица журнала
  `ident_communication_log` (`message_id`, `answer_id`, `appoint_id`,
  `appoint_guid`, `visit_dt`, `sent_dt`, `action_dt`, `contact_info`, `channel`,
  `action_code`, `action_text`, `status`, `error`, `created_at`, `updated_at`,
  индекс по `message_id`);
- `status` журнала принимает значения из `CommunicationStatuses`;
- переключателей `Is*Enabled` и `Forbidden` в документе нет.

### ExporterInfoclinicVS

**Type:** `EInfoclinicVS`. Экспорт статуса визита в МИС Инфоклиника.

**Обязательные:** `Subdomain`, `ClinicKey`.

**Необязательные:** `StartFrom`; `CustId` — принудительный ИД филиала
(по умолчанию берётся из сообщения); `Delay` (по умолчанию `1000`);
три `Is*Enabled`.

**Особенность:** до запуска нужно зарегистрировать экземпляр Инфоклиники на
`https://companies.zabota.space/infoclinica/config`.

### ExporterMedialogVS

**Type:** `EMedialogVS`. Экспорт статуса визита в МИС Медиалог.

**Обязательные:** `Hostname`, `Database`, `Login`, `Password` — доступ к БД
МИС.

**Необязательные:** `StartFrom`; `IsEncryptedPassword` (`YES/NO`, по умолчанию
`NO`); три `Is*Enabled`.

**Особенность:** работает через SQL-доступ к базе Медиалога, а не через Web API.

### ExporterRenovatioVS

**Type:** `ERenovatioVS`. Экспорт статуса визита в МИС Renovatio.

**Обязательные:** `BaseURL`, `APIKey`.

**Необязательные:** `StartFrom`; `Delay` (по умолчанию `3000` мс);
`TimeCorrection` (`-12…12`); `Forbidden` — `1` записан, `2` ожидает,
`3` на приёме, `4` завершён, `5` отменён; три `Is*Enabled`.

**Особенность:** большой `Delay` по умолчанию (3 с) и числовые статусы.

### ExporterSqnsVS

**Type:** `ESqnsVS`. Экспорт статуса визита в МИС SQNS.

**Обязательные:** `BaseURL`, `UserEmail`, `UserPassword`.

**Необязательные:** `StartFrom`; `Forbidden` — `0` new, `2` confirmed,
`1` showedUp, `-1` cancel; три `Is*Enabled`.

**Особенность:** нет `Delay` и `TimeCorrection`; идентификация по e-mail.

---

## Импортёры

### ImporterClientics

**Type:** `IClientics`. Импорт из МИС Клиентикс.

**Обязательные:** `BaseURL`, `AccountID`, `UserID`, `Token`.

**Необязательные:** `Limit` — записей в ответе API, `1–100`, по умолчанию
`50`; `Delay` — мс между запросами, по умолчанию `1000`; `CancelledVisit` —
статусы отменённого визита, по умолчанию пусто (пример:
`cancelled_by_sms cancelled missed`).

**Аргументы `ImportN`:** `/D`, `/T`; `/LDS` (`N` — без кеша, `S` — сохранить,
`U` — читать кеш); `/LLL` — нижний предел загрузки в днях или `MAX` (по
умолчанию `MAX` = с 01.01.2000); `/LD` — глубина загрузки, по умолчанию равна
НПЗ.

**Цепочка кеша:** `Visits`, `VisitStatuses`, `Treatments`.

**`/D`:** `Doctors`; `Patients` (`/LLL`, `/LD`, удаление при инкременте);
`Procedures`; `Treatments` (`/LDS`, `/LLL`, `/LD`, удаление); `Visits`
(`/LDS`, `/LLL`, `/LD`, удаление); `VisitStatuses` (`/LDS`, `/LLL`, `/LD`,
удаление); `VisitStatusTypes`.

**Референсные даты:** `Patients` — обновление пациента; `Treatments`,
`Visits`, `VisitStatuses` — дата обновления визита.

**Таблицы (`ImporterClientics.sql`):** `imports`, `doctors`, `patients`,
`procedures`, `patients_treatment`, `patients_visits`, `visit_statuses`,
`status_types`.

**Особенность:** единственный документированный импортёр с параметром
`CancelledVisit`; `Limit` ограничен 100.

### ImporterDentalpro

**Type:** `IDentalpro`. Импорт из МИС DentalPRO.

**Обязательные:** `BaseURL`, `Token`, `Secret`.

**Необязательные:** `Limit` — по умолчанию `1000`; `Delay` — по умолчанию
`1000` мс; `Total` — что писать в `patients_treatment.total`: `PRICE` (итог
прайс-листа) или `PAID` (итог к оплате), по умолчанию `PRICE`.

**Аргументы:** `/LLL`, `/ULL` (верхний предел загрузки в днях, по умолчанию
`0` = по текущую дату), `/LD`. `/LDS` в документе не описан.

**`/D`:** `Chairs`; `DeletedVisits`; `Doctors`; `InsuredPatients`; `Patients`
(`/LLL`, `/LD`, удаление); `Procedures`; `Treatments` (`/LLL`, `/LD`,
удаление); `VisitReasonTypes`; `Visits` (`/LLL`, `/ULL`, `/LD`, удаление);
`VisitStatuses` (`/LLL`, `/LD`, удаление); `VisitStatusTypes`.

**Референсные даты:** `Patients` — создание/обновление; `Treatments` — дата
счёта; `Visits` — дата визита; `VisitStatuses` — дата установки статуса.

**Таблицы:** `imports`, `chairs`, `custom_deleted_visits`,
`custom_insured_patients`, `custom_reason_types`, `doctors`, `patients`,
`patients_treatment`, `patients_visits`, `procedures`, `status_types`,
`visit_statuses`. В DDL есть `checkin_time`, `checkout_time`, `balance`,
`amount`, `chid`, `reason_id`, `cust_id`.

**Особенности:** есть отдельные сущности «удалённые визиты» и «страховые
пациенты»; `/ULL` применим к `Visits`. В шапке упомянут шаблон
`ImporterDentalpro.sccfg`, но в папке его нет.

### ImporterMedods

**Type:** `IMedods`. Импорт из МИС MEDODS.

**Обязательные:** `BaseURL`, `IdentityKey`, `SecretKey`.

**Необязательные:** `Total` (`PRICE`/`PAID`, по умолчанию `PRICE`). `Limit` и
`Delay` не описаны.

**Аргументы:** `/LDS`, `/LLL`, `/LD`.

**Цепочки кеша:** `PatientCommunications` + `Patients`; `VisitComments`,
`VisitProcedures`, `Visits`, `VisitStatuses`.

**`/D`:** `Doctors`; `PatientCommunications` (`/LDS`, `/LLL`, `/LD`,
удаление); `Patients` (`/LDS`, `/LLL`, `/LD`, удаление); `Procedures`;
`StoreRemains`; `Treatments` (`/LLL`, `/LD`, удаление); `VisitComments`
(`/LDS`, `/LLL`, `/LD`, удаление); `VisitProcedures` (`/LDS`, `/LLL`, `/LD`,
удаление); `VisitReasonTypes`; `Visits` (`/LDS`, `/LLL`, `/LD`, удаление);
`VisitStatuses` (`/LDS`, `/LLL`, `/LD`, удаление); `VisitStatusTypes`.

**Референсные даты:** `PatientCommunications`, `Patients` — обновление
пациента; `Treatments` — дата лечения; `VisitComments`, `VisitProcedures`,
`Visits`, `VisitStatuses` — обновление визита.

**Таблицы:** `imports`, `custom_patient_communications`, `custom_reason_types`,
`custom_store_remains`, `custom_visit_comments`, `custom_visit_procedures`,
`doctors_tmp`, `patients_tmp`, `patients_treatment_tmp`, `patients_visits`,
`procedures_tmp`, `status_types`, `visit_statuses`.

**Особенности:** самый широкий набор сущностей: согласия на коммуникации
(`denyCalls`, `denyEmail`, `denySmsNotifications`, `denySmsDispatches`,
`denyWhatsappMessages`), комментарии и процедуры визита, остатки склада
(`amount`, `price`, `costPrice`, `number`). В шапке шаблон назван
`ImportMedods.sccfg` (фактически в папке `ImporterMedods.sccfg`).

### ImporterRenovatio

**Type:** `IRenovatio`. Импорт из МИС Renovatio.

**Обязательные:** `BaseURL`, `APIKey`, `ClinicIDs` (список через пробел).

**Необязательные:** `Total` (`PRICE`/`PAID`, по умолчанию `PRICE`);
`LoadRange` — дней в одном запросе, имитация постраничной загрузки, по
умолчанию `30`; рекомендуется подбирать так, чтобы ответ был не более
1000–1500 записей.

**Аргументы:** `/LDS`, `/LLL`, `/ULL`, `/LD`.

**Цепочки кеша:** `Visits`, `VisitStatuses`, `Treatments`; отдельно
`VisitReasons`, `Visits`, `VisitScheduleCategories`, `VisitStatuses`, `Chairs`;
`Diagnoses`, `PatientDiagnoses`.

**`/D`:** `Chairs` (`/LDS`, `/LLL`, `/ULL`, `/LD`, **без** удаления);
`Diagnoses` (`/LDS`, `/LLL`, `/LD`, **без** удаления); `Doctors`;
`PatientDiagnoses` (`/LDS`, `/LLL`, `/LD`, удаление); `Patients` (`/LLL`,
`/LD`, удаление); `Procedures`; `ScheduleCategories`; `TreatmentPlans`
(`/LLL`, `/LD`, удаление); `Treatments` (`/LLL`, `/LD`, удаление);
`VisitReasons` (`/LDS`, `/LLL`, `/ULL`, `/LD`, удаление); `Visits` (`/LDS`,
`/LLL`, `/ULL`, `/LD`, удаление); `VisitScheduleCategories` (`/LDS`, `/LLL`,
`/ULL`, `/LD`, удаление); `VisitStatuses` (`/LDS`, `/LLL`, `/ULL`, `/LD`,
удаление); `VisitStatusTypes`.

**Референсные даты:** `Chairs`, `VisitReasons`, `Visits`,
`VisitScheduleCategories`, `VisitStatuses` — дата визита; `Diagnoses`,
`PatientDiagnoses` — дата врачебного документа; `Patients` — обновление
пациента; `TreatmentPlans` — создание плана; `Treatments` — дата счёта.

**Таблицы:** `imports`, `chairs`, `custom_schedule_categories`,
`custom_treatment_plans`, `custom_visit_reasons`,
`custom_visit_schedule_categories`, `diagnosis`, `doctors`, `patients`,
`patients_diags`, `patients_treatment`, `patients_visits`, `procedures`,
`status_types`, `visit_statuses`.

**Особенности:** самый полный набор сущностей (диагнозы, планы лечения,
категории расписания, причины визита). Пример в документе содержит опечатки
(`/LD-5`, `/T-patients_diags`, обратные кавычки, лишний текст) — рабочий
формат: `/LD=-5`, `/T=<таблица>`.

### ImporterSqns

**Type:** `ISqns`. Импорт из МИС SQNS.

**Обязательные:** `BaseURL`, `UserEmail`, `UserPassword`.

**Необязательные:** `MaxRows` — строк в блоке при загрузке по диапазону дат,
по умолчанию `10000`; `ExcludeOnlineVisits` — исключать онлайн-визиты
(`YES/NO`, по умолчанию `NO`); `Total` (`PRICE`/`PAID`).

**Аргументы:** `/LDS`, `/LLL`, `/ULL`, `/LD`.

**Цепочка кеша:** `Visits`, `VisitStatuses`, `Treatments`.

**`/D`:**

- `Doctors` — автоматическая загрузка изменённых данных (не более суток);
- `Patients` — то же;
- `Procedures` — то же;
- `Treatments` — `/LDS`, `/LLL`, `/LD`, удаление;
- `Visits` — `/LDS`, `/LLL`, `/LD`, `/ULL`, удаление;
- `VisitStatuses` — `/LDS`, `/LLL`, `/LD`, `/ULL`, удаление;
- `VisitStatusTypes`.

**Референсные даты:** `Treatments`, `Visits`, `VisitStatuses` — дата визита.

**Таблицы:** `imports`, `doctors`, `patients`, `procedures`,
`patients_treatment`, `patients_visits`, `visit_statuses`, `status_types`;
у пациентов есть `amount`, `category`.

**Особенности:** для `Doctors`/`Patients`/`Procedures` не нужно задавать
периоды — модуль сам берёт изменения за последние сутки; есть фильтр
онлайн-визитов.

### ImporterStomx

**Type:** `IStomX`. Импорт из МИС StomX.

**Обязательные:** `BaseURL`, `XAPIKey`.

**Необязательные:** `Limit` — `1–1000`, по умолчанию `1000`; `Delay` — мс,
по умолчанию `1000`; `Total` (`PRICE`/`PAID`).

**Аргументы:** только `/LLL` и `/LD` (`/LDS`, `/ULL` не описаны).

**`/D`:** `Chairs`; `Doctors` (`/LLL`, `/LD`, без удаления); `Patients`
(`/LLL`, `/LD`, без удаления); `Procedures`; `Treatments` (`/LLL`, `/LD`,
без удаления); `Visits` (`/LLL`, `/LD`, без удаления); `VisitStatuses`
(`/LLL`, `/LD`, без удаления); `VisitStatusTypes`.

**Референсные даты:** `Doctors`, `Patients`, `Treatments`, `Visits`,
`VisitStatuses` — дата обновления соответствующей записи.

**Таблицы:** `imports`, `chairs`, `doctors`, `patients`, `procedures`,
`patients_treatment`, `patients_visits`, `visit_statuses`, `status_types`.

**Особенность:** импорт **не поддерживает удаление** записей при инкрементном
обновлении ни для одной сущности.

---

## Прочие файлы

### StoredProcedure.sql

Шаблон хранимой процедуры для `Postprocess`:

- входные параметры и `@Result INT OUTPUT`;
- перед выходом присвоить `@Result`;
- `0` — успех, отрицательное — ошибка, положительное — зависит от логики.

### `Importer*.sql`

Не код интеграции, а DDL целевых таблиц в БД «Забота». Общая таблица
`imports` пишется импортёрами: `ImportType` (в комментариях Medods/Dentalpro —
«всегда CS5»), `FileName` (целевая таблица), `ImportedRecs`, `UpdatedRecs`,
`ErrorRecs`, `ImportTime`, `nstatus`, `Created`, `filetime`.
Для каждой МИС набор таблиц свой; перед подключением импортёра эти объекты
должны существовать.

### Модули без документации

В каталоге `Integrator` есть `ImporterCsv.dll`, `ImporterOdbc.dll`,
`ImporterArchimedplus.dll`, `ExporterMedodsVS.dll`, но отдельных `.md` в
`Documents` нет. Их параметры, `Type` и поведение в этих источниках
**не описаны**.
