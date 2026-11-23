#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Сравнение инвентарей объектов двух баз Заботы.

Зачем: кастом в клиентской базе проще всего найти сравнением с чистой.
Берём выгрузку 02_object_inventory.sql с эталона и с клиента и смотрим разницу.

Использование:
    python tools/schema_diff.py sterile.txt client.txt
    python tools/schema_diff.py sterile.txt client.txt --diff-client-only
"""
import argparse
import re
import sys
from pathlib import Path

# schema.object — так печатает 02_object_inventory.sql
LINE_RE = re.compile(r"^[A-Za-z_][\w$#]*\.[\w$#]+$")


def read_inventory(path: Path) -> dict[str, str]:
    """ключ — имя в нижнем регистре, значение — как написано в базе."""
    items: dict[str, str] = {}
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    for raw in text.splitlines():
        line = raw.strip()
        if LINE_RE.match(line):
            items.setdefault(line.lower(), line)
    return items


def main() -> int:
    p = argparse.ArgumentParser(description="Diff двух инвентарей объектов MSSQL")
    p.add_argument("etalon", type=Path, help="инвентарь эталонной (чистой) базы")
    p.add_argument("client", type=Path, help="инвентарь клиентской базы")
    p.add_argument("--limit", type=int, default=0, help="показать не больше N строк (0 — все)")
    args = p.parse_args()

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    for f in (args.etalon, args.client):
        if not f.is_file():
            print(f"нет файла: {f}")
            return 2

    et = read_inventory(args.etalon)
    cl = read_inventory(args.client)

    if not et or not cl:
        print("Одна из выгрузок пустая — проверь, что скопирован список объектов "
              "(строки вида dbo.TableName).")
        return 1

    added = sorted(cl[k] for k in cl.keys() - et.keys())      # у клиента, нет в эталоне = кастом
    removed = sorted(et[k] for k in et.keys() - cl.keys())    # в эталоне, нет у клиента = другая версия

    def show(title: str, items: list[str]) -> None:
        print(f"\n{title}: {len(items)}")
        shown = items if args.limit <= 0 else items[: args.limit]
        for name in shown:
            print(f"  {name}")
        if args.limit > 0 and len(items) > args.limit:
            print(f"  ... ещё {len(items) - args.limit}")

    print(f"эталон : {len(et)} объектов  ({args.etalon})")
    print(f"клиент : {len(cl)} объектов  ({args.client})")

    show("ТОЛЬКО У КЛИЕНТА (кастом / доработки)", added)
    show("ТОЛЬКО В ЭТАЛОНЕ (другая версия / удалено)", removed)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
