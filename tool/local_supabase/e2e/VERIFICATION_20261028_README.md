# 28 Ekim 2026 — Yerel native uygulama ve veri doğrulaması

Bu rehber A doğrulama senaryolarını yeniden çalıştırmak içindir; tamamlanmış sonuçların raporu değildir. Sonuç ve bekleyen işler [ana doğrulama raporunda](../../../analiz/DOGRULAMA_RAPORU_2026-10-28.md) tutulur. Burada bir komutun bulunması onun bütün cihazlarda geçtiği anlamına gelmez.

Yalnız yerel Supabase ve uydurma QA hesapları kullanılır. Canlıya bağlantı, deploy, üretim anahtarı, `.env` okuma veya gerçek hesap temizliği yoktur. Ana yerel sunucuda **27–30 kurulu, 31 kurulu olmamalıdır**; 31 kullanıcı kararı bekler. Sayaç hızlandırması normal uygulamaya eklenmez.

## Kanıt türleri

| Kanıt | Ne gösterir? | Neyi göstermez? |
|---|---|---|
|R gerçek LGS Sözel 75 dk|Gerçek 4500 saniye, OS kapaması sonrası aynı attempt, doğal bitiş ve tek ödül|Diğer altı resmî sınavın tam süresinin de beklendiğini|
|AD/R kısa katalog 60 sn|Gerçek 60 saniye ve gerçek RPC; tamamlama/net/OS/offline yolları|75/135/165/180 dakikalık doğal bekleyişi|
|Kontrollü geçmiş|Public RPC ile puan/kum/rapor/lig; açıkça etiketli geçmiş başlangıç ve yeni attempt/gate metadata'sı|Tarihlerin cihazda doğal beklenmesini, ay dönümünü canlı beklemeyi|
|AF sosyal|Bir native gözlemci ve API ile yönetilen en az üç hesap; I08 fixture'ında sekiz arkadaş|Sekiz eşzamanlı native cihazı|
|Unit/widget/izole SQL|04:00, ay, saat dilimi, dedup, hata ve muhasebe sözleşmeleri|Gerçek OS kapaması veya gerçek bildirim teslimini|

## Ön koşullar ve portlar

Kurulumun eski snapshot→27–30 sırası için [yerel altyapı rehberi](../README.md) ve [paket rehberi](../../../supabase/proposed/NIGHT_20261028_README.md) okunmalı. `supabase start` tek başına 27–30 kurmaz. Mevcut QA veritabanında `db reset`, toplu `db push`, Auth temizliği veya guard kaldırma yapılmaz.

- Flutter/Dart bağımlılıkları ve yerelleştirme (`l10n`) çıktıları hazır olmalı; bu makinedeki güncel iOS ortamı Xcode ve iOS 27.0 runtime, Android ortamı SDK 36 ve JDK 17'dir. 28 Ekim'e ait iOS 18.6 sonuçları tarihsel kanıttır.
- 29 Ekim temizliği sonrası yalnız paylaşılan **HocamMacVar · iPhone 17 (iOS 27.0)** (`2CFDB5C8-6CA6-457C-8A6E-864B1849C681`) ve **PomoSprint_QA_API36** Android emülatörü tutulur. Fiziksel cihaz kullanılmaz. Paylaşılan iPhone'daki mevcut PomoSprint/Hocam uygulamaları, hesaplar ve taslaklar korunur; reset/hesap değiştiren testler **ayrı QA uygulama kimliğiyle** çalıştırılır, normal uygulama veya cihaz silinmez.
- Aynı anda tek Flutter derleme/test komutu çalıştırın. Aynı cihazdaki bitmemiş probe sırasında başka hesap açan/reset yapan senaryo başlatmayın.

`tool/local_supabase/e2e/sim/build_site_media_20261028.py` ve ilgili kaynak manifestleri, gerçek iOS 18.6 çekiminin tarihli tarifidir; güncel cihaz yapılandırması değildir. Bu dosyalardaki eski cihazı yeni çekim için doğrudan kullanmayın. Güncel sabit host hedefi `exam32_host.py` içindedir; tarihsel çekim bilgileri değiştirilmez.

| Hizmet | Host loopback portu |
|---|---:|
|Ana Supabase API / PostgreSQL|54321 /54322|
|Studio / Mailpit|54323 /54324|
|Kesinti proxy'si / admin|54325 /54326|
|AE eski sunucu gateway / REST / Auth|54341 /54342 /54343|
|iOS / Android E2eHost örneği|54399 /54398|

Repo kökünden cihazları açıkça seçin. UUID/serial yeni makinede farklı olabilir:

```sh
xcrun simctl list devices available
adb devices
export SIM_UDID='2CFDB5C8-6CA6-457C-8A6E-864B1849C681' # Önce bu makinedeki cihaz listesiyle doğrula.
export ANDROID_SERIAL='emulator-5554'
TASK_QA_RUN="verify-$(date +%m%d%H%M%S)"
```

`SIM_UDID` değerini listeden gerçek QA UUID'siyle değiştirin; Android serial'ının doğru AVD'ye ait olduğunu kontrol edin. Gerekirse kendi kurulu JDK 17 yolunuzu `JAVA_HOME`/Flutter ayarına verin.

```sh
bash tool/local_supabase/parity_check.sh --reviewed-night-20261028-with-start-atomic
```

Bu komut kayıtlı yerel 27–30 referansını karşılaştırır; canlıyı okumaz. Bu rehberde wrapper'lara `E2E_REVIEWED_NIGHT=2` verilir. 31 referansı olan değer 3 kullanılmaz.

İki wrapper URL ve **açık yerel demo anon** anahtarını birlikte dart-define olarak verir. Service-role veya `.env` şablonu kopyalamak gerekmez; yerel override nedeniyle Sentry varsayılan olarak kapalı kalır. Android wrapper yalnız seçilen emülatörün gereken `adb reverse` portlarını kurar ve çıkışta kaldırır. `--no-uninstall` uygulama verisini süreçler arasında korur.

### Bitmemiş veriyi koruma

R başlangıcının guard'ı bitmemiş süre probe'larını, aktif odak sayaçlarını, bekleyen seans kuyruğunu ve aktif/bekleyen Deneme journal'ını korur. Diğer resetli senaryolar öncesinde de bu koşulların sağlanması zorunludur; bütün tarihsel testlerin aynı guard kapsamını taşıdığı varsayılmaz. Guard reddederse **prefs.clear, uygulamayı silme, hesabı silme veya marker silme yapmayın**. Önce aynı `E2E_RUN_ID` ile ilgili `resume` yolunu tamamlayın. Sonuç başarısızsa mevcut disk kaydını koruyup sebebi inceleyin; yeni hesap açarak başarısızlık gizlenmez.

## Önerilen sıra

1. Resmî katalog ve 27–30 paritesini doğrulayın; mevcut bitmemiş probe'ları tamamlayın.
2. AD `official` koşularını iki platformda çalıştırın. Yeni gerçek 75 dk R koşusunu başlatıp aynı cihaz/veriyle doğal finalini alın.
3. Gerekli kontrollü rapor/lig fixture'larını resmî katalog açıkken hazırlayın.
4. Tek sorumlu tarafından yönetilen kısa katalog penceresinde AD `short` ve R offline döngülerini çalıştırın.
5. Hata/iptalde de katalog ve bağlantıyı geri yükleyin; resmî katalog eşitliği ve 27–30 paritesi tekrar geçmeden devam etmeyin.
6. AD `reports`, AF ve ayrı eski sunucudaki AE'yi çalıştırın. Sonuçları bağımsız oracle ve loglarla raporlayın.

## AD: resmî katalog, kısa tamamlanma ve raporlar

Dosya: `integration_test/ad_verify_reports_exams_test.dart`. `E2E_VERIFY_PHASE` yalnız `official`, `short`, `reports` alır; varsayılan `official`dır. Bir faz çalışınca diğer iki test bilinçli atlanır. Logdaki `+1 ~2` üç fazın geçtiği anlamına gelmez.

### Resmî katalog — `official`

Yedi sınavın her biri TR ve EN'de başlatılır: TYT, AYT, YDT, LGS Sözel/Sayısal, TUS Temel/Klinik. Süre ve soru, 3-2-1, mola/duraklatma olmaması, erken bitiş reddi, ödülsüz vazgeçme/geçmiş ve normal/Maraton ile iki yönlü çakışma denetlenir. TYT'deki widget ağacını yeniden kurma, OS force-stop ile aynı kanıt değildir.

```sh
SIM_UDID="$SIM_UDID" E2E_HOST_PORT=54399 E2E_REVIEWED_NIGHT=2 \
  E2E_API_PORT=54321 E2E_RUN_ID="$TASK_QA_RUN-ios-official" \
  E2E_VERIFY_PHASE=official \
  bash tool/local_supabase/e2e/sim/run_sim_e2e.sh ad

ANDROID_SERIAL="$ANDROID_SERIAL" E2E_HOST_PORT=54398 E2E_REVIEWED_NIGHT=2 \
  E2E_API_PORT=54321 E2E_RUN_ID="$TASK_QA_RUN-android-official" \
  E2E_VERIFY_PHASE=official \
  bash tool/local_supabase/e2e/sim/run_android_e2e.sh ad
```

### Kısa doğal tamamlanma — `short`

**Yalnız aşağıdaki kısa katalog protokolü kurulmuşken** çalıştırılır. Her sınav iki dilde gerçekten 60 saniye beklenir; tek tamamlanma/tekrar gönderim, tüm derslerin netleri, kısmi giriş/düzeltme, otomatik/elle boş, geçersiz giriş ve ekonominin değişmemesi kontrol edilir. LGS Sayısal'daki net kaydı kesinti proxy'sinden geçirilir.

Bu kesinti yerel HTTP/API erişimini simüle eder; cihazın Wi-Fi veya uçak modunun kapatılması değildir. Ayrı terminalde sabit loopback proxy'yi başlatın; hazır bir proxy varsa ikinci kez başlatmayın:

```sh
python3 tool/local_supabase/qa_http_proxy.py
```

```sh
SIM_UDID="$SIM_UDID" E2E_HOST_PORT=54399 E2E_REVIEWED_NIGHT=2 \
  E2E_API_PORT=54325 E2E_HTTP_PROXY=true \
  E2E_RUN_ID="$TASK_QA_RUN-ios-short" E2E_VERIFY_PHASE=short \
  bash tool/local_supabase/e2e/sim/run_sim_e2e.sh ad

ANDROID_SERIAL="$ANDROID_SERIAL" E2E_HOST_PORT=54398 E2E_REVIEWED_NIGHT=2 \
  E2E_API_PORT=54325 E2E_HTTP_PROXY=true \
  E2E_RUN_ID="$TASK_QA_RUN-android-short" E2E_VERIFY_PHASE=short \
  bash tool/local_supabase/e2e/sim/run_android_e2e.sh ad
```

**Wrapper/parite ayrımı:** iOS wrapper koşu sonunda da parite çalıştırır; Android'de bu örneklerde değer 2 aynı kontrolü seçer. Geçici 60 sn katalog resmî referansa uymadığından native test geçse bile wrapper parite nedeniyle sıfır dışı çıkabilir. Bu farkı saklamayın. Native log sonucu ayrı kaydedilir; bütün kısa pencere sonunda birebir restore ve son parite exit 0 ayrıca zorunludur. Başka native hata varsa bunu “beklenen parite farkı” diye geçiştirmeyin.

### Günlük/haftalık/aylık raporlar — `reports`

Normal, Maraton, tamamlanmış ve vazgeçilmiş Deneme içeren **mevcut** yerel QA sahibini seçin. Cohort'un yalnız normal+deneme verisi, bütün karma türlerin yerine geçmez. Rapor fazı yeni veri üretmez; oracle günlük/haftalık/aylık beklenenlerini native gerçek rapor widget/kart/kategori/hedef/verimlilik değerleriyle TR/EN karşılaştırır.

```sh
TASK_REPORT_EMAIL='e2e-sim-mevcut-karma-fixture@pomosprint.local'

SIM_UDID="$SIM_UDID" E2E_HOST_PORT=54399 E2E_REVIEWED_NIGHT=2 \
  E2E_API_PORT=54321 E2E_RUN_ID="$TASK_QA_RUN-ios-reports" \
  E2E_VERIFY_PHASE=reports E2E_EXAM_FIXTURE_EMAIL="$TASK_REPORT_EMAIL" \
  bash tool/local_supabase/e2e/sim/run_sim_e2e.sh ad

ANDROID_SERIAL="$ANDROID_SERIAL" E2E_HOST_PORT=54398 E2E_REVIEWED_NIGHT=2 \
  E2E_API_PORT=54321 E2E_RUN_ID="$TASK_QA_RUN-android-reports" \
  E2E_VERIFY_PHASE=reports E2E_EXAM_FIXTURE_EMAIL="$TASK_REPORT_EMAIL" \
  bash tool/local_supabase/e2e/sim/run_android_e2e.sh ad
```

E-posta yer tutucusunu manifestteki gerçek yerel QA e-postasıyla değiştirin. Bu koşunun eski karmaW hesabı yeni veritabanında otomatik oluşmaz. Tek tarihsel UID/baseline'a bağlı `extend_w_mixed_fixture.py`, tamamlanmış bir kerelik hazırlık olduğu için 29 Ekim 2026 temizliğinde aktif kaynaklardan kaldırıldı; kaynak `889cab0` commit'inde korunur. Yeni fixture'lar desteklenen `w_normal_http_restart_test.dart` ve `ad_verify_reports_exams_test.dart` akışları için ayrı QA kurulumunda hazırlanır; eski hesap veya baseline tekrar kullanılmaz.

## R: gerçek süre ve OS/offline süreçleri

Dosya: `integration_test/r_real_duration_probe_test.dart`. Wrapper'lar aşağıdaki define'ları doğrulayıp iletir:

| Değişken | Değer |
|---|---|
|`E2E_PROBE_MODE`|`normal25_start`, `normal50_start`, `exam_lgs_start`, `exam_tus_start`, `exam_catalog_start`, `resume`|
|`E2E_PROBE_EXAM_ID`|Katalog başlangıcında zorunlu: `tyt`, `ayt`, `ydt`, `lgs_verbal`, `lgs_quantitative`, `tus_basic`, `tus_clinical`|
|`E2E_PROBE_LANGUAGE`|Katalog döngüsü için `tr` veya `en`; gerçek Ayarlar seçimi kalıcı tutulur|
|`E2E_PROBE_EXPECT_OFFLINE_COMPLETION`|Ara offline resume için `true`; kabul edilmiş final değildir|
|`E2E_PROBE_REQUIRE_COMPLETED`|Final resume için `true`; offline ara aşamada `false`|

### Resmî LGS Sözel 75 dk örneği

Resmî katalog açık olmalı. Aynı run, cihaz, app installation ve journal korunur:

```sh
TASK_R75_RUN="r75-$(date +%m%d%H%M%S)"
ANDROID_SERIAL="$ANDROID_SERIAL" E2E_HOST_PORT=54398 E2E_REVIEWED_NIGHT=2 \
  E2E_API_PORT=54321 E2E_RUN_ID="$TASK_R75_RUN" E2E_PROBE_MODE=exam_lgs_start \
  bash tool/local_supabase/e2e/sim/run_android_e2e.sh r
adb -s "$ANDROID_SERIAL" shell am force-stop com.pomosprint.app
```

Log/proof'taki sunucu `ends_at` anına kadar doğal süre geçsin. Arada aynı cihazı sıfırlayan başka senaryo çalıştırmayın. Sonra:

```sh
ANDROID_SERIAL="$ANDROID_SERIAL" E2E_HOST_PORT=54398 E2E_REVIEWED_NIGHT=2 \
  E2E_API_PORT=54321 E2E_RUN_ID="$TASK_R75_RUN" E2E_PROBE_MODE=resume \
  E2E_PROBE_REQUIRE_COMPLETED=true \
  bash tool/local_supabase/e2e/sim/run_android_e2e.sh r
```

iOS karşılığı aynı mod/run ile `SIM_UDID`, host 54399 ve `run_sim_e2e.sh r` kullanır; kapama `xcrun simctl terminate "$SIM_UDID" com.pomosprint.app` ile yalnız QA uygulamasına yapılır. Final tek attempt/event, orijinal süre/zaman, 75 ortak dakika, ayrı 15 deneme puanı/3 deneme kumu ve normal ekonominin değişmemesini denetler. TUS gerçek modunda süre 8100 sn ve ödül 27/5'tir.

### Kısa katalog: başlangıç → offline pending → bağlantılı final

Bu üç aşama aynı run ve aynı cihazda yapılır; araya başka hesap/reset girmez. Tek sınav örneği `tyt`; yedi ID ve iki dil ayrı, benzersiz run'larla tekrarlanabilir. Önce kısa katalog ve proxy hazır olmalı:

```sh
TASK_CYCLE_RUN="cycle-$(date +%m%d%H%M%S)"
SIM_UDID="$SIM_UDID" E2E_HOST_PORT=54399 E2E_REVIEWED_NIGHT=2 \
  E2E_API_PORT=54325 E2E_RUN_ID="$TASK_CYCLE_RUN" \
  E2E_PROBE_MODE=exam_catalog_start E2E_PROBE_EXAM_ID=tyt E2E_PROBE_LANGUAGE=tr \
  bash tool/local_supabase/e2e/sim/run_sim_e2e.sh r
xcrun simctl terminate "$SIM_UDID" com.pomosprint.app
curl -fsS -X POST http://127.0.0.1:54326/availability \
  -H 'Content-Type: application/json' -d '{"available":false}'
```

Proof'taki 60 sn `ends_at` geçtikten sonra, proxy hâlâ kapalıyken:

```sh
SIM_UDID="$SIM_UDID" E2E_HOST_PORT=54399 E2E_REVIEWED_NIGHT=2 \
  E2E_API_PORT=54325 E2E_RUN_ID="$TASK_CYCLE_RUN" \
  E2E_PROBE_MODE=resume E2E_PROBE_EXAM_ID=tyt E2E_PROBE_LANGUAGE=tr \
  E2E_PROBE_EXPECT_OFFLINE_COMPLETION=true E2E_PROBE_REQUIRE_COMPLETED=false \
  bash tool/local_supabase/e2e/sim/run_sim_e2e.sh r
xcrun simctl terminate "$SIM_UDID" com.pomosprint.app
curl -fsS -X POST http://127.0.0.1:54326/availability \
  -H 'Content-Type: application/json' -d '{"available":true}'

SIM_UDID="$SIM_UDID" E2E_HOST_PORT=54399 E2E_REVIEWED_NIGHT=2 \
  E2E_API_PORT=54325 E2E_RUN_ID="$TASK_CYCLE_RUN" \
  E2E_PROBE_MODE=resume E2E_PROBE_EXAM_ID=tyt E2E_PROBE_LANGUAGE=tr \
  E2E_PROBE_EXPECT_OFFLINE_COMPLETION=false E2E_PROBE_REQUIRE_COMPLETED=true \
  bash tool/local_supabase/e2e/sim/run_sim_e2e.sh r
```

Ara aşama diskte `complete/connection` kuyruğu ve ekranda pending mesajını, DB'de active/0 ödülü kanıtlar; `completion_verified=false` kalır. Final aynı attempt/start/end/snapshot'la tek tamamlanmayı doğrular.

**İptal/hata halinde de proxy'yi true durumuna geri getirin; otomasyon sahibi bunu finally/trap içinde yapmalıdır.** Katalog geri yüklemesi ayrıca yapılır. Android karşılığında aynı 54325 proxy kullanın; iOS wrapper yerine Android wrapper/host 54398, kapama için `adb ... force-stop` ve dil için `en` seçilebilir. Android wrapper başlangıçta reverse mapping'i yeniden kurduğundan, 54321'i dışarıdan `adb reverse --remove` ile kesmek wrapper tabanlı offline senaryosuna uygun değildir.

## Geçici kısa katalog protokolü

Wrapper'lar kataloğu kurmaz veya geri yüklemez. Kısa testten sorumlu koordinatör şu şartları sağlamalı; mevcut bitmemiş denemeyi kısa süreli hale getirmek için snapshot değiştirilmez:

1. Resmî katalogda tam yedi ID/süre/soru/ödül ve 27–30 paritesi önce geçsin. Bütün `exam_catalog` satırlarını (`id`, `definition`, `enabled`) birebir yedekleyin; sadece süre/ödül listesini yedeklemek yetmez.
2. Aktif uzun probe'ların attempt/definition/start/end hash'lerini kaydedin. Aynı anda başka katalog yazarı, fixture kurucusu veya native derleme olmasın; tek sahipli kilit kullanın.
3. Yalnız ana loopback QA katalog tanımlarındaki **gelecek başlangıçları**60 sn/0 puan/0 kum yapın. Soru sayıları/bölenler korunur. `exam_attempts` snapshot'ı, kullanıcı bakiyesi, kayıtlı süre ve sunucu saati değiştirilmez.
4. Native short sonuçlarını ve bilinen geçici wrapper parite farkını ayrı kaydedin. Sıfır puanlı tamamlanma yine 1 dakika ve tek sıfır puanlı lig event'i üretir; oda/normal ekonomi kazandırmaz.
5. Başarı, hata, timeout ve Ctrl+C yollarının tamamında bağlantıyı açın; katalog satırlarını yedekten birebir geri yükleyin. Child/host cleanup hatası diğer geri yüklemeleri atlamamalı.
6. Katalog eşitliği, aktif uzun attempt'lerin değişmediği ve aşağıdaki son parite exit 0 zorunludur. Geri yükleme/parite başarısızsa çalışma **tamamlanmış sayılmaz**; resmî katalog isteyen fixture'lara/normal kullanıma geçilmez.

```sh
bash tool/local_supabase/parity_check.sh --reviewed-night-20261028-with-start-atomic
```

Bu rehber bilerek yeni bir katalog yazma/bootstrap aracı sunmaz. Bu koşuya ait `/tmp` orchestrator dosyaları taşınabilir repo kurulumu sayılmaz; sonraki konuşmada mevcut oldukları varsayılmaz. Yeni katalog penceresi açılırken yukarıdaki backup/guard/finally protokolü somutlaştırılmalıdır.

## AF: kategori/global lig ve sosyal

Dosya: `integration_test/af_verification_leagues_social_test.dart`. `E2E_AF_PHASE=leagues|social|all`.

Lig için resmî katalog açıkken yeni LGS/TUS cohort'u hazırlanır. Varsayılan plan yazmaz; açık apply dört uydurma hesap ve kontrollü geçmiş oluşturur. Mevcut run'ı tekrar kullanmayın:

```sh
TASK_COHORT_RUN="verify-$(date +%m%d%H%M%S)"
python3 tool/local_supabase/e2e/create_verification_cohort.py --run "$TASK_COHORT_RUN"
python3 tool/local_supabase/e2e/create_verification_cohort.py \
  --run "$TASK_COHORT_RUN" --apply --allow-historical-metadata

SIM_UDID="$SIM_UDID" E2E_HOST_PORT=54399 E2E_REVIEWED_NIGHT=2 \
  E2E_API_PORT=54321 E2E_RUN_ID="$TASK_QA_RUN-ios-leagues" \
  E2E_AF_PHASE=leagues E2E_VERIFY_COHORT_RUN="$TASK_COHORT_RUN" \
  bash tool/local_supabase/e2e/sim/run_sim_e2e.sh af
```

İki LGS ve iki TUS hesabının normal/deneme puanları ayrı kalır; her LGS çiftinin her iki türde aynı odada olduğu önceden doğrulanır. SQL→RPC→native sıra/puan/kimlik; kategori/global, visible/private/blocked ve TR/EN karşılaştırılır. Screenshot adları bu durumları ayrı saklar. [Cohort sözleşmesi](VERIFICATION_COHORT_README.md).

Sosyal için ayrı, yeni I08 fixture'ı testten hemen önce kurulur; 5 dakikalık molaları saatler önceden oluşturmayın:

```sh
TASK_SOCIAL_RUN="social-$(date +%m%d%H%M%S)"
python3 tool/local_supabase/e2e/i08_multiuser_fixture.py setup --run-id "$TASK_SOCIAL_RUN"
python3 tool/local_supabase/e2e/i08_multiuser_fixture.py check --run-id "$TASK_SOCIAL_RUN"

SIM_UDID="$SIM_UDID" E2E_HOST_PORT=54399 E2E_REVIEWED_NIGHT=2 \
  E2E_API_PORT=54321 E2E_RUN_ID="$TASK_QA_RUN-ios-social" \
  E2E_AF_PHASE=social E2E_SOCIAL_FIXTURE_RUN="$TASK_SOCIAL_RUN" \
  bash tool/local_supabase/e2e/sim/run_sim_e2e.sh af
```

Fixture bir gözlemci+sekiz API arkadaşıdır:4 odak/2 mola/2 deneme. Test durum bitişini, sosyal gizliliği ve engellemeyi görünür ekrandaki 30 sn polling ile denetler; değişiklikleri QA sahibinin API'siyle geri alır. Test sürerken dışarıdan fixture refresh çalıştırmayın; silinmesi beklenen durumu geri açabilir. Fixture'ın `cleanup` eylemi hesap siler; bu test sırasının otomatik adımı değildir.

Android karşılığında aynı env alanlarıyla `ANDROID_SERIAL`, host 54398 ve `run_android_e2e.sh af` kullanılır. Sosyal için her platforma yeni run tercih edilir. Açık ekranın gerçek ay dönümünü bekleme bu AF'nin kapsamı değildir; ay sınırı unit ve izole SQL kanıtı ayrıca etiketlenir.

## AE: yalıtılmış eski sunucu

Dosya: `integration_test/ae_old_server_isolated_test.dart`. Ana sunucudaki 27–30 geri alınmaz. Ön koşul `pomosprint_overnight_baseline` adlı **boş** eski referanstır; hazır değilse [eski sunucu rehberindeki](isolated_old_stack_README.md) guard'lar incelenir. Ana DB/Auth verisini rastgele klonlamak veya guard'ı kaldırmak çözüm değildir.

```sh
python3 tool/local_supabase/e2e/isolated_old_stack.py start
python3 tool/local_supabase/e2e/isolated_old_stack.py status

SIM_UDID="$SIM_UDID" E2E_HOST_PORT=54399 E2E_REVIEWED_NIGHT=2 \
  E2E_API_PORT=54341 E2E_RUN_ID="$TASK_QA_RUN-ios-old" \
  bash tool/local_supabase/e2e/sim/run_sim_e2e.sh ae

ANDROID_SERIAL="$ANDROID_SERIAL" E2E_HOST_PORT=54398 E2E_REVIEWED_NIGHT=2 \
  E2E_API_PORT=54341 E2E_RUN_ID="$TASK_QA_RUN-android-old" \
  bash tool/local_supabase/e2e/sim/run_android_e2e.sh ae

```

AE tamamlanıp ekran/SQL kanıtları saklandıktan ve bu eski uygulamada aktif sayaç/bekleyen kuyruk kalmadığı doğrulandıktan sonra ayrı temizlik yapılabilir. `stop`, yalnız sahiplik etiketi doğrulanan eski QA container'larını **ve eski kopya DB'yi** kaldırır; başarısız veya bitmemiş AE'yi bu komutla temizleyip yeniden başlatmayın:

```sh
python3 tool/local_supabase/e2e/isolated_old_stack.py stop
```

Gateway 54341 yalnız ayrı eski Auth/REST'e gider; main Auth 54321 paylaşılmaz. Eski stack autoconfirm kullanır, SMTP göndermez. TR/EN'de Deneme güvenli “kullanılamaz” görünümü, TUS niyetinin kaybolmaması, normal başlangıç/iptal ve kontrollü 25 dk geçmiş üzerinden raporlar sınanır. 25 dakika doğal beklendiği iddia edilmez. Genel E2eHost bu hesaplarda SQL/e-posta için kullanılmaz; eski gateway kendi UID-sınırlı read-only doğrulamasını yapar. Wrapper'ın son paritesi ana 27–30 DB'yi denetler; eski DB'ye yeni paket kurmaz.

## Bağımsız oracle ve kanıtlar

[Oracle rehberi](VERIFY_REPORTS_AND_EXAMS_README.md) tüm alanları ve sınırları açıklar:

```sh
TASK_QA_OWNER='yerel-qa-owner-uuid'
TASK_QA_PEER='baska-yerel-qa-owner-uuid'
python3 tool/local_supabase/e2e/verify_reports_and_exams.py --owner "$TASK_QA_OWNER"
python3 tool/local_supabase/e2e/verify_reports_and_exams.py \
  --owner "$TASK_QA_OWNER" --peer-owner "$TASK_QA_PEER"
```

UUID yer tutucularını manifestten alın. Yalnız kabul edilmiş DB kayıtlarını okur; cihazın gönderilmemiş kuyruğunu göremez. RLS kontrolü için kaynakta en az bir deneme ve bir net satırı bulunmalı; boş veride sıfır görmeyi güvenlik başarısı saymaz. Stdout JSON `status`, `passed_checks/total_checks`, `checks`, `warnings` ve günlük/haftalık/aylık beklenenleri içerir. Exit 0 bile uyarılar varsa onları çözülmüş saydırmaz.

04:00 çalışma günü profil IANA diliminde başlangıca göredir; Maraton plan sayısı son odağın bitiş çalışma gününe gider. Lig ayı normal `completed_at`, deneme `ends_at` üzerinden 00:00 İstanbul'dur. Geç gönderilen geçmiş kayıt ve saat dilimi değişiminin saklı seri politikası oracle rehberinde ayrıca yazılıdır.

Wrapper logları `build/e2e_sim` / `build/e2e_android` altındadır; sonraki koşu aynı dosya adını değiştirebilir. Her koşudan sonra logları benzersiz kanıt klasörüne kopyalayın veya dışarıda `tee` ile saklayın. `E2E_SHOT_DIR` ile benzersiz ekran klasörü seçilebilir. Native exit, beklenen geçici parite farkı, final restore/parite, oracle ve testin kapsamı ayrı kaydedilir. Screenshot tek başına muhasebe kanıtı değildir.

### AH hakkında

`integration_test/ah_pending_exam_recovery_test.dart`, bu koşuda diskte kalmış **exact owner/attempt** için tamamlanmış tek seferlik kısa YDT kurtarmasıydı. 29 Ekim 2026 temizliğinde aktif kaynaklardan kaldırıldı; tarihsel kaynak ve doğrulama kayıtları Git geçmişinde korunur. Bu eski senaryonun 60 saniyelik YDT ve sahip varsayımları yeni kayıtlara uygulanmaz. Yeni kurtarma incelemeleri, desteklenen `u_exam_http_recovery_test.dart` ve `r_real_duration_probe_test.dart` akışlarının ilgili sahip/journal korumalarıyla yürütülür; bekleyen kullanıcı verisi sıfırlanmaz.

## Son kapı

Bu komutlar normal kod kapısıdır; native/DB sonuçlarını onların yerine saymayın:

```sh
flutter analyze
flutter test
npm --prefix scripts test
```

Final raporda hangi cihaz/dil/fazın gerçekten geçtiği, hangi kontrollü verinin kullanıldığı ve kalanlar açık olmalı. Yeni README veya test dosyası eklemek, bekleyen native çalışmayı otomatik PASS yapmaz. Bu rehber deploy, üretim SQL'i, main'e merge veya fiziksel cihaz yetkisi vermez.
