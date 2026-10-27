#!/bin/bash
# Gerçek main() ve normal 25/50 dk ile yalnız yerel Supabase iOS E2E.
# Açıkça seçilen test simülatörü gerekir; kayıt/çıktılar yerelde kalır.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT" || exit 1
if [[ "${1:-}" == "--help" ]]; then
  echo "Senaryolar: a b c d e g i j k l m n t; varsayılan: a b c d e"
  echo "Yerel Supabase açık olmalı; sayaçlar gerçek 25/50 dakikadır."
  echo "Cihazı açıkça seçin: SIM_UDID (iOS) veya ANDROID_SERIAL (Android emülatörü)."
  exit 0
fi
[[ $# -gt 0 ]] || set -- a b c d e
declare -a FILES=()
shopt -s nullglob
for part in "$@"; do
  case "$part" in
    a|b|c|d|e|g|i|j|k|l|m|n|t) ;;
    *) echo "HATA: desteklenmeyen senaryo '$part'; --help ile listeye bakın." >&2; exit 2 ;;
  esac
  matches=(integration_test/"${part}"_*_test.dart)
  [[ ${#matches[@]} -eq 1 ]] || { echo "HATA: '$part' için tek bir test dosyası bulunmalı." >&2; exit 2; }
  FILES+=("${matches[0]}")
done

[[ -n "${SIM_UDID:-}" ]] || { echo "HATA: SIM_UDID ile test simülatörünü seçin (xcrun simctl list devices available)." >&2; exit 2; }
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
PORT="${E2E_HOST_PORT:-54399}"
API_URL="http://127.0.0.1:54321"
# Herkese açık yerel demo anon anahtarı; üretimde geçmez.
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
RUN_ID="${E2E_RUN_ID:-$(date +%m%d%H%M%S)}"
LOG_DIR="$ROOT/build/e2e_sim"
curl -fsS -o /dev/null "$API_URL/auth/v1/health" -H "apikey: $ANON_KEY" \
  || { echo "HATA: yerel Supabase yanıt vermiyor; supabase start --workdir tool/local_supabase" >&2; exit 1; }
if ! xcrun simctl list devices booted | grep -Fq "$SIM_UDID"; then
  xcrun simctl boot "$SIM_UDID" || exit 1
fi
mkdir -p "$LOG_DIR"
python3 tool/local_supabase/e2e/sim/e2e_host.py --port "$PORT" --udid "$SIM_UDID" \
  --shot-dir "${E2E_SHOT_DIR:-$LOG_DIR/screenshots}" 2>"$LOG_DIR/host.log" &
HOST_PID=$!
trap 'kill "$HOST_PID" 2>/dev/null || true' EXIT
READY=false
for _ in {1..50}; do
  if curl -fsS -o /dev/null "http://127.0.0.1:$PORT/health" 2>/dev/null; then READY=true; break; fi
  sleep 0.1
done
[[ "$READY" == true ]] || { echo "HATA: yerel test hostu başlamadı." >&2; exit 1; }
STATUS=0
for f in "${FILES[@]}"; do
  name=$(basename "$f" .dart)
  echo "=== $f / $RUN_ID"
  flutter test "$f" -d "$SIM_UDID" \
    --dart-define=SUPABASE_URL="$API_URL" \
    --dart-define=SUPABASE_ANON_KEY="$ANON_KEY" \
    --dart-define=E2E_HOST_PORT="$PORT" \
    --dart-define=E2E_RUN_ID="$RUN_ID" 2>&1 | tee "$LOG_DIR/$name.log"
  rc=${PIPESTATUS[0]}
  echo "=== $f: $([ "$rc" = 0 ] && echo GEÇTİ || echo "KALDI ($rc)")"
  [[ "$rc" = 0 ]] || STATUS=1
done
# Şema yalnız kayıtlı referansla karşılaştırılır; güncel canlı doğrulaması değildir.
/bin/bash tool/local_supabase/parity_check.sh | tee "$LOG_DIR/parity.log"
[[ ${PIPESTATUS[0]} -eq 0 ]] || STATUS=1
exit "$STATUS"
