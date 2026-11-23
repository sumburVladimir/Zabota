/* ============================================================================
   04_table_shape.sql — всё про одну таблицу: колонки, индексы, связи, кто читает
   ----------------------------------------------------------------------------
   Использование: вписать имя таблицы в @Table (без схемы) и выполнить.
   Права        : db_datareader
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @Table sysname = N'deliveries';   /* <<< сюда имя таблицы */

DECLARE @ObjId int = (
    SELECT TOP 1 t.object_id
    FROM sys.tables t
    WHERE t.name = @Table
    ORDER BY CASE WHEN SCHEMA_NAME(t.schema_id) = 'dbo' THEN 0 ELSE 1 END
);

IF @ObjId IS NULL
BEGIN
    SELECT N'Таблица ''' + @Table + N''' не найдена. Проверь имя через 03_find_by_name.sql'
           AS [примечание];
END
ELSE
BEGIN
    /* --- 1. Колонки ------------------------------------------------------- */
    SELECT
        c.column_id                                AS [№],
        c.name                                     AS [колонка],
        TYPE_NAME(c.user_type_id)                  AS [тип],
        CASE WHEN c.max_length = -1 THEN 'max'
             ELSE CAST(c.max_length AS varchar(10)) END AS [длина],
        CASE c.is_nullable WHEN 1 THEN 'NULL' ELSE 'NOT NULL' END AS [null],
        CASE WHEN c.is_identity = 1 THEN 'identity' ELSE '' END   AS [identity],
        ISNULL(dc.definition, '')                  AS [default]
    FROM sys.columns c
    LEFT JOIN sys.default_constraints dc
           ON dc.object_id = c.default_object_id
    WHERE c.object_id = @ObjId
    ORDER BY c.column_id;

    /* --- 2. Индексы ------------------------------------------------------- */
    SELECT
        i.name                                     AS [индекс],
        CASE i.type WHEN 1 THEN 'clustered'
                    WHEN 2 THEN 'nonclustered'
                    WHEN 3 THEN 'XML'
                    ELSE CAST(i.type AS varchar(10)) END AS [вид],
        CASE WHEN i.is_unique = 1 THEN 'уникальный' ELSE '' END AS [уникальный],
        STUFF((SELECT ', ' + c.name
               FROM sys.index_columns ic
               JOIN sys.columns c ON c.object_id = ic.object_id
                                 AND c.column_id = ic.column_id
               WHERE ic.object_id = i.object_id
                 AND ic.index_id  = i.index_id
               ORDER BY ic.key_ordinal
               FOR XML PATH('')), 1, 2, '')        AS [колонки]
    FROM sys.indexes i
    WHERE i.object_id = @ObjId
    ORDER BY i.index_id;

    /* --- 3. Внешние ключи (в обе стороны) --------------------------------- */
    SELECT
        'исходящий'                    AS [направление],
        OBJECT_SCHEMA_NAME(fk.parent_object_id) + '.' + OBJECT_NAME(fk.parent_object_id) AS [откуда],
        fk.name                        AS [ключ],
        OBJECT_SCHEMA_NAME(fk.referenced_object_id) + '.' + OBJECT_NAME(fk.referenced_object_id) AS [куда]
    FROM sys.foreign_keys fk
    WHERE fk.parent_object_id = @ObjId
    UNION ALL
    SELECT
        'входящий',
        OBJECT_SCHEMA_NAME(fk.parent_object_id) + '.' + OBJECT_NAME(fk.parent_object_id),
        fk.name,
        OBJECT_SCHEMA_NAME(fk.referenced_object_id) + '.' + OBJECT_NAME(fk.referenced_object_id)
    FROM sys.foreign_keys fk
    WHERE fk.referenced_object_id = @ObjId;

    /* --- 4. Кто ссылается на таблицу в коде ------------------------------- */
    SELECT DISTINCT
        o.type_desc                 AS [тип],
        sch.name + '.' + o.name     AS [объект]
    FROM sys.sql_modules m
    JOIN sys.objects o   ON o.object_id = m.object_id
    JOIN sys.schemas sch ON sch.schema_id = o.schema_id
    WHERE CAST(m.definition AS nvarchar(max)) LIKE '%' + @Table + '%'
    ORDER BY [тип], [объект];
END
