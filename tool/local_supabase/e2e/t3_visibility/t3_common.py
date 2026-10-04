"""t3 (hesaplar arası görünürlük ve güvenlik) E2E betiklerinin ortak yardımcıları.

Yalnızca yerel Supabase kopyasına (127.0.0.1:54321 / :54322) bağlanır.
Hesaplar: t3-a .. t3-e@pomosprint.local. test1/test2 ve başka ajanların
hesaplarına dokunulmaz.
"""

import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..")))

import local_api as api  # noqa: E402

DB_URL = "postgresql://postgres:postgres@127.0.0.1:54322/postgres"

USERS = {
    "A": ("t3-a@pomosprint.local", "Ayse Tetik"),
    "B": ("t3-b@pomosprint.local", "Bora Uslu"),
    "C": ("t3-c@pomosprint.local", "Cem"),
    "D": ("t3-d@pomosprint.local", "Deniz Kaya Er"),
    "E": ("t3-e@pomosprint.local", "Ece Su"),
}

RESULTS = []


def check(cid, ok, desc, detail=""):
    RESULTS.append((cid, bool(ok), desc, detail))
    mark = "OK  " if ok else "FAIL"
    print(f"[{mark}] {cid}: {desc}" + (f"  -> {detail}" if detail and not ok else ""))
    return ok


def info(cid, desc, detail=""):
    """Bulgu niteliğinde gözlem (beklenen güvenli davranış DEĞİL)."""
    RESULTS.append((cid, None, desc, detail))
    print(f"[NOTE] {cid}: {desc}" + (f"  -> {detail}" if detail else ""))


def call(method, path, body=None, token=None, headers=None):
    try:
        return 200, api.request(method, path, body, token, headers)
    except api.ApiError as e:
        return e.status, e.body


def rpc(name, args=None, token=None):
    return call("POST", f"/rest/v1/rpc/{name}", args or {}, token)


def err_code(body):
    return body.get("code") if isinstance(body, dict) else None


def psql(sql, on_error_stop=True):
    cmd = ["psql", DB_URL, "-X", "-q", "-At", "-v", f"ON_ERROR_STOP={1 if on_error_stop else 0}", "-f", "-"]
    env = dict(os.environ, PGPASSWORD="postgres")
    out = subprocess.run(cmd, input=sql, capture_output=True, text=True, env=env)
    if on_error_stop and out.returncode != 0:
        raise SystemExit(f"psql hatası:\n{out.stderr}")
    return out.stdout, out.stderr


def ensure_users():
    users = {}
    for key, (email, name) in USERS.items():
        try:
            api.sign_up(email, name)
        except api.ApiError as e:
            code = e.body.get("error_code") if isinstance(e.body, dict) else None
            if code not in ("user_already_exists", "email_exists"):
                raise
        s = api.sign_in(email)
        token, uid = s["access_token"], s["user"]["id"]
        prof = api.select("profiles", "select=id,name,friend_code", token)
        users[key] = {"email": email, "name": name, "token": token, "uid": uid, "code": prof[0]["friend_code"]}
    return users


def reset_state(users):
    """Yalnızca t3 hesaplarının arkadaşlık/canlı seans/görünürlük durumunu sıfırlar."""
    ids = ",".join(f"'{u['uid']}'" for u in users.values())
    sql = f"""
    delete from public.friendships where user_id in ({ids}) or friend_id in ({ids});
    update public.profiles p set show_in_social_feed = true, active_session_ends_at = null,
           active_session_category_name = null where p.id in ({ids});
    """
    for key, u in users.items():
        sql += f"update public.profiles set name = '{u['name']}' where id = '{u['uid']}';\n"
    psql(sql)


def summary():
    fails = [r for r in RESULTS if r[1] is False]
    notes = [r for r in RESULTS if r[1] is None]
    oks = [r for r in RESULTS if r[1] is True]
    print(f"\nÖzet: {len(oks)} OK, {len(fails)} FAIL, {len(notes)} NOTE")
    for r in fails:
        print(f"  FAIL {r[0]}: {r[2]} -> {r[3]}")
    for r in notes:
        print(f"  NOTE {r[0]}: {r[2]} -> {r[3]}")
    return 1 if fails else 0


def dump_json(obj):
    return json.dumps(obj, ensure_ascii=False)[:400]
