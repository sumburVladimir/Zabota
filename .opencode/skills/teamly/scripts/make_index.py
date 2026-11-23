# -*- coding: utf-8 -*-
"""Собирает docs/zabota/teamly/README.md — индекс выгрузки Teamly."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4] / "docs" / "zabota" / "teamly"


def read_meta(f: Path):
    head = f.read_text(encoding="utf-8")[:2000]
    m_title = re.search(r'^title: (".*")$', head, re.M)
    m_id = re.search(r"^article_id: (\S+)$", head, re.M)
    title = json.loads(m_title.group(1)) if m_title else f.stem
    return title, (m_id.group(1) if m_id else "")


def main() -> None:
    spaces = []
    for d in sorted((p for p in ROOT.iterdir() if p.is_dir()), key=lambda p: p.name.lower()):
        items = []
        for f in sorted(d.glob("*.md"), key=lambda p: p.name.lower()):
            title, aid = read_meta(f)
            items.append((title, f.name, aid))
        if items:
            spaces.append((d.name, items))

    total = sum(len(i) for _, i in spaces)
    out = []
    out.append("# Teamly — зеркало базы знаний\n\n")
    out.append("Корпоративная база знаний (TEAMLY, `https://zabota.teamly.ru`) в markdown.\n")
    out.append(f"Выгружено {len(spaces)} пространств, {total} статей.\n\n")
    out.append("Оригинал любой статьи открывается по ссылке `https://zabota.teamly.ru/at/<id>`.\n\n")
    out.append("## Как это сделано\n\n")
    out.append("Через внутренний JSON API панели из залогиненной вкладки браузера:\n")
    out.append("`POST https://app2.teamly.ru/api/v1/wiki/ql/articles` — список,\n")
    out.append("`GET /api/v1/wiki/articles/{id}?viewMode=edit` — тело статьи.\n")
    out.append("Контент приходит как ProseMirror-JSON и конвертируется в markdown\n")
    out.append("скриптом `.opencode/skills/teamly/scripts/crawl.js`; файлы на диск пишет\n")
    out.append("локальный приёмник `collector.py`. Подробности — в [../teamly.md](../teamly.md).\n\n")
    out.append("Ограничения: картинки и вложения не копируются, остаются ссылками на Teamly.\n")
    out.append("11 заглушек — главные страницы пространств без контента — отдают 404.\n\n")
    out.append("## Пространства\n\n| Пространство | Статей |\n|---|---|\n")
    for name, items in sorted(spaces, key=lambda s: -len(s[1])):
        out.append(f"| {name} | {len(items)} |\n")
    out.append("\n## Оглавление\n")
    for name, items in sorted(spaces, key=lambda s: (-len(s[1]), s[0].lower())):
        out.append(f"\n### {name} ({len(items)})\n\n")
        for title, fname, aid in sorted(items, key=lambda x: x[0].lower()):
            link = f"{name}/{fname}".replace(" ", "%20").replace("(", "%28").replace(")", "%29")
            out.append(f"- [{title}]({link}) — [оригинал](https://zabota.teamly.ru/at/{aid})\n")
    (ROOT / "README.md").write_text("".join(out), encoding="utf-8", newline="\n")

    print(f"spaces={len(spaces)} articles={total}")
    for name, items in sorted(spaces, key=lambda s: -len(s[1])):
        print(f"{len(items):>4}  {name}")


if __name__ == "__main__":
    main()
