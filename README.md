# PomoSprint

PomoSprint, Android ve iOS için oyunlaştırılmış bir Pomodoro uygulamasıdır. 25/50 dakikalık odak seansları, 2/3/4 seanslık Maraton, kategoriler, raporlar, seri, lig, avatar ve arkadaş özellikleri sunar. Puan, kum ve lig işlemlerini Supabase hesaplar; istemci sonucu gösterir.

**Son durum — 9 Ekim 2026:** Ronin kaldırıldı; kalan 21 özel avatarın her biri 500 kum. Kartların görsel ve ad hizası düzeltildi. Canlı SQL kullanıcı tarafından uygulandı; 20/20 salt okuma kontrolü geçti. Mevcut 4 hesap, 9 seans ve ekonomi verileri korundu. Flutter testlerinde 1291 PASS var; isteğe bağlı 5 ekran görüntüsü testi atlandı. Analiz temiz. Eski hızlı QA/demo/gece araçları, ham test verileri ve kullanılmayan platform şablonları temizlendi. Tüm simülatörler ve yerel Docker test veri hacimleri silindi; açık uygulama yok. [Güncel QA](analiz/QA_RELEASE_CLEANUP_2026-10-09.md), [devir §37](PROJE_DEVIR.md).

## Ürün davranışı

- Ana ekrandaki **Maratonu başlat** düğmesi planlama penceresini açar. 2/3/4 seans ve 25/50 dakikalık süre seçilir; normal BAŞLAT düğmesi tek seans başlatır. Odak seansları arasında 5 dakika mola vardır. Ardından en fazla 1 dakika içinde **Buradayım** onayı gerekir. Tamamlanan odak seansları korunur. Geçerli planın tamamı bitirilirse 25 dk için +2/+3/+5, 50 dk için +4/+6/+10 bonus bir kez verilir.
- Sosyal ekran tek listedir: normal seans veya Maraton odağı **Odaklanıyor**, yalnız Maraton molası **Molada** olarak görünür. Ekran görünürken durum 30 saniyede bir yenilenir; sunucudan anlık push gelmez.
- Raporlar günlük, haftalık ve aylık seansları ve kategorileri gösterir. Çalışma günü, profilin IANA saat diliminde 04:00 sınırını kullanır.
- Ligler Bronz/Gümüş/Altın/Safir/Elmas olarak adlandırılır; bir oda en fazla 25 gerçek kullanıcı içerir. Kullanıcı ilk puanlı seansıyla odaya yerleşir. Hazırlık sonrasında aktiflik ve yeterlilik koşullarına bağlı 14 günlük yarış uygulanır; [lig kuralları](AGENTS.md#64-lig-döngüsü--güncel-8-ekim-paketi).
- Kayıt/onboarding yalnız 7 aktif ücretsiz temel avatarı gösterir. **Özel Avatarlar / Special Avatars** koleksiyonundaki 21 avatarın her biri 500 kumdur; bu avatarlar kayıt seçimine dahil değildir. Lig ödülü avatarları satın alınamaz.
- Türkçe/İngilizce ve sistem/açık/koyu tema desteklenir. Yatay Pomo’da animasyon, sayaç, duraklatma hakkı ve uygun seans kontrolleri görünür; kahve yalnız Maraton molasındadır.

## Kurulum ve çalıştırma

Proje kökü bu Mac’te `/Users/almano/Desktop/Projects/Pomodoro`.
Flutter/Dart, Android SDK veya Xcode gerekir. Ürün platformları yalnız `android/` ve `ios/`; site `landing/` altındadır.

```sh
flutter pub get
flutter gen-l10n
flutter devices
flutter run -d <güncel-cihaz-id> -t lib/main.dart
```

Kök `.env`, istemciye açık Supabase URL/anon ve isteğe bağlı Sentry DSN içindir; `.env.example` şablondur. Service-role/Resend/management sırlarını mobil asset’e koyma. Normal çalıştırma mevcut `.env` ile canlı Supabase’e bağlanır; yerel ortam seçimi URL ve anon define’ları birlikte verilerek yapılır. [İzolasyon rehberi](tool/local_supabase/README.md).

**Sayaç tüm normal derlemelerde gerçek 25/50 dakikadır.** Eski QUICK/SAVE define’ları ve demo profilleri kaldırılmıştır. Açıkça verilen hızlı widget simülasyonu yalnız regresyon testlerindedir; QA RPC ile kısa kayıt yapılmaz. Eski hızlandırılmış kalıcı kayıtlar güvenli biçimde reddedilir; gerçek seanslar korunur.

Şu anda kurulu simülatör/runtime yok. Önceki BEA/HMV UUID’leri geçersizdir. Kullanıcı istediğinde tek yeni cihaz kurup `flutter devices` ile güncel ID seçilmeli. Xcode SDK ve simülatör runtime ayrı bileşenlerdir; eski hedef hatası için eski UUID kullanmak çözüm değildir.

## Kontroller

```sh
flutter analyze
flutter test --concurrency=2
```

İsteğe bağlı beş ekran görüntüsü senaryosu için `--dart-define=SCREENSHOTS=true` kullanılabilir. Çalışma günü değişirse New York saat diliminde ilgili rapor/stats testlerini de çalıştır. Kalıcı birim/widget ve SQL regresyonları korunur; uygulama paketine dahil değildir. Yeni test hesabı ve native test koşusu yalnız izole yerel backend’de yapılır; [yerel rehber](tool/local_supabase/README.md).

Site/Edge betikleri değişirse `cd scripts && npm test`; HTML parçaları değişirse `python3 landing/tools/sync_partials.py --check`. Canlı Auth hesabı açıp silebilen `scripts/security_regression_test.js` ayrı yetkilendirme gerektirir.

## Mağaza ve backend

`scripts/build_release.sh android|ios|all` mağaza derlemesi, obfuscation ve sembol işlemleri içindir. Android upload keystore ve iOS Apple takım/provisioning ayarları gerekir. Sentry sırları `scripts/.env` ve ortam değişkenlerinde tutulur. Release derlemek, mağazaya yükleme veya fiziksel cihaz testini tamamlamaz.

Kök migration geçmişi canlıyla birebir değildir: **kör `supabase db push/reset` yapma.** Yeni SQL şu akışı izler: güncel canlı tanım → izole test → DRYRUN → kullanıcının SQL Editor’de uygulaması → salt okuma doğrulaması. [Supabase rehberi](supabase/README.md).

Temizlik uygulamanın tüm yayın koşullarını tamamlamaz. §33 operasyonel güvenlik eksikleri, gerçek Google/Apple sağlayıcı ve fiziksel cihaz testleri, Apple imzalama/mağaza beyanları, yasal kimlik/gönderen bilgileri halen ayrı işlerdir. [Operasyonel QA](analiz/QA_OPERATIONAL_CONTROLS_2026-10-08.md), [mağaza kontrol listesi](analiz/magaza_uyum_kontrol_listesi_2026-10-03.md).

## Belgeler ve klasörler

| Yol | İçerik |
|---|---|
| [AGENTS.md](AGENTS.md) | Çalışma kuralları, canlı RPC sözleşmeleri ve alan haritası |
| [PROJE_DEVIR.md](PROJE_DEVIR.md) | Mimari, tarihli çalışmalar ve yeni oturumun devam noktası |
| [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) | Kısa güncel ürün/mimari özeti |
| [Temizlik QA](analiz/QA_RELEASE_CLEANUP_2026-10-09.md) | Ronin/hizalama, gerçek test sonuçları, veri koruması ve temizlenenler |
| `lib/`, `assets/` | Mobil ürün ve aktif görseller |
| `test/`, `integration_test/` | Korunan anlamlı regresyon kaynakları |
| `supabase/`, `tool/local_supabase/` | SQL/Edge kaynakları ve izole test altyapısı |
| [landing/README.md](landing/README.md) | `pomosprint.app` site geliştirme/yayın rehberi |
| `scripts/` | Mağaza derlemesi, bülten ve Node testleri |
| `analiz/` | İnsan tarafından okunabilir tarihli QA, operasyon ve pazarlama raporları |

Eski ham fixture, ekran görüntüsü, JSONL ve loglar kullanıcı talebiyle silindi; geçmiş rapor sonuçları korunur. Orijinal Stitch ve kullanılmayan lig tasarımları `/Users/almano/Desktop/PomoSprint-Tasarim-Arsivi` içinde arşivlendi. `.env`, imzalama, `.git`, gerçek hesaplar ve aktif site medyası korundu. Bu çalışmada commit/push veya site yayını yapılmadı.
