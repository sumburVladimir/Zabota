# Zabota — инструкции для агента

## Что это
Автоматизация работы с системой «Забота»: импорт из МИС, сценарии рассылок (продюсер), клиент PR2.
- **Базы клиник** стоят на серверах самих клиентов (доступ через RDP/Ассистент, срез в буфере обмена или выгрузки CSV/XLS; карты их схем — в `docs/zabota/clients/<Zabota_ID>/`).
- **Локальная БД `wellness_new`** (`USERPC\ZABOTASQLSERVER1`) — только тестовый слепок (эталон схемы и песочница для `tmp_` баз) на ПК пользователя. В ней нет данных текущих клиентских задач.
Общение и документация — на русском.

## ГЛАВНОЕ ПРАВИЛО СКОРОСТИ (НЕ ЧИТАТЬ ЛИШНЕГО!)
1. **НЕ читай документацию «впрок»!** Никогда не открывай `producer.md`, `scenarios-audit.md`, `README.md` или чужие папки клиник `docs/zabota/clients/*`, если пользователь просто просит написать типовой SQL-сегмент или акцию.
2. **Никогда не читай папки других клиник** (`docs/zabota/clients/<чужой_ID>/`), чтобы «посмотреть примеры» — там лежат списки на тысячи `Procedure_id`, которые забивают контекст и тормозят ответ.
3. **Если в условии брифа/задачи есть двусмысленность** (например, к какому блоку относятся врачи или услуги) — **НЕ ищи ответ по всем файлам проекта**. Задай пользователю 1 короткий вопрос ИЛИ сразу выдай готовый SQL с понятным комментарием `/* УТОЧНИТЬ: ... */`.

## Два режима работы по SQL-задачам

### Режим 1. БЫСТРЫЙ (включён ВСЕГДА по умолчанию — «напиши акцию / сегмент / условие»)
Если пользователь дал условия словами/брифом (или просто просит написать SQL-шаблон):
- **НИКОГДА не требуй от пользователя срез базы (`00_snapshot_for_agent.sql`) или CSV-выгрузки!**
- **Не запускай цепочку из 3 сабагентов и не читай файлы из `docs/`.**
- Сразу пиши SQL по встроенному каркасу ниже (если ID врачей/услуг не даны — ставь понятные заглушки `/* ид докторов */` или `/* ид услуг */`).
- Каркас ручного SQL-сегмента (`deliv_conditions.Expression` — фирменный стиль «акция с амоунтом»):
  ```sql
  SELECT TOP (:IPAT) vv.* from (select patients.* FROM vpatients patients
  WHERE 
      cellphone LIKE ('79%')  
      AND hide=0 AND Exclude=0

  	/*сюда вставлять свой код (блоки ниже по условиям брифа; соединять через AND, OR только если явно сказано ИЛИ)*/

    -- [Кирпич: Нет визитов на будущее]
    AND NOT EXISTS (SELECT 1 FROM patients_visits pv /*нет визитов на будущее */
     WHERE patients.patient_id=pv.Patient_Id              
     AND DATEDIFF(DAY,GETDATE(), pv.Visit_date) BETWEEN 0 AND 60
     and pv.visit_state<>'C'
     and pv.doctor_id in(1,2,3,4) /*ид докторов*/
     ) 

    -- [Кирпич: Был визит в диапазоне]
    AND EXISTS (SELECT 1 FROM patients_visits pv /* был визит в диапазоне от 61 до 1095*/
     WHERE patients.patient_id=pv.Patient_Id
     and pv.visit_state<>'C'
     AND DATEDIFF(DAY,pv.Visit_date,GETDATE()) BETWEEN 61 AND 1095
     and pv.doctor_id in(1,2,3,4) /*ид докторов*/
     )

    -- [Кирпич: Сумма оплат от N]
    AND EXISTS ( 
     SELECT pt.Patient_id FROM patients_treatment pt WHERE patients.patient_id = pt.Patient_id GROUP BY pt.Patient_id HAVING SUM(pt.Total)> 10000 /*оплаты от 10к*/
    )

    -- [Кирпич: Не было конкретных услуг за N дней — СТРОГО ЧЕРЕЗ NOT EXISTS]
    AND NOT EXISTS (SELECT 1 FROM patients_treatment pt
     WHERE patients.patient_id=pt.Patient_id
     AND DATEDIFF(DAY, pt.Treatment_date, GETDATE()) BETWEEN 0 AND 149 /*не было услуг профгигиены за 149 дн*/
     AND pt.Procedure_id IN (2943, 2743, 2736)
     )

    -- [Кирпич: Не было сообщений этого сценария по patient_id / или любых сообщений за 180 дн (если нужно по брифу)]
    -- AND NOT EXISTS(SELECT 1 from messages m INNER JOIN deliv_orders o ON o.Order_id=m.order_id WHERE m.Patient_id=patients.patient_id AND o.Delivery_id=:DID)
    -- AND NOT EXISTS(SELECT 1 from messages m INNER JOIN deliv_orders o ON o.Order_id=m.order_id WHERE m.Patient_id=patients.patient_id AND DATEDIFF(DAY,o.created,GETDATE())<180)

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
- Отдай готовый SQL сразу, коротко и по делу.

### Режим 2. ПОЛНЫЙ КОНВЕЙЕР (включается ТОЛЬКО когда пользователь сам дал срез или выгрузки!)
Активируется **только по инициативе пользователя**, когда он сам положил срез базы (`00_snapshot_for_agent.sql`) в буфер обмена/файл или дал CSV-выгрузки со словами *«срез в буфере / разбери базу клиники / сверь бриф со справочником»*:
1. **`zabota-recon`**: распаковывает срез в `tmp_clinic_<ID>` (`python tools/snapshot_to_sandbox.py --from-clipboard --clinic-id <ID>`), матчит бриф (`tools/brief_group_match.py`) или ищет причину неотправки сообщения.
2. **`zabota-sql-coder`**: пишет патч-скрипт (`UPDATE`/`INSERT` с бэкапом `_bak_YYYYMMDD` и транзакцией `@@ROWCOUNT`).
3. **`zabota-sql-auditor`**: проверяет патч через `python tools/verify_sql.py --db tmp_clinic_<ID>`.

### Режим 3. Разбор непонятных логов Импорта / Экспортёра / Интегратора
Когда пользователь присылает непонятную ошибку из лога `Integrator.exe`, `ZabotaMISExporter.exe` или `cr2importer_zabota.exe`:
1. Сначала проверь `docs/zabota/integrator.md`, `docs/zabota/import.md` и `docs/zabota/integration/digest-integrator.md`.
2. Если ответа в доках нет — найди точную строку из лога прямо внутри `.NET` бинарников (`.dll` / `.exe`) соответствующего модуля в `C:\Users\Владимир Капов\Desktop\интеграция\` (или `C:\Zabota 2.0\`), посмотри условие в коде вокруг этой строки и точно объясни пользователю причину ошибки. Новую находку кратко зафиксируй в `integrator.md` или `import.md`.

## Справочник документации (открывать ТОЛЬКО по прямой необходимости!)
- Карта документации: `docs/zabota/README.md`.
- Только если задача про импорт IDENT: `docs/zabota/import.md`; про Интегратор: `docs/zabota/integrator.md`.
- Только если задача про архитектуру/PR2/Продюсер: `architecture.md`, `pr2.md`, `producer.md`.
- Скиллы (загружать только когда нужны): `zabota-db` (запросы к локальной БД), `bitrix24` (задачи в браузере), `teamly` (регламенты из `docs/zabota/teamly/README.md`).
- **Посмотреть второй монитор (RDP / Ассистент):** `powershell -ExecutionPolicy Bypass -File tools/look_screen.ps1` → читать `C:\Users\Владимир Капов\AppData\Local\Temp\opencode\screen_1.png`.
- **Кириллица в выводе:** писать в файл UTF-8 и читать файлом.

## Запреты
- Секреты (пароли, токены) хранить **только** в `credentials.local.ini` (в `.gitignore`).
- Не распаковывать `.7z` / `.zip` / `.rar` без явной просьбы.
- Не делать `UPDATE` / `DELETE` / `INSERT` в БД без подтверждения.
