#!/usr/bin/env python
"""Bitrix24 REST helper: profile / my / call <method> --params '<json>'.

Credentials: .opencode/skills/bitrix24/credentials.ini
    [bitrix24]
    portal = https://xxx.bitrix24.ru
    user_id = 1
    webhook_token = abc...

Examples:
    bx.py profile
    bx.py my --all --csv tasks.csv
    bx.py call tasks.task.get --params '{"taskId": 123}'
"""
import argparse
import configparser
import csv
import json
import sys
from pathlib import Path

import requests

HERE = Path(__file__).resolve().parent
CRED = HERE.parent / "credentials.ini"
TIMEOUT = 30
PAGE = 50


def load_creds():
    if not CRED.exists():
        sys.exit(f"Нет файла с реквизитами: {CRED}\n"
                 f"Скопируй credentials.example.ini -> credentials.ini и заполни.")
    cp = configparser.ConfigParser()
    cp.read(CRED, encoding="utf-8")
    if "bitrix24" not in cp:
        sys.exit(f"В {CRED} нет секции [bitrix24]")
    s = cp["bitrix24"]
    portal = (s.get("portal") or "").rstrip("/")
    uid = (s.get("user_id") or "").strip()
    token = (s.get("webhook_token") or "").strip()
    access = (s.get("access_token") or "").strip()
    if not portal:
        sys.exit("В credentials.ini не задан portal")
    if not access and not (uid and token):
        sys.exit("Нужен либо access_token, либо user_id + webhook_token")
    return portal, uid, token, access


def base_url(creds, method):
    portal, uid, token, access = creds
    if access:
        return f"{portal}/rest/{method}.json"
    return f"{portal}/rest/{uid}/{token}/{method}.json"


def call(creds, method, params=None):
    params = dict(params or {})
    if creds[3]:
        params.setdefault("auth", creds[3])
    url = base_url(creds, method)
    r = requests.post(url, json=params, timeout=TIMEOUT)
    if r.status_code != 200:
        sys.exit(f"HTTP {r.status_code}: {r.text[:500]}")
    data = r.json()
    if isinstance(data, dict) and data.get("error"):
        sys.exit(f"API error {data.get('error')}: {data.get('error_description')}")
    return data.get("result", data) if isinstance(data, dict) else data


def call_all(creds, method, params=None, limit=None):
    params = dict(params or {})
    params["start"] = 0
    out, seen = [], 0
    while True:
        res = call(creds, method, params)
        if isinstance(res, dict):
            items = res.get("tasks") or res.get("result") or []
        else:
            items = res
        if not isinstance(items, list):
            return items
        out.extend(items)
        seen += len(items)
        if limit and seen >= limit:
            return out[:limit]
        if isinstance(res, dict) and "next" in res:
            params["start"] = res["next"]
            continue
        if len(items) < PAGE:
            break
        params["start"] = params["start"] + PAGE
    return out


def profile(creds):
    out = {}
    try:
        out["app_info"] = call(creds, "app.info")
    except SystemExit:
        pass
    out["user"] = call(creds, "user.current")
    return out


def my_tasks(creds, group=None, all_pages=False, limit=None):
    user = call(creds, "user.current")
    uid = user.get("ID")
    flt = {"RESPONSIBLE_ID": uid, "STATUS": [1, 2, 3]}
    if group:
        flt["GROUP_ID"] = int(group)
    params = {
        "filter": flt,
        "select": ["ID", "TITLE", "STATUS", "DEADLINE", "GROUP_ID",
                   "CREATED_DATE", "PRIORITY"],
        "order": {"DEADLINE": "asc"},
    }
    if all_pages or limit:
        return call_all(creds, "tasks.task.list", params, limit or (None if all_pages else 50))
    return call(creds, "tasks.task.list", params)


def flatten(rows):
    if not isinstance(rows, list):
        return rows
    flat = []
    for row in rows:
        item = dict(row)
        for key in ("status", "responsible", "creator", "group"):
            v = item.get(key)
            if isinstance(v, dict):
                item[key] = v.get("name") or v.get("title") or v.get("id")
        flat.append(item)
    return flat


def print_table(rows):
    rows = flatten(rows)
    if not isinstance(rows, list) or not rows:
        print(json.dumps(rows, ensure_ascii=False, indent=2))
        return
    keys = [k for k in rows[0].keys()]
    widths = {k: max(len(k), *(len(str(r.get(k, ""))[:60]) for r in rows)) for k in keys}
    print(" | ".join(k.ljust(widths[k]) for k in keys))
    print("-+-".join("-" * widths[k] for k in keys))
    for r in rows:
        print(" | ".join(str(r.get(k, ""))[:60].ljust(widths[k]) for k in keys))


def dump_csv(rows, path):
    rows = flatten(rows)
    if not isinstance(rows, list) or not rows:
        sys.exit("Нечего сохранять")
    keys = list(rows[0].keys())
    with open(path, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=keys, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    print(f"Сохранено {len(rows)} строк -> {path}")


def main():
    ap = argparse.ArgumentParser(description="Bitrix24 REST helper")
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("profile", help="проверить вебхук и показать текущего пользователя")

    p_my = sub.add_parser("my", help="мои активные задачи")
    p_my.add_argument("--group", type=int, help="ID рабочей группы/проекта")

    p_call = sub.add_parser("call", help="произвольный REST-метод")
    p_call.add_argument("method")
    p_call.add_argument("--params", default="{}", help="JSON параметров")

    for p in (p_my, p_call):
        p.add_argument("--all", action="store_true", dest="all_pages")
        p.add_argument("--limit", type=int)
        p.add_argument("--json", action="store_true")
        p.add_argument("--csv")

    args = ap.parse_args()
    creds = load_creds()

    if args.cmd == "profile":
        print(json.dumps(profile(creds), ensure_ascii=False, indent=2))
        return

    if args.cmd == "my":
        rows = my_tasks(creds, group=args.group, all_pages=args.all_pages, limit=args.limit)
    else:
        try:
            params = json.loads(args.params)
        except json.JSONDecodeError as e:
            sys.exit(f"Плохой JSON в --params: {e}")
        rows = (call_all(creds, args.method, params, args.limit)
                if args.all_pages else call(creds, args.method, params))

    if getattr(args, "csv", None):
        dump_csv(rows, args.csv)
    elif getattr(args, "json", False):
        print(json.dumps(rows, ensure_ascii=False, indent=2))
    else:
        print_table(rows)


if __name__ == "__main__":
    main()
