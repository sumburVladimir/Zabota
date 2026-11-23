-- Клиника 2523, задача 1455558, часть 3: приглашения (PW4/PW5/PW6/PW11/PW21).
-- Только SELECT. Запускать в базе клиники. Каждый запрос -> CSV UTF-8.

USE wellness_new;
GO

/* ---------- 1. Параметры сценариев: какие группы (:IGROUP) и исключения (:DID) ---------- */
SELECT p.Id, p.delivery_id, p.Name, p.Value, p.Descr, p.schedule_trigger_id, p.order_number
FROM dbo.deliv_params p
WHERE p.delivery_id IN (535, 536, 541, 542, 551, 552, 555, 556, 655, 656, 657, 658, 663, 664)
   OR p.delivery_id IS NULL
ORDER BY p.delivery_id, p.Name;
GO

/* ---------- 2. Расписания (интервалы отправки) ---------- */
SELECT t.id AS trigger_id, t.delivery_id, d.dname, t.type, t.enabled,
       t.monday, t.tuesday, t.wednesday, t.thursday, t.friday, t.saturday, t.sunday,
       t.days, t.months,
       t.repeat_period, t.repeat_period_metric,
       t.repeat_every_day, t.repeat_every_weekend,
       t.repeat_from_hour, t.repeat_from_minute, t.repeat_to_hour, t.repeat_to_minute,
       t.start_at, t.finish_at, t.repeat_flag, t.finish_flag,
       t.repeat_duration_flag, t.hide, t.personal_parameters,
       t.created_at, t.modified_at
FROM dbo.delivery_schedule_trigger t
JOIN dbo.deliveries d ON d.delivery_id = t.delivery_id
WHERE t.delivery_id IN (535, 536, 541, 542, 551, 552, 555, 556, 655, 656, 657, 658, 663, 664)
ORDER BY t.delivery_id, t.id;
GO

/* ---------- 3. Врачи: ID -> ФИО (для сверки списков «нет записи на будущее») ---------- */
SELECT Doctor_ID, FullName, Surname, Firstname, Middlename
FROM dbo.doctors
ORDER BY Doctor_ID;
GO

/* ---------- 4. Группы процедур: состав (на что указывают :IGROUP) ---------- */
SELECT g.id AS group_id, g.code, g.name, g.descr, COUNT(px.proc_id) AS procs,
       SUM(CASE WHEN ISNULL(px.exclude, 0) = 0 THEN 1 ELSE 0 END) AS active
FROM dbo.procgroups g
LEFT JOIN dbo.procedurex px ON px.group_id = g.id
GROUP BY g.id, g.code, g.name, g.descr
ORDER BY g.id;
GO

/* ---------- 5. Что реально в группах (для сверки с брифом) ---------- */
SELECT g.id AS group_id, g.code, px.proc_id, p.Descr, ISNULL(px.exclude, 0) AS exclude
FROM dbo.procgroups g
JOIN dbo.procedurex px ON px.group_id = g.id
JOIN dbo.procedures p ON p.Procedure_id = px.proc_id
WHERE g.id IN (3, 4, 6, 8, 13, 22, 24, 25, 29, 34)
ORDER BY g.id, p.Descr;
GO

/* ---------- 6. Проверка: все Doctor_ID из условий существуют ---------- */
SELECT v.doctor_id, d.FullName
FROM (VALUES (942),(582),(397),(51),(324),(203),(280),(388),(334),(721),(514),(118),(24),(724))
     AS v(doctor_id)
LEFT JOIN dbo.doctors d ON d.Doctor_ID = v.doctor_id
WHERE d.Doctor_ID IS NULL;
GO
/* ожидается 0 строк */
