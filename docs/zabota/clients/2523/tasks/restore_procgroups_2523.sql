/* ============================================================================
   Клиника 2523 — ВОССТАНОВЛЕНИЕ справочника групп процедур (procgroups).
   Источник: выгрузка expdata.xls, сделанная ДО удаления (17.11.2026).
   Групп в выгрузке: 38. Связок procedurex: 758.

   ВАЖНО:
   - procgroups.id — IDENTITY, поэтому INSERT идёт с SET IDENTITY_INSERT ON.
   - В выгрузку попали только группы, у которых есть хотя бы одна процедура.
     Группы без процедур восстановить из этих данных нельзя — если такие были,
     они не вернутся (сверить с бэкапом/скриншотом, если он есть).
   - descr = NULL там, где в выгрузке было пусто.
   - Скрипт НЕ трогает procedurex (связки услуг с группами).
   ============================================================================ */

USE wellness_new;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ---------- 1. ДИАГНОСТИКА: что сейчас в базе ---------- */
SELECT
    (SELECT COUNT(*) FROM dbo.procgroups)  AS groups_now,
    (SELECT COUNT(*) FROM dbo.procedurex)  AS links_now,
    (SELECT COUNT(DISTINCT group_id) FROM dbo.procedurex) AS distinct_group_ids_in_links,
    (SELECT MAX(group_id) FROM dbo.procedurex) AS max_group_id_in_links;
GO

-- какие group_id есть в связках, но отсутствуют в procgroups (их и надо вернуть)
SELECT px.group_id, COUNT(*) AS links
FROM dbo.procedurex px
WHERE NOT EXISTS (SELECT 1 FROM dbo.procgroups g WHERE g.id = px.group_id)
GROUP BY px.group_id
ORDER BY px.group_id;
GO

/* ---------- 2. ВОССТАНОВЛЕНИЕ ГРУПП ---------- */
BEGIN TRAN;

SET IDENTITY_INSERT dbo.procgroups ON;

INSERT INTO dbo.procgroups (id, code, name, descr)
SELECT v.id, v.code, v.name, v.descr
FROM (VALUES
(1, N'G1', N'Инъекционка', N'Инъекционка'),
(2, N'G2', N'Микроигольчатый РФ', N'Микроигольчатый РФ'),
(3, N'G3', N'Пилинг', N'Пилинг'),
(4, N'G4', N'Контурная пластика', N'Контурная пластика'),
(5, N'G5', N'Лечение купероза  и пигментации', N'Лечение купероза  и пигментации'),
(6, N'G6', N'лазерной шлифовка', N'лазерной шлифовка'),
(7, N'G7', N'удаление новообразований', N'удаление новообразований'),
(8, N'G8', N'Чистка лица', N'Чистка лица'),
(9, N'G9', N'плазмотерапии', N'плазмотерапии'),
(10, N'G10', N'Тело (PW8)', N'Тело (PW8)'),
(11, N'G11', N'LPG (PW16)', N'LPG (PW16)'),
(12, N'G12', N'Обертывание (PW17)', N'Обертывание (PW17)'),
(13, N'G13', N'Лицо (PW11)', N'Лицо (PW11)'),
(14, N'G14', N'Массаж (PW14)', N'Массаж (PW14)'),
(15, N'G15', N'лазерная эпиляция', N'лазерная эпиляция'),
(16, N'G16', N'Ботулинотерапия', N'Ботулинотерапия'),
(17, N'G17', N'Мезотерапия', N'Мезотерапия'),
(19, N'IW3', N'IW3', NULL),
(20, N'IW6', N'IW6', NULL),
(21, N'IW7', N'IW7', NULL),
(22, N'IW9', N'IW9', NULL),
(23, N'IW11', N'IW11', NULL),
(24, N'IW12', N'IW12', NULL),
(25, N'IW13', N'IW13', NULL),
(26, N'PW2', N'PW2', NULL),
(27, N'PW3', N'PW3', NULL),
(28, N'PW4', N'PW4', NULL),
(29, N'PW5', N'PW5', NULL),
(30, N'PW5.1', N'PW5.1', NULL),
(31, N'PW5.2', N'PW5.2', NULL),
(32, N'PW6', N'PW6', NULL),
(33, N'PW8', N'PW8', NULL),
(34, N'PW11', N'PW11', NULL),
(35, N'PW12', N'PW12', NULL),
(36, N'PW14', N'PW14', NULL),
(37, N'PW15', N'PW15', NULL),
(38, N'PW16', N'PW16', NULL),
(39, N'PW17', N'PW17', NULL)
) AS v(id, code, name, descr)
WHERE NOT EXISTS (SELECT 1 FROM dbo.procgroups g WHERE g.id = v.id);

SET IDENTITY_INSERT dbo.procgroups OFF;

DECLARE @n INT;
SELECT @n = COUNT(*) FROM dbo.procgroups;
IF @n < 38
BEGIN
    PRINT '!!! групп меньше 38 — откат';
    ROLLBACK TRAN;
END
ELSE
BEGIN
    PRINT 'procgroups: восстановлено, всего групп ' + CAST(@n AS VARCHAR(10));
    COMMIT TRAN;
END
GO

/* ---------- 3. КОНТРОЛЬ: сверка с выгрузкой ---------- */
WITH expected(group_id, code, cnt) AS (
    SELECT * FROM (VALUES
        (1, N'G1', 64),
        (2, N'G2', 14),
        (3, N'G3', 3),
        (4, N'G4', 33),
        (5, N'G5', 18),
        (6, N'G6', 26),
        (7, N'G7', 17),
        (8, N'G8', 2),
        (9, N'G9', 3),
        (10, N'G10', 20),
        (11, N'G11', 6),
        (12, N'G12', 9),
        (13, N'G13', 31),
        (14, N'G14', 12),
        (15, N'G15', 37),
        (16, N'G16', 5),
        (17, N'G17', 7),
        (19, N'IW3', 71),
        (20, N'IW6', 18),
        (21, N'IW7', 27),
        (22, N'IW9', 32),
        (23, N'IW11', 5),
        (24, N'IW12', 2),
        (25, N'IW13', 3),
        (26, N'PW2', 76),
        (27, N'PW3', 3),
        (28, N'PW4', 2),
        (29, N'PW5', 32),
        (30, N'PW5.1', 32),
        (31, N'PW5.2', 32),
        (32, N'PW6', 11),
        (33, N'PW8', 18),
        (34, N'PW11', 30),
        (35, N'PW12', 19),
        (36, N'PW14', 12),
        (37, N'PW15', 12),
        (38, N'PW16', 5),
        (39, N'PW17', 9)
    ) AS v(group_id, code, cnt)
)
SELECT e.group_id, e.code, g.name, e.cnt AS links_expected,
       ISNULL(a.cnt, 0) AS links_now,
       ISNULL(a.cnt, 0) - e.cnt AS diff
FROM expected e
LEFT JOIN dbo.procgroups g ON g.id = e.group_id
LEFT JOIN (SELECT group_id, COUNT(*) AS cnt FROM dbo.procedurex GROUP BY group_id) a
       ON a.group_id = e.group_id
ORDER BY e.group_id;
GO
/* diff должен быть 0 по всем строкам, links_now = links_expected.
   Сверка имеет смысл, когда procedurex уже восстановлена: если в разделе 1
   links_now = 0, сначала выполните restore_procedurex_2523.sql, потом этот запрос. */

/* ---------- 4. Если связки тоже пропали ----------
   Если links_now в разделе 1 = 0, значит DELETE ушёл каскадом и procedurex очищена.
   Тогда после восстановления групп выполните restore_procedurex_2523.sql.
   ---------------------------------------------------------------------------- */
