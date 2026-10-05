#!/usr/bin/env python3
"""t4-05: Lig/avatar RPC'lerinin HTTP sözleşmesi, istemcinin (lib/) çağırdığı
biçimde: parametre adları, dönen alan/tipler ve hata metinlerinin
lib/services/service_errors.dart serviceErrorCodeOf() ile sınıflandırılması.

Yalnızca YEREL kopya (local_api._require_local). Kendi t4- hesabını açar,
kum vermek için yalnızca KENDİ hesabının profiles.coins'ini psql ile ayarlar;
sonda hesabı siler (auth.users → cascade). Lig/seans verisi yazmaz (paylaşılan
lig odalarına dokunmamak için; lig senaryoları 01-03 SQL'lerinde ROLLBACK).

    python3 tool/local_supabase/e2e/t4_league_avatar/05_client_contract.py
"""

import datetime as dt
import os
import subprocess
import sys
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..")))
import local_api as api  # noqa: E402

PG = "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
results = []


def check(name, ok, detail=""):
    results.append((bool(ok), name, detail))


def psql(sql):
    out = subprocess.run(["psql", PG, "-At", "-c", sql], capture_output=True, text=True, check=True)
    return out.stdout.strip()


def service_error_code_of(status, body):
    """lib/services/service_errors.dart serviceErrorCodeOf (PostgrestException dalı)."""
    message = (body.get("message") or "").lower() if isinstance(body, dict) else str(body).lower()
    code = (body.get("code") or "") if isinstance(body, dict) else ""
    if "not authenticated" in message:
        return "notSignedIn"
    if "kategori" in message and "en fazla" in message:
        return "categoryLimitReached"
    if "zaten var" in message or (code == "23505" and "categor" in message):
        return "categoryNameExists"
    if "yetersiz bakiye" in message:
        return "insufficientCoins"
    if "premium" in message:
        return "premiumRequired"
    if "kilitli" in message:
        return "avatarLocked"
    if "bulunamad" in message:
        return "notFound"
    if code == "PGRST301":
        return "notSignedIn"
    if code.startswith("22") or code.startswith("23"):
        return "invalidInput"
    return "server"


def rpc_err(name, args, token):
    try:
        return None, api.rpc(name, args, token)
    except api.ApiError as e:
        return e, None


def main():
    email = f"t4-contract-{uuid.uuid4().hex[:8]}@pomosprint.local"
    api.sign_up(email, "t4 Sözleşme")
    session = api.sign_in(email)
    token, uid = session["access_token"], session["user"]["id"]
    try:
        run(token, uid)
    finally:
        psql(f"delete from auth.users where id = '{uid}' and email like 't4-%@pomosprint.local'")
    failed = [r for r in results if not r[0]]
    for ok, name, detail in results:
        print(f"{'OK  ' if ok else 'FAIL'} {name}" + (f" — {detail}" if detail else ""))
    print(f"\n{len(results) - len(failed)}/{len(results)} OK")
    return 1 if failed else 0


def run(token, uid):
    # 1) Ligsiz kullanıcı: get_my_league_ranking (istemci: rpc('get_my_league_ranking'), parametresiz)
    rows = api.rpc("get_my_league_ranking", {}, token)
    keys = {"name", "avatar_id", "weekly_points", "tier", "end_date", "is_me",
            "promotion_zone_end", "demotion_zone_start", "member_count", "id", "is_blocked"}
    check("get_my_league_ranking: liste, tek satır, LeagueSnapshot alanlarının hepsi",
          isinstance(rows, list) and len(rows) == 1 and set(rows[0]) == keys, rows)
    r = rows[0]
    end = dt.datetime.fromisoformat(r["end_date"])
    check("Ligsiz satır: is_me, 0 puan, member_count 0 → istemci awaitingPlacement",
          r["is_me"] is True and r["weekly_points"] == 0 and r["member_count"] == 0
          and r["promotion_zone_end"] == 1 and r["demotion_zone_start"] == 999, r)
    # istemcinin assumedLeaguePeriodEnd() formülü ile sunucu aynı mı (DateTime.tryParse ISO)
    now = dt.datetime.now(dt.timezone.utc)
    ist = now + dt.timedelta(hours=3)
    monday = dt.date(ist.year, ist.month, ist.day) - dt.timedelta(days=ist.weekday())
    assumed = dt.datetime(monday.year, monday.month, monday.day, 23, 59, 59, tzinfo=dt.timezone.utc) \
        + dt.timedelta(days=13) - dt.timedelta(hours=3)
    check("end_date ISO ayrıştırılabilir ve istemcinin assumedLeaguePeriodEnd() ile aynı",
          end == assumed, f"sunucu={r['end_date']} istemci={assumed.isoformat()}")
    check("Tipler: weekly_points/tier/member_count int, is_me bool (RankingEntry/_asInt)",
          all(isinstance(r[k], int) for k in ("weekly_points", "tier", "member_count",
                                               "promotion_zone_end", "demotion_zone_start"))
          and isinstance(r["is_me"], bool), "")

    # 2) Katalog: istemci .from('avatars').select().eq('is_active', true).order('sort_order')
    cat = api.select("avatars", "select=*&is_active=eq.true&order=sort_order.asc", token)
    cat_anon = api.request("GET", "/rest/v1/avatars?select=*&is_active=eq.true&order=sort_order.asc")
    awards = [a["id"] for a in cat if a.get("is_league_award")]
    check("Katalog (oturumlu ve anon): 26 aktif avatar, is_league_award kolonu var, 10 lig ödülü, tomato yok",
          len(cat) == 26 and len(cat_anon) == 26 and "is_league_award" in cat[0] and len(awards) == 10
          and all(a["id"] != "tomato_basic" for a in cat), f"{len(cat)}/{len(cat_anon)} awards={len(awards)}")
    unlocked = [x["avatar_id"] for x in api.select("avatar_unlocks", f"select=avatar_id&user_id=eq.{uid}", token)]
    defaults = sorted(a["id"] for a in cat if a["is_default"])
    check("avatar_unlocks (istemci _fetchUnlockedAvatars): yeni hesapta tam olarak varsayılanlar",
          sorted(unlocked) == defaults, unlocked)

    # 3) Satın alma hataları ve istemci sınıflandırması
    cases = [
        ("avatar_9_viking", "insufficientCoins"),     # 0 kum
        ("avatar_11_doctor", "premiumRequired"),      # Premium değil
        ("league_gold_monthly", "server"),            # lig ödülü (istemci zaten tıklatmıyor)
        ("tomato_basic", "notFound"),                 # pasif
        ("yok_boyle", "notFound"),
    ]
    for avatar_id, expected in cases:
        err, _ = rpc_err("purchase_avatar", {"p_avatar_id": avatar_id}, token)
        got = service_error_code_of(err.status, err.body) if err else "NO-ERROR"
        check(f"purchase_avatar({avatar_id}) → istemci kodu {expected}",
              got == expected, f"HTTP {err.status if err else '-'} {err.body if err else ''}")

    # 4) Başarılı satın alma: dönüş JSON sayı (istemci: response is num)
    psql(f"update public.profiles set coins = 230 where id = '{uid}'")
    resp = api.rpc("purchase_avatar", {"p_avatar_id": "avatar_9_viking"}, token)
    check("purchase_avatar başarı: JSON int yeni bakiye (230-200=30)", isinstance(resp, int) and resp == 30, repr(resp))
    resp2 = api.rpc("purchase_avatar", {"p_avatar_id": "avatar_9_viking"}, token)
    check("purchase_avatar sahip olunan: aynı bakiye, hata yok", resp2 == 30, repr(resp2))

    # 5) Kuşanma: dönüş true; kilitli → avatarLocked
    eq = api.rpc("set_equipped_avatar", {"p_avatar_id": "avatar_9_viking"}, token)
    prof = api.select("profiles", "select=avatar_id,coins", token)[0]
    check("set_equipped_avatar(sahip) → true; profiles.avatar_id güncel", eq is True and prof["avatar_id"] == "avatar_9_viking",
          f"{eq!r} {prof}")
    for avatar_id in ("avatar_4_bowtie", "league_diamond_monthly", "avatar_12_builder", "yok_boyle"):
        err, _ = rpc_err("set_equipped_avatar", {"p_avatar_id": avatar_id}, token)
        got = service_error_code_of(err.status, err.body) if err else "NO-ERROR"
        check(f"set_equipped_avatar({avatar_id}) → avatarLocked", got == "avatarLocked",
              f"HTTP {err.status if err else '-'} {err.body if err else ''}")

    # 6) İstemcinin doğrudan yazma denemeleri (RPC'yi atlama) reddedilir
    for path, body, method in [
        (f"/rest/v1/profiles?id=eq.{uid}", {"avatar_id": "avatar_4_bowtie"}, "PATCH"),
        (f"/rest/v1/profiles?id=eq.{uid}", {"coins": 99999}, "PATCH"),
        ("/rest/v1/avatar_unlocks", {"user_id": uid, "avatar_id": "avatar_4_bowtie", "unlock_type": "coins"}, "POST"),
    ]:
        try:
            api.request(method, path, body, token=token)
            check(f"Doğrudan {method} {path.split('?')[0]} {list(body)} reddedilir", False, "GEÇTİ")
        except api.ApiError as e:
            check(f"Doğrudan {method} {path.split('?')[0]} {list(body)} reddedilir", e.status in (401, 403),
                  f"HTTP {e.status} {e.body.get('code') if isinstance(e.body, dict) else e.body}")

    # 7) Yetki: ensure_user_in_league / process_weekly_leagues / get_league_ranking(başkası)
    for name, args in [("ensure_user_in_league", {"p_user_id": uid, "p_points": 1000}),
                       ("process_weekly_leagues", {})]:
        err, _ = rpc_err(name, args, token)
        check(f"authenticated {name} çağıramaz", err is not None and err.status in (401, 403, 404),
              f"HTTP {err.status if err else '-'} {err.body.get('message') if err and isinstance(err.body, dict) else ''}")
    err, _ = rpc_err("get_league_ranking", {"p_user_id": str(uuid.uuid4())}, token)
    check("get_league_ranking(başka id) → not authorized", err is not None and "not authorized" in str(err.body), str(err.body if err else ""))
    err, _ = rpc_err("get_my_league_ranking", {}, None)
    check("anon get_my_league_ranking yetkisiz", err is not None and err.status in (401, 403), f"HTTP {err.status if err else '-'}")
    z = api.rpc("get_league_zones", {"p_member_count": 12}, None)
    check("anon get_league_zones(12) → [{3, 10}]", z == [{"promotion_zone_end": 3, "demotion_zone_start": 10}], z)


if __name__ == "__main__":
    sys.exit(main())
