# PomoSprint

PomoSprint, Android ve iOS için odaklanma ve sınava hazırlık uygulamasıdır. Gerçek 25/50 dakikalık Pomodoro, 2/3/4 seanslık Maraton, Deneme, raporlar, ligler, avatarlar ve arkadaş durumlarını birleştirir. Süreye bağlı puan, kum ve lig sonuçlarını Supabase hesaplar; istemci ödül üretmez.

**Güncel gece durumu — 28 Ekim 2026:** Deneme/TUS, birleşik çalışma raporları, TR/EN karşılama ve aylık lig çalışmaları `codex/gece-2026-10-27` dalındadır. Son kayıtlı adımlar: `b37899e` eksik geçmiş/içgörü, `01bf20f` native sürücüler, `f2c6a7d` site özel avatarları. **Yeni SQL ve site değişiklikleri canlıya uygulanmadı; push/deploy yapılmadı.** Root'un son `full32` kapısı: analyze temiz, **1416 Flutter testi geçti / 5 isteğe bağlı ekran üretimi atlandı**; **158 Node testi geçti**. Bu, bitmemiş native koşuların geçtiği anlamına gelmez. Güncel ayrıntılar [ilerleme kaydı](analiz/CODEX_ILERLEME.md), [istek listesi](analiz/ISTEKLER.md) ve [§39 devir bölümündedir](PROJE_DEVIR.md#39-2728-ekim-2026--yerel-deneme-tus-ve-aylık-lig-devri); eski tarihli raporlar tarihsel kanıttır.

| Native kontrol | Bu kontrol anındaki durum |
|---|---|
| iOS 18.6 gerçek 25 dakika | Final geçti: tek seans/lig olayı, 5 normal puan, 20 kum, 1 günlük seri; kaynak zamanları korundu. |
| iOS 27 TUS 135 | Ara yeniden açılış geçti; **02:03 İstanbul civarı final bekleniyor**, tamamlama/ödül henüz doğrulanmış sayılmaz. |
| Android | q/j/t/o1/o2 geçti; gerçek 25 dakikalık Maraton varyantı **devam ediyor**. |
| w gerçek 25 + HTTP503/restart | **00:27:23'te başladı**, doğal bitiş hedefi **00:52:23 İstanbul**; outbox/restart/senkron finali henüz PASS değil. |
| Site videosu | İlk gerçek çekim ve encoder doğrulandı; istenmeyen test crosshair'i nedeniyle yayın adayı değil. Temiz pointer helper'ı hazır; ikinci çekim w sonrasını bekliyor. |

## Ürün davranışı

- **Pomodoro:** 25 veya 50 dakika, bir duraklatma hakkı. Normal derlemelerde hızlı test modu yoktur.
- **Maraton:** 2/3/4 odak seansı; arada 5 dakika mola, ardından en fazla 1 dakika içinde ön planda **Buradayım** ve sunucu onayı. Erken ayrılınca tamamlanmış odaklar korunur. Tam plan bonusu 25 dk için +2/+3/+5, 50 dk için +4/+6/+10; yalnız sunucu bir kez verir.
- **Deneme:** TYT, AYT, YDT, LGS Sözel/Sayısal ve TUS Temel/Klinik. Sunucu onaylı başlangıç, gerçek sınav süresi, duraklatmasız sayaç; kapanma/arka plan süreyi durdurmaz. Sonuçlar sonradan ders bazında doğru/yanlış/boş olarak girilir. Netler kişiseldir; puan/kum/lig kazancını değiştirmez. [Resmî soru, süre ve net kaynakları](analiz/SINAV_KAYNAKLARI_2026-10-28.md).
- **Raporlar:** Pomodoro + Maraton + tamamlanmış deneme süreleri birlikte; deneme ayrıntıları ve süre–net karşılaştırmaları ayrı. Deneme süresi derslere dağıtılmaz. Vazgeçilen deneme geçmişte kalır, tamamlama ödülü veya toplam çalışma süresi kazanmaz. Raporların çalışma günü sınırı profil saat diliminde **04:00**'tır.
- **Ligler:** Yeni paket normal ve deneme ekonomisini ayırır; hedef kategorisi ve global görünüm sunar. Lig ayı **Europe/Istanbul ayın 1'i 00:00**'da döner; çalışma günü 04:00 ile karıştırılmaz. Oda kapasitesi en fazla 25, ilk puanlı aktivitede yerleşme. Ay ortası hedef değişimi sonraki ayda etkili olur. Yeni aylık şema canlıya uygulanana kadar eski sunucunun lig davranışı sürer; [geçiş/ödül kuralları](supabase/proposed/NIGHT_20261028_README.md).
- **Sosyal:** Odaklanıyor, yalnız Maraton molasında Molada, yeni Deneme sunucusunda Denemede. Görünür ekranda 30 saniyelik sorgulama; anlık push değildir. Gizlilik/engelleme filtreleri korunur.
- **Avatar/dil:** Kayıtta 7 ücretsiz avatar; 21 özel avatarın her biri 500 kum. Lig ödülleri satın alınmaz. Yeni deneme ligine gerçek görseller gelmeden hayalî ödül eklenmez. TR/EN; sistem/açık/koyu tema. Kayıt sonrası dil seçimi ve özellik rehberi vardır; yaş adımı ile 13 altı engeli korunur.

Deneme RPC'leri eski sunucuda yoksa özellik güvenli hazırlık durumunda kalır. Ağ/yetki hatası başarı gibi gösterilmez. Normal Pomodoro/Maraton çalışması yeni deneme şemasına bağlanmaz.

## Kurulum ve çalıştırma

Bu Mac'teki aktif proje kökü `/Users/almano/Desktop/Projects/Pomodoro`. `/Users/almano/Desktop/Courses/Projects/Pomodoro` ayrı bir kopyadır; bu gecenin devamı için kullanılmaz. Flutter/Dart ile Android SDK veya Xcode gerekir. Mobil ürün `android/` ve `ios/`; statik site `landing/` altındadır.

```sh
flutter pub get
flutter gen-l10n
flutter devices
flutter run -d <güncel-cihaz-id> -t lib/main.dart
```

Eski cihaz UUID'sini kullanma; `flutter devices` ile güncel cihazı seç. Xcode SDK ile simülatör runtime ayrı bileşenlerdir. Güncel cihaz/yerel servis envanteri gece raporunda tutulur; 9 Ekim'deki “0 simülatör” notu bugünkü envanter değildir.

Kök `.env`, istemciye açık Supabase URL/anon ve isteğe bağlı Sentry DSN içindir; `.env.example` şablondur. Service-role/Resend/management sırları mobil asset'e girmez. **Normal çalıştırma mevcut `.env` ile canlıya bağlanabilir.** Yerel testte URL ve anon define'larını birlikte açıkça ver; [izole backend rehberini](tool/local_supabase/README.md) izle. Bu gece `.env` okunmadı/değiştirilmedi ve yeni hesaplar yalnız yerel ortam içindir.

## Kontroller

```sh
flutter analyze
flutter test --concurrency=2
python3 landing/tools/sync_partials.py --check
cd scripts && npm test
```

Anlamlı birim/widget ve SQL regresyonları korunur; uygulama paketine dahil değildir. `test/hourglass_lifecycle_test.dart` geciken asset, duraklatma, görünmez sekme ve hareket azaltma davranışlarını kapsar. `test/localization_completeness_test.dart` ARB anahtar/placeholder eşitliği, eski çeviri köprüsü ve doğrudan görünen sabit metinleri denetler. Normal turdaki **5 atlama**, `--dart-define=SCREENSHOTS=true` ile açılan PNG üreticileridir: onboarding 1, kayıt 3, sayaç 1; işlevsel testler değildir. Açık hata/bildirim dil değişimi ve derin Sentry temizliği `runtime_localization_test`, `notification_language_refresh_test` ve `error_reporting_test` ile ayrıca sınanır. Açık Deneme/onboarding onaylarının ve kategori penceresi etiketlerinin dil değişimi ayrıca `exam_dialog_localization_test` ve `onboarding_dialog_localization_test` ile doğrulanır. Tarih/saat dilimi değişikliklerinde New York/DST regresyonlarını da çalıştır.

Cihazda `flutter test integration_test/... -d ...` varsayılan kapanışta uygulamayı kaldırabilir. Çok aşamalı native `r`/`w`/`x` testlerinde `tool/local_supabase/e2e/sim/` altındaki iOS/Android çalıştırıcılarının **`--no-uninstall --no-pub`** seçeneklerini koru; aşamalar arasında uygulama verisini temizleme, uygulamayı yeniden kurma veya simülatörü sıfırlama. OS sürecini kapatıp açmak bu verileri silmek değildir. İlk r25/r135 koşuları bu uninstall davranışı nedeniyle kalıcılık kanıtı sayılmadı; yeni başlangıçlarda container ve kalıcı işaret ayrıca doğrulanıyor. `r` başlangıç PASS'i tamamlanma/ödül PASS'i değildir. `w` gerçek 25 dakika, HTTP 503 ve OS yeniden açılışını; `x` kontrollü geçmiş üzerinden hedef/Global ve OS yeniden açılışını sınar.

Son native kanıt: iOS 18.6 `o2_04` net/yatay/kayıt/haftalık ortak SQL toplamını, `x_change` + `x_resume` hedef/Global durumunun ayrı OS sürecinde korunmasını geçti. Kontrollü geçmiş kullanıldığı için doğal 330 dakika veya ay geçişi sayılmaz. **Yeni gerçek r25 finali geçti; TUS 135 finali, w ve gerçek Maraton çevrimleri bekleniyor.** Android q/j/t/o1/o2 sonuçları da tamamlandı. [Native QA raporu](analiz/QA_NATIVE_GECE_2026-10-28.md) son loglar geldikçe güncellenir; başlatılmış/ara koşu final başarı yerine kullanılamaz. Bu dal genel yayın onayı değildir.

SQL kurulumu, geri alma ve yerel test komutları [27/28/29 paket rehberindedir](supabase/proposed/NIGHT_20261028_README.md). Sabit fikstür ve kısa yerel katalog deneyi, gerçek 75/135/180 dakika beklenmiş native deneme değildir. Simülatör debug kare ölçümü, fiziksel cihazdaki profile/release performansının kanıtı değildir. Son raporda bu kapsamlar ayrı yazılır.

Canlı Auth hesabı açıp silebilen `scripts/security_regression_test.js` normal test komutu değildir; ayrıca açık yetkilendirme gerekir. Chrome kullanıcıya ayrılmıştır; tarayıcı doğrulamasında Safari kullanılır.

## Mağaza ve backend

`scripts/build_release.sh android|ios|all`, obfuscation ve sembol çıktılarıyla mağaza derlemesi içindir. Android upload keystore, iOS ücretli Apple takım/provisioning ayarları ve ilgili sembol yükleme kimlikleri gerekir. İmzalı IPA, mağaza yayını ve fiziksel cihaz doğrulaması ayrı işlerdir.

Kök migration geçmişi canlıyla birebir değildir: **kör `supabase db push/reset` yapma.** Her paket için güncel canlı tanım/ACL karşılaştırması → izole test → geri alınan DRYRUN → kullanıcının SQL Editor işlemi → salt okuma doğrulaması gerekir. **D-06 yayın sırası: 27 TUS → 28 Deneme → 29 aylık lig → yeni uygulama yayını → site yayını.** 30 başlangıç kota paketi bağımsızdır. Site, yeni özellikler kullanıcının uygulamasında ve sunucusunda hazır olmadan yayınlanmaz. Rollback, kaydedilmiş denemeyi veya işlenmiş yarış sonucunu silerek zorlanmaz. [Supabase rehberi](supabase/README.md), [paket rehberi](supabase/proposed/NIGHT_20261028_README.md).

Bu dal genel yayın onayı değildir. §33'teki operasyonel konular, gerçek Google/Apple girişi, fiziksel cihazlar, Apple imzalama/mağaza beyanları ve gerçek yasal/gönderen kimliği ayrıca tamamlanmalıdır. Kullanıcı kimlik bilgilerini en son sağlayacak. [Operasyonel QA](analiz/QA_OPERATIONAL_CONTROLS_2026-10-08.md), [mağaza kontrol listesi](analiz/magaza_uyum_kontrol_listesi_2026-10-03.md).

## Belgeler ve klasörler

| Yol | İçerik |
|---|---|
| [AGENTS.md](AGENTS.md) | Çalışma kuralları, mevcut/yeni sözleşmeler ve alan haritası |
| [PROJE_DEVIR.md](PROJE_DEVIR.md) | Mimari, tarihli çalışmalar ve devam noktası |
| [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) | Kısa güncel ürün/mimari özeti |
| [İstek listesi](analiz/ISTEKLER.md), [ilerleme](analiz/CODEX_ILERLEME.md) | Gece maddeleri, gerçek kontroller, eksikler ve commitler |
| [Yeni API sözleşmesi](supabase/proposed/EXAM_API_CONTRACT.md) | Deneme, aylık lig, hedef ve çalışma metaverisi |
| `lib/`, `assets/` | Mobil ürün ve aktif görseller |
| `test/`, `integration_test/` | Birim/widget/native regresyon kaynakları |
| `supabase/`, `tool/local_supabase/` | SQL/Edge kaynakları ve izole yerel altyapı |
| [landing/README.md](landing/README.md) | TR/EN site geliştirme/yayın rehberi |
| `scripts/`, `analiz/` | Derleme, Node testleri ve tarihli QA/operasyon raporları |

9 Ekim temizliği eski ham fixture/log ve kullanılmayan platform şablonlarını kaldırdı; tasarım arşivi repo dışındadır. Yeni gecenin kanıtları ayrı tarihli tutulur. Sırlar, imzalama ve mevcut gerçek hesaplar commit'e alınmaz veya test temizliği diye silinmez.
