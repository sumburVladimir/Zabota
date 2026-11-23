/* ============================================================================
   02_object_inventory.sql — инвентарь объектов базы (для сравнения с эталоном)
   ----------------------------------------------------------------------------
   Зачем: кастом проще всего найти сравнением с чистой базой.
          1) запустить на эталоне (wellness_new)      -> сохранить в sterile.txt
          2) запустить на клиенте                     -> сохранить в client.txt
          3) python tools/schema_diff.py sterile.txt client.txt
   Права : db_datareader
   ============================================================================ */
SET NOCOUNT ON;

/* --- 1. Полный список объектов: одна колонка, удобно сравнивать ------------ */
SELECT sch.name + '.' + o.name AS [объект]
FROM sys.objects o
JOIN sys.schemas sch ON sch.schema_id = o.schema_id
WHERE o.is_ms_shipped = 0
  AND o.type IN ('U', 'V', 'P', 'FN', 'IF', 'TF', 'TR', 'SN')
ORDER BY 1;

/* --- 2. Сколько чего ------------------------------------------------------- */
SELECT
    CASE o.type
         WHEN 'U'  THEN 'таблица'
         WHEN 'V'  THEN 'вьюха'
         WHEN 'P'  THEN 'процедура'
         WHEN 'FN' THEN 'функция'
         WHEN 'IF' THEN 'функция (inline)'
         WHEN 'TF' THEN 'функция (table)'
         WHEN 'TR' THEN 'триггер'
         WHEN 'SN' THEN 'синоним'
    END                     AS [тип],
    COUNT(*)                AS [штук]
FROM sys.objects o
WHERE o.is_ms_shipped = 0
  AND o.type IN ('U', 'V', 'P', 'FN', 'IF', 'TF', 'TR', 'SN')
GROUP BY o.type
ORDER BY [штук] DESC;

/* --- 3. Волны создания: когда что появлялось ------------------------------- */
/* Установка, обновления, ручные доработки — видно по месяцам.                  */
SELECT
    CONVERT(varchar(7), o.create_date, 120) AS [месяц],
    COUNT(*)                                AS [объектов]
FROM sys.objects o
WHERE o.is_ms_shipped = 0
  AND o.type IN ('U', 'V', 'P', 'FN', 'IF', 'TF')
GROUP BY CONVERT(varchar(7), o.create_date, 120)
ORDER BY [месяц] DESC;
