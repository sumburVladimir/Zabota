/* ============================================================================
   05_live_tables.sql — какие таблицы реально живут (а какие мёртвый кастом)
   ----------------------------------------------------------------------------
   Идея: у кастомных таблиц часто остаётся пустая шелуха от прошлых внедрений.
   Смотрим активность записи и чтения + счётчики identity.

   Важно: статистика активности обнуляется при перезапуске SQL Server,
   поэтому «давно» может означать «сервер недавно перезапускали».

   Права: db_datareader; блок 1 дополнительно требует VIEW DATABASE STATE
          (если права нет — скрипт об этом скажет и пойдёт дальше).
   ============================================================================ */
SET NOCOUNT ON;

/* --- 1. Активность с момента старта SQL Server ----------------------------- */
IF HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW DATABASE STATE') = 0
BEGIN
    SELECT N'Нет права VIEW DATABASE STATE — блок активности пропущен. Смотри блок 2.'
           AS [примечание];
END
ELSE IF NOT EXISTS (SELECT 1 FROM sys.dm_db_index_usage_stats WHERE database_id = DB_ID())
BEGIN
    SELECT N'Статистика активности пуста: сервер недавно перезапускали или база с AUTO_CLOSE. Смотри блок 2.'
           AS [примечание];
END
ELSE
BEGIN
    SELECT TOP (100)
        OBJECT_SCHEMA_NAME(s.object_id) + '.' + OBJECT_NAME(s.object_id) AS [таблица],
        CONVERT(varchar(19), MAX(s.last_user_update), 120)              AS [последняя запись],
        CONVERT(varchar(19), MAX(s.last_user_seek), 120)                AS [последнее чтение],
        SUM(s.user_updates)                                             AS [записей с старта],
        SUM(s.user_seeks + s.user_scans + s.user_lookups)               AS [чтений с старта]
    FROM sys.dm_db_index_usage_stats s
    WHERE s.database_id = DB_ID()
      AND OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
    GROUP BY s.object_id
    ORDER BY MAX(s.last_user_update) DESC;
END

/* --- 2. Счётчики identity: где реально набиваются строки ------------------- */
SELECT
    sch.name + '.' + t.name                       AS [таблица],
    ic.name                                        AS [колонка],
    CONVERT(bigint, ic.last_value)                 AS [последний id],
    (SELECT SUM(p.rows) FROM sys.partitions p
      WHERE p.object_id = t.object_id AND p.index_id IN (0, 1)) AS [строк]
FROM sys.identity_columns ic
JOIN sys.tables t    ON t.object_id = ic.object_id
JOIN sys.schemas sch ON sch.schema_id = t.schema_id
ORDER BY CONVERT(bigint, ic.last_value) DESC;

/* --- 3. Точечная проверка «свежести» одной таблицы ------------------------ */
/* Раскомментируй и впиши таблицу + колонку с датой, если нужно точно знать,
   когда в неё последний раз писали. На больших таблицах это скан — осторожно. */
/*
DECLARE @Sql nvarchar(max) = N'SELECT MAX([дата]) AS [последняя запись] FROM [dbo].[таблица]';
EXEC sp_executesql @Sql;
*/
