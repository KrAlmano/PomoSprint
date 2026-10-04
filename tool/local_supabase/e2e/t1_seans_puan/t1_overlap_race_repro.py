#!/usr/bin/env python3
"""t1 bulgu repro: complete_study_session çakışma denetimi eşzamanlı isteklerde atlanıyor.

Yalnızca yerel kopya. Yeni bir t1- hesabı açar, aynı 25 dakikalık aralık için
N paralel istek gönderir (iki cihazın aynı anda biten seansları gibi) ve kaç
tanesinin kabul edildiğini, profil/lig toplamlarını yazar.

    python3 tool/local_supabase/e2e/t1_seans_puan/t1_overlap_race_repro.py [N=2]

Beklenen: 1 kabul + (N-1) × {"error":"overlap"}.
Gerçek (canlı gövde): N kabul; puan/kum/lig N katı, study_sessions'ta çakışan satırlar.
Neden: overlap SELECT'i profiles ... FOR UPDATE kilidinden ÖNCE çalışıyor; bekleyen
istek kilidi alınca çakışmayı yeniden denetlemiyor ve kendi satırını ekliyor.
"""

import datetime as dt
import os
import subprocess
import sys
import threading
import time
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..")))
import local_api as api  # noqa: E402

DB = "postgresql://postgres:postgres@127.0.0.1:54322/postgres"


def psql(sql):
    return subprocess.run(["psql", DB, "-XAtq", "-c", sql], capture_output=True, text=True, check=True).stdout.strip()


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 2
    email = f"t1-race-{time.strftime('%m%d%H%M%S')}@pomosprint.local"
    api.sign_up(email, "T1 race")
    s = api.sign_in(email)
    tok, uid = s["access_token"], s["user"]["id"]
    api.rpc("setup_onboarding_categories", {"p_categories": [{"name": "Matematik", "color_hex": "#EF4444", "icon_name": "calculate"}]}, tok)
    cat = api.select("categories", "select=id", tok)[0]["id"]
    started = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=30)).strftime("%Y-%m-%dT%H:%M:%S.%fZ")
    out = [None] * n

    def fire(i):
        try:
            out[i] = api.rpc("complete_study_session", {
                "p_client_uuid": str(uuid.uuid4()), "p_category_id": cat, "p_duration_minutes": 25,
                "p_was_paused": False, "p_is_verified": 1500, "p_started_at": started}, tok)
        except api.ApiError as e:
            out[i] = f"HATA {e}"

    threads = [threading.Thread(target=fire, args=(i,)) for i in range(n)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    accepted = sum(1 for r in out if isinstance(r, dict) and "error" not in r)
    print(f"kullanıcı {email}  aynı aralık için {n} paralel istek → kabul: {accepted}, overlap: {sum(1 for r in out if r == {'error': 'overlap'})}")
    print(psql(f"select 'profil: lifetime_points=' || lifetime_points || ' coins=' || coins || ' total_minutes=' || total_minutes from public.profiles where id = '{uid}';"))
    print(psql(f"select 'study_sessions satır=' || count(*) from public.study_sessions where user_id = '{uid}';"))
    print(psql(f"select 'lig weekly_points=' || coalesce(sum(weekly_points),0) from public.league_memberships where user_id = '{uid}';"))
    sys.exit(0 if accepted <= 1 else 1)


if __name__ == "__main__":
    main()
