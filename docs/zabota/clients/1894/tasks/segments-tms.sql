/* ============================================================
   ID1894 «Новые Возможности» — сегменты ТМС (deliv_conditions.Expression)
   Тип условия: 1 (ручной SQL), saved_code пустой.

   Параметры PR2 подставляет сам при запуске:
     :IPAT   — сколько пациентов за прогон (для «1 сообщение каждые 17 минут» = 1)
     :ITIME1 / :ITIME2 — окно часов (9 / 19)
     :DID    — delivery_id текущего сценария

   «Приём у психиатра/психотерапевта» считается составно — как визит
   (patients_visits) ИЛИ как оказанная услуга (patients_treatment) у этих врачей:
   в базе приёмы бывают заведены и тем, и другим способом.

   Врачи (психиатр/психотерапевт):
     48  Онищенко (Дорошенко) Ольга Викторовна
     160 Сурков Владислав Сергеевич
     190 Мамай Ирма Анзоровна
     221 Дмитриева Екатерина Феликсовна
     238 Гуцан Наталья Леонидовна
     282 Бубнова Марина Александровна
     297 Привалова Наталья Андреевна
     301 Тугаринова Надежда Фастовна
     302 Савин Александр Евгеньевич
     334 Иванова Наталья Эдуардовна
     339 Янкун Диана Сергеевна
     348 Парфентьева Анастасия Дмитриевна
     351 Етоева Наталья Владимировна
     384 Назарова Кристина Викторовна
     385 Ярошевич Роман Андреевич
     393 Щербакова Татьяна Викторовна
     394 Пантелеева Татьяна Александровна
     408 Жаданова Наталья Юрьевна
     412 Корытина Екатерина Андреевна
     416 Червякова Ангелина Максимовна
   Дети дополнительно:
     295 Буйначёва Виктория Олеговна
     406 Хакназарова Анастасия Валерьевна

   Услуги ТМС: 1477 (взрослые разово), 21475 (ТМС), 23524 (дети разово)
   ============================================================ */


/* ---------- 1. ТМС для взрослых (разовая отправка) ---------- */
SELECT TOP (:IPAT) vv.* FROM (SELECT patients.* FROM vpatients patients
WHERE
    cellphone LIKE '79%'
    AND hide = 0 AND Exclude = 0
    AND age >= 18                                   /* возраст от 18 лет */

    /* было 2 и более приёма у психиатра/психотерапевта:
       визит ИЛИ оказанная услуга, даты не задваиваются (UNION) */
    AND 2 <= (
        SELECT COUNT(*) FROM (
            SELECT pv.Patient_Id, CONVERT(date, pv.Visit_date) AS d
            FROM patients_visits pv
            WHERE pv.visit_state <> 'C'
              AND pv.doctor_id IN (48,160,190,221,238,282,297,301,302,334,339,
                                   348,351,384,385,393,394,408,412,416)
            UNION
            SELECT pt.Patient_id, CONVERT(date, pt.Treatment_date)
            FROM patients_treatment pt
            WHERE pt.doctor_id IN (48,160,190,221,238,282,297,301,302,334,339,
                                   348,351,384,385,393,394,408,412,416)
        ) exams
        WHERE exams.Patient_Id = patients.patient_id
    )

    /* была получена услуга ТМС 90-720 дней назад */
    AND EXISTS (SELECT 1 FROM patients_treatment pt
         WHERE pt.Patient_id = patients.patient_id
           AND pt.Procedure_id IN (1477, 21475, 23524) /* ТМС */
           AND DATEDIFF(DAY, pt.Treatment_date, GETDATE()) BETWEEN 90 AND 720)

    /* нет записи на будущее (к любому врачу, 60 дней) */
    AND NOT EXISTS (SELECT 1 FROM patients_visits pv
         WHERE pv.Patient_Id = patients.patient_id
           AND pv.visit_state <> 'C'
           AND DATEDIFF(DAY, GETDATE(), pv.Visit_date) BETWEEN 0 AND 60)

    /* разовая отправка: этому номеру по этому сценарию уже не слали */
    AND NOT EXISTS (SELECT 1 FROM messages m
         INNER JOIN deliv_orders do ON do.Order_id = m.Order_id
         WHERE do.Delivery_id = :DID
           AND m.Contact_info = patients.cellphone)
) vv
LEFT JOIN (
    SELECT v1.patient_id FROM patients v1
    INNER JOIN patients v2 ON v2.cellphone = v1.cellphone
    WHERE v1.patient_id > v2.patient_id
) duplicatePatients ON vv.patient_id = duplicatePatients.patient_id
WHERE
    duplicatePatients.patient_id IS NULL
    AND datepart(HOUR, GETDATE()) BETWEEN :ITIME1 AND :ITIME2


/* ---------- 2. ТМС для взрослых (регулярный сценарий) ---------- */
/* Отличие от п.1: вместо «2 и более приёмов» — приём ровно 7 дней назад.
   «Нет записи на будущее» в брифе не указано — блок закомментирован;
   раскомментировать, если приглашение не должно уходить записанным.
   Ограничение повтора: не чаще 1 раза в 180 дней (уточнить у клиники). */
SELECT TOP (:IPAT) vv.* FROM (SELECT patients.* FROM vpatients patients
WHERE
    cellphone LIKE '79%'
    AND hide = 0 AND Exclude = 0
    AND age >= 18                                   /* возраст от 18 лет */

    /* приём у психиатра/психотерапевта 7 дней назад: визит ИЛИ услуга */
    AND (
        EXISTS (SELECT 1 FROM patients_visits pv
            WHERE pv.Patient_Id = patients.patient_id
              AND pv.visit_state <> 'C'
              AND DATEDIFF(DAY, pv.Visit_date, GETDATE()) = 7
              AND pv.doctor_id IN (48,160,190,221,238,282,297,301,302,334,339,
                                   348,351,384,385,393,394,408,412,416))
        OR
        EXISTS (SELECT 1 FROM patients_treatment pt
            WHERE pt.Patient_id = patients.patient_id
              AND DATEDIFF(DAY, pt.Treatment_date, GETDATE()) = 7
              AND pt.doctor_id IN (48,160,190,221,238,282,297,301,302,334,339,
                                   348,351,384,385,393,394,408,412,416))
    )

    /* была получена услуга ТМС 90-720 дней назад */
    AND EXISTS (SELECT 1 FROM patients_treatment pt
         WHERE pt.Patient_id = patients.patient_id
           AND pt.Procedure_id IN (1477, 21475, 23524) /* ТМС */
           AND DATEDIFF(DAY, pt.Treatment_date, GETDATE()) BETWEEN 90 AND 720)

    /* нет записи на будущее (к любому врачу, 60 дней) — в брифе нет
    AND NOT EXISTS (SELECT 1 FROM patients_visits pv
         WHERE pv.Patient_Id = patients.patient_id
           AND pv.visit_state <> 'C'
           AND DATEDIFF(DAY, GETDATE(), pv.Visit_date) BETWEEN 0 AND 60)
    */

    /* не чаще 1 раза в 180 дней по этому сценарию */
    AND NOT EXISTS (SELECT 1 FROM messages m
         INNER JOIN deliv_orders do ON do.Order_id = m.Order_id
         WHERE do.Delivery_id = :DID
           AND m.Contact_info = patients.cellphone
           AND DATEDIFF(DAY, do.Created, GETDATE()) <= 180)
) vv
LEFT JOIN (
    SELECT v1.patient_id FROM patients v1
    INNER JOIN patients v2 ON v2.cellphone = v1.cellphone
    WHERE v1.patient_id > v2.patient_id
) duplicatePatients ON vv.patient_id = duplicatePatients.patient_id
WHERE
    duplicatePatients.patient_id IS NULL
    AND datepart(HOUR, GETDATE()) BETWEEN :ITIME1 AND :ITIME2


/* ---------- 3. ДЕТИ 3-17 лет, анонс курса ---------- */
SELECT TOP (:IPAT) vv.* FROM (SELECT patients.* FROM vpatients patients
WHERE
    cellphone LIKE '79%'
    AND hide = 0 AND Exclude = 0
    AND age BETWEEN 3 AND 17                        /* 3-17 лет включительно */

    AND (
        /* были визиты у детского психиатра/психотерапевта/психолога за 24 мес */
        EXISTS (SELECT 1 FROM patients_visits pv
            WHERE pv.Patient_Id = patients.patient_id
              AND pv.visit_state <> 'C'
              AND DATEDIFF(DAY, pv.Visit_date, GETDATE()) BETWEEN 0 AND 730
              AND pv.doctor_id IN (48,160,190,221,238,282,295,297,301,302,334,
                                   339,348,351,384,385,393,394,406,408,412,416))
        OR
        /* ИЛИ была услуга ТМС 90-720 дней назад */
        EXISTS (SELECT 1 FROM patients_treatment pt
            WHERE pt.Patient_id = patients.patient_id
              AND pt.Procedure_id IN (1477, 21475, 23524) /* ТМС */
              AND DATEDIFF(DAY, pt.Treatment_date, GETDATE()) BETWEEN 90 AND 720)
    )

    /* разовая отправка: этому номеру по этому сценарию уже не слали */
    AND NOT EXISTS (SELECT 1 FROM messages m
         INNER JOIN deliv_orders do ON do.Order_id = m.Order_id
         WHERE do.Delivery_id = :DID
           AND m.Contact_info = patients.cellphone)
) vv
LEFT JOIN (
    SELECT v1.patient_id FROM patients v1
    INNER JOIN patients v2 ON v2.cellphone = v1.cellphone
    WHERE v1.patient_id > v2.patient_id
) duplicatePatients ON vv.patient_id = duplicatePatients.patient_id
WHERE
    duplicatePatients.patient_id IS NULL
    AND datepart(HOUR, GETDATE()) BETWEEN :ITIME1 AND :ITIME2
