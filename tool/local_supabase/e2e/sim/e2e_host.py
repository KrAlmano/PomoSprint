#!/usr/bin/env python3
"""Simülatördeki integration_test'lerin bilgisayar tarafı yardımcısı.

Uygulama (iOS simülatörü bilgisayarın ağını paylaşır) testin ortasında bu
sunucuya 127.0.0.1 üzerinden istek atar:

- ``GET /health`` → ``ok``
- ``POST /confirm-email`` (JSON: yalnız ``email``) → yerel Mailpit'teki
  kayıt doğrulama bağlantısını yönlendirmeyi takip etmeden açar.
- ``GET /shot?name=e2e-kayit`` → ``xcrun simctl io <UDID> screenshot
  analiz/ekranlar/e2e-kayit.png`` (eşzamanlı; yanıt dosya yazılınca döner).
  Ad yalnızca ``e2e-[a-z0-9-]+`` olabilir.
- ``POST /psql`` (gövde: SQL) → yerel kopyada ``psql`` çıktısı (düz metin).
  Bağlantı yalnızca YEREL veritabanına (127.0.0.1:54322) ve salt okuma
  (``default_transaction_read_only=on``) açılır; test bununla sunucu
  durumunu doğrular. Her sorgu ve sonucu ``build/e2e_sim/psql.log``'a yazılır.

Yalnızca 127.0.0.1'e bağlanır. Çalıştırma: ``run_sim_e2e.sh`` başlatır;
elle: ``python3 tool/local_supabase/e2e/sim/e2e_host.py --udid <UDID> --port 54399``.
"""

import argparse
import datetime
import json
import os
import re
import struct
import subprocess
import sys
import tempfile
import urllib.parse
import zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from local_mailpit import ConfirmationError, confirm_local_email
from local_recovery import RecoveryError, reset_local_password

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))
DB_URL = "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
SHOT_NAME = re.compile(r"^e2e-[a-z0-9-]{1,60}$")
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class ScreenshotError(Exception):
    """A fixed public error code, never subprocess output or device details."""


def png_dimensions(path):
    """Validate a complete PNG container before counting it as evidence."""
    try:
        with open(path, "rb") as source:
            data = source.read(64 * 1024 * 1024 + 1)
    except FileNotFoundError:
        raise ScreenshotError("screenshot_invalid_png") from None
    if len(data) > 64 * 1024 * 1024 or not data.startswith(PNG_SIGNATURE):
        raise ScreenshotError("screenshot_invalid_png")
    offset = len(PNG_SIGNATURE)
    dimensions = None
    saw_image_data = False
    while offset + 12 <= len(data):
        size = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4:offset + 8]
        end = offset + 12 + size
        if end > len(data):
            break
        payload = data[offset + 8:offset + 8 + size]
        checksum = struct.unpack_from(">I", data, offset + 8 + size)[0]
        if zlib.crc32(kind + payload) & 0xffffffff != checksum:
            break
        if dimensions is None:
            if kind != b"IHDR" or size != 13:
                break
            width, height = struct.unpack_from(">II", payload)
            if not (0 < width <= 16384 and 0 < height <= 16384
                    and width * height <= 64 * 1024 * 1024):
                break
            dimensions = (width, height)
        elif kind == b"IHDR":
            break
        if kind == b"IDAT" and size:
            saw_image_data = True
        if kind == b"IEND":
            if size == 0 and end == len(data) and saw_image_data:
                return dimensions
            break
        offset = end
    raise ScreenshotError("screenshot_invalid_png")


def capture_screenshot(server, name):
    """Publish only a new, validated capture; retain previous good evidence."""
    temporary = None
    try:
        os.makedirs(server.shot_dir, exist_ok=True)
        # A fresh name prevents an rc=0 capture that wrote nothing from reusing
        # an older successful image. Atomic replacement happens only at the end.
        fd, temporary = tempfile.mkstemp(prefix=".capture-", suffix=".png", dir=server.shot_dir)
        os.close(fd)
        os.unlink(temporary)
        try:
            if server.android_serial:
                proc = subprocess.run([os.path.expanduser("~/Library/Android/sdk/platform-tools/adb"),
                    "-s", server.android_serial, "exec-out", "screencap", "-p"],
                    capture_output=True, timeout=30)
                if proc.returncode == 0:
                    with open(temporary, "wb") as output:
                        output.write(proc.stdout)
            else:
                proc = subprocess.run(
                    ["xcrun", "simctl", "io", server.udid, "screenshot", temporary],
                    capture_output=True, timeout=60,
                )
        except subprocess.TimeoutExpired:
            raise ScreenshotError("screenshot_capture_timeout") from None
        if proc.returncode != 0:
            raise ScreenshotError("screenshot_capture_failed")
        png_dimensions(temporary)
        try:
            resize = subprocess.run(["sips", "-Z", "1311", temporary],
                                    capture_output=True, timeout=60)
        except subprocess.TimeoutExpired:
            raise ScreenshotError("screenshot_resize_timeout") from None
        if resize.returncode != 0:
            raise ScreenshotError("screenshot_resize_failed")
        png_dimensions(temporary)
        out = os.path.join(server.shot_dir, name + ".png")
        os.replace(temporary, out)
        return os.path.relpath(out, ROOT)
    except OSError:
        raise ScreenshotError("screenshot_io_error") from None
    finally:
        if temporary is not None:
            try:
                os.unlink(temporary)
            except OSError:
                pass


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
        # A malformed caller must not be able to put a token in the access log.
        safe_args = tuple(re.sub(r"\?[^\s\"]*", "?[redacted]", arg) if isinstance(arg, str) else arg for arg in args)
        sys.stderr.write("[e2e_host] " + (fmt % safe_args) + "\n")

    def do_GET(self):  # noqa: N802
        url = urllib.parse.urlparse(self.path)
        if url.path == "/health":
            return self._reply(200, "ok")
        if url.path == "/shot":
            name = (urllib.parse.parse_qs(url.query).get("name") or [""])[0]
            if not SHOT_NAME.fullmatch(name):
                return self._reply(400, "gecersiz ad")
            try:
                return self._reply(200, capture_screenshot(self.server, name))
            except ScreenshotError as failure:
                return self._reply(500, str(failure))
        return self._reply(404, "yok")

    def do_POST(self):  # noqa: N802
        url = urllib.parse.urlparse(self.path)
        if url.path == '/recover-password':
            try:
                self.connection.settimeout(5)
                length = int(self.headers.get('Content-Length', '0'))
                if (url.query or self.headers.get('Origin') is not None
                        or not 0 < length <= 8192
                        or self.headers.get_content_type() != 'application/json'):
                    raise RecoveryError('invalid_recovery_request')
                body = json.loads(self.rfile.read(length))
                if not isinstance(body, dict) or set(body) != {'email', 'password', 'anon_key'}:
                    raise RecoveryError('invalid_recovery_request')
                changed = reset_local_password(body['email'], body['password'], body['anon_key'])
                return self._reply(200, json.dumps({'changed': changed}), 'application/json')
            except (ValueError, UnicodeDecodeError):
                error = 'invalid_recovery_request'
            except (RecoveryError, ConfirmationError) as failure:
                error = str(failure)
            except OSError:
                error = 'recovery_unavailable'
            return self._reply(400 if error.startswith(('invalid_', 'recipient_')) else 503,
                               json.dumps({'changed': False, 'error': error}), 'application/json')
        if url.path == "/confirm-email":
            try:
                self.connection.settimeout(5)
                length = int(self.headers.get("Content-Length", "0"))
                if (url.query or not 0 < length <= 512
                        or self.headers.get_content_type() != "application/json"):
                    raise ConfirmationError("invalid_confirmation_request")
                body = json.loads(self.rfile.read(length))
                if not isinstance(body, dict) or set(body) != {"email"}:
                    raise ConfirmationError("invalid_confirmation_request")
                confirmed = confirm_local_email(body["email"])
                return self._reply(200, json.dumps({"confirmed": confirmed}), "application/json")
            except (ValueError, UnicodeDecodeError):
                error = "invalid_confirmation_request"
            except ConfirmationError as failure:
                error = str(failure)
            except OSError:
                error = "confirmation_request_timeout"
            status = 400 if error.startswith(("invalid_", "recipient_")) else 503
            return self._reply(status, json.dumps({"confirmed": False, "error": error}), "application/json")
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
    device = ap.add_mutually_exclusive_group(required=True)
    device.add_argument("--android-serial")
    ap.add_argument("--port", type=int, default=54399)
    device.add_argument("--udid")
    ap.add_argument("--shot-dir", default=os.path.join(ROOT, "analiz", "ekranlar"))
    ap.add_argument("--psql-log", default=os.path.join(ROOT, "build", "e2e_sim", "psql.log"))
    args = ap.parse_args()
    if args.android_serial and not re.fullmatch(r"emulator-[0-9]+", args.android_serial):
        ap.error("Yalnizca Android emulatoru desteklenir")
    if args.udid and not re.fullmatch(r"[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}", args.udid):
        ap.error("Gecerli bir iOS simulator UDID gerekli")
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.allow_api_outage = args.allow_api_outage
    server.android_serial = args.android_serial
    server.udid = args.udid
    server.shot_dir = args.shot_dir
    server.psql_log = args.psql_log
    sys.stderr.write(f"[e2e_host] 127.0.0.1:{args.port} (device {args.udid or args.android_serial})\n")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        if args.allow_api_outage:
            subprocess.run(["docker", "start", "supabase_kong_pomosprint-local"], capture_output=True, timeout=30)


if __name__ == "__main__":
    main()
