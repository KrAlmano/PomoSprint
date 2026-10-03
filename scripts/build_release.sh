#!/usr/bin/env bash
# PomoSprint mağaza derlemesi: Dart kodu --obfuscate ile karıştırılır, hata
# ayıklama sembolleri --split-debug-info ile ayrılır ve Sentry'ye yüklenir.
#
# Kullanım (repo kökünden):
#   scripts/build_release.sh android   # build/app/outputs/bundle/release/app-release.aab
#   scripts/build_release.sh ios       # build/ios/ipa/*.ipa
#   scripts/build_release.sh all
#
# Gerekenler:
#   - Kök .env dolu (SUPABASE_URL, SUPABASE_ANON_KEY, SENTRY_DSN). Bu betik
#     içeriğini okumaz, yalnızca boş olmadığını kontrol eder.
#   - Android: android/key.properties + upload keystore (yoksa bundleRelease durur).
#   - Sentry yüklemesi için scripts/.env'de SENTRY_AUTH_TOKEN, SENTRY_ORG,
#     SENTRY_PROJECT (şablon: scripts/.env.example). Bu dosyadan yalnızca
#     SENTRY_* satırları okunur; token repoya ve pubspec.yaml'a yazılmaz.
#     Eksikse derleme yapılır, yükleme atlanır. Yükleme hatası derlemeyi
#     durdurmaz; semboller yerelde kalır, aynı komutla sonra yüklenebilir.
#
# Ne yüklenir:
#   - Dart sembolleri (*.symbols) ve obfuscation haritası: sentry_dart_plugin.
#   - iOS dSYM'leri: sentry_dart_plugin build/ altında bulur.
#   - Android R8 mapping.txt (eklentilerin Java/Kotlin kodu): sentry-cli
#     upload-proguard. Eşleşme için derlemeden önce bir UUID üretilir ve
#     android/app/src/main/assets/sentry-debug-meta.properties'e yazılır
#     (sentry-android açılışta okur); derlemeden sonra dosya silinir.
#     libflutter.so / libapp.so native sembol tabloları AAB'ye girer
#     (build.gradle.kts ndk.debugSymbolLevel); Play Console bunları kullanır.
#
# Semboller release_symbols/<sürüm>/<platform>/ altında kalır (git'e girmez).
# Her mağaza sürümü için saklayın; Sentry'siz çözümleme:
#   flutter symbolize -i <stack.txt> -d release_symbols/<sürüm>/android/app.android-arm64.symbols
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PLATFORM="${1:-}"
case "$PLATFORM" in
  android | ios | all) ;;
  *)
    echo "Kullanım: $0 android|ios|all" >&2
    exit 64
    ;;
esac

if [ ! -s .env ]; then
  echo "HATA: kök .env yok ya da boş; release derlemesi bulutsuz açılır. README > Kurulum." >&2
  exit 1
fi

# scripts/.env'den yalnızca SENTRY_* anahtarları (diğer sırlar derlemeye taşınmaz).
if [ -f scripts/.env ]; then
  while IFS='=' read -r key value; do
    case "$key" in
      SENTRY_AUTH_TOKEN | SENTRY_ORG | SENTRY_PROJECT | SENTRY_URL)
        value="${value%\"}"
        value="${value#\"}"
        if [ -n "$value" ]; then export "$key=$value"; fi
        ;;
    esac
  done < <(grep -E '^SENTRY_[A-Z_]+=' scripts/.env || true)
fi

VERSION="$(grep -E '^version:' pubspec.yaml | head -n1 | awk '{print $2}')"
if [ -z "$VERSION" ] || [[ "$VERSION" != *+* ]]; then
  echo "HATA: pubspec.yaml 'version' <sürüm>+<derleme numarası> biçiminde olmalı (ör. 1.0.0+1)." >&2
  exit 1
fi
BUILD_NUMBER="${VERSION##*+}"
# sentry_flutter'ın varsayılan release adıyla aynı: <paket adı>@<sürüm>+<derleme>.
# Android applicationId ve iOS bundle id ikisi de com.pomosprint.app.
RELEASE="com.pomosprint.app@${VERSION}"
SYMBOLS_ROOT="$ROOT/release_symbols/$VERSION"

ASSETS_DIR="$ROOT/android/app/src/main/assets"
DEBUG_META="$ASSETS_DIR/sentry-debug-meta.properties"
R8_MAPPING="$ROOT/build/app/outputs/mapping/release/mapping.txt"

cleanup() {
  rm -f "$DEBUG_META"
  rmdir "$ASSETS_DIR" 2>/dev/null || true
}
trap cleanup EXIT

can_upload() {
  [ -n "${SENTRY_AUTH_TOKEN:-}" ] && [ -n "${SENTRY_ORG:-}" ] && [ -n "${SENTRY_PROJECT:-}" ]
}

# sentry_dart_plugin sentry-cli'yi .dart_tool altına indirir; PATH'teki
# sentry-cli varsa o kullanılır.
sentry_cli() {
  if command -v sentry-cli >/dev/null 2>&1; then
    echo "sentry-cli"
  elif [ -x "$ROOT/.dart_tool/pub/bin/sentry_dart_plugin/sentry-cli" ]; then
    echo "$ROOT/.dart_tool/pub/bin/sentry_dart_plugin/sentry-cli"
  fi
}

upload_symbols() {
  local platform="$1"
  local dir="$SYMBOLS_ROOT/$platform"
  if ! can_upload; then
    echo "UYARI: SENTRY_AUTH_TOKEN / SENTRY_ORG / SENTRY_PROJECT eksik; $platform sembolleri yüklenmedi." >&2
    echo "       Semboller: $dir" >&2
    return 0
  fi
  echo "==> Sentry: $platform Dart sembolleri ve obfuscation haritası ($RELEASE)"
  if ! dart run sentry_dart_plugin \
    "--sentry-define=release=$RELEASE" \
    "--sentry-define=dist=$BUILD_NUMBER" \
    "--sentry-define=symbols_path=$dir" \
    "--sentry-define=dart_symbol_map_path=$dir/app.obfuscation.map.json"; then
    echo "UYARI: $platform sembolleri Sentry'ye yüklenemedi; dosyalar $dir altında." >&2
  fi

  if [ "$platform" = android ] && [ -f "$dir/mapping.txt" ]; then
    local cli
    cli="$(sentry_cli)"
    if [ -z "$cli" ]; then
      echo "UYARI: sentry-cli bulunamadı; R8 mapping yüklenmedi ($dir/mapping.txt)." >&2
      return 0
    fi
    echo "==> Sentry: Android R8 mapping (UUID $(cat "$dir/proguard_uuid.txt"))"
    if ! "$cli" upload-proguard --uuid "$(cat "$dir/proguard_uuid.txt")" "$dir/mapping.txt"; then
      echo "UYARI: R8 mapping Sentry'ye yüklenemedi; dosya $dir/mapping.txt." >&2
    fi
  fi
}

build_platform() {
  local platform="$1"
  local dir="$SYMBOLS_ROOT/$platform"
  rm -rf "$dir"
  mkdir -p "$dir"
  local flags=(
    --release
    --obfuscate
    "--split-debug-info=$dir"
    "--extra-gen-snapshot-options=--save-obfuscation-map=$dir/app.obfuscation.map.json"
  )
  echo "==> $platform derleniyor ($VERSION)"
  if [ "$platform" = android ]; then
    local proguard_uuid
    proguard_uuid="$(uuidgen | tr '[:upper:]' '[:lower:]')"
    mkdir -p "$ASSETS_DIR"
    printf 'io.sentry.ProguardUuids=%s\n' "$proguard_uuid" >"$DEBUG_META"
    flutter build appbundle "${flags[@]}"
    cleanup
    if [ -f "$R8_MAPPING" ]; then
      cp "$R8_MAPPING" "$dir/mapping.txt"
      echo "$proguard_uuid" >"$dir/proguard_uuid.txt"
    else
      echo "UYARI: R8 mapping.txt yok ($R8_MAPPING); Java/Kotlin yığınları çözülmez." >&2
    fi
  else
    flutter build ipa "${flags[@]}"
  fi
  upload_symbols "$platform"
}

# Temiz derleme: sentry_dart_plugin build/ altındaki her dSYM'i bulur; önceki
# bir iOS derlemesinin dSYM'i Android haritasıyla eşleşmesin.
flutter clean
flutter pub get

if [ "$PLATFORM" = android ] || [ "$PLATFORM" = all ]; then
  build_platform android
fi
if [ "$PLATFORM" = ios ] || [ "$PLATFORM" = all ]; then
  build_platform ios
fi

echo "==> Bitti. Semboller: $SYMBOLS_ROOT"
