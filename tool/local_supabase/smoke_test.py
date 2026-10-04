#!/usr/bin/env python3
"""Yerel Supabase kopyasında duman testi (kullanıcı JWT'siyle PostgREST).

    python3 tool/local_supabase/smoke_test.py

Test hesaplarını (create_test_users.py) açar ya da kullanır, sonra:
  - anon: get_points_config, get_league_zones, avatars SELECT, profiles'a erişim YOK
  - test1: create_category → complete_study_session (started_at = şimdi - 25 dk)
    → aynı client_uuid ile tekrar (duplicate) → bitmemiş seans reddi
    → profil (puan/kum) → get_my_league_ranking
  - test1 ↔ test2 arkadaşlık: add_friend_by_code → respond_friend_request → get_my_friends
Veriyi bırakır (sonraki denemeler kullanabilir). Son seans 25 dk'dan yeniyse
seans adımı çakışma (overlap) yerine atlanır. YALNIZCA yerel adrese bağlanır.
"""

import datetime as dt
import sys
import uuid

import local_api as api
from create_test_users import ensure_user

FAILED = []


def check(name, cond, detail=""):
    print(f"  [{'ok' if cond else 'HATA'}] {name}" + (f" — {detail}" if detail else ""))
    if not cond:
        FAILED.append(name)


def main():
    print("anon:")
    cfg = api.rpc("get_points_config")
    check("get_points_config (anon)", isinstance(cfg, dict) and cfg.get("coins_per_session") == 20, str(cfg))
    zones = api.rpc("get_league_zones", {"p_member_count": 15})
    check("get_league_zones(15) = ilk 3 / son 3", zones == [{"promotion_zone_end": 3, "demotion_zone_start": 13}], str(zones))
    avatars = api.select("avatars", "select=id&is_active=eq.true", None)
    check("avatars (anon SELECT)", len(avatars) == 26, f"{len(avatars)} etkin avatar")
    try:
        rows = api.select("profiles", "select=id&limit=1", None)
        check("profiles anon'a kapalı", False, f"{rows}")
    except api.ApiError as e:
        check("profiles anon'a kapalı", e.status in (401, 403), f"HTTP {e.status}")

    print("hesaplar:")
    _, t1, p1 = ensure_user(1)
    _, t2, p2 = ensure_user(2)

    print("test1 seans:")
    cfg_user = api.rpc("get_points_config", token=t1)
    check("get_points_config (authenticated)", cfg_user == cfg)
    cats = api.select("categories", "select=id,name&is_archived=eq.false&order=sort_order", t1)
    if cats:
        cat_id = cats[0]["id"]
    else:
        cat_id = api.rpc("create_category", {"p_name": "Matematik", "p_color_hex": "#3B82F6", "p_icon_name": "calculate"}, t1)
    check("kategori", isinstance(cat_id, str) and len(cat_id) == 36, str(cat_id))

    now = dt.datetime.now(dt.timezone.utc)
    last = api.select("study_sessions", "select=completed_at&order=completed_at.desc&limit=1", t1)
    last_end = dt.datetime.fromisoformat(last[0]["completed_at"]) if last else None
    if last_end and last_end > now - dt.timedelta(minutes=25):
        print(f"  [atlandı] son seans {last_end:%H:%M} UTC'de bitti; yeni 25 dk'lık seans çakışırdı (overlap)")
    else:
        before = api.select("profiles", "select=coins,lifetime_points", t1)[0]
        client_uuid = str(uuid.uuid4())
        args = {
            "p_client_uuid": client_uuid,
            "p_category_id": cat_id,
            "p_duration_minutes": 25,
            "p_was_paused": False,
            "p_is_verified": 1500,
            "p_started_at": (now - dt.timedelta(minutes=25)).isoformat(),
        }
        res = api.rpc("complete_study_session", args, t1)
        check("complete_study_session (25 dk, şimdi - 25 dk)",
              res.get("base_points") == 5 and res.get("coins_earned") == 20 and res.get("duplicate") is False,
              str(res))
        dup = api.rpc("complete_study_session", args, t1)
        check("aynı client_uuid → duplicate, kum 0", dup.get("duplicate") is True and dup.get("coins_earned") == 0, str(dup))
        after = api.select("profiles", "select=coins,lifetime_points", t1)[0]
        check("profil: kum +20, puan +toplam",
              after["coins"] == before["coins"] + 20
              and after["lifetime_points"] == before["lifetime_points"] + res.get("total_points", -1),
              f"{before} → {after}")
    try:
        api.rpc("complete_study_session", {
            "p_client_uuid": str(uuid.uuid4()), "p_category_id": cat_id, "p_duration_minutes": 25,
            "p_was_paused": False, "p_is_verified": 600,
            "p_started_at": (now - dt.timedelta(minutes=10)).isoformat(),
        }, t1)
        check("bitmemiş seans reddedilir", False, "kabul edildi")
    except api.ApiError as e:
        msg = e.body.get("message") if isinstance(e.body, dict) else str(e.body)
        check("bitmemiş seans reddedilir (session_not_finished)", msg == "session_not_finished", f"HTTP {e.status} {msg}")

    ranking = api.rpc("get_my_league_ranking", token=t1)
    me = [r for r in ranking if r.get("is_me")]
    check("get_my_league_ranking: is_me satırı", len(me) == 1, f"{len(ranking)} üye, ben: {me[0] if me else None}")

    print("arkadaşlık:")
    friends = api.rpc("get_my_friends", token=t2)
    if any(f["id"] == p1["id"] for f in friends):
        print("  [atlandı] test1 ve test2 zaten arkadaş")
    else:
        add = api.rpc("add_friend_by_code", {"p_code": p1["friend_code"]}, t2)
        check("test2 → add_friend_by_code(test1)", add.get("success") is True, str(add))
        incoming = api.rpc("get_incoming_friend_requests", token=t1)
        check("test1 gelen istek", any(r["id"] == p2["id"] for r in incoming), f"{len(incoming)} istek")
        resp = api.rpc("respond_friend_request", {"p_from_user_id": p2["id"], "p_accept": True}, t1)
        check("respond_friend_request(kabul)", isinstance(resp, dict) and resp.get("success") is True, str(resp))
    f1 = api.rpc("get_my_friends", token=t1)
    check("get_my_friends (test1 → test2)", any(f["id"] == p2["id"] for f in f1), f"{len(f1)} arkadaş")

    if FAILED:
        print(f"SONUÇ: {len(FAILED)} HATA: {', '.join(FAILED)}")
        sys.exit(1)
    print("SONUÇ: duman testi geçti")


if __name__ == "__main__":
    main()
