"""Fixed-loopback HTTP/SQL helpers for explicitly labelled local QA fixtures."""
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.request
from uuid import UUID

ROOT = Path(__file__).resolve().parents[3]
API = 'http://127.0.0.1:54321'
DB = 'postgresql://postgres:postgres@127.0.0.1:54322/postgres'
ANON = ('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9'
        '.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0')


class FixtureError(Exception):
    pass


def require_local():
    if os.environ.get('LOCAL_SUPABASE_URL', API) != API or os.environ.get('LOCAL_DB_URL', DB) != DB:
        raise FixtureError('Only the fixed loopback local Supabase is permitted')


def password():
    # Public local-only test constant, not a dotenv or production credential.
    source = (ROOT/'integration_test/support/e2e.dart').read_text()
    return re.search(r"kE2ePassword = '([^']+)'", source).group(1)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def request(method, path, body=None, token=None):
    require_local()
    if not path.startswith(('/auth/v1/', '/rest/v1/')) or '://' in path or '\n' in path:
        raise FixtureError('Invalid local API path')
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(API+path, data=data, method=method, headers={
        'apikey': ANON, 'Authorization': 'Bearer '+(token or ANON), 'Content-Type': 'application/json',
    })
    opener = urllib.request.build_opener(NoRedirect(), urllib.request.ProxyHandler({}))
    try:
        with opener.open(request, timeout=15) as response:
            raw = response.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        status = error.code
        error.close()
        raise FixtureError(f'Local {method} {path.split("?")[0]} failed (HTTP {status}); no response tokens logged') from None
    except (OSError, ValueError):
        raise FixtureError('Local API unavailable or invalid response') from None


def rpc(name, args=None, token=None):
    if not re.fullmatch(r'[a-z_]+', name):
        raise FixtureError('Invalid RPC name')
    return request('POST', '/rest/v1/rpc/'+name, args or {}, token)


def sign_in(email):
    return request('POST', '/auth/v1/token?grant_type=password', {'email': email, 'password': password()})


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


def sql(body):
    require_local()
    result = subprocess.run(['psql', DB, '-XqAt', '-v', 'ON_ERROR_STOP=1', '-c', body],
                            capture_output=True, text=True, timeout=20)
    if result.returncode:
        raise FixtureError('Local fixture SQL failed; no row or token content logged')
    return result.stdout.strip()


def assert_qa_owner(uid, email):
    require_local()
    if str(UUID(uid)) != uid or not re.fullmatch(r'(?:qa-i08-|e2e-sim-)[a-z0-9._+-]+@pomosprint\.local', email):
        raise FixtureError('Only explicitly named new local QA owners are accepted')
    found = sql(f"select count(*) from auth.users where id={literal(uid)}::uuid and email={literal(email)} and created_at>=now()-interval '24 hours'")
    if found != '1':
        raise FixtureError('QA owner id/email/recent creation check failed')
