# Интегратор — новый импорт

## Что это и место в системе

`Integrator` — компонент «Забота 2.0 Desktop Backend» для двунаправленной
интеграции с МИС: импорт справочников и оперативных данных (врачи, пациенты,
визиты, статусы, услуги) и экспорт итогов взаимодействия (подтверждение,
перенос, отмена визита). Настройка — только силами техподдержки «Заботы».

**Отличие от старого импорта.** Старый — две программы: `ZabotaMISExporter.exe`
+ `scripts\*.ns` (каждый `.ns` — `SELECT` с колонками схемы Заботы; результат
в CSV `server\In\` или сразу в БД) и `cr2importer_zabota.exe` (CSV →
`wellness_new`); конфиг `z20.ini`, банк скриптов `ScriptsBankName`. Новый —
одна служба `Integrator.exe`, логика МИС в подключаемых DLL, конфиг
`Integrator.sccfg`, декларативные шаги `ImportN = /D=... /T=...`, прямая
запись в целевую таблицу без CSV-прослойки, встроенное расписание и встречный
экспорт статусов.

**Статус.** Новый, внедряемый. В текущем `profiles\zabota` рабочий импорт —
ещё старый; Интегратор ставится отдельно в `server\Integrator` для новых
подключений. Часть модулей описана, часть есть только в виде DLL.

## Где взять последнюю версию

Актуальную сборку складывают на диск Битрикс24 (записано со слов
пользователя, 2026-11-19):

`Разработка → Приложения (Интеграции, importer, producer и прочее) →`
`Интеграции с МИС → Integrator`

- https://zabota20.bitrix24.ru/company/personal/user/4636/disk/path/%D0%A0%D0%B0%D0%B7%D1%80%D0%B0%D0%B1%D0%BE%D1%82%D0%BA%D0%B0/%D0%9F%D1%80%D0%B8%D0%BB%D0%BE%D0%B6%D0%B5%D0%BD%D0%B8%D1%8F%20%28%D0%98%D0%BD%D1%82%D0%B5%D0%B3%D1%80%D0%B0%D1%86%D0%B8%D0%B8%2C%20importer%2C%20producer%20%D0%B8%20%D0%BF%D1%80%D0%BE%D1%87%D0%B5%D0%B5%29/%D0%98%D0%BD%D1%82%D0%B5%D0%B3%D1%80%D0%B0%D1%86%D0%B8%D0%B8%20%D1%81%20%D0%9C%D0%98%D0%A1/Integrator/

Это диск пользователя 4636 на портале — доступ по правам Битрикса, вход
выполняет пользователь. В Teamly отдельной статьи про это нет: в
«Руководстве пользователя программы Integrator» (`add4efa9`) стоит пустая
ссылка «Скачайте тут», статья «Integrator» (`dcc5e93c`) — пустая.

## Архитектура

- `Integrator.exe` — служба Windows, .NET 6 Runtime, ОС не ниже Windows 7 SP1.
  Ставится распаковкой `Integrator.zip` в `server\Integrator`.
- `Sdk.dll` — общее ядро/SDK, с которым работают подключаемые модули.
- `Stub.dll` — заглушка для проверки расписания и службы (`Type = Stub`).
- `Exporter<МИС>VS.dll` / `Importer<МИС>.dll` — подключаемые модули; выбор по
  `Type` (`E...VS` — экспорт, `I...` — импорт).
- `Configurator` — утилита формирования `Integrator.sccfg`.

**`.sccfg`.** `Integrator.sccfg` лежит рядом с `Integrator.exe`, создаётся
только `Configurator`; секции `Common`, `IntegrationN`, `ZabotaDatabase` и
произвольные общие секции. Регистр не важен. После правки — перезапуск.
Шаблоны: `ExporterAltegioVS.sccfg`, `ExporterClienticsVS.sccfg`,
`ExporterCsvVS.sccfg`, `ExporterIdentVS.sccfg`, `ExporterInfoclinicVS.sccfg`,
`ExporterRenovatioVS.sccfg`, `ImporterMedods.sccfg`. В поставке они двоичные —
вручную не редактируются.

**Рабочий `.sccfg` тоже двоичный** (шифрованный; `Get-Content` даёт мусор,
первые байты вида `7D 39 A7 28…`). Читаемый текст в окне `Configurator` —
это расшифрованное представление, поэтому:
- правки делать только в `Configurator` и обязательно нажимать «Сохранить»;
- после сохранения проверять, что обновился файл именно рядом с `Integrator.exe`
  (`Get-Item .\Integrator.sccfg | fl LastWriteTime`);
- «правлю конфиг, а ничего не меняется» = правки не сохранены или сохранены
  в другую копию (частая ситуация: `…\server\Integrator` и распакованная
  папка из архива).

**БД и облако.** Подключение — секция `ZabotaDatabase`: `Hostname`, `Database`,
`Username`, пароль (`Password`/`CPassword`/`CryptPassword`),
`StoredProcedureTimeout`. Имя базы в доках не фиксировано; на практике
`wellness_new`. Целевые таблицы создаются заранее по `Importer*.sql`.
Облако описано только для Инфоклиники: регистрация экземпляра на
`https://companies.zabota.space/infoclinica/config`.

## Ключевые понятия

- **Exporter** — Забота → МИС. Все описанные — экспорт статуса визита: ищут
  новые ответы пациентов и шлют подтверждение/перенос/отмену.
- **Importer** — МИС → Забота, раскладывает данные по таблицам шагами
  `Import1`, `Import2`, ….
- **`Type`** — тип интеграции = модуль DLL и режим (`IRenovatio`, `EIdentVS`).
- **`CommunicationStatuses`** — `0` обработка, `1` отправлена доставка,
  `2` отправлен ответ, `3` сбой, `4` пропуск.
- **`Postprocess`** — хранимая процедура после успешного импорта; `0` — успех,
  отрицательное — ошибка, положительное — по логике процедуры.
- **Pipeline** — шаги `ImportN` по порядку; экспортёр за цикл опрашивает
  ответы и отправляет действия.

Разница: экспортёр отдаёт статусы/ответы в API или CSV, импортёр забирает
справочники и визиты в таблицы; у первого `Is*Enabled`/`Forbidden`, у второго
`ImportN` и периоды загрузки.

## Поток данных

```
ИМПОРТ
МИС (API/SQL) → Importer<МИС>.dll (Type=I<МИС>)
  → Import1..N: /D=<тип> → /T=<таблица>
  → [кеш /LDS: N нет, S сохранить, U читать]
  → таблица БД «Забота» → PostprocessN

ЭКСПОРТ
БД «Забота» → Exporter<МИС>VS.dll (Type=E<МИС>VS)
  → новые ответы с StartFrom → фильтр Forbidden и Is*Enabled
  → Web API МИС либо CSV (ECsvVS, Route)
```

Промежуточного файла/очереди между импортёром и БД в доках нет; `/LDS` —
внутренний кеш, а не формат обмена.

## Настройка (IntegratorSettings)

`[Common]`: `NumIntegrations` (по умолч. 1), `SleepDuration` (пауза цикла,
мин, 1–360, по умолч. 15), `WorkTimeStart`/`WorkTimeEnd` (`9:00`/`18:00`),
`IsWriteLogToConsoleEnabled`, `IsTraceLevelLogEnabled`,
`IsDebugLevelLogEnabled`, `IsWaitGC` (все `NO`).

`[IntegrationN]`: `Type`; `Config` — ссылка на общую секцию (кроме `Type`,
`Config`, расписания); расписание — только одно из `ScheduleDay` (часы 0–23),
`ScheduleWeek` (1–7, 1 = Пн), `ScheduleMonth` (1–28), плюс `StartTime` (час
0–23, по умолч. 0). Без расписания — работа в окне
`WorkTimeStart`–`WorkTimeEnd`; расписание приоритетнее. `ImportN`,
`PostprocessN`.

`[ZabotaDatabase]`: `Hostname`, `Database` (обязательны), `Username`,
пароль, `StoredProcedureTimeout` (сек., по умолч. 30).

`Postprocess`: `ИмяПроцедуры /<ПАРАМЕТР>|<ТИП>|<ЗНАЧЕНИЕ>`; типы `INT`,
`REAL` (запятая), `BOOL`, `DATETIME`, `STRING`, допустим `NULL`.

`Stub`: `Type = Stub`, `Message = <текст>` — запись в журнал при запуске.

## Поддерживаемые МИС

| МИС | Exporter | Importer | Кратко | Особенности |
|---|---|---|---|---|
| Altegio | `EAltegioVS` | — | статус визита | `PartnerToken`, `CompanyID`; числовые `Forbidden`; `Delay` 300 мс |
| Clientics | `EClienticsVS` | `IClientics` | статус + импорт | `AccountID`/`UserID`/`Token`; 7 типов `/D`; `Limit` 1–100 |
| Csv | `ECsvVS` | `ImporterCsv.dll` (нет `.md`) | статус в файл | `Route`, `Expire` |
| Ident | `EIdentVS` | — | статус визита | API + БД МИС; журнал `ident_communication_log` |
| Infoclinic | `EInfoclinicVS` | — | статус визита | `Subdomain`, `ClinicKey`; регистрация в облаке |
| Medialog | `EMedialogVS` | — | статус визита | доступ к SQL-БД МИС; `IsEncryptedPassword` |
| Renovatio | `ERenovatioVS` | `IRenovatio` | статус + полный импорт | 14 типов `/D`, диагнозы, планы лечения; `LoadRange` |
| Sqns | `ESqnsVS` | `ISqns` | статус + импорт | `MaxRows`, `ExcludeOnlineVisits`; авто-загрузка изменений |
| Stomx | — | `IStomX` | импорт | `XAPIKey`; **без удаления** при инкременте |
| Dentalpro | — | `IDentalpro` | импорт | `Token`+`Secret`; `Total`; удалённые визиты |
| Medods | `ExporterMedodsVS.dll` (нет `.md`) | `IMedods` | импорт | `IdentityKey`/`SecretKey`; коммуникации, склад |

Также есть `ImporterCsv.dll`, `ImporterOdbc.dll`, `ImporterArchimedplus.dll`,
`ExporterMedodsVS.dll` без отдельных MD — их настройки не описаны.

## Как добавить/подключить новую МИС

Разработка модуля (SDK, контракт DLL) в доках не описана. Подключение
готового:

1. Положить DLL в каталог `Integrator` рядом с `Integrator.exe`.
2. Создать целевые таблицы по `Importer<МИС>.sql`.
3. В `Configurator` добавить `IntegrationN`, задать `Type`.
4. Заполнить доступ к МИС по MD этой МИС (секреты — только в конфиге).
5. Описать `ImportN = /D=<тип> /T=<таблица>` в нужном порядке либо параметры
   экспорта.
6. Задать расписание и `PostprocessN` при необходимости.
7. Сформировать `Integrator.sccfg`, скопировать в `server\Integrator`,
   перезапустить службу. Первичная проверка — `Type = Stub`.

## Логи и права (проверено на `Integrator.dll` 1.0.23181.0)

- Логи пишутся **в файл всегда** (флаг влияет только на консоль):
  `<папка exe>\logs\Integrator_ГГГГ-ММ-ДД.log`, строка вида
  `[2026-10-29 11:52:17][…][…]: сообщение`. Старые логи чистит `DeleteObsoleteLogs`.
- `IsWriteLogToConsoleEnabled = YES` — только вывод в консоль; удобно при запуске
  `Integrator.exe` из командной строки.
- **При старте Интегратор делает запись в журнал Windows (Event Log)**
  (`Worker.BuildInitializer`). Если процесс запущен не от администратора,
  падает `System.Security.SecurityException: The source was not found...`
  и работа завершается **до** создания логов — «лого́в нет и ничего не работает».
  Отсюда: запускать из-под администратора или как службу (LocalSystem).
- `Type` сверяется со списком: `EIDENTVS, ECLIENTICSVS, ECSVVS, ...` — опечатка
  (`EldentVS` с маленькой `l`) даёт «модуль не найден».

## Статусы и диагностика

`CommunicationStatuses`: `0` обработка, `1` отправлена доставка, `2` отправлен
ответ, `3` сбой, `4` пропуск (в частности, `ident_communication_log.status`).

При ошибках смотреть:

1. Логи: `IsDebugLevelLogEnabled`, `IsTraceLevelLogEnabled`,
   `IsWriteLogToConsoleEnabled`. Файловый лог создаётся только после успешной
   инициализации: если падение на старте, в `logs\` ничего не появится, а причина
   будет только в журнале Windows (источник `Integrator`).
2. Ошибка SQL `26 — Не удается обнаружить указанный сервер/экземпляр` — это
   разбор имени сервера, **до** проверки логина/пароля. Проверять: не смешаны ли
   `хост,порт` и `хост\экземпляр` в одном значении; точное имя экземпляра
   (`Get-Service | ? Name -like 'MSSQL*'` → `MSSQL$ИМЯ`); локальный экземпляр
   надёжнее адресовать как `.\ИМЯ`.
2. Таблицу `imports`: `ImportType`, `FileName`, `ImportedRecs`,
   `UpdatedRecs`, `ErrorRecs`, `ImportTime`, `nstatus`, `Created`.
3. Статус `3` — сбой отправки/ответа, `4` — пропуск (например, `Forbidden`).
4. `Postprocess`: ненулевой `@Result` — ошибка.
5. Настройки: `Type`, наличие DLL, доступность API/БД, существование
   `/T`-таблицы, корректность `/LLL`, `/LD`, `/ULL` (ГЗ ≤ НПЗ; текущая дата −
   НПЗ ≥ 01.01.2000).
6. Расписание: окно `WorkTimeStart`–`WorkTimeEnd` или длинный `SleepDuration`.
7. Кеш `/LDS=U` может отдать устаревшие данные; для диагностики — `N`.

## Источники

Основная папка:
`C:\Users\Владимир Капов\Desktop\интеграция\ОИ и новый импорт единая версия\Integrator\Documents\`

- `IntegratorManual.md`, `IntegratorSettings.md`,
  `CommunicationStatuses.md`, `Stub.md`
- `Exporter{Altegio,Clientics,Csv,Ident,Infoclinic,Medialog,Renovatio,Sqns}VS.md`
- `Importer{Clientics,Dentalpro,Medods,Renovatio,Sqns,Stomx}.md`
- `*.sql` — DDL таблиц и шаблон процедуры; `*.sccfg` — двоичные шаблоны

Старая копия для сверки:
`C:\Users\Владимир Капов\Desktop\интеграция\Интегратор новый\Integrator\Documents\`

Смежно: `docs\zabota\import.md`, `docs\zabota\architecture.md`.
