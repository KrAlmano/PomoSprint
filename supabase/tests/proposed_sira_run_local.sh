#!/usr/bin/env bash
# supabase/proposed/ uygulama sırasını ve geri alma zincirini YEREL, tek
# kullanımlık bir Postgres'te (16+) sınar. CANLI veritabanına KARŞI
# ÇALIŞTIRMAYIN.
#
#   ileri : 12 → 15 → 16 → 19 → 13 → 14   (her adımdan önce o adımın DRYRUN'u)
#   geri  : 14_down → 13_down → 19_down → 16_down → 15_down → 12_down
#
# Taban şema: proposed_sira_local_stub.sql (canlıdan salt okunarak kuruldu;
# public'teki 33 fonksiyonun md5'i canlıyla aynı). Her adımdan sonra şemanın
# kanonik bir dökümü alınır; her _down dosyasından sonra döküm, o adımdan
# ÖNCEKİ dökümle birebir aynı olmalı. Ayrıca sıra dışı kullanım denenir:
# 13'ten önce 14'ün DRYRUN'u ve 14'ten sonra 13 ön koşul hatasıyla durmalı.
#
# Bağlantı standart PG* ortam değişkenleriyle (yalnızca yerel sunucu).
# Kullanım: supabase/tests/proposed_sira_run_local.sh
set -euo pipefail

case "${PGHOST:-}" in
  ""|localhost|127.0.0.1|::1|/*) ;;
  *) echo "HATA: PGHOST yerel değil (${PGHOST}); bu script yalnızca yerel Postgres içindir." >&2; exit 1 ;;
esac
if [[ -n "${DATABASE_URL:-}" ]]; then
  echo "HATA: DATABASE_URL tanımlı; yanlışlıkla uzak veritabanına bağlanmamak için iptal edildi." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DB="proposed_sira_$$"
TMP="$(mktemp -d)"
createdb "$DB"
trap 'dropdb --if-exists "$DB"; rm -rf "$TMP"' EXIT

PSQL=(psql -X -q -v ON_ERROR_STOP=1 -d "$DB")
export PGOPTIONS="${PGOPTIONS:-} -c client_min_messages=warning"
FAILED=0

# Dosyayı \echo/\quit satırları olmadan uygular (SQL Editor'deki gibi).
apply() {
  echo "-> uygula: $1"
  sed -e '/^\\echo /d' -e '/^\\quit$/d' "$ROOT/$1" | "${PSQL[@]}" -f - >/dev/null
}

# Uygulama hata vermeli ve hata metni $2'yi içermeli (sıra dışı kullanım).
apply_must_fail() {
  local out
  if out="$(sed -e '/^\\echo /d' -e '/^\\quit$/d' "$ROOT/$1" | psql -X -q -v ON_ERROR_STOP=1 -d "$DB" -f - 2>&1 >/dev/null)"; then
    echo "   YANLIŞ: $1 hata vermeden uygulandı"; FAILED=1; return
  fi
  if [[ "$out" == *"$2"* ]]; then echo "   doğru: $1 durdu ($2)"; else echo "   YANLIŞ: $1 beklenmeyen hata: $out"; FAILED=1; fi
}

# DRYRUN_RESULT satırını ayrıştırır: ': true' / ': false' ile biten maddeleri
# sayar (T00 özeti ve BİLGİ satırları sayılmaz). $2 verilirse DRYRUN yerine
# o metni içeren bir hata beklenir.
dryrun() {
  local out line item pass=0 fail=0
  out="$(psql -X -d "$DB" -f "$ROOT/$1" 2>&1 >/dev/null || true)"
  if [[ -n "${2:-}" ]]; then
    if [[ "$out" == *"$2"* && "$out" != *"DRYRUN_RESULT >>"* ]]; then
      echo "   doğru: $1 durdu ($2)"
    else
      echo "   YANLIŞ: $1 durmadı ya da beklenmeyen çıktı:"; printf '%s\n' "$out" | head -5; FAILED=1
    fi
    return
  fi
  line="$(printf '%s\n' "$out" | grep -o 'DRYRUN_RESULT >> .*' | head -1 || true)"
  if [[ -z "$line" ]]; then
    echo "   YANLIŞ: $1 DRYRUN_RESULT üretmedi:"; printf '%s\n' "$out" | head -10; FAILED=1; return
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

# Şemanın kanonik dökümü (fonksiyon gövdeleri md5 ile). Yetki listeleri
# sıralanır: DROP + CREATE edilen fonksiyonda aynı yetkilerin sırası değişebilir.
snapshot() {
  "${PSQL[@]}" -At > "$TMP/$1.snap" <<'SQL'
CREATE FUNCTION pg_temp.acl(a aclitem[]) RETURNS text LANGUAGE sql AS
  $$ SELECT coalesce(string_agg(x::text, ',' ORDER BY x::text), '') FROM unnest(a) x $$;
SELECT 'schema ' || n.nspname || ' ' || pg_temp.acl(n.nspacl)
  FROM pg_namespace n WHERE n.nspname IN ('public', 'ops', 'auth', 'cron', 'supabase_migrations')
UNION ALL
SELECT 'func ' || p.oid::regprocedure::text || ' ' || md5(pg_get_functiondef(p.oid)) || ' ' || pg_temp.acl(p.proacl)
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
SELECT 'con ' || conrelid::regclass::text || ' ' || conname || ' ' || pg_get_constraintdef(oid)
  FROM pg_constraint WHERE connamespace = 'public'::regnamespace
UNION ALL
SELECT 'idx ' || pg_get_indexdef(i.indexrelid)
  FROM pg_index i JOIN pg_class c ON c.oid = i.indrelid WHERE c.relnamespace = 'public'::regnamespace
UNION ALL
SELECT 'pol ' || schemaname || '.' || tablename || ' ' || policyname || ' ' || cmd || ' ' || roles::text
       || ' ' || coalesce(qual, '') || ' ' || coalesce(with_check, '')
  FROM pg_policies WHERE schemaname = 'public'
UNION ALL
SELECT 'trg ' || pg_get_triggerdef(t.oid)
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

echo "-> taban: supabase/tests/proposed_sira_local_stub.sql"
"${PSQL[@]}" -f "$ROOT/supabase/tests/proposed_sira_local_stub.sql" >/dev/null
snapshot s0

echo "== İLERİ =="
dryrun supabase/tests/proposed_12_delete_own_account_dryrun.sql
apply supabase/proposed/12_delete_own_account.sql;                 snapshot s12
dryrun supabase/proposed/15_monthly_leaderboard_study_month_dryrun.sql
apply supabase/proposed/15_monthly_leaderboard_study_month.sql;    snapshot s15
dryrun supabase/proposed/16_categories_order_and_privileges_dryrun.sql
apply supabase/proposed/16_categories_order_and_privileges.sql;    snapshot s16
dryrun supabase/tests/proposed_19_waitlist_consent_token_dryrun.sql
apply supabase/proposed/19_waitlist_consent_token.sql;             snapshot s19
echo "-- sıra dışı: 13'ten önce 14"
dryrun supabase/tests/proposed_14_gizlilik_sosyal_dryrun.sql "proposed/14 ön koşulu"
dryrun supabase/tests/proposed_13_sunucu_butunluk_dryrun.sql
apply supabase/proposed/13_sunucu_butunluk.sql;                    snapshot s13
dryrun supabase/tests/proposed_14_gizlilik_sosyal_dryrun.sql
apply supabase/proposed/14_gizlilik_sosyal.sql;                    snapshot s14
echo "-- sıra dışı: 14'ten sonra 13 ve 14 tekrar"
apply_must_fail supabase/proposed/13_sunucu_butunluk.sql "proposed/13 ön koşulu"
apply_must_fail supabase/proposed/14_gizlilik_sosyal.sql "proposed/14 ön koşulu"

echo "== GERİ =="
apply supabase/proposed/14_gizlilik_sosyal_down.sql;               snapshot d14; same_as d14 s13
apply supabase/proposed/13_sunucu_butunluk_down.sql;               snapshot d13; same_as d13 s19
apply supabase/proposed/19_waitlist_consent_token_down.sql;        snapshot d19; same_as d19 s16
apply supabase/proposed/16_categories_order_and_privileges_down.sql; snapshot d16; same_as d16 s15
apply supabase/proposed/15_monthly_leaderboard_study_month_down.sql; snapshot d15; same_as d15 s12
apply supabase/proposed/12_delete_own_account_down.sql;            snapshot d12; same_as d12 s0

if [[ $FAILED -ne 0 ]]; then
  echo "SONUÇ: BAŞARISIZ" >&2
  exit 1
fi
echo "SONUÇ: tüm adımlar beklendiği gibi"
