# SQL-сегменты сценариев — фирменный ручной стиль

Как мы пишем `deliv_conditions.Expression` руками (в отличие от генератора
`constructor.exe`, который выдаёт перегруженные скрипты). Источник — личный
блокнот пользователя `Desktop\интеграция\всякие задачки\акция с амоунтом.txt`.

## Каркас (обёртка)

```sql
SELECT TOP (:IPAT) vv.* from (select patients.* FROM vpatients patients
WHERE 
    cellphone LIKE ('79%')  
    AND hide=0 AND Exclude=0

	/*сюда вставлять свой код*/

  AND                      
  NOT EXISTS(SELECT 1 FROM messages m                              
  INNER JOIN deliv_orders do ON do.Order_id=m.Order_id
  WHERE do.Delivery_id=:DID              
  AND m.Contact_info=patients.cellphone)) vv
  LEFT JOIN (
    SELECT v1.patient_id
    FROM patients v1
    INNER JOIN patients v2 ON v2.cellphone = v1.cellphone
    WHERE v1.patient_id > v2.patient_id
   ) duplicatePatients ON vv.patient_id = duplicatePatients.patient_id
  WHERE 
  duplicatePatients.patient_id IS NULL
  AND datepart(HOUR, GETDATE()) BETWEEN :ITIME1 AND :ITIME2
```

## Параметры

| Параметр | Смысл |
|---|---|
| `:IPAT` | лимит пациентов (`TOP`) |
| `:ITIME1`, `:ITIME2` | окно часов работы сценария |
| `:DID` | `delivery_id` текущего сценария |

## Базовые конструкции (кирпичики)

1. **Только российские мобильные:**
   ```sql
   cellphone LIKE ('79%')
   ```
2. **Не исключённые и не скрытые:**
   ```sql
   hide=0 AND Exclude=0
   ```
3. **Не слали по этому сценарию (по номеру телефона):**
   ```sql
   NOT EXISTS(SELECT 1 FROM messages m
     INNER JOIN deliv_orders do ON do.Order_id=m.Order_id
     WHERE do.Delivery_id=:DID
     AND m.Contact_info=patients.cellphone)
   ```
4. **Дедуп по телефону — один пациент на номер** (self-join, оставляем младший id):
   ```sql
   LEFT JOIN (
     SELECT v1.patient_id
     FROM patients v1
     INNER JOIN patients v2 ON v2.cellphone = v1.cellphone
     WHERE v1.patient_id > v2.patient_id
   ) duplicatePatients ON vv.patient_id = duplicatePatients.patient_id
   WHERE duplicatePatients.patient_id IS NULL
   ```
5. **Ограничение по часам:**
   ```sql
   datepart(HOUR, GETDATE()) BETWEEN :ITIME1 AND :ITIME2
   ```

## Визиты (`patients_visits`)

6. **Нет визитов на будущее** (ближайшие 60 дней, у выбранных врачей):
   ```sql
   NOT EXISTS (SELECT 1 FROM patients_visits pv
     WHERE patients.patient_id = pv.Patient_Id
     AND DATEDIFF(DAY, GETDATE(), pv.Visit_date) BETWEEN 0 AND 60
     AND pv.visit_state <> 'C'
     AND pv.doctor_id IN (1,2,3,4) /*ид докторов*/)
   ```
7. **Был визит в диапазоне** (61–1095 дней назад):
   ```sql
   EXISTS (SELECT 1 FROM patients_visits pv
     WHERE patients.patient_id = pv.Patient_Id
     AND pv.visit_state <> 'C'
     AND DATEDIFF(DAY, pv.Visit_date, GETDATE()) BETWEEN 61 AND 1095
     AND pv.doctor_id IN (1,2,3,4))
   ```

## Услуги / суммы (`patients_treatment`)

8. **Сумма оплат от N:**
   ```sql
   EXISTS (SELECT pt.Patient_id FROM patients_treatment pt
     WHERE patients.patient_id = pt.Patient_id
     GROUP BY pt.Patient_id HAVING SUM(pt.Total) > 10000)
   ```
9. **Не было конкретной услуги за N дней:**
   ```sql
   NOT EXISTS (SELECT 1 FROM patients_treatment pt
     WHERE patients.patient_id = pt.Patient_id
     AND DATEDIFF(DAY, pt.Treatment_date, GETDATE()) BETWEEN 0 AND 149
     AND pt.Procedure_id IN (2943, 2743, 2736))
   ```

## Сообщения (`messages`)

10. **Не было сообщений этого типа:**
    ```sql
    NOT EXISTS(SELECT 1
      FROM messages m INNER JOIN deliv_orders o ON o.Order_id=m.order_id
      WHERE m.Patient_id=patients.patient_id
      AND o.Delivery_id=:DID)
    ```
11. **Не было сообщений за N дней (в т.ч. другими сценариями):**
    ```sql
    NOT EXISTS(SELECT 1
      FROM messages m INNER JOIN deliv_orders o ON o.Order_id=m.order_id
      WHERE m.Patient_id=patients.patient_id
      AND DATEDIFF(DAY, o.created, GETDATE()) < 180)
    ```

## Ключевые идиомы

- **`DATEDIFF(DAY, дата, GETDATE())`** — дней от даты до сегодня (положительное = было в прошлом).
- **`DATEDIFF(DAY, GETDATE(), дата)`** — дней от сегодня до даты (для будущих визитов).
- **`pv.visit_state <> 'C'`** — визит не отменён.
- **`pv.doctor_id IN (...)`** — фильтр по врачам (ид докторов комментарием).
- Комментарии по-русски через `/* ... */`, короткие, у каждого блока.

## Полный пример из блокнота («акция с амоунтом»)

```sql
SELECT TOP (:IPAT) vv.* from (select patients.* FROM vpatients patients
WHERE 
    cellphone LIKE ('79%')  
    AND hide=0 AND Exclude=0

	/*сюда вставлять свой код*/
	
  AND                      
  NOT EXISTS(SELECT 1 FROM messages m                              
  INNER JOIN deliv_orders do ON do.Order_id=m.Order_id
  WHERE do.Delivery_id=:DID              
  AND m.Contact_info=patients.cellphone)) vv
  LEFT JOIN (
    SELECT v1.patient_id
    FROM patients v1
    INNER JOIN patients v2 ON v2.cellphone = v1.cellphone
    WHERE v1.patient_id > v2.patient_id
   ) duplicatePatients ON vv.patient_id = duplicatePatients.patient_id
  WHERE 
  duplicatePatients.patient_id IS NULL
  AND datepart(HOUR, GETDATE()) BETWEEN :ITIME1 AND :ITIME2  

                 
  
  AND NOT EXISTS (SELECT 1 FROM patients_visits pv /*нет визитов на будущее */
   WHERE patients.patient_id=pv.Patient_Id              
   AND DATEDIFF(DAY,GETDATE(), pv.Visit_date) BETWEEN 0 AND 60
   and pv.visit_state<>'C'
   and pv.doctor_id in(1,2,3,4) /*ид докторов*/
   ) 

 AND  EXISTS (SELECT 1 FROM patients_visits pv /* был визит в диапазоне от 61 до 1095*/
  WHERE patients.patient_id=pv.Patient_Id
  and pv.visit_state<>'C'
  AND DATEDIFF(DAY,pv.Visit_date,GETDATE()) BETWEEN 61 AND 1095
  and pv.doctor_id in(1,2,3,4) /*ид докторов*/
  )


AND EXISTS ( 
  SELECT pt.Patient_id FROM patients_treatment pt WHERE patients.patient_id = pt.Patient_id  GROUP BY pt.Patient_id HAVING SUM(pt.Total)> 10000 /*оплаты от 10к*/
  
)


AND NOT EXISTS
          (SELECT 1 FROM patients_treatment pt
          WHERE patients.patient_id=pt.Patient_id
          AND DATEDIFF(DAY, pt.Treatment_date, GETDATE()) BETWEEN 0 AND 149 /*не было услуг профгигиены за 149 дне*/
          AND pt.Procedure_id IN  (2943, 2743, 2736)
          )  
          
        
 
  
   AND     /*нет сообщений этого типа в течение 180 дн*/
     NOT EXISTS(SELECT 1
                  from messages m INNER JOIN deliv_orders o ON o.Order_id=m.order_id
                  WHERE m.Patient_id=patients.patient_id
                  AND o.Delivery_id=:DID)

  AND     
     NOT EXISTS(SELECT 1
                  from messages m INNER JOIN deliv_orders o ON o.Order_id=m.order_id
                  WHERE m.Patient_id=patients.patient_id              
                  AND DATEDIFF(DAY,o.created,GETDATE())<180) 


AND datepart(HOUR, GETDATE()) BETWEEN 10 AND 19 /*ограничить время работы сценария с 11 часов до 18:59*/
```

## Отличие от стиля `constructor.exe`

Генератор пишет через `DATEADD(day, DATEDIFF(day, 0, GETDATE()) - N, 0)` и вложенные
`IN (SELECT DISTINCT ...)` по каждой таблице — громоздко. Ручной стиль проще и читаемее:
`DATEDIFF(DAY, <колонка>, GETDATE()) BETWEEN a AND b`, `EXISTS`/`NOT EXISTS`, плоский
список условий, короткие русские комментарии.
