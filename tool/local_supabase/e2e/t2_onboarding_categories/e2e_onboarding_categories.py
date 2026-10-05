#!/usr/bin/env python3
"""t2 — Onboarding ve kategoriler: uçtan uca test (YALNIZCA yerel kopya).

    python3 tool/local_supabase/e2e/t2_onboarding_categories/e2e_onboarding_categories.py

Her senaryo kendi t2-<senaryo>-<zaman>@pomosprint.local hesabını açar;
test1/test2'ye dokunmaz. Küresel durumu değiştirebilecek denemeler
(premium bayrağı, sunucu fonksiyonunu doğrudan çağırma) geri alınan
transaction içinde yapılır. İstemci akışı lib/'deki çağrılarla aynı sırada
taklit edilir (client_model.py değerleri Dart kaynaklarından okur):

  kayıt (auth.signUp metadata) → handle_new_user → _ensureOwnProfile
  → setup_onboarding_categories(p_categories) → profiles PATCH
  (onboardingProfileUpdate, select=id) → fetchUserCategories.

Çıktı: her denetim için OK/FAIL satırı ve en sonda özet. FAIL satırları
bulgudur (beklenen davranış "olması gereken" olarak yazıldı).
"""

import datetime as dt
import json
import os
import subprocess
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..")))
sys.path.insert(0, HERE)

import local_api as api  # noqa: E402
import client_model as cm  # noqa: E402

DB = "postgresql://postgres:postgres@127.0.0.1:54322/postgres"
RUN = time.strftime("%m%d%H%M%S")
RESULTS = []


def check(sid, name, ok, detail=""):
    RESULTS.append((sid, name, bool(ok), detail))
    print(("OK   " if ok else "FAIL ") + f"[{sid}] {name}" + (f"  -- {detail}" if detail else ""), flush=True)
    return ok


def psql(sql):
    p = subprocess.run(["psql", DB, "-X", "-At", "-q", "-v", "ON_ERROR_STOP=1"], input=sql,
                       capture_output=True, text=True, timeout=120)
    return p.returncode, p.stdout.strip(), p.stderr.strip()


def psql_val(sql):
    rc, out, err = psql(sql)
    if rc != 0:
        raise RuntimeError(err)
    return out


def as_user_tx(uid, body):
    """Kullanıcı taklidi; her zaman ROLLBACK."""
    return psql(
        "BEGIN;\n"
        f"select set_config('request.jwt.claims', json_build_object('sub','{uid}','role','authenticated')::text, true) is not null as _;\n"
        "SET LOCAL ROLE authenticated;\n"
        f"{body}\nROLLBACK;\n"
    )


def err_body(e):
    return e.body if isinstance(e, api.ApiError) else str(e)


def classify(e):
    """lib/services/service_errors.dart serviceErrorCodeOf (PostgrestException kolu)."""
    if not isinstance(e, api.ApiError) or not isinstance(e.body, dict):
        return "unknown"
    message = (e.body.get("message") or "").lower()
    code = e.body.get("code") or ""
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


class Client:
    """Uygulamadaki SupabaseService akışının REST karşılığı."""

    def __init__(self, tag, name="T2 Kullanıcı", avatar_id="avatar_16_basic", newsletter=False, data=None):
        self.email = f"t2-{tag}-{RUN}@pomosprint.local"
        meta = data if data is not None else {
            # SupabaseService.signUpMetadata + RegistrationConsent.toMetadata
            "name": name,
            "avatar_id": avatar_id,
            "newsletter": newsletter,
            "marketing_consent": newsletter,
            "terms_version": api.LEGAL_VERSION,
            "privacy_version": api.LEGAL_VERSION,
            "terms_accepted_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        }
        self.meta = meta
        r = api.request("POST", "/auth/v1/signup", {"email": self.email, "password": api.TEST_PASSWORD, "data": meta})
        self.token = r["access_token"]
        self.uid = r["user"]["id"]

    # --- REST ---
    def select(self, table, query):
        return api.select(table, query, self.token)

    def rpc(self, name, args=None):
        return api.rpc(name, args or {}, self.token)

    def profile(self):
        rows = self.select("profiles", f"select={cm.OWN_PROFILE_COLUMNS}&id=eq.{self.uid}")
        return rows[0] if rows else None

    def patch_profile(self, update, uid=None):
        return api.request("PATCH", f"/rest/v1/profiles?id=eq.{uid or self.uid}&select=id", update,
                           token=self.token, headers={"Prefer": "return=representation"})

    def ensure_own_profile(self, requested_avatar=None):
        """SupabaseService._ensureOwnProfile: varsa oku, yoksa ignore-duplicates upsert."""
        row = self.profile()
        if row is not None:
            return row, False
        api.request("POST", "/rest/v1/profiles?on_conflict=id", {
            "id": self.uid,
            "email": self.email,
            "name": self.meta.get("name") or self.email.split("@")[0],
            "avatar_id": requested_avatar or self.meta.get("avatar_id") or "avatar_16_basic",
        }, token=self.token, headers={"Prefer": "resolution=ignore-duplicates,return=minimal"})
        return self.profile(), True

    def setup_categories(self, payload):
        return self.rpc("setup_onboarding_categories", {"p_categories": payload})

    def complete_onboarding(self, birth_year, segment, goal, payload, show):
        """SupabaseService.completeOnboarding sırası: profil → kategoriler → PATCH."""
        self.ensure_own_profile()
        if payload:
            self.setup_categories(payload)
        completed = dt.datetime.now(dt.timezone.utc).isoformat()
        update = cm.onboarding_profile_update(birth_year, segment, goal, show, completed)
        rows = self.patch_profile(update)
        if not rows:
            raise RuntimeError("notFound: profil güncellemesi satıra uymadı")
        return update

    def categories(self, include_archived=False):
        q = "select=id,name,color_hex,icon_name,sort_order,is_archived,created_at"
        q += f"&user_id=eq.{self.uid}"
        if not include_archived:
            q += "&is_archived=eq.false"
        q += "&order=sort_order.asc,created_at.asc,id.asc"
        return self.select("categories", q)


def expect_api_error(fn):
    try:
        fn()
    except api.ApiError as e:
        return e
    return None


# ---------------------------------------------------------------------------
# A. Kayıt → handle_new_user → profil varsayılanları
# ---------------------------------------------------------------------------
def scenario_signup():
    sid = "A"
    c = Client("a-signup", name="Ayşe Yılmaz", newsletter=True)
    raw = json.loads(psql_val(f"select raw_user_meta_data from auth.users where id='{c.uid}'"))
    for k in ("name", "avatar_id", "newsletter", "marketing_consent", "terms_version", "privacy_version",
              "terms_accepted_at"):
        check(sid, f"metadata '{k}' auth.users.raw_user_meta_data'ya yazıldı", raw.get(k) == c.meta[k],
              f"{raw.get(k)!r}")
    p = c.profile()
    check(sid, "handle_new_user profili açtı ve istemci ownProfileColumns ile okuyabiliyor", p is not None)
    check(sid, "ad metadata'dan", p["name"] == "Ayşe Yılmaz", p["name"])
    check(sid, "avatar varsayılan avatar_16_basic", p["avatar_id"] == "avatar_16_basic", p["avatar_id"])
    check(sid, "friend_code 6 karakter büyük harf/rakam",
          isinstance(p["friend_code"], str) and len(p["friend_code"]) == 6 and p["friend_code"] == p["friend_code"].upper(),
          p["friend_code"])
    check(sid, "sayaçlar sıfır, lig kademesi 1, premium değil",
          (p["coins"], p["lifetime_points"], p["total_minutes"], p["current_streak"], p["league_tier"], p["is_premium"])
          == (0, 0, 0, 0, 1, False), str((p["coins"], p["lifetime_points"], p["league_tier"], p["is_premium"])))
    check(sid, "onboarding alanları boş (segment, doğum yılı, hedef, onboarding_completed_at)",
          all(p[k] is None for k in ("user_segment", "birth_year", "daily_goal_minutes", "onboarding_completed_at")))
    check(sid, "Açık seçim öncesi sosyal görünürlük varsayılanı FALSE", p["show_in_social_feed"] is False)
    check(sid, "timezone varsayılanı Europe/Istanbul", p["timezone"] == "Europe/Istanbul", p["timezone"])
    unlocked = c.select("avatar_unlocks", f"select=avatar_id&user_id=eq.{c.uid}")
    n_default = int(psql_val("select count(*) from avatars where is_default and is_active"))
    check(sid, "give_default_avatars varsayılan avatarları açtı", len(unlocked) == n_default,
          f"{len(unlocked)}/{n_default}")
    cats = c.categories(include_archived=True)
    check(sid, "kayıtta sunucu hiç kategori AÇMAZ (kategori onboarding'de kurulur)", cats == [], str(len(cats)))
    sub = psql_val(f"select count(*) from marketing_subscribers where user_id='{c.uid}'")
    check(sid, "newsletter=true → marketing_subscribers satırı (yerel otomatik onay)", sub == "1", sub)

    c2 = Client("a-nonews", newsletter=False)
    sub2 = psql_val(f"select count(*) from marketing_subscribers where user_id='{c2.uid}'")
    check(sid, "newsletter=false → abonelik satırı yok", sub2 == "0", sub2)

    c3 = Client("a-paidavatar", avatar_id="avatar_1_gamer")
    check(sid, "ücretli avatar istenirse avatar_16_basic'e zorlanır", c3.profile()["avatar_id"] == "avatar_16_basic",
          c3.profile()["avatar_id"])

    c4 = Client("a-blankname", name="   ")
    check(sid, "boş ad → e-posta açığa çıkarmayan nötr ad", c4.profile()["name"].startswith("Pomo ") and c4.email.split("@")[0] not in c4.profile()["name"], c4.profile()["name"])

    c5 = Client("a-longname", name="X" * 60)
    check(sid, "60 karakterlik ad 50'ye kesilir (CHECK 1..50)", len(c5.profile()["name"]) == 50,
          str(len(c5.profile()["name"])))

    # _ensureOwnProfile: profil varken upsert yolu çalışmaz; çalışsa bile ignore-duplicates ad/avatarı ezmez.
    api.request("POST", "/rest/v1/profiles?on_conflict=id",
                {"id": c.uid, "email": c.email, "name": "Ezildi", "avatar_id": "avatar_1_gamer"},
                token=c.token, headers={"Prefer": "resolution=ignore-duplicates,return=minimal"})
    p2 = c.profile()
    check(sid, "mevcut profilde ignore-duplicates upsert hata vermez ve ad/avatarı ezmez",
          p2["name"] == "Ayşe Yılmaz" and p2["avatar_id"] == "avatar_16_basic", f"{p2['name']}/{p2['avatar_id']}")

    # Yedek akış: profil satırı yoksa istemci upsert'i profili açar (sanitize + give_default_avatars).
    c6 = Client("a-fallback", name="Yedek Kişi")
    psql_val(f"delete from public.profiles where id='{c6.uid}'")  # yalnızca kendi test hesabımız
    row, created = c6.ensure_own_profile(requested_avatar="avatar_1_gamer")
    check(sid, "profil yoksa istemci upsert'i (id,email,name,avatar_id) satırı açar", created and row is not None)
    check(sid, "yedek akışta ücretli avatar sanitize_profile_insert ile varsayılana çekilir",
          row and row["avatar_id"] == "avatar_16_basic", row and row["avatar_id"])
    n6 = len(c6.select("avatar_unlocks", f"select=avatar_id&user_id=eq.{c6.uid}"))
    check(sid, "yedek akışta da varsayılan avatarlar açılır", n6 == n_default, str(n6))
    return c


# ---------------------------------------------------------------------------
# B. Her segment için onboarding (TR) → önerilen kategoriler sunucuda
# ---------------------------------------------------------------------------
def verify_categories(sid, label, c, expected_payload):
    rows = c.categories()
    names = [r["name"] for r in rows]
    exp_names = [p["name"] for p in expected_payload]
    check(sid, f"{label}: adlar ve sıra istemcinin seçim sırasıyla aynı", names == exp_names,
          f"sunucu={names} beklenen={exp_names}")
    check(sid, f"{label}: renkler paletten sırayla", [r["color_hex"] for r in rows] == [p["color_hex"] for p in expected_payload],
          str([r["color_hex"] for r in rows]))
    check(sid, f"{label}: sort_order 0..n-1", [r["sort_order"] for r in rows] == list(range(len(rows))),
          str([r["sort_order"] for r in rows]))
    check(sid, f"{label}: icon_name 'book', arşivsiz", all(r["icon_name"] == "book" and not r["is_archived"] for r in rows))
    return rows


def scenario_segments():
    sid = "B"
    year = dt.date.today().year
    cases = [
        ("lgs", 2012, True, 60),
        ("yks", 2008, True, 120),
        ("university", 2004, False, 180),
        ("work", 1990, True, 240),
        (cm.OTHER_SEGMENT, 1985, False, 60),
        (None, 2000, True, 120),  # segment seçmeden "Devam"
    ]
    for seg, by, show, goal in cases:
        label = f"segment={seg}"
        c = Client(f"b-{seg or 'none'}")
        rec = cm.recommended_for(seg)
        # Kullanıcı önerileri ters sırayla seçer (seçim sırası korunmalı); limit 8.
        chosen = list(reversed(rec))[: cm.FREE_LIMIT]
        payload = cm.category_payload(chosen, turkish=True)
        upd = c.complete_onboarding(by, seg, goal, payload, show)
        verify_categories(sid, label, c, payload)
        p = c.profile()
        exp_seg = seg if seg in cm.VALID_SEGMENTS else None
        check(sid, f"{label}: user_segment={exp_seg!r}", p["user_segment"] == exp_seg, repr(p["user_segment"]))
        check(sid, f"{label}: birth_year/daily_goal/show_in_social_feed yazıldı",
              (p["birth_year"], p["daily_goal_minutes"], p["show_in_social_feed"]) == (by, goal, show),
              str((p["birth_year"], p["daily_goal_minutes"], p["show_in_social_feed"])))
        check(sid, f"{label}: onboarding_completed_at dolu → AppGate kabuğa geçer",
              p["onboarding_completed_at"] is not None, p["onboarding_completed_at"])
        if seg == "yks":
            check(sid, "yks: 9 öneriden en çok 8'i seçilebilir (ücretsiz limit)", len(rec) == 9 and len(c.categories()) == 8,
                  f"öneri={len(rec)} kurulan={len(c.categories())}")
        if seg in (cm.OTHER_SEGMENT, None):
            check(sid, f"{label}: genel öneriler (Ders Çalışma, Okuma, Öğrenme, Proje) kuruldu",
                  sorted(r["name"] for r in c.categories()) == sorted(cm.GENERAL))
        _ = (upd, year)

    # Segment kümesi: kullanıcının sorduğu ilgi alanları istemcide ve sunucuda var mı?
    asked = {"kpss": "KPSS", "language": "dil (yabancı dil / YDS)"}
    present = set(cm.SEGMENT_BUTTONS)
    for key, label in asked.items():
        check(sid, f"ilgi alanı seçeneği '{label}' onboarding'de var", key in present,
              f"istemci segmentleri={cm.SEGMENT_BUTTONS}")
    c = Client("b-kpss")
    e = expect_api_error(lambda: c.patch_profile({"user_segment": "kpss"}))
    check(sid, "Güncel sunucu CHECK KPSS segmentini kabul eder",
          e is None and c.profile()["user_segment"] == "kpss", str(err_body(e)))


# ---------------------------------------------------------------------------
# C. İngilizce arayüz: adlar İngilizce saklanır, eşleme anahtarı TR'ye döner
# ---------------------------------------------------------------------------
def scenario_english():
    sid = "C"
    for seg in ("lgs", "yks", "university", "work", None):
        c = Client(f"c-en-{seg or 'none'}")
        chosen = cm.recommended_for(seg)[: cm.FREE_LIMIT]
        payload = cm.category_payload(chosen, turkish=False)
        untranslated = [n for n in chosen if cm.translate_cat_name(n, False) == n]
        check(sid, f"EN segment={seg}: tüm öneriler category_names.dart'ta İngilizce karşılığa sahip",
              not untranslated, str(untranslated))
        c.complete_onboarding(2000, seg, 60, payload, True)
        rows = verify_categories(sid, f"EN segment={seg}", c, payload)
        keys_ok = all(cm.category_match_key(r["name"]) == cm.category_match_key(n) for r, n in zip(rows, chosen))
        check(sid, f"EN segment={seg}: categoryMatchKey İngilizce adı Türkçe anahtara eşler (kuyruk/rapor)", keys_ok)
        check(sid, f"EN segment={seg}: TR arayüzde translateCatName Türkçe gösterir",
              [cm.translate_cat_name(r["name"], True) for r in rows] == chosen)
        tz = c.profile()["timezone"]
        check(sid, f"EN segment={seg}: mevcut onboarding profilin varsayılan saat dilimini korur",
              tz == "Europe/Istanbul", f"Bilinen ürün sınırlaması: cihaz IANA dilimi henüz yazılmıyor; timezone={tz}")


# ---------------------------------------------------------------------------
# D. Tekrar çalıştırma: çoğalma, yarıda kalan onboarding, dil değişimi
# ---------------------------------------------------------------------------
def scenario_idempotency():
    sid = "D"
    c = Client("d-rerun")
    chosen = ["Matematik", "Fizik", "Kimya"]
    payload = cm.category_payload(chosen)
    c.complete_onboarding(2008, "yks", 60, payload, True)
    first = c.categories()
    first_done = c.profile()["onboarding_completed_at"]
    c.complete_onboarding(2008, "yks", 60, payload, True)
    second = c.categories()
    check(sid, "aynı onboarding iki kez → kategori çoğalmaz, kimlik/sıra aynı",
          [(r["id"], r["sort_order"]) for r in first] == [(r["id"], r["sort_order"]) for r in second],
          f"{len(first)} → {len(second)}")
    check(sid, "ikinci tamamlama onboarding_completed_at'i yeniler (zararsız)",
          c.profile()["onboarding_completed_at"] >= first_done)

    # Yarıda kalan onboarding: kategoriler kuruldu, profil PATCH'i yapılamadı (ağ koptu).
    c2 = Client("d-partial")
    c2.ensure_own_profile()
    c2.setup_categories(cm.category_payload(cm.recommended_for("yks")[:8]))
    p = c2.profile()
    check(sid, "yarıda kalan onboarding: onboarding_completed_at NULL kalır → AppGate onboarding'i yeniden gösterir",
          p["onboarding_completed_at"] is None)
    # Kullanıcı ikinci denemede farklı segment seçiyor (taslak 'work').
    new_choice = cm.recommended_for("work")
    try:
        c2.complete_onboarding(1995, "work", 60, cm.category_payload(new_choice), True)
        ok_call = True
    except api.ApiError as e:
        ok_call = False
        print("  hata:", err_body(e))
    names = [r["name"] for r in c2.categories()]
    check(sid, "ikinci deneme hata vermeden biter (RPC limitte sessizce durur)", ok_call)
    check(sid, "ikinci denemede seçilen kategoriler kullanıcıya ulaşmalı (work: Derin Çalışma, Okuma, Öğrenme, Proje)",
          all(n in names for n in new_choice),
          f"sunucudaki aktif={names}; yeni seçimden eksik={[n for n in new_choice if n not in names]}")
    check(sid, "segment 'work' ama kategoriler hâlâ YKS dersleri olmamalı",
          not any(n in names for n in ("Fizik", "Kimya", "Biyoloji")), str(names))

    # Dil değişip tekrar: TR kurulumdan sonra EN arayüzle aynı seçim.
    c3 = Client("d-lang")
    lgs = cm.recommended_for("lgs")
    c3.ensure_own_profile()
    c3.setup_categories(cm.category_payload(lgs, turkish=True))
    c3.complete_onboarding(2012, "lgs", 60, cm.category_payload(lgs, turkish=False), True)
    rows = c3.categories()
    keys = [cm.category_match_key(r["name"]) for r in rows]
    dupes = sorted({k for k in keys if keys.count(k) > 1})
    check(sid, "TR yarım kurulum + EN tekrar → aynı ders iki kez oluşmamalı (dilden bağımsız eşleme)",
          not dupes, f"aktif={[r['name'] for r in rows]} çift anahtarlar={dupes}")

    # Aynı istekte aynı ad iki kez.
    c4 = Client("d-samepayload")
    c4.ensure_own_profile()
    c4.setup_categories([{"name": "Okuma", "color_hex": "#EF4444", "icon_name": "book"},
                         {"name": "Okuma", "color_hex": "#3B82F6", "icon_name": "book"}])
    rows = c4.categories()
    check(sid, "aynı istekte aynı ad iki kez → tek kategori, hata yok", [r["name"] for r in rows] == ["Okuma"],
          str([r["name"] for r in rows]))


# ---------------------------------------------------------------------------
# E. Kategori sınırı (8 / 15), create_category hata sınıflandırması
# ---------------------------------------------------------------------------
def scenario_limits():
    sid = "E"
    c = Client("e-limit")
    c.ensure_own_profile()
    names = [f"Ders {i}" for i in range(1, 11)]
    r = c.setup_categories(cm.category_payload(names))
    rows = c.categories()
    check(sid, "ücretsiz: 10 kategori gönderilince 8'i kurulur, RPC hata vermez", len(rows) == 8 and isinstance(r, dict) and r["skipped_limit"] == 2,
          f"kurulan={len(rows)}")
    check(sid, "limitte ilk 8 (gönderim sırası) kalır", [x["name"] for x in rows] == names[:8])
    e = expect_api_error(lambda: c.rpc("create_category", {"p_name": "Fazla", "p_color_hex": "#EF4444", "p_icon_name": "book"}))
    check(sid, "create_category 9. kategoride reddedilir → istemci categoryLimitReached",
          e is not None and classify(e) == "categoryLimitReached", f"{err_body(e)} → {classify(e) if e else None}")
    e = expect_api_error(lambda: api.request("POST", "/rest/v1/categories",
                                             {"user_id": c.uid, "name": "Doğrudan", "color_hex": "#EF4444"},
                                             token=c.token))
    check(sid, "doğrudan INSERT de limit trigger'ına takılır", e is not None and classify(e) == "categoryLimitReached",
          str(err_body(e)))
    # Arşivlenen kategori sayılmaz; onboarding tekrarında yeniden açılabilir.
    first_id = rows[0]["id"]
    api.request("PATCH", f"/rest/v1/categories?id=eq.{first_id}&user_id=eq.{c.uid}", {"is_archived": True}, token=c.token)
    c.setup_categories(cm.category_payload(["Ders 1"]))
    act = [x["name"] for x in c.categories()]
    check(sid, "Yarım onboarding seçimi değişince arşivdeki aynı kimlik geri açılır",
          act == ["Ders 1"] and c.categories()[0]["id"] == first_id, str(act))
    c.setup_categories(cm.category_payload(names[:8]))
    api.request("PATCH", f"/rest/v1/categories?id=eq.{first_id}&user_id=eq.{c.uid}", {"is_archived": True}, token=c.token)
    c.rpc("create_category", {"p_name":"Yeni Ders","p_color_hex":"#EF4444","p_icon_name":"book"})
    e = expect_api_error(lambda: api.request("PATCH", f"/rest/v1/categories?id=eq.{first_id}&user_id=eq.{c.uid}",
                                             {"is_archived": False}, token=c.token))
    check(sid, "limitteyken arşivden çıkarma reddedilir", e is not None, str(err_body(e)))

    # Premium (geri alınan transaction): 16 ad → 15.
    c2 = Client("e-premium")
    c2.ensure_own_profile()
    payload = json.dumps(cm.category_payload([f"P{i}" for i in range(1, 17)])).replace("'", "''")
    rc, out, err = psql(
        "BEGIN;\n"
        f"update profiles set is_premium=true where id='{c2.uid}';\n"
        f"select set_config('request.jwt.claims', json_build_object('sub','{c2.uid}','role','authenticated')::text, true) is not null;\n"
        "SET LOCAL ROLE authenticated;\n"
        f"select public.setup_onboarding_categories('{payload}'::jsonb);\n"
        f"select 'N=' || count(*) from categories where user_id='{c2.uid}' and not is_archived;\n"
        "ROLLBACK;\n")
    check(sid, "premium: 16 gönderilince 15 kurulur (geri alındı)", "N=15" in out, out or err)


# ---------------------------------------------------------------------------
# F. Özel kategori ve sunucu doğrulaması
# ---------------------------------------------------------------------------
def scenario_custom_and_validation():
    sid = "F"
    c = Client("f-custom")
    chosen = ["Matematik", "Kendi Kategorim", "Fen Bilimleri"]
    payload = cm.category_payload(chosen)
    c.complete_onboarding(2012, "lgs", 60, payload, True)
    verify_categories(sid, "özel kategori karışık", c, payload)

    c2 = Client("f-validate")
    c2.ensure_own_profile()
    weird = [
        {"name": "", "color_hex": "#EF4444", "icon_name": "book"},
        {"name": "   ", "color_hex": "#EF4444", "icon_name": "book"},
        {"name": "Y" * 300, "color_hex": "#EF4444", "icon_name": "book"},
        {"name": "RenkBozuk", "color_hex": "kirmizi", "icon_name": "<script>"},
    ]
    try:
        c2.setup_categories(weird)
    except api.ApiError as e:
        print("  hata:", err_body(e))
    rows = c2.categories()
    accepted = [(len(r["name"]), r["name"][:12], r["color_hex"]) for r in rows]
    check(sid, "sunucu boş/boşluk ad, 40'tan uzun ad ve geçersiz renk kabul etmemeli (istemci 1..40 ve palet)",
          len(rows) == 0, f"kabul edilen={accepted}")

    c3 = Client("f-case")
    c3.ensure_own_profile()
    c3.setup_categories([{"name": "Matematik", "color_hex": "#EF4444", "icon_name": "book"},
                         {"name": "matematik", "color_hex": "#3B82F6", "icon_name": "book"},
                         {"name": "Matematik ", "color_hex": "#10B981", "icon_name": "book"}])
    rows = [r["name"] for r in c3.categories()]
    check(sid, "büyük/küçük harf ve sondaki boşluk farkı aynı kategori sayılmalı",
          len(rows) == 1, f"aktif={rows}")

    c4 = Client("f-null")
    c4.ensure_own_profile()
    r = c4.setup_categories([
        {"name": "Geçerli", "color_hex": "#EF4444", "icon_name": "book"},
        {"name": None, "color_hex": "#EF4444", "icon_name": "book"}])
    rows = c4.categories()
    check(sid, "Adı null olan satır atlanır; geçerli kategori ve skipped_invalid=1 döner",
          r["skipped_invalid"] == 1 and [x["name"] for x in rows] == ["Geçerli"], str(r))
    r = c4.rpc("setup_onboarding_categories", {"p_categories": {"name": "x"}})
    check(sid, "Dizi olmayan yük sıfır sonuç döndürür ve veri değiştirmez",
          all(v == 0 for v in r.values()) and c4.categories() == rows, str(r))


# ---------------------------------------------------------------------------
# G. Profil PATCH: kolon yetkileri ve CHECK'ler
# ---------------------------------------------------------------------------
def scenario_profile_update():
    sid = "G"
    c = Client("g-profile")
    other = Client("g-other")
    for col, val in (("coins", 999), ("is_premium", True), ("league_tier", 5), ("lifetime_points", 1),
                     ("avatar_id", "avatar_1_gamer"), ("friend_code", "AAAAAA")):
        e = expect_api_error(lambda: c.patch_profile({col: val}))
        check(sid, f"istemci '{col}' kolonunu yazamaz (42501)", e is not None and e.body.get("code") == "42501",
              str(err_body(e))[:120])
    for col, val in (("user_segment", "yks"), ("birth_year", 2008), ("daily_goal_minutes", 120),
                     ("show_in_social_feed", False), ("onboarding_completed_at", "2026-10-05T10:00:00Z"),
                     ("timezone", "Europe/Istanbul"), ("name", "Yeni Ad")):
        try:
            rows = c.patch_profile({col: val})
            ok = rows == [{"id": c.uid}]
        except api.ApiError as e:
            ok = False
            print("  hata:", err_body(e))
        check(sid, f"istemci '{col}' kolonunu yazabilir ve select=id satırı döner", ok)
    for upd, label in ((({"user_segment": "other"}), "segment 'other'"),
                       (({"birth_year": 1899}), "doğum yılı 1899"),
                       (({"daily_goal_minutes": 4}), "hedef 4 dk"),
                       (({"daily_goal_minutes": 1441}), "hedef 1441 dk")):
        e = expect_api_error(lambda: c.patch_profile(upd))
        check(sid, f"{label} CHECK ile reddedilir → istemci invalidInput",
              e is not None and e.body.get("code") == "23514" and classify(e) == "invalidInput", str(err_body(e))[:100])
    rows = c.patch_profile({"user_segment": "work"}, uid=other.uid)
    check(sid, "başkasının profiline PATCH 0 satır (RLS) → istemci notFound", rows == [], str(rows))

    # Yaş sınırı yalnızca istemcide mi?
    year = dt.date.today().year
    c2 = Client("g-age")
    try:
        c2.complete_onboarding(year - 5, "lgs", 60, cm.category_payload(["Matematik"]), True)
        accepted = True
    except api.ApiError:
        accepted = False
    check(sid, "13 yaş altı doğum yılıyla onboarding sunucuda tamamlanamamalı (Şartlar: en az 13)",
          not accepted, f"birth_year={year - 5} kabul edildi; onboarding_completed_at={c2.profile()['onboarding_completed_at']}")

    # show_in_social_feed verilmezse (taslaktan dönüşte olabilir) varsayılan TRUE kalır.
    c3 = Client("g-noshow")
    c3.complete_onboarding(2000, "work", 60, cm.category_payload(["Okuma"]), None)
    check(sid, "Görünürlük gönderilmezse sunucu FALSE bırakır; açık seçim olmadan görünmez",
          c3.profile()["show_in_social_feed"] is False, "bilgi: istemci taslak bulgusuyla birlikte değerlendir")


# ---------------------------------------------------------------------------
# H. Kabuğa geçiş: kategoriler kabukta, varsayılan tohumlama tetiklenmez
# ---------------------------------------------------------------------------
def scenario_shell():
    sid = "H"
    c = Client("h-shell")
    chosen = ["Derin Çalışma", "Okuma"]
    c.complete_onboarding(1990, "work", 120, cm.category_payload(chosen), True)
    p = c.profile()
    check(sid, "onboarding sonrası profil: onboarding_completed_at dolu, segment work, hedef 120",
          p["onboarding_completed_at"] and p["user_segment"] == "work" and p["daily_goal_minutes"] == 120)
    # loadShellCategories: aktif liste boş değilse tohumlama yok.
    act = c.categories()
    check(sid, "kabuk aktif kategorileri okur (yalnızca seçilenler, varsayılan 5 ders eklenmez)",
          [r["name"] for r in act] == chosen, str([r["name"] for r in act]))
    # Seçilen kategoriyle seans sunucuda kabul edilir (complete_study_session kategori sahipliği).
    started = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=26)).isoformat()
    import uuid as _uuid
    res = c.rpc("complete_study_session", {
        "p_client_uuid": str(_uuid.uuid4()), "p_category_id": act[0]["id"], "p_duration_minutes": 25,
        "p_was_paused": False, "p_is_verified": 1500, "p_started_at": started})
    check(sid, "onboarding kategorisiyle ilk seans kaydedilir", isinstance(res, dict) and "error" not in res
          and res.get("total_points", 0) > 0, str(res))

    # Hiç kategorisi olmayan hesap: ensureServerCategories / kuyruk varsayılanları (TR 5 ders, segmentten bağımsız).
    c2 = Client("h-empty")
    c2.complete_onboarding(1990, "work", 60, [], True)  # kategori listesi boş (istemci bunu göndermez)
    c2.setup_categories(cm.category_payload(cm.recommended_for("work")[:5]))  # defaultCategorySeed
    names = [r["name"] for r in c2.categories()]
    check(sid, "kategorisiz hesabın (ensureServerCategories / kuyruk) varsayılanları segmenti dikkate almalı",
          names == cm.recommended_for("work")[:5], f"segment=work, tohumlanan={names}")


# ---------------------------------------------------------------------------
# I. Yetki, oturum ve eşzamanlılık
# ---------------------------------------------------------------------------
def scenario_auth_and_race():
    sid = "I"
    e = expect_api_error(lambda: api.rpc("setup_onboarding_categories", {"p_categories": []}))
    check(sid, "anon setup_onboarding_categories çağıramaz", e is not None and e.status in (401, 403),
          f"{e.status if e else None} {err_body(e)}")
    c = Client("i-jwt")
    bad = c.token[:-4] + ("AAAA" if not c.token.endswith("AAAA") else "BBBB")
    e = expect_api_error(lambda: api.rpc("setup_onboarding_categories", {"p_categories": []}, token=bad))
    code = e.body.get("code") if e and isinstance(e.body, dict) else None
    check(sid, "bozuk JWT → PostgREST kodu istemcinin notSignedIn saydığı kod olmalı",
          e is not None and classify(e) == "notSignedIn", f"HTTP {e.status if e else None} code={code} → {classify(e) if e else None}")

    # Eşzamanlı iki kurulum (ör. iki cihaz / çift dokunma): limit aşılmamalı.
    c2 = Client("i-race")
    c2.ensure_own_profile()
    a = json.dumps(cm.category_payload([f"A{i}" for i in range(8)])).replace("'", "''")
    b = json.dumps(cm.category_payload([f"B{i}" for i in range(8)])).replace("'", "''")
    claims = f"select set_config('request.jwt.claims', json_build_object('sub','{c2.uid}','role','authenticated')::text, true) is not null;"
    out = {}

    def run_a():
        out["a"] = psql(f"BEGIN;\n{claims}\nSET LOCAL ROLE authenticated;\n"
                        f"select public.setup_onboarding_categories('{a}'::jsonb);\nselect pg_sleep(3);\nCOMMIT;\n")

    t = threading.Thread(target=run_a)
    t.start()
    time.sleep(1)
    out["b"] = psql(f"BEGIN;\n{claims}\nSET LOCAL ROLE authenticated;\n"
                    f"select public.setup_onboarding_categories('{b}'::jsonb);\nCOMMIT;\n")
    t.join()
    n = len(c2.categories())
    check(sid, "eşzamanlı iki setup_onboarding_categories ücretsiz limiti (8) aşmamalı", n <= cm.FREE_LIMIT,
          f"aktif kategori={n}; a_rc={out['a'][0]} b_rc={out['b'][0]}")


def main():
    for fn in (scenario_signup, scenario_segments, scenario_english, scenario_idempotency, scenario_limits,
               scenario_custom_and_validation, scenario_profile_update, scenario_shell, scenario_auth_and_race):
        print(f"\n=== {fn.__name__} ===", flush=True)
        try:
            fn()
        except Exception as e:  # senaryo çökerse diğerleri yine çalışsın
            check(fn.__name__, "senaryo istisnasız bitti", False, f"{type(e).__name__}: {err_body(e)}")
    fails = [r for r in RESULTS if not r[2]]
    print(f"\nÖZET: {len(RESULTS)} denetim, {len(RESULTS) - len(fails)} OK, {len(fails)} FAIL (run={RUN})")
    for sid, name, _, detail in fails:
        print(f"  FAIL [{sid}] {name} -- {detail}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
