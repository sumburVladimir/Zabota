/* ============================================================================
   03_find_by_name.sql — поиск по базе: имена объектов, колонки, код
   ----------------------------------------------------------------------------
   Самый полезный скрипт на незнакомой базе.
   Ищем в трёх местах: названия объектов, названия колонок, текст вьюх/процедур.
   В третьем — показываем кусок кода вокруг совпадения, это обычно и есть ответ.

   Настройка: список слов ниже. Держи 2-4 слова за раз, иначе будет шум.
   Права    : db_datareader (на текст модулей прав хватает у db_datareader)
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @Patterns TABLE (p nvarchar(100) PRIMARY KEY);
INSERT INTO @Patterns (p) VALUES
    (N'врач'),
    (N'doctor'),
    (N'запис');

/* --- 1. Совпадения в названиях объектов ----------------------------------- */
SELECT DISTINCT
    'объект'                AS [где],
    o.type_desc             AS [тип],
    sch.name + '.' + o.name AS [имя],
    ''                      AS [деталь]
FROM sys.objects o
JOIN sys.schemas sch ON sch.schema_id = o.schema_id
CROSS JOIN @Patterns pt
WHERE o.is_ms_shipped = 0
  AND o.type IN ('U', 'V', 'P', 'FN', 'IF', 'TF')
  AND o.name LIKE '%' + pt.p + '%'
ORDER BY [имя];

/* --- 2. Совпадения в таблицах и колонках ---------------------------------- */
SELECT DISTINCT
    'колонка'                              AS [где],
    TYPE_NAME(c.user_type_id)              AS [тип],
    sch.name + '.' + t.name                AS [имя],
    c.name                                 AS [деталь]
FROM sys.columns c
JOIN sys.tables t     ON t.object_id = c.object_id
JOIN sys.schemas sch  ON sch.schema_id = t.schema_id
CROSS JOIN @Patterns pt
WHERE t.name LIKE '%' + pt.p + '%'
   OR c.name LIKE '%' + pt.p + '%'
ORDER BY [имя], [деталь];

/* --- 3. Совпадения в коде (вьюхи, процедуры, функции) --------------------- */
/* Здесь чаще всего и живёт кастомная логика: вьюха с врачом, процедура отбора. */
SELECT DISTINCT
    'код'                       AS [где],
    o.type_desc                 AS [тип],
    sch.name + '.' + o.name     AS [имя],
    s.snippet                   AS [деталь]
FROM sys.sql_modules m
JOIN sys.objects o    ON o.object_id = m.object_id
JOIN sys.schemas sch  ON sch.schema_id = o.schema_id
CROSS APPLY (SELECT CAST(m.definition AS nvarchar(max)) AS def) d
CROSS JOIN @Patterns pt
CROSS APPLY (
    SELECT CASE WHEN CHARINDEX(pt.p, d.def) = 0 THEN NULL
                ELSE SUBSTRING(d.def,
                               CASE WHEN CHARINDEX(pt.p, d.def) - 90 < 1
                                    THEN 1
                                    ELSE CHARINDEX(pt.p, d.def) - 90 END,
                               200)
           END AS snippet
) s
WHERE s.snippet IS NOT NULL
ORDER BY [имя];
