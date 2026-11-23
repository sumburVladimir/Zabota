/* ============================================================================
   00_snapshot_for_agent.sql — Единый срез базы клиники в буфер обмена (без CSV)
   ----------------------------------------------------------------------------
   КАК ПОЛЬЗОВАТЬСЯ В SSMS НА ПК КЛИНИКИ:
   1. Выберите режим в блоке НАСТРОЙКИ ниже (по умолчанию — общий срез сценариев).
   2. Нажмите F5.
   3. В таблице результатов кликните в левый верхний пустой квадратик (Ctrl+A -> Ctrl+C).
   4. Скажите агенту в чате: "срез в буфере, клиника <ID>".

   ШПАРГАЛКА ПО РЕЖИМАМ:
   - Режим А (Аудит/создание сценариев по брифу): ничего не менять, просто F5.
   - Режим Б (Почему пациенту не ушло сообщение / кривая карточка):
       вписать в @PatientSearch фамилию, телефон, карту или Patient_Id (например: N'Иванов').
   - Режим В (Разбор конкретного сценария и его последних отправок/ошибок):
       вписать в @DeliveryID номер сценария (например: 509).
   ============================================================================ */
SET NOCOUNT ON;

/* ============================ НАСТРОЙКИ СРЕЗА ============================ */
DECLARE @PatientSearch        nvarchar(100) = NULL; -- Поиск пациента: ФИО, телефон, карта или ID (NULL = не искать)
DECLARE @DeliveryID           int           = NULL; -- Разбор одного сценария и его логов отправки (NULL = все)
DECLARE @DaysBack             int           = 14;   -- За сколько дней брать логи deliv_orders/messages для @DeliveryID
DECLARE @Filter               nvarchar(100) = NULL; -- Фильтр сценариев по коду/названию (например N'PW%'), NULL = все
DECLARE @IncludeAllProcedures bit           = 1;    -- 1 = весь справочник услуг, 0 = только услуги из групп/пациента
/* ========================================================================= */

-- Собираем найденных пациентов во временную таблицу (до 50 человек, чтобы не перегрузить буфер)
IF OBJECT_ID('tempdb..#TargetPatients') IS NOT NULL DROP TABLE #TargetPatients;
CREATE TABLE #TargetPatients (Patient_Id int PRIMARY KEY);

IF @PatientSearch IS NOT NULL AND LTRIM(RTRIM(@PatientSearch)) <> N''
BEGIN
    DECLARE @q nvarchar(100) = LTRIM(RTRIM(@PatientSearch));
    INSERT INTO #TargetPatients (Patient_Id)
    SELECT TOP 50 p.Patient_Id
    FROM dbo.patients p
    WHERE (TRY_CAST(@q AS int) IS NOT NULL AND p.Patient_Id = TRY_CAST(@q AS int))
       OR p.Surname LIKE N'%' + @q + N'%'
       OR (ISNULL(p.Surname, N'') + N' ' + ISNULL(p.Firstname, N'') + N' ' + ISNULL(p.Midname, N'')) LIKE N'%' + @q + N'%'
       OR p.Cellphone LIKE N'%' + @q + N'%'
       OR p.Card LIKE N'%' + @q + N'%'
    ORDER BY p.Patient_Id DESC;
END

SELECT [line]
FROM (
    /* 1. МЕТАДАННЫЕ БАЗЫ И СХЕМА ТАБЛИЦ (включая кастомные колонки клиники) */
    SELECT 1 AS [ord], 0 AS [sub],
           N'=== [META] DB=' + DB_NAME() + N' | Server=' + @@SERVERNAME
           + N' | Date=' + CONVERT(nvarchar(19), GETDATE(), 120)
           + N' | PatientSearch=' + ISNULL(@PatientSearch, N'NULL')
           + N' | DeliveryID=' + ISNULL(CAST(@DeliveryID AS nvarchar(20)), N'NULL')
           + N' ===' AS [line]

    UNION ALL
    SELECT 2, ROW_NUMBER() OVER (ORDER BY t.name, c.column_id),
           N'SCHEMA|' + t.name
           + N'|' + c.name
           + N'|' + tp.name
           + N'|' + CAST(c.max_length AS nvarchar(10))
           + N'|' + CAST(c.precision AS nvarchar(10))
           + N'|' + CAST(c.scale AS nvarchar(10))
           + N'|' + CAST(c.is_nullable AS nvarchar(2))
           + N'|' + CAST(c.is_computed AS nvarchar(2))
    FROM sys.tables t
    JOIN sys.columns c ON c.object_id = t.object_id
    JOIN sys.types tp  ON tp.user_type_id = c.user_type_id
    WHERE t.schema_id = SCHEMA_ID('dbo')

    /* 2. СЦЕНАРИИ (deliveries) */
    UNION ALL SELECT 3, 0, N'=== [DELIVERIES] id|code|active|deleted|type|uni_key|parent_id|name ==='
    UNION ALL
    SELECT 4, d.delivery_id,
           N'DELIV|' + CAST(d.delivery_id AS nvarchar(20))
           + N'|' + ISNULL(RTRIM(d.code), N'')
           + N'|' + CAST(ISNULL(d.dactive, 0) AS nvarchar(5))
           + N'|' + CAST(ISNULL(d.deleted, 0) AS nvarchar(5))
           + N'|' + CAST(ISNULL(d.delivery_type, 0) AS nvarchar(10))
           + N'|' + ISNULL(d.Uni_key, N'')
           + N'|' + ISNULL(CAST(d.Parent_id AS nvarchar(20)), N'')
           + N'|' + ISNULL(REPLACE(REPLACE(REPLACE(d.dname, N'|', N'/'), CHAR(13), N' '), CHAR(10), N' '), N'')
    FROM dbo.deliveries d
    WHERE ISNULL(d.deleted, 0) = 0
      AND (@Filter IS NULL OR d.code LIKE @Filter OR d.dname LIKE @Filter)
      AND (@DeliveryID IS NULL OR d.delivery_id = @DeliveryID)

    /* 3. ПАРАМЕТРЫ СЦЕНАРИЕВ (deliv_params) */
    UNION ALL SELECT 5, 0, N'=== [DELIV_PARAMS] id|delivery_id|uni_key|name|value|value2 ==='
    UNION ALL
    SELECT 6, p.Id,
           N'PARAM|' + CAST(p.Id AS nvarchar(20))
           + N'|' + ISNULL(CAST(p.delivery_id AS nvarchar(20)), N'')
           + N'|' + ISNULL(p.Uni_key, N'')
           + N'|' + ISNULL(REPLACE(p.Name, N'|', N'/'), N'')
           + N'|' + ISNULL(REPLACE(REPLACE(REPLACE(CAST(p.Value AS nvarchar(max)), N'|', N'/'), CHAR(13), N' '), CHAR(10), N' '), N'')
           + N'|' + ISNULL(REPLACE(REPLACE(REPLACE(CAST(p.Value2 AS nvarchar(max)), N'|', N'/'), CHAR(13), N' '), CHAR(10), N' '), N'')
    FROM dbo.deliv_params p

    /* 4. СЕГМЕНТЫ / УСЛОВИЯ ОТБОРА (deliv_conditions) */
    UNION ALL SELECT 7, 0, N'=== [DELIV_CONDITIONS] id|uni_key|type|has_saved_code|name|expression ==='
    UNION ALL
    SELECT 8, c.Id,
           N'COND|' + CAST(c.Id AS nvarchar(20))
           + N'|' + ISNULL(c.Uni_key, N'')
           + N'|' + CAST(ISNULL(c.Condition_Type, 0) AS nvarchar(5))
           + N'|' + CASE WHEN c.saved_code IS NOT NULL AND DATALENGTH(c.saved_code) > 2 THEN N'1' ELSE N'0' END
           + N'|' + ISNULL(REPLACE(REPLACE(REPLACE(c.Name, N'|', N'/'), CHAR(13), N' '), CHAR(10), N' '), N'')
           + N'|' + ISNULL(REPLACE(REPLACE(REPLACE(CAST(c.Expression AS nvarchar(max)), N'|', N'{{PIPE}}'), CHAR(13), N' '), CHAR(10), N' {{NL}} '), N'')
    FROM dbo.deliv_conditions c

    /* 5. ГРУППЫ ПРОЦЕДУР И СОСТАВ ГРУПП (procgroups + procedurex) */
    UNION ALL SELECT 9, 0, N'=== [PROCGROUPS] id|code|name|descr ==='
    UNION ALL
    SELECT 10, g.id,
           N'GRP|' + CAST(g.id AS nvarchar(20))
           + N'|' + ISNULL(RTRIM(g.code), N'')
           + N'|' + ISNULL(REPLACE(REPLACE(REPLACE(g.name, N'|', N'/'), CHAR(13), N' '), CHAR(10), N' '), N'')
           + N'|' + ISNULL(REPLACE(REPLACE(REPLACE(g.descr, N'|', N'/'), CHAR(13), N' '), CHAR(10), N' '), N'')
    FROM dbo.procgroups g

    UNION ALL SELECT 11, 0, N'=== [PROCEDUREX] id|group_id|proc_id|exclude|code ==='
    UNION ALL
    SELECT 12, px.id,
           N'GRP_PROC|' + CAST(px.id AS nvarchar(20))
           + N'|' + CAST(ISNULL(px.group_id, 0) AS nvarchar(20))
           + N'|' + CAST(ISNULL(px.proc_id, 0) AS nvarchar(20))
           + N'|' + CAST(ISNULL(px.exclude, 0) AS nvarchar(5))
           + N'|' + ISNULL(RTRIM(px.code), N'')
    FROM dbo.procedurex px

    /* 6. ВРАЧИ (doctors) */
    UNION ALL SELECT 13, 0, N'=== [DOCTORS] id|fullname ==='
    UNION ALL
    SELECT 14, doc.Doctor_ID,
           N'DOC|' + CAST(doc.Doctor_ID AS nvarchar(20))
           + N'|' + ISNULL(REPLACE(REPLACE(REPLACE(
               ISNULL(doc.FullName, ISNULL(doc.Surname, N'') + N' ' + ISNULL(doc.Firstname, N'')),
               N'|', N'/'), CHAR(13), N' '), CHAR(10), N' '), N'')
    FROM dbo.doctors doc

    /* 7. СПРАВОЧНИК УСЛУГ (procedures) */
    UNION ALL SELECT 15, 0, N'=== [PROCEDURES] id|descr ==='
    UNION ALL
    SELECT 16, pr.Procedure_id,
           N'PROC|' + CAST(pr.Procedure_id AS nvarchar(20))
           + N'|' + ISNULL(REPLACE(REPLACE(CAST(pr.Descr AS nvarchar(max)), CHAR(13), N' '), CHAR(10), N' '), N'')
    FROM dbo.procedures pr
    WHERE @IncludeAllProcedures = 1
       OR EXISTS (SELECT 1 FROM dbo.procedurex px WHERE px.proc_id = pr.Procedure_id)
       OR EXISTS (SELECT 1 FROM dbo.patients_visits pv JOIN #TargetPatients tp ON tp.Patient_Id = pv.Patient_Id WHERE pv.Procedure_id = pr.Procedure_id)
       OR EXISTS (SELECT 1 FROM dbo.patients_treatment pt JOIN #TargetPatients tp ON tp.Patient_Id = pt.Patient_id WHERE pt.Procedure_id = pr.Procedure_id)

    /* 8. РАССЛЕДОВАНИЕ ПО ПАЦИЕНТАМ И ЛОГАМ СООБЩЕНИЙ (активируется при @PatientSearch или @DeliveryID) */
    UNION ALL SELECT 17, 0, N'=== [INVESTIGATION_ROWS] table|json_row ==='

    -- 8.1 Карточки найденных пациентов (все поля, включая кастом!)
    UNION ALL
    SELECT 18, p.Patient_Id,
           N'ROW|patients|' + (SELECT p.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
    FROM dbo.patients p
    JOIN #TargetPatients tp ON tp.Patient_Id = p.Patient_Id

    -- 8.2 Визиты найденных пациентов (patients_visits)
    UNION ALL
    SELECT 19, pv_sub.Visit_Id, pv_sub.[line]
    FROM (
        SELECT TOP 300 pv.Visit_Id,
               N'ROW|patients_visits|' + (SELECT pv.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS [line]
        FROM dbo.patients_visits pv
        JOIN #TargetPatients tp ON tp.Patient_Id = pv.Patient_Id
        ORDER BY pv.Visit_Id DESC
    ) AS pv_sub

    -- 8.3 Оказанные услуги найденных пациентов (patients_treatment)
    UNION ALL
    SELECT 20, pt_sub.Treatment_id, pt_sub.[line]
    FROM (
        SELECT TOP 300 pt.Treatment_id,
               N'ROW|patients_treatment|' + (SELECT pt.* FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS [line]
        FROM dbo.patients_treatment pt
        JOIN #TargetPatients tp ON tp.Patient_Id = pt.Patient_id
        ORDER BY pt.Treatment_id DESC
    ) AS pt_sub

    -- 8.4 Сообщения (messages) по найденным пациентам ИЛИ по @DeliveryID за последние @DaysBack дней
    UNION ALL
    SELECT 21, m_sub.Message_id, m_sub.[line]
    FROM (
        SELECT TOP 300 m.Message_id,
               N'ROW|messages|' + (
                   SELECT m.Message_id, m.Order_id, m.Patient_id, m.sent, m.Message_type,
                          m.Message_state, m.Subject,
                          LEFT(CAST(m.Message_Text AS nvarchar(max)), 2000) AS Message_Text,
                          m.Contact_info, m.Retry, m.Err_code,
                          LEFT(CAST(m.Err_msg AS nvarchar(max)), 1000) AS Err_msg,
                          m.Appoint_Id, m.retry_dt, m.card, m.modified, m.doctor_id, m.Context_md5
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
               ) AS [line]
        FROM dbo.messages m
        WHERE m.Patient_id IN (SELECT Patient_Id FROM #TargetPatients)
           OR (
               @DeliveryID IS NOT NULL
               AND m.Order_id IN (
                   SELECT TOP 100 o.Order_id
                   FROM dbo.deliv_orders o
                   WHERE o.Delivery_id = @DeliveryID
                     AND o.Created >= DATEADD(DAY, -@DaysBack, GETDATE())
                   ORDER BY o.Order_id DESC
               )
           )
        ORDER BY m.Message_id DESC
    ) AS m_sub

    -- 8.5 Задания на отправку (deliv_orders) по сообщениям пациента ИЛИ по @DeliveryID
    UNION ALL
    SELECT 22, o_sub.Order_id, o_sub.[line]
    FROM (
        SELECT TOP 100 o.Order_id,
               N'ROW|deliv_orders|' + (
                   SELECT o.Order_id, o.Created, o.Delivery_id, o.Delivery_dt, o.Order_state,
                          o.Patientcount,
                          LEFT(CAST(o.Response AS nvarchar(max)), 2000) AS Response,
                          o.Errorcount, o.Err_code,
                          LEFT(CAST(o.Err_msg AS nvarchar(max)), 1000) AS Err_msg,
                          o.modified
                   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
               ) AS [line]
        FROM dbo.deliv_orders o
        WHERE (
            @DeliveryID IS NOT NULL
            AND o.Delivery_id = @DeliveryID
            AND o.Created >= DATEADD(DAY, -@DaysBack, GETDATE())
        )
        OR o.Order_id IN (
            SELECT DISTINCT m2.Order_id
            FROM dbo.messages m2
            JOIN #TargetPatients tp ON tp.Patient_Id = m2.Patient_id
            WHERE m2.Order_id IS NOT NULL
        )
        ORDER BY o.Order_id DESC
    ) AS o_sub
) AS snap
ORDER BY [ord], [sub];
