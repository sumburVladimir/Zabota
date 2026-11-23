/* ============================================================================
   Клиника 2523 (Wellness Clinic), задача 1455558 - часть 1 (памятки).
   Отключение ЛИШНИХ услуг в группах процедур: procedurex.exclude = 1.
   Сверка с брифом от 11.11.26, выгрузки expdata.xls + procedures.xls, 17.11.2026.

   Всего помечается: 29 связок в 4 группах:
     группа 19 (IW3  После инъекций) - 8
     группа 20 (IW6  Лечение купероза и пигментации) - 7
     группа 21 (IW7  После лазерной шлифовки/лазерного пилинга) - 13
     группа 22 (IW9  После контурной пластики) - 1

   ВНИМАНИЕ:
   - exclude=1 сам по себе сегмент НЕ фильтрует. В тексте сегмента памятки
     должно быть условие:  AND px.exclude = 0  (или ISNULL(px.exclude,0) = 0)
     в подзапросе по procedurex, иначе услуги продолжат срабатывать.
   - Строки не удаляются: откат - раздел 6 этого же скрипта.
   - Блоки 20 (IW6) и 21 (IW7) - зоны ТЕЛА: в брифе только лицо/шея/декольте.
     Если нужны намеренно - не выполняйте эти блоки.
   ============================================================================ */

USE wellness_new;
GO
SET NOCOUNT ON;
GO
SET XACT_ABORT ON;   -- при ошибке SQL транзакция откатится, а не останется висеть
GO

/* ---------- 1. ПРЕДПРОСМОТР: что сейчас будет помечено ---------- */
-- IW3 После инъекций (группа 19): 8 услуг
SELECT px.group_id, g.code AS group_code, px.proc_id, px.exclude, p.Descr
FROM dbo.procedurex px
JOIN dbo.procedures p ON p.Procedure_id = px.proc_id
JOIN dbo.procgroups g ON g.id = px.group_id
WHERE px.group_id = 19 AND px.proc_id IN (2157, 2367, 12063, 14360, 18736, 19458, 19822, 23508)
ORDER BY p.Descr;
GO

-- IW6 Лечение купероза и пигментации (группа 20): 7 услуг
SELECT px.group_id, g.code AS group_code, px.proc_id, px.exclude, p.Descr
FROM dbo.procedurex px
JOIN dbo.procedures p ON p.Procedure_id = px.proc_id
JOIN dbo.procgroups g ON g.id = px.group_id
WHERE px.group_id = 20 AND px.proc_id IN (785, 788, 789, 17614, 19836, 22656, 23874)
ORDER BY p.Descr;
GO

-- IW7 После лазерной шлифовки/лазерного пилинга (группа 21): 13 услуг
SELECT px.group_id, g.code AS group_code, px.proc_id, px.exclude, p.Descr
FROM dbo.procedurex px
JOIN dbo.procedures p ON p.Procedure_id = px.proc_id
JOIN dbo.procgroups g ON g.id = px.group_id
WHERE px.group_id = 21 AND px.proc_id IN (782, 20444, 20966, 20968, 21412, 21702, 22160, 22557, 22627, 23061, 23298, 24151, 24986)
ORDER BY p.Descr;
GO

-- IW9 После контурной пластики (группа 22): 1 услуг
SELECT px.group_id, g.code AS group_code, px.proc_id, px.exclude, p.Descr
FROM dbo.procedurex px
JOIN dbo.procedures p ON p.Procedure_id = px.proc_id
JOIN dbo.procgroups g ON g.id = px.group_id
WHERE px.group_id = 22 AND px.proc_id IN (19544)
ORDER BY p.Descr;
GO

/* Ожидаемые количества: 19=8, 20=7, 21=13, 22=1 */

/* ---------- 2. Пометка exclude = 1 ---------- */
/* ---- IW3 После инъекций - группа 19, 8 услуг ---- */
BEGIN TRAN;

UPDATE dbo.procedurex
SET exclude = 1
WHERE group_id = 19
  AND proc_id IN (2157, 2367, 12063, 14360, 18736, 19458, 19822, 23508)
  AND ISNULL(exclude, 0) = 0;

IF @@ROWCOUNT <> 8
BEGIN
    PRINT '!!! IW3: помечено не 8 строк (уже были exclude=1?) - откат блока';
    ROLLBACK TRAN;
END
ELSE
BEGIN
    PRINT 'IW3: помечено 8 строк';
    COMMIT TRAN;
END
GO

/* ---- IW6 Лечение купероза и пигментации - группа 20, 7 услуг ---- */
BEGIN TRAN;

UPDATE dbo.procedurex
SET exclude = 1
WHERE group_id = 20
  AND proc_id IN (785, 788, 789, 17614, 19836, 22656, 23874)
  AND ISNULL(exclude, 0) = 0;

IF @@ROWCOUNT <> 7
BEGIN
    PRINT '!!! IW6: помечено не 7 строк (уже были exclude=1?) - откат блока';
    ROLLBACK TRAN;
END
ELSE
BEGIN
    PRINT 'IW6: помечено 7 строк';
    COMMIT TRAN;
END
GO

/* ---- IW7 После лазерной шлифовки/лазерного пилинга - группа 21, 13 услуг ---- */
BEGIN TRAN;

UPDATE dbo.procedurex
SET exclude = 1
WHERE group_id = 21
  AND proc_id IN (782, 20444, 20966, 20968, 21412, 21702, 22160, 22557, 22627, 23061, 23298, 24151, 24986)
  AND ISNULL(exclude, 0) = 0;

IF @@ROWCOUNT <> 13
BEGIN
    PRINT '!!! IW7: помечено не 13 строк (уже были exclude=1?) - откат блока';
    ROLLBACK TRAN;
END
ELSE
BEGIN
    PRINT 'IW7: помечено 13 строк';
    COMMIT TRAN;
END
GO

/* ---- IW9 После контурной пластики - группа 22, 1 услуг ---- */
BEGIN TRAN;

UPDATE dbo.procedurex
SET exclude = 1
WHERE group_id = 22
  AND proc_id IN (19544)
  AND ISNULL(exclude, 0) = 0;

IF @@ROWCOUNT <> 1
BEGIN
    PRINT '!!! IW9: помечено не 1 строк (уже были exclude=1?) - откат блока';
    ROLLBACK TRAN;
END
ELSE
BEGIN
    PRINT 'IW9: помечено 1 строк';
    COMMIT TRAN;
END
GO

/* ---------- 3. КОНТРОЛЬ: сколько активных осталось в группах ---------- */
SELECT g.id AS group_id, g.code, g.name,
       COUNT(*) AS procs_total,
       SUM(CASE WHEN ISNULL(px.exclude, 0) = 0 THEN 1 ELSE 0 END) AS procs_active,
       SUM(CASE WHEN ISNULL(px.exclude, 0) = 1 THEN 1 ELSE 0 END) AS procs_excluded
FROM dbo.procgroups g
LEFT JOIN dbo.procedurex px ON px.group_id = g.id
WHERE g.id IN (19, 20, 21, 22)
GROUP BY g.id, g.code, g.name
ORDER BY g.id;
GO
/* Ожидается активных: 19 -> 63,  20 -> 11,  21 -> 14,  22 -> 31 */
/* Исключённых:        19 ->  8,  20 ->  7,  21 -> 13,  22 ->  1 */

/* ---------- 4. Что именно помечено (полный список) ---------- */
SELECT g.code AS group_code, px.proc_id, p.Descr
FROM dbo.procedurex px
JOIN dbo.procedures p ON p.Procedure_id = px.proc_id
JOIN dbo.procgroups g ON g.id = px.group_id
WHERE px.group_id IN (19, 20, 21, 22)
  AND ISNULL(px.exclude, 0) = 1
ORDER BY g.code, p.Descr;
GO

/* ---------- 5. Проверка сегмента (после правки текста сегмента) ---------- */
/*
SELECT COUNT(*) AS patients
FROM vpatients patients
WHERE patients.Exclude = 0 AND patients.hide = 0 AND patients.age >= 18
  AND EXISTS (SELECT 1 FROM patients_treatment pt
              JOIN procedurex p ON p.proc_id = pt.Procedure_id
              WHERE patients.patient_id = pt.Patient_id
                AND p.group_id = 19
                AND ISNULL(p.exclude, 0) = 0
                AND DATEDIFF(DAY, pt.Treatment_date, GETDATE()) = 0)
  AND NOT EXISTS (SELECT 1 FROM messages m
                  JOIN deliv_orders do ON m.Order_id = do.Order_id
                  WHERE m.Patient_id = patients.patient_id
                    AND do.Delivery_id IN (:DID)
                    AND DATEDIFF(DAY, do.Created, GETDATE()) <= 90);
*/

/* ---------- 6. ОТКАТ: вернуть exclude = 0 ---------- */
/*
-- IW3
UPDATE dbo.procedurex SET exclude = 0
WHERE group_id = 19 AND proc_id IN (2157, 2367, 12063, 14360, 18736, 19458, 19822, 23508);
-- IW6
UPDATE dbo.procedurex SET exclude = 0
WHERE group_id = 20 AND proc_id IN (785, 788, 789, 17614, 19836, 22656, 23874);
-- IW7
UPDATE dbo.procedurex SET exclude = 0
WHERE group_id = 21 AND proc_id IN (782, 20444, 20966, 20968, 21412, 21702, 22160, 22557, 22627, 23061, 23298, 24151, 24986);
-- IW9
UPDATE dbo.procedurex SET exclude = 0
WHERE group_id = 22 AND proc_id IN (19544);
*/
GO