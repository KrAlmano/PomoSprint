#!/usr/bin/env python3
"""t1 — SEANS / PUAN / KUM / SERİ: sunucu tarafı uçtan uca testleri.

YALNIZCA yerel Supabase kopyasında çalışır (tool/local_supabase). Kendi
hesaplarını `t1-<çalıştırma>-<etiket>@pomosprint.local` olarak açar; test1/test2
hesaplarına dokunmaz. Küresel durumu değiştiren hiçbir şey yapmaz; seri/bonus
senaryoları geri alınan transaction içinde kendi test kullanıcısında çalışır.

    python3 tool/local_supabase/e2e/t1_seans_puan/t1_server_e2e.py

Çıkış kodu: tüm denetimler geçerse 0. "BULGU" satırları beklenen davranıştan
(ya da AGENTS.md sözleşmesinden) sapmaları gösterir; bunlar da başarısız sayılır.
"""

import datetime as dt
import json
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
RUN = os.environ.get("T1_RUN") or time.strftime("%m%d%H%M%S")
IST = dt.timezone(dt.timedelta(hours=3))  # Europe/Istanbul: 2016'dan beri sabit +03, yaz saati yok
UTC = dt.timezone.utc
MIN = dt.timedelta(minutes=1)

RESULTS = []  # (ok, ad, ayrıntı)


def check(name, ok, detail=""):
    RESULTS.append((bool(ok), name, detail))
    print(("  OK   " if ok else "  FAIL ") + name + ("" if ok else f"  -> {detail}"))
    return ok


def section(title):
    print(f"\n== {title}")


# ---------- yardımcılar ----------

def psql(sql, check_rc=True):
    r = subprocess.run(["psql", DB, "-XAtq", "-v", "ON_ERROR_STOP=1"], input=sql, capture_output=True, text=True)
    if check_rc and r.returncode != 0:
        raise RuntimeError(f"psql hata: {r.stderr.strip()}\nSQL: {sql[:400]}")
    return r.stdout.strip()


def db_now():
    raw = psql("select to_char(now() at time zone 'utc', 'YYYY-MM-DD\"T\"HH24:MI:SS.US');")
    return dt.datetime.fromisoformat(raw).replace(tzinfo=UTC)


def iso(t):
    """Dart DateTime.toUtc().toIso8601String() biçimi (session_queue → p_started_at)."""
    return t.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%S.%f") + "Z"


def study_day(t, rule="04"):
    loc = t.astimezone(IST)
    if rule == "04":
        loc = loc - dt.timedelta(hours=4)
    return loc.date()


def model_streaks(starts, rule):
    out, streak, last = [], 0, None
    for t in starts:
        d = study_day(t, rule)
        if last is None:
            streak = 1
        elif d == last:
            pass
        elif d == last + dt.timedelta(days=1):
            streak += 1
        elif d < last:
            out.append(streak)
            continue
        else:
            streak = 1
        last = d if last is None or d > last else last
        out.append(streak)
    return out


class User:
    def __init__(self, tag):
        self.tag = tag
        self.email = f"t1-{RUN}-{tag}@pomosprint.local"
        api.sign_up(self.email, f"T1 {tag}")
        s = api.sign_in(self.email)
        self.tok, self.uid = s["access_token"], s["user"]["id"]
        # Uygulamanın varsayılan kategori tohumlaması (CourseCategory.initialCategories().toServerJson()).
        api.rpc("setup_onboarding_categories", {"p_categories": [
            {"name": "Matematik", "color_hex": "#EF4444", "icon_name": "calculate"},
            {"name": "Fizik", "color_hex": "#3B82F6", "icon_name": "science"},
            {"name": "Kimya", "color_hex": "#10B981", "icon_name": "biotech"},
        ]}, self.tok)
        cats = api.select("categories", "select=id,name&order=sort_order", self.tok)
        self.cat = {c["name"]: c["id"] for c in cats}
        self.m = self.cat["Matematik"]
        # Güncel onboarding açık bir görünürlük seçimi gerektirir.
        api.request("PATCH", f"/rest/v1/profiles?id=eq.{self.uid}", {
            "show_in_social_feed": True, "birth_year": 2007,
            "onboarding_completed_at": dt.datetime.now(UTC).isoformat(),
        }, token=self.tok)

    def profile(self):
        raw = psql(f"""select json_build_object('lifetime_points', lifetime_points, 'coins', coins,
            'total_minutes', total_minutes, 'current_streak', current_streak, 'longest_streak', longest_streak,
            'last_study_date', last_study_date, 'active_session_ends_at', active_session_ends_at,
            'active_session_category_name', active_session_category_name)
            from public.profiles where id = '{self.uid}';""")
        return json.loads(raw)

    def league_points(self):
        return int(psql(f"""select coalesce(sum(lm.weekly_points), 0) from public.league_memberships lm
            join public.leagues l on l.id = lm.league_id where lm.user_id = '{self.uid}' and l.is_active;"""))

    def session_count(self):
        return int(psql(f"select count(*) from public.study_sessions where user_id = '{self.uid}';"))


def complete(user, minutes, started, paused=False, cat=None, cu=None, verified=None, raw_started=None, token=None):
    cu = cu or str(uuid.uuid4())
    args = {
        "p_client_uuid": cu,
        "p_category_id": cat if cat is not None else user.m,
        "p_duration_minutes": minutes,
        "p_was_paused": paused,
        "p_is_verified": verified if verified is not None else minutes * 60,
        "p_started_at": raw_started if raw_started is not None else (iso(started) if started else None),
    }
    try:
        return cu, api.rpc("complete_study_session", args, token if token is not None else user.tok), None
    except api.ApiError as e:
        return cu, None, e


def err_text(e):
    if e is None:
        return ""
    b = e.body if isinstance(e.body, dict) else {"message": str(e.body)}
    return f"{e.status} {b.get('code')} {b.get('message')}"


def expect_ok(name, res, **want):
    cu, body, e = res
    if e is not None or not isinstance(body, dict) or "error" in body:
        return check(name, False, f"hata/yanıt: {err_text(e) or body}")
    bad = {k: (body.get(k), v) for k, v in want.items() if body.get(k) != v}
    return check(name, not bad, f"farklı alanlar (gelen, beklenen): {bad}; yanıt={body}")


def expect_err(name, res, needle, status=None):
    cu, body, e = res
    if e is None:
        return check(name, False, f"hata bekleniyordu, yanıt={body}")
    txt = err_text(e)
    ok = needle.lower() in txt.lower() and (status is None or e.status == status)
    return check(name, ok, f"gelen: {txt}")


def impersonate_sql(uid):
    claims = json.dumps({"sub": uid, "role": "authenticated"})
    return f"select set_config('request.jwt.claims', '{claims}', true);\nSET LOCAL ROLE authenticated;\n"


def boundary(now, hour, min_age):
    """now'dan en az min_age önceki en yakın İstanbul hh:00 anı."""
    b = now.astimezone(IST).replace(hour=hour, minute=0, second=0, microsecond=0)
    while now - b < min_age:
        b -= dt.timedelta(days=1)
    return b.astimezone(UTC)


# ---------- senaryolar ----------

def s_config():
    section("get_points_config (anon) ve fonksiyon sabitleri")
    cfg = api.rpc("get_points_config")
    want = {"base_points_25min": 5, "base_points_50min": 12, "pause_penalty_pct": 20,
            "daily_league_session_limit": 16, "coins_per_session": 20}
    check("config sabitleri", all(cfg.get(k) == v for k, v in want.items()), cfg)
    tiers = [(t["min_days"], t["bonus_pct"]) for t in cfg.get("streak_bonus_tiers", [])]
    check("config seri kademeleri 3/7/14 → 10/20/30", tiers == [(3, 10), (7, 20), (14, 30)], tiers)
    body = psql("select pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure);")
    for frag, label in [("v_base_points := 5", "25dk=5"), ("v_base_points := 12", "50dk=12"),
                        ("ceil(v_base_points * 0.20)", "duraklatma %20 ceil"), ("v_daily_sessions >= 16", "tavan 16"),
                        ("v_coins_earned integer := 20", "kum 20"), ("v_bonus_streak >= 14", "seri 14"),
                        ("v_bonus_pct := 30", "%30"), ("interval '4 hours'", "gün 04:00")]:
        check(f"fonksiyon gövdesi config ile aynı: {label}", frag in body, frag)
    return cfg


def s_basic(now):
    section("A: 25/50 dk, duraklatma, tekrar (duplicate), çakışma, profil ve lig toplamları")
    a = User("a")
    p0 = a.profile()
    check("yeni profil başlangıcı 0 puan / 0 kum / 0 seri", (p0["lifetime_points"], p0["coins"], p0["current_streak"]) == (0, 0, 0), p0)
    T = now.replace(second=0, microsecond=0)
    a1_start = T - 30 * MIN
    r_a1 = complete(a, 25, a1_start)
    expect_ok("A1 25 dk → 5/0/5, kum 20, seri 1", r_a1, base_points=5, bonus_points=0, total_points=5,
              coins_earned=20, streak=1, bonus_pct=0, duplicate=False, daily_limit_reached=False)
    row = psql(f"""select base_points, bonus_points, duration_minutes, category, was_paused, is_verified,
        to_char(started_at at time zone 'utc','HH24:MI'), to_char(completed_at at time zone 'utc','HH24:MI')
        from public.study_sessions where client_uuid = '{r_a1[0]}';""")
    exp_row = f"5|0|25|Matematik|f|1500|{a1_start.strftime('%H:%M')}|{(a1_start + 25 * MIN).strftime('%H:%M')}"
    check("A1 study_sessions satırı (completed_at = started_at + 25)", row == exp_row, f"{row} != {exp_row}")
    p1 = a.profile()
    check("A1 profil: puan 5, kum 20, 25 dk, seri 1, last_study_date",
          (p1["lifetime_points"], p1["coins"], p1["total_minutes"], p1["current_streak"], p1["last_study_date"])
          == (5, 20, 25, 1, str(study_day(a1_start))), p1)
    check("A1 lig haftalık puanı 5", a.league_points() == 5, a.league_points())

    # Aynı client_uuid ile tekrar (yanıtı kaybolmuş seans)
    r_dup = complete(a, 25, a1_start, cu=r_a1[0])
    cu, body, e = r_dup
    check("A2 duplicate: duplicate=true, kum 0", e is None and body.get("duplicate") is True and body.get("coins_earned") == 0, body or err_text(e))
    check("A2 duplicate profil/lig/satır değişmedi", a.profile() == p1 and a.league_points() == 5 and a.session_count() == 1, a.profile())
    dup_original_points = e is None and body.get("total_points") == 5 and body.get("base_points") == 5
    check("A2 duplicate: ilk kaydın puanı döner; profil/lig yukarıda değişmedi", dup_original_points,
          f"duplicate yanıtı ilk kaydın puanını döndürüyor: base={body.get('base_points') if body else None}, total={body.get('total_points') if body else None}")
    r_dup_bad = complete(a, 30, None, cu=r_a1[0])
    check("A2b duplicate doğrulamadan önce: geçersiz süre/null started_at ile aynı uuid → duplicate", r_dup_bad[2] is None and r_dup_bad[1].get("duplicate") is True, r_dup_bad[1] or err_text(r_dup_bad[2]))

    # Dokunan seans (bitişi A1 başlangıcına eşit) çakışma sayılmaz
    r_touch = complete(a, 25, T - 55 * MIN)
    expect_ok("A3 uç uca (A1'e dokunan) seans kabul", r_touch, total_points=5, streak=1)
    # 50 dk duraklatılmış
    r_50p = complete(a, 50, T - 115 * MIN, paused=True)
    expect_ok("A4 50 dk duraklatılmış → 12-ceil(2.4)=9", r_50p, base_points=9, total_points=9, coins_earned=20)
    # 25 dk duraklatılmış
    r_25p = complete(a, 25, T - 200 * MIN, paused=True)
    expect_ok("A5 25 dk duraklatılmış → 5-ceil(1)=4", r_25p, base_points=4, total_points=4)
    # 50 dk normal
    r_50 = complete(a, 50, T - 290 * MIN)
    expect_ok("A6 50 dk → 12", r_50, base_points=12, total_points=12)
    before = (a.profile(), a.league_points(), a.session_count())
    r_ov = complete(a, 25, T - 40 * MIN)
    cu, body, e = r_ov
    check("A7 çakışma → {error:'overlap'} (hata değil, 200)", e is None and body == {"error": "overlap"}, body or err_text(e))
    check("A7 çakışmada profil/lig/satır değişmedi", (a.profile(), a.league_points(), a.session_count()) == before, a.profile())
    r_ov2 = complete(a, 50, T - 135 * MIN)  # 50 dk duraklatılmış seansın içine taşan
    check("A7b kısmi çakışma (50 dk) → overlap", r_ov2[2] is None and r_ov2[1] == {"error": "overlap"}, r_ov2[1] or err_text(r_ov2[2]))

    p = a.profile()
    total = 5 + 5 + 9 + 4 + 12
    check("A toplam: lifetime_points = yanıtların total_points toplamı", p["lifetime_points"] == total, p)
    check("A toplam: coins = 5 seans × 20", p["coins"] == 100, p)
    check("A toplam: total_minutes = 25+25+50+25+50", p["total_minutes"] == 175, p)
    check("A toplam: lig haftalık puanı = lifetime_points", a.league_points() == total, a.league_points())
    rk = api.rpc("get_my_league_ranking", None, a.tok)
    me = [r for r in rk if r.get("is_me")]
    check("A get_my_league_ranking is_me satırı weekly_points", len(me) == 1 and me[0]["weekly_points"] == total, rk)
    feed = psql(f"""select payload->>'session_count' from public.activity_feed
        where user_id = '{a.uid}' and activity_type = 'daily_summary' order by activity_date desc limit 1;""")
    feed_enabled = psql("select ops.activity_feed_enabled()") == "t"
    check("A activity_feed kaydı sunucu özellik anahtarına uyar", bool(feed) == feed_enabled, feed)
    return a


def s_validation(now, other):
    section("V: doğrulama sırası, tolerans, 24 saat, süre, kategori, arşiv, anon")
    v = User("v")
    T = now
    expect_ok("V1 bitişi now+4dk olan 25 dk seans kabul (5 dk tolerans)", complete(v, 25, T - 21 * MIN), total_points=5)
    expect_err("V2 bitişi now+6dk → session_not_finished", complete(v, 25, T - 19 * MIN), "session_not_finished", 400)
    expect_err("V2b 50 dk, 40 dk önce başlamış → session_not_finished", complete(v, 50, T - 40 * MIN), "session_not_finished")
    expect_err("V3 gelecekte started_at → 'started_at cannot be in the future'", complete(v, 25, T + 2 * MIN), "cannot be in the future")
    expect_err("V3b null started_at → aynı mesaj", complete(v, 25, None), "cannot be in the future")
    expect_err("V4 24 saat + 1 dk önce → older than 24 hours", complete(v, 25, T - dt.timedelta(hours=24, minutes=1)), "older than 24 hours")
    expect_ok("V5 23 sa 58 dk önce → kabul", complete(v, 25, T - dt.timedelta(hours=23, minutes=58)), total_points=5)
    for d in (30, 0, -25, 26, 100):
        expect_err(f"V6 süre {d} → invalid duration", complete(v, d, T - 3 * dt.timedelta(hours=1)), "invalid duration")
    expect_err("V7 başka kullanıcının kategorisi → category does not belong", complete(v, 25, T - 60 * MIN, cat=other.m), "category does not belong")
    expect_err("V7b var olmayan uuid kategori → category does not belong", complete(v, 25, T - 60 * MIN, cat=str(uuid.uuid4())), "category does not belong")
    expect_err("V7c UUID olmayan kategori '1' → 400 22P02 (uuid)", complete(v, 25, T - 60 * MIN, cat="1"), "22P02 invalid input syntax for type uuid", 400)
    expect_err("V7d UUID olmayan client_uuid → 400 22P02 (uuid)", complete(v, 25, T - 60 * MIN, cu="legacy-1"), "22P02", 400)
    # Arşivlenmiş kategoriyle seans (istemcinin archiveCategory PATCH'i)
    api.request("PATCH", f"/rest/v1/categories?id=eq.{v.cat['Fizik']}&user_id=eq.{v.uid}", {"is_archived": True}, token=v.tok)
    arch = psql(f"select is_archived from public.categories where id = '{v.cat['Fizik']}';")
    check("V8 hazırlık: Fizik arşivlendi", arch == "t", arch)
    r = complete(v, 25, T - 60 * MIN, cat=v.cat["Fizik"])
    expect_ok("V8 arşivlenmiş kategoriyle seans kabul (seans sürerken arşivlenen kategori)", r, total_points=5)
    check("V8 satırdaki kategori adı 'Fizik'", psql(f"select category from public.study_sessions where client_uuid='{r[0]}';") == "Fizik")
    # Saat dilimi ofsetli ISO metni
    t_off = (T - 100 * MIN).replace(microsecond=0)
    r = complete(v, 25, None, raw_started=t_off.astimezone(IST).isoformat())
    expect_ok("V9 '+03:00' ofsetli p_started_at kabul", r, total_points=5)
    stored = psql(f"select to_char(started_at at time zone 'utc','YYYY-MM-DD HH24:MI:SS') from public.study_sessions where client_uuid='{r[0]}';")
    check("V9 aynı an olarak saklandı", stored == t_off.strftime("%Y-%m-%d %H:%M:%S"), stored)
    # Dart toIso8601String (mikro saniyeli, Z) zaten tüm çağrılarda kullanılıyor; milisaniyeli de denenir.
    t_ms = (T - 140 * MIN)
    r = complete(v, 25, None, raw_started=t_ms.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%S.") + f"{t_ms.microsecond // 1000:03d}Z")
    expect_ok("V10 milisaniyeli 'Z' biçimi kabul", r, total_points=5)
    expect_ok("V11 p_is_verified=0 (hiç ön planda değil) kabul — sunucu doğrulamıyor", complete(v, 25, T - 180 * MIN, verified=0), total_points=5)
    # anon
    try:
        api.rpc("complete_study_session", {"p_client_uuid": str(uuid.uuid4()), "p_category_id": v.m, "p_duration_minutes": 25,
                                           "p_was_paused": False, "p_is_verified": 0, "p_started_at": iso(T - 220 * MIN)})
        check("V12 anon çağrı reddedilir", False, "anon kabul edildi")
    except api.ApiError as e:
        b = e.body if isinstance(e.body, dict) else {}
        check("V12 anon çağrı reddedilir (401/42501 → istemci 'auth' çevrimdışı)", e.status in (401, 403) and b.get("code") == "42501", err_text(e))
    return v


def s_day_boundary(now):
    section("B: gün sınırı (İstanbul 04:00 mı gece yarısı mı), seri, geç gelen seans")
    b = User("b")
    b4 = boundary(now, 4, 35 * MIN)
    m0 = boundary(now, 0, 35 * MIN)
    floor = now - dt.timedelta(hours=23, minutes=50)
    starts = []
    if b4 - 50 * MIN >= floor:
        starts += [b4 - 50 * MIN, b4 + 5 * MIN]
    else:
        print(f"  (04:00 sınırı pencere dışında: {b4.isoformat()})")
    if m0 - 30 * MIN >= floor:
        starts += [m0 - 30 * MIN, m0 + 5 * MIN]
    else:
        print(f"  (gece yarısı sınırı pencere dışında: {m0.isoformat()})")
    starts.sort()
    exp04 = model_streaks(starts, "04")
    exp00 = model_streaks(starts, "00")
    got = []
    for t in starts:
        cu, body, e = complete(b, 25, t)
        got.append(body.get("streak") if body else err_text(e))
    labels = [t.astimezone(IST).strftime("%m-%d %H:%M IST") for t in starts]
    check(f"B1 seri dizisi 04:00 kuralıyla aynı {list(zip(labels, got))}", got == exp04, f"gelen {got}, 04:00 modeli {exp04}, gece yarısı modeli {exp00}")
    check("B1 test ayırt edici (gece yarısı modeli farklı sonuç verirdi)", exp04 != exp00, f"{exp04} == {exp00}")
    p = b.profile()
    last_exp = str(max(study_day(t) for t in starts))
    check("B1 last_study_date = son çalışma günü (04:00 kuralı)", p["last_study_date"] == last_exp, p)
    # Geç gelen (önceki güne ait) seans: seriyi ve last_study_date'i geri almaz
    late_t = b4 - 100 * MIN
    if late_t >= floor and study_day(late_t) < study_day(max(starts)):
        streak_before = p["current_streak"]
        cu, body, e = complete(b, 25, late_t)
        ok = e is None and body.get("streak") == streak_before
        check("B2 geç gelen eski güne ait seans: seri değişmez", ok, body or err_text(e))
        p2 = b.profile()
        check("B2 geç gelen seans: last_study_date geri alınmaz", p2["last_study_date"] == p["last_study_date"] and p2["current_streak"] == streak_before, p2)
        check("B2 geç gelen seans yine de puan/kum alır", body and body.get("total_points") == 5 and body.get("coins_earned") == 20, body)
    return b


def s_daily_limit(now):
    section("C: günlük sınır (16 seans) ve daily_limit_reached")
    c = User("c")
    b4 = boundary(now, 4, 0 * MIN)
    need = 18 * 26 * MIN + 10 * MIN
    if now - b4 >= need:
        s0 = b4 + 5 * MIN
    else:
        s0 = max(b4 - dt.timedelta(days=1), now - dt.timedelta(hours=23, minutes=50)) + 5 * MIN
    starts = [s0 + i * 26 * MIN for i in range(18)]
    assert all(study_day(t) == study_day(starts[0]) for t in starts), "pencere tek çalışma gününde değil"
    assert starts[-1] + 25 * MIN <= now
    bodies = []
    for t in starts:
        cu, body, e = complete(c, 25, t)
        bodies.append(body if body else err_text(e))
    first16 = bodies[:16]
    check("C1 ilk 16 seans 5 puan / 20 kum / limit yok",
          all(isinstance(x, dict) and x.get("total_points") == 5 and x.get("coins_earned") == 20 and x.get("daily_limit_reached") is False for x in first16),
          [x if not isinstance(x, dict) else (x.get("total_points"), x.get("coins_earned"), x.get("daily_limit_reached")) for x in first16])
    for i in (16, 17):
        x = bodies[i]
        check(f"C2 {i + 1}. seans: daily_limit_reached=true, 0 puan, 0 kum, seri döner",
              isinstance(x, dict) and x.get("daily_limit_reached") is True and x.get("total_points") == 0
              and x.get("base_points") == 0 and x.get("bonus_points") == 0 and x.get("coins_earned") == 0 and x.get("streak") == 1, x)
    p = c.profile()
    check("C3 profil: puan 80, kum 320, dakika 18×25 (tavan sonrası da artar)",
          (p["lifetime_points"], p["coins"], p["total_minutes"]) == (80, 320, 450), p)
    check("C3 lig haftalık puanı 80 (tavan sonrası eklenmez)", c.league_points() == 80, c.league_points())
    rows = psql(f"select count(*) filter (where base_points = 0) from public.study_sessions where user_id = '{c.uid}';")
    check("C3 tavan sonrası 2 satır 0 puanla kaydedildi (seans silinmez)", rows == "2", rows)
    return c


def s_streak_bonus(now):
    section("S: seri bonusu kademeleri, ceil yuvarlama, seri kırılması (geri alınan transaction)")
    u = User("s")
    today = study_day(now)
    t25 = now - 30 * MIN
    cases = [
        # ad, önceki seri, last_study_date gün farkı, süre, duraklatıldı, beklenen (seri, pct, base, bonus, total)
        ("seri 2→3, 25 dk: %10 ceil(0.5)=1", 2, -1, 25, False, (3, 10, 5, 1, 6)),
        ("seri 2→3, 50 dk: %10 ceil(1.2)=2", 2, -1, 50, False, (3, 10, 12, 2, 14)),
        ("seri 2→3, 50 dk duraklatılmış: 9 + ceil(0.9)=1", 2, -1, 50, True, (3, 10, 9, 1, 10)),
        ("seri 2→3, 25 dk duraklatılmış: 4 + ceil(0.4)=1", 2, -1, 25, True, (3, 10, 4, 1, 5)),
        ("seri 6→7, 25 dk: %20 → 6", 6, -1, 25, False, (7, 20, 5, 1, 6)),
        ("seri 6→7, 50 dk: %20 ceil(2.4)=3 → 15", 6, -1, 50, False, (7, 20, 12, 3, 15)),
        ("seri 13→14, 25 dk: %30 ceil(1.5)=2 → 7", 13, -1, 25, False, (14, 30, 5, 2, 7)),
        ("seri 13→14, 50 dk: %30 ceil(3.6)=4 → 16", 13, -1, 50, False, (14, 30, 12, 4, 16)),
        ("seri 13→14, 50 dk duraklatılmış: 9 + ceil(2.7)=3 → 12", 13, -1, 50, True, (14, 30, 9, 3, 12)),
        ("seri 1→2 bonus yok", 1, -1, 25, False, (2, 0, 5, 0, 5)),
        ("aynı gün seri 5 korunur, %10", 5, 0, 25, False, (5, 10, 5, 1, 6)),
        ("2 gün ara: seri 10 kırılır → 1, bonus 0", 10, -2, 50, False, (1, 0, 12, 0, 12)),
        ("seri 29→30 (kademe yok, %30)", 29, -1, 25, False, (30, 30, 5, 2, 7)),
    ]
    for name, prev, gap, mins, paused, exp in cases:
        last = today + dt.timedelta(days=gap)
        cu = str(uuid.uuid4())
        start = now - (mins + 5) * MIN
        sql = (f"BEGIN;\nUPDATE public.profiles SET current_streak = {prev}, longest_streak = {prev}, last_study_date = '{last}', "
               f"lifetime_points = 1000, coins = 1000 WHERE id = '{u.uid}';\n"
               "SELECT coalesce(sum(lm.weekly_points),0) FROM public.league_memberships lm JOIN public.leagues l ON l.id = lm.league_id "
               f"WHERE lm.user_id = '{u.uid}' AND l.is_active;\n"
               + impersonate_sql(u.uid) +
               f"SELECT public.complete_study_session('{cu}', '{u.m}', {mins}, {str(paused).lower()}, 0, '{iso(start)}')::text;\n"
               "RESET ROLE;\n"
               f"SELECT json_build_object('lp', lifetime_points, 'coins', coins, 'cs', current_streak, 'ls', longest_streak, 'last', last_study_date)::text "
               f"FROM public.profiles WHERE id = '{u.uid}';\n"
               "SELECT coalesce(sum(lm.weekly_points),0) FROM public.league_memberships lm JOIN public.leagues l ON l.id = lm.league_id "
               f"WHERE lm.user_id = '{u.uid}' AND l.is_active;\n"
               "ROLLBACK;\n")
        out = psql(sql).splitlines()
        lg0, body, prof, lg1 = int(out[0]), json.loads(out[2]), json.loads(out[3]), int(out[4])
        got = (body.get("streak"), body.get("bonus_pct"), body.get("base_points"), body.get("bonus_points"), body.get("total_points"))
        ok = got == exp and prof["lp"] == 1000 + exp[4] and prof["coins"] == 1020 and prof["cs"] == exp[0] \
            and prof["ls"] == max(prev, exp[0]) and (lg1 - lg0) == exp[4]
        check(f"S {name}", ok, f"yanıt {got} beklenen {exp}; profil {prof}; lig Δ {lg1 - lg0}")
    # Geç seans kendi günündeki geçmiş seriyle değerlendirilir (proposed/13).
    cu = str(uuid.uuid4())
    floor = now - dt.timedelta(hours=23, minutes=50)
    t = boundary(now, 4, 0 * MIN) - 60 * MIN  # bir önceki çalışma günü 03:00 IST
    if t >= floor:
        sql = (f"BEGIN;\nUPDATE public.profiles SET current_streak = 3, longest_streak = 3, last_study_date = '{today}' WHERE id = '{u.uid}';\n"
               + impersonate_sql(u.uid) +
               f"SELECT public.complete_study_session('{cu}', '{u.m}', 25, false, 0, '{iso(t)}')::text;\nRESET ROLE;\n"
               f"SELECT current_streak || '|' || last_study_date FROM public.profiles WHERE id = '{u.uid}';\nROLLBACK;\n")
        out = psql(sql).splitlines()
        body = json.loads(out[1])
        check("S geç gelen (dünkü) seans: seri 3 korunur, last_study_date bugün kalır", out[2] == f"3|{today}" and body["streak"] == 3, out)
        check("S geç gelen seansın gününde geçmiş kayıt yoksa bugünkü seriyle bonus almaz", body["bonus_pct"] == 0 and body["total_points"] == 5, body)


def s_timezone(now):
    section("Z: profil saat dilimi (profiles.timezone) gün hesabında kullanılıyor mu")
    from zoneinfo import ZoneInfo
    u = User("z")
    t = now - 30 * MIN
    for tz in ("America/New_York", "Asia/Tokyo"):
        loc = t.astimezone(ZoneInfo(tz)) - dt.timedelta(hours=4)
        day = loc.date()
        cu = str(uuid.uuid4())
        sql = (f"BEGIN;\nUPDATE public.profiles SET timezone = '{tz}', current_streak = 4, longest_streak = 4, "
               f"last_study_date = '{day - dt.timedelta(days=1)}' WHERE id = '{u.uid}';\n"
               + impersonate_sql(u.uid) +
               f"SELECT public.complete_study_session('{cu}', '{u.m}', 25, false, 0, '{iso(t)}')::text;\nRESET ROLE;\n"
               f"SELECT current_streak || '|' || last_study_date FROM public.profiles WHERE id = '{u.uid}';\nROLLBACK;\n")
        out = psql(sql).splitlines()
        check(f"Z {tz}: çalışma günü profil diliminde 04:00 ({day}); dünkü günden seri 4→5",
              out[2] == f"5|{day}" and json.loads(out[1])["streak"] == 5, out)


def s_live(now):
    section("L: start_study_session / cancel_study_session ve canlı çalışanlar")
    e, f = User("e"), User("f")
    fc = {u.tag: psql(f"select friend_code from public.profiles where id = '{u.uid}';") for u in (e, f)}
    r1 = api.rpc("add_friend_by_code", {"p_code": fc["f"]}, e.tok)
    r2 = api.rpc("add_friend_by_code", {"p_code": fc["e"]}, f.tok)
    check("L0 arkadaşlık kuruldu (karşılıklı kod → auto_accepted)", r1.get("success") and r2.get("auto_accepted"), (r1, r2))
    api.rpc("start_study_session", {"p_duration_minutes": 25, "p_category_name": "Matematik"}, e.tok)
    p = e.profile()
    ends = dt.datetime.fromisoformat(p["active_session_ends_at"])
    dnow = db_now()
    check("L1 start: active_session_ends_at ≈ now + 25 dk, kategori adı yazıldı",
          abs((ends - dnow) - 25 * MIN) < dt.timedelta(seconds=10) and p["active_session_category_name"] == "Matematik", p)
    live = api.rpc("get_live_friends", None, f.tok)
    check("L1 arkadaş canlı listede görüyor (id, ad, kategori, ends_at)",
          len(live) == 1 and live[0]["id"] == e.uid and live[0]["category_name"] == "Matematik" and live[0]["ends_at"], live)
    check("L1 kişi kendini canlı listede görmez", api.rpc("get_live_friends", None, e.tok) == [], None)
    # complete_study_session canlı durumu temizlemez (istemci cancel çağırır)
    complete(e, 25, now - 30 * MIN)
    check("L2 complete_study_session active_session'ı temizlemiyor (temizlik istemcinin cancel çağrısında)",
          e.profile()["active_session_ends_at"] is not None, e.profile())
    fr = [x for x in api.rpc("get_my_friends", None, f.tok) if x.get("id") == e.uid]
    check("L2b arkadaş listesinde puan/dakika seans sonrası güncel (get_my_friends)",
          len(fr) == 1 and fr[0]["lifetime_points"] == 5 and fr[0]["total_minutes"] == 25, fr)
    api.rpc("cancel_study_session", None, e.tok)
    p = e.profile()
    check("L3 cancel: alanlar null, arkadaş listesinden düştü",
          p["active_session_ends_at"] is None and p["active_session_category_name"] is None and api.rpc("get_live_friends", None, f.tok) == [], p)
    # görünürlük kapalıyken
    api.request("PATCH", f"/rest/v1/profiles?id=eq.{e.uid}", {"show_in_social_feed": False}, token=e.tok)
    api.rpc("start_study_session", {"p_duration_minutes": 25, "p_category_name": "Matematik"}, e.tok)
    check("L4 show_in_social_feed=false iken canlı listede görünmez", api.rpc("get_live_friends", None, f.tok) == [], None)
    api.rpc("cancel_study_session", None, e.tok)
    api.request("PATCH", f"/rest/v1/profiles?id=eq.{e.uid}", {"show_in_social_feed": True}, token=e.tok)
    # parametre doğrulaması yok
    long_name = "X" * 5000
    try:
        api.rpc("start_study_session", {"p_duration_minutes": 100000, "p_category_name": long_name}, e.tok)
        live = api.rpc("get_live_friends", None, f.tok)
        ends = dt.datetime.fromisoformat(live[0]["ends_at"]) if live else None
        check("L5 start_study_session süre/ad doğrulaması (25/50, makul ad uzunluğu)", False,
              f"100000 dk ve 5000 karakterlik ad kabul edildi; arkadaş {((ends - dnow).days if ends else '?')} gün boyunca 'canlı' görüyor, ad uzunluğu {len(live[0]['category_name']) if live else '?'}")
    except api.ApiError as ex:
        check("L5 start_study_session süre/ad doğrulaması", True, err_text(ex))
    api.rpc("cancel_study_session", None, e.tok)
    try:
        api.rpc("start_study_session", {"p_duration_minutes": 25, "p_category_name": "x"}, None)
        prof_cnt = psql("select count(*) from public.profiles where active_session_category_name = 'x';")
        check("L6 anon start_study_session reddedilir", False, f"anon kabul edildi (etkilenen profil {prof_cnt})")
    except api.ApiError as ex:
        check("L6 anon start_study_session reddedilir", ex.status in (401, 403), err_text(ex))
    return e, f


def _race_psql(uid, cat, cu1, t1, cu2, t2):
    """conn1 seansı yazar ama commit etmez; conn2 aynı kullanıcı için ikinci seansı gönderir
    (profil FOR UPDATE kilidinde bekler); conn1 commit → conn2'nin sonucu döner."""
    base = ["psql", DB, "-XAtq", "-v", "ON_ERROR_STOP=1"]
    p1 = subprocess.Popen(base, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    p1.stdin.write("BEGIN;\n" + impersonate_sql(uid) +
                   f"SELECT public.complete_study_session('{cu1}', '{cat}', 25, false, 1500, '{iso(t1)}')::text;\n")
    p1.stdin.flush()
    time.sleep(1.0)
    p2 = subprocess.Popen(base, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    p2.stdin.write("BEGIN;\n" + impersonate_sql(uid) +
                   f"SELECT public.complete_study_session('{cu2}', '{cat}', 25, false, 1500, '{iso(t2)}')::text;\nCOMMIT;\n")
    p2.stdin.close()
    time.sleep(1.5)
    blocked = p2.poll() is None
    p1.stdin.write("COMMIT;\n")
    p1.stdin.close()
    o1, e1 = p1.communicate(timeout=20)
    o2, e2 = p2.communicate(timeout=20)
    return blocked, (o1.strip(), e1.strip()), (o2.strip(), e2.strip())


def s_concurrency(now):
    section("R: eşzamanlılık (iki cihaz aynı anda gönderir)")
    g = User("g")
    t1 = now - 60 * MIN
    t2 = now - 50 * MIN  # t1 ile çakışır
    cu1, cu2 = str(uuid.uuid4()), str(uuid.uuid4())
    blocked, r1, r2 = _race_psql(g.uid, g.m, cu1, t1, cu2, t2)
    check("R1 hazırlık: ikinci çağrı profil kilidinde bekledi", blocked, "beklemedi")
    n = g.session_count()
    p = g.profile()
    ok = n == 1
    check("R1 eşzamanlı ÇAKIŞAN iki seans: yalnızca biri kabul edilmeli (overlap)", ok,
          f"ikisi de kaydedildi: satır={n}, puan={p['lifetime_points']}, kum={p['coins']}, lig={g.league_points()}; conn2 yanıtı={r2[0] or r2[1]}")
    overl = psql(f"""select count(*) from public.study_sessions a join public.study_sessions b
        on a.user_id = b.user_id and a.id < b.id and a.started_at < b.completed_at and b.started_at < a.completed_at
        where a.user_id = '{g.uid}';""")
    check("R1 kalıcı durumda çakışan seans çifti yok", overl == "0", f"çakışan çift sayısı {overl}")
    # aynı client_uuid ile yarış
    cu3 = str(uuid.uuid4())
    t3 = now - 200 * MIN
    blocked, r1, r2 = _race_psql(g.uid, g.m, cu3, t3, cu3, t3)
    cnt = psql(f"select count(*) from public.study_sessions where client_uuid = '{cu3}';")
    check("R2 aynı client_uuid eşzamanlı: tek satır; ikinci çağrı duplicate=true",
          cnt == "1" and not r2[1] and json.loads(r2[0].splitlines()[-1]).get("duplicate") is True, f"satır={cnt}, conn2={r2}")
    # Gerçek HTTP ile paralel istekler (iki cihaz)
    h = User("h")
    both = 0
    trials = 8
    for k in range(trials):
        tk = now - (40 + 60 * k) * MIN
        res = [None, None]

        def fire(i):
            res[i] = complete(h, 25, tk + i * 3 * MIN)
        th = [threading.Thread(target=fire, args=(i,)) for i in range(2)]
        for x in th:
            x.start()
        for x in th:
            x.join()
        oks = sum(1 for r in res if r[2] is None and isinstance(r[1], dict) and "error" not in r[1])
        if oks == 2:
            both += 1
    p = h.profile()
    check(f"R3 HTTP paralel çakışan çiftler ({trials} deneme): hiçbirinde ikisi birden kabul edilmemeli", both == 0,
          f"{both}/{trials} denemede iki çakışan seans da kabul edildi; puan={p['lifetime_points']} (çakışmasız beklenen {trials * 5}), kum={p['coins']}")
    # Aynı 25 dakikalık aralık için 16 paralel istek: günlük tavanın tamamı tek seansın süresinde
    k = User("k")
    tk = now - 30 * MIN
    res = [None] * 16

    def fire16(i):
        res[i] = complete(k, 25, tk)
    th = [threading.Thread(target=fire16, args=(i,)) for i in range(16)]
    for x in th:
        x.start()
    for x in th:
        x.join()
    accepted = sum(1 for r in res if r[2] is None and isinstance(r[1], dict) and "error" not in r[1])
    p = k.profile()
    check("R4 aynı aralık için 16 paralel istek: en fazla 1 kabul", accepted <= 1,
          f"{accepted}/16 kabul; 25 dakikalık tek aralıktan puan={p['lifetime_points']}, kum={p['coins']}, lig={k.league_points()}, total_minutes={p['total_minutes']}")
    return g, h


def main():
    print(f"t1 sunucu E2E — çalıştırma kimliği {RUN}, API {api.API_URL}")
    now = db_now()
    print(f"DB now() = {now.isoformat()}  (İstanbul {now.astimezone(IST).strftime('%Y-%m-%d %H:%M')}, çalışma günü {study_day(now)})")
    s_config()
    a = s_basic(db_now())
    s_validation(db_now(), a)
    s_day_boundary(db_now())
    s_daily_limit(db_now())
    s_streak_bonus(db_now())
    s_timezone(db_now())
    s_live(db_now())
    s_concurrency(db_now())
    fails = [r for r in RESULTS if not r[0]]
    print(f"\nSONUÇ: {len(RESULTS) - len(fails)}/{len(RESULTS)} geçti")
    for _, name, detail in fails:
        print(f"  BULGU/FAIL: {name}\n      {detail}")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
