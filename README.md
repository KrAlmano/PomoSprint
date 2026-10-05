# PomoSprint

PomoSprint, oyunlaştırılmış bir çalışma sayacıdır. Android ve iOS'ta 25 veya 50 dakikalık odak seansı; ders kategorileri, raporlar, çalışma serisi, puan/kum, ligler, avatarlar ve arkadaş özellikleri sunar. Seansın otoritatif kaydı, puanı, kumu, serisi ve lig etkisi Supabase sunucusunda hesaplanır.

## Proje belgeleri

| Belge | İçerik |
|---|---|
| [PROJE_DEVIR.md](PROJE_DEVIR.md) | Yapay zekâya ve geliştiriciye tam devir: mimari, yerel kurulum, modlar, QA sonuçları ve sonraki işler |
| [AGENTS.md](AGENTS.md) | Günlük kodlama kuralları, dosya haritası ve istemci–Supabase RPC sözleşmeleri |
| [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) | Kısa ürün/mimari özeti |
| [QA takip raporu](analiz/QA_FOLLOWUP_2026-10-05.txt) | En yeni saat dilimi, arkadaş ve yasal onay kontrolleri |
| [Kapsamlı QA raporu](analiz/QA_FULL_2026-10-05.txt) | Önceki çok hesaplı iOS/Android simülatör/emülatör denetimi |
| [Yerel Supabase](tool/local_supabase/README.md) | İzole backend, test hesapları, kısa seans kaydı ve E2E komutları |
| [Supabase işlemleri](supabase/README.md) | Canlı veritabanı geçmişi ve güvenli SQL değişikliği akışı |
| [Site rehberi](landing/README.md) | `pomosprint.app` geliştirme ve deploy kuralları |

## Platformlar ve teknoloji

| Platform | Durum |
|---|---|
| Android | Ürün platformu, `com.pomosprint.app`; Android 16 ARM64 emülatörde UI E2E ve release APK derlendi. Fiziksel Android testi bekliyor |
| iOS | Ürün platformu, minimum iOS 15.0, `com.pomosprint.app`; iPhone 16 Plus / iOS 18.6 simülatörü test edildi. Release derlemesi imzasızdı |
| macOS, Linux, Windows, Web | `flutter create` kalıntısı; desteklenen ürün platformları değil |

Flutter 3.44 / Dart `^3.12.2`. Backend, Supabase Auth + PostgreSQL + RLS + RPC + cron + Edge Functions. Site, Cloudflare Workers static assets. Gerçek paket sürümleri `pubspec.lock` içindedir.

## Kurulum ve çalıştırma

1. Flutter/Dart kur ve depo kökünde bağımlılıkları al:

   ```sh
   flutter pub get
   ```

2. Canlı backend ile normal geliştirme için `.env` oluştur. Yalnızca istemciye açık `SUPABASE_URL`, `SUPABASE_ANON_KEY` ve isteğe bağlı `SENTRY_DSN` koy. `.env` uygulama paketine düz metin asset olarak girer: **service role, Resend, Apple private key veya başka sır ekleme.** `scripts/.env` ve Supabase Edge secrets ayrı yönetilir.

3. Normal uygulama 25/50 dakikalık seans kullanır:

   ```sh
   flutter run
   ```

4. Yerel Supabase'e bağlanmak için önce Docker ve `supabase start --workdir tool/local_supabase` çalıştır. Uygulamada URL ve anon key'i birlikte `--dart-define` ile ver; ayrıntılı hazır komutlar [yerel test rehberinde](tool/local_supabase/README.md).

### Hızlı sayaç modları

- `QUICK_TIMER=true`: 25/50 dakikayı 5/10 saniyeye indirir, TEST rozeti gösterir ve seansı **kaydetmez**.
- Yerel rapor/puan akışını kısa sürede doğrulamak için ayrıca `QUICK_TIMER_SAVE=true`, debug derleme ve yalnızca yerel HTTP Supabase adresi gerekir. Bu özel mod 5/10 saniyeyi 25/50 dakika olarak yalnızca **yerel** `complete_qa_study_session` RPC'sine yazar.
- Canlı `complete_study_session` davranışı değiştirilmedi. İzin koşulları ve yerel RPC kurulumu: [PROJE_DEVIR.md §7](PROJE_DEVIR.md#7-normal-ve-qa-çalışma-modları--karıştırma) ve [tool/local_supabase/README.md](tool/local_supabase/README.md).

ARB çevirileri değişince `flutter gen-l10n` çalıştır; üretilen `app_localizations*.dart` dosyalarını elle düzenleme.

## Testler

```sh
flutter analyze
flutter test --concurrency=2
```

Rapor/çalışma günü değişikliklerinde New York DST doğrulaması:

```sh
TZ=America/New_York flutter test \
  test/reports_correctness_test.dart test/reports_findings_test.dart \
  test/stats_calculator_test.dart test/study_day_test.dart --concurrency=2
```

Gerçek backend ve uygulama UI'siyle testler yalnızca izole yerel Supabase'te çalışır. Simülatör/emülatör senaryoları, Android'e özel bildirim testi ve iOS native testi için [yerel E2E senaryolarına](tool/local_supabase/README.md#simülatörde-uçtan-uca-test) bak. Son kaydedilmiş sonuç (5 Ekim 2026): Flutter analizi temiz; tüm birim/widget paketinde 1068 test geçti, 5 isteğe bağlı screenshot testi atlandı; takip turunda iOS ve Android UI senaryoları ile iki release derlemesi geçti. Bu, fiziksel cihaz, gerçek Google/Apple girişi veya mağaza yayın onayı anlamına gelmez. Tam kapsam ve sınırlar raporlarda.

Site JS/Edge testleri `cd scripts && npm test`. Ortak HTML parçası değişince `python3 landing/tools/sync_partials.py --check`. Canlı hesap açıp silebilen `scripts/security_regression_test.js`'i yerel Flutter testleriyle karıştırma; kapsamı [AGENTS.md](AGENTS.md)'de oku.

## Mağaza derlemesi

```sh
scripts/build_release.sh android   # imzalı AAB: upload keystore gerekir
scripts/build_release.sh ios       # IPA: Apple imzalama ayarları gerekir
scripts/build_release.sh all
```

Bu betik obfuscation ve `--split-debug-info` kullanır; Sentry sembol upload ayarları `scripts/.env`'den alınır. QA sırasında alınan düz release build'leri mağaza paketi veya imzalı dağıtım değildir. Keystore/Sentry gereksinimleri: [`scripts/build_release.sh`](scripts/build_release.sh) üstbilgisi.

## Supabase güvenliği

Canlı proje `Pomodoro App` (`eoosnyakvxmifmexpgxa`, `eu-north-1`). Canlı gövde ve katalog sözleşmesi gerçektir; kök `supabase/migrations/` canlı migration geçmişinin kopyası değildir. **Kökte `supabase db push` veya `db reset` çalıştırma.** SQL değişikliği için canlı tanımı okuyup migration + down + geri alınan DRYRUN hazırla; sırayı ve ayrıntıyı [supabase/README.md](supabase/README.md) ve [AGENTS.md](AGENTS.md) §2'den izle.

5 Ekim 2026 tarihli proje kaydına göre 12, 15, 16, 19 A, 13, 14 ve 20–26 paketleri canlıya uygulanıp doğrulandı; 19 B uygulanmadı. Canlıya dair yeni bir işlemden önce tarihli repo bilgisini yeniden salt okunur doğrula. Bu belgede canlıya yeni bağlantı yapıldığı iddia edilmiyor.

## Repo haritası

| Yol | Rol |
|---|---|
| `lib/app/`, `lib/screens/`, `lib/widgets/` | Yönlendirme/kabuk, ürün ekranları ve UI parçaları |
| `lib/services/`, `lib/models/`, `lib/utils/` | Veri servisi, kalıcı seans/outbox, domain modelleri ve hesaplamalar |
| `lib/l10n/` | TR/EN ARB ve üretilen çeviri kodu |
| `test/`, `integration_test/` | Birim/widget ve gerçek yerel backend E2E |
| `android/`, `ios/` | Native bildirim, kanal ve platform ayarları |
| `supabase/` | SQL tarihçesi, güncel paket notları, Edge Functions ve e-posta şablonları |
| `tool/local_supabase/` | Canlıya bağlanmayan yerel Docker backend ve test araçları |
| `scripts/` | JS testleri, e-posta aracı ve mağaza derleme betiği |
| `landing/` | `pomosprint.app` kaynakları |
| `analiz/` | Tarihli QA raporları, loglar ve simülatör ekranları |

## Site

Site build gerektirmez. Ortak `_partials/` kaynağını değiştirince sayfalara eşitle:

```sh
python3 landing/tools/sync_partials.py --check
cd landing && wrangler deploy
```

Yayın öncesi KVKK veri sorumlusu gerçek bilgisi ve ileti/SMTP tercihlerini, [site rehberindeki](landing/README.md) kontrollerle doğrula. İmzalı uygulama veya site deploy'u bu README güncellemesinin parçası değildir.
