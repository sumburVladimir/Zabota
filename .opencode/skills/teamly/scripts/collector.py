#!/usr/bin/env python
"""Приёмник статей Teamly -> markdown на диск.

Запуск:  python .opencode/skills/teamly/scripts/collector.py --port 8765
Страница Teamly в браузере постит сюда готовые markdown-файлы.

POST /save  {"path": "Пространство/статья.md", "content": "..."}
GET  /health
GET  /stats
"""
import argparse
import json
import re
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4] / "docs" / "zabota" / "teamly"
ALLOW_ORIGIN = "https://zabota.teamly.ru"
BAD = re.compile(r'[<>:"/\\|?*\x00-\x1f]')
_lock = threading.Lock()
_stats = {"saved": 0, "errors": 0}


def safe_path(rel: str) -> Path:
    rel = rel.replace("\\", "/").strip("/")
    parts = [BAD.sub("_", p).strip(" .") or "_" for p in rel.split("/")]
    target = (ROOT.joinpath(*parts)).resolve()
    if ROOT.resolve() not in target.parents:
        raise ValueError("path escapes root")
    return target


class Handler(BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", ALLOW_ORIGIN)
        self.send_header("Access-Control-Allow-Credentials", "true")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Private-Network", "true")

    def _json(self, code, payload):
        body = json.dumps(payload, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self._cors()
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        if self.path.startswith("/health"):
            return self._json(200, {"ok": True, "root": str(ROOT)})
        if self.path.startswith("/stats"):
            return self._json(200, _stats)
        if self.path.startswith("/raw/"):
            name = self.path[len("/raw/"):].split("?")[0]
            src = Path(__file__).resolve().parent / name
            if name and src.is_file() and src.parent == Path(__file__).resolve().parent:
                body = src.read_bytes()
                self.send_response(200)
                self.send_header("Content-Type", "text/javascript; charset=utf-8")
                self.send_header("Content-Length", str(len(body)))
                self._cors()
                self.end_headers()
                self.wfile.write(body)
                return
            return self._json(404, {"error": "no such script"})
        self._json(404, {"error": "not found"})

    def do_POST(self):
        if not self.path.startswith("/save"):
            return self._json(404, {"error": "not found"})
        try:
            length = int(self.headers.get("Content-Length") or 0)
            data = json.loads(self.rfile.read(length) or b"{}")
            path = safe_path(data["path"])
            content = data.get("content") or ""
            with _lock:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding="utf-8", newline="\n")
                _stats["saved"] += 1
            self._json(200, {"ok": True, "path": str(path)})
        except Exception as e:  # noqa: BLE001
            with _lock:
                _stats["errors"] += 1
            self._json(400, {"error": str(e)})

    def log_message(self, *args):
        pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8765)
    args = ap.parse_args()
    ROOT.mkdir(parents=True, exist_ok=True)
    srv = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"collector on http://127.0.0.1:{args.port} -> {ROOT}", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("stopped", flush=True)
        sys.exit(0)


if __name__ == "__main__":
    main()
