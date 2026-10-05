#!/bin/bash
# Tek Android emülatörde yerel Supabase UI testleri. SDK emülatörü önceden
# başlatılmış olmalı. Android'in 10.0.2.2 adresi ana makinenin loopback'idir.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT" || exit 1
export ANDROID_HOME="${ANDROID_HOME:-/Users/almano/Library/Android/sdk}"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
export GRADLE_OPTS='-Dorg.gradle.jvmargs=-Xmx2048m -Dorg.gradle.workers.max=2 -Dorg.gradle.parallel=false'
DEVICE="${ANDROID_SERIAL:-emulator-5554}"
case "$DEVICE" in emulator-*) ;; *) echo "Yalnızca Android emülatörü desteklenir" >&2; exit 2 ;; esac
PORT="${E2E_HOST_PORT:-54399}"
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
RUN_ID="${E2E_RUN_ID:-$(date +%m%d%H%M%S)}"
LOG_DIR="$ROOT/build/e2e_android"
mkdir -p "$LOG_DIR"
curl -fsS -o /dev/null http://127.0.0.1:54321/auth/v1/health -H "apikey: $ANON_KEY" || exit 1
adb -s "$DEVICE" get-state || exit 1
python3 tool/local_supabase/e2e/sim/e2e_host.py --port "$PORT" --android-serial "$DEVICE" \
  ${E2E_ALLOW_OUTAGE:+--allow-api-outage} ${E2E_SHOT_DIR:+--shot-dir "$E2E_SHOT_DIR"} 2>"$LOG_DIR/host.log" &
HOST_PID=$!
trap 'kill $HOST_PID 2>/dev/null; docker start supabase_kong_pomosprint-local >/dev/null 2>&1' EXIT
for _ in $(seq 1 50); do curl -fsS -o /dev/null "http://127.0.0.1:$PORT/health" && break; sleep 0.1; done
STATUS=0
for part in "$@"; do
  f=$(ls integration_test/"${part}"_*_test.dart 2>/dev/null | head -1)
  [ -n "$f" ] || exit 2
  echo "=== $f / Android / $RUN_ID"
  flutter test "$f" -d "$DEVICE" \
    --dart-define=SUPABASE_URL=http://10.0.2.2:54321 \
    --dart-define=SUPABASE_ANON_KEY="$ANON_KEY" \
    --dart-define=E2E_HOST_ADDRESS=10.0.2.2 --dart-define=E2E_HOST_PORT="$PORT" \
    --dart-define=E2E_RUN_ID="$RUN_ID" \
    --dart-define=QUICK_TIMER="${QUICK_TIMER:-false}" \
    --dart-define=QUICK_TIMER_SAVE="${QUICK_TIMER_SAVE:-false}" \
    --dart-define=E2E_REUSE="${E2E_REUSE:-false}" 2>&1 | tee "$LOG_DIR/$(basename "$f" .dart).log"
  rc=${PIPESTATUS[0]}
  echo "=== $f: $([ "$rc" = 0 ] && echo GEÇTİ || echo "KALDI ($rc)")"
  [ "$rc" = 0 ] || STATUS=1
done
exit "$STATUS"
