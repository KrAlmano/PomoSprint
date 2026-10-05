#!/usr/bin/env python3
"""Simülatördeki integration_test'lerin bilgisayar tarafı yardımcısı.

Uygulama (iOS simülatörü bilgisayarın ağını paylaşır) testin ortasında bu
sunucuya 127.0.0.1 üzerinden istek atar:

- ``GET /health`` → ``ok``
- ``GET /shot?name=e2e-kayit`` → ``xcrun simctl io <UDID> screenshot
  analiz/ekranlar/e2e-kayit.png`` (eşzamanlı; yanıt dosya yazılınca döner).
  Ad yalnızca ``e2e-[a-z0-9-]+`` olabilir.
- ``POST /psql`` (gövde: SQL) → yerel kopyada ``psql`` çıktısı (düz metin).
  Bağlantı yalnızca YEREL veritabanına (127.0.0.1:54322) ve salt okuma
  (``default_transaction_read_only=on``) açılır; test bununla sunucu
  durumunu doğrular. Her sorgu ve sonucu ``build/e2e_sim/psql.log``'a yazılır.

Yalnızca 127.0.0.1'e bağlanır. Çalıştırma: ``run_sim_e2e.sh`` başlatır;
elle: ``python3 tool/local_supabase/e2e/sim/e2e_host.py --port 54399``.
"""

import argparse
import datetime
import os
import re
import subprocess
import sys
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
DEFAULT_UDID = "7B8AF086-0864-42FD-B4D8-37A782C3F6B9"
DB_URL = "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
SHOT_NAME = re.compile(r"^e2e-[a-z0-9-]{1,60}$")


def _log(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "a", encoding="utf-8") as f:
        f.write(text)


class Handler(BaseHTTPRequestHandler):
    server_version = "PomoSprintE2EHost/1"

    def _reply(self, status, body, content_type="text/plain; charset=utf-8"):
        data = body.encode("utf-8") if isinstance(body, str) else body
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):  # noqa: N802 (BaseHTTPRequestHandler API)
        sys.stderr.write("[e2e_host] " + (fmt % args) + "\n")

    def do_GET(self):  # noqa: N802
        url = urllib.parse.urlparse(self.path)
        if url.path == "/health":
            return self._reply(200, "ok")
        if url.path == "/shot":
            name = (urllib.parse.parse_qs(url.query).get("name") or [""])[0]
            if not SHOT_NAME.match(name):
                return self._reply(400, "gecersiz ad")
            out = os.path.join(self.server.shot_dir, name + ".png")
            os.makedirs(self.server.shot_dir, exist_ok=True)
            if self.server.android_serial:
                proc = subprocess.run([os.path.expanduser("~/Library/Android/sdk/platform-tools/adb"),
                    "-s", self.server.android_serial, "exec-out", "screencap", "-p"],
                    capture_output=True, timeout=30)
                if proc.returncode == 0:
                    with open(out, "wb") as shot:
                        shot.write(proc.stdout)
            else:
                proc = subprocess.run(
                    ["xcrun", "simctl", "io", self.server.udid, "screenshot", out],
                    capture_output=True, text=True, timeout=60,
                )
            if proc.returncode != 0:
                return self._reply(500, proc.stderr)
            # Depoda yer kaplamasın: yarı çözünürlük (iPhone 16 Pro → 603x1311).
            subprocess.run(["sips", "-Z", "1311", out], capture_output=True, timeout=60)
            return self._reply(200, os.path.relpath(out, ROOT))
        return self._reply(404, "yok")

    def do_POST(self):  # noqa: N802
        url = urllib.parse.urlparse(self.path)
        if url.path == "/android-notifications":
            if not self.server.android_serial:
                return self._reply(403, "Android emulatore ozel")
            proc = subprocess.run([os.path.expanduser("~/Library/Android/sdk/platform-tools/adb"),
                "-s", self.server.android_serial, "shell", "pm", "grant", "com.pomosprint.app",
                "android.permission.POST_NOTIFICATIONS"], capture_output=True, text=True, timeout=15)
            return self._reply(200 if proc.returncode == 0 else 500, proc.stdout or proc.stderr)
        if url.path == "/local-api":
            if not self.server.allow_api_outage:
                return self._reply(403, "yerel API kesintisi etkin degil")
            action = self.rfile.read(int(self.headers.get("Content-Length") or 0)).decode()
            if action not in {"stop", "start"}:
                return self._reply(400, "gecersiz islem")
            proc = subprocess.run(["docker", action, "supabase_kong_pomosprint-local"],
                                  capture_output=True, text=True, timeout=30)
            return self._reply(200 if proc.returncode == 0 else 500, proc.stdout or proc.stderr)
        if url.path != "/psql":
            return self._reply(404, "yok")
        length = int(self.headers.get("Content-Length") or 0)
        sql = self.rfile.read(length).decode("utf-8")
        env = dict(os.environ, PGOPTIONS="-c default_transaction_read_only=on", PGCONNECT_TIMEOUT="10")
        proc = subprocess.run(
            ["psql", DB_URL, "-X", "-A", "-t", "-q", "-v", "ON_ERROR_STOP=1", "-c", sql],
            capture_output=True, text=True, timeout=60, env=env,
        )
        stamp = datetime.datetime.now().isoformat(timespec="seconds")
        _log(self.server.psql_log, f"-- {stamp}\n{sql.strip()}\n=> {proc.stdout.strip() or proc.stderr.strip()}\n\n")
        if proc.returncode != 0:
            return self._reply(500, proc.stderr)
        return self._reply(200, proc.stdout.strip())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--allow-api-outage", action="store_true")
    ap.add_argument("--android-serial")
    ap.add_argument("--port", type=int, default=54399)
    ap.add_argument("--udid", default=os.environ.get("SIM_UDID", DEFAULT_UDID))
    ap.add_argument("--shot-dir", default=os.path.join(ROOT, "analiz", "ekranlar"))
    ap.add_argument("--psql-log", default=os.path.join(ROOT, "build", "e2e_sim", "psql.log"))
    args = ap.parse_args()
    if args.android_serial and not args.android_serial.startswith("emulator-"):
        ap.error("Yalnizca Android emulatoru desteklenir")
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.allow_api_outage = args.allow_api_outage
    server.android_serial = args.android_serial
    server.udid = args.udid
    server.shot_dir = args.shot_dir
    server.psql_log = args.psql_log
    sys.stderr.write(f"[e2e_host] 127.0.0.1:{args.port} (sim {args.udid})\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        if args.allow_api_outage:
            subprocess.run(["docker", "start", "supabase_kong_pomosprint-local"], capture_output=True, timeout=30)


if __name__ == "__main__":
    main()
