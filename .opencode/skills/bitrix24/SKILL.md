---
name: Bitrix24 (задачи)
description: Битрикс24 проекта (портал zabota20.bitrix24.ru, рабочая группа 1185). Задачи смотрим через встроенный браузер OpenCode — API/вебхук не используется. Используй, когда речь о задачах, заявках или поручениях из Битрикса.
---

# Bitrix24 — подключение и работа с задачами

## Как смотрим задачи сейчас: через браузер пользователя

Вебхука/API у нас **нет** (и создавать нельзя — см. «Запреты»). Задачи смотрим
через **браузер самого пользователя** (Chrome-семейство), где запущен плагин
browse (расширение). Работаем через него, а не через встроенный браузер OpenCode.

- Инструменты: `execute` → `tools.browse.execute({ code, targetUrl?, session? })`
  (MCP-сервер `browse`). Код — строка Playwright JavaScript, внутри доступны
  `page`, `snapshot()`, `ref(id)`, `handoff("...")`.
- Сессия браузера у пользователя: логин в Битрикс сохраняется в его профиле
  Chrome, поэтому после входа вручную работа идёт без повторной авторизации.
- Если экран входа — `handoff("войдите в Битрикс")` и ждать подтверждения
  пользователя. Пароль в чат не выводить.
- Перед сессией проверять статус через `status` (relay и расширение подключены).
- Закончив, `session_reset` (или `session_delete`) свою сессию, если
  продолжения не ожидается.

Адреса:

| Что | Адрес |
|---|---|
| Портал | `https://zabota20.bitrix24.ru` |
| Задачи проекта (основная рабочая группа 1185) | `https://zabota20.bitrix24.ru/workgroups/group/1185/tasks/` |
| Мои задачи | левое меню «Задачи» (иконка ✓); прямой `/tasks/` и `/tasks/tasks/` отдают 404 |
| Разработчикам (вебхуки) | `https://zabota20.bitrix24.ru/devops/` |

Порядок работы:

1. Открыть вкладку `tools.browser.tabs.open` на нужный адрес.
2. Если показан экран входа — сессия истекла: попросить пользователя войти
   в этой же вкладке (пароль — в `credentials.local.ini`; в чат не выводить).
3. Если открылся портал — читать задачи из интерфейса.

Особенности интерфейса (проверено на портале проекта):

- Контент счётчиков и части страниц лежит в iframe с `IFRAME_TYPE=SIDE_SLIDER`
  и в `about:blank`-фрейме слайдера — искать текст через
  `iframe.contentDocument.body.innerText`, а не только в основном документе.
- Раздел «Разработчикам» → плитка «Другое» → «Входящий вебхук» (класс
  `.rest-integration-tile-item`).
- Сессия браузера хранится в профиле приложения
  (`%APPDATA%\ai.opencode.desktop`), поэтому логин переживает закрытие вкладок
  и перезапуск приложения, но не выход из аккаунта в Битриксе.

### Как вытащить задачи с канбана

Канбан проекта — это `.../workgroups/group/1185/tasks/`, по умолчанию
открывается доска с колонками (стадии и/или ответственные). Разметка:

- карточка — `.main-kanban-item`;
- колонка — `.main-kanban-column`;
- ссылка на задачу — `a[href*="/tasks/task/view/"]`, ID из `view/<id>/`.

Рабочий сниппет (в `tools.browser.evaluate`):

```js
const seen = new Map();
for (const a of document.querySelectorAll('a[href*="/tasks/task/view/"]')) {
  const id = a.getAttribute('href').match(/view\/(\d+)/)?.[1];
  if (!id || seen.has(id)) continue;
  const card = a.closest('.main-kanban-item');
  const col = a.closest('.main-kanban-column');
  seen.set(id, {
    id,
    col: (col?.innerText || '').split('\n')[0].trim(),
    text: (card?.innerText || '').replace(/\n+/g, ' | '),
  });
}
return [...seen.values()];
```

Текст карточки — это `Заголовок | #теги | приоритет | срок | затраченное время`.
Сроки приходят уже в локали портала («Сегодня, 20:00», «Завтра, 20:00»,
«Без срока», «- 1 неделя» = просрочено). На доске группы 1185 бывает ~200+
активных задач, поэтому в ответ — выжимку, а не весь список.

## Запреты по Битриксу

- **Не создавать** входящие/исходящие вебхуки и не нажимать «Создать»
  на странице вебхука. Возможно, хуки удалены намеренно, из соображений
  безопасности.
- Не менять «Настройку прав» существующих хуков и не перегенерировать токены.
- Не отправлять задачи, комментарии, не менять статусы — только чтение,
  пока пользователь отдельно не попросит.
- Всё, что просит «открыть», «сохранить», «создать» в Битриксе — сначала
  спрашивать подтверждение.

## API (если когда-нибудь разрешат)

Раздел ниже оставлен на будущее: он описывает работу через входящий вебхук.
Пока пользователь не разрешил API явно — не использовать.

### Где лежат реквизиты

Секреты **не** хранятся в этом файле и не вставляются в чат. Они лежат в:

```
.opencode/skills/bitrix24/credentials.ini
```

Формат (см. `credentials.example.ini`):

```ini
[bitrix24]
portal = https://zabota20.bitrix24.ru
user_id = 1
webhook_token = xxxxxxxxxxxxxxxxxxxxxxxx
```

Полный URL запроса собирается так:

```
{portal}/rest/{user_id}/{webhook_token}/{method}.json
```

Если пользователь присылает готовую ссылку вебхука вида
`https://zabota20.bitrix24.ru/rest/12/abc123.../` — разобрать её на
`portal` = `https://zabota20.bitrix24.ru`, `user_id` = `12`,
`webhook_token` = `abc123...` и записать в `credentials.ini`.

Портал проекта: **`https://zabota20.bitrix24.ru`**, основная рабочая группа
(проект) — **1185** (`/workgroups/group/1185/tasks/`).

Если файла нет — попроси пользователя заполнить его (сам секрет не читай вслух
и не печатай). Для методов, где нужен OAuth-токен вместо вебхука, используй
`access_token` в той же секции и передавай его параметром `auth`.

### Быстрая проверка подключения

```bash
python .opencode/skills/bitrix24/scripts/bx.py profile
python .opencode/skills/bitrix24/scripts/bx.py call user.current
```

### Готовый helper

Базовый вызов любого REST-метода:

```bash
# список задач с фильтром
python .opencode/skills/bitrix24/scripts/bx.py call tasks.task.list \
  --params '{"filter":{"RESPONSIBLE_ID":123},"select":["ID","TITLE","STATUS","DEADLINE","GROUP_ID"],"order":{"ID":"desc"}}' \
  --all

# одна задача
python .opencode/skills/bitrix24/scripts/bx.py call tasks.task.get --params '{"taskId":123}'

# комментарии задачи
python .opencode/skills/bitrix24/scripts/bx.py call task.commentitem.getlist --params '{"TASKID":123}'

# мои задачи (все страницы, вывод таблицей)
python .opencode/skills/bitrix24/scripts/bx.py my --all

# мои задачи по конкретной рабочей группе (проект 1185)
python .opencode/skills/bitrix24/scripts/bx.py my --group 1185 --all

# все задачи группы 1185 (не только мои)
python .opencode/skills/bitrix24/scripts/bx.py call tasks.task.list \
  --params '{"filter":{"GROUP_ID":1185},"select":["ID","TITLE","STATUS","RESPONSIBLE_ID","DEADLINE"],"order":{"ID":"desc"}}' --all
```

Полезные флаги: `--all` (листать по 50 до конца), `--json` (сырой JSON),
`--csv out.csv`, `--limit N`.

### Полезные методы

| Задача | Метод |
|---|---|
| Кто я / проверка вебхука | `profile` (scope + user.current) |
| Мои задачи | `my` (обёртка над `tasks.task.list` с `RESPONSIBLE_ID` = я) |
| Список задач | `tasks.task.list` |
| Одна задача с деталями | `tasks.task.get` |
| Комментарии | `task.commentitem.getlist` |
| Добавить комментарий | `task.commentitem.add` |
| Создать задачу | `tasks.task.add` |
| Изменить задачу / статус | `tasks.task.update` |
| Завершить задачу | `tasks.task.complete` |
| Справочник статусов | `tasks.task.list` c `select:["STATUS"]` или `tasks.task.get` |
| Сотрудники (для ID) | `user.get` |
| Проекты/группы | `sonet_group.get` |
| Стадии (канбан) | `task.stages.get` |

Фильтры `tasks.task.list` принимают префиксы: `=` точное, `%` подстрока,
`>`/`<`/`>=`/`<=` сравнение. Примеры:

```json
{"filter": {"STATUS": "2"}, "order": {"DEADLINE": "asc"}}
{"filter": {"%TITLE": "импорт"}, "select": ["ID", "TITLE", "STATUS"]}
{"filter": {">=DEADLINE": "2026-01-01", "<DEADLINE": "2026-02-01"}}
```

Коды статусов задачи: `1` — новая, `2` — в работе (ждёт выполнения),
`3` — ждёт контроля, `4` — завершена, `5` — отложена, `6` — отклонена.
В ответе часто приходит и `status` строкой (`new`, `in_progress`, ...).

### Правила работы

1. **По умолчанию только чтение.** Любые `tasks.task.add/update/complete`,
   комментарии и удаления — только после явного подтверждения пользователя.
2. Секреты (webhook, токен) не выводить в ответах, логах, коммитах.
   Не вставлять их в этот файл — только в `credentials.ini`.
3. Результаты тяжёлых выборок складывать в файл (`--csv`), в чат — выжимку.
4. Если запрос упирается в права (ошибка `insufficient_scope`) — сказать,
   какие scope нужны для вебхука (`task`, `tasks_extended`, `user`, `sonet_group`).
5. ID задач, сотрудников и групп — числа; не угадывать, получать из `user.get` /
   `sonet_group.get`.

### Если вебхук не подходит

- Портал self-hosted (коробка) — тот же REST, но `portal` — адрес портала,
  часто с `/rest/...` без `bitrix24.ru`.
- Есть только OAuth — тогда нужен `access_token` + `refresh_token`, время жизни
  ограничено, обновление через `oauth.bitrix.info/oauth/token/`.
- Сайт на «1С-Битрикс» (не 24) — это другой API, задачи так не читаются.
