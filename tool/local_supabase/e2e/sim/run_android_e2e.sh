#!/bin/bash
# Normal 25/50 dk ile yalnız yerel Supabase Android E2E.
# Tek test emülatörü önceden başlatılmış olmalı; fiziksel cihaz kabul edilmez.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT" || exit 1
if [[ "${1:-}" == "--help" ]]; then
  echo "Senaryolar: a aa b c d e g h i j k l m n o p q r s t u v w x; varsayılan: a b c d e"
  echo "Yerel Supabase açık olmalı; sayaçlar gerçek 25/50 dakikadır."
  echo "Cihazı açıkça seçin: SIM_UDID (iOS) veya ANDROID_SERIAL (Android emülatörü)."
  exit 0
fi
[[ $# -gt 0 ]] || set -- a b c d e
declare -a FILES=()
shopt -s nullglob
for part in "$@"; do
  case "$part" in
    a|aa|b|c|d|e|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x) ;;
    *) echo "HATA: desteklenmeyen senaryo '$part'; --help ile listeye bakın." >&2; exit 2 ;;
  esac
  matches=(integration_test/"${part}"_*_test.dart)
  [[ ${#matches[@]} -eq 1 ]] || { echo "HATA: '$part' için tek bir test dosyası bulunmalı." >&2; exit 2; }
  FILES+=("${matches[0]}")
done

DEVICE="${ANDROID_SERIAL:-}"
case "$DEVICE" in emulator-*) ;; *) echo "HATA: ANDROID_SERIAL ile emulator-* test cihazını seçin (adb devices)." >&2; exit 2 ;; esac
export ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
export GRADLE_OPTS='-Dorg.gradle.jvmargs=-Xmx2048m -Dorg.gradle.workers.max=2 -Dorg.gradle.parallel=false'
PORT="${E2E_HOST_PORT:-54399}"
API_PORT="${E2E_API_PORT:-54321}"
case "$API_PORT" in 54321|54325) ;; *) echo "HATA: yalnız yerel QA API portu kabul edilir." >&2; exit 2 ;; esac
# Herkese açık yerel demo anon anahtarı; üretimde geçmez.
ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
RUN_ID="${E2E_RUN_ID:-$(date +%m%d%H%M%S)}"
EXTRA_DEFINES=()
if [[ -n "${E2E_PLAIN_NAME:-}" ]]; then
  EXTRA_DEFINES+=("--plain-name=$E2E_PLAIN_NAME")
fi
case "${E2E_MARATHON_MINUTES:-25}" in 25|50) ;; *) echo "HATA: Maraton yalnız25/50 dakika olabilir." >&2; exit 2 ;; esac
EXTRA_DEFINES+=("--dart-define=E2E_MARATHON_MINUTES=${E2E_MARATHON_MINUTES:-25}")
for flag in E2E_REAL_MARATHON E2E_HTTP_PROXY E2E_NORMAL_HTTP_REAL25 E2E_NORMAL_HTTP_PRESEEDED E2E_FIRST_USE_REAL25 E2E_EXAM_INSIGHTS; do
  case "${!flag:-false}" in
    true) EXTRA_DEFINES+=("--dart-define=$flag=true") ;;
    false) ;;
    *) echo "HATA: $flag true/false olmalı." >&2; exit 2 ;;
  esac
done
if [[ "${E2E_EXAM_INSIGHTS:-false}" == "true" ]]; then
  [[ "${E2E_EXAM_INSIGHT_EMAIL:-}" =~ ^e2e-sim-exam-fixture-insight-[a-z0-9-]+@pomosprint\.local$ ]] \
    || { echo "HATA: yalnız yerel insight fixture hesabı kabul edilir." >&2; exit 2; }
  [[ "${E2E_EXAM_INSIGHT_OWNER:-}" =~ ^[0-9a-f-]{36}$ ]] \
    || { echo "HATA: insight owner UUID gereklidir." >&2; exit 2; }
  EXTRA_DEFINES+=("--dart-define=E2E_EXAM_INSIGHT_EMAIL=$E2E_EXAM_INSIGHT_EMAIL" "--dart-define=E2E_EXAM_INSIGHT_OWNER=$E2E_EXAM_INSIGHT_OWNER")
fi
if [[ -n "${E2E_NORMAL_HTTP_MODE:-}" ]]; then
  case "$E2E_NORMAL_HTTP_MODE" in start|resume) ;; *) echo "HATA: geçersiz HTTP süreç testi aşaması." >&2; exit 2 ;; esac
  EXTRA_DEFINES+=("--dart-define=E2E_NORMAL_HTTP_MODE=$E2E_NORMAL_HTTP_MODE")
fi
if [[ -n "${E2E_LEAGUE_FIXTURE_EMAIL:-}" ]]; then
  case "$E2E_LEAGUE_FIXTURE_EMAIL" in
    e2e-sim-*@pomosprint.local) ;;
    *) echo "HATA: yalnız yerel e2e-sim lig fixture hesabı kabul edilir." >&2; exit 2 ;;
  esac
  case "${E2E_LEAGUE_PHASE:-change}" in change|resume) ;; *) echo "HATA: geçersiz lig testi aşaması." >&2; exit 2 ;; esac
  EXTRA_DEFINES+=("--dart-define=E2E_LEAGUE_FIXTURE_EMAIL=$E2E_LEAGUE_FIXTURE_EMAIL" "--dart-define=E2E_LEAGUE_PHASE=${E2E_LEAGUE_PHASE:-change}")
fi
if [[ -n "${E2E_PROBE_MODE:-}" ]]; then
  case "$E2E_PROBE_MODE" in
    normal25_start|normal50_start|exam_lgs_start|exam_tus_start|resume) ;;
    *) echo "HATA: geçersiz gerçek süre probe modu." >&2; exit 2 ;;
  esac
  case "${E2E_PROBE_REQUIRE_COMPLETED:-false}" in true|false) ;; *) exit 2 ;; esac
  EXTRA_DEFINES+=("--dart-define=E2E_PROBE_MODE=$E2E_PROBE_MODE" "--dart-define=E2E_PROBE_REQUIRE_COMPLETED=${E2E_PROBE_REQUIRE_COMPLETED:-false}")
fi
if [[ -n "${E2E_EXAM_FIXTURE_EMAIL:-}" ]]; then
  case "$E2E_EXAM_FIXTURE_EMAIL" in
    e2e-sim-*@pomosprint.local) EXTRA_DEFINES+=("--dart-define=E2E_EXAM_FIXTURE_EMAIL=$E2E_EXAM_FIXTURE_EMAIL") ;;
    *) echo "HATA: yalnız yerel e2e-sim deneme fixture hesabı kabul edilir." >&2; exit 2 ;;
  esac
fi
LOG_DIR="$ROOT/build/e2e_android"
curl -fsS -o /dev/null "http://127.0.0.1:54321/auth/v1/health" -H "apikey: $ANON_KEY" \
  || { echo "HATA: yerel Supabase yanıt vermiyor; supabase start --workdir tool/local_supabase" >&2; exit 1; }
if [[ "$API_PORT" == "54325" ]]; then
  curl -fsS -o /dev/null http://127.0.0.1:54326/health \
    || { echo "HATA: yerel QA HTTP proxy admin yanıt vermiyor." >&2; exit 1; }
fi
adb -s "$DEVICE" get-state || exit 1
mkdir -p "$LOG_DIR"
# Use this emulator's adb transport instead of the host's LAN/NAT permissions.
# Only these explicitly mapped QA ports are removed when the runner exits.
REVERSE_PORTS=("$API_PORT" "$PORT")
[[ "$API_PORT" != 54325 ]] || REVERSE_PORTS+=(54326)
HOST_PID=""
cleanup() {
  [[ -z "$HOST_PID" ]] || kill "$HOST_PID" 2>/dev/null || true
  [[ -z "$HOST_PID" ]] || wait "$HOST_PID" 2>/dev/null || true
  for reverse_port in "${REVERSE_PORTS[@]}"; do
    adb -s "$DEVICE" reverse --remove "tcp:$reverse_port" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT
for reverse_port in "${REVERSE_PORTS[@]}"; do
  adb -s "$DEVICE" reverse "tcp:$reverse_port" "tcp:$reverse_port" || exit 1
done
python3 tool/local_supabase/e2e/sim/e2e_host.py --port "$PORT" --android-serial "$DEVICE" \
  --shot-dir "${E2E_SHOT_DIR:-$LOG_DIR/screenshots}" 2>"$LOG_DIR/host.log" &
HOST_PID=$!
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
  # Preserve the installation and its data for genuine process-restart tests.
  flutter test --no-pub --no-uninstall "$f" -d "$DEVICE" \
    --dart-define=SUPABASE_URL="http://127.0.0.1:$API_PORT" \
    --dart-define=SUPABASE_ANON_KEY="$ANON_KEY" \
    --dart-define=E2E_HOST_ADDRESS=127.0.0.1 \
    --dart-define=E2E_HOST_PORT="$PORT" \
    --dart-define=E2E_RUN_ID="$RUN_ID" ${EXTRA_DEFINES[@]+"${EXTRA_DEFINES[@]}"} 2>&1 | tee "$LOG_DIR/$name.log"
  rc=${PIPESTATUS[0]}
  echo "=== $f: $([ "$rc" = 0 ] && echo GEÇTİ || echo "KALDI ($rc)")"
  [[ "$rc" = 0 ]] || STATUS=1
done
# Same explicit reviewed local schema as the iOS runner; no live connection.
if [[ "${E2E_REVIEWED_NIGHT:-0}" == "2" ]]; then
  /bin/bash tool/local_supabase/parity_check.sh --reviewed-night-20261028-with-start-atomic | tee "$LOG_DIR/parity.log"
  [[ ${PIPESTATUS[0]} -eq 0 ]] || STATUS=1
elif [[ "${E2E_REVIEWED_NIGHT:-0}" == "1" ]]; then
  /bin/bash tool/local_supabase/parity_check.sh --reviewed-night-20261028 | tee "$LOG_DIR/parity.log"
  [[ ${PIPESTATUS[0]} -eq 0 ]] || STATUS=1
fi
exit "$STATUS"
