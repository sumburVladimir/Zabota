/* ============================================================
   ID1894 «Новые Возможности» — сегмент 4 (скелет)

   Задача:
     - была получена услуга 14-1010 дней назад (список услуг ниже)
     - ИЛИ был действительный визит 0-1010 дней назад
     - нет записи вперёд
     - возраст 18+
     - исключить дубли (один пациент на телефон)
     - телефон начинается с 79
     - 1 сообщение в 21 минуту  → :IPAT = 1, шаг 21 мин в расписании

   ЧТО ЗАМЕНИТЬ ПЕРЕД ЗАЛИВКОЙ:
     1. `IN (0 /* TODO */)` в блоке «была получена услуга» — на Procedure_id
        из procedures по кодам B01.065.007, B01.066.001, B01.065.009,
        B01.065.001, B01.067.001, B01.067.001.500, B01.065.005, B01.065.003,
        B01.065.008, B01.066.002, B01.065.002, B01.067.002, B01.065.004
        + «Первичная консультация».
     2. Проверить, что «действительный визит» в этой базе = visit_state = 'N'
        (в wellness_new: N — действительный, C — отменён).
     3. Если услуга и визит должны быть ОБА (а не ИЛИ) — убрать `OR`
        вместе с комментариями и оставить два отдельных блока через AND.

   Параметры PR2 подставляет сам: :IPAT, :ITIME1/:ITIME2, :DID.
   ============================================================ */

SELECT TOP (:IPAT) vv.* FROM (SELECT patients.* FROM vpatients patients
WHERE
    cellphone LIKE '79%'
    AND hide = 0 AND Exclude = 0
    AND age >= 18                                   /* возраст от 18 лет */

    /* была получена услуга 14-1010 дней назад */
    AND EXISTS (SELECT 1 FROM patients_treatment pt
        WHERE pt.Patient_id = patients.patient_id
          AND pt.Procedure_id IN (0 /* TODO: коды услуг + «Первичная консультация» */)
          AND DATEDIFF(DAY, pt.Treatment_date, GETDATE()) BETWEEN 14 AND 1010)

    /* был действительный визит 0-1010 дней назад */
    AND EXISTS (SELECT 1 FROM patients_visits pv
        WHERE pv.Patient_Id = patients.patient_id
          AND pv.visit_state = 'N'                  /* действительный, не отменён */
          AND DATEDIFF(DAY, pv.Visit_date, GETDATE()) BETWEEN 0 AND 1010)

    /* нет записи вперёд */
    AND NOT EXISTS (SELECT 1 FROM patients_visits pv
         WHERE pv.Patient_Id = patients.patient_id
           AND pv.visit_state <> 'C'
           AND DATEDIFF(DAY, GETDATE(), pv.Visit_date) BETWEEN 0 AND 60)

    /* по этому сценарию этому номеру уже не слали */
    AND NOT EXISTS (SELECT 1 FROM messages m
         INNER JOIN deliv_orders do ON do.Order_id = m.Order_id
         WHERE do.Delivery_id = :DID
           AND m.Contact_info = patients.cellphone)
) vv
/* исключить дубли: один пациент на номер телефона (оставляем младший id) */
LEFT JOIN (
    SELECT v1.patient_id FROM patients v1
    INNER JOIN patients v2 ON v2.cellphone = v1.cellphone
    WHERE v1.patient_id > v2.patient_id
) duplicatePatients ON vv.patient_id = duplicatePatients.patient_id
WHERE
    duplicatePatients.patient_id IS NULL
    AND datepart(HOUR, GETDATE()) BETWEEN :ITIME1 AND :ITIME2
