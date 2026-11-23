/* ============================================================================
   01_schema_map.sql — карта базы: таблицы, размер, строки, даты создания
   ----------------------------------------------------------------------------
   Где запускать : любая клиентская база Заботы (wellness_new / wellness / ...)
   Права         : db_datareader
   Результат     : 2 набора — таблицы (по размеру) и сводка по базе
   Что делать    : скопировать оба набора в чат «как есть»
   ============================================================================ */
SET NOCOUNT ON;

/* --- 1. Таблицы ------------------------------------------------------------ */
SELECT
    sch.name                                              AS [схема],
    t.name                                                AS [таблица],
    SUM(p.rows)                                           AS [строк],
    CAST(SUM(a.total_pages) * 8.0 / 1024 AS decimal(12,1)) AS [мб],
    CONVERT(varchar(10), o.create_date, 104)              AS [создана],
    CONVERT(varchar(10), o.modify_date, 104)              AS [изменена]
FROM sys.tables t
JOIN sys.schemas sch  ON sch.schema_id = t.schema_id
JOIN sys.objects o    ON o.object_id   = t.object_id
JOIN sys.indexes i    ON i.object_id   = t.object_id AND i.index_id IN (0, 1)
JOIN sys.partitions p ON p.object_id   = t.object_id AND p.index_id = i.index_id
LEFT JOIN sys.allocation_units a
       ON a.container_id = p.partition_id AND a.type IN (1, 3)
GROUP BY sch.name, t.name, o.create_date, o.modify_date
ORDER BY [мб] DESC, [таблица];

/* --- 2. Сводка ------------------------------------------------------------- */
/* «Самый старый объект» ~= дата установки/создания базы.
   Всё, что создано заметно позже — обновления или кастом.                       */
SELECT
    COUNT(*)                                                    AS [таблиц],
    SUM(CASE WHEN o.is_ms_shipped = 1 THEN 1 ELSE 0 END)         AS [помечено штатными],
    CONVERT(varchar(10), MIN(o.create_date), 104)                AS [самый старый объект],
    CONVERT(varchar(10), MAX(o.create_date), 104)                AS [самый новый объект]
FROM sys.tables t
JOIN sys.objects o ON o.object_id = t.object_id;
