#!/bin/bash
# Simülatörde, yerel Supabase kopyasına bağlı uçtan uca testler
# (integration_test/). Ayrıntı: tool/local_supabase/README.md
# "Simülatörde uçtan uca test".
#
#   tool/local_supabase/e2e/sim/run_sim_e2e.sh            # hepsi (a b c d e)
#   tool/local_supabase/e2e/sim/run_sim_e2e.sh c d        # yalnızca seçilenler
#
# Ortam: SIM_UDID (vars. iPhone 16 Pro / iOS 18.6), DEVELOPER_DIR (vars.
# /Applications/Xcode.app/Contents/Developer), E2E_HOST_PORT (vars. 54399).
# Ekran görüntüleri analiz/ekranlar/e2e-*.png, psql günlüğü build/e2e_sim/.
set -u -o pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT" || exit 1

SIM_UDID="${SIM_UDID:-7B8AF086-0864-42FD-B4D8-37A782C3F6B9}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
PORT="${E2E_HOST_PORT:-54399}"
API_URL="http://127.0.0.1:54321"
# Supabase CLI'nin herkese açık YEREL demo anahtarı (tool/local_supabase/local_api.py; canlıda geçmez).
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
RUN_ID="${E2E_RUN_ID:-$(date +%m%d%H%M%S)}"
LOG_DIR="$ROOT/build/e2e_sim"
mkdir -p "$LOG_DIR"

declare -a FILES=()
for s in "${@:-a b c d e}"; do
  for part in $s; do
    f=$(ls integration_test/"${part}"_*_test.dart 2>/dev/null | head -1)
    [ -n "$f" ] || { echo "HATA: senaryo '$part' için integration_test/${part}_*_test.dart yok" >&2; exit 2; }
    FILES+=("$f")
  done
done

# Ön koşullar: yerel API, simülatör açık.
curl -fsS -o /dev/null "$API_URL/auth/v1/health" -H "apikey: $ANON_KEY" \
  || { echo "HATA: yerel Supabase ($API_URL) yanıt vermiyor: supabase start --workdir tool/local_supabase" >&2; exit 1; }
xcrun simctl list devices | grep -q "$SIM_UDID) (Booted)" || xcrun simctl boot "$SIM_UDID"

python3 tool/local_supabase/e2e/sim/e2e_host.py --port "$PORT" --udid "$SIM_UDID" 2>>"$LOG_DIR/host.log" &
HOST_PID=$!
trap 'kill $HOST_PID 2>/dev/null' EXIT
for _ in $(seq 1 50); do curl -fsS -o /dev/null "http://127.0.0.1:$PORT/health" && break; sleep 0.1; done

echo "koşu: $RUN_ID (hesaplar: e2e-sim-*-$RUN_ID@pomosprint.local)"
STATUS=0
for f in "${FILES[@]}"; do
  name=$(basename "$f" .dart)
  echo "=== $f"
  start=$(date +%s)
  flutter test "$f" -d "$SIM_UDID" \
    --dart-define=SUPABASE_URL="$API_URL" \
    --dart-define=SUPABASE_ANON_KEY="$ANON_KEY" \
    --dart-define=E2E_HOST_PORT="$PORT" \
    --dart-define=E2E_RUN_ID="$RUN_ID" 2>&1 | tee "$LOG_DIR/$name.log"
  rc=${PIPESTATUS[0]}
  echo "=== $f: $([ "$rc" = 0 ] && echo GEÇTİ || echo "KALDI ($rc)") ($(( $(date +%s) - start )) sn)"
  [ "$rc" = 0 ] || STATUS=1
done

# Ana yerel kopya canlıyla eşit kalmalı (testler yalnızca veri yazar).
/bin/bash tool/local_supabase/parity_check.sh | tail -1
exit $STATUS
