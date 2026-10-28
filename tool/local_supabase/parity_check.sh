#!/usr/bin/env bash
# Yerel Supabase kopyasının şemasını canlının parmak iziyle karşılaştırır.
# Canlıya BAĞLANMAZ: canlı taraf parity/live_summary.tsv (kategori başına
# satır sayısı + md5) ve parity/live_lines.tsv (satır satır) dosyalarındadır;
# ikisi de canlıda parity/fingerprint_lines.sql'in salt okuma çıktısıdır.
#
# Kullanım:
#   tool/local_supabase/parity_check.sh                     yerel = canlı mı? (çıkış 0 = evet)
#   tool/local_supabase/parity_check.sh --diff              + farklı satırlar (live_lines.tsv'ye göre)
#   tool/local_supabase/parity_check.sh --print-summary-sql canlıda çalıştırılacak özet SQL'i
#   tool/local_supabase/parity_check.sh --print-lines-sql   canlıda çalıştırılacak ayrıntı SQL'i
#   tool/local_supabase/parity_check.sh --local-lines       yerelin normalize satırları
#   tool/local_supabase/parity_check.sh --reviewed-night-20261028
#     yalnız yerel 27/28/29 adayını ayrı incelenmiş referansla karşılaştırır
#
# Canlı özeti tazelemek: --print-summary-sql çıktısını Supabase SQL Editor'de
# (ya da MCP execute_sql ile) çalıştır, (k, n, h) satırlarını sekmeyle ayırıp
# parity/live_summary.tsv'ye yaz. Bilinçli farklar aşağıda normalize edilir.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
LINES_SQL="$HERE/parity/fingerprint_lines.sql"
LIVE_SUMMARY="$HERE/parity/live_summary.tsv"
LIVE_LINES="$HERE/parity/live_lines.tsv"
DB_URL="${LOCAL_DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"

# Explicit opt-in only: the default historical live reference below is unchanged.
if [[ "${1:-}" == "--reviewed-night-20261028" ]]; then
  [[ $# -eq 1 ]] || { echo "HATA: reviewed parity ek seçenek kabul etmez." >&2; exit 2; }
  exec python3 "$HERE/parity_check_reviewed.py"
fi
if [[ "${1:-}" == "--reviewed-night-20261028-with-start-atomic" ]]; then
  [[ $# -eq 1 ]] || { echo "HATA: reviewed parity ek seçenek kabul etmez." >&2; exit 2; }
  exec python3 "$HERE/parity_check_reviewed.py" --with-session-start-atomic
fi
if [[ "${1:-}" == "--reviewed-night-20261028-with-marathon-anchor" ]]; then
  [[ $# -eq 1 ]] || { echo "HATA: reviewed parity ek seçenek kabul etmez." >&2; exit 2; }
  exec python3 "$HERE/parity_check_reviewed.py" --with-marathon-anchor
fi

case "$DB_URL" in
  *@127.0.0.1:*|*@localhost:*|*@\[::1\]:*) ;;
  *) echo "HATA: LOCAL_DB_URL yerel değil; bu betik yalnızca yerel kopyaya bağlanır." >&2; exit 2 ;;
esac

# fingerprint_lines.sql'in "with lines(k, line) as (...)" gövdesi (yorum
# satırları ve son select olmadan).
cte_body() {
  grep -v '^[[:space:]]*--' "$LINES_SQL" | grep -v '^select k, '
}

summary_sql() {
  cte_body
  cat <<'SQL'
select k, count(*) n, md5(string_agg(line, E'\n' order by line collate "C")) h from lines group by k order by k;
SQL
}

# Bilinçli fark 1: hoş geldin e-postası trigger'ı yerelde devre dışı ('D').
# Karşılaştırmadan önce canlıdaki hâline ('O') çevrilir; yerelde gerçekten
# kapalı olduğu ayrıca denetlenir.
normalized_cte() {
  cte_body
  cat <<'SQL'
, norm(k, line) as (
  select k, case when k = 'trg' and line like 'public.marketing_subscribers after_insert_marketing_subscribers enabled=D %'
                 then replace(line, ' enabled=D ', ' enabled=O ') else line end
    from lines)
SQL
}

psql_local() {
  psql "$DB_URL" -X -q -At -F $'\t' -v ON_ERROR_STOP=1 "$@"
}

local_summary() {
  { normalized_cte
    cat <<'SQL'
select k, count(*) n, md5(string_agg(line, E'\n' order by line collate "C")) h from norm group by k order by k;
SQL
  } | psql_local -f -
}

local_lines() {
  { normalized_cte
    cat <<'SQL'
select k, replace(line, E'\n', '\n') as line from norm order by k, replace(line, E'\n', '\n') collate "C";
SQL
  } | psql_local -f -
}

case "${1:-}" in
  --print-summary-sql) summary_sql; exit 0 ;;
  --print-lines-sql) cat "$LINES_SQL"; exit 0 ;;
  --local-lines) local_lines; exit 0 ;;
  ""|--diff) ;;
  *) echo "Bilinmeyen seçenek: $1" >&2; exit 2 ;;
esac

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
local_summary > "$TMP/local.tsv"

FAILED=0
printf '%-8s %6s %6s  %s\n' kategori canli yerel sonuc
while IFS=$'\t' read -r k n h; do
  [[ -z "$k" ]] && continue
  lrow="$(awk -F'\t' -v k="$k" '$1 == k' "$TMP/local.tsv")"
  ln="$(cut -f2 <<< "$lrow")"; lh="$(cut -f3 <<< "$lrow")"
  if [[ "$h" == "$lh" ]]; then
    res="aynı"
  elif [[ "$k" == "extver" ]]; then
    res="FARKLI (bilgi: extension sürümü imaja bağlı)"
  else
    res="FARKLI"; FAILED=1
  fi
  printf '%-8s %6s %6s  %s\n' "$k" "$n" "${ln:-0}" "$res"
done < "$LIVE_SUMMARY"

# Yerelde olup canlı özette olmayan kategori
while IFS=$'\t' read -r k n h; do
  if ! awk -F'\t' -v k="$k" '$1 == k { f = 1 } END { exit !f }' "$LIVE_SUMMARY"; then
    printf '%-8s %6s %6s  %s\n' "$k" 0 "$n" "FARKLI (canlıda yok)"; FAILED=1
  fi
done < "$TMP/local.tsv"

# Bilinçli fark 1 gerçekten yerinde mi?
state="$(psql_local -c "select tgenabled from pg_trigger where tgname = 'after_insert_marketing_subscribers' and tgrelid = 'public.marketing_subscribers'::regclass")"
if [[ "$state" == "D" ]]; then
  echo "bilinçli fark: after_insert_marketing_subscribers yerelde devre dışı (canlıya istek yok)"
else
  echo "YANLIŞ: after_insert_marketing_subscribers yerelde etkin ($state); canlı Edge Function'a istek atabilir"; FAILED=1
fi

# Avatar kataloğu (seed.sql) canlıyla aynı mı? (TimeZone=UTC ile)
avatars="$(PGTZ=UTC psql_local -F ' ' -c "select count(*), md5(string_agg(format('%L,%L,%L,%L,%s,%s,%s,%s,%s,%L,%s', id, name_tr, name_en, asset_key, cost_coins, is_premium_only, is_default, sort_order, is_active, created_at, is_league_award), E'\n' order by id collate \"C\")) from public.avatars")"
if [[ "$avatars" == "27 2dffed668b250dbc592e8c7c31ad3754" ]]; then
  echo "avatars: 27 satır, canlıyla aynı"
else
  echo "YANLIŞ: avatars canlıdan farklı ($avatars)"; FAILED=1
fi

if [[ "${1:-}" == "--diff" && $FAILED -ne 0 && -f "$LIVE_LINES" ]]; then
  local_lines > "$TMP/local_lines.tsv"
  echo "--- canlı (parity/live_lines.tsv)   +++ yerel"
  diff "$LIVE_LINES" "$TMP/local_lines.tsv" | grep '^[<>]' | sed -e 's/^</-/' -e 's/^>/+/' || true
fi

if [[ $FAILED -ne 0 ]]; then
  echo "SONUÇ: yerel kopya canlıdan FARKLI" >&2
  exit 1
fi
echo "SONUÇ: yerel kopya canlıyla aynı (bilinçli farklar hariç)"
