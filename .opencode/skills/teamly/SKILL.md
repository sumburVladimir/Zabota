---
name: Teamly (база знаний)
description: Корпоративная база знаний компании «Забота» на https://zabota.teamly.ru (TEAMLY). Выгрузка статей в markdown через внутренний API панели из залогиненной вкладки браузера. Используй, когда нужны регламенты, инструкции, описания продуктов или процессы компании — и когда надо обновить зеркало в docs/zabota/teamly.
---

# Teamly — корпоративная база знаний

## Что это

`https://zabota.teamly.ru` — база знаний компании (платформа TEAMLY / QSOFT).
26 пространств, ~956 статей: техподдержка, продукты, разработка, внедрение,
сервисы, онбординг, бэк-офис и т.д.

Зеркало в markdown лежит в `docs/zabota/teamly/` (индекс — `docs/zabota/teamly/README.md`).
Общее описание и структура — `docs/zabota/teamly.md`.

**Сначала смотри локальное зеркало.** В браузер иди, только если нужного нет
или нужна свежая версия статьи.

## Доступ

API-токена нет. Пользователь входит в Teamly вручную во встроенном браузере
OpenCode; работаем из залогиненной вкладки.

SPA Teamly ходит в `https://app2.teamly.ru/api/v1/...`. Обязательные условия:

- `credentials: 'include'` — cookie-сессия на домене `.teamly.ru`;
- заголовок `x-account-slug: zabota` — без него `401 unauthorized`;
- `Content-Type: application/json`.

## Эндпоинты

| Что | Запрос |
|---|---|
| Список пространств | `POST /api/v1/wiki/ql/spaces` |
| Список статей | `POST /api/v1/wiki/ql/articles` |
| Статья целиком | `GET /api/v1/wiki/articles/{id}?viewMode=edit&latestVersionAt=1` |
| Блоки/вложенные статьи | `POST /api/v1/wiki/ql/article_content` |
| Комментарии | `GET /api/v1/space/{spaceId}/article/{articleId}/comments` |

Тело `ql`-запроса:

```json
{ "query": {
    "__filter": { "space_id": "<uuid>" },
    "__pagination": { "page": 1, "per_page": 50 },
    "id": true, "title": true,
    "space": { "id": true, "title": true }
} }
```

Подводные камни (проверено):

- `per_page` максимум **50**, иначе 422.
- `__filter.space_id` **не фильтрует** выдачу и не влияет на `paginate.total`
  (везде 956). Фильтровать и дедуплицировать по `id` на клиенте.
- Статья отдаёт тело в `editorContentObject.content` — это **JSON-строка**
  документа ProseMirror, её надо распарсить и обойти дерево.
- Главные страницы пространств (11 штук) отдают **404** — у них нет контента.
- После перезагрузки страницы Teamly загруженный в неё скрипт теряется.

## Как обновить зеркало

Скрипты: `.opencode/skills/teamly/scripts/`

1. Запустить приёмник (порт 8765, пишет в `docs/zabota/teamly/`):

   ```powershell
   Start-Process python -ArgumentList ".opencode\skills\teamly\scripts\collector.py","--port","8765" -WorkingDirectory "<проект>" -WindowStyle Hidden
   ```

2. В залогиненной вкладке Teamly выполнить `browser.evaluate`:

   ```js
   (async () => {
     const res = await fetch('http://127.0.0.1:8765/raw/crawl.js?t=' + Date.now());
     new Function(await res.text())();
     window.__teamlyStart().catch(e => window.__teamlyError = String(e));
     return 'started';
   })()
   ```

   Скрипт отдаёт сам приёмник (`GET /raw/crawl.js`), поэтому в evaluate не нужно
   вставлять 7 КБ кода. Прогресс — в `window.__teamlyCrawl`, статистика файлов —
   `http://127.0.0.1:8765/stats`.

3. Пересобрать индекс: `python .opencode\skills\teamly\scripts\make_index.py`.

4. Остановить приёмник:

   ```powershell
   Get-CimInstance Win32_Process -Filter "Name='python.exe'" | Where-Object { $_.CommandLine -match 'collector.py' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
   ```

Полный прогон 956 статей занимает ~50 секунд, даёт 945 файлов (~3.6 МБ).

## Формат конвертации

`crawl.js` превращает ProseMirror в markdown: `heading`, `paragraph`,
`bulletList`, `orderedList`, `blockquote`, `codeBlock`, `horizontalRule`,
`table`, `image`, `text` с `marks` (bold / italic / code / strike / link).

Особый случай — `table`: ячейки (`tableCell` / `tableHeader`) содержат
абзацы; текст берётся как `inline(paragraph.content)`, абзацы склеиваются
пробелом, `|` экранируется, строки выравниваются по числу колонок.

Каждый файл — с YAML-frontmatter:

```
---
title: "..."
space: "..."
article_id: <uuid>
source: https://zabota.teamly.ru/at/<uuid>
---
```

## Запреты

- Пароль Teamly — в `credentials.local.ini` (в `.gitignore`); вход в браузер выполняет пользователь, в чат пароль не выводить.
- Ничего в Teamly не создавать, не редактировать, не удалять — **только чтение**.
- Не публиковать содержимое базы знаний во внешние сервисы.
- Картинки и вложения не копируются — остаются ссылками на Teamly.
