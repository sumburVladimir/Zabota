# Операционные заметки по интеграции

Рабочий пул заметок из блокнота `Desktop\интеграция\интеграция.txt` (актуализируется
вручную, последняя правка 14.10.2026). Часть записей может устаревать — сверяйся по
дате и по источникам. Секреты вычищены (они в `credentials.local.ini`).

## Карта серверов (куда что ставим)

| Сервер | Адрес | Назначение |
|---|---|---|
| APP1 | `89.248.192.64:3380` | новые клиенты: только ПР2 и МО |
| APP2 | `95.143.190.222:3380` | новые клиенты: ничего не ставим |
| APP3 | `78.24.181.213` | новые клиенты: ничего не ставим |
| APP2.1 | `37.48.249.112` | новые клиенты: **импорты и обратные интеграции** |
| APP3.1 | `87.228.65.201` | новые клиенты: **проды** |
| ЦБД5 | `78.24.181.230` | БД новых клиентов (≤ 50 БД на сервер) |
| ЦБД6 | `87.228.57.242` | БД новых клиентов (≤ 50 БД на сервер) |

На остальные ЦБД-сервера новые БД не ставим.

## Адреса и порты для работы

- Локальная сеть: **SQL Server TCP 30000**.
- Whitelist для сетевых фильтров (порты 80/443):
  `cl1.su`, `ptrr.zabota.space`, `wp.zabota.space`, `z20.ms`, `nps.st`,
  `mgate.zabota.space`, `q.z20.pw`, `2ap.su`, `companies.zabota.space`.
- Облако: порт **51820** (Wireguard).
- Модуль ответов: доступ к `cl1.su` (вкладка «Анкетирование») и `cdb.zabota.space:4040`.

### Адреса для облачных клиентов (ЦБД облака 1–3)

| ЦБД | РДП | МО клиентов | Сервер приложений |
|---|---|---|---|
| Облако 1 | `5.35.7.50:33890` | `100.64.0.10,30000\ZABOTACBD` | `10.20.0.3,30000\ZABOTACBD` |
| Облако 2 | `77.223.102.217` | `100.64.0.12,30000\ZABOTACBD` | `10.20.0.4,30000\ZABOTACBD` |
| Облако 3 | `87.249.36.149` | `100.64.0.13,30000\ZABOTACBD` | `10.20.0.5,30000\ZABOTACBD` |

(Полная карта ЦБД 1–9 — в `credentials.local.ini`, раздел-комментарий.)

## Полезные ссылки на сервисы

| Что | Ссылка |
|---|---|
| Привязки MAX и Telegram | `https://messaging.zabota.space/tools/accounts` |
| Логотипы клиник | `https://companies.zabota.space/tools/old/logos` |
| Установщик | `https://companies.zabota.space/installer` (по клинике: `/i/<id>`) |
| Утилита ссылок | `z20.su` |
| URL-инструмент (филиалы) | `http://2ap.su/tools/urls/index.html` |
| Статистика | `http://cl1.su/statistics` (доступ — см. credentials) |
| Регистрация экземпляра (Инфоклиника, облако) | `https://companies.zabota.space/infoclinica/config` |

## Типы сценариев (ref)

- `ref3` — приглашения
- `ref2` — напоминания
- остальные — обратная связь

## VPN / Wireguard

Удаление туннеля:

```
"C:\Program Files\wireguard\wireguard.exe" /uninstalltunnelservice <имя.conf> <название туннеля>
```

## Интеграции с конкретными МИС

### Апдента
Рабочая интеграция, клиент **4885**.

### IDENT
- Ссылка на мануал: `https://nextcloud.zabota.space/index.php/s/F4cLLM8c6JHFxWX`.
- **Важный нюанс:** если сценарий не имеет тип «Обратная связь» / «Напоминания» — ответы по нему не отправляются.

### DentalPro
Проверка секрета/токена: `GET https://<клиника>.crm2.dental-pro.online/api/z/companies?token=...&secret=...`
(токен/секрет — запрашиваются у клиники; тестовый пример не публикуем).

### НПС-интеграции (перевод на ЛК Интис)

Перед запуском переводим клинику на ЛК Интис (клиника должна предоставить его на
момент интеграции; иначе ждём). Порядок (в `http://ptrr.zabota.space/tools/gates/`):
1. Найти клинику по ID.
2. «Имя» — название клиники.
3. «Провайдер» — не трогаем.
4. «Логин/Пароль» — по данным от куратора.
5. Проверить на `sms16.ru`, что входит в ЛК (если нет — писать, что не заходит).
6. «Отправитель» — стандартно `mytestsms`, не трогаем (если клиника не подключила имя отправителя).
7. Сохранить, запустить рассылку после завершения интеграции.

Сценарий «Индекс НПС» / параметры:
1. В тексте вписать название клиники вручную (как на отзовике).
2. Параметр сегмента «Услуга получена от 1 до 3 дней назад», остальное не меняем.
3. Расписание — ежедневно 12:00.
4. Запуск.

### Сценарий и параметры (проверка филиала)

Проверять сегментом, что `cust_Id` один, а не несколько. Если несколько — уточнить
у куратора, какой филиал запускаем, и исключить лишние из выгрузки. ID филиала в
рассылках должен совпадать с ID на `http://2ap.su/tools/urls/index.html`.

## Мультифилиал (COALESCE :CUST_ID)

Для мультифилиальных клиентов в SQL-сценарии добавлять фильтр по филиалу:

```sql
AND v.cust_id = COALESCE(:CUST_ID, v.cust_id)
```

- СОЗ: `AND patients.cust_id = COALESCE(:CUST_ID, patients.cust_id)`
- НАП (по дням): `AND v.cust_id = COALESCE(:CUST_ID, v.cust_id)`
- НАП (по часам): `AND patients.cust_id = COALESCE(:CUST_ID, patients.cust_id)`
- Анкеты/НПС: `AND pl.cust_id = COALESCE(:CUST_ID, pl.cust_id)`
- Для НАП добавить филиал в вывод: `v.cust_id AS ClinicID`, `v.cust_id AS cust_id`.

## Тайминги каналов (Десктоп / Клауд)

| Канал | Десктоп | Клауд |
|---|---|---|
| WhatsApp | 120 минут | 60 минут |
| Telegram | 20 секунд | 15 минут |
| MAX | 60 минут | 30 минут |
| SMS | 120 минут | 60 минут |

## SQL-сниппеты

### Первичный/повторный к доктору (`fsIsFirstVisitToDoctor`)

Параметр `:IFDOC` (0 — все, 1 — впервые, 2 — повторно):

```sql
((dbo.fsIsFirstVisitToDoctor(patients.Appoint_Id) = 1 AND :IFDOC = 1)
 OR (dbo.fsIsFirstVisitToDoctor(patients.Appoint_Id) = 0 AND :IFDOC = 2)
 OR (:IFDOC = 0))
```

Функция (готовая к созданию в БД):

```sql
CREATE FUNCTION dbo.fsIsFirstVisitToDoctor (@Appoint_ID INT)
RETURNS INT
AS
BEGIN
  DECLARE @First INT, @Patient_Id INT, @Doctor_Id INT, @Visit_Date DATETIME;

  SELECT TOP 1 @Patient_Id = Patient_Id, @Doctor_Id = Doctor_ID, @Visit_Date = Visit_date
  FROM patients_visits WHERE Appoint_Id = @Appoint_ID;

  SELECT @First = CASE
      WHEN EXISTS (SELECT 0 FROM patients_visits pv
                   WHERE pv.Patient_Id = @Patient_Id
                     AND pv.Doctor_ID = @Doctor_Id
                     AND (pv.Visit_state <> 'C' OR pv.Visit_state IS NULL)
                     AND DATEDIFF(DAY, pv.Visit_date, @Visit_Date) > 0) THEN 0
      ELSE 1 END;
  RETURN @First;
END
```

### Первичные/повторные действительные на завтра

```sql
-- Первичные, действительные на завтра
SELECT v.dob AS 'Дата рождения', v.age AS 'Возраст', v.surname AS 'Фамилия',
       v.firstname AS 'Имя', v.midname AS 'Отчество', v.cellphone AS 'Номер телефона',
       c.cust_address AS 'Адрес клиники'
FROM patients_visits pv
INNER JOIN vpatients v ON pv.Patient_Id = v.patient_id
INNER JOIN customers c ON c.cust_code = pv.cust_id
WHERE DATEDIFF(DAY, GETDATE(), pv.Visit_date) = 1
  AND ISNULL(pv.Visit_state, 'C') = 'N'
  AND v.Isfirst = 1;   -- для повторных: = 0; отменённые: Visit_state = 'C'
```

### Перепривязка сообщений при переносе базы

```sql
-- связь старых и новых id по ФИО+телефону
SELECT p.Patient_Id AS new, p1.Patient_Id AS old INTO #pat_relation
FROM patients p
JOIN k37_old.dbo.patients p1
  ON p.Cellphone = p1.Cellphone AND p.Surname = p1.Surname
  AND p.Firstname = p1.Firstname AND p.Midname = p1.Midname;

SELECT d.Doctor_ID AS new, d1.Doctor_ID AS old INTO #doc_relation
FROM doctors d JOIN k37_old.dbo.doctors d1 ON d.Surname = d1.Surname;

UPDATE a SET patient_id = new FROM answers a JOIN #pat_relation pr ON pr.old = a.patient_id;
UPDATE a SET doctor_id  = new FROM answers a JOIN #doc_relation dr ON dr.old = a.doctor_id;
UPDATE messages SET Patient_id = new FROM messages m JOIN #pat_relation pr ON pr.old = m.Patient_id;
```

### Убрать экранизацию в каскадных ссылках

```sql
UPDATE deliveries_cascade_params SET value = replace(value, '\/', '/');        -- все ссылки
UPDATE deliveries_cascade_params SET value = replace(value, '<\/smile>', '</smile>'); -- только смайлы
```

### Удаление шаблонов сценариев

```sql
UPDATE deliveries SET deleted = 1 WHERE Parent_id IS NOT NULL;
-- проверка:
SELECT d.delivery_id, d.code, d.dname, d.deleted FROM deliveries d
WHERE d.Parent_id IS NOT NULL AND d.deleted = 1;
```

### Собрать Procedure_ID в строку (через STUFF + FOR XML)

```sql
SELECT STUFF((
    SELECT ',' + CAST(p.procedure_id AS VARCHAR(10))
    FROM procedures p
    INNER JOIN _procedures_iskl ON p.Descr = _procedures_iskl.descr
    FOR XML PATH('')), 1, 1, '') AS ProcedureIDs;
```

### Отключение IDENTITY на `_tmp`-таблицах (курсор)

Используется перед ручным наполнением временных таблиц импорта. Список таблиц:
`chairs_tmp`, `diagnosis_tmp`, `doctors_tmp`, `patients_diags_tmp`, `patients_tmp`,
`patients_treatment_teeth_tmp`, `patients_treatment_tmp`, `patients_visits_reasons_tmp`,
`patients_visits_tmp`, `procedures_tmp`, `status_types_tmp`, `visit_statuses_tmp`,
`custom_*_tmp`. (Полный скрипт — в блокноте.)

### Блокировка базы от пользователей

```sql
ALTER DATABASE [DbName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;  -- выбить всех
ALTER DATABASE [DbName] SET MULTI_USER;                            -- вернуть
```

## Удалённый доступ

Ассистент у клиентов не работает — предлагать **RustDesk** (общая учётка ТП; логин/пароль
в `credentials.local.ini`). Инструкция: `https://zabota.teamly.ru/at/78f3614d-8a25-4b6e-9228-accad723f839`.
Клиентские дистрибутивы — ссылки в Bitrix24.

## Разное

- **Как писать в `support@ident-it.ru`** (ошибка МИС IDENT): указывать название клиники,
  адрес, ФИО и номер директора, инфо по ошибке; можно указать свой номер для связи.
- **Оффлайн-установка .NET Framework** — `https://deepsmr.ru/komputer/ustanovka-framework-windows-10.html`.
- **Visual C++ Redistributable** (для модуля ответов) — `https://www.techpowerup.com/download/visual-c-redistributable-runtime-package-all-in-one/`.
- **Виджет записи cl1.su** — embed-код `<script src="https://cl1.su/public/js/widget.js">`
  с параметрами `widget_clinic`, `widget_height`, `widget_width`, `widget_logo`, `widget_doctors`.
- **Dob с проверкой даты** (при импорте):
  ```sql
  CASE WHEN isdate(p.birthday) = 1 THEN CAST(p.birthday AS DATE) ELSE NULL END AS 'Dob'
  ```
