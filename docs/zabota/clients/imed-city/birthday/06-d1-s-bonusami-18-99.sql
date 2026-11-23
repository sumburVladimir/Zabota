/* =====================================================================
   Бриф, стр. 6/6 — «Поздравление с ДР с бонусами 18-99»
   Код сценария: W.D1 / D1 (скидка 30% на проф. гигиену до {idt,14})

   Сегмент:
     • день рождения: через 7 дней (в диапазоне 7-7 дней вперёд)
     • возраст: 18-99
     • был действительный визит 31-1095 дней назад
     • НЕТ записи на 0-60 дней вперёд
     • НЕТ визита 0-30 дней назад (пациент не был месяц и не записан)
     • исключить, если был ТОЛЬКО 1 визит к Шорстову И не было визитов
       к другим врачам
     • не отправляли этот сценарий пациенту за последние 180 дней
   Расписание (задаётся в PR2): каждый день, один раз в день, 11:20.
   Параметры продюсера: :IPAT, :DID
   ===================================================================== */
SELECT TOP (:IPAT) patients.*
FROM vpatients patients
WHERE patients.cellphone LIKE '79%'
  AND ISNULL(patients.hide, 0) = 0
  AND ISNULL(patients.exclude, 0) = 0
  AND NOT EXISTS (SELECT 1 FROM phonex px WHERE px.cellphone = patients.cellphone)

  /* --- день рождения: через 7 дней --- */
  AND MONTH(patients.dob) = MONTH(DATEADD(DAY, 7, GETDATE()))
  AND DAY(patients.dob) = DAY(DATEADD(DAY, 7, GETDATE()))

  /* --- возраст 18-99 --- */
  AND patients.age BETWEEN 18 AND 99

  /* --- был визит 31-1095 дней назад --- */
  AND EXISTS (SELECT 1
              FROM patients_visits pv
              WHERE pv.Patient_Id = patients.patient_id
                AND ISNULL(pv.Visit_state, 'N') <> 'C'
                AND DATEDIFF(DAY, pv.Visit_date, GETDATE()) BETWEEN 31 AND 1095)

  /* --- нет записи на 0-60 дней вперёд --- */
  AND NOT EXISTS (SELECT 1
                  FROM patients_visits pv
                  WHERE pv.Patient_Id = patients.patient_id
                    AND ISNULL(pv.Visit_state, 'N') <> 'C'
                    AND DATEDIFF(DAY, GETDATE(), pv.Visit_date) BETWEEN 0 AND 60)

  /* --- не было визита 0-30 дней назад --- */
  AND NOT EXISTS (SELECT 1
                  FROM patients_visits pv
                  WHERE pv.Patient_Id = patients.patient_id
                    AND ISNULL(pv.Visit_state, 'N') <> 'C'
                    AND DATEDIFF(DAY, pv.Visit_date, GETDATE()) BETWEEN 0 AND 30)

  /* --- исключить «только Шорстов»: у пациента были визиты к Шорстову
         и НИ ОДНОГО визита к другим врачам (любой Doctor_ID, кроме 10000040) --- */
  AND NOT (
        EXISTS (SELECT 1
                FROM patients_visits pv
                WHERE pv.Patient_Id = patients.patient_id
                  AND ISNULL(pv.Visit_state, 'N') <> 'C'
                  AND pv.Visit_date <= GETDATE()
                  AND pv.Doctor_ID = 10000040)
    AND NOT EXISTS (SELECT 1
                    FROM patients_visits pv2
                    WHERE pv2.Patient_Id = patients.patient_id
                      AND ISNULL(pv2.Visit_state, 'N') <> 'C'
                      AND pv2.Visit_date <= GETDATE()
                      AND pv2.Doctor_ID <> 10000040)
      )

  /* --- не чаще 1 раза в 180 дней; в IN(...) добавить id второй версии --- */
  AND NOT EXISTS (SELECT 1
                  FROM vmessages m
                  WHERE m.Patient_id = patients.patient_id
                    AND m.message_state IN (0, 1, 3, 4, 10, 12, 13, 16)
                    AND m.delivery_id IN (:DID)
                    AND m.created >= DATEADD(DAY, -180, CONVERT(date, GETDATE()))
                    AND m.created <  DATEADD(DAY,   1, CONVERT(date, GETDATE())))
