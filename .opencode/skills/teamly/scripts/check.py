# -*- coding: utf-8 -*-
"""Диагностика выгрузки Teamly: пустые файлы, артефакты конвертации."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4] / "docs" / "zabota" / "teamly"
BAD = [
    ("undefined", re.compile(r"\bundefined\b")),
    ("null", re.compile(r"\[object Object\]")),
    ("двойной текст", re.compile(r"\*\*([^*]{2,40})\*\*\1")),
    ("пустой заголовок", re.compile(r"^#\s*$", re.M)),
]


def main() -> None:
    files = sorted(ROOT.rglob("*.md"))
    empty, short, bad = [], [], []
    for f in files:
        if f.name == "README.md":
            continue
        txt = f.read_text(encoding="utf-8")
        body = txt.split("---", 2)[-1].strip()
        if "_Пустое содержимое_" in txt:
            empty.append(f)
        elif len(body) < 200:
            short.append((f, len(body)))
        for name, rx in BAD:
            if rx.search(txt):
                bad.append((name, f))
    print(f"файлов: {len(files)}")
    print(f"пустых: {len(empty)}")
    for f in empty[:15]:
        print("   empty:", f.relative_to(ROOT))
    print(f"коротких (<200 симв. тела): {len(short)}")
    for f, n in short[:15]:
        print(f"   short {n:>4}: {f.relative_to(ROOT)}")
    print(f"подозрительных: {len(bad)}")
    for name, f in bad[:20]:
        print("   bad:", name, f.relative_to(ROOT))


if __name__ == "__main__":
    main()
