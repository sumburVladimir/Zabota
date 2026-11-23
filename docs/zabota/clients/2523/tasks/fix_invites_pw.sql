/* ============================================================================
   Клиника 2523, задача 1455558 — фиксы приглашений PW4 / PW6 / PW21.

   1) PW21 (условие 216): повтор ограничен 90 днями (было «навсегда»).
   2) PW4  (группа 28): добавлены 3 пилинга BioRePeel — теперь 5 услуг по брифу.
   3) PW4  (условие 286): = :IGROUP -> IN (:IGROUP); блок 0-89 дней исправлен
      на NOT EXISTS; добавлено исключение 553 «пилинг лица» за сегодня.
   4) PW6  (группа 32): добавлены 9 RF-услуг лица — теперь 20 услуг по брифу.

   Параметры (:IGROUP) остаются одиночными: 28 для PW4, 32 для PW6 — менять не надо.

   ВНИМАНИЕ: Expression правится напрямую. Условие 286 — SQL-тип (saved_code пуст),
   правка постоянная. У 216 saved_code — JSON конструктора: если открыть это условие
   в PR2 и сохранить, правка Expression может быть перезаписана (тогда повторить или
   поправить в конструкторе).
   ============================================================================ */

USE wellness_new;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ---------- 0. БЭКАП условий ---------- */
IF OBJECT_ID(N'dbo.deliv_conditions_bak_20261117', N'U') IS NULL
    SELECT * INTO dbo.deliv_conditions_bak_20261117
    FROM dbo.deliv_conditions WHERE Id IN (216, 286);
GO
SELECT Id, Name FROM dbo.deliv_conditions_bak_20261117;
GO

/* ---------- 1. PW21: повтор не чаще 1 раза в 3 месяца ---------- */
BEGIN TRAN;

UPDATE dbo.deliv_conditions
SET Expression = REPLACE(CAST(Expression AS NVARCHAR(MAX)),
                      N'C.delivery_id IN (:DID, 542) )',
                      N'C.delivery_id IN (:DID, 542) AND C.created >= DATEADD(day, -90, GETDATE()) )'),
    Modified = GETDATE()
WHERE Id = 216;

IF @@ROWCOUNT <> 1
   OR (SELECT CAST(Expression AS NVARCHAR(MAX)) FROM dbo.deliv_conditions WHERE Id = 216)
      NOT LIKE N'%DATEADD(day, -90, GETDATE()) )%'
BEGIN
    PRINT '!!! 216: правка не применилась — откат';
    ROLLBACK TRAN;
END
ELSE
BEGIN
    PRINT '216 (PW21): повтор ограничен 90 днями';
    COMMIT TRAN;
END
GO

/* ---------- 2. PW4: добавить 3 пилинга BioRePeel в группу 28 ---------- */
BEGIN TRAN;

INSERT INTO dbo.procedurex (code, exclude, proc_id, group_id)
SELECT NULL, 0, v.proc_id, 28
FROM (VALUES
        (21918),
        (23613),
        (23792)
) AS v(proc_id)
WHERE NOT EXISTS (SELECT 1 FROM dbo.procedurex x
                  WHERE x.group_id = 28 AND x.proc_id = v.proc_id);

IF @@ROWCOUNT <> 3
BEGIN
    PRINT '!!! PW4: добавлено не 3 строки — откат';
    ROLLBACK TRAN;
END
ELSE
BEGIN
    PRINT 'PW4: в группу 28 добавлены 3 пилинга BioRePeel';
    COMMIT TRAN;
END
GO

/* ---------- 3. PW4: новое условие 286 ---------- */
BEGIN TRAN;

UPDATE dbo.deliv_conditions
SET Expression = CAST(N'  SELECT top :IPAT * FROM vpatients patients
  WHERE
patients.Exclude=0 and patients.hide=0
  AND patients.age >= 18

  /* была получена услуга ровно 90 дней назад (чистки + пилинги BioRePeel, группа 28) */
  AND EXISTS (SELECT 1 FROM patients_treatment pt
  JOIN procedurex p ON p.proc_id=pt.Procedure_id
  WHERE patients.patient_id=pt.Patient_id
  AND p.group_id IN (:IGROUP)
  AND DATEDIFF(DAY, pt.Treatment_date, GETDATE()) = 90)

  /* исключить получение услуг 0-89 дней */
  AND NOT EXISTS (SELECT 1 FROM patients_treatment pt
  JOIN procedurex p ON p.proc_id=pt.Procedure_id
  WHERE patients.patient_id=pt.Patient_id
  AND p.group_id IN (:IGROUP)
  AND DATEDIFF(DAY, pt.Treatment_date, GETDATE()) BETWEEN 0 AND 89)

  /* нет записи на будущее */
  AND NOT EXISTS (SELECT 1 FROM patients_visits pv
  WHERE patients.patient_id=pv.Patient_Id
  AND DATEDIFF(DAY, GETDATE(), pv.Visit_date) >= 0
  AND pv.Visit_state=''N''
  AND pv.Doctor_ID in (942, 582, 397, 51, 324, 203, 280, 388, 334, 721, 514, 118))

  /* не чаще 1 раза в 3 месяца */
  AND NOT EXISTS (SELECT 1 FROM messages m
  JOIN deliv_orders do ON m.Order_id = do.Order_id
  WHERE m.Patient_id=patients.patient_id
  AND do.Delivery_id IN (:DID)
  AND DATEDIFF(DAY, do.Created, GETDATE()) <= 90)

  /* исключить успешное сегодня «Приглашение на пилинг лица WA» (553) */
  AND NOT EXISTS (SELECT 1 FROM messages m
  JOIN deliv_orders do ON m.Order_id = do.Order_id
  WHERE m.Patient_id=patients.patient_id
  AND do.Delivery_id = 553
  AND DATEDIFF(DAY, do.Created, GETDATE()) = 0)' AS NVARCHAR(MAX)),
    Modified = GETDATE()
WHERE Id = 286;

IF @@ROWCOUNT <> 1
BEGIN
    PRINT '!!! 286: не обновлено — откат';
    ROLLBACK TRAN;
END
ELSE
BEGIN
    PRINT '286 (PW4): условие обновлено';
    COMMIT TRAN;
END
GO

/* ---------- 4. PW6: добавить 9 RF-услуг лица в группу 32 ---------- */
BEGIN TRAN;

INSERT INTO dbo.procedurex (code, exclude, proc_id, group_id)
SELECT NULL, 0, v.proc_id, 32
FROM (VALUES
        (27208),
        (25295),
        (28032),
        (10516),
        (9951),
        (7792),
        (9471),
        (6242),
        (5125)
) AS v(proc_id)
WHERE NOT EXISTS (SELECT 1 FROM dbo.procedurex x
                  WHERE x.group_id = 32 AND x.proc_id = v.proc_id);

IF @@ROWCOUNT <> 9
BEGIN
    PRINT '!!! PW6: добавлено не 9 строк — откат';
    ROLLBACK TRAN;
END
ELSE
BEGIN
    PRINT 'PW6: в группу 32 добавлено 9 RF-услуг лица';
    COMMIT TRAN;
END
GO

/* ---------- 5. КОНТРОЛЬ ---------- */
SELECT Id, LEN(CAST(Expression AS NVARCHAR(MAX))) AS expr_len, Modified
FROM dbo.deliv_conditions WHERE Id IN (216, 286) ORDER BY Id;
GO
SELECT g.id, g.code, COUNT(*) AS procs,
       SUM(CASE WHEN ISNULL(px.exclude,0)=0 THEN 1 ELSE 0 END) AS active
FROM dbo.procgroups g
JOIN dbo.procedurex px ON px.group_id = g.id
WHERE g.id IN (27, 28, 32)
GROUP BY g.id, g.code ORDER BY g.id;
GO
/* ожидается: 27 — 3, 28 — 5, 32 — 20 */

/* ---------- 6. Проверка ключевых фрагментов 286 ---------- */
SELECT
  CASE WHEN CAST(Expression AS NVARCHAR(MAX)) LIKE N'%p.group_id IN (:IGROUP)%' THEN 1 ELSE 0 END AS has_in_groupid,
  CASE WHEN CAST(Expression AS NVARCHAR(MAX)) LIKE N'%AND NOT EXISTS (SELECT 1 FROM patients_treatment pt%' THEN 1 ELSE 0 END AS has_not_exists,
  CASE WHEN CAST(Expression AS NVARCHAR(MAX)) LIKE N'%do.Delivery_id = 553%' THEN 1 ELSE 0 END AS has_553
FROM dbo.deliv_conditions WHERE Id = 286;
GO
/* ожидается 1 / 1 / 1 */

/* ---------- 7. ОТКАТ ---------- */
/*
UPDATE dbo.deliv_conditions SET Expression = b.Expression, Modified = b.Modified
FROM dbo.deliv_conditions d JOIN dbo.deliv_conditions_bak_20261117 b ON b.Id = d.Id;
DELETE x FROM dbo.procedurex x WHERE x.group_id = 28 AND x.proc_id IN (21918, 23613, 23792);
DELETE x FROM dbo.procedurex x WHERE x.group_id = 32 AND x.proc_id IN (27208, 25295, 28032, 10516, 9951, 7792, 9471, 6242, 5125);
*/
GO

/* ============================================================================
   ОПЦИОНАЛЬНО (не входит в фикс): в условиях 288 (PW5), 291 (PW6), 294 (PW11)
   блок «исключить получение услуг 0-N дней» тоже сделан через IN, а не NOT EXISTS —
   свежие услуги не исключают пациента, а требуются. Если подтвердят — раскомментировать:
   ----------------------------------------------------------------------------
UPDATE dbo.deliv_conditions
SET Expression = REPLACE(CAST(Expression AS NVARCHAR(MAX)),
                         N'AND patients.patient_id IN (SELECT pt.Patient_id from patients_treatment pt',
                         N'AND NOT EXISTS (SELECT 1 FROM patients_treatment pt')
WHERE Id IN (288, 291, 294);
   ============================================================================ */