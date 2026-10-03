#!/usr/bin/env bash
# Migration zincirini ve SQL davranış testlerini YEREL, tek kullanımlık bir
# Postgres veritabanında çalıştırır. CANLI veritabanına KARŞI ÇALIŞTIRMAYIN.
#
# Gereksinim: PostgreSQL 14+ istemci araçları (createdb, dropdb, psql) ve
# yerel bir sunucu. Bağlantı standart PG* ortam değişkenleriyle verilir
# (varsayılan: yerel Unix soketi).
#
# Kullanım: supabase/tests/run_local.sh
# Sıra: stub (baseline) -> supabase/migrations/*.sql (isim sırasıyla) ->
#       proposed/11_audit_fixes_unapplied.sql (canlıda YOK; yalnızca bu
#       yerel test için uygulanır) -> helpers.sql -> security_hardening_test.sql
#       -> audit_fixes_test.sql
# Not: Repodaki 2026-08 / 2026-09 migration'ları canlı geçmişte yok; bu
# zincir canlıyı değil, o dosyaların kendi tutarlılığını sınar.
#
# SKIP_MIGRATIONS (boşlukla ayrılmış dosya adları) repo zincirinde
# kurulamayan migration'ları atlar. Varsayılan:
# 20261003150000_live_audit_fixes.sql — canlı fonksiyon gövdelerinden
# yazıldı ve canlıda olup repoda olmayan nesnelere (marketing_subscribers,
# league_award_avatar_id, add_friend_by_code, e-postasız get_league_ranking
# ...) dayanır. Onun doğrulaması tests/20261003_live_audit_fixes_dryrun.sql
# ile (canlı üzerinde, geri alınan transaction'da) yapılır.
set -euo pipefail

SKIP_MIGRATIONS="${SKIP_MIGRATIONS-20261003150000_live_audit_fixes.sql}"

case "${PGHOST:-}" in
  ""|localhost|127.0.0.1|::1|/*) ;;
  *) echo "HATA: PGHOST yerel değil (${PGHOST}); bu script yalnızca yerel Postgres içindir." >&2; exit 1 ;;
esac
if [[ -n "${DATABASE_URL:-}" ]]; then
  echo "HATA: DATABASE_URL tanımlı; yanlışlıkla uzak veritabanına bağlanmamak için iptal edildi." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DB="pomosprint_test_$$"

createdb "$DB"
trap 'dropdb --if-exists "$DB"' EXIT

PSQL=(psql -X -q -v ON_ERROR_STOP=1 -d "$DB")

"${PSQL[@]}" -f "$ROOT/supabase/tests/security_hardening_stub.sql"
for f in "$ROOT"/supabase/migrations/*.sql; do
  name="$(basename "$f")"
  if [[ " $SKIP_MIGRATIONS " == *" $name "* ]]; then
    echo "-- atlandı: $name"
    continue
  fi
  echo "-> $name"
  "${PSQL[@]}" -f "$f"
done
echo "-> proposed/11_audit_fixes_unapplied.sql (yalnızca yerel test)"
"${PSQL[@]}" -f "$ROOT/supabase/proposed/11_audit_fixes_unapplied.sql"
"${PSQL[@]}" -f "$ROOT/supabase/tests/helpers.sql"
"${PSQL[@]}" -f "$ROOT/supabase/tests/security_hardening_test.sql"
"${PSQL[@]}" -f "$ROOT/supabase/tests/audit_fixes_test.sql"

echo "Tüm SQL testleri geçti."
