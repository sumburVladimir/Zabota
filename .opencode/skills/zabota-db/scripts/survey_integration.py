# -*- coding: utf-8 -*-
"""Обзор папки Desktop\интеграция: разбор по датам, отдельно текст vs бинарники."""
import os
import sys
from collections import Counter

ROOT = r"C:\Users\Владимир Капов\Desktop\интеграция"
OUT = r"C:\Users\Владимир Капов\Documents\Default Project\docs\zabota\_integration_survey.txt"

TEXT_EXT = {".txt", ".sql", ".md", ".ini", ".cfg", ".conf", ".csv", ".bat",
            ".log", ".rdp", ".bun", ".docx", ".xls", ".susp"}
ARCH_EXT = {".7z", ".zip", ".rar"}

rows = []
for dirpath, dirs, files in os.walk(ROOT):
    for fn in files:
        p = os.path.join(dirpath, fn)
        try:
            st = os.stat(p)
            rows.append((st.st_mtime, st.st_size, p))
        except OSError:
            continue

rows.sort(key=lambda r: -r[0])

def year_of(ts):
    import datetime
    return datetime.datetime.fromtimestamp(ts).year

def kind(path):
    e = os.path.splitext(path)[1].lower()
    if e in ARCH_EXT:
        return "arch"
    if e in TEXT_EXT:
        return "text"
    if e in {".exe", ".dll", ".jpg", ".jpeg", ".png", ".pdf", ".db", ".xls", ".docx", ".bun"}:
        return "bin"
    return "other"

lines = []
lines.append("=== Обзор: Desktop\\интеграция ===\n")
lines.append(f"Всего файлов: {len(rows)}, суммарно {sum(r[1] for r in rows)/1024/1024/1024:.2f} ГБ\n")

by_year = Counter(year_of(r[0]) for r in rows)
by_kind = Counter(kind(r[2]) for r in rows)
lines.append("По годам (mtime): " + ", ".join(f"{y}={by_year[y]}" for y in sorted(by_year, reverse=True)) + "\n")
lines.append("По типу: " + ", ".join(f"{k}={v}" for k, v in by_kind.most_common()) + "\n")

# Топ-40 свежих текстовых файлов
lines.append("\n=== Свежие текстовые файлы (2025-11 и новее) ===\n")
import datetime
for ts, size, p in rows:
    if kind(p) != "text":
        continue
    y = year_of(ts)
    d = datetime.datetime.fromtimestamp(ts).strftime("%Y-%m-%d")
    rel = p.replace(ROOT, "").lstrip("\\")
    if y >= 2025:
        lines.append(f"{d}  {size:>9}  {rel}")
    if y < 2024:
        break

# Все текстовые 2026
lines.append("\n=== Все текстовые файлы 2026 года ===\n")
for ts, size, p in rows:
    if kind(p) != "text" or year_of(ts) != 2026:
        continue
    d = datetime.datetime.fromtimestamp(ts).strftime("%Y-%m-%d")
    rel = p.replace(ROOT, "").lstrip("\\")
    lines.append(f"{d}  {size:>9}  {rel}")

with open(OUT, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

print("wrote", OUT)
print("files", len(rows), "text", by_kind["text"], "arch", by_kind["arch"], "bin", by_kind["bin"])
