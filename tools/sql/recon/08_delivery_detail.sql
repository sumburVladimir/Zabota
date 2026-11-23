/* ============================================================================
   08_delivery_detail.sql — один сценарий целиком: отбор, параметры, соседи
   ----------------------------------------------------------------------------
   Вписать delivery_id в @DeliveryID и выполнить.
   Выводит: шапку, полный текст отбора (Expression), параметры,
            и все ДРУГИЕ сценарии, которые сидят на том же условии.

   Права: db_datareader
   ============================================================================ */
SET NOCOUNT ON;

DECLARE @DeliveryID int = 509;   /* <<< сюда delivery_id */

IF NOT EXISTS (SELECT 1 FROM dbo.deliveries WHERE delivery_id = @DeliveryID)
BEGIN
    SELECT N'Сценарий ' + CAST(@DeliveryID AS nvarchar(20)) + N' не найден.'
           AS [примечание];
END
ELSE
BEGIN
    DECLARE @UniKey varchar(50) = (SELECT Uni_key FROM dbo.deliveries
                                    WHERE delivery_id = @DeliveryID);

    /* --- 1. Шапка --------------------------------------------------------- */
    SELECT
        d.delivery_id                      AS [ID],
        d.dname                            AS [название],
        d.delivery_type                    AS [тип],
        CASE WHEN d.dactive = 1 THEN 'вкл' ELSE '' END AS [активен],
        d.code                             AS [код],
        c.Id                               AS [условие],
        c.Name                             AS [имя условия],
        CONVERT(varchar(10), d.modified, 104) AS [изменён]
    FROM deliveries d
    LEFT JOIN deliv_conditions c ON c.Uni_key = d.Uni_key
    WHERE d.delivery_id = @DeliveryID;

    /* --- 2. Полный текст отбора ------------------------------------------- */
    /* Именно здесь обычно зашиты списки врачей: doctor_id in (...) / not in (...) */
    SELECT
        c.Id                          AS [условие],
        CAST(c.Expression AS varchar(max)) AS [отбор],
        c.QueryDescription            AS [описание]
    FROM deliv_conditions c
    WHERE c.Uni_key = @UniKey;

    /* --- 3. Параметры ----------------------------------------------------- */
    SELECT
        p.Id             AS [ID],
        p.Name           AS [параметр],
        p.Value          AS [значение],
        p.Value2         AS [значение 2],
        p.delivery_id    AS [сценарий],
        p.Note           AS [примечание]
    FROM deliv_params p
    WHERE p.delivery_id = @DeliveryID
       OR (p.delivery_id IS NULL AND p.Uni_key = @UniKey)
    ORDER BY p.order_number, p.Id;

    /* --- 4. Соседи: кто ещё использует это же условие --------------------- */
    /* Правка отбора затронет их всех — смотри внимательно.                   */
    SELECT
        d.delivery_id                                   AS [ID],
        d.dname                                         AS [название],
        CASE WHEN d.dactive = 1 THEN 'вкл' ELSE '' END  AS [активен],
        CASE WHEN d.delivery_id = @DeliveryID THEN 'этот' ELSE '' END AS [кто]
    FROM deliveries d
    WHERE d.Uni_key = @UniKey
      AND ISNULL(d.deleted, 0) = 0
    ORDER BY d.delivery_id;
END
