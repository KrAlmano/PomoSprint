# PomoSprint

Pomodoro tekniğini oyunlaştıran Flutter çalışma uygulaması: 25/50 dakikalık odak seansları, ders kategorileri, raporlar, seri bonusu, **14 günlük** ligler, avatarlar ve arkadaşlar. Backend Supabase (Postgres, Auth, RPC'ler, Edge Functions); site `pomosprint.app`.

| Belge | İçerik |
|---|---|
| [AGENTS.md](AGENTS.md) | Ayrıntılı ve güncel geliştirici / AI rehberi (sözleşmeler, kurallar, açık konular) |
| [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) | Kısa ürün ve mimari özeti |
| [supabase/README.md](supabase/README.md) | Canlı veritabanı durumu ve migration akışı |
| [landing/README.md](landing/README.md) | Site kuralları |

## Desteklenen platformlar

| Platform | Durum |
|---|---|
| Android | Destekleniyor (`com.pomosprint.app`) |
| iOS | Destekleniyor (min. iOS 15.0, `com.pomosprint.app`) |
| macOS, Linux, Windows, Web | `flutter create` şablonları; **çalışmıyor**, bakımı yapılmıyor |

## Kurulum

1. Flutter 3.44+ (Dart ^3.12) kurulu olmalı.
2. Kök dizinde `.env` oluştur. Anahtarlar:

   | Anahtar | Zorunlu | Not |
   |---|---|---|
   | `SUPABASE_URL` | Evet | Yoksa uygulama bulutsuz (yalnızca yerel) açılır |
   | `SUPABASE_ANON_KEY` | Evet | Public anon key |
   | `SENTRY_DSN` | Hayır | Boşsa Sentry kapalı |

   Bu dosya APK/IPA içine düz metin gömülür. **Service role veya Resend anahtarı koyma.** Onlar yalnızca `scripts/.env`'de durur (şablon: `scripts/.env.example`; anahtarlar `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API_KEY`).
3. Komutlar:

   ```bash
   flutter pub get
   flutter gen-l10n        # lib/l10n/*.arb değiştiyse
   flutter run             # debug: sayaç 5/10 sn, sunucu bu seansları reddeder
   flutter run --profile   # gerçek seans ve puan testi
   ```

4. Android release AAB için `android/key.properties` ve upload keystore gerekir. Yoksa `bundleRelease` bilerek hata verir; release APK ise uyarıyla debug anahtarıyla imzalanır.

## Mağaza derlemesi

```bash
scripts/build_release.sh android   # AAB: build/app/outputs/bundle/release/
scripts/build_release.sh ios       # IPA: build/ios/ipa/
scripts/build_release.sh all
```

- Betik `flutter clean` yapar, `--obfuscate --split-debug-info` ile derler. Dart sembolleri, obfuscation haritası ve Android R8 `mapping.txt` `release_symbols/<sürüm>/<platform>/` altına yazılır (git'e girmez). Her mağaza sürümü için saklayın.
- Sentry'ye yükleme için `scripts/.env`'e `SENTRY_ORG`, `SENTRY_PROJECT`, `SENTRY_AUTH_TOKEN` ekleyin (şablon: `scripts/.env.example`). Betik bu dosyadan yalnızca `SENTRY_*` satırlarını okur. Token repoya ve `pubspec.yaml`'a yazılmaz. Eksikse derleme yapılır, yükleme atlanır.
- Yüklenenler: Dart sembolleri ve obfuscation haritası (`sentry_dart_plugin`), iOS dSYM'leri, Android R8 mapping (`sentry-cli upload-proguard`; eşleşme UUID'si derleme sırasında `android/app/src/main/assets/sentry-debug-meta.properties`'e yazılır, sonra silinir). Native sembol tabloları AAB'ye girer (`ndk.debugSymbolLevel`), Play Console kullanır.
- Release adı `com.pomosprint.app@<pubspec version>`, dist derleme numarası; `sentry_flutter`'ın varsayılanıyla aynı.
- Sentry'siz çözümleme: `flutter symbolize -i <stack.txt> -d release_symbols/<sürüm>/android/app.android-arm64.symbols`.
- Android derlemesi ve R8 mapping eşleşmesi bu makinede doğrulanmadı (Android SDK yok). İlk Android sürümünde Sentry'de bir Java yığınının çözüldüğünü kontrol edin.

## Kontrol ve testler

```bash
flutter analyze   # beklenen: No issues found!
flutter test      # test/ altındaki 8 birim test dosyası
```

- Yeni metinler `lib/l10n/app_tr.arb` ve `app_en.arb` dosyalarına eklenir, ardından `flutter gen-l10n`. `app_localizations*.dart` elle düzenlenmez.
- SQL davranış testleri (yalnızca yerel, tek kullanımlık Postgres): `supabase/tests/run_local.sh`.
- Canlı projeye karşı regresyon testi gerçek test hesapları açıp siler: `cd scripts && npm install && node security_regression_test.js`. Yalnızca bilerek çalıştır.

## Klasörler

| Klasör | İçerik |
|---|---|
| `lib/app/` | Açılış sonrası kabuk: yönlendirme kapısı (`app_gate`), ana sekmeler (`main_shell`), tema, Sentry |
| `lib/screens/` | Ekranlar |
| `lib/services/` | Supabase veri katmanı, çevrimdışı seans kuyruğu, süren seans kaydı, bildirim, dil |
| `lib/models/`, `lib/utils/`, `lib/widgets/` | Modeller, yardımcılar (çalışma günü, istatistik), ortak widget'lar |
| `lib/l10n/` | ARB çevirileri ve üretilen yerelleştirme kodu |
| `test/` | Birim testleri |
| `supabase/migrations/` | İleri migration'lar (yalnızca `20261003150000_live_audit_fixes` canlıda) |
| `supabase/rollbacks/`, `supabase/proposed/` | Geri alma betikleri; canlıya uygulanmamış öneriler |
| `supabase/functions/` | Edge Functions: `unsubscribe`, `send-welcome-email` |
| `supabase/tests/` | Yerel SQL testleri ve canlı DRYRUN betikleri |
| `scripts/` | Güvenlik regresyon testi, bülten gönderimi (Node) |
| `landing/` | Tanıtım sitesi (pomosprint.app) |
| `android/`, `ios/` | Platform yapılandırması |
| `analiz/` | Denetim raporları |

## Supabase akışı

Canlı veritabanı (`eoosnyakvxmifmexpgxa`) gerçeğin kaynağıdır ve repodaki eski migration'larla eşleşmez. **`supabase db push` / `db reset` çalıştırma.** Değişiklik akışı (canlı tanımı oku → migration + rollback + DRYRUN → önce DRYRUN, sonra migration, SQL Editor'de) ve baseline adımları: [supabase/README.md](supabase/README.md).

Edge Function'lar JWT doğrulaması kapalı deploy edilir:

```bash
supabase functions deploy unsubscribe --no-verify-jwt
supabase functions deploy send-welcome-email --no-verify-jwt
```

## Landing deploy

```bash
cd landing
python3 tools/sync_partials.py --check   # fark varsa önce: python3 tools/sync_partials.py
wrangler deploy
```

Statik site, derleme adımı yok. `worker.js` http → https ve www → apex yönlendirmesini yapar; güvenlik başlıkları `_headers`'ta. Kurallar: [landing/README.md](landing/README.md).

## Lig

- Dönem **14 gün**; Pazartesi 00:01 (TR) civarında çalışan cron dönemi biten ligleri işler.
- 5 kademe (Bronz, Gümüş, Altın, Safir, Elmas), odada en fazla 30 kişi.
- Dönem sonunda puanı olan üst sıralar terfi eder, alt sıralar düşer; ilk 3'e ödül avatarı verilir.
