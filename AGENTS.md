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

### Режим 1. БЫСТРЫЙ (по умолчанию — «напиши акцию / сегмент / условие»)
Если пользователь дал условия словами/брифом (список ID услуг, врачей, сроки, возраст):
- **Не запускай цепочку из 3 сабагентов и не читай файлы из `docs/`.**
- Сразу пиши SQL по встроенному каркасу ниже (или вызови один `zabota-sql-coder` без чтения лишних файлов).
- Каркас ручного SQL-сегмента (`deliv_conditions.Expression`):
  ```sql
  SELECT TOP (:IPAT) vv.* FROM (
      SELECT patients.* FROM vpatients patients
      WHERE cellphone LIKE ('79%')
        AND hide = 0 AND Exclude = 0
        /* --- УСЛОВИЯ БРИФА (все через AND, OR только если явно сказано ИЛИ) --- */
        -- Возраст: AND patients.age BETWEEN 18 AND 99
        -- Был визит N..M дней назад:
        -- AND EXISTS (SELECT 1 FROM patients_visits pv WHERE patients.patient_id = pv.Patient_Id AND pv.visit_state <> 'C' AND DATEDIFF(DAY, pv.Visit_date, GETDATE()) BETWEEN 61 AND 1095 AND pv.doctor_id IN (...))
        -- Нет записи на будущее:
        -- AND NOT EXISTS (SELECT 1 FROM patients_visits pv WHERE patients.patient_id = pv.Patient_Id AND pv.visit_state <> 'C' AND DATEDIFF(DAY, GETDATE(), pv.Visit_date) BETWEEN 0 AND 60 AND pv.doctor_id IN (...))
        -- Была/не была услуга (patients_treatment):
        -- AND NOT EXISTS (SELECT 1 FROM patients_treatment pt WHERE patients.patient_id = pt.Patient_id AND DATEDIFF(DAY, pt.Treatment_date, GETDATE()) BETWEEN 0 AND 149 AND pt.Procedure_id IN (...))
        -- Не слали по этому сценарию за N дней:
        AND NOT EXISTS (
            SELECT 1 FROM messages m
            INNER JOIN deliv_orders do ON do.Order_id = m.Order_id
            WHERE do.Delivery_id = :DID
              AND m.Contact_info = patients.cellphone
              AND DATEDIFF(DAY, do.Created, GETDATE()) < 180
        )
  ) vv
  LEFT JOIN (
      SELECT v1.patient_id FROM patients v1
      INNER JOIN patients v2 ON v2.cellphone = v1.cellphone
      WHERE v1.patient_id > v2.patient_id
  ) duplicatePatients ON vv.patient_id = duplicatePatients.patient_id
  WHERE duplicatePatients.patient_id IS NULL
  ```
- Отдай готовый SQL сразу, коротко и по делу.

### Режим 2. ПОЛНЫЙ КОНВЕЙЕР (только для большого аудита клиники или среза из буфера)
Включается **только** когда пользователь дал срез базы (`00_snapshot_for_agent.sql`), выгрузки таблиц или явно попросил: *«проведи полный аудит сценариев клиники»* / *«разберись со срезом»*:
1. **`zabota-recon`**: распаковывает срез в `tmp_clinic_<ID>` (`python tools/snapshot_to_sandbox.py --from-clipboard --clinic-id <ID>`), матчит бриф (`tools/brief_group_match.py`) или ищет причину неотправки сообщения.
2. **`zabota-sql-coder`**: пишет патч-скрипт (`UPDATE`/`INSERT` с бэкапом `_bak_YYYYMMDD` и транзакцией `@@ROWCOUNT`).
3. **`zabota-sql-auditor`**: проверяет патч через `python tools/verify_sql.py --db tmp_clinic_<ID>`.

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
