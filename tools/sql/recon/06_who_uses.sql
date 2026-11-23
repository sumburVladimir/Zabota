/* ============================================================================
   06_who_uses.sql — кто использует объект: точные зависимости + поиск по коду
   ----------------------------------------------------------------------------
   Вписать имя объекта (таблицы/вьюхи) в @Obj — без схемы.
   Показывает: точные ссылки по sys.sql_expression_dependencies,
               совпадения в тексте модулей, внешние ключи.
   Права: db_datareader
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @Obj sysname = N'deliveries';   /* <<< сюда имя */

/* --- 1. Точные зависимости (кто ссылается на объект) ---------------------- */
SELECT DISTINCT
    o.type_desc                 AS [тип],
    sch.name + '.' + o.name     AS [объект],
    'точная ссылка'             AS [как связано]
FROM sys.sql_expression_dependencies d
JOIN sys.objects o   ON o.object_id = d.referencing_id
JOIN sys.schemas sch ON sch.schema_id = o.schema_id
WHERE d.referenced_entity_name = @Obj

UNION ALL

/* --- 2. Поиск по тексту кода (ловит и динамический SQL) ------------------- */
SELECT DISTINCT
    o.type_desc,
    sch.name + '.' + o.name,
    'упоминание в коде'
FROM sys.sql_modules m
JOIN sys.objects o   ON o.object_id = m.object_id
JOIN sys.schemas sch ON sch.schema_id = o.schema_id
WHERE CAST(m.definition AS nvarchar(max)) LIKE '%' + @Obj + '%'

ORDER BY [как связано], [объект];

/* --- 3. Внешние ключи ----------------------------------------------------- */
SELECT
    'исходящий'  AS [направление],
    OBJECT_SCHEMA_NAME(fk.parent_object_id) + '.' + OBJECT_NAME(fk.parent_object_id) AS [откуда],
    fk.name      AS [ключ],
    OBJECT_SCHEMA_NAME(fk.referenced_object_id) + '.' + OBJECT_NAME(fk.referenced_object_id) AS [куда]
FROM sys.foreign_keys fk
WHERE OBJECT_NAME(fk.parent_object_id) = @Obj
UNION ALL
SELECT
    'входящий',
    OBJECT_SCHEMA_NAME(fk.parent_object_id) + '.' + OBJECT_NAME(fk.parent_object_id),
    fk.name,
    OBJECT_SCHEMA_NAME(fk.referenced_object_id) + '.' + OBJECT_NAME(fk.referenced_object_id)
FROM sys.foreign_keys fk
WHERE OBJECT_NAME(fk.referenced_object_id) = @Obj;
