#!/usr/bin/env bash
# supabase/proposed zincirini yerel Supabase kopyasının AYRI bir veritabanı
# kopyasında sınar. Ana yerel kopyaya ('postgres' veritabanı; parity_check.sh
# onu canlıyla karşılaştırır) YAZMAZ, canlıya bağlanmaz.
#
#  1. Kopya: Docker'daki yerel Postgres'te 'postgres' veritabanının public,
#     auth ve supabase_migrations şemaları (şema + veri) pg_dump ile alınır,
#     CHAIN_DB (vars. pomosprint_chain) adlı yeni veritabanına yüklenir.
#     pg_cron yalnızca 'postgres'te kurulabildiği için cron.job / schedule /
#     unschedule taklit edilir (canlıdaki iş satırlarıyla). public'teki 33
#     fonksiyon, kolon, kısıt, index, politika, yetki ve trigger'lar ana
#     kopyayla (= canlı) aynıdır: CHECK_BASE=1 ile parity_check.sh kopyada
#     da çalıştırılır.
#  2. İleri: 12 → 15 → 16 → 19 → 13 → 14 → 20 → 21 → ... → 26. Her adımda önce
#     DRYRUN (DRYRUN_RESULT satırındaki her madde 'true'), sonra dosya
#     (\echo/\quit satırları silinerek, postgres rolüyle: SQL Editor'deki gibi).
#  3. Yeni adımlar (20+): DRYRUN dosyasındaki öneri gövdesi kopyası ana
#     dosyadakiyle birebir aynı mı (işaret satırları arasında).
#  4. Geri: yeni adımların _down dosyaları ters sırada; her birinden sonra
#     şemanın kanonik dökümü o adımdan ÖNCEKİ dökümle birebir aynı olmalı.
#     (12–19 ve 13/14 geri alma zinciri proposed_sira_run_local.sh'te.)
#
# Kullanım:
#   tool/local_supabase/proposed_chain_check.sh               # kur, sına, sonda kopyayı sil
#   KEEP_DB=1 tool/local_supabase/proposed_chain_check.sh     # kopya kalır (ileri adımlar uygulanmış hâlde)
#   NO_DOWN=1 KEEP_DB=1 ...                                   # geri alma yapılmaz
#   UNTIL=14 KEEP_DB=1 ...                                    # yalnızca zincir (yeni adımlar uygulanmaz)
#   UNTIL=0 KEEP_DB=1 ...                                     # yalnızca kopya (canlı hâl; hiçbir öneri uygulanmaz)
#   CHECK_BASE=1 ...                                          # kopyada parity_check.sh (kurulumdan hemen sonra)
#   psql postgresql://postgres:postgres@127.0.0.1:54322/pomosprint_chain   # kopyayı incelemek
#
# İstemciyi kopyaya bağlamak (REST_PORT, yalnızca KEEP_DB ile): sonda kopyaya
# bağlı ayrı bir PostgREST konteyneri (<CHAIN_DB>_rest; yerel REST'in imajı,
# JWT anahtarı ve rolleriyle) 127.0.0.1:REST_PORT'ta açılır. Giriş (Auth) ana
# yerel kopyada kalır: aynı anahtarla imzalanmış oturum kopyada da geçer;
# kullanıcı satırı kopyaya ayrıca aktarılmalıdır (ör.
# tool/local_supabase/e2e/client_compat/). Ana kopyanın REST'i (54321) değişmez.
#   CHAIN_DB=pomosprint_chain_client NO_DOWN=1 KEEP_DB=1 REST_PORT=54331 tool/local_supabase/proposed_chain_check.sh
#   CHAIN_DB=pomosprint_chain_client DROP_ONLY=1 tool/local_supabase/proposed_chain_check.sh   # konteyner + kopya silinir
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
CONTAINER="${LOCAL_DB_CONTAINER:-supabase_db_pomosprint-local}"
REST_SOURCE="${LOCAL_REST_CONTAINER:-supabase_rest_pomosprint-local}"
DB="${CHAIN_DB:-pomosprint_chain}"
UNTIL="${UNTIL:-99}"
HOST_URL="postgresql://postgres:postgres@127.0.0.1:54322/$DB"
REST_CONTAINER="$(printf '%s' "$DB" | tr -c 'A-Za-z0-9_.-' '_')_rest"

case "$DB" in
  postgres|template0|template1|_supabase|storage_vectors|"")
    echo "HATA: CHAIN_DB '$DB' olamaz (ana yerel kopya ya da sistem veritabanı)." >&2; exit 2 ;;
esac
if ! docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; then
  echo "HATA: $CONTAINER çalışmıyor. Önce: supabase start --workdir tool/local_supabase" >&2; exit 2
fi
if [[ -n "${REST_PORT:-}" && -z "${KEEP_DB:-}" ]]; then
  echo "HATA: REST_PORT yalnızca KEEP_DB=1 ile (kopya sonda silinirse REST boşa bağlanır)." >&2; exit 2
fi

# Önceki koşunun REST konteyneri (varsa) her durumda kaldırılır.
docker rm -f "$REST_CONTAINER" >/dev/null 2>&1 || true
if [[ -n "${DROP_ONLY:-}" ]]; then
  docker exec "$CONTAINER" psql -U supabase_admin -d postgres -q -c "DROP DATABASE IF EXISTS \"$DB\" WITH (FORCE)" >/dev/null
  echo "SONUÇ: $REST_CONTAINER ve $DB kaldırıldı"
  exit 0
fi

TMP="$(mktemp -d)"
FAILED=0
cleanup() {
  rm -rf "$TMP"
  if [[ -z "${KEEP_DB:-}" ]]; then
    docker exec "$CONTAINER" psql -U supabase_admin -d postgres -q -c "DROP DATABASE IF EXISTS \"$DB\" WITH (FORCE)" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

admin() { docker exec -i "$CONTAINER" psql -U supabase_admin -X -q -v ON_ERROR_STOP=1 "$@"; }
PSQL=(psql "$HOST_URL" -X -q -v ON_ERROR_STOP=1)
export PGOPTIONS="${PGOPTIONS:-} -c client_min_messages=warning"

# ---------------------------------------------------------------------------
# 1. Kopya
# ---------------------------------------------------------------------------
echo "-> kopya: postgres (public, auth, supabase_migrations) → $DB"
docker exec "$CONTAINER" pg_dump -U supabase_admin -d postgres -n public -n auth -n supabase_migrations \
  -Fc -f "/tmp/${DB}_base.dump"
docker exec "$CONTAINER" sh -c "pg_restore -l /tmp/${DB}_base.dump | grep -v ' SCHEMA - public ' > /tmp/${DB}_base.list"
admin -d postgres -c "SET client_min_messages = warning" -c "DROP DATABASE IF EXISTS \"$DB\" WITH (FORCE)" >/dev/null
admin -d postgres -c "CREATE DATABASE \"$DB\" OWNER postgres" >/dev/null
admin -d "$DB" >/dev/null <<'SQL'
CREATE SCHEMA IF NOT EXISTS extensions;
GRANT USAGE ON SCHEMA extensions TO postgres, anon, authenticated, service_role;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_net;
-- pg_cron taklidi (gerçek uzantı yalnızca cron.database_name = postgres'te kurulur)
CREATE SCHEMA cron;
CREATE TABLE cron.job (
    jobid bigserial PRIMARY KEY,
    schedule text NOT NULL,
    command text NOT NULL,
    nodename text NOT NULL DEFAULT 'localhost',
    nodeport integer NOT NULL DEFAULT 5432,
    database text NOT NULL DEFAULT 'postgres',
    username text NOT NULL DEFAULT 'postgres',
    active boolean NOT NULL DEFAULT true,
    jobname text UNIQUE
);
CREATE FUNCTION cron.schedule(job_name text, schedule text, command text) RETURNS bigint LANGUAGE sql AS $$
    INSERT INTO cron.job (jobname, schedule, command) VALUES (job_name, schedule, command)
    ON CONFLICT (jobname) DO UPDATE SET schedule = excluded.schedule, command = excluded.command
    RETURNING jobid;
$$;
CREATE FUNCTION cron.unschedule(job_id bigint) RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM cron.job WHERE jobid = job_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'could not find valid entry for job %', job_id; END IF;
    RETURN true;
END $$;
CREATE FUNCTION cron.unschedule(job_name text) RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM cron.job WHERE jobname = job_name;
    IF NOT FOUND THEN RAISE EXCEPTION 'could not find valid entry for job %', job_name; END IF;
    RETURN true;
END $$;
GRANT USAGE ON SCHEMA cron TO postgres;
GRANT ALL ON ALL TABLES IN SCHEMA cron TO postgres;
GRANT ALL ON ALL SEQUENCES IN SCHEMA cron TO postgres;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA cron TO postgres;
SQL
docker exec "$CONTAINER" psql -U supabase_admin -X -q -d postgres -At \
  -c "copy (select jobname, schedule, command from cron.job order by jobid) to stdout" > "$TMP/jobs.tsv"
admin -d "$DB" -c "copy cron.job (jobname, schedule, command) from stdin" < "$TMP/jobs.tsv" >/dev/null
docker exec "$CONTAINER" pg_restore -U supabase_admin -d "$DB" -L "/tmp/${DB}_base.list" "/tmp/${DB}_base.dump"
docker exec "$CONTAINER" rm -f "/tmp/${DB}_base.dump" "/tmp/${DB}_base.list"

if [[ -n "${CHECK_BASE:-}" ]]; then
  echo "-> kopyada parity_check.sh (cron/ext/pub farkları kopyaya özgü, beklenen)"
  LOCAL_DB_URL="$HOST_URL" "$HERE/parity_check.sh" || true
fi

# ---------------------------------------------------------------------------
# Yardımcılar
# ---------------------------------------------------------------------------
apply() {
  echo "-> uygula: $1"
  sed -e '/^\\echo /d' -e '/^\\quit$/d' "$ROOT/$1" | "${PSQL[@]}" -f - >/dev/null
}

dryrun() {
  local out line item pass=0 fail=0
  out="$(psql "$HOST_URL" -X -f "$ROOT/$1" 2>&1 >/dev/null || true)"
  line="$(printf '%s\n' "$out" | grep -o 'DRYRUN_RESULT >> .*' | head -1 || true)"
  if [[ -z "$line" ]]; then
    echo "   YANLIŞ: $1 DRYRUN_RESULT üretmedi:"; printf '%s\n' "$out" | head -15; FAILED=1; return
  fi
  line="${line#DRYRUN_RESULT >> }"
  while IFS= read -r item; do
    [[ "$item" == "T00 "* ]] && continue
    case "$item" in
      *": true") pass=$((pass + 1)) ;;
      *": false") fail=$((fail + 1)); echo "   YANLIŞ: $item" ;;
    esac
  done <<< "${line// || /$'\n'}"
  echo "   DRYRUN $1: $pass/$((pass + fail)) true"
  [[ $fail -eq 0 && $pass -gt 0 ]] || FAILED=1
}

# DRYRUN'daki öneri gövdesi kopyası (işaret satırları arası) = ana dosyadaki
# BEGIN; ile COMMIT; arası.
body_matches() {
  local main="$ROOT/$1" dry="$ROOT/$2"
  awk 'f && /^COMMIT;$/ {exit} f {print} /^BEGIN;$/ {f=1}' "$main" > "$TMP/main.body"
  awk '/^-- <<< ÖNERİ GÖVDESİ SONU/ {exit} f {print} /^-- >>> ÖNERİ GÖVDESİ/ {f=1}' "$dry" > "$TMP/dry.body"
  if [[ ! -s "$TMP/main.body" ]]; then
    echo "   YANLIŞ: $1 içinde BEGIN;/COMMIT; gövdesi bulunamadı"; FAILED=1; return
  fi
  if diff -q "$TMP/main.body" "$TMP/dry.body" >/dev/null; then
    echo "   doğru: $2 içindeki gövde $1 ile birebir aynı ($(wc -l < "$TMP/main.body" | tr -d ' ') satır)"
  else
    echo "   YANLIŞ: $2 içindeki gövde $1 ile farklı:"; diff -u "$TMP/main.body" "$TMP/dry.body" | head -20; FAILED=1
  fi
}

snapshot() {
  "${PSQL[@]}" -At > "$TMP/$1.snap" <<'SQL'
CREATE FUNCTION pg_temp.acl(a aclitem[]) RETURNS text LANGUAGE sql AS
  $$ SELECT coalesce(string_agg(x::text, ',' ORDER BY x::text), '') FROM unnest(a) x $$;
SELECT 'schema ' || n.nspname || ' ' || pg_temp.acl(n.nspacl)
  FROM pg_namespace n WHERE n.nspname IN ('public', 'ops', 'auth', 'cron', 'supabase_migrations')
UNION ALL
SELECT 'func ' || p.oid::regprocedure::text || ' ' || md5(pg_get_functiondef(p.oid)) || ' ' || pg_temp.acl(p.proacl)
       || ' cfg=' || coalesce(array_to_string(p.proconfig, ','), '')
  FROM pg_proc p WHERE p.pronamespace IN ('public'::regnamespace, coalesce(to_regnamespace('ops'), 0))
UNION ALL
SELECT 'rel ' || c.oid::regclass::text || ' ' || c.relkind::text || ' rls=' || c.relrowsecurity::text || ' ' || pg_temp.acl(c.relacl)
       || ' ' || coalesce(obj_description(c.oid, 'pg_class'), '')
       || CASE WHEN c.relkind = 'v' THEN ' ' || md5(pg_get_viewdef(c.oid)) ELSE '' END
  FROM pg_class c WHERE c.relnamespace IN ('public'::regnamespace, coalesce(to_regnamespace('ops'), 0)) AND c.relkind IN ('r', 'v')
UNION ALL
SELECT 'col ' || c.oid::regclass::text || '.' || a.attname || ' ' || format_type(a.atttypid, a.atttypmod)
       || ' notnull=' || a.attnotnull::text || ' default=' || coalesce(pg_get_expr(d.adbin, d.adrelid), '')
       || ' identity=' || a.attidentity::text || ' acl=' || pg_temp.acl(a.attacl)
       || ' comment=' || coalesce(col_description(c.oid, a.attnum), '')
  FROM pg_class c JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum > 0 AND NOT a.attisdropped
  LEFT JOIN pg_attrdef d ON d.adrelid = c.oid AND d.adnum = a.attnum
 WHERE c.relnamespace IN ('public'::regnamespace, coalesce(to_regnamespace('ops'), 0)) AND c.relkind IN ('r', 'v')
UNION ALL
SELECT 'con ' || conrelid::regclass::text || ' ' || conname || ' ' || pg_get_constraintdef(oid) || ' valid=' || convalidated::text
  FROM pg_constraint WHERE connamespace = 'public'::regnamespace
UNION ALL
SELECT 'idx ' || pg_get_indexdef(i.indexrelid)
  FROM pg_index i JOIN pg_class c ON c.oid = i.indrelid WHERE c.relnamespace = 'public'::regnamespace
UNION ALL
SELECT 'pol ' || schemaname || '.' || tablename || ' ' || policyname || ' ' || cmd || ' ' || roles::text
       || ' ' || coalesce(qual, '') || ' ' || coalesce(with_check, '')
  FROM pg_policies WHERE schemaname = 'public'
UNION ALL
SELECT 'trg ' || pg_get_triggerdef(t.oid) || ' enabled=' || t.tgenabled::text
  FROM pg_trigger t JOIN pg_class c ON c.oid = t.tgrelid
 WHERE NOT t.tgisinternal AND c.relnamespace IN ('public'::regnamespace, 'auth'::regnamespace)
UNION ALL
SELECT 'cron ' || jobname || ' ' || schedule || ' ' || md5(command) FROM cron.job
UNION ALL
SELECT 'mig ' || version || ' ' || coalesce(name, '') FROM supabase_migrations.schema_migrations
ORDER BY 1;
SQL
}

same_as() {
  if diff -u "$TMP/$2.snap" "$TMP/$1.snap" > "$TMP/$1.diff"; then
    echo "   doğru: şema '$2' adımındakiyle birebir aynı ($(wc -l < "$TMP/$1.snap" | tr -d ' ') satır)"
  else
    echo "   YANLIŞ: şema '$2' adımındakinden farklı:"; head -40 "$TMP/$1.diff"; FAILED=1
  fi
}

# ---------------------------------------------------------------------------
# 2. İleri: mevcut zincir (supabase/proposed/README.md "Dosyalar ve uygulama sırası")
# ---------------------------------------------------------------------------
if [[ "$UNTIL" -ge 14 ]]; then
echo "== ZİNCİR 12 → 15 → 16 → 19 → 13 → 14 =="
dryrun supabase/tests/proposed_12_delete_own_account_dryrun.sql
apply supabase/proposed/12_delete_own_account.sql
dryrun supabase/proposed/15_monthly_leaderboard_study_month_dryrun.sql
apply supabase/proposed/15_monthly_leaderboard_study_month.sql
dryrun supabase/proposed/16_categories_order_and_privileges_dryrun.sql
apply supabase/proposed/16_categories_order_and_privileges.sql
dryrun supabase/tests/proposed_19_waitlist_consent_token_dryrun.sql
apply supabase/proposed/19_waitlist_consent_token.sql
dryrun supabase/tests/proposed_13_sunucu_butunluk_dryrun.sql
apply supabase/proposed/13_sunucu_butunluk.sql
dryrun supabase/tests/proposed_14_gizlilik_sosyal_dryrun.sql
apply supabase/proposed/14_gizlilik_sosyal.sql
fi

# ---------------------------------------------------------------------------
# 3. Yeni adımlar (zincirden SONRA). Biçim: numara|ad
# ---------------------------------------------------------------------------
NEW_STEPS=(
  "20|20_lig_donemi"
  "21|21_seans_kilit_gec_bonus"
  "22|22_avatar_satin_alma"
  "23|23_kategori_butunluk"
  "24|24_onboarding_profil"
  "25|25_sosyal_erisim"
  "26|26_segment_genisletme"
)

APPLIED=()
if [[ "$UNTIL" -ge 20 ]]; then
  echo "== YENİ ADIMLAR =="
  snapshot s14
  prev=s14
  for entry in "${NEW_STEPS[@]}"; do
    n="${entry%%|*}"; name="${entry#*|}"
    [[ "$n" -le "$UNTIL" ]] || break
    [[ -f "$ROOT/supabase/proposed/$name.sql" ]] || { echo "   (yok, atlandı: $name)"; continue; }
    body_matches "supabase/proposed/$name.sql" "supabase/tests/proposed_${name}_dryrun.sql"
    dryrun "supabase/tests/proposed_${name}_dryrun.sql"
    apply "supabase/proposed/$name.sql"
    snapshot "s$n"
    APPLIED+=("$n|$name|$prev")
    prev="s$n"
  done
fi

# ---------------------------------------------------------------------------
# 4. Geri: yeni adımların _down dosyaları ters sırada
# ---------------------------------------------------------------------------
if [[ -z "${NO_DOWN:-}" && ${#APPLIED[@]} -gt 0 ]]; then
  echo "== GERİ (yeni adımlar) =="
  for (( i=${#APPLIED[@]}-1; i>=0; i-- )); do
    IFS='|' read -r n name before <<< "${APPLIED[$i]}"
    apply "supabase/proposed/${name}_down.sql"
    snapshot "d$n"
    same_as "d$n" "$before"
  done
fi

if [[ $FAILED -ne 0 ]]; then
  echo "SONUÇ: BAŞARISIZ" >&2
  exit 1
fi
echo "SONUÇ: tüm adımlar beklendiği gibi${KEEP_DB:+ (kopya: $HOST_URL)}"

# ---------------------------------------------------------------------------
# 5. (İsteğe bağlı) Kopyaya bağlı PostgREST: REST_PORT=54331 KEEP_DB=1 ...
# ---------------------------------------------------------------------------
if [[ -n "${REST_PORT:-}" ]]; then
  NETWORK="$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' "$CONTAINER")"
  IMAGE="$(docker inspect -f '{{.Config.Image}}' "$REST_SOURCE")"
  # Yerel REST'in ayarları (yerel demo JWT anahtarı dahil; canlıda geçmez),
  # yalnızca bağlantı ve şema listesi kopyaya göre değişir.
  docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$REST_SOURCE" \
    | grep -E '^PGRST_' | grep -vE '^PGRST_(DB_URI|DB_SCHEMAS)=' > "$TMP/rest.env"
  docker run -d --name "$REST_CONTAINER" --network "$NETWORK" -p "127.0.0.1:$REST_PORT:3000" \
    --env-file "$TMP/rest.env" \
    -e "PGRST_DB_URI=postgresql://authenticator:postgres@$CONTAINER:5432/$DB" \
    -e "PGRST_DB_SCHEMAS=public" \
    "$IMAGE" >/dev/null
  for _ in $(seq 1 30); do
    if curl -fsS -o /dev/null "http://127.0.0.1:$REST_PORT/" 2>/dev/null; then break; fi
    sleep 1
  done
  if ! curl -fsS -o /dev/null "http://127.0.0.1:$REST_PORT/"; then
    echo "HATA: $REST_CONTAINER yanıt vermiyor:" >&2; docker logs --tail 20 "$REST_CONTAINER" >&2; exit 1
  fi
  echo "REST: http://127.0.0.1:$REST_PORT ($REST_CONTAINER → $DB). Kaldırmak: CHAIN_DB=$DB DROP_ONLY=1 $0"
fi
