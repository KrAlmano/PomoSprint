#!/usr/bin/env python3
"""Gerçek sunucu yanıtlarını istemci ayrıştırma testine (t3_client_parsing_test.dart) fixture olarak yazar.

    python3 tool/local_supabase/e2e/t3_visibility/t3_rest_test.py      # önce: arkadaşlık durumu
    python3 tool/local_supabase/e2e/t3_visibility/t3_capture_fixtures.py
    flutter test tool/local_supabase/e2e/t3_visibility/t3_client_parsing_test.dart

Lig/aylık satırları geri alınan transaction içinde üretilir (iz bırakmaz).
"""

import json
import os

from t3_common import HERE, ensure_users, psql, rpc
from t3_rollback_test import as_anon, as_user


def main():
    U = ensure_users()
    A, B, C, D = (U[k] for k in "ABCD")
    fx = {"uids": {k: u["uid"] for k, u in U.items()}, "names": {k: u["name"] for k, u in U.items()}}
    fx["friends_A"] = rpc("get_my_friends", None, A["token"])[1]
    fx["incoming_A"] = rpc("get_incoming_friend_requests", None, A["token"])[1]
    fx["add_already_friends"] = rpc("add_friend_by_code", {"p_code": B["code"]}, A["token"])[1]
    fx["add_not_found"] = rpc("add_friend_by_code", {"p_code": "ZZZZZZ"}, A["token"])[1]
    fx["respond_gone"] = rpc("respond_friend_request", {"p_from_user_id": D["uid"], "p_accept": True}, A["token"])[1]
    rpc("start_study_session", {"p_duration_minutes": 25, "p_category_name": "Matematik"}, B["token"])
    rpc("start_study_session", {"p_duration_minutes": 50, "p_category_name": "Gitar"}, D["token"])
    fx["live_A"] = rpc("get_live_friends", None, A["token"])[1]
    rpc("cancel_study_session", None, B["token"])
    rpc("cancel_study_session", None, D["token"])

    s = "begin;\n"
    for k in "ABCD":
        s += as_user(U[k]["uid"])
        s += (f"select public.complete_study_session(gen_random_uuid(), public.create_category('T3 Fx {k}', '#123456', 'book'), "
              f"{25 if k != 'B' else 50}, false, 1500, now() - interval '{25 if k != 'B' else 50} minutes') \\g /dev/null\n")
    s += as_user(A["uid"])
    s += "select 'T3|league|' || jsonb_agg(to_jsonb(r))::text from public.get_my_league_ranking() r;\n"
    s += "select 'T3|monthly|' || jsonb_agg(to_jsonb(r))::text from public.get_public_monthly_leaderboard(50) r;\n"
    s += as_anon()
    s += "select 'T3|monthly_anon|' || jsonb_agg(to_jsonb(r))::text from public.get_public_monthly_leaderboard(10) r;\n"
    s += "reset role;\nrollback;\n"
    out, err = psql(s, on_error_stop=False)
    if err.strip():
        raise SystemExit(err)
    for line in out.splitlines():
        if line.startswith("T3|"):
            _, tag, rest = line.split("|", 2)
            fx[tag] = json.loads(rest)
    path = os.path.join(HERE, "fixtures.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(fx, f, ensure_ascii=False, indent=1)
    print(f"{path}: " + ", ".join(f"{k}={len(v) if isinstance(v, list) else 'obj'}" for k, v in fx.items()))


if __name__ == "__main__":
    main()
