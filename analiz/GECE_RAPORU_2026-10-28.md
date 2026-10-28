# Gece çalışması nihai raporu — 28 Ekim 2026

**07:00 teslimi yapılamadı; etkin gece çalışması yaklaşık 04:27'de kullanım limiti nedeniyle kesildi.** Önceden başlatılmış Android testleri 05:12'de tamamlandı. Kullanıcının sabah yalnız kapanış işleri talebiyle 09:34'te yeniden başlandı; aşağıdaki kapanış işleri **09:59 Europe/Istanbul** itibarıyla tamamlandı. Yeni özellik eklenmedi. Bu rapor yerel doğrulamadır; mağaza/yayın onayı değildir.

- Dal: `codex/gece-2026-10-27`; son kaydedilmiş gece HEAD'i **`6cca804`**, başlangıç `036fa60` sonrasında **33 commit**. `main` (`5f99f90`) değiştirilmedi, push yapılmadı. Sabah bekleyen dört öğe **`889cab0`** ile kaydedildi; son kapanış belgeleri bu raporun son commit kaydındadır.
- Son başarılı **gece** ortak kaynak kapısı **42. tur**: analiz temiz; Flutter **1417 geçti / 5 isteğe bağlı PNG testi atlandı / 0 hata**, Node **164/164**. Parite aracının ayrı birim paketi **14/14**; native koşular bu sayılara dahil değil.
- Gerçek süreli finaller: iOS 18 normal 25 ve normal 50; iOS 18 gerçek 25 + HTTP503 + farklı süreç; iOS 27 TUS 135 ve aynı hesapta ilk kullanım H27; iOS 18 H18 gerçek25 ve04:00 geçişi; Android2×25 Maraton/V13, doğal LGS Sözel75 ve aynı hesapta ilk kullanım AndroidH. Android finalleri önceden başlatılmış arka plan işleriyle 05:12'de tamamlandı.
- Android **2×50 Maratonun 100 dakika/28 puan/40 kum/4 bonusu kaydedildi**, fakat özgün testin son yardımcı isteği eskimiş JWT nedeniyle başarısız. Aynı kayıtlar üzerinde ayrı **AC postflight 1/1 + parite PASS**; özgün S50 FAIL korunur.
- **Sabah kapanışı tamamlandı:** imzasız iOS Release ve normal uygulamanın iOS18.6'ya veriyi koruyan kurulumu/açılışı; iki fazla QA cihazı ve geçici derleme temizliği; temiz analiz, **1417/5/0 Flutter** ve **164/164 Node**. AB önceki iki FAIL korunur, ayrı verify 1/1+parite PASS. **31 kullanıcı kararı bekliyor; uygulanmadı ve 31 sonrası native test yapılmadı.**
- **31 numaralı Maraton önerisi ana yerel QA'ya veya canlıya uygulanmadı.** İzole 96/96 kontrol ve içerilen 13/13 DRYRUN geçti. Katı 5+1 sınırının gecikmiş dürüst kullanıcıya etkisi ve duraklatılmış AFK açığı aşağıda açıkça ayrıldı.
- **Canlı Supabase/Resend/site isteği, canlı SQL, push ve deploy yok.** Yerel başarı, fiziksel cihaz veya mağaza onayı değildir.

Ayrıntılar: [istekler](ISTEKLER.md), [ilerleme/commit kaydı](CODEX_ILERLEME.md), [doğrulama matrisi](DOGRULAMA_MATRISI_2026-10-28.md), [native QA](QA_NATIVE_GECE_2026-10-28.md), [sunucu QA](QA_BACKEND_GECE_2026-10-28.md), [güvenlik](QA_GUVENLIK_GECE_2026-10-28.md), [ilk kullanım](QA_ILK_KULLANIM_2026-10-28.md), [Maraton kapanışı](QA_MARATON_KAPANIS_2026-10-28.md), [denetçi](DENETIM.md). `/tmp` günlükleri geçicidir; sonuçların kalıcı özeti bu belgeler ve sürümlü test kaynaklarıdır.

## Çalışma ve kesinti zaman çizelgesi

- **27 Ekim 22:26→28 Ekim yaklaşık 04:27:** etkin geliştirme, alt ajan incelemeleri ve test takibi yapıldı. iOS son derleme doğrulaması sırasında alt ajan kullanım sınırına takılınca etkin çalışma kesildi.
- **Yaklaşık04:27→05:12:** daha önce başlatılmış Android R75 ve ilk kullanım H işleri arka planda devam etti; bunlar yeni etkin ajan çalışması değildir. Günlüklerde ikisi de PASS ile bitti.
- **06:30/07:00:** planlanan temizlik ve nihai teslim yapılmadı. 07:00'ye kadar kesintisiz çalışıldığı veya zamanında teslim edildiği iddia edilmiyor.
- **Sabah 09:34:** kullanıcının yalnız mevcut işleri kapatma yetkisiyle çalışma yeniden başladı. Yeni özellik eklenmiyor; 31'in uygulanması kullanıcı kararına bırakılıyor. Sabah kapanışı 09:59 itibarıyla aşağıdaki kanıtlarla tamamlandı.

## 1. Yapılanlar: değişiklikler ve commit'ler

Başlangıç kontrol noktası `036fa60`, önceki `5f99f90` sonrasında birikmiş **575 dosya yolu değişikliğini** topladı. Bu sayı bu gece eklenen özellik veya test sayısı değildir. Sonraki çalışmanın somut özeti:

| Alan | Tamamlanan değişiklik | İlgili commit'ler |
|---|---|---|
| Kapsam ve onboarding | I-01–I-20 kabul ölçütleri; açık TR/EN seçimi, TUS hedefi, dersler ve ekran rehberi | `7bcbb4a`, `af5c338` |
| Sunucu temeli | TUS 27, Deneme 28, tek aylık kategori/Global ligi 29; ayrı cüzdan, owner RLS, katalog/net ve rollback/DRYRUN | `52f5a02` |
| Deneme istemcisi | Kalıcı UUID/journal, katalog, sayaç, başlat/vazgeç/geçmiş/net; beşinci sekme ve normal/Maraton çakışma engeli | `f887933`, `d3d3ee4` |
| Hedef ve lig | Eski sunucuda TUS niyeti; aylık hedef/Global ekranı; dönem dönüşünde güvenli yenileme | `cb68cff`, `d963fcc`, `c263e4f` |
| Rapor | Tamamlanan Deneme dakikası ortak; gerçek seans, Maraton odağı/planı ve 25 dk eşdeğeri ayrı; uzun geçmiş eksiksiz yüklenir | `607595a`, `59f1995`, `f82f999` |
| Dil ve mahremiyet | Açık hata/diyalog/bildirimlerin dil değişimi; hata raporlarında iç içe kişisel verinin maskelenmesi | `1a1ca26`, `cc27330`, `cd756f1` |
| Yarış ve geri yükleme | Geç yanıt yeni kaydı ezmez; hesap geçişi/restore/kalıcı journal kilitleri; eksik geçmişten sahte içgörü üretilmez | `bf507b0`, `b692d98`, `b37899e` |
| D-03–D-05 | İş yokken tüm profilleri kilitlememe; süresi dolmuş Denemeyi tek kez kapatma; TUS/AYT kategori eşlemesi | `901e129` |
| Kum saati | Görsel tasarım eklemeden yaşam döngüsü ve hareket azaltma düzeltmeleri | `80f7ab2` |
| Site ve gerçek medya | Mevcut TR/EN yapı, Deneme/lig açıklamaları, eksik 21 avatar ve gerçek y3 videoları | `6d2b9f0`, `f2c6a7d`, `ccb89da` |
| Yerel QA araçları | PNG bütünlüğü, doğru Date başlıklı kesinti proxy'si, native/gerçek süre ve aynı hesap ilk kullanım sürücüleri | `c0ae947`, `01bf20f`, `de7668a`, `0b9802e` |
| QA güvenliği/derleme | Host Origin/Sec-Fetch/Host koruması; Android iç lint görevini AAB sanan guard düzeltmesi; pozitif içgörü ve Global kontrolü | `b752933` |
| Maraton önerisi 31 | Yalnız duraklatılmamış geç ilk/ara odakta kabul edilen seans sonuna bağlı 300+60 sınırı; mevcut normal ödül korunur | `3fc0fe9` |
| Uzun test sonu | S50'nin test token'ını güncel SDK oturumundan alma; aynı kurulumda ayrı AC doğrulaması | `1e2e8a9` |
| Geçersiz plan açıklaması | TR/EN metin normal seans/puan/kumun korunduğunu, Maraton ek puanı olmadığını açıklar; gecikmeyi kesin neden diye sunmaz | `1cc6a05` |
| Süreç testi doğruluğu | Sunucu–cihaz saat düzeltmesini doğru karşılaştırma; alt çizgili ekran adı düzeltmesi ve tamamlanmış kurtarmayı değiştirmeyen ayrı postflight | `8d2bf7a`, `ffa5d5c` |
| Gece kanıt kontrol noktası | 17doküman,168gerçekPNG ve yanlış sınır yorumunun düzeltilmesi;186dosya yolu. Ürün/DB davranışı değişmedi | `6cca804` |

Son metin değişikliği davranış veya RPC kuralını değiştirmedi. Tek widget testi iki dil ve dört ilk-odak yanıtını dolaşır; ilgili hedefli paket 12/12, son tam 42. kapı 1417/5 geçti. Normal sayaçlar 25/50 dakika, sınavlar standart katalog sürelerinde kaldı. Yeni kullanıcıya açık özellik olarak istenmeyen görsel/akış eklenmedi.

Android R75/H finalleri `6cca804` sonrasında geldi. Kapanışta bu iki ekran klasörü, ilerleme kaydı ve `extend_w_mixed_fixture.py` dahil dört öğe ana ajan tarafından incelendi;10PNG CRC ve yardımcı AST/kapsam kontrolleri geçti. Bu dört öğe **`889cab0`** ile 12 dosya yolu olarak commitlendi. Öncesinde son ortak kapı ve staged dosya/sır kontrolü temiz geçti. Fixture yeniden çalıştırılmadı.

## 2. Sabah kapanışı ve açık kalanlar

| Kapanış işi | Bu rapor hazırlanırken durum | Tamamlanma kanıtı |
|---|---|---|
| Son iOS paket doğrulaması | **TAMAMLANDI** | [iOS kapanışı](QA_IOS_KAPANIS_2026-10-28.md): Flutter Release config 17,14 sn + pinleri koruyan Xcode Release 77,99 sn, çıkış0;55.029.553 bayt imzasız uygulama.9Swift pini/Dart lock/kaynak aynı, boş envasset. |
| Normal iOS uygulama kurulumu/açılışı | **TAMAMLANDI** | `8D0…` iOS18.6'ya normal `lib/main.dart` DEBUG paketi uninstall/erase olmadan kuruldu. PID72227 canlı, gerçek Pomo25:00 ekranı, aynı hesap/H18 tamamlanma işareti korunmuş. [Sonuç](../build/overnight_final_main/ios_normal_main_install_smoke.json). Yerel QA54321, Sentry kapalı. |
| Normal Android main kurulumu/runtime | **Bu kapanışın kapsamı dışında** | Kullanıcı sabah yalnız normal iOS kurulumunu istedi. Android main release/debug derleme/statik sonuçları var; ayrıca Android runtime/normal paket kurulumu yapıldığı iddia edilmez. Gece R75/H native sonuçları ayrı başarıdır. |
| Fazla QA cihazları | **TAMAMLANDI** | [Cihaz kaydı](../build/overnight_final_main/cleanup/device_cleanup.json): `66504…` ve `59F07…` silindi. PomoSprint için yalnız `8D0…` iPhone18.6 ve `PomoSprint_QA_API36` kaldı. Başka projenin `2CFDB…` HocamMacVar cihazı ve runtime'lar korundu. |
| Geçici derleme/cache temizliği | **TAMAMLANDI** | [Temizlik sonucu](../build/overnight_final_main/cleanup/build_cleanup.json), [ayrıntılı liste](QA_TEMIZLIK_PLANI_2026-10-28.md):15yeniden üretilebilir yol kaldırıldı; cache ölçümünde13,52GiB ek boş alan, son142,12GiB. Son paketler/kanıtlar, SwiftPMhedefi/JDK17/globalSDK ve istenenfixturekaynağı korundu. |
| Son ortak test kapısı | **TAMAMLANDI** | Analyze temiz5,29sn; Flutter **1417 geçti/5 isteğe bağlı PNG atlandı/0 hata**,62,28sn; Node **164/164**,0,54sn. [Günlükler/sonuç](../build/overnight_final_main/closing_checks/results.json). Sonrasında ürün kaynakları değişmedi; yalnız rapor/temizlik yapıldı. |
| Bekleyen dört öğe | **COMMITLENDİ — `889cab0`** | İlerleme kaydı,9AndroidH+1R75PNG ve kontrollüfixtureyardımcısı:12dosya.10PNGCRC10/10, PythonAST/güvenli kapsam kontrolü; araç çalıştırılmadı. |
| Son sır/stage kontrolü ve kapanış kaydı | **Son commit kaydında** | Yalnız ilgili kapanış belgeleri kaydedilir; `.env`, anahtar/sertifika/keystore, yerel ayarlar ve DENETIM.md eklenmez. Son hash `git log -1` ile, kullanıcı yanıtında da verilir. `main`e merge/push yok. |

- **31 kullanıcı kararı bekliyor.** Ana yerel QA'ya veya canlıya uygulanmadı; 31 sonrası native AB koşusu yapılmadı. İzole96/96 ve13DRYRUN bu iki eksiği kapatmaz. Sabah yalnız kapanış yapılıyor; paket veya özellik sessizce etkinleştirilmeyecek.
- **D-07 açık:** katı5+1 politikasında uzun bağlantı gecikmesi normal bitmiş seans/puan/kumu korur, Maraton devamı/bonusunu düşürebilir. Açıklayıcı TR/EN metin hazır. Duraklatılmış AFK açığı31 ile kapanmaz.
- **Safari kısmi:** 04:18'e kadar yerel masaüstü TR/EN, görseller, SSS ve oynat/duraklat etiketleri incelendi; video kare ilerlemesi/autoplay ve mobil dar ekran etkileşimi doğrulanmadı. Chrome kullanılmadı. [Safari raporu](QA_SAFARI_2026-10-28.md).
- **Canlı ve mağaza ayrı:** 27–30 yalnız yerel QA'da;31 yalnız izole klonda sınandı. Canlı güncel hash/ACL/RLS/cron, gerçek Resend teslimi, signing/provisioning/TestFlight, Apple/Google girişi ve fiziksel cihazlar bu raporla tamamlanmaz.
- **Operasyon/ürün kararları:** Sentry alarmı/semboller ve HTTP500 yakalama, hosted staging, genel API abuse/fatura koruması, Maraton kill switch'i, normal geçmiş-tarihli offline ödül ve anon waitlist onay/limit konusu açık. Deneme ligi15avatar slotu ve resmî geliştirici/adres/gönderen bilgileri bekliyor.
- **Saat dilimi geçmiş politikası:** rapor güncel profil diliminde yeniden gruplanır, lig olayının kabul günü sabit kalır. Karma geçmişle seyahat tutarlılığı karar/test boşluğudur; tarih/ödül yeniden yazılmadı. [İnceleme](QA_SAAT_DILIMI_SINIRI_2026-10-28.md).

Android R75 ve H **bekleyen test değildir**: gerçek günlükler ve bağımsız kanıtları aşağıda başarı olarak eklendi. İlk r25/r135 uninstall denemeleri, S50 eski yardımcı JWT'si ve iki AB test sürücüsü FAIL'i ise korunur; sonraki ayrı başarılar bunları geçmişten silmez.

## 3. Varsayımlar ve ürün politikaları

Kullanıcının açık kararları varsayım değildir: lig ayı ayın 1'i İstanbul 00:00, çalışma günü/seri 04:00; normal ve Deneme ekonomisi ayrı; netler kişisel; yaş/veli kuralları korunur; bu gece canlıya yazma/deploy yok.

- **Deneme ödülü varsayımı:** tamamlanan her 5 dakika için 1 Deneme puanı, her 25 dakika için 1 Deneme kumu; aşağı yuvarlama. Katalog snapshot'ına yazılır, netlere bağlı değildir. TUS 135=27/5, TYT 165=33/6. Oran sabah ürün kararı olarak gözden geçirilebilir.
- **Vazgeçme:** kayıt ve `elapsed_seconds` geçmişte kalır; tamamlanmamış Deneme süre, seri, tamamlanan adet veya ekonomi üretmez. Süresi dolmuş deneme isteği tek ve idempotent tamamlamaya döner.
- **Süre/dikkat ayrımı:** uygulama kapalıyken sunucu süresi durmaz. Geçen süre kullanıcının fiziksel dikkatinin tasdiki değildir.
- **Lig hazırlığı:** hedefler karışmaz; oda en fazla 25 kişi. Üçten az aktifte hazırlık; terfi ilk `floor(aktif/3)`, en az 3 gün/300 dakika/pozitif puan koşullarıyla. Düşme ve normal avatar ödülü en az 10 aktifte; son 72 saatte katılanın düşme koruması var. Kurallar canlı nüfusla doğal ay boyunca beklenmedi, kontrollü test edildi.
- **Hedef değişikliği:** ilk aktif normal rezervasyon/Denemeden sonra bu ayın oda/puanı korunur, yeni hedef sonraki aya kalır. Etkinliksiz ilk tercih hemen uygulanır.
- **Geç offline kayıt:** kabul edilen eski seans geçmiş süreye eklenir; kapanmış ayın kesinleşmiş kademe/ödülü yeniden hesaplanmaz. Mevcut normal başlangıç/tarih güven politikasının daha sıkı hâli bu gece sessizce devreye alınmadı.
- **Saat dilimi seyahati:** geçerli cihaz IANA adı profile senkronlanır. Rapor geçmişinin güncel dilimle yeniden sınıflandırılması ve ligde saklanan kabul günü farklı yaklaşımlardır; geçmişin sabit mi dinamik mi olması gerektiği henüz kararlaştırılmadı. Toplam süre/ödül kaybı iddiası yok; gün/ay dağılımı ve seri/terfi günlerinin tutarlılığı için karar sonrası karma geçmiş+offline regresyonu gerekir.
- **İçgörü:** yalnız aynı sınav/sürüm/ders ve uygun zaman aralığı karşılaştırılır. İlişkili TUS kategori dakikası ilgili netlere bağlam verir; süre dağıtımı, iki kez toplam veya nedensellik iddiası değildir. Küçük Stajlar için uydurma resmî dağılım yoktur.
- **Koleksiyon:** standart kullanıcı 42 karakter; 7 başlangıç+4 mağaza+21 özel+10 lig görseli. 5 Premium ile aktif katalog 47'dir. 15 boş Deneme slotu bu sayıya eklenmedi. Eski lig kazanımları korunur. [Katalog kanıtı](QA_SITE_AVATARLARI_2026-10-28.md).
- **31 sınırı:** duraklatılmamış ilk/ara odakta kabul edilen bitiş+300/+360 kullanılır. Süresi dolmuşsa normal ödül korunur, plan/bonus geçersiz olur. `p_was_paused=true` eski kabul-anı davranışındadır; meşru duraklama ile AFK/geç gönderim mevcut API'de güvenle ayırt edilemez. Tam çözüm sunucu start/pause/resume defteri gerektirir. [31 kapsamı](../supabase/proposed/31_marathon_completion_anchor_README.md).

## 4. Test sonuçları ve kanıtın sınırları

**B:** saf birim, **W:** widget/sahte servis, **F:** izole SQL/API veya kontrollü geçmiş, **N:** native uygulama/yerel API, **S:** statik kaynak kontrolü. Aynı davranış birden çok pakette sınanır; aşağıdaki sayılar toplanarak benzersiz test veya kullanıcı yolculuğu sayısı üretilmez.

### Ortak kapı ve derlemeler

| Kontrol | Doğrulanmış sonuç | Kanıt / sınır |
|---|---|---|
|Sabah kapanışı analiz|Temiz,5,29sn|[Günlük](../build/overnight_final_main/closing_checks/analyze.log).|
|Sabah kapanışı Flutter|1417 geçti/5 isteğe bağlı PNG atlandı/0hata;62,28sn|[Günlük](../build/overnight_final_main/closing_checks/flutter_test.log).|
|Sabah kapanışı Node|164/164;0,54sn|[Günlük](../build/overnight_final_main/closing_checks/node_test.log).|
|Son iOS Release+normal kurulum|İmzasız55.029.553bayt Release; normal DEBUGiOS18.6kurulum/açılış/veri koruma PASS|[iOS kapanış raporu](QA_IOS_KAPANIS_2026-10-28.md). Yerel QA, fiziksel cihaz/TestFlight değildir.|
|Gece42. tur analiz|Temiz, 8,2 sn|[Günlük](/tmp/pomosprint_checkpoint_42_analyze.log); HEAD `ffa5d5c` ile kaydedilen kaynak.|
|Gece42. tur Flutter|1417 geçti /5 isteğe bağlı PNG atlandı /0 hata; 1:59|[Günlük](/tmp/pomosprint_checkpoint_42_tests.log). Kayıt 3, onboarding 1, sayaç 1 PNG üreticisi isteğe bağlı; native testler bu toplama girmez.|
|Gece42. tur Node|164/164|[Günlük](/tmp/pomosprint_checkpoint_42_node.log); site/kaynak sözleşmeleri, Safari sonucu değil.|
|Ayrı parite araç testi|14/14|[Günlük](/tmp/pomosprint_checkpoint_39_parity.log). Eski referanslar korunur; 31 için açık üçüncü mod vardır. Ana QA'ya 31 kurulduğunu kanıtlamaz.|
|Önceki iOS release|İmzasız derleme geçti; `.app`55,0 MB|[Günlük](/tmp/pomosprint_release_ios_20261028.log). Arm64 ve TimerWidget mevcut; mağaza indirme boyutu/cihaz imzası veya sabah son paket doğrulaması değildir.|
|Önceki Android release|İzole APK geçti; 54.167.363 bayt|[Manifest](../build/overnight_release_android/manifest.json); `ccb89da` arşivi+reviewed Gradle guard yaması. Bu tarihsel QA ikilisi son ürün kaynağının yerine geçmez.|
|Normal Android release/debug|`lib/main.dart`, ürün kaynağı `1cc6a05`; release 54.167.363, debug 128.223.167 bayt; derleme/statik doğrulama PASS|[Release doğrulama](../build/overnight_final_main/android_release_verification.json), [debug doğrulama](../build/overnight_final_main/android_debug_verification.json). İkisi de mevcut debug imzasıyla eşleşir; integration_test yok, boş `.env`, yalnız yerel API. Android normal main kurulum/runtime bu kapanışta talep edilmedi; başarı iddia edilmiyor. R75/H finalleri tamamlandı, verileri korunuyor.|

Android APK'nın SHA-256 değeri `54f1968b0995b24f5f321b8f6609610fbcbc5855901d241b08d946609bc31897`. Önceki başarısız derlemeler saklandı: ilkinde iç lint görevi AAB sanılıyordu; daha sonra `--no-pub` QA komutu release plugin kaydını yenilemedi. Standart `--pub` ile kilitli bağımlılıklar değişmeden derlendi. Bu ikinci hata ürün bağımlılığı kusuru diye sunulmaz. Önceki izole APK farklı debug anahtarı taşıdığından mevcut native veri üstüne kurulmadı. Son normal main derlemeleri ise mevcut debug imzasını doğruladı; gece R75/H bitmeden kurulmadı. Android normal main kurulum/runtime sabah kapanışının kapsamına eklenmedi. Sonraki `8d2bf7a`/`ffa5d5c` yalnız QA sürücüsüdür; ürün kaynağı değişmedi. Release manifestinde yerel HTTP izni yoktur; loopback ağ yapılandırmalı normal debug ikilisi yerel çalıştırma adayıdır, henüz runtime başarısı değildir.

### F/S: yerel sunucu ve yardımcı araçlar

| Paket | Sonuç | Kapsam |
|---|---:|---|
|Deneme backend|52/52|Katalog, owner/RLS, erken ret, UUID/çakışma, ayrı ekonomi/net; izole özel katalogda gerçek 60 sn server-clock deneyi.|
|Aylık kategori/Global|21/21|26 eşzamanlı ilk tamamlama→25+1 oda; kontrollü ay kapanışı/terfi/düşme/ödül.|
|Geçiş/rapor metadata|20/20|Eski geçmiş/ödül, normal/Maraton/Deneme ayrımı; Deneme fixture'ı 02:30–03:50 ile tümüyle 04:00 öncesindedir, sonraki 05:00 normal odağı iki çalışma gününü sınar. Denemenin kendisi sınırı geçmez.|
|Mahremiyet/retention|26/26|Ters/karşılıklı engel, yetkisiz yazma, hesap silme/arşiv temizliği.|
|Hedef rezervasyonu/geç kayıt|15/15|Aktif rezervasyon, sonraki ay hedefi, kapanmış ay kararının korunması.|
|Migration/down/DRYRUN|16/16|27–29 sıra/gövde/geri alma ve şema/ACL/cron eşitliği.|
|D-03/D-05|25/25|İş yokken profil kilidi almama, süresi dolmuş Deneme toparlama.|
|Başlangıç önerisi 30|31/31|Kota/UUID/metadata yarışları; içerilen 10 DRYRUN tekrar sayılmaz.|
|Ekonomi/yetki güvenliği|41/41|Profil/cüzdan/avatar yazma reddi, satın alma yarışları, duplicate/çakışma; bilinen riskler açık.|
|Doğrudan Global|46/46|İki LGS+iki TUS; iki lig türünde exact-owner kümeleri, Global'de dört kullanıcı, ekonomi değişmezliği.|
|Maraton önerisi 31|96/96|İzole geç-kabul sınırı, 25/50, gerçek ACK çağrıları, tekrar/yarış/rollback; içerilen DRYRUN 13/13. Native doğal süre değildir.|
|QA host güvenliği/PNG|28/28|16 HTTP Origin/Sec-Fetch/Host +12 PNG bütünlüğü; yan etkiler mock.|
|HTTP kesinti proxy'si|10/10|Tek Date başlığı, soket/503, admin ve log mahremiyeti.|
|Yerel Mailpit yardımcıları|16/16|Signup/onay/login, yanlış alıcı/host/redirect reddi; canlı SMTP değil.|
|Medya aracı|18/18|Manifest/sahne/encode korumaları; gerçek dosyalar ayrıca decode/hash/görsel kontrolden geçti.|
|Eski sunucu istemci sözleşmesi|105/105|Sekiz hedefli test dosyasında missing-RPC/eski API ve güvenli fallback. Yeni tam eski-sunucu HTTP E2E yapılmadı; mevcut harness ana Auth'a yan etki yapabileceği için çalıştırılmadı.|

Kaynaklar: [backend](QA_BACKEND_GECE_2026-10-28.md), [güvenlik](QA_GUVENLIK_GECE_2026-10-28.md), [Global](QA_GLOBAL_KAPSAM_2026-10-28.md), [eski sunucu sınırı](QA_ESKI_SUNUCU_UYUMU_2026-10-28.md), [31](../supabase/proposed/31_marathon_completion_anchor_README.md). Eski Global testi yalnız fazla satır sayıyordu; 46/46 paket farklı hedeflerin UID kümelerini doğrudan denetledi. Eski 31 davranışında 6 kontrol ve 1 beklenen güvenlik FAIL, ardından gerçekten 300 sn bekleyip taze onayın kabulü kaydedildi; 96/96 yeni öneri sonucudur.

### N: gerçek süreler ve kontrollü geçmiş

| Koşu | Sonuç | Kesin sınır |
|---|---|---|
|iOS 18 normal 25|Başlangıç/final ayrı 1/1+parite; 1500 sn, tek 25 dk/5 puan/20 kum/1 seri/1 lig olayı|23:55→00:20 takvim gece yarısı; 04:00 veya ay sınırı değil. [Final](../build/overnight_backend/real25_final_verified.json).|
|iOS 18 normal 50|Final 1/1+parite; 3000 sn, kapalı uygulama/cihaz sonrası tek 50 dk/12 puan/20 kum/1 seri/1 olay|İlk tarihler/UUID korundu, duplicate ödül üretmedi. [Final](../build/overnight_backend/real50_final_verified.json).|
|iOS 27 TUS 135|Ara açılış ve final ayrı 1/1+parite; 8100 sn, 135 ortak dakika/27 Deneme puanı/5 Deneme kumu/1 seri, normal ekonomi 0|Aynı server başlangıç/bitiş ve tek olay; ilk uninstall koşusu geçersiz. [Final](../build/overnight_backend/real135_final_verified.json).|
|iOS 18 W HTTP503|Başlangıç/final ayrı 1/1+parite; 1505 duvar sn, doğal 25 dk diskte kaldı, farklı süreçte tek ödül; gün/hafta/ay UI–SQL eşit|Son 430 dk=405 kontrollü+25 doğal. Normal 22 puan/80 kum; Deneme 66/12 değişmedi. Fiziksel uçak modu değil. [Final](../build/overnight_backend/w_final_verified.json).|
|Android S25|1/1+parite; 3351 duvar sn, 2×25 dk+300 sn mola+60 sn içinde onay; 50 dk/12 puan/40 kum, son odakta+2 bonus|Haftalık 2 Maraton odağı/1 plan ve lig 12; duplicate sabit. [Log](/tmp/pomosprint_android_s25_12.log).|
|Android V13|1/1+parite; 1906 duvar sn, 25 dk+300 sn mola+60 sn cevapsız onay; tek 25 dk/5 puan/20 kum/0 bonus, ikinci odak yok|Poll başlangıcı geç olduğu için logda 297/58 sn görünür; sunucu aralıkları 300/60. İlk odak zamanında kabul edildi; geç ilk kabul/paused yolu değildir. [Log](/tmp/pomosprint_android_v_13.log).|
|Android S50|Özgün koşu **FAIL**; iki gerçek 3000 sn odak+300 sn mola/onay ve final kaydı 100 dk/28 puan/40 kum/4 bonus|Son duplicate RPC eski test JWT'siyle 401/PGRST303; rapor/lig adımına ulaşmadı. [Özgün log](/tmp/pomosprint_android_s50_14.log).|
|Android AC postflight|Ayrı 1/1+parite; aynı korunmuş S50 kaydı, taze owner-validated token, duplicate sabit; haftalık UI 100 dk/2 odak/1 plan; `RankingStandings`28|Yeni hesap/fixture/reset veya 105 dk tekrar yok. Lig görüntüsünde bilgi katmanı açık; görünür sıralama kanıtı değildir. [Log](/tmp/pomosprint_android_ac_01.log).|
|iOS 27 H ilk kullanım|1/1+parite; aynı yeni hesapta UI kayıt→Mailpit→giriş→TUS rehber→gerçek 25→rapor→TUS başlat/erken ret/vazgeçme; 1503 duvar sn|25 dk/5 puan/20 kum/1 seri; Deneme ödülü 0, fixture yok. `crossed_04_boundary=false`. [Final](../build/overnight_backend/first_use_ios27_final.json).|
|iOS 18 H ilk kullanım / gerçek 04:00|1/1+parite; 1503 duvar sn, 03:44:57–04:09:57 İstanbul; 25 dk/5 puan/20 kum/1 seri/tek kayıt/tek olay|[Bağımsız final](../build/overnight_backend/first_use_ios18_final.json): başlangıç çalışma günü 27 Ekim, 28 Ekim günlük0 ve haftalık/aylık25. Hedef saat veya fixture değil; normal 25 dakikadır, Deneme/ay/seyahat kanıtı değildir.|
|AB önceki şema: geç kabul + kurtarma|İki ayrı **FAIL**: ham sunucu/cihaz zamanı eşitliği yaklaşık130ms farkla; ardından tamamlanmış kurtarma ekran adındaki alt çizgi nedeniyle host400|[İlk FAIL](/tmp/pomosprint_ios27_ab_before_break.log), [kurtarma FAIL](/tmp/pomosprint_ios27_ab_before_recovery.log). Korunan kayıt: tek25dk/5puan/20kum, onaysız gate, ikinci odak yok. Ayrı [verify](/tmp/pomosprint_ios27_ab_before_verify.log) **1/1+parite PASS**: PID15773→19986, aynı owner, tek25dk/5puan/20kum, boş timer/kuyruk/ret, aynı gate; tamamlanmış proof değişmedi. Özgün iki FAIL korunur; doğal bekleyiş tekrarı değildir.|
|Android LGS Sözel75|Final **1/1+parite PASS**, doğal4500sn;03:29:56→04:44:56, farklı süreçte aynı Deneme/UUID/tarihler;75ortak dakika/15Deneme puanı/3Deneme kumu/seri1, normal ekonomi0|[Günlük](/tmp/pomosprint_android_r75_resume_01.log), [bağımsız final](../build/overnight_backend/real75_final_verified.json). Tek tamamlanan Deneme/lig olayı,27Ekim başlangıç çalışma günü; doğal Deneme04:00 geçişi. Ay/DST/seyahat veya tüm sınav kataloğu kanıtı değildir.|
|Android H ilk kullanım|**1/1+parite PASS**; tüm test25:57, odak1503duvar saniyesi/25dk. Aynı UI kayıtlı hesap, Mailpit/onboarding, normal25/5puan/20kum/seri1, gün/hafta/ay rapor ve erkenTUSvazgeçme|[Günlük](/tmp/pomosprint_android_first_use_h1.log), [bağımsız final](../build/overnight_backend/first_use_android_final.json).04:46:37→05:11:37TR;28Ekim çalışma günü, Deneme ödülü0; fixture yok.04:00 sınırını geçmez.|
|31 sonrası native AB|**YAPILMADI; kullanıcı kararı bekliyor**|31 anaQA/canlıya uygulanmadı. Önceki şema ABverify veya izole96/96 sonucu bunun yerine sayılmaz.|
|iOS/Android O2 ve AA|O2 net/yatay/kayıt/haftalık rapor; iOS 18 AA ve Android AA ayrı 1/1+parite, Profil TR/EN ve pozitif içgörü|O2'de 2×165 dk, AA'da 355 dk geçmiş kontrollü. AA 25 ilişkili dakika ve 19,25→27,50/19.25→27.50 cümlesi/uyarısı; doğal bekleyiş değildir.|
|iOS 18 Z|İki senaryo 2/2+parite: gelen arkadaş isteği kabul/ret; 500 kum avatar alma/kuşanma ve duplicate ücret yok|Finansman 25 tarihli normal RPC kaydıyla 625 dk/500 kum; doğrudan bakiye ataması yok, 625 dk beklenmedi.|

Diğer native kapsam: iOS 27 yedi onboarding hedefi geçti; Android ilk dört hedef `a_02` içinde, dil/üniversite/iş ayrı başarılı koşularda doğrulandı. Tek Android turuna 7/7 denmez. iOS/Android Q her birinde **tek gözlemci+8 yerel API hesabı** ve doğal sosyal yenilemedir; sekiz cihaz değildir. iOS G2 parola yenileme yerel Mailpit/Auth kullanır. M/D/L/N/E kategori, arkadaşlık, onay, engel, raporlama ve hesap silme turları ayrı 1/1+parite geçti. L'nin New York/DST kısmı mock platform değeridir; E'de yerel Edge 404 sonrası RPC yedeği çalıştı. Android J ve iOS K yerel bildirim/iptal/ActivityKit kontrolleridir; APNs, fiziksel Doze veya gerçek ses/banner garantisi değildir.

Kum saati `p_01` ölçümü debug simülatörde p99 build 3,315 ms/raster 1,32 ms ve 16,67 ms üzeri kare 0 gösterdi. Release FPS, pil veya bütün uygulama performansı garantisi değildir. Android T kısa turu 50 dakika modunda duraklat/devam/ikinci hak reddi/iptali doğruladı; tamamlanmış 50 dakika kanıtı ayrı iOS normal 50 koşusudur.

Başarısız eski koşular ayrı durur: r25/r135 uninstall marker kaybı, Android bağlantı/tıklama zaman aşımı, iOS O2 yanlış test alanı/SQL'i, AA ilk sorguda yanlış `catalog_version`, eski medya sürücü kadrajları, Global klon ilk kurulum denemeleri, S50 test token'ı ve AB ham saat eşitliği/ekran adı hataları. Son başarılar bunları geriye dönük PASS yapmaz. [Tam koşu ayrımı](QA_NATIVE_GECE_2026-10-28.md).

### I-16–I-19 eşlemesi

| İstek | B/W/F kanıtı | N kanıtı ve açık kalan sınır |
|---|---|---|
|I-16 hedef/Global aylık lig|Kategori/owner/kind ayrımı, 26→25+1 kapasite, kontrollü terfi/düşme/ödül, aktif rezervasyonda sonraki ay, Global 46/46 exact-owner ve ekonomi değişmezliği|iOS 18 X change+ayrı process resume her biri 1/1+parite: YKS oda/puan korunur,TUS sonraki ay; iki Global görünüm sabit. Doğal ay kapanışı, canlı cron/nüfus ve Android X yolu bekler.|
|I-17 onboarding rehberi|TR/EN açık seçim, owner kapısı, küçük/yatay/2× yazı, tercih koruma/tek kaydetme; yaş/13 altı regresyonları|iOS 27 yedi hedef, Android yedi hedef ayrı koşular; H27 ve H18 aynı UI kayıtlı hesapla ayrı ilk gerçek kullanım; H18 doğal04:00 geçişi de doğrulandı. AndroidH de arka plan koşusunda tamamlandı; doğal odak25, tüm test25:57. Native turlar yetişkin yıl kullanır; veli/assistive-tech kapsamı tamamlanmış sayılmaz.|
|I-18 dil|ARB/placeholder, dar görünür metin taraması, sunucu adları, açık hata/diyaloglar, net virgül/nokta, bildirimde değişmeyen bitiş; yeni Maraton açıklaması iki dil/dört yanıt|O2 iki platform; AA iOS 18 ve Android'de Profil'den TR/EN ve içgörü/uyarı. Q dil servisiyle değişir, gerçek Profil yolu diye sayılmaz. Her hata/erişilebilirlik kombinasyonu tüketilmedi.|
|I-19 ortak süre/ayrı ekonomi|340 dk model fixture'ı; gerçek seans/Maraton planı/Deneme/25 dk eşdeğeri ayrı; 04:00/TZ/DST; UUID/outbox; net-ekonomi ayrımı; eksik/201 kayıt geçmişi|R25/R50/TUS 135 gerçek finaller; W doğal 25+karma rapor; S25/V13 ve S50+ayrı AC; H27/H18. H18 normal25 gerçek04:00 geçişini kanıtlar. Android LGS75 doğal Deneme04:00 geçişini, AndroidH aynı hesap ilk kullanımını doğruladı. Doğal ay kapanışı yok;31 sonrası AB kullanıcı kararı nedeniyle yapılmadı; kabul edilmiş geçmişle saat dilimi seyahati politika/test boşluğudur.|

Birim testte tarih değiştirmek, native cihaz saatinin değiştirildiği veya doğal ay/DST geçişinin beklendiği anlamına gelmez. Fiziksel cihaz kapsamı bu gecede kapatılmadı.

## 5. Sabah onayını bekleyen sunucu paketleri

**Hiçbiri canlıya uygulanmadı.** Sabah güncel canlı gövde/hash/ACL/cron ön koşulları ayrı doğrulanmalı; uyumsuzlukta guard kaldırılmaz. Toplu `db push/reset` yapılmaz. Her adım önce kendi DRYRUN'ı, sonra kullanıcı incelemesiyle ileri dosyasıdır.

| Sıra | DRYRUN | İleri | Geri alma | Amaç |
|---|---|---|---|---|
|1|[27 DRYRUN](../supabase/proposed/27_tus_segment_dryrun.sql)|[27 ileri](../supabase/proposed/27_tus_segment.sql)|[27 down](../supabase/proposed/27_tus_segment_down.sql)|TUS; eski altı hedef korunur.|
|2|[28 DRYRUN](../supabase/proposed/28_exam_core_dryrun.sql)|[28 ileri](../supabase/proposed/28_exam_core.sql)|[28 down](../supabase/proposed/28_exam_core_down.sql)|Deneme, katalog/net, RLS ve ayrı ekonomi.|
|3|[29 DRYRUN](../supabase/proposed/29_monthly_competitions_dryrun.sql)|[29 ileri](../supabase/proposed/29_monthly_competitions.sql)|[29 down](../supabase/proposed/29_monthly_competitions_down.sql)|Tek aylık hedef/Global şema ve eski dönem geçişi.|
|Bağımsız|[30 DRYRUN](../supabase/proposed/30_session_start_atomic_dryrun.sql)|[30 ileri](../supabase/proposed/30_session_start_atomic.sql)|[30 down](../supabase/proposed/30_session_start_atomic_down.sql)|Normal başlangıç kota/UUID atomikliği.|
|Ayrı karar|[31 DRYRUN](../supabase/proposed/31_marathon_completion_anchor_dryrun.sql)|[31 ileri](../supabase/proposed/31_marathon_completion_anchor.sql)|[31 down](../supabase/proposed/31_marathon_completion_anchor_down.sql)|Duraklatılmamış geç ilk/ara odak için kabul edilmiş son+300/+360.|

**29 zamanlaması:** paket, uygulandığı ayı izleyen ayın1'i **00:00 Europe/Istanbul** anında etkinleşir. **31 Ekim 23:59'dan önce** uygulanırsa hedef **1 Kasım 2026**; Kasım içinde uygulanırsa **1 Aralık 2026** olur. O zamana kadar eski 14 günlük lig sürer. Takvim tarihi kurulum yapılmış gibi yazılmamalı; bu gece/sabah canlı uygulama yapılmadı.

DRYRUN sonundaki **`DRYRUN_RESULT` hatası bilinçli rollback** sonucudur; önceki bütün Txx değerleri `true` olmalıdır. `\echo`/`\quit` korumaları ve SQL Editor uygulaması [kurulum rehberinde](../supabase/proposed/NIGHT_20261028_README.md) açıklanır. [API sözleşmesi](../supabase/proposed/EXAM_API_CONTRACT.md) ayrı tutulur.

27–29 bağımlı zincirinde geri sıra 29→28→27; 30 kendi down'ıyla döner. 29 işlenmiş sonuç/aktivasyon/bekleyen tercih, 28 Deneme/cüzdan, 27 TUS profili varsa veri kaybını önlemek için geri almayı reddeder; veriler silinerek zorlanmaz. 31 kuruluysa önce 31 geri alınır. 31 down mevcut seans, makbuz ve geçersizlik kararını geri yazmaz; yalnız gelecek çağrıları eski fonksiyona döndürür.

**31/D-07 karar noktası:** Katı sınır seçilirse uzun ağ gecikmesinde dürüst kullanıcının da yalnız Maraton devamı/bonusu sona erebilir; normal bitmiş odak korunur. Daha toleranslı offline politika seçilecekse güvenilir server start/pause/resume modeli ayrıca tasarlanmalıdır. Bu geceki mesaj değişikliği bu kararın veya duraklatılmış açığın çözüldüğü anlamına gelmez. 31 ana QA'ya veya canlıya kurulmadı; Android finallerinin bitmiş olması uygulama yetkisi değildir. **Kullanıcı D-07 kararından sonra** ayrı değerlendirilir; olası gelecekteki31 sonrası native/parite sonucu ayrıca kaydedilmelidir.

## 6. Deploy bekleyen site değişiklikleri

**D-06 yayın sırası:**27→28→29 canlı doğrulama/uygulama → yeni uygulama sürümü → site deploy'u. 30 ve 31 ayrı karar paketidir. Site bu gece yayımlanmadı.

Mevcut TR/EN ana sayfa/Özellikler/SSS yapısı korundu. Deneme/TUS, süre–net, aylık hedef/Global, Kumu akıt ve 42 karakter anlatımı güncellendi. Hero ilk boyamada görünür; title/H1/alternates/sitemap, POST form/onay/yasal linkler, menü/SSS ve public sıralamanın boş/eksikRPC/hata halleri kaynak testindedir. Sahte kullanıcı/yorum/çıkış tarihi veya mağaza rozeti eklenmedi. 21 özel avatar, uygulamanın gerçek PNG'lerinden 160×160 WebP'ye dönüştürüldü; toplam 79.918 bayt, kırpma/yeniden çizim yok. [Avatar kanıtı](QA_SITE_AVATARLARI_2026-10-28.md).

`ccb89da` içindeki **y3 gerçek native videoları** mevcut üç video alanını yeniledi. Normal ve Maraton sahneleri, 17 gerçek dokunuş, beyaz imleç; renkli test artısı yok. 540×1170/24fps/H264/yuv420p, sessiz; 205.761 ve 199.294 bayt. Tam decode/hash, poster ve seçili kareler doğrulandı. Hız değiştirilmedi; demo seansları ödül almadan iptal edildi. [Manifest](../landing/videos/manifest-20261028.json), [araç/medya QA](QA_SITE_VIDEO_TOOLS_2026-10-28.md), [ekran kaynakları](../landing/screenshots/README.md).

Son Node 164/164, gerçek Safari sonucu değildir. Safari'de 03:45–03:53 ve 04:16–04:18 yerel TR/EN masaüstü sayfalar, SSS aç/kapa ve mevcut video karesi/imleç incelendi. Video düğmesinin adı değişti; kare ilerlemesi/otomatik oynatma doğrulanmadı. Koordinat eylemleri `noWindowsAvailable`, Responsive Design Mode devre dışı; mobil menü/dar ekran ve video hareketi açık. Önceki `cgWindowNotFound` denemeleri korunur; Chrome kullanılmadı. Geçici Range önizleme10/10 ve mevcut Worker Range15/15, video oynatma kanıtı değildir. [Safari ayrıntısı](QA_SAFARI_2026-10-28.md). Yerel preview ve statik doğrulama canlı deploy sayılmaz.

## 7. Denetçi bulgularının son durumu

Son okunan bağımsız commit turu **04:48**, `ffa5d5c`/`6cca804`; ayrıca **07:18 sabah özeti ve09:40 düzeltmesi** okundu. [DENETIM.md](DENETIM.md) değiştirilmedi. Denetçi notları son kaynak kapısı ve native sonuçlardan ayrı delildir.

| Bulgu | Durum | Açıklama |
|---|---|---|
|D-01 Eski sunucuda TUS niyeti|Çözüldü|`cb68cff`; UID bazlı kalıcı niyet ve güvenli tekrar, 27 ilk kurulum.|
|D-02 Logo decode boyutu|Çözüldü|`cb68cff`; gerçek gösterim×DPR `cacheWidth`.|
|D-03 Her gece bütün profilleri kilitleme|Çözüldü|`901e129`; iş yoksa kilitsiz dönüş, kilit altında tekrar kontrol.|
|D-04 TUS/AYT kategori eşlemesi|Çözüldü|`901e129`; SQL/JSON/Dart eşitliği, alias/çift sayım testleri.|
|D-05 Süresi dolmuş aktif Deneme|Çözüldü|`901e129`; aynı kuralla tek tamamlanma, DRYRUN.|
|D-06 Yeni site için yayın sırası|Kabul edildi, deploy bekler|Sunucu 27–29 ve yeni uygulama yayını tamamlanmadan site yayımlanmaz.|
|D-07 Katı Maraton sınırında bağlantı gecikmesi|Kullanıcı kararı bekliyor|31 normal seans/puan/kumu korur; süreyi aşan planın ek puanı ve devamı sona erebilir. Neden uydurmayan açıklama `1cc6a05` ile hazır; 31 henüz uygulanmadı.|

Duraklatılmış Maraton AFK açığı ayrı ve açık kalır. Normal geçmiş-tarihli offline ödül ve anon waitlist riskleri de 41/41 güvenlik paketinin yeşil olmasıyla kapanmış sayılmaz. Denetçi04:48 turunda yeni bulgu bildirmedi;09:40 düzeltmesinde AndroidH/R75 finallerini PASS olarak düzeltti ve etkin çalışmanın yaklaşık 04:27'de kesildiğini arka plan işlerinden ayırdı. Native koşuları kendisi yeniden çalıştırmadı; sabah yeni kurulum/temizlik/son kapı henüz onun tarafından doğrulanmış sayılmaz.

## 8. Kullanıcı kararı ve yayın için sonraki adımlar

1. **31/D-07 kararını ver.** Katı5+1 kuralının uzun offline gecikmede Maraton bonusunu/devamını bitirme etkisi açık. Normal tamamlanan odak ve ödülü korunur; duraklatılmış AFK için ayrı güvenilir sunucu defteri gerekir. Karar verilmeden31 uygulanmaz;31 sonrası native test yapılmış sayılmaz.
2. **Sunucu sırasını incele:**27→28→29; bağımsız30;31 yalnız karardan sonra. Her pakette önce güncel canlı ön koşul/hash ve DRYRUN, sonra kullanıcı SQL Editor uygulaması.29 için31Ekim23:59/1Kasım etkinleşme tarihine dikkat et. Toplu db push/reset veya guard kaldırma yok.
3. **Deneme ligi görselleri ve resmî bilgileri tamamla:**15boş avatar slotu, geliştirici/veri sorumlusu/adres/gönderen kimliği son aşamada kullanıcıdan alınacak.
4. **D-06 yayın sırasını koru:**27–29 canlı doğrulama/uygulama→yeni uygulama sürümü→site deploy'u. Site bu raporla yayımlanmadı; Safari mobil/video hareketi açık kısmı ayrıca kontrol edilir.
5. **Fiziksel iOS/Android ve operasyon turunu planla:**kilit/force-kill/izin reddi/Doze/düşük bellek, gerçek bildirim/Canlı Etkinlik, Google/Apple girişleri, imza/TestFlight; Sentry alarm/semboller, gerçek posta teslimi, staging/kota/backup/izleme.

### Sabah kapanışının son kaydı — 09:59 Europe/Istanbul

Bekleyen dört öğe `889cab0` içinde kaydedildi. İmzasız iOS Release, normal iOS18.6 uygulama kurulumu/açılışı, iki fazla QA cihazı ve15geçici/araçıktı yolunun temizliği tamamlandı. Aynı hesap ve kayıtlar korundu; yerel QA kurulumu kullanılıyor. Son ortak kapı temizdir: analyze,1417/5/0Flutter,164/164Node. Son ürün kodu değişmedi; bu rapor ve ilgili kapanış belgeleri son commit'te saklanır.31kullanıcı kararı bekliyor; uygulanmadı/sonrası test yapılmadı. Push, main merge veya canlı değişiklik yok.
