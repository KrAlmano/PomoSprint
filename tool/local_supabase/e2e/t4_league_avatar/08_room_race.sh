#!/usr/bin/env bash
# t4-08: ensure_user_in_league oda seçimi kilitsiz mi? İki FARKLI yeni
# kullanıcı aynı anda (aynı kademede, boş yer ararken) ilk seansını bitirir.
# Her iki bağlantı da kendi transaction'ında kullanıcı açar ve ROLLBACK eder;
# kalıcı hiçbir şey yazılmaz. Kademe 4 kullanılır (yerelde başka tier-4 oda
# yoksa sonuç deterministik).
#   tool/local_supabase/e2e/t4_league_avatar/08_room_race.sh
set -euo pipefail
PG=postgresql://postgres:postgres@127.0.0.1:54322/postgres
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
echo "Önceden aktif tier-4 oda sayısı: $(psql "$PG" -qAt -c "select count(*) from leagues where is_active and tier = 4")"

body() { # $1 etiket, $2 bekleme
cat <<EOF
\set ON_ERROR_STOP on
\o /dev/null
begin;
\i _helpers.sql
create temp table v as select pg_temp.t4_user('race$1', 4) u;
create temp table c as select pg_temp.t4_category((select u from v)) cat;
select pg_temp.t4_as((select u from v));
select clock_timestamp() t0 \gset
select public.complete_study_session(gen_random_uuid(), (select cat from c), 25, false, 0, now() - interval '26 minutes');
\o
select '$1: oda=' || pg_temp.t4_league_of((select u from v))
       || ' üye(görünen)=' || (select count(*) from league_memberships where league_id = pg_temp.t4_league_of((select u from v)))
       || ' bekleme=' || round(extract(epoch from clock_timestamp() - :'t0'::timestamptz)::numeric, 2) || 'sn';
select pg_sleep($2);
rollback;
EOF
}
OUT_A=$(mktemp)
body A 4 | psql "$PG" -qAt >"$OUT_A" 2>&1 &
PID_A=$!
sleep 1
body B 0 | psql "$PG" -qAt 2>&1 | grep -v '^$'
wait $PID_A
grep -v '^$' "$OUT_A"; rm -f "$OUT_A"
echo "Beklenen (kilitli): B, A commit/rollback edene kadar bekler ve A'nın odasına girer."
echo "Gerçek: B beklemeden AYRI bir oda açıyorsa seçim kilitsizdir (aynı yarış 29 üyeli odada 31 üyeye yol açar)."
