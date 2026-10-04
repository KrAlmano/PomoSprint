#!/usr/bin/env python3
"""t3 — seans/lig/aktivite gerektiren görünürlük senaryoları (GERİ ALINAN transaction).

    python3 tool/local_supabase/e2e/t3_visibility/t3_rollback_test.py

Önce t3_rest_test.py çalışmış olmalı (A↔B ve A↔D arkadaş, C→A bekleyen istek).
Tüm yazmalar (seans, lig üyeliği, aktivite, görünürlük) tek bir BEGIN … ROLLBACK
içinde, kullanıcı taklidiyle (request.jwt.claims + SET LOCAL ROLE) yapılır;
paylaşılan veritabanında iz kalmaz.
"""

import json

from t3_common import check, ensure_users, info, psql, summary


def as_user(uid):
    claims = json.dumps({"sub": uid, "role": "authenticated"})
    return (f"reset role;\nselect set_config('request.jwt.claims', '{claims}', true) \\g /dev/null\n"
            "set local role authenticated;\n")


def as_anon():
    return ("reset role;\nselect set_config('request.jwt.claims', '{\"role\":\"anon\"}', true) \\g /dev/null\n"
            "set local role anon;\n")


def expect_error(tag, stmt):
    return (f"savepoint sp;\n{stmt};\n\\echo T3|{tag}|:SQLSTATE|:LAST_ERROR_MESSAGE\nrollback to savepoint sp;\n")


def main():
    U = ensure_users()
    A, B, C, D, E = (U[k] for k in "ABCDE")
    out, _ = psql(f"""
      select (select status from friendships where user_id='{A['uid']}' and friend_id='{B['uid']}')
          || ',' || (select status from friendships where user_id='{A['uid']}' and friend_id='{D['uid']}')
          || ',' || (select status from friendships where user_id='{C['uid']}' and friend_id='{A['uid']}');""")
    if out.strip() != "accepted,accepted,pending":
        raise SystemExit(f"Önce t3_rest_test.py çalıştır (arkadaşlık durumu: {out.strip()!r})")

    s = "begin;\n"
    # E'yi ayrı bir kademeye (2) al: ilk puanlı seansta yeni bir tier-2 lig odası açılır.
    s += f"update public.profiles set league_tier = 2 where id = '{E['uid']}';\n"
    # E henüz odasızken
    s += as_user(E["uid"])
    s += "select 'T3|E0|' || jsonb_agg(r)::text from public.get_my_league_ranking() r;\n"
    for k in "ABCDE":
        u = U[k]
        s += as_user(u["uid"])
        s += (f"select 'T3|S.{k}|' || public.complete_study_session(gen_random_uuid(), "
              f"public.create_category('T3 Txn {k}', '#123456', 'book'), 25, false, 1500, now() - interval '25 minutes')::text;\n")
    # B görünürlüğü kapatır (seans ve aktivite kaydı yazıldıktan sonra)
    s += as_user(B["uid"])
    s += f"update public.profiles set show_in_social_feed = false where id = '{B['uid']}';\n"

    names = "('Ayse Tetik','Bora Uslu','Cem','Deniz Kaya Er','Ece Su','Ayse T.','Bora U.','Deniz K.','Ece S.')"
    # Herkese açık aylık / tüm zamanlar
    s += as_anon()
    s += f"select 'T3|M.anon|' || coalesce(jsonb_agg(r order by r.name)::text,'[]') from public.get_public_monthly_leaderboard(100) r where r.name in {names};\n"
    s += f"select 'T3|AT.anon|' || coalesce(jsonb_agg(r order by r.name)::text,'[]') from public.get_public_alltime_leaderboard(100) r where r.name in {names};\n"
    s += "select 'T3|M.anon.null|' || count(*) from public.get_public_monthly_leaderboard(null) r;\n"
    s += as_user(A["uid"])
    s += f"select 'T3|M.A|' || coalesce(jsonb_agg(r order by r.name)::text,'[]') from public.get_public_monthly_leaderboard(100) r where r.name in {names} or r.is_me;\n"
    s += "select 'T3|M.A.me|' || count(*) filter (where is_me) from public.get_public_monthly_leaderboard(100);\n"

    # Lig
    for k in "ABE":
        s += as_user(U[k]["uid"])
        s += f"select 'T3|LG.{k}|' || jsonb_agg(json_build_object('name', r.name, 'is_me', r.is_me, 'tier', r.tier, 'pts', r.weekly_points, 'n', r.member_count))::text from public.get_my_league_ranking() r;\n"
    s += as_user(A["uid"])
    s += "select 'T3|LM.A|' || jsonb_agg(json_build_object('user_id', user_id, 'league_id', league_id, 'weekly_points', weekly_points))::text from public.league_memberships;\n"
    s += f"select 'T3|LM.A.E|' || count(*) from public.league_memberships where user_id = '{E['uid']}';\n"
    s += "select 'T3|LG.A.count|' || count(*) from public.leagues;\n"
    s += expect_error("LR.other", f"select * from public.get_league_ranking('{B['uid']}')")
    s += expect_error("EUL.other", f"select public.ensure_user_in_league('{B['uid']}', 1000)")

    # Başkasının seansı / kategorisi
    s += f"select 'T3|SS.A.B|' || count(*) from public.study_sessions where user_id = '{B['uid']}';\n"
    s += f"select 'T3|SS.A.all|' || count(*) || ',' || count(*) filter (where user_id <> '{A['uid']}') from public.study_sessions;\n"
    s += (f"select 'T3|CAT.B.id|' || id from public.categories where name = 'T3 Txn B' \\g /dev/null\n")
    s += "reset role;\n"
    s += f"select id as b_cat from public.categories where user_id = '{B['uid']}' and name = 'T3 Txn B' \\gset\n"
    s += as_user(A["uid"])
    s += expect_error("CSS.Bcat", "select public.complete_study_session(gen_random_uuid(), :'b_cat'::uuid, 25, false, 1500, now() - interval '55 minutes')")

    # Aktivite akışı: A, B'nin arkadaşı; B görünürlüğü kapattı
    s += f"select 'T3|AF.A.B|' || coalesce(jsonb_agg(json_build_object('type', activity_type, 'payload', payload))::text, '[]') from public.activity_feed where user_id = '{B['uid']}';\n"
    s += f"select 'T3|GFF.A|' || coalesce((select jsonb_agg(x->>'name')::text from jsonb_array_elements(public.get_friends_feed(50)) x), '[]');\n"
    s += as_user(C["uid"])
    s += f"select 'T3|AF.C.B|' || count(*) from public.activity_feed where user_id = '{B['uid']}';\n"
    s += f"select 'T3|AF.C.A|' || count(*) from public.activity_feed where user_id = '{A['uid']}';\n"
    s += as_user(A["uid"])
    s += expect_error("GFF.neg", "select public.get_friends_feed(-1)")

    # Ad metadata'sı olmadan açılan hesap (Apple signInWithIdToken: id_token'da ad yok)
    s += "reset role;\n"
    s += ("insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, raw_app_meta_data, created_at, updated_at) "
          "values ('00000000-0000-4000-8000-0000000000f3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', "
          "'erdal.yilmaz.1987@icloud.com', '{}'::jsonb, '{\"provider\":\"apple\"}'::jsonb, now(), now());\n")
    s += "select 'T3|EM.name|' || name from public.profiles where id = '00000000-0000-4000-8000-0000000000f3';\n"
    s += as_user("00000000-0000-4000-8000-0000000000f3")
    s += ("select public.complete_study_session(gen_random_uuid(), public.create_category('T3 Em', '#123456', 'book'), 25, false, 1500, "
          "now() - interval '25 minutes') \\g /dev/null\n")
    s += as_anon()
    s += "select 'T3|EM.anon|' || coalesce(jsonb_agg(r.name)::text, '[]') from public.get_public_monthly_leaderboard(100) r where r.name ilike '%erdal%';\n"
    s += "reset role;\nrollback;\n"

    stdout, stderr = psql(s, on_error_stop=False)
    res = {}
    for line in stdout.splitlines():
        if line.startswith("T3|"):
            _, tag, rest = line.split("|", 2)
            res[tag] = rest
    if stderr.strip():
        print("psql stderr (beklenen hatalar dahil):\n" + "\n".join("   " + x for x in stderr.strip().splitlines()))

    def j(tag):
        try:
            return json.loads(res.get(tag) or "null")
        except ValueError:
            return res.get(tag)

    e0 = j("E0")
    check("LG0", e0 and len(e0) == 1 and e0[0]["is_me"] is True and e0[0]["member_count"] == 1 and e0[0]["weekly_points"] == 0,
          "Odası olmayan kullanıcıya tek satır (is_me, 0 puan, member_count 1)", res.get("E0"))
    for k in "ABCDE":
        r = j(f"S.{k}")
        check(f"S.{k}", isinstance(r, dict) and r.get("total_points") == 5 and r.get("duplicate") is False,
              f"{k} seansı tamamlar (5 puan)", res.get(f"S.{k}"))

    m_anon = j("M.anon")
    anon_names = sorted(x["name"] for x in m_anon)
    check("LB1", anon_names == ["Ayse T.", "Cem", "Deniz K.", "Ece S."],
          "Aylık (anon): adlar maskeli ('Ayse T.', 'Deniz K.'), tek kelime 'Cem' aynen; görünürlüğü kapalı B yok", anon_names)
    check("LB2", all(x["is_me"] is False and "id" not in x for x in m_anon), "Aylık (anon): is_me false, id yok", res.get("M.anon"))
    at_anon = sorted(x["name"] for x in j("AT.anon"))
    check("LB3", at_anon == ["Ayse T.", "Cem", "Deniz K.", "Ece S."], "Tüm zamanlar (anon): maskeli, B yok", at_anon)
    check("LB4", res.get("M.anon.null") == "0", "p_limit null → 0 satır (istemci her zaman p_limit gönderiyor)", res.get("M.anon.null"))
    m_a = j("M.A")
    a_names = sorted(x["name"] for x in m_a)
    me_rows = [x["name"] for x in m_a if x["is_me"]]
    check("LB5", a_names == ["Ayse Tetik", "Cem", "Deniz Kaya Er", "Ece Su"] and me_rows == ["Ayse Tetik"],
          "Aylık (A oturumlu): tam adlar, yalnızca A is_me, B yok", f"{a_names} me={me_rows}")
    check("LB6", res.get("M.A.me") == "1", "Aylık listede tam bir is_me satırı", res.get("M.A.me"))

    lga, lgb, lge = j("LG.A"), j("LG.B"), j("LG.E")
    na = {x["name"] for x in lga}
    check("LG1", {"Ayse Tetik", "Bora Uslu", "Cem", "Deniz Kaya Er"} <= na and "Ece Su" not in na
          and [x["name"] for x in lga if x["is_me"]] == ["Ayse Tetik"] and lga[0]["n"] == len(lga),
          "A'nın lig odası: A,B,C,D aynı odada; farklı kademedeki E yok; yalnızca A is_me; member_count = satır sayısı",
          json.dumps(lga, ensure_ascii=False))
    check("LG2", "Bora Uslu" in {x["name"] for x in lgb} and [x["name"] for x in lgb if x["is_me"]] == ["Bora Uslu"],
          "Görünürlüğü kapalı B lig odasında görünmeye devam eder (arayüz metni: 'Lig grubun … her durumda görür')",
          json.dumps(lgb, ensure_ascii=False))
    check("LG3", [x["name"] for x in lge] == ["Ece Su"] and lge[0]["tier"] == 2 and lge[0]["is_me"],
          "E (kademe 2) yalnızca kendi odasını görür; A-D'yi görmez", json.dumps(lge, ensure_ascii=False))
    lm = j("LM.A")
    other_uids = {x["user_id"] for x in lm} - {A["uid"]}
    league_ids = {x["league_id"] for x in lm}
    check("LG4", res.get("LM.A.E") == "0" and len(league_ids) == 1, "A, başka odadaki E'nin üyeliğini league_memberships'ten okuyamaz",
          f"E={res.get('LM.A.E')} odalar={league_ids}")
    if B["uid"] in other_uids:
        info("LG5", f"A, league_memberships'i doğrudan okuyarak oda arkadaşlarının user_id (UUID), weekly_points ve joined_at "
             f"değerlerini görüyor ({len(other_uids)} başka kullanıcı; görünürlüğü kapalı B dahil). RPC bilerek kimlik döndürmüyor.",
             f"örnek={sorted(other_uids)[:3]}")
    check("LG6", res.get("LR.other", "").startswith("P0001|not authorized"), "get_league_ranking(başkasının id'si) reddedilir", res.get("LR.other"))
    check("LG7", res.get("EUL.other", "").startswith("42501"), "ensure_user_in_league authenticated'a kapalı", res.get("EUL.other"))

    check("SS1", res.get("SS.A.B") == "0", "A, B'nin study_sessions satırını göremez", res.get("SS.A.B"))
    ss_all = (res.get("SS.A.all") or "").split(",")
    check("SS2", len(ss_all) == 2 and ss_all[1] == "0", "A filtresiz SELECT'te yalnızca kendi seanslarını görür", res.get("SS.A.all"))
    check("SS3", "category does not belong" in (res.get("CSS.Bcat") or ""), "A, B'nin kategori id'siyle seans kaydedemez", res.get("CSS.Bcat"))

    af = j("AF.A.B")
    gff = j("GFF.A")
    if af and any(x["type"] == "daily_summary" for x in af) and "Bora Uslu" not in (gff or []):
        info("AF1", "Görünürlüğü kapatan B'nin activity_feed satırları (günlük dakika, seans sayısı, en çok çalışılan kategori adı) "
             "arkadaşı A tarafından doğrudan REST/SELECT ile okunabiliyor; get_friends_feed RPC'si ise B'yi gizliyor",
             json.dumps(af, ensure_ascii=False))
    else:
        check("AF1", True, "activity_feed görünürlük tercihine uyuyor", res.get("AF.A.B"))
    check("AF2", res.get("AF.C.B") == "0" and res.get("AF.C.A") == "0", "Arkadaş olmayan C, A/B'nin aktivitesini okuyamaz (bekleyen istek yetmez)",
          f"{res.get('AF.C.B')} {res.get('AF.C.A')}")
    check("AF3", (res.get("GFF.neg") or "").startswith("2201W"), "get_friends_feed(-1) LIMIT hatası (kullanılmıyor)", res.get("GFF.neg"))
    em_name, em_anon = res.get("EM.name"), j("EM.anon")
    if em_name == "erdal.yilmaz.1987" and em_anon == ["erdal.yilmaz.1987"]:
        info("EM1", "Ad metadata'sı olmayan hesapta (Apple id_token) handle_new_user adı e-postanın yerel kısmı yapıyor; "
             "tek parça olduğu için mask_public_name maskelemiyor → anon aylık listede (landing) aynen görünüyor",
             f"profiles.name={em_name} anon={em_anon}")
    else:
        check("EM1", True, "E-posta yerel kısmı herkese açık listeye sızmıyor", f"{em_name} {em_anon}")
    return summary()


if __name__ == "__main__":
    raise SystemExit(main())
