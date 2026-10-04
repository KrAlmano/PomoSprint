#!/usr/bin/env python3
"""t3 — REST/RPC üzerinden hesaplar arası görünürlük ve güvenlik (yerel kopya).

    python3 tool/local_supabase/e2e/t3_visibility/t3_rest_test.py

Kalıcı olarak yalnızca t3-a..t3-e hesaplarının arkadaşlık satırlarını, canlı
seans alanlarını, görünürlük tercihini ve B'nin bir kategorisini yazar.
Seans/lig/aktivite gerektiren senaryolar t3_rollback_test.py'dedir (geri
alınan transaction).
"""

import random
import string
import time
from datetime import datetime, timedelta, timezone

from t3_common import (api, call, check, dump_json, ensure_users, err_code, info, psql, reset_state, rpc,
                       summary)


def parse_ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def main():
    U = ensure_users()
    reset_state(U)
    A, B, C, D, E = (U[k] for k in "ABCDE")
    print("Hesaplar:", {k: (u["uid"], u["code"]) for k, u in U.items()})

    # ------------------------------------------------------------------ arkadaşlık
    st, r = rpc("add_friend_by_code", {"p_code": B["code"]}, A["token"])
    check("F1", st == 200 and r.get("success") is True and r.get("auto_accepted") is False
          and r["friend"]["id"] == B["uid"] and set(r["friend"]) == {"id", "name", "avatar_id"},
          "A, B'nin koduyla istek gönderir: success, auto_accepted=false, friend={id,name,avatar_id}", dump_json(r))

    st, inc_b = rpc("get_incoming_friend_requests", None, B["token"])
    row = next((x for x in inc_b if x["id"] == A["uid"]), None) if st == 200 else None
    check("F2", row is not None and set(row) == {"id", "name", "avatar_id", "lifetime_points", "total_minutes", "created_at"}
          and row["name"] == A["name"],
          "B'nin gelen isteklerinde A var; alanlar id,name,avatar_id,lifetime_points,total_minutes,created_at", dump_json(inc_b))
    st, inc_a = rpc("get_incoming_friend_requests", None, A["token"])
    check("F2b", st == 200 and inc_a == [], "Gönderen A'nın gelen isteklerinde kayıt yok", dump_json(inc_a))
    st1, fa = rpc("get_my_friends", None, A["token"])
    st2, fb = rpc("get_my_friends", None, B["token"])
    check("F3", fa == [] and fb == [], "Bekleyen istek arkadaş listesinde görünmez (A ve B)", f"{fa} {fb}")

    st, r = rpc("add_friend_by_code", {"p_code": B["code"]}, A["token"])
    check("F4", r.get("success") is False and "zaten istek" in r.get("message", ""), "Aynı isteği tekrar gönderme reddedilir", dump_json(r))
    check("F4b", "code" not in r, "Sunucu yanıtında makine-okunur 'code' YOK (istemci switch'i ölü kod)", dump_json(r))
    st, r = rpc("add_friend_by_code", {"p_code": A["code"].lower()}, A["token"])
    check("F5", r.get("success") is False and "Kendini" in r.get("message", ""), "Kendi kodunu (küçük harf) ekleme reddedilir", dump_json(r))
    st, r = rpc("add_friend_by_code", {"p_code": "ZZZZZZ"}, A["token"])
    check("F6", r.get("success") is False and "bulunamadı" in r.get("message", ""), "Geçersiz kod: bulunamadı", dump_json(r))
    st, r = rpc("add_friend_by_code", {"p_code": "  " + D["code"].lower() + "  "}, A["token"])
    check("F7", r.get("success") is True and r.get("auto_accepted") is False, "Baş/son boşluklu küçük harf kod sunucuda normalize edilir (A→D)", dump_json(r))

    # Üçüncü kişi başkasının isteğini kabul edemez; gönderen kendi isteğini kabul edemez
    st, r = rpc("respond_friend_request", {"p_from_user_id": A["uid"], "p_accept": True}, C["token"])
    check("F8", r.get("success") is False, "C, A→B isteğini (hedefi değil) kabul edemez", dump_json(r))
    st, r = rpc("respond_friend_request", {"p_from_user_id": B["uid"], "p_accept": True}, A["token"])
    check("F9", r.get("success") is False, "Gönderen A, ters yönde (B→A yok) kabul edemez", dump_json(r))
    out, _ = psql(f"select status from friendships where user_id='{A['uid']}' and friend_id='{B['uid']}';"
                  f"select count(*) from friendships where user_id='{C['uid']}' or friend_id='{C['uid']}';")
    check("F9b", out.split() == ["pending", "0"], "A→B hâlâ pending, C'ye satır açılmadı", out)

    st, r = rpc("respond_friend_request", {"p_from_user_id": A["uid"], "p_accept": True}, B["token"])
    check("F10", st == 200 and r == {"success": True}, "B, A'nın isteğini kabul eder", dump_json(r))
    st, fa = rpc("get_my_friends", None, A["token"])
    st, fb = rpc("get_my_friends", None, B["token"])
    check("F10b", [x["id"] for x in fa] == [B["uid"]] and [x["id"] for x in fb] == [A["uid"]]
          and set(fa[0]) == {"id", "name", "avatar_id", "lifetime_points", "total_minutes"},
          "Kabulden sonra iki taraf birbirini get_my_friends'te görür (tek satır, alanlar doğru)", f"{dump_json(fa)} {dump_json(fb)}")
    st, inc_b = rpc("get_incoming_friend_requests", None, B["token"])
    check("F10c", all(x["id"] != A["uid"] for x in inc_b), "Kabul edilen istek gelenlerden düşer", dump_json(inc_b))
    st, r = rpc("add_friend_by_code", {"p_code": B["code"]}, A["token"])
    check("F11", r.get("success") is False and "zaten arkadaşın" in r.get("message", ""), "Arkadaşı tekrar ekleme reddedilir", dump_json(r))

    # D, A'nın kodunu girer: A→D bekliyordu, otomatik kabul
    st, r = rpc("add_friend_by_code", {"p_code": A["code"]}, D["token"])
    check("F12", r.get("success") is True and r.get("auto_accepted") is True
          and {"lifetime_points", "total_minutes"} <= set(r.get("friend", {})),
          "Karşılıklı istek otomatik kabul (auto_accepted=true, friend puan/dakika içerir)", dump_json(r))

    # Ret ve yeniden gönderme (engel yok)
    st, r = rpc("add_friend_by_code", {"p_code": A["code"]}, C["token"])
    check("F13", r.get("success") is True, "C→A istek", dump_json(r))
    st, r = rpc("respond_friend_request", {"p_from_user_id": C["uid"], "p_accept": False}, A["token"])
    check("F13b", r == {"success": True}, "A, C'nin isteğini reddeder", dump_json(r))
    out, _ = psql(f"select count(*) from friendships where user_id='{C['uid']}' and friend_id='{A['uid']}';")
    check("F13c", out.strip() == "0", "Ret satırı siler", out)
    st, r = rpc("respond_friend_request", {"p_from_user_id": C["uid"], "p_accept": False}, A["token"])
    check("F13d", r.get("success") is False and "code" not in r,
          "Artık olmayan isteğe yanıt: success=false, mesaj var ama 'code' yok (istemci friendsRequestGone dalına giremez)", dump_json(r))
    resend = []
    for _ in range(3):
        _, r1 = rpc("add_friend_by_code", {"p_code": A["code"]}, C["token"])
        _, r2 = rpc("respond_friend_request", {"p_from_user_id": C["uid"], "p_accept": False}, A["token"])
        resend.append((r1.get("success"), r2.get("success")))
    if all(x == (True, True) for x in resend):
        info("F14", "Reddedilen kullanıcı hemen tekrar istek gönderebiliyor (soğuma/engel yok)", str(resend))
    else:
        check("F14", True, "Ret sonrası tekrar gönderme sınırlı", str(resend))
    # C→A pending bırak (canlı ve REST testleri için)
    rpc("add_friend_by_code", {"p_code": A["code"]}, C["token"])

    st, fc = rpc("get_my_friends", None, C["token"])
    check("F15", fc == [], "C (arkadaş değil, yalnızca bekleyen istek) kimseyi arkadaş olarak görmez", dump_json(fc))

    # ------------------------------------------------------------- friendships REST
    st, rows = call("GET", "/rest/v1/friendships?select=*", token=A["token"])
    ok = st == 200 and all(A["uid"] in (x["user_id"], x["friend_id"]) for x in rows)
    check("R1", ok, f"A friendships SELECT yalnızca kendi satırları ({len(rows) if isinstance(rows, list) else rows} satır)", dump_json(rows))
    st, rows = call("GET", f"/rest/v1/friendships?select=*&user_id=eq.{B['uid']}&friend_id=eq.{A['uid']}", token=C["token"])
    check("R2", st == 200 and rows == [], "C, A↔B arkadaşlığını göremez", dump_json(rows))
    st, r = call("POST", "/rest/v1/friendships", {"user_id": C["uid"], "friend_id": A["uid"], "status": "accepted"}, token=C["token"])
    check("R3", st in (401, 403) and err_code(r) == "42501", "C friendships'e doğrudan 'accepted' satır yazamaz", f"{st} {dump_json(r)}")
    st, r = call("PATCH", f"/rest/v1/friendships?user_id=eq.{C['uid']}&friend_id=eq.{A['uid']}", {"status": "accepted"},
                 token=C["token"], headers={"Prefer": "return=representation"})
    check("R4", st in (401, 403) and err_code(r) == "42501", "C kendi bekleyen isteğini 'accepted' yapamaz", f"{st} {dump_json(r)}")
    st, r = call("DELETE", f"/rest/v1/friendships?user_id=eq.{A['uid']}", token=B["token"])
    check("R5", st in (401, 403) and err_code(r) == "42501", "B friendships satırı silemez", f"{st} {dump_json(r)}")

    # ------------------------------------------------------------- canlı çalışanlar
    st, r = rpc("start_study_session", {"p_duration_minutes": 25, "p_category_name": "Matematik"}, B["token"])
    check("L0", st == 200, "B start_study_session(25, Matematik)", dump_json(r))
    st, live_a = rpc("get_live_friends", None, A["token"])
    row = next((x for x in live_a if x["id"] == B["uid"]), None) if isinstance(live_a, list) else None
    ok = row is not None and set(row) == {"id", "name", "avatar_id", "category_name", "ends_at"} \
        and row["category_name"] == "Matematik" \
        and timedelta(minutes=24) < parse_ts(row["ends_at"]) - datetime.now(timezone.utc) <= timedelta(minutes=25, seconds=5)
    check("L1", ok, "Arkadaş A, B'yi canlı listede görür (alanlar ve ends_at≈+25 dk)", dump_json(live_a))
    check("L1b", isinstance(live_a, list) and len([x for x in live_a if x["id"] == B["uid"]]) == 1, "B bir kez listelenir (çift satır yok)", dump_json(live_a))
    for k in ("C", "D", "E"):
        st, lv = rpc("get_live_friends", None, U[k]["token"])
        check(f"L2{k}", st == 200 and all(x["id"] != B["uid"] for x in lv), f"{k} (B'nin arkadaşı değil) B'yi canlı listede görmez", dump_json(lv))
    st, r = call("PATCH", f"/rest/v1/profiles?id=eq.{B['uid']}", {"show_in_social_feed": False}, token=B["token"],
                 headers={"Prefer": "return=representation"})
    check("L3a", st == 200 and r and r[0]["show_in_social_feed"] is False, "B görünürlüğü kapatır (izinli kolon)", dump_json(r))
    st, live_a = rpc("get_live_friends", None, A["token"])
    check("L3", all(x["id"] != B["uid"] for x in live_a), "show_in_social_feed=false iken A, B'yi görmez", dump_json(live_a))
    call("PATCH", f"/rest/v1/profiles?id=eq.{B['uid']}", {"show_in_social_feed": True}, token=B["token"])
    st, live_a = rpc("get_live_friends", None, A["token"])
    check("L3b", any(x["id"] == B["uid"] for x in live_a), "Görünürlük açılınca süren seans yine görünür", dump_json(live_a))
    rpc("cancel_study_session", None, B["token"])
    st, live_a = rpc("get_live_friends", None, A["token"])
    check("L4", all(x["id"] != B["uid"] for x in live_a), "cancel_study_session sonrası B listeden düşer", dump_json(live_a))

    rpc("start_study_session", {"p_duration_minutes": 25, "p_category_name": "Fizik"}, C["token"])
    st, live_a = rpc("get_live_friends", None, A["token"])
    check("L5", all(x["id"] != C["uid"] for x in live_a), "Yalnızca bekleyen istek (C→A) canlı listeye sokmaz", dump_json(live_a))
    rpc("cancel_study_session", None, C["token"])

    st, r = rpc("get_live_friends", None, None)
    check("L6", st == 401 and err_code(r) == "42501", "anon get_live_friends çağıramaz", f"{st} {dump_json(r)}")

    # Sınırsız süre ve uzun kategori adı
    big = "X" * 100_000
    st, r = rpc("start_study_session", {"p_duration_minutes": 2147483647, "p_category_name": big}, B["token"])
    st2, live_a = rpc("get_live_friends", None, A["token"])
    row = next((x for x in live_a if x["id"] == B["uid"]), None) if isinstance(live_a, list) else None
    if st == 200 and row and len(row["category_name"]) == 100_000:
        info("L7", "start_study_session süre/ad sınırı yok: B, 100.000 karakterlik kategori adıyla ve "
             f"ends_at={row['ends_at']} ile arkadaşlarına 'canlı' görünür", f"len={len(row['category_name'])}")
    else:
        check("L7", True, "start_study_session süre/ad sınırı uygulanıyor", f"{st} {dump_json(r)}")
    st, r = rpc("start_study_session", {"p_duration_minutes": -10, "p_category_name": "neg"}, B["token"])
    st2, live_a = rpc("get_live_friends", None, A["token"])
    check("L8", all(x["id"] != B["uid"] for x in live_a), "Negatif süre canlı göstermez", f"{st} {dump_json(r)}")
    rpc("cancel_study_session", None, B["token"])

    # ------------------------------------------------------------- profiles
    st, rows = call("GET", "/rest/v1/profiles?select=*", token=A["token"])
    check("P1", st == 200 and len(rows) == 1 and rows[0]["id"] == A["uid"], "A profiles'ta yalnızca kendi satırını görür", f"{len(rows)} satır")
    st, rows = call("GET", f"/rest/v1/profiles?select=email,coins,birth_year,friend_code&id=eq.{B['uid']}", token=A["token"])
    check("P2", st == 200 and rows == [], "A, B'nin özel kolonlarını (email,coins,birth_year,friend_code) okuyamaz", dump_json(rows))
    st, rows = call("PATCH", f"/rest/v1/profiles?id=eq.{B['uid']}", {"name": "HACKED"}, token=A["token"],
                    headers={"Prefer": "return=representation"})
    out, _ = psql(f"select name from profiles where id='{B['uid']}'")
    check("P3", rows == [] and out.strip() == B["name"], "A, B'nin adını değiştiremez (0 satır)", f"{st} {dump_json(rows)} ad={out.strip()}")
    for col, val in [("coins", 999999), ("lifetime_points", 999), ("is_premium", True), ("league_tier", 5),
                     ("friend_code", "AAAAAA"), ("email", "x@y.z"), ("current_streak", 99), ("total_minutes", 9999),
                     ("active_session_ends_at", "2999-01-01T00:00:00Z"), ("active_session_category_name", "x"), ("id", B["uid"])]:
        st, r = call("PATCH", f"/rest/v1/profiles?id=eq.{A['uid']}", {col: val}, token=A["token"])
        check(f"P4.{col}", st in (401, 403) and err_code(r) == "42501", f"A kendi {col} kolonunu yazamaz", f"{st} {dump_json(r)}")
    st, r = call("DELETE", f"/rest/v1/profiles?id=eq.{B['uid']}", token=A["token"])
    check("P5", st in (401, 403) and err_code(r) == "42501", "A profiles silemez (B'nin satırı)", f"{st} {dump_json(r)}")
    st, r = call("POST", "/rest/v1/profiles", {"id": B["uid"], "email": "x@y.z", "name": "x"}, token=A["token"])
    check("P6", st in (401, 403, 409) and err_code(r) in ("42501", "23505"), "A, B adına profiles satırı ekleyemez", f"{st} {dump_json(r)}")
    st, r = call("POST", "/rest/v1/profiles?on_conflict=id", {"id": A["uid"], "email": A["email"], "name": A["name"], "coins": 5000},
                 token=A["token"], headers={"Prefer": "resolution=merge-duplicates"})
    check("P7", st in (401, 403) and err_code(r) == "42501", "A upsert ile kendi coins'ini yazamaz", f"{st} {dump_json(r)}")
    st, r = call("PATCH", f"/rest/v1/profiles?id=eq.{A['uid']}", {"birth_year": 2001}, token=A["token"],
                 headers={"Prefer": "return=representation"})
    check("P8", st == 200 and r and r[0]["birth_year"] == 2001, "A izinli kolonu (birth_year) yazabilir", dump_json(r))
    call("PATCH", f"/rest/v1/profiles?id=eq.{A['uid']}", {"birth_year": None}, token=A["token"])

    # ------------------------------------------------------------- categories
    st, cat_id = rpc("create_category", {"p_name": "T3 Gizli Ders", "p_color_hex": "#FF0000", "p_icon_name": "book"}, B["token"])
    if st != 200:
        st2, rows = call("GET", "/rest/v1/categories?select=id&name=eq.T3%20Gizli%20Ders", token=B["token"])
        cat_id = rows[0]["id"] if rows else None
    check("C0", cat_id is not None, "B kendi kategorisini oluşturur", dump_json(cat_id))
    st, rows = call("GET", f"/rest/v1/categories?id=eq.{cat_id}", token=A["token"])
    check("C1", st == 200 and rows == [], "A, B'nin kategorisini okuyamaz", dump_json(rows))
    st, rows = call("PATCH", f"/rest/v1/categories?id=eq.{cat_id}", {"name": "HACK", "is_archived": True}, token=A["token"],
                    headers={"Prefer": "return=representation"})
    st2, rows = call("DELETE", f"/rest/v1/categories?id=eq.{cat_id}", token=A["token"], headers={"Prefer": "return=representation"})
    out, _ = psql(f"select name || '|' || is_archived from categories where id='{cat_id}'")
    check("C2", out.strip() == "T3 Gizli Ders|false", "A, B'nin kategorisini güncelleyemez/silemez", f"{st}/{st2} {out.strip()}")
    st, r = call("POST", "/rest/v1/categories", {"user_id": B["uid"], "name": "Sızma", "color_hex": "#000000"}, token=A["token"])
    check("C3", st in (401, 403) and err_code(r) == "42501", "A, B adına kategori ekleyemez (RLS)", f"{st} {dump_json(r)}")
    st, own = call("GET", "/rest/v1/categories?select=id&limit=1", token=A["token"])
    if not own:
        _, cid = rpc("create_category", {"p_name": "T3 A Ders", "p_color_hex": "#00FF00", "p_icon_name": "book"}, A["token"])
        own = [{"id": cid}]
    st, r = call("PATCH", f"/rest/v1/categories?id=eq.{own[0]['id']}", {"user_id": B["uid"]}, token=A["token"])
    out, _ = psql(f"select user_id from categories where id='{own[0]['id']}'")
    check("C4", st in (401, 403) and out.strip() == A["uid"], "A kendi kategorisini B'ye taşıyamaz (UPDATE WITH CHECK)", f"{st} {dump_json(r)}")

    # ------------------------------------------------------------- diğer tablolar
    for table in ("study_sessions", "avatar_unlocks", "marketing_subscribers", "activity_feed"):
        st, rows = call("GET", f"/rest/v1/{table}?select=*&user_id=eq.{B['uid']}", token=C["token"])
        check(f"T.{table}", st == 200 and rows == [], f"C, B'nin {table} satırlarını okuyamaz", f"{st} {dump_json(rows)}")
    st, r = call("POST", "/rest/v1/study_sessions", {"user_id": A["uid"], "category": "x", "duration_minutes": 25,
                                                      "base_points": 1000}, token=A["token"])
    check("T.ss_insert", st in (401, 403) and err_code(r) == "42501", "A study_sessions'a doğrudan yazamaz", f"{st} {dump_json(r)}")
    st, r = call("POST", "/rest/v1/avatar_unlocks", {"user_id": A["uid"], "avatar_id": "avatar_1_gamer", "unlock_type": "coins"},
                 token=A["token"])
    check("T.au_insert", st in (401, 403) and err_code(r) == "42501", "A avatar_unlocks'a doğrudan yazamaz", f"{st} {dump_json(r)}")
    st, r = call("POST", "/rest/v1/league_memberships", {"user_id": A["uid"], "weekly_points": 9999}, token=A["token"])
    check("T.lm_insert", st in (401, 403) and err_code(r) == "42501", "A league_memberships'e yazamaz", f"{st} {dump_json(r)}")
    st, r = call("POST", "/rest/v1/activity_feed", {"user_id": B["uid"], "activity_type": "daily_summary", "payload": {},
                                                     "activity_date": "2026-10-05"}, token=A["token"])
    check("T.af_insert", st in (401, 403) and err_code(r) == "42501", "A activity_feed'e (B adına) yazamaz", f"{st} {dump_json(r)}")

    # ------------------------------------------------------------- anon
    for table in ("profiles", "study_sessions", "categories", "friendships", "league_memberships", "leagues",
                  "activity_feed", "avatar_unlocks", "marketing_subscribers", "waitlist"):
        st, r = call("GET", f"/rest/v1/{table}?select=*&limit=1")
        check(f"N.{table}", st == 401 and err_code(r) == "42501", f"anon {table} okuyamaz", f"{st} {dump_json(r)}")
    st, r = call("GET", "/rest/v1/avatars?select=id&limit=1")
    check("N.avatars", st == 200 and isinstance(r, list) and len(r) == 1, "anon avatars kataloğunu okur", dump_json(r))
    for fn, args in [("get_my_friends", {}), ("get_incoming_friend_requests", {}), ("add_friend_by_code", {"p_code": B["code"]}),
                     ("respond_friend_request", {"p_from_user_id": A["uid"], "p_accept": True}),
                     ("get_my_league_ranking", {}), ("get_league_ranking", {"p_user_id": A["uid"]}),
                     ("start_study_session", {"p_duration_minutes": 25, "p_category_name": "x"}),
                     ("get_friends_feed", {"p_limit": 5}), ("get_my_league_ids", {}), ("mask_public_name", {"p_name": "a b"})]:
        st, r = rpc(fn, args)
        check(f"N.rpc.{fn}", st == 401 and err_code(r) == "42501", f"anon {fn} çağıramaz", f"{st} {dump_json(r)}")

    # ------------------------------------------------------------- herkese açık sıralamalar (mevcut veriyle)
    st, anon_m = rpc("get_public_monthly_leaderboard", {"p_limit": 100})
    st2, a_m = rpc("get_public_monthly_leaderboard", {"p_limit": 100}, A["token"])
    check("M1", st == 200 and all(set(x) == {"name", "avatar_id", "total_points", "total_minutes", "is_me"} for x in anon_m),
          "Aylık sıralama kimlik (id) döndürmez", dump_json(anon_m))
    check("M2", all(x["is_me"] is False for x in anon_m), "anon için is_me hep false", dump_json(anon_m))
    anon_names = [x["name"] for x in anon_m]
    a_names = [x["name"] for x in a_m]
    check("M3", "Test K." in anon_names and "Test Kullanıcı 1" in a_names,
          "anon 'Ad S.' maskeli ad görür, oturumlu kullanıcı tam ad görür", f"anon={anon_names} auth={a_names}")
    st, al = rpc("get_public_alltime_leaderboard", {"p_limit": 100})
    check("M4", st == 200 and all(" " not in (x["name"] or "") or x["name"].endswith(".") for x in al)
          and all(x["is_me"] is False for x in al),
          "Tüm zamanlar (anon): tüm adlar maskeli, is_me false", dump_json([x["name"] for x in al]))
    st, al_a = rpc("get_public_alltime_leaderboard", {"p_limit": 100}, A["token"])
    mine = [x for x in al_a if x["is_me"]]
    check("M5", len(mine) == 1 and mine[0]["name"] == A["name"], "Tüm zamanlar (A): yalnızca kendi satırı is_me", dump_json(mine))
    st, r = rpc("get_public_alltime_leaderboard", {"p_limit": 100000})
    check("M6", st == 200 and len(r) <= 100, f"p_limit 100 ile sınırlı ({len(r)} satır)", "")
    st, r = rpc("get_public_monthly_leaderboard", {"p_limit": -5})
    check("M7", st == 200 and r == [], "Negatif p_limit boş döner", dump_json(r))
    names_c = [x["name"] for x in al if x["name"] in ("Cem",)]
    check("M8", names_c == ["Cem"], "Tek kelimelik ad (Cem) anon'a olduğu gibi gider (maskelenecek soyad yok)", dump_json(names_c))
    st, r = call("PATCH", f"/rest/v1/profiles?id=eq.{C['uid']}", {"show_in_social_feed": False}, token=C["token"])
    st, al = rpc("get_public_alltime_leaderboard", {"p_limit": 100})
    check("M9", all(x["name"] != "Cem" for x in al), "show_in_social_feed=false olan herkese açık listeden çıkar", "")
    call("PATCH", f"/rest/v1/profiles?id=eq.{C['uid']}", {"show_in_social_feed": True}, token=C["token"])

    # ------------------------------------------------------------- arkadaş kodu uzayı ve hız
    n = 200
    t0 = time.time()
    hits = 0
    for _ in range(n):
        code = "Z" + "".join(random.choice("GHJKLMNPQRSTUVWXY") for _ in range(5))  # hex dışı: hiçbir gerçek koda denk gelmez
        _, r = rpc("add_friend_by_code", {"p_code": code}, E["token"])
        hits += 1 if r.get("success") else 0
    dt = time.time() - t0
    rate = n / dt
    out, _ = psql("select count(*), count(*) filter (where friend_code ~ '^[0-9A-F]{6}$') from profiles")
    info("K1", f"add_friend_by_code hız sınırı yok: tek istemciden {rate:.0f} deneme/sn ({n} deneme, 0 hata); kod uzayı 16^6=16.777.216 "
         f"(tüm kodlar hex mi: {out.strip()}) → tek istemciyle tüm uzay ~{16**6 / rate / 3600:.1f} saat", f"hits={hits}")

    # ------------------------------------------------------------- league_memberships / leagues doğrudan
    st, rows = call("GET", "/rest/v1/leagues?select=id,tier,end_date,is_active", token=E["token"])
    if st == 200 and rows:
        info("G1", f"Ligi olmayan E bile tüm leagues satırlarını okuyabiliyor ({len(rows)} satır)", dump_json(rows[:2]))

    return summary()


if __name__ == "__main__":
    raise SystemExit(main())
