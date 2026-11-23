#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Helper for the Zabota MSSQL database.

Usage:
    python db.py -c "SELECT TOP 10 * FROM patients"
    python db.py --db zabota -c "SELECT name FROM sys.tables"
    python db.py --file query.sql --csv out.csv
    python db.py -c "SELECT ..." --json
"""
import argparse
import configparser
import csv
import json
import sys
from pathlib import Path

import pyodbc

# Секреты читаются из локального файла (в .gitignore), см. credentials.local.ini.
CRED_FILE = Path(__file__).resolve().parents[4] / "credentials.local.ini"

SERVER = r"USERPC\ZABOTASQLSERVER1"
USER = "sa"
PASSWORD = "Hj61jaz4Kaz"
DRIVER = "ODBC Driver 17 for SQL Server"
DEFAULT_DB = "wellness_new"


def _load_credentials():
    if not CRED_FILE.is_file():
        return
    cfg = configparser.RawConfigParser()
    cfg.read(CRED_FILE, encoding="utf-8")
    sec = cfg["mssql"] if cfg.has_section("mssql") else None
    if sec is None:
        return
    global SERVER, USER, PASSWORD, DRIVER, DEFAULT_DB
    SERVER = sec.get("server", SERVER)
    USER = sec.get("user", USER)
    PASSWORD = sec.get("password", PASSWORD)
    DRIVER = sec.get("driver", DRIVER)
    DEFAULT_DB = sec.get("database", DEFAULT_DB)


_load_credentials()


def connect(db: str):
    conn = (
        f"DRIVER={{{DRIVER}}};"
        f"SERVER={SERVER};"
        f"UID={USER};PWD={PASSWORD};"
        f"DATABASE={db};"
        "TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn, timeout=15)


def main() -> int:
    p = argparse.ArgumentParser(description="Query the Zabota MSSQL database")
    p.add_argument("-c", "--command", help="SQL query to execute")
    p.add_argument("-f", "--file", help="Path to a .sql file")
    p.add_argument("--db", default=DEFAULT_DB, help=f"Database (default: {DEFAULT_DB})")
    p.add_argument("--csv", help="Write result to this CSV file")
    p.add_argument("--json", action="store_true", help="Print result as JSON")
    p.add_argument("--max-rows", type=int, default=200, help="Max rows printed (default 200)")
    args = p.parse_args()

    if not args.command and not args.file:
        p.error("provide -c/--command or -f/--file")

    sql = args.command
    if args.file:
        with open(args.file, "r", encoding="utf-8") as fh:
            sql = fh.read()

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    cn = connect(args.db)
    try:
        cur = cn.cursor()
        cur.execute(sql)

        if cur.description is None:
            print(f"OK, rows affected: {cur.rowcount}")
            cn.commit()
            return 0

        columns = [d[0] for d in cur.description]
        rows = cur.fetchmany(args.max_rows)

        if args.csv:
            with open(args.csv, "w", encoding="utf-8-sig", newline="") as fh:
                w = csv.writer(fh)
                w.writerow(columns)
                w.writerows(rows)
            print(f"Saved {len(rows)} rows to {args.csv}")
            return 0

        if args.json:
            print(json.dumps(
                [dict(zip(columns, r)) for r in rows],
                ensure_ascii=False, default=str, indent=2,
            ))
            return 0

        print("\t".join(columns))
        print("-" * 60)
        for r in rows:
            print("\t".join("NULL" if v is None else str(v) for v in r))
        print(f"\n({len(rows)} rows shown)")
        return 0
    finally:
        cn.close()


if __name__ == "__main__":
    raise SystemExit(main())
