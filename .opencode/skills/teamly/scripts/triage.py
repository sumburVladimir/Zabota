# -*- coding: utf-8 -*-
"""Триаж выгрузки Teamly: список файлов по размеру для трёх пространств."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4] / "docs" / "zabota" / "teamly"
DIRS = ["Техническая поддержка", "Продукты", "Разработка"]
OUT = Path(__file__).resolve().parents[4] / "docs" / "zabota" / "_triage.json"


def title_of(f: Path) -> str:
    head = f.read_text(encoding="utf-8")[:1200]
    m = re.search(r'^title: (".*")$', head, re.M)
    return json.loads(m.group(1)) if m else f.stem


def main() -> None:
    res = {}
    for d in DIRS:
        dirp = ROOT / d
        items = []
        for f in dirp.glob("*.md"):
            items.append({"name": f.name, "size": f.stat().st_size, "title": title_of(f)})
        items.sort(key=lambda x: -x["size"])
        res[d] = items
    OUT.write_text(json.dumps(res, ensure_ascii=False, indent=1), encoding="utf-8")
    for d, items in res.items():
        big = sum(1 for i in items if i["size"] > 4000)
        mid = sum(1 for i in items if 800 <= i["size"] <= 4000)
        small = sum(1 for i in items if i["size"] < 800)
        print(f"{d}: всего={len(items)} крупных(>4КБ)={big} средних={mid} заглушек(<800б)={small}")


if __name__ == "__main__":
    main()
