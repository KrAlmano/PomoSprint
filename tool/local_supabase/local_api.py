"""Yerel Supabase kopyası (tool/local_supabase) için küçük HTTP yardımcıları.

Yalnızca yerel adrese bağlanır. Buradaki anahtarlar Supabase CLI'nin herkese
açık yerel demo anahtarlarıdır (her yerel kurulumda aynı); sır değildir ve
canlı projede geçmez. Test hesaplarının parolası da yalnızca bu yerel kopya
içindir.
"""

import json
import os
import urllib.error
import urllib.parse
import urllib.request

API_URL = os.environ.get("LOCAL_SUPABASE_URL", "http://127.0.0.1:54321").rstrip("/")

# `supabase status -o env --workdir tool/local_supabase` → ANON_KEY / SERVICE_ROLE_KEY
ANON_KEY = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9"
    ".CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
)

# Yerel test hesapları: test1@pomosprint.local, test2@pomosprint.local, ...
TEST_EMAIL_FORMAT = "test{}@pomosprint.local"
TEST_PASSWORD = os.environ.get("LOCAL_TEST_PASSWORD", "pomosprint-yerel-test")
LEGAL_VERSION = "2026-10-03"  # lib/widgets/auth/legal_links.dart kLegalDocumentsVersion


def _require_local():
    host = urllib.parse.urlparse(API_URL).hostname or ""
    if host not in ("127.0.0.1", "localhost", "::1") and not host.endswith(".localhost"):
        raise SystemExit(f"HATA: {API_URL} yerel değil; bu betik yalnızca yerel kopyaya bağlanır.")


_require_local()


class ApiError(Exception):
    def __init__(self, status, body):
        super().__init__(f"HTTP {status}: {body}")
        self.status = status
        self.body = body


def request(method, path, body=None, token=None, headers=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(API_URL + path, data=data, method=method)
    req.add_header("apikey", ANON_KEY)
    req.add_header("Authorization", f"Bearer {token or ANON_KEY}")
    req.add_header("Content-Type", "application/json")
    for k, v in (headers or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            raw = resp.read().decode()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            parsed = json.loads(raw)
        except ValueError:
            parsed = raw
        raise ApiError(e.code, parsed) from None


def sign_up(email, name, newsletter=False):
    """Uygulamadaki auth.signUp ile aynı metadata (SupabaseService.signUpMetadata)."""
    return request("POST", "/auth/v1/signup", {
        "email": email,
        "password": TEST_PASSWORD,
        "data": {
            "name": name,
            "avatar_id": "avatar_16_basic",
            "newsletter": newsletter,
            "marketing_consent": newsletter,
            "terms_version": LEGAL_VERSION,
            "privacy_version": LEGAL_VERSION,
            "terms_accepted_at": "2026-10-04T12:00:00.000Z",
        },
    })


def sign_in(email):
    return request("POST", "/auth/v1/token?grant_type=password", {"email": email, "password": TEST_PASSWORD})


def rpc(name, args=None, token=None):
    return request("POST", f"/rest/v1/rpc/{name}", args or {}, token=token)


def select(table, query, token):
    return request("GET", f"/rest/v1/{table}?{query}", token=token)
