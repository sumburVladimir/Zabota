-- Клиника 2523, задача 1455558, часть 2: напоминания о визите (NW1/NW2).
-- Только SELECT. Запускать в базе клиники (wellness_new).
-- Результат каждого запроса сохранить в CSV (кодировка UTF-8) и прислать.

USE wellness_new;
GO

/* ---------- 1. Сценарии напоминаний: все поля, влияющие на расписание ---------- */
SELECT delivery_id, dname, ddescr, dactive, deleted, istemplate, delivery_type, dtype,
       segment_id, code, Parent_id,
       repeating, repeattimes, Interval, sendatonce, multifindt,
       H0, M0, H1, M1,
       Dw1, Dw2, Dw3, Dw4, Dw5, Dw6, Dw7,
       work_interval_start_at_hour, work_interval_start_at_minute,
       work_interval_finish_at_hour, work_interval_finish_at_minute,
       finish_flag, finish_at_hour, finish_at_minute,
       use_one_queue, sendcascade, senddate, sendtime, Stop_dt, Lastpost_dt,
       sendsms, sendemail, sendwhatsapp, sendmax, sendtelegrampersonal, sendchatbot,
       LEN(CAST(whatsapptext AS NVARCHAR(MAX))) AS wa_len,
       LEN(CAST(maxtext AS NVARCHAR(MAX))) AS max_len,
       LEN(CAST(telegrampersonaltext AS NVARCHAR(MAX))) AS tg_len,
       modified
FROM dbo.deliveries
WHERE dname LIKE N'%напомин%'
   OR dname LIKE N'%визит%'
   OR dname LIKE N'%прием%'
   OR dname LIKE N'%приём%'
ORDER BY delivery_id;
GO

/* ---------- 2. Триггеры (расписания) этих сценариев ---------- */
SELECT t.id AS trigger_id, t.delivery_id, d.dname, t.type, t.enabled,
       t.repeat_flag, t.finish_flag, t.start_at, t.finish_at,
       t.monday, t.tuesday, t.wednesday, t.thursday, t.friday, t.saturday, t.sunday,
       t.months, t.days,
       t.repeat_period, t.repeat_period_metric,
       t.repeat_every_day, t.repeat_every_weekend,
       t.repeat_from_hour, t.repeat_from_minute, t.repeat_to_hour, t.repeat_to_minute,
       t.repeat_duration_flag, t.hide, t.personal_parameters,
       t.created_at, t.modified_at
FROM dbo.delivery_schedule_trigger t
JOIN dbo.deliveries d ON d.delivery_id = t.delivery_id
WHERE d.dname LIKE N'%напомин%'
   OR d.dname LIKE N'%визит%'
   OR d.dname LIKE N'%прием%'
   OR d.dname LIKE N'%приём%'
ORDER BY t.delivery_id, t.id;
GO

/* ---------- 3. Структура таблицы расписаний (на случай отличий) ---------- */
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'delivery_schedule_trigger'
ORDER BY ORDINAL_POSITION;
GO

/* ---------- 4. Сегменты напоминаний ---------- */
SELECT c.Id AS cond_id, c.Name AS cond_name, c.Condition_Type, c.Ident, c.Uni_key,
       c.Modified, c.Created,
       CAST(c.Expression AS NVARCHAR(MAX)) AS Expression,
       CAST(c.saved_code AS NVARCHAR(MAX)) AS saved_code
FROM dbo.deliv_conditions c
WHERE c.Name LIKE N'%напомин%'
   OR c.Name LIKE N'%визит%'
   OR c.Name LIKE N'%прием%'
   OR c.Name LIKE N'%приём%'
   OR CAST(c.Expression AS NVARCHAR(MAX)) LIKE N'%vpatients_visit%'
   OR CAST(c.Expression AS NVARCHAR(MAX)) LIKE N'%patients_visits%'
ORDER BY c.Id;
GO

/* ---------- 5. Параметры сценариев ---------- */
SELECT * FROM dbo.deliv_params;
GO

/* ---------- 6. Настройки по времени/очереди/рассылкам ---------- */
SELECT * FROM dbo.config
WHERE LOWER(section) LIKE '%time%' OR LOWER(section) LIKE '%hour%'
   OR LOWER(section) LIKE '%deliver%' OR LOWER(section) LIKE '%messag%'
   OR LOWER(section) LIKE '%queue%' OR LOWER(section) LIKE '%interval%'
   OR LOWER(name) LIKE '%time%' OR LOWER(name) LIKE '%hour%'
   OR LOWER(name) LIKE '%interval%' OR LOWER(name) LIKE '%queue%'
   OR LOWER(name) LIKE '%timezone%' OR LOWER(name) LIKE '%часов%';
GO

/* ---------- 7. Время сервера и пояса ---------- */
SELECT @@SERVERNAME AS server, GETDATE() AS server_time, SYSDATETIMEOFFSET() AS server_offset,
       GETUTCDATE() AS utc_time;
GO

/* ---------- 8. Фактические отправки за 30 дней: по дате и часу ---------- */
SELECT o.Delivery_id, d.dname,
       CAST(o.Delivery_dt AS DATE) AS dt_date,
       DATEPART(hour, o.Delivery_dt) AS dt_hour,
       o.Order_state,
       COUNT(*) AS orders_cnt,
       SUM(o.Patientcount) AS patients_cnt
FROM dbo.deliv_orders o
JOIN dbo.deliveries d ON d.delivery_id = o.Delivery_id
WHERE o.Delivery_dt >= DATEADD(day, -30, GETDATE())
  AND (d.dname LIKE N'%напомин%' OR d.dname LIKE N'%визит%' OR d.dname LIKE N'%прием%' OR d.dname LIKE N'%приём%')
GROUP BY o.Delivery_id, d.dname, CAST(o.Delivery_dt AS DATE), DATEPART(hour, o.Delivery_dt), o.Order_state
ORDER BY o.Delivery_id, dt_date, dt_hour;
GO

/* ---------- 9. Объём: сколько записей на приём в ближайшие дни (по дням недели) ---------- */
SELECT CAST(v.Visit_date AS DATE) AS visit_date,
       DATENAME(weekday, v.Visit_date) AS weekday,
       COUNT(*) AS visits
FROM dbo.patients_visits v
WHERE v.Visit_date >= CAST(GETDATE() AS DATE)
  AND v.Visit_date < DATEADD(day, 14, CAST(GETDATE() AS DATE))
GROUP BY CAST(v.Visit_date AS DATE), DATENAME(weekday, v.Visit_date)
ORDER BY visit_date;
GO
