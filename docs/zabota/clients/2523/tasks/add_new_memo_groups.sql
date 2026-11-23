/* ============================================================================
   Клиника 2523, задача 1455558 — новые памятки: IW10 / IW15 / IW16.
   Создание групп процедур с точным составом из брифа от 11.11.26
   и наполнение их услугами. Существующие G2 и G7 не изменяются;
   из IW6 убираются пигментные услуги (раздел 4).

   Состав:
     IW10 После удаления новообразований      — 13 услуг (состав как в G7)
     IW15 После удаления пигментных пятен     — 4 услуг (пересекается с IW6)
     IW16 После игольчатого РФ-лифтинга       — 12 услуг (как в G2, без 2 лишних)

   Скрипт идемпотентный: повторный запуск не создаёт дублей.
   ============================================================================ */

USE wellness_new;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ---------- 1. ПРОВЕРКА: все услуги есть в справочнике ---------- */
SELECT v.proc_id
FROM (VALUES
    (23593),
    (24976),
    (5117),
    (8974),
    (8439),
    (20990),
    (20515),
    (24788),
    (22803),
    (7663),
    (9262),
    (7578),
    (6607),
    (786),
    (787),
    (23112),
    (785),
    (27208),
    (25295),
    (28032),
    (10516),
    (9951),
    (7792),
    (5977),
    (5435),
    (9471),
    (6242),
    (5125),
    (6832)
) AS v(proc_id)
LEFT JOIN dbo.procedures p ON p.Procedure_id = v.proc_id
WHERE p.Procedure_id IS NULL;
GO
/* Ожидается 0 строк. Если что-то вернулось — услуги нет в procedures,
   дальше запускать нельзя. */

/* ---------- 2. СОЗДАНИЕ ГРУПП ---------- */
BEGIN TRAN;

IF NOT EXISTS (SELECT 1 FROM dbo.procgroups WHERE code = N'IW10')
    INSERT INTO dbo.procgroups (code, name, descr)
    VALUES (N'IW10', N'IW10', N'Памятка после удаления новообразований');
IF NOT EXISTS (SELECT 1 FROM dbo.procgroups WHERE code = N'IW15')
    INSERT INTO dbo.procgroups (code, name, descr)
    VALUES (N'IW15', N'IW15', N'Памятка после удаления пигментных пятен');
IF NOT EXISTS (SELECT 1 FROM dbo.procgroups WHERE code = N'IW16')
    INSERT INTO dbo.procgroups (code, name, descr)
    VALUES (N'IW16', N'IW16', N'Памятка после процедуры Игольчатого-РФ Лифтинга');

DECLARE @cnt INT;
SELECT @cnt = COUNT(*) FROM dbo.procgroups WHERE code IN (N'IW10', N'IW15', N'IW16');
IF @cnt <> 3
BEGIN
    PRINT '!!! создано не 3 группы — откат';
    ROLLBACK TRAN;
END
ELSE
BEGIN
    PRINT 'группы IW10 / IW15 / IW16 готовы';
    COMMIT TRAN;
END
GO

SELECT id, code, name, descr FROM dbo.procgroups WHERE code IN (N'IW10', N'IW15', N'IW16') ORDER BY code;
GO
/* запомните id — они нужны как :GROUPID в сценариях */

/* ---------- 3. НАПОЛНЕНИЕ ГРУПП ---------- */
/* ---- IW10 — удаление новообразований: 13 услуг ---- */
DECLARE @g INT;
SELECT @g = id FROM dbo.procgroups WHERE code = N'IW10';
IF @g IS NULL
BEGIN
    PRINT '!!! IW10: группа не найдена';
END
ELSE
BEGIN
    BEGIN TRAN;

    INSERT INTO dbo.procedurex (code, exclude, proc_id, group_id)
    SELECT NULL, 0, v.proc_id, @g
    FROM (VALUES
        (23593),
        (24976),
        (5117),
        (8974),
        (8439),
        (20990),
        (20515),
        (24788),
        (22803),
        (7663),
        (9262),
        (7578),
        (6607)
    ) AS v(proc_id)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.procedurex x
                      WHERE x.group_id = @g AND x.proc_id = v.proc_id);

    IF @@ROWCOUNT <> 13
    BEGIN
        PRINT '!!! IW10: добавлено не 13 строк — откат';
        ROLLBACK TRAN;
    END
    ELSE
    BEGIN
        PRINT 'IW10: добавлено 13 услуг';
        COMMIT TRAN;
    END
END
GO

/* ---- IW15 — удаление пигментных пятен: 4 услуг ---- */
DECLARE @g INT;
SELECT @g = id FROM dbo.procgroups WHERE code = N'IW15';
IF @g IS NULL
BEGIN
    PRINT '!!! IW15: группа не найдена';
END
ELSE
BEGIN
    BEGIN TRAN;

    INSERT INTO dbo.procedurex (code, exclude, proc_id, group_id)
    SELECT NULL, 0, v.proc_id, @g
    FROM (VALUES
        (786),
        (787),
        (23112),
        (785)
    ) AS v(proc_id)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.procedurex x
                      WHERE x.group_id = @g AND x.proc_id = v.proc_id);

    IF @@ROWCOUNT <> 4
    BEGIN
        PRINT '!!! IW15: добавлено не 4 строк — откат';
        ROLLBACK TRAN;
    END
    ELSE
    BEGIN
        PRINT 'IW15: добавлено 4 услуг';
        COMMIT TRAN;
    END
END
GO

/* ---- IW16 — игольчатый РФ-лифтинг: 12 услуг ---- */
DECLARE @g INT;
SELECT @g = id FROM dbo.procgroups WHERE code = N'IW16';
IF @g IS NULL
BEGIN
    PRINT '!!! IW16: группа не найдена';
END
ELSE
BEGIN
    BEGIN TRAN;

    INSERT INTO dbo.procedurex (code, exclude, proc_id, group_id)
    SELECT NULL, 0, v.proc_id, @g
    FROM (VALUES
        (27208),
        (25295),
        (28032),
        (10516),
        (9951),
        (7792),
        (5977),
        (5435),
        (9471),
        (6242),
        (5125),
        (6832)
    ) AS v(proc_id)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.procedurex x
                      WHERE x.group_id = @g AND x.proc_id = v.proc_id);

    IF @@ROWCOUNT <> 12
    BEGIN
        PRINT '!!! IW16: добавлено не 12 строк — откат';
        ROLLBACK TRAN;
    END
    ELSE
    BEGIN
        PRINT 'IW16: добавлено 12 услуг';
        COMMIT TRAN;
    END
END
GO

/* ---------- 4. IW6: убрать пигментные услуги (пересечение с IW15) ----------
   В IW6 (id 20) остаются только сосудистые услуги, пигментные уходят в IW15.
   Иначе пациент после лазера по пигменту получает две памятки.
   Если разделение не нужно — не выполняйте этот блок.
   ---------------------------------------------------------------------------- */
DECLARE @g20 INT;
SELECT @g20 = id FROM dbo.procgroups WHERE code = N'IW6';

IF @g20 IS NULL
BEGIN
    PRINT '!!! IW6 не найдена';
END
ELSE
BEGIN
    BEGIN TRAN;

    UPDATE dbo.procedurex
    SET exclude = 1
    WHERE group_id = @g20
      AND proc_id IN (785, 786, 787, 23112)
      AND ISNULL(exclude, 0) = 0;

    DECLARE @u INT = @@ROWCOUNT;
    PRINT 'IW6: помечено пигментных услуг ' + CAST(@u AS VARCHAR(10)) + ' (ожидается 3 или 4)';
    IF @u NOT IN (3, 4)
        ROLLBACK TRAN;
    ELSE
        COMMIT TRAN;
END
GO

/* ---------- 5. КОНТРОЛЬ ---------- */
SELECT g.id, g.code, g.name,
       COUNT(px.proc_id) AS procs,
       SUM(CASE WHEN ISNULL(px.exclude, 0) = 0 THEN 1 ELSE 0 END) AS active
FROM dbo.procgroups g
LEFT JOIN dbo.procedurex px ON px.group_id = g.id
WHERE g.code IN (N'IW10', N'IW15', N'IW16', N'IW6')
GROUP BY g.id, g.code, g.name
ORDER BY g.code;
GO
/* Ожидается: IW10 — 13, IW15 — 4, IW16 — 12 (active = procs).
   IW6 — 18 всего; активных 14, а если ранее применялся disable_extra_group_procs.sql
   (он помечал 785, 788, 789, 17614, 19836, 22656, 23874) — активных 8,
   т.е. ровно сосудистые услуги из брифа. */

/* ---------- 6. Состав новых групп ---------- */
SELECT g.code AS group_code, px.proc_id, p.Descr, ISNULL(px.exclude, 0) AS exclude
FROM dbo.procedurex px
JOIN dbo.procgroups g ON g.id = px.group_id
JOIN dbo.procedures p ON p.Procedure_id = px.proc_id
WHERE g.code IN (N'IW10', N'IW15', N'IW16')
ORDER BY g.code, p.Descr;
GO

/* ============================================================================
   ДАЛЬШЕ: id новых групп подставить в :GROUPID сценария и в текст сегмента
   памятки. id видны в разделе 2 (и в разделе 5).
   ============================================================================ */