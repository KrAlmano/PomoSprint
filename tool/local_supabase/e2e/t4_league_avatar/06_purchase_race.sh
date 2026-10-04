#!/usr/bin/env bash
# t4-06: purchase_avatar eşzamanlı çift satın alma (kayıp güncelleme).
# Yalnızca YEREL kopya. Kendi t4- hesabını açar (yalnızca kendi profiline kum
# yazar), iki ayrı bağlantıdan aynı anda iki farklı 200'lük avatar alır, sonra
# hesabı siler. Lig/paylaşılan veriye dokunmaz.
#   tool/local_supabase/e2e/t4_league_avatar/06_purchase_race.sh
set -euo pipefail
PG=postgresql://postgres:postgres@127.0.0.1:54322/postgres
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/../.."

UID_=$(python3 - <<'EOF'
import uuid, local_api as api
email = f"t4-race-{uuid.uuid4().hex[:8]}@pomosprint.local"
api.sign_up(email, "t4 Yarış")
print(api.sign_in(email)["user"]["id"])
EOF
)
trap 'psql "$PG" -qAt -c "delete from auth.users where id = '"'"'$UID_'"'"' and email like '"'"'t4-%'"'"'" >/dev/null' EXIT

psql "$PG" -qAt -c "update public.profiles set coins = 300 where id = '$UID_'" >/dev/null
echo "Başlangıç: 300 kum; avatar_1_gamer (200) ve avatar_4_bowtie (200) aynı anda alınıyor."
echo "Doğru davranış: biri başarılı (100 kalır), diğeri 'Yetersiz bakiye'."

OUT_A=$(mktemp)
CLAIMS="select set_config('request.jwt.claims', json_build_object('sub','$UID_','role','authenticated')::text, true);"
# A: satın alır, satırı kilitli tutarak 3 sn bekler, commit
psql "$PG" -qAt >"$OUT_A" 2>&1 <<EOF &
begin; $CLAIMS set local role authenticated;
select 'A dönüş: ' || public.purchase_avatar('avatar_1_gamer');
select pg_sleep(3);
commit;
EOF
PID_A=$!
sleep 1
# B: A commit etmeden okur (300 görür), UPDATE A'nın kilidini bekler
psql "$PG" -qAt <<EOF 2>&1 | sed 's/^/  /'
begin; $CLAIMS set local role authenticated;
select 'B dönüş: ' || public.purchase_avatar('avatar_4_bowtie');
commit;
EOF
wait $PID_A
sed 's/^/  /' "$OUT_A" | grep -v '^  $' ; rm -f "$OUT_A"

echo "Sonuç:"
psql "$PG" -qAt -c "select '  kum=' || coins from public.profiles where id = '$UID_'"
psql "$PG" -qAt -c "select '  ' || avatar_id || ' ' || unlock_type || '/' || coins_spent from public.avatar_unlocks where user_id = '$UID_' and unlock_type = 'coins' order by avatar_id"
psql "$PG" -qAt -c "select case when count(*) = 2 then '  HATA: 300 kumla 400 kumluk iki avatar alındı (kayıp güncelleme)' else '  OK: yalnızca biri alındı' end from public.avatar_unlocks where user_id = '$UID_' and unlock_type = 'coins'"
