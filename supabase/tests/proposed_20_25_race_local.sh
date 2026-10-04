#!/usr/bin/env bash
# Eşzamanlılık bulguları (t1-01, t2-07, t4-F1, t4-F7): iki ayrı bağlantıdan
# aynı anda çağrı. YALNIZCA YEREL bir KOPYA veritabanında çalıştırın (ana yerel
# kopya 'postgres' reddedilir): her senaryo sentetik kullanıcılar açıp COMMIT
# eder, sonda kullanıcılarını siler (auth.users → cascade).
#
#   canlı hâl : CHAIN_DB=pomosprint_base UNTIL=0 KEEP_DB=1 tool/local_supabase/proposed_chain_check.sh
#               supabase/tests/proposed_20_25_race_local.sh postgresql://postgres:postgres@127.0.0.1:54322/pomosprint_base
#   zincir    : CHAIN_DB=pomosprint_chain UNTIL=14 KEEP_DB=1 tool/local_supabase/proposed_chain_check.sh
#   + 20–25   : CHAIN_DB=pomosprint_chain NO_DOWN=1 KEEP_DB=1 tool/local_supabase/proposed_chain_check.sh
#               supabase/tests/proposed_20_25_race_local.sh postgresql://postgres:postgres@127.0.0.1:54322/pomosprint_chain
#   Sonra: KEEP_DB olmadan bir kez çalıştırmak ya da DROP DATABASE ile kopyaları silin.
#
# Her senaryo 'BUG' ya da 'düzgün' yazar. Çıkış kodu: düzgün olmayan senaryo sayısı.
set -uo pipefail

DB_URL="${1:-postgresql://postgres:postgres@127.0.0.1:54322/pomosprint_chain}"
case "$DB_URL" in
  *@127.0.0.1:*|*@localhost:*) ;;
  *) echo "HATA: yalnızca yerel veritabanı." >&2; exit 2 ;;
esac
case "$DB_URL" in
  */postgres|*/postgres\?*) echo "HATA: ana yerel kopya ('postgres') değil, bir KOPYA veritabanı verin." >&2; exit 2 ;;
esac

PSQL=(psql "$DB_URL" -X -q -At -v ON_ERROR_STOP=1)
TAG="race$$"
BAD=0
TMP="$(mktemp -d)"
cleanup() {
  "${PSQL[@]}" -c "DELETE FROM auth.users WHERE email LIKE '$TAG-%@example.invalid'" >/dev/null 2>&1
  rm -rf "$TMP"
}
trap cleanup EXIT

new_user() {  # $1 = etiket → uuid
  "${PSQL[@]}" -c "INSERT INTO auth.users (id, email, raw_user_meta_data, raw_app_meta_data, aud, role)
                   VALUES (gen_random_uuid(), '$TAG-$1@example.invalid', '{\"name\":\"Yaris $1\"}',
                           '{\"provider\":\"email\"}', 'authenticated', 'authenticated') RETURNING id"
}
as_user() {  # $1 = uuid → oturum başı SQL
  echo "SELECT set_config('request.jwt.claims', json_build_object('sub','$1','role','authenticated')::text, true); SET LOCAL ROLE authenticated;"
}
report() {  # $1 = id, $2 = düzgün mü (1/0), $3 = ayrıntı
  if [[ "$2" == 1 ]]; then echo "düzgün | $1 | $3"; else echo "BUG    | $1 | $3"; BAD=$((BAD + 1)); fi
}
# A: işlemi açar, $2'yi çalıştırır, 2 sn bekler, COMMIT. B: 0,5 sn sonra $3, COMMIT.
race() {
  "${PSQL[@]}" > "$TMP/a.out" 2>&1 <<SQL &
BEGIN; $1 $2; SELECT pg_sleep(2); COMMIT;
SQL
  local pid=$!
  sleep 0.5
  "${PSQL[@]}" > "$TMP/b.out" 2>&1 <<SQL
BEGIN; $1 $3; COMMIT;
SQL
  wait "$pid"
}

# ----------------------------------------------------------------- t1-01
U=$(new_user t101)
CAT=$("${PSQL[@]}" -c "INSERT INTO public.categories (user_id, name, color_hex, icon_name) VALUES ('$U', 'Yaris Ders', '#123456', 'book') RETURNING id")
race "$(as_user "$U")" \
  "SELECT 'A ' || public.complete_study_session(gen_random_uuid(), '$CAT', 25, false, 1500, now() - interval '60 minutes')::text" \
  "SELECT 'B ' || public.complete_study_session(gen_random_uuid(), '$CAT', 25, false, 1500, now() - interval '50 minutes')::text"
N=$("${PSQL[@]}" -c "SELECT count(*) FROM public.study_sessions WHERE user_id = '$U'")
P=$("${PSQL[@]}" -c "SELECT lifetime_points || ' puan, ' || coins || ' kum, ' || total_minutes || ' dk' FROM public.profiles WHERE id = '$U'")
report "t1-01 iki cihazdan eşzamanlı çakışan seans" "$([[ "$N" == 1 ]] && grep -q overlap "$TMP/b.out" && echo 1 || echo 0)" \
  "$N seans kaydı; $P; B: $(tr '\n' ' ' < "$TMP/b.out" | cut -c1-140)"

# Aynı client_uuid iki bağlantıdan: ikincisi 23505 değil duplicate dönmeli
U=$(new_user t101b)
CAT=$("${PSQL[@]}" -c "INSERT INTO public.categories (user_id, name, color_hex, icon_name) VALUES ('$U', 'Yaris Ders', '#123456', 'book') RETURNING id")
CU=$("${PSQL[@]}" -c "SELECT gen_random_uuid()")
race "$(as_user "$U")" \
  "SELECT 'A ' || public.complete_study_session('$CU', '$CAT', 25, false, 1500, now() - interval '60 minutes')::text" \
  "SELECT 'B ' || public.complete_study_session('$CU', '$CAT', 25, false, 1500, now() - interval '60 minutes')::text"
report "t1-01 aynı client_uuid eşzamanlı (R2)" "$(grep -q '"duplicate": true' "$TMP/b.out" && echo 1 || echo 0)" \
  "B: $(tr '\n' ' ' < "$TMP/b.out" | cut -c1-140)"

# ----------------------------------------------------------------- t2-07
V=$(new_user t207)
"${PSQL[@]}" -c "UPDATE public.profiles SET onboarding_completed_at = now() WHERE id = '$V'" >/dev/null
A_JSON='[{"name":"A0","color_hex":"#111111","icon_name":"book"},{"name":"A1","color_hex":"#111111","icon_name":"book"},{"name":"A2","color_hex":"#111111","icon_name":"book"},{"name":"A3","color_hex":"#111111","icon_name":"book"},{"name":"A4","color_hex":"#111111","icon_name":"book"},{"name":"A5","color_hex":"#111111","icon_name":"book"},{"name":"A6","color_hex":"#111111","icon_name":"book"},{"name":"A7","color_hex":"#111111","icon_name":"book"}]'
B_JSON="${A_JSON//\"A/\"B}"
race "$(as_user "$V")" \
  "SELECT public.setup_onboarding_categories('$A_JSON')" \
  "SELECT public.setup_onboarding_categories('$B_JSON')"
N=$("${PSQL[@]}" -c "SELECT count(*) FROM public.categories WHERE user_id = '$V' AND NOT is_archived")
report "t2-07 eşzamanlı iki kategori kurulumu (ücretsiz limit 8)" "$([[ "$N" -le 8 ]] && echo 1 || echo 0)" "aktif kategori: $N"

W=$(new_user t207b)
"${PSQL[@]}" -c "INSERT INTO public.categories (user_id, name, color_hex, icon_name, sort_order)
                 SELECT '$W', 'W' || g, '#111111', 'book', g FROM generate_series(1, 7) g" >/dev/null
race "$(as_user "$W")" \
  "SELECT public.create_category('X1', '#222222', 'book')" \
  "SELECT public.create_category('X2', '#222222', 'book')"
N=$("${PSQL[@]}" -c "SELECT count(*) FROM public.categories WHERE user_id = '$W' AND NOT is_archived")
report "t2-07 eşzamanlı iki create_category (7 varken)" "$([[ "$N" -le 8 ]] && echo 1 || echo 0)" \
  "aktif kategori: $N; B: $(tr '\n' ' ' < "$TMP/b.out" | cut -c1-100)"

# ----------------------------------------------------------------- t4-F1
P1=$(new_user f1)
"${PSQL[@]}" -c "UPDATE public.profiles SET coins = 300 WHERE id = '$P1'" >/dev/null
race "$(as_user "$P1")" \
  "SELECT 'A ' || public.purchase_avatar('avatar_1_gamer')" \
  "SELECT 'B ' || public.purchase_avatar('avatar_4_bowtie')"
C=$("${PSQL[@]}" -c "SELECT coins FROM public.profiles WHERE id = '$P1'")
N=$("${PSQL[@]}" -c "SELECT count(*) FROM public.avatar_unlocks WHERE user_id = '$P1' AND unlock_type = 'coins'")
report "t4-F1 300 kumla eşzamanlı iki 200'lük avatar" "$([[ "$N" == 1 && "$C" == 100 ]] && echo 1 || echo 0)" \
  "alınan: $N, kalan kum: $C; B: $(tr '\n' ' ' < "$TMP/b.out" | cut -c1-120)"

P2=$(new_user f1b)
CAT=$("${PSQL[@]}" -c "INSERT INTO public.categories (user_id, name, color_hex, icon_name) VALUES ('$P2', 'Yaris Ders', '#123456', 'book') RETURNING id")
"${PSQL[@]}" -c "UPDATE public.profiles SET coins = 300 WHERE id = '$P2'" >/dev/null
race "$(as_user "$P2")" \
  "SELECT 'A ' || (public.complete_study_session(gen_random_uuid(), '$CAT', 25, false, 1500, now() - interval '30 minutes')->>'coins_earned')" \
  "SELECT 'B ' || public.purchase_avatar('avatar_1_gamer')"
C=$("${PSQL[@]}" -c "SELECT coins FROM public.profiles WHERE id = '$P2'")
report "t4-F1 seans (+20 kum) sürerken satın alma: +20 ezilmemeli (300+20-200)" "$([[ "$C" == 120 ]] && echo 1 || echo 0)" "kalan kum: $C"

# ----------------------------------------------------------------- t4-F7
if [[ "$("${PSQL[@]}" -c "SELECT count(*) FROM public.leagues WHERE is_active AND tier = 3")" != 0 ]]; then
  echo "atlandı | t4-F7 | kopyada aktif tier-3 odası var"
else
  A=$(new_user f7a); B=$(new_user f7b)
  "${PSQL[@]}" -c "UPDATE public.profiles SET league_tier = 3 WHERE id IN ('$A', '$B')" >/dev/null
  CA=$("${PSQL[@]}" -c "INSERT INTO public.categories (user_id, name, color_hex, icon_name) VALUES ('$A', 'Yaris Ders', '#123456', 'book') RETURNING id")
  CB=$("${PSQL[@]}" -c "INSERT INTO public.categories (user_id, name, color_hex, icon_name) VALUES ('$B', 'Yaris Ders', '#123456', 'book') RETURNING id")
  "${PSQL[@]}" > "$TMP/a.out" 2>&1 <<SQL &
BEGIN; $(as_user "$A") SELECT public.complete_study_session(gen_random_uuid(), '$CA', 25, false, 1500, now() - interval '30 minutes'); SELECT pg_sleep(2); COMMIT;
SQL
  pid=$!
  sleep 0.5
  "${PSQL[@]}" > "$TMP/b.out" 2>&1 <<SQL
BEGIN; $(as_user "$B") SELECT public.complete_study_session(gen_random_uuid(), '$CB', 25, false, 1500, now() - interval '30 minutes'); COMMIT;
SQL
  wait "$pid"
  R=$("${PSQL[@]}" -c "SELECT count(DISTINCT league_id) FROM public.league_memberships WHERE user_id IN ('$A', '$B')")
  report "t4-F7 aynı kademede eşzamanlı ilk seanslar aynı odaya" "$([[ "$R" == 1 ]] && echo 1 || echo 0)" "farklı oda sayısı: $R"
  "${PSQL[@]}" -c "DELETE FROM public.leagues l WHERE l.tier = 3 AND NOT EXISTS (SELECT 1 FROM public.league_memberships m WHERE m.league_id = l.id AND m.user_id NOT IN ('$A', '$B'))" >/dev/null
fi

echo "düzgün olmayan: $BAD"
exit "$BAD"
