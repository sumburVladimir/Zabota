/* ============================================================================
   07_deliveries.sql — все сценарии рассылок: связка сценарий -> условие отбора
   ----------------------------------------------------------------------------
   Важная особенность Заботы: условия (deliv_conditions) крепятся к сценарию
   через Uni_key, и ОДНО условие может обслуживать несколько сценариев.
   Поэтому правка отбора в одном сценарии меняет поведение всех его «соседей».

   Права: db_datareader
   ============================================================================ */
SET NOCOUNT ON;

IF OBJECT_ID('dbo.deliveries') IS NULL
BEGIN
    SELECT N'В базе нет dbo.deliveries — это не схема Заботы или другая версия.'
           AS [примечание];
END
ELSE
BEGIN
    SELECT
        d.delivery_id                                   AS [ID],
        d.dname                                         AS [название],
        d.delivery_type                                 AS [тип],
        CASE WHEN d.dactive = 1 THEN 'вкл' ELSE '' END  AS [активен],
        d.code                                          AS [код],
        c.Id                                            AS [условие],
        c.Name                                          AS [имя условия],
        (SELECT COUNT(*) FROM deliveries d2
          WHERE d2.Uni_key = d.Uni_key AND d2.Uni_key IS NOT NULL) AS [сценариев на условии],
        CASE WHEN CAST(c.Expression AS varchar(max)) LIKE '%doctor_id%'
             THEN 'да' ELSE '' END                      AS [врач в отборе],
        LEN(CAST(c.Expression AS varchar(max)))          AS [длина отбора],
        CONVERT(varchar(10), d.modified, 104)            AS [изменён]
    FROM deliveries d
    LEFT JOIN deliv_conditions c
           ON c.Uni_key = d.Uni_key
    WHERE ISNULL(d.deleted, 0) = 0
    ORDER BY d.delivery_id;
END
