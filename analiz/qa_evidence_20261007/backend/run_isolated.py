"""One-off release QA harness. Only the isolated local QA DB is writable.

Uses the existing server suites without changing application or SQL code.
Auth and REST are routed to clone services, not the mobile E2E environment.
"""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[3]
DB = "postgresql://postgres:postgres@127.0.0.1:54322/pomosprint_release_qa_20261007"
PROXY = "http://127.0.0.1:54343"
os.environ["LOCAL_SUPABASE_URL"] = PROXY
os.environ["T1_RUN"] = "release1007isolated"
sys.path.insert(0, str(ROOT / "tool/local_supabase"))


class Handler(BaseHTTPRequestHandler):
    def forward(self):
        if self.path.startswith("/auth/v1/"):
            target = "http://127.0.0.1:54342" + self.path[len("/auth/v1"):]
        elif self.path.startswith("/rest/v1/"):
            target = "http://127.0.0.1:54341" + self.path[len("/rest/v1"):]
        else:
            self.send_error(404)
            return
        data = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        req = urllib.request.Request(target, data=data or None, method=self.command)
        for name in ("Content-Type", "Authorization", "apikey", "Prefer"):
            if name in self.headers:
                req.add_header(name, self.headers[name])
        try:
            response = urllib.request.urlopen(req, timeout=30)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            raw = response.read()
            self.send_response(response.status)
            self.send_header("Content-Type", response.headers.get("Content-Type", "application/json"))
            self.send_header("Content-Length", str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)

    do_POST = do_GET = do_PATCH = do_DELETE = do_PUT = forward

    def log_message(self, *_):
        pass


def load(relative):
    path = ROOT / relative
    sys.path.insert(0, str(path.parent))
    spec = importlib.util.spec_from_file_location("isolated_qa_suite", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.DB = DB
    module.PG = DB
    return module


def clean_owned_accounts():
    # Prefixes belong to the copied suites. Cleanup is restricted to the clone.
    sql = "DELETE FROM auth.users WHERE email LIKE 't1-release1007isolated-%@pomosprint.local' OR email LIKE 't2-%@pomosprint.local' OR email LIKE 'qa-social-%@pomosprint.local';"
    subprocess.run(["psql", DB, "-Xq", "-v", "ON_ERROR_STOP=1", "-c", sql], check=True)


server = ThreadingHTTPServer(("127.0.0.1", 54343), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    suite = sys.argv[1]
    if suite == "t1":
        module = load("tool/local_supabase/e2e/t1_seans_puan/t1_server_e2e.py")
    elif suite == "t2":
        module = load("tool/local_supabase/e2e/t2_onboarding_categories/e2e_onboarding_categories.py")
    elif suite == "social":
        # This suite executes on import and only calls the routed API.
        module = load("tool/local_supabase/e2e/social_safety_test.py")
    elif suite == "avatar":
        module = load("tool/local_supabase/e2e/t4_league_avatar/05_client_contract.py")
    elif suite == "auth_mail":
        source = ROOT / "tool/local_supabase/e2e/auth_mail_test.py"
        # The original suite hardcodes its DB and link port; adapt only
        # those local endpoints while retaining every original assertion.
        code = source.read_text().replace("postgresql://postgres:postgres@127.0.0.1:54322/postgres", DB)
        code = code.replace("u.port == 54321", "u.port == 54342")
        exec(compile(code, str(source), "exec"), {"__name__": "isolated_qa_suite", "__file__": str(source)})
        module = None
    else:
        raise SystemExit("Use t1, t2, social, avatar or auth_mail")
    if suite not in ("social", "auth_mail"):
        status = module.main()
        raise SystemExit(status or 0)
finally:
    clean_owned_accounts()
    server.shutdown()
