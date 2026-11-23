# wellness_new — схема ключевых таблиц

Снято с `USERPC\ZABOTASQLSERVER1`, база `wellness_new` (SQL Server 2017 Express).

## patients (319 498 строк)

| Колонка | Тип | Примечание |
|---|---|---|
| `Patient_Id` | int, PK, identity | |
| `Card` | varchar | номер карты |
| `Cellphone` | varchar | телефон |
| `Surname`, `Firstname`, `Midname` | nvarchar | ФИО по частям (поля `fullname` нет) |
| `Dob` | datetime | дата рождения |
| `Email` | varchar | |
| `Created`, `Modified` | datetime | |
| `Deleted` | datetime | мягкое удаление |
| `Balance`, `Amount` | numeric | |
| `Import_Id` | int | |
| `Exclude` | int | |
| `Gender` | char | |
| `Practice_id` | int | |
| `Completed`, `Undone` | int | |
| `xcard`, `xcard2` | varchar | |
| `cust_id` | int | |
| `category` | varchar | |
| `age` | int | |
| `cash` | int | |
| `ntyp`, `cstatus` | int | |
| `promocode` | varchar | промокод |

## patients_visits (13 886)

`Visit_Id` (PK), `Patient_Id`, `Visit_date` (datetime), `Visit_time` (varchar),
`Doctor_ID`, `Plan_duration`, `Arrived_time`, `Checkin_time`, `Checkout_time`,
`Visit_state` (char), `Appoint_Id` (varchar), `Created`, `cust_id`, `chid`,
`modified`, `status` (varchar), `Procedure_id`, `Reason_id` (varchar).

## patients_treatment (64 984)

`Treatment_id` (PK), `Patient_id`, `Procedure_id`, `Treatment_date`,
`Total` (numeric), `Doctor_ID`, `Pay_or_not` (bit), `Teeth_id`, `cust_id`.

## procedures (29 257)

`Procedure_id` (PK), `Name`, `Descr`, `cust_id`.

## doctors (1 004)

`Doctor_ID` (PK), `Code`, `Surname`, `Firstname`, `Middlename`, `cust_id`,
`phone`, `FullName`.

## deliveries (153)

Сценарии рассылок: `delivery_id` (PK), `dname`, `delivery_type`, `dactive`,
`istemplate`, `smstext`, `emailtext`, `calltext`, `whatsapptext`, `maxtext`,
`telegrampersonaltext`, `senddate`, `sendtime`, `repeating`, `Interval`,
`Lastpost_dt`, `Stop_dt`, флаги `sendsms`, `sendemail`, `sendwhatsapp`,
`sendmax`, `sendmaxbot`, `sendtelegrampersonal`, `sendchatbot`, `sendcrm`,
`sendatonce`, `deleted`, `modified`, `code`, `segment_id`.

## deliv_orders (35 328)

`Order_id` (PK), `Created`, `Delivery_id`, `Delivery_dt`, `Order_state` (int),
`Patientcount`, `Response` (text), `Errorcount`, `Err_code`, `Err_msg`,
`chunk`, `prevorder_id`, `nextorder_id`, `modified`, `cust_id`, `is_test`.

## messages (100 753)

`Message_id` (PK), `Order_id`, `score_id`, `sent` (bit), `Message_type`,
`Message_state` (int), `Subject`, `Message_Text` (text), `Contact_info`,
`Retry`, `PRMS_id`, `SMS_parts`, `Err_code`, `Err_msg`, `Appoint_Id`,
`Patient_id`, `accept_code`, `retry_dt`, `card`, `modified`, `cust_id`,
`doctor_id`, `whats_app_id`.

## delivery_schedule_trigger (73)

`id` (PK), `delivery_id`, `type`, `enabled`, `repeat_flag`, `finish_flag`,
`start_at`, дни недели (`monday`..`sunday`), `months`, `days`,
`repeat_period`, `repeat_period_metric`, `finish_at`, `repeat_every_day`,
`repeat_every_weekend`, `repeat_from_hour/minute`, `repeat_to_hour/minute`,
`created_at`, `modified_at`.

## config (48)

`id` (PK), `created`, `section`, `name`, `value` (nvarchar), `desc`,
`parent_id`, `cust_id`, `modified`.

## Группы процедур и сегменты

> Механика групп процедур (`procgroups` + `procedurex`) — **необязательная**.
> В большинстве клиник она не заведена: услуги перечисляются в тексте сегмента
> (`Procedure_id IN (...)`), а `IGROUP`/`GROUPID` в `deliv_params` отсутствуют.
> Перед работой смотреть, что реально в базе.

### procgroups

`id` (PK, **IDENTITY**), `code` char(6), `name` varchar(80), `descr` varchar(250).
Код группы обычно совпадает с кодом сценария: `IW3`, `PW4`, `PW5.1`.

### procedurex

`id` (PK, **IDENTITY**), `code` varchar(16), `exclude` int, `proc_id`, `group_id`.
Связка «услуга ↔ группа». `proc_id` → `procedures.Procedure_id`.
`exclude = 1` — услуга отключена в группе, но **сегмент её не фильтрует**,
пока в тексте условия нет `AND ISNULL(p.exclude, 0) = 0`.

### deliv_conditions

`Id` (PK), `Condition_Type` (1 — ручной SQL, 2 — конструктор), `Expression` (text),
`Uni_key`, `Modified`, `Created`, `Name`, `Descr`, `Ident`, `saved_code` (text,
JSON `TMultiAction` у типа 2), `QueryDescription`.

### deliv_params

`Id` (PK), `Name`, `Value`, `Descr`, `delivery_id`, `Check_expression`, `Note`,
`Uni_key`, `Value2`, `order_number`, `schedule_trigger_id`.
Значения параметров сегмента: `IGROUP`/`GROUPID` (id группы), `IPAT` (сколько
пациентов за прогон), `IAGE1`/`IAGE2`, `ISFIRST`, `IGEN`, `IDAYS` и др.
Записи с `delivery_id IS NULL` — шаблонные (привязка через `Uni_key`).

## users (2)

`user_id` (PK), `name`, `password`, `role_id`. Пароли не выводить.

## Справочники

`delivery_types` (4), `deliv_groups` (4), `deliv_params` (64),
`deliv_conditions` (72), `delivery_type_chains` (96), `procgroups` (17),
`answer_words` (7), `answers` (12 973), `imports` (50).

## Представления (views)

`vpatients`, `VVisits`, `vmessages`, `vmessages_out`, `vbalance`,
`vTotals`, `vpatients_today`, `VPatients_Recorded`, `vDelivOrders1`,
`vnotcompleted` и др.

## Процедуры

`spAfterReplace`, `spReplaceAll`, `spNewOrder`, `spNewMessage`,
`spUpdateLastEvent`, `spUpdateVisitsTime`, `spFillPatientsStage` и др.
