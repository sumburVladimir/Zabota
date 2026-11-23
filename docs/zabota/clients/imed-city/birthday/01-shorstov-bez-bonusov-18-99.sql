/* =====================================================================
   Бриф, стр. 1/6 — «Поздравление с днем рождения без бонусов 18-99 Шорстов»

   Сегмент:
     • день рождения: сегодня
     • возраст: 18-99
     • было более 2 приёмов у доктора Шорстова (Шорстов Я.В. = 10000040)
     • ИЛИ (действительная запись на 0-60 дней вперёд)
       ИЛИ (действительный визит 0-30 дней назад)
     • не отправляли этот сценарий пациенту за последние 180 дней
       (сюда же добавить id второй версии сценария — см. комментарий ниже)
   Расписание (задаётся в PR2): каждый день, один раз в день.
   Параметры продюсера: :IPAT, :DID
   ===================================================================== */
SELECT TOP (:IPAT) patients.*
FROM vpatients patients
WHERE patients.cellphone LIKE '79%'
  AND ISNULL(patients.hide, 0) = 0
  AND ISNULL(patients.exclude, 0) = 0
  /* не дубли по номеру телефона */
  AND NOT EXISTS (SELECT 1 FROM phonex px WHERE px.cellphone = patients.cellphone)

  /* --- день рождения: сегодня --- */
  AND MONTH(patients.dob) = MONTH(GETDATE())
  AND DAY(patients.dob) = DAY(GETDATE())

  /* --- возраст 18-99 --- */
  AND patients.age BETWEEN 18 AND 99

  /* --- было более 2 приёмов у доктора Шорстова (10000040) --- */
  AND (SELECT COUNT(*)
       FROM patients_visits pv
       WHERE pv.Patient_Id = patients.patient_id
         AND ISNULL(pv.Visit_state, 'N') <> 'C'
         AND pv.Visit_date <= GETDATE()
         AND pv.Doctor_ID = 10000040) > 2

  /* --- ИЛИ: запись на 0-60 дней вперёд ИЛИ визит 0-30 дней назад --- */
  AND (
        EXISTS (SELECT 1
                FROM patients_visits pv
                WHERE pv.Patient_Id = patients.patient_id
                  AND ISNULL(pv.Visit_state, 'N') <> 'C'
                  AND DATEDIFF(DAY, GETDATE(), pv.Visit_date) BETWEEN 0 AND 60)
     OR EXISTS (SELECT 1
                FROM patients_visits pv
                WHERE pv.Patient_Id = patients.patient_id
                  AND ISNULL(pv.Visit_state, 'N') <> 'C'
                  AND DATEDIFF(DAY, pv.Visit_date, GETDATE()) BETWEEN 0 AND 30)
      )

  /* --- не чаще 1 раза в 180 дней ---
     В IN(...) перечислить :DID И id второй версии этого же сценария
     (без фильтра по Шорстову), если она заведена отдельной строкой:
     тогда пациент не получит два поздравления в один день. */
  AND NOT EXISTS (SELECT 1
                  FROM vmessages m
                  WHERE m.Patient_id = patients.patient_id
                    AND m.message_state IN (0, 1, 3, 4, 10, 12, 13, 16)
                    AND m.delivery_id IN (:DID)
                    AND m.created >= DATEADD(DAY, -180, CONVERT(date, GETDATE()))
                    AND m.created <  DATEADD(DAY,   1, CONVERT(date, GETDATE())))
