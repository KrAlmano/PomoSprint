# Gece QA temizlik planı — 28 Ekim 2026

**Durum: yalnız envanter ve plan; hiçbir dosya, cihaz veya veri silinmedi.**
İlk ölçüm 28 Ekim 00:05–00:07 Europe/Istanbul civarında alındı; aşağıdaki
03:29 güncellemesi daha yenidir. Saat 06:30'da
root yeniden kontrol ederek uygulayabilir; devam eden test varsa ertelenir.
Bu plan yalnız PomoSprint repo çıktıları ve bu gece oluşturulan QA ortamını
kapsar. `.env`/anahtar içerikleri okunmadı, canlı servise gidilmedi. Bu planı
yazan ajan yalnız `adb devices -l` ile cihaz listesini okudu; Android cihaz
durumunu değiştirmedi. `DENETIM.md` okundu ve değiştirilmedi.

Boyutlar `du -sk` ile ayrılan blokların MiB/GiB karşılığıdır. Büyüyen dosyalar,
APFS klonları/sparse diskler ve paylaşılan bloklar nedeniyle silindikten sonra
gerçek boşalan alan bu sayıların toplamından farklı olabilir. Bir dosyanın
eski olması tek başına bu gece üretildiği veya gereksiz olduğu kanıtı değildir.

## 06:30 için güvenli sıra

1. Root ve Android ajanı son native/Maraton/HTTP/medya testlerinin bittiğini
   doğrular. Açık uzun test, recorder, encoder, Flutter veya Gradle çalışması
   varken ilgili cihaz/cache/çıktı silinmez. `Shutdown` cihaz durumu, içinde
   bekleyen gerçek süreli deneme olmadığı anlamına gelmez.
2. Son başarı **ve başarısızlık** logları, süreç kapanış/geri yükleme
   manifestleri, fixture ayrımı ve ekran/video kanıtları korunur. Gerekirse
   arşivlenir; token/kişisel veri taraması yapılmadan ham log Git'e eklenmez.
3. Aşağıdaki yeniden üretilebilir derleme çıktıları ve kesin geçici kopyalar
   temizlenir. Repo köküne `flutter clean` uygulamak burada listelenen kanıt
   klasörlerini de kaldırabileceğinden bu iş için körlemesine kullanılmaz.
4. Kullanıcının istediği gibi bu projeye ait **bir iOS18.6 ve bir Android AVD**
   bırakılır. Diğer iki PomoSprint QA iOS cihazı, bütün probe/final kanıtları
   kapanınca kaldırılır. Başka projenin `HocamMacVar` cihazı ve iOS27 runtime'ı
   bu sayıya dahil edilip silinmez; kapsam dışıdır.

## Yeniden üretilebilir çıktı adayları

Repo kökü: `/Users/almano/Desktop/Projects/Pomodoro`.
Aşağıdaki göreli yolların tamamı bu köke bağlıdır; başka proje veya global
önbellek temizliği anlamına gelmez.

| Net yol | Ölçülen boyut | 06:30 kararı / gerekçe |
|---|---:|---|
| `.dart_tool/flutter_build/` | 3.34 GiB | Tüm Flutter işleri bitince silinebilir; derleme ara çıktıları yeniden oluşur. Sonraki derleme uzar. `.dart_tool` bütünü silinmez. |
| `build/app/intermediates/` | 1.19 GiB | Android native/Gradle işi tamamen bitince silinebilir; kaynak veya kullanıcı verisi değildir. |
| `build/ios/Debug-iphonesimulator/` | 387.20 MiB | iOS/media/final probe tamamlanınca silinebilir; derleme çıktısı. |
| `build/ios/iphonesimulator/` | 182.16 MiB | Aynı koşul; yüklenmiş cihazın veri konteyneri değildir. |
| `build/test_cache/` | 96.17 MiB | Son Flutter test turu tamamlanınca yeniden üretilebilir cache. |
| `build/unit_test_assets/` | 26.12 MiB | Son test turundan sonra yeniden paketlenebilir varlık kopyaları. |
| `build/jni/` | 3.95 MiB | Android derlemeleri durduktan sonra yeniden üretilebilir native çıktı. |
| `build/.cxx/` | 0.91 MiB | Aynı koşul; Gradle/native cache. |
| `build/app/kotlin/` | 0.59 MiB | Aynı koşul; Kotlin ara çıktısı. |
| `build/app/tmp/` | 0.08 MiB | Aynı koşul; derleme geçicileri. |
| `/tmp/pomosprint_jdk21.tar.gz` | 190.50 MiB | Çıkarılmış JDK zaten var; checksum/indirme referansı korunarak arşiv temizlenebilir. **Çıkarılmış JDK'yı silmekle aynı şey değildir.** |
| `/tmp/pomosprint_jdk21/` | 335.12 MiB | Root doğruladı: JDK21 uyumsuz bulunmuş, aktif Android JDK17'ye geçilmiş; bu çıkarılmış geçici JDK da 06:30 adayıdır. |

Bu temel listenin ölçülen blok toplamı yaklaşık **5.73 GiB**'dır; garantili
boşalan alan iddiası değildir. `build/app/outputs/` ayrıca **331.04 MiB**:
son kurulabilir APK ve gerekli build tanımlayıcısı korunacaksa yalnız eski
kopyalar seçilmelidir. Son paket teslimi/kurulum ihtiyacı bitmeden tüm
`outputs/` silinmesi önerilmez.

## Bu gece oluşturulan cihazlar

01:01TR ek envanter: `66504EAE-D6FA-4877-98FB-6E7348BA57F5`, **PomoSprint QA Shortflows iPhone (18.6)**, mevcut iOS18.6 runtime'ında geçici oluşturuldu. Amaç, asıl iOS18 gerçek50 ve iOS27 gerçek135 deneme disk kayıtlarına dokunmadan parola/sosyal/profil gibi kısa native turları bitirmektir. Aynı anda yalnız bu iOS ve tek Android çalıştırılır; iki uzun probe cihazı kapalıdır. Bu ek cihaz da06:30 temizliğinde iOS27 ile birlikte kaldırılacak; asıl iOS18 ve tek Android kalacaktır. Kullanıcının korunan `2CF…` cihazına dokunulmaz.

Oluşturulma zamanları dizin `birthtime` verisinden doğrulandı. iOS envanteri
salt-okuma `simctl list devices --json` ile alındı; cihaz açılmadı/kapatılmadı.

| Cihaz / net dizin | Oluşturulma (İstanbul) | Ayrılmış blok | Öneri |
|---|---|---:|---|
| PomoSprint QA iPhone 16 (18.6), `/Users/almano/Library/Developer/CoreSimulator/Devices/8D0EFF44-5AF3-42E6-9F59-92CDFF8C9E5C/` | 27 Ekim 22:27:45 | 2.02 GiB | Kullanıcıya bırakılacak iOS18.6 simülatörü olarak koru. Gerçek25 probe/app verisi ve site kaydı işi bitmeden kesinlikle kaldırma. |
| PomoSprint QA iPhone 17 (27), `/Users/almano/Library/Developer/CoreSimulator/Devices/59F07F60-879F-49CF-9749-51F4BFE8E106/` | 27 Ekim 22:27:46 | 2.84 GiB | Root kararına bağlı ikinci cihaz adayı. Gerçek135 deneme finali, süreç korunma kanıtı ve gerekli UI kontrolleri tamamlanıp rapora işlendiğinde kaldırılabilir. O zamana kadar koru. |
| PomoSprint_QA_API36, `/Users/almano/.android/avd/PomoSprint_QA_API36.avd/` ve eş `.ini` dosyası | 27 Ekim 22:28:06 | 3.56 GiB + 134 B | Tek Android test ortamı; korumak önerilir. Android ajanı da testler bitene kadar korunmasını doğruladı. Root kaldırmaya karar verirse önce tüm Android Maraton/geri yükleme kanıtları kapanır. |

Bu dizinler doğrudan rastgele dosya silerek parçalanmamalıdır; cihaz kaldırma
kararı verilirse ilgili platformun cihaz yönetimi kullanılmalıdır. Burada
silme komutu çalıştırılmadı. Mevcut, kullanıcıya ait **`2CF…` cihazı** hiçbir
temizlik listesine dahil değildir. iOS runtime'ları, Android SDK/system-image
paketleri ve diğer uygulamaların cihazları bu kapsamın dışındadır.

## Varsayılan korunacak büyük bağımlılıklar

| Yol | Boyut | Neden |
|---|---:|---|
| `build/ios/SourcePackages/` | 1.98 GiB | SwiftPM paket/artifact cache'i. Gece ilk indirme uzun sürdü; temizlemek bir sonraki iOS çalıştırmada tekrar indirme ve bekleme yaratır. Yer zorunluluğunda ayrıca karar verilir, otomatik listeye alınmaz. |
| `build/ios/SourcePackages/artifacts/` | 1.78 GiB | Yukarıdaki toplamın parçası; toplamda tekrar sayılmaz. |
| `/Users/almano/Library/Java/pomosprint-qa/zulu17.62.17-ca-jdk17.0.17-macosx_aarch64/zulu-17.jdk/Contents/Home` | Bu envanterde ölçülmedi | Root tarafından aktif Android JDK yolu olarak doğrulandı; korunur. Geçici JDK21 ile karıştırılmaz. |
| `/tmp/pomosprint-exam-research-20261028/` | 11.73 MiB | Sınav süre/dağılımının resmî kaynak PDF/metin kopyaları. Kaynak raporu yanında korunması faydalı; sonradan kaynak arşivine taşınabilir. |

Global `~/.gradle`, `~/.pub-cache`, Android SDK, Xcode/SwiftPM global cache,
Docker volume/image ve diğer projeler bu temizlikte **hedef değildir**.
Yerel QA veritabanı ve Mailpit de root ayrıca karar vermedikçe korunur;
hesap/ekonomi geçmişini dosya temizliği gerekçesiyle sıfırlama yoktur.

## Küçük scratch kopyaları

Aşağıdakiler toplam **65.631 bayt**; disk kazancı küçüktür. Son diff ve
çeviri testleri tamamlandıktan sonra, karşılıklarının repo kaynaklarına
geçtiği görülerek temizlenebilir:

| Net `/tmp/` yolu | Bayt | Gerekçe |
|---|---:|---|
| `/tmp/pomosprint-i18n-additions.json` | 6.073 | Birleşen ARB ek taslağı. |
| `/tmp/pomosprint-league-l10n-20261028.json` | 4.441 | Lig çeviri ek taslağı. |
| `/tmp/pomosprint-localization-completeness.dart` | 9.443 | Geçici test taslağı; repo regression karşılığı kontrol edilir. |
| `/tmp/pomosprint-target-guard.sql` | 831 | İnceleme taslağı; nihai proposed SQL/test yerine kullanılmaz. |
| `/tmp/pomosprint_a_register_onboarding.expanded.dart` | 17.848 | Birleşen native test ara kopyası. |
| `/tmp/pomosprint_a_register_onboarding_expansion.patch` | 10.730 | Aynı değişikliğin geçici yaması. |
| `/tmp/pomosprint_exam_async_guard.patch` | 1.850 | Birleşen kaynak yaması. |
| `/tmp/pomosprint_exam_l10n_20261027.json` | 12.012 | Deneme çeviri ek taslağı. |
| `/tmp/pomosprint_reports_l10n_20261027.json` | 2.403 | Rapor çeviri ek taslağı. |

Fixture UID allowlist JSON'ları ve çalışma sırasındaki port/host kayıtları
yeniden çalıştırmalarda kullanılabildiğinden bu küçük taslak listesine
katılmadı. `/tmp/pomosprint*` gibi geniş bir wildcard ile silme yapılmaz.

Özel kaynak dosyası adayı:
`/Users/almano/Desktop/Projects/Pomodoro/tool/local_supabase/e2e/extend_w_mixed_fixture.py`
(10.225 bayt).
Bu, exact UID'ye kilitli, yalnız bu gecenin `w` kontrollü geçmişini hazırlayan
tek kullanımlık yardımcıdır; yeniden kullanılabilir ürün regresyonu değildir.
**Şimdilik kalır.** Root talimatıyla ancak `w` tamamen bittiğinde,
`build/overnight_backend/w_mixed_fixture_71ffd38f-84db-4003-b785-840ea83bb477.json`
manifesti ve rapordaki gerçek/kontrollü süre ayrımı korunduktan sonra 06:30
temizliğine alınabilir. Genel `create_exam_qa_fixture_account.py`, proxy
araçları ve `w_normal_http_restart_test.dart` ise tekrar kullanılabilir;
korunur.

## Kanıt ve regression olarak korunacaklar

- `analiz/QA_NATIVE_GECE_2026-10-28.md`,
  `analiz/DOGRULAMA_MATRISI_2026-10-28.md`, gece raporu, istekler/ilerleme
  kayıtları ve ilgili güvenlik/lig/animasyon/yerelleştirme QA raporları.
- `analiz/ekran_gece_2026-10-28/`: ölçüm anında **15.77 MiB** gerçek ekranlar.
  Dosya sayısı koşular sürdükçe artabilir; önceki başarısız koşuların görüntüsü
  başarı görüntüsüyle karıştırılmaz. Başarı kanıtı yerine tekrar çizim yoktur.
- `build/overnight_backend/`: **0.22 MiB** SQL sonuçları, fixture manifestleri,
  04:00/ay dönümü/owner/RLS/race/rollback kanıtı, review snapshot'ları ve
  `real25/real135_*process_close.json`, `league_process_resume_verified.json`.
  Küçük ama kritik; sadece `build/` altında diye silinmez.
- `build/e2e_sim/` (**0.09 MiB**) ve `build/e2e_android/` (**0.03 MiB**)
  son wrapper/parite logları; bunların üzerine yeni koşular yazabildiği için
  tarihli `/tmp/pomosprint_ios*` ve `/tmp/pomosprint_android*` logları da korunur.
- Gerçek süreli `r`, `s`, `v`, `w` başlangıç/final logları ve native
  preferences/owner/süre kanıtları. İlk uninstall nedeniyle geçersiz kalan
  probe sonuçları da nedenini belgelemek için tutulur; silinerek başarıya
  dönüştürülmez.
- `/tmp/pomosprint_*before*.log` ve ilgili `after/final` logları: FAIL→PASS
  regression kanıtları. Envanterde `/tmp/pomosprint*` 226 dosya toplam yaklaşık
  199.08 MiB idi; bunun 190.50 MiB'ı tek JDK arşiviydi. Geri kalan yaklaşık
  **8.58 MiB** için kanıt kaybetmek gereksizdir.
- `build/native_site_media/` oluşturulduğunda gerçek ham video,
  `recording.json`, final MP4/WebP/ASS ve SHA/UTC/tap manifesti önce gözle
  doğrulanır. Kaynak görüntü/provenance tutulmadan yalnız sıkıştırılmış video
  bırakılmaz. Ölçüm anında bu klasör henüz yoktu.
- `test/`, `integration_test/`, `tool/local_supabase/` altındaki anlamlı
  owner-race, offline/restart, parasal ayrım, rollback, RLS ve native regresyon
  testleri kaynak olarak korunur. Bunlar geçici veri değildir.

## Medya araçlarının hafif doğrulaması

`record_site_video.py` + `encode_site_video.py` için **16/16 çevrimdışı test
geçti**; iki CLI `--help` ve `py_compile` geçti. Cihaz/korunan UUID/output
yolu, UTC/monoton zaman/sahne/tap şeması, vektör koordinatı ve CRF42'de boyut
sınırının açık hataya dönüşmesi denetlendi. Gerçek kayıt ve encoder işlemi
bu kontrol sırasında başlatılmadı; görsel okunabilirlik ayrı native kayıt
sonrası doğrulanmalıdır. Ayrıntı: `QA_SITE_VIDEO_TOOLS_2026-10-28.md`.


## 03:29 TR güncellemesi — son kurulum ve kesin temizlik sırası

**Bu bölüm de plandır; derleme, kurulum ve silme yapılmadı.** Envanter yalnız
liste/metadata komutlarıyla güncellendi. Veri bölümünde 126 GiB boş alan var;
acil disk baskısı bulunmadığından son native kanıtları bitmeden alan açmak
için cihaz ya da cache kaldırılmamalıdır. `DENETIM.md` son 03:18 turu okundu.

| Güncel envanter | Ayrılmış alan | Karar |
|---|---:|---|
| `.dart_tool/flutter_build/` | 6.39 GiB | Son kaynak/test/normal uygulama derlemeleri bitince silinebilir. |
| `build/app/intermediates/` | 1.06 GiB | Son Android paket kurulup doğrulandıktan sonra silinebilir. |
| `build/ios/Debug-iphonesimulator/` | 387.20 MiB | Son normal Runner.app korunup kurulduktan sonra silinebilir. |
| `build/ios/iphonesimulator/` | 182.16 MiB | Aynı koşul. |
| `/tmp/pomosprint-release-android-20261028-ewzefjzo/` | 760.13 MiB | Son manifest ve `build/overnight_release_android/` çıktısı korununca silinebilir; bu kopyanın debug imzası son cihaza kurulum için uygun değildir. |
| iOS18 ana cihaz `8D0EFF44-5AF3-42E6-9F59-92CDFF8C9E5C` | 1.75 GiB | **Koru.** Son kullanıcıya bırakılacak PomoSprint iOS cihazı. |
| Geçici iOS18 `66504EAE-D6FA-4877-98FB-6E7348BA57F5` | 3.10 GiB | Kısa native test kanıtları tamam; 06:30'da root son kontrolünden sonra kaldır. |
| iOS27 `59F07F60-879F-49CF-9749-51F4BFE8E106` | 3.32 GiB | **Şu anda silinemez:** ön/son 31 paketi Maraton probe planı bitmeli. Sonuçlar ve marker exportları kapanınca 06:30'da kaldır. |
| Diğer proje `2CFDB5C8-6CA6-457C-8A6E-864B1849C681` | 2.60 GiB | **Dokunma.** HocamMacVar cihazı. |
| `PomoSprint_QA_API36` | 4.04 GiB | **Koru.** Tek Android AVD; `emulator-5554` bağlı. |
| `build/ios/SourcePackages/` | 1.98 GiB | Koru; son temiz kaynak iOS derlemesinde yeniden kullanılabilir. |
| `build/native_site_media/` | 36.06 MiB | Ham video/manifest/nihai medya kanıtını koru. |
| `build/overnight_backend/` | 0.39 MiB | Tüm SQL, gerçek süre ve süreç kanıtlarını koru. |
| `analiz/ekran_gece_2026-10-28/` | 28.34 MiB | Başarılı ve başarısız koşular ayrımıyla koru. |

Önceki tablodaki test cache/JDK adaylarıyla birlikte, iki fazla QA cihazı ve
kesin derleme/scratch kopyalarının toplamı yaklaşık **15.8 GiB ayrılmış blok**
eder. Bu, ölçüm anının tahmini toplamıdır; yeni derlemeler, APFS paylaşımı ve
sparse diskler nedeniyle silme sonrası aynı miktar boş alan garanti edilmez.
`build/app/outputs/` (331.04 MiB), normal uygulama teslimi bitmeden silinmez.
iOS18.1 runtime'ında cihaz yok, fakat bu gece oluşturulduğu kanıtlanmadı;
**runtime'lar silme listesinde değildir**. iOS27 diğer projeye de gereklidir.

### Son kullanıcıya bırakılacak uygulama

Entegrasyon testi bittiğinde cihaza son yüklenen APK/Runner otomatik test
hedefi olabilir. Son adımda `lib/main.dart` normal uygulaması ayrıca derlenip
**veri korunarak** kurulmalıdır. Bu yerel QA kurulumudur: 25/50 dakika gerçektir,
backend `127.0.0.1:54321` yerel Supabase'dir; canlı hesaplar için hazır kurulum
veya mağaza paketi olarak sunulmaz. Sentry kapalı bırakılır.

1. Bütün uzun probe'ların final marker'ı ve bağımsız sunucu doğrulaması
   kaydedilir. Aynı cihazda hâlâ tamamlanmamış probe varsa kurulum yapılmaz.
2. Root son commit/hash'i kaydeder. `git archive` ile yalnız son incelenmiş
   commit'teki kaynaklar ayrı bir `/tmp/pomosprint-final-main-*` dizinine alınır.
   `.env*`, `scripts/.env`, `key.properties`, `settings.local.json` ve
   `.keystore/.jks/.p12/.pfx/.p8/.pem/.key/.mobileprovision/.cer/.crt` uzantıları
   **arşive alınmadan önce** dosya listesinde elenir. Normal `cp -R` ile çalışma
   ağacı/`.git`/önbellek taşınmaz. Boş `.env` sonradan oluşturulur. Arşiv listesi,
   kaynak hash'i, boş asset boyutu ve yasaklı dosya taraması manifeste yazılır.
3. `flutter --suppress-analytics pub get --offline` çalıştırılır ve
   `pubspec.lock` hash'i değişmediği doğrulanır. Paketler mevcut önbellekten
   kullanılmalı; `pub upgrade` ve genel SDK güncellemesi yapılmaz.
4. Yeni kopyada Android `gradle.properties` yalnız o kopyada en çok 2 işçi,
   2048 MiB heap, 768 MiB metaspace, paralellik kapalı ve SDK indirme kapalı
   olacak şekilde sınırlandırılır. **`ANDROID_USER_HOME` ve `GRADLE_USER_HOME`
   izole release kopyasına yönlendirilmez.** Mevcut native testin normal debug
   imzası korunur; anahtar içeriği okunmaz/kopyalanmaz. Aktif Java aşağıdaki
   mevcut JDK17'dir; geçici JDK21 kullanılmaz.
5. iOS için yeni kopyadaki `build/ios/SourcePackages` mevcut repo önbelleğine
   symlink olabilir; böylece yaklaşık 2 GiB tekrar indirme gerekmez. Bir iOS
   derlemesi sürerken başka iOS derlemesi başlatılmaz. Normal hedefe geçerken
   standart `--pub` akışı plugin kaydını yeniden üretir; eski entegrasyon test
   çıktısı kopyalanmaz.

Aşağıdaki komutlar **örnektir, bu raporu hazırlarken çalıştırılmadı**.
`FINAL_SOURCE` yalnız yukarıdaki denetlenmiş temiz kaynak kopyasını,
`LOCAL_ANON` ise `run_android_e2e.sh` içindeki herkese açık yerel demo anon
anahtarını temsil eder; canlı `.env` okunarak doldurulmaz.

```sh
# Temiz kaynak kopyasında; önce iOS, sonra Android veya tek sıra.
flutter --suppress-analytics build ios --simulator --debug --pub \
  --target lib/main.dart \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY="$LOCAL_ANON" \
  --dart-define=SENTRY_DSN=

JAVA_HOME=/Users/almano/Library/Java/pomosprint-qa/zulu17.62.17-ca-jdk17.0.17-macosx_aarch64/zulu-17.jdk/Contents/Home \
flutter --suppress-analytics build apk --debug --pub \
  --target lib/main.dart --target-platform android-arm64 \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY="$LOCAL_ANON" \
  --dart-define=SENTRY_DSN=
```

Paketlerin `.env` asset'i sıfır bayt olmalı; kaynak/lock hash'leri saklanır.
APK imza sertifikası özeti hem cihaza önceden kurulu paket hem yeni paket için
`apksigner verify --print-certs` ile karşılaştırılabilir; bu işlem özel anahtar
okumaz. `build/overnight_release_android/app-release-qa-arm64.apk` farklı,
izole debug anahtarıyla imzalandığından **bu işte kullanılamaz**.

```sh
# Yalnız son probe'lar bittiğinde; bu komutlar veri temizlemez.
xcrun simctl install 8D0EFF44-5AF3-42E6-9F59-92CDFF8C9E5C \
  "$FINAL_SOURCE/build/ios/iphonesimulator/Runner.app"
xcrun simctl launch 8D0EFF44-5AF3-42E6-9F59-92CDFF8C9E5C com.pomosprint.app

adb -s emulator-5554 reverse tcp:54321 tcp:54321
adb -s emulator-5554 install -r -t \
  "$FINAL_SOURCE/build/app/outputs/flutter-apk/app-debug.apk"
adb -s emulator-5554 shell am start -n com.pomosprint.app/.MainActivity
```

Kapalı iOS yalnız korunacak UUID ile boot edilir; `simctl bootstatus ... -b`
sonucu beklenir. Kurulum hata verirse **kaldırıp yeniden kurma yoktur**: imza,
bundle ID ve paket metadata'sı incelenir, veri korunur. `flutter install`
varsayılanı uninstall edebildiği için kullanılmaz. Android emulator yeniden
başlatılırsa `adb reverse` tekrar gerekebilir; bu sabah raporuna yazılır.
Son açılışta en az 15–30 saniye beklenip normal ekran, hesap/süre korunması,
PID'in yaşaması ve yeni fatal log olmadığı doğrulanır. Bu son smoke testi
başlı başına bütün uygulamanın test edildiği anlamına gelmez.

**Süre bütçesi (tahmin):** mevcut cache ile temiz pub 1–2 dk, Android debug
2–5 dk, iOS ilk temiz proje 3–10 dk; kurulum/açılış 1–2 dk. Beklenmedik paket
çözümleme varsa daha uzun sürer. 06:30 temizliğinden önce tamamlamak için
05:40 civarında başlanması güvenli; tüm derlemeler bitmeden cache silinmez.

### 06:30'da root'un uygulayacağı son liste

- İki fazla QA cihazı için bütün pending/final marker'ları tekrar kontrol et.
  Son onaydan sonra yalnız şu UUID'lerde platform aracını kullan:
  `xcrun simctl delete 66504EAE-D6FA-4877-98FB-6E7348BA57F5` ve
  `xcrun simctl delete 59F07F60-879F-49CF-9749-51F4BFE8E106`.
  Bu komutlar **henüz çalıştırılmadı**. `simctl delete all/unavailable`,
  `erase`, bütün `~/Library/Developer/CoreSimulator` dizinini silme yoktur.
- Son app artifact ve kanıtlar saklandıktan sonra yukarıdaki kesin cache/JDK21/
  izole release kopyası listesi temizlenir. `/tmp/pomosprint*` wildcard'ı yoktur.
  Final temiz kaynak kopyası da yalnız son paketler ayrı korunduktan sonra
  kaldırılır; paket/manifest için küçük `build/overnight_final_main/` korunabilir.
- Tek kullanımlık `extend_w_mixed_fixture.py` ancak `w` kanıtı/root onayı sonrası
  kaldırılır. Anlamlı testler, kaynaklar, yerel DB/Mailpit, aktif JDK17, global
  Flutter/Gradle/pub/SDK ve SwiftPM önbellekleri korunur.
- Kalan cihaz listesi **bir PomoSprint iOS + bir Android**, ayrıca dokunulmayan
  başka projeye ait HocamMacVar cihazı şeklinde kaydedilir. Disk öncesi/sonrası
  ölçülür; gerçek kazanım ayrıca raporlanır.


## 04:15 TR güncellemesi — normal Android paketleri ve son kanıtların korunması

**Temizlik hâlâ plan; silme ve cihaz kurulumu yapılmadı.** Bu bölümdeki Android
derlemeleri ise gerçekten tamamlandı. `DENETIM.md` 03:48 turu yeniden okundu.
04:15 envanterinde veri diskinde **121 GiB boş** alan var. Son Android derleme
wrapper'ı (49348) exit 0 ile kapandı; salt okunur süreç kontrolünde bu final
kaynak kopyasına ait Android derleme süreci kalmadı. Bu tespit root'un ayrı
AB/diğer cihaz denemelerinin bitmiş olduğu anlamına gelmez; onların durumunu
root ayrıca doğrular.

| Korunacak son çıktı | Gerçek durum |
|---|---|
| `build/overnight_final_main/app-debug-local-main-arm64.apk` | Normal `lib/main.dart`, yerel Supabase, 25/50 gerçek süre; **82,59 sn** toplam / 78,8 sn Gradle, PASS. **128.223.167 bayt**, SHA256 `83e1c8df4f0d570401917fdc60a822c5343621657ce35f9314524aa7a6874e4d`. Kurulmadı. |
| `build/overnight_final_main/app-release-local-qa-arm64.apk` | Aynı normal kaynakların release derlemesi; **49,98 sn** toplam / 47,9 sn Gradle, PASS. **54.167.363 bayt**, SHA256 `ff3096e51a7ce9519b9ba2dcd23c3f8212f1b757d079abfe5cfb518f3d9b07d6`. Kurulmadı. |
| `source_manifest.json` | Kaynak commit `1cc6a059fb07be3ec6bbf38ceb3924a4bebaeb82`; 1.071 dosyalı sır filtresi uygulanmış arşiv, 236 kaynak SHA256. |
| `android_debug_verification.json`, `android_release_verification.json` | 236 hash commit ile eşleşiyor; kopyada 235 dosya aynı, yalnız `android/gradle.properties` 2 GiB/2 işçi kaynak sınırları farklı. `pubspec.lock` değişmedi. Her iki paketin `.env` asset'i **0 bayt**. |
| `final-debug-public-cert.txt` ve önceki APK sertifika karşılaştırması | İmza SHA256 her iki normal pakette ve önceki native APK'da **aynı**: `077124814fdbb9e299b34a8c52de950a932df90b4b9b8501e7bf453dd0534e34`. Yalnız APK içindeki açık sertifika okundu; özel anahtar açılmadı/kopyalanmadı. |
| `final-debug-network-security-tree.txt` | DEBUG pakette `127.0.0.1` için yerel cleartext izin listesi doğrulandı. Release manifestinde bu debug ayarı bulunmadığından yerel son kurulumda DEBUG paket tercih edilir. Gerçek bağlantı testi kurulumdan sonra root'a aittir. |

Bu iki paket **mağazaya dağıtılacak paket değildir**; yerel backend'e bağlı QA
çıktılarıdır. DEBUG paketin büyük olması mağaza indirme boyutu değildir.
Önceki `build/overnight_release_android/app-release-qa-arm64.apk` farklı bir
izole debug anahtarıyla imzalı eski kanıttır; yeni normal paketin yerine
kurulmaz. Yeni release paketinde entegrasyon testi sınıfının DEX içinde
olmadığı ayrıca doğrulandı; normal DEBUG hedefi de `lib/main.dart`'tır.

İlk üç final Android denemesi Maven dinamik sürüm listesi nedeniyle başarısız
oldu: önce geçici DNS, ardından `androidx.test:runner:1.2+` için offline liste
bulunamaması. SDK/kilitli paketler değiştirilmeden, yalnız kopyadaki geçici
offline ayarı geri alınarak taze Gradle süreciyle çevrimiçi tekrar geçti.
Bunlar ürün kodu düzeltmesi olarak gösterilmez; hata ve tekrar logları ayrıdır.

### Artan ama geri üretilebilir alan

| Net yol | 04:15 ayrılmış alan | 06:30 kuralı |
|---|---:|---|
| `/tmp/pomosprint-final-main-20261028-vgcv2fgh/` | 2,29 GiB | **Şimdi korunur:** iOS normal derlemesi bekliyor. Son iOS/Android paketleri `build/overnight_final_main/` içine kopyalanıp hash kontrolünden geçmeden, kurulum/açılış kanıtı bitmeden silinmez. |
| `build/overnight_final_main/` | 174,07 MiB | Korunur; iki kurulabilir paket ve küçük manifestler. iOS paketi eklenince artacak. Genel `build/` temizliğiyle kaldırılmaz. |
| `.dart_tool/flutter_build/` | 6,39 GiB | Son testler/derlemeler bitince silinebilir. |
| `build/app/intermediates/` | 1,19 GiB | Son Android kurulum/kanıt tamamlanınca silinebilir. |
| `build/app/outputs/` | 309,88 MiB | Son normal paketler ayrı klasörde ve hash'leri doğrulanmışsa eski test paketleri seçilerek kaldırılabilir. |
| `/tmp/pomosprint-release-android-20261028-ewzefjzo/` | 760,13 MiB | Eski release kanıt paketi/log/manifest korunduktan sonra silinebilir. |

Son kaynak klasörünü kaldırmak **ana repo veya SwiftPM cache'i silmek değildir**:
`source/build/ios/SourcePackages` ana repodaki cache'e symlink'tir. Silme aracı
symlink'i izleyerek hedefe girmemeli; cache yolu ayrı korunmalıdır. Final
kaynak kopyasına ait `retry-gradle-home` ve `retry-gradle-home-debug` içinde de
ana `~/.gradle/caches`/`wrapper` symlink'leri vardır; hedefleri silme.

### Commit'e girecek kanıtlar seçilmeli

Her ham logu/dump'ı commit'e topluca ekleme. Son raporun iddialarını karşılayan
küçük, **ayıklanmış** kanıt seti seçilir: sonuç kodu, gerçek süre/deadline,
kayıt ve ödül sayıları, kontrol adı, kaynak/artifact hash'i ve testin log yolu.
JWT/session/refresh token, parola, tam Supabase oturum nesnesi, ham native
preferences ve özel e-posta içeren kayıtlar commit'e girmez. JSON dışa aktarımı
için alan izin listesi kullanılmalı; yalnız metin üstünde token regex'i güvenli
ayıklama kanıtı sayılmaz. APK içindeki açık imza sertifikası gizli anahtar
değildir; karşılaştırma sonucu ve SHA yeterlidir.

Ham kaynak loglar henüz silinmez: root önce seçilmiş kanıtın aslıyla uyuştuğunu
ve başarısız koşuların doğru temsil edildiğini kontrol eder. Başarısız test
başarılı olarak yeniden adlandırılmaz; son rapor ilk hata ve ayrı tekrar
sonucunu açıkça ayırır. Sonra yalnız kesin geçici dosyalar temizlenebilir.
`build/overnight_backend/`, küçük final manifestler, kaynak testler ve gerekli
görseller korunur; bütün `/tmp/pomosprint*` veya `build/*` glob'u kullanılmaz.

### İzlenen dosyalarda gereksizlik incelemesi

`git ls-files` üzerinde derleme/önbellek klasörleri, `.apk/.aab/.ipa/.log`,
`.tmp/.bak/.orig/.rej`, `GeneratedPluginRegistrant`, `Generated.xcconfig`,
`flutter_export_environment.sh` ve geçici dosya adı örüntüleri tarandı:
**izlenen dosyalar içinde bu kapsamda bir silme adayı çıkmadı.**

`tool/local_supabase/e2e/` altındaki tarihli SQL/native yardımcıları owner/RLS,
rollback, iki ekonomi, kuyruk/süre ve eşzamanlılık regresyonlarını korur;
tarihli isimleri tek başına gereksizlik kanıtı değildir. Bu inceleme sonucunda
hiçbir izlenen test veya ürün dosyasının silinmesi önerilmiyor. Daha önce
belirlenen `extend_w_mixed_fixture.py` **izlenmeyen, tek kullanımlık** adaydır;
root `w` sonucu/manifestini koruduktan sonra karar verir. Üretilmiş ARB/Dart
çeviri dosyaları uygulamanın normal build akışının parçasıdır, bu kapsamda
silinmez. Kaynakta işlev kaldıran bir “temizlik” değişikliği yapılmadı.
