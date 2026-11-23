-- Клиника 2523, задача 1455558, часть 1 (памятки). Только SELECT.
-- Запускать в базе wellness_new на сервере клиники (RDP, dbForge).

-- 1. Памятки: статус, каналы, тексты
SELECT delivery_id, dname, delivery_type, dactive, istemplate, deleted,
       senddate, sendtime, sendatonce, repeating, Interval, Stop_dt, Lastpost_dt,
       sendsms, sendemail, sendwhatsapp, sendmax, sendmaxbot, sendtelegrampersonal, sendchatbot,
       LEN(CAST(whatsapptext AS NVARCHAR(MAX))) AS wa_len,       LEFT(CAST(whatsapptext AS NVARCHAR(MAX)), 150) AS wa_text,
       LEN(CAST(maxtext AS NVARCHAR(MAX))) AS max_len,           LEFT(CAST(maxtext AS NVARCHAR(MAX)), 150) AS max_text,
       LEN(CAST(telegrampersonaltext AS NVARCHAR(MAX))) AS tg_len,
       LEN(CAST(smstext AS NVARCHAR(MAX))) AS sms_len,
       segment_id, code, modified
FROM deliveries
WHERE dname LIKE N'%памят%' OR dname LIKE N'%Инф%'
ORDER BY dname;

-- 2. Расписание (триггеры) памяток
SELECT d.delivery_id, d.dname, t.id AS trigger_id, t.type, t.enabled, t.repeat_flag, t.finish_flag,
       t.start_at, t.finish_at, t.repeat_period, t.repeat_period_metric,
       t.repeat_every_day, t.repeat_every_weekend,
       t.repeat_from_hour, t.repeat_from_minute, t.repeat_to_hour, t.repeat_to_minute
FROM deliveries d
LEFT JOIN delivery_schedule_trigger t ON t.delivery_id = d.delivery_id
WHERE d.dname LIKE N'%памят%' OR d.dname LIKE N'%Инф%'
ORDER BY d.dname, t.id;

-- 3. Активность: сколько заданий ушло за 90 дней
SELECT d.delivery_id, d.dname,
       COUNT(o.Order_id)      AS orders_90d,
       SUM(o.Patientcount)    AS patients_90d,
       MAX(o.Delivery_dt)     AS last_dt
FROM deliveries d
LEFT JOIN deliv_orders o
       ON o.Delivery_id = d.delivery_id
      AND o.Delivery_dt >= DATEADD(day, -90, GETDATE())
WHERE d.dname LIKE N'%памят%' OR d.dname LIKE N'%Инф%'
GROUP BY d.delivery_id, d.dname
ORDER BY d.dname;

-- 4. Структура deliv_conditions (нужна, чтобы дальше достать условия сегментов)
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'deliv_conditions'
ORDER BY ORDINAL_POSITION;
