# Maraton uygulama ve puan QA — 7 Ekim 2026

Çalışma ağacına Maraton eklendi. **Canlı Supabase'e SQL yazılmadı ve uygulama mağazaya gönderilmedi.** Sonuçlar yalnız aşağıdaki yerel kapsam içindir; eski yayın QA raporu bu yeni özellik için test kanıtı sayılmadı.

## Uygulanan davranış

Ana ekranda tek Pomodoro veya **2/3/4 odaklık Maraton** seçilir. 25/50 dk seçimi tüm plana uygulanır. Her odak ayrı UUID ve seans kaydıyla normal puan, kum, seri ve lig akışına girer. Aralarda **5 dk mola** vardır; mola çalışma dakikası veya ödül üretmez. Tamamlanan önceki odaklar, plan durdurulsa da korunur.

Sonraki odak uygulama ön plandayken otomatik başlar. Uygulama askıdaysa veya kapalıysa bitiş/mola bildirimi sistem tarafından gösterilir; sonraki odak açıldığında **yeni başlangıç anıyla** sürer. Geçmişte çalışılmamış odaklar üretilmez. Geç açılışta biten odağın gerçek bitişinden hesaplanan mola dolmuşsa ikinci bir 5 dk bekleme eklenmez.

Sosyal ekranda **Odaklanıyor | Molada** filtreleri vardır. Maraton odağı normal çalışan gibi, mola ayrı kahve simgesi ve “Molada” metniyle görünür. Normal tazeleme 30 sn, kayıtlı yerel QA'da 2 sn'dir; bu özellik push realtime değildir.

## Puan matrisi

Ek bonus yalnız tam Maraton için, sunucuda ve bir kez verilir. Seri çarpanı bonusu artırmaz; bonus ek kum üretmez. Aşağıdaki toplamlar **yeni hesap / seri 1 / duraklatılmamış odak** fikstürüne aittir; normal seri ve duraklatma kuralları başka hesapların normal seans puanını değiştirebilir.

| Odak süresi | Seans sayısı | Kaydedilen dakika | Normal toplam puan | Maraton ek puanı | Son toplam | Kum |
|---|---:|---:|---:|---:|---:|---:|
| 25 dk | 2 | 50 | 10 | **2** | 12 | 40 |
| 25 dk | 3 | 75 | 15 | **3** | 18 | 60 |
| 25 dk | 4 | 100 | 20 | **5** | 25 | 80 |
| 50 dk | 2 | 100 | 24 | **4** | 28 | 40 |
| 50 dk | 3 | 150 | 36 | **6** | 42 | 60 |
| 50 dk | 4 | 200 | 48 | **10** | 58 | 80 |

Günlük puan tavanı yüzünden puansız odak içeren bir tam plan ek bonus kazanmaz; çalışma dakikaları normal kaydolur. Yarım plan ek bonus kazanmaz. Aynı final seansının tekrar gönderilmesi puan/kum üretmez. Sırasız ulaşan geçerli kuyruk kayıtları tüm indeksler tamamlanınca ödüllendirilir; yanlış kronolojik indeksler normal odak geçmişini korur, ek puan kazanmaz.

## Doğrulama sonucu

| Kontrol | Sonuç |
|---|---|
| `flutter analyze` | Temiz, No issues found |
| Tam `flutter test --concurrency=2 --dart-define=SCREENSHOTS=true` | **1129/1129**, 0 atlama |
| Maraton model / akış / responsive alt kümesi | 12/12; tam paketin alt kümesi, toplama tekrar eklenmez |
| Yeni Maraton ekranı | 96 düzen durumu: 6 boyut × TR/EN × metin1/2 × boşta/odak/mola/sunucu desteği kapalı |
| Sosyal focus/break | 17/17 widget testi; eski focus-only satır, filtre, gizleme, yenileme, loaded/empty ve dar ekran |
| Yerel mola SQL DRYRUN | **23/23 true** |
| Yerel puan SQL DRYRUN | **59/59 true**; duraklatma, lig devri, kapanmış dönem ve çoğul aktif üyelik dahil |
| Gerçek iki PostgreSQL bağlantısı / silme / rollback | **20/20** |
| iPhone16 Plus, iOS18.6 gerçek UI | İlk tam matris: 6 yeni odak hesabı +1 arkadaş, 6/6 kombinasyon geçti |
| Son iOS koduyla tekrar | 25dk×2 ve 50dk×4, 2 yeni odak hesabı +1 arkadaş; 2/2 geçti |
| iOS native | Odak/mola alarmı bağımsız zamanlama, iptal, teslim; provisional izin ve ActivityKit start/pause/resume geçti |
| Android16 ARM64 gerçek UI | Tam matris: 6 yeni odak hesabı +1 arkadaş; 6/6 kombinasyon, mola sırasında geri tuşu, ayrı kayıt/rapor/lig/puan/kum ve sosyal filtreler geçti |
| Son Android koduyla tekrar | 25dk×2 ve 50dk×4, 2 yeni odak hesabı +1 arkadaş; 2/2 geçti |
| Android native | Gerçek izin, ongoing sayaç, odak0 ve mola2 zamanlama/iptal/teslim ve tercih kapatma geçti |
| Eski sunucuda gerçek iOS UI | Yeni iki RPC yokken Maraton kapalı; normal 5sn→25dk, 5puan/20kum, rapor ve eski sosyal odak listesi geçti |
| Normal Android release | Obfuscated ARM64 APK **28,1 MB**, imza doğrulaması geçti |
| Normal iOS release | Obfuscated, imzasız uygulama **28,4 MB** derlendi; imzalı IPA değildir |
| Test sonrası yerel şema | İki paket ve QA RPC'leri kaldırıldı; baseline paritesi aynı |

Testlerde odak **5/10 gerçek saniye**, rapor dakikası **25/50** olarak kaydedildi. Normal derleme hâlâ 25/50 dk'dır. Normal QUICK_TIMER molası 3 sn; yavaş Android emülatöründeki API/psql okumalarını kararlı yapmak için son matriste **yalnız izinli yerel debug QA** `LOCAL_QA_MARATHON_BREAK_SECONDS=10` kullanıldı. Üretim veya kayıtsız hızlı mod bu ayarı kullanamaz. Gerçek 5 dakikalık mola hesabı sahte saatli model/akış testinde, gerçek normal zamanlı seans kuralları SQL DRYRUN'da doğrulandı; mobil matris boyunca 25/50 dk beklenmedi.

Gerçek UI matrisinde her odak için ayrı UUID, ilk molada tek seans ve sıfır Maraton bonusu, finalde tam bonus, profil puan/kum, DB toplamları, rapor dakikası ve lig puanı birlikte kontrol edildi. Arkadaş API'sinde focus/break geçişi ve gerçek Sosyal ekranının iki filtresi doğrulandı. Android geri tuşunda mola sırasında da çıkış uyarısı kontrol edildi.

## Bulunan ve düzeltilenler

1. Küçük yatay ekranda başlık/ilerleme taşması ve büyük İngilizce başlat metninin düğmeyi ekran yüksekliğine çıkarması düzeltildi. Etiketler sınırlanır, seçenekler dar alanda iki satıra geçer.
2. Sosyalde 568×320, metin×2 başlık ve filtre listeyi 34px'e sıkıştırıyordu. Kısa ekranda başlık/filtre listeyle birlikte kayar; normal dikey/tablet düzeni korunur.
3. Kaydetme sürerken Durdur → ekran kapanışı → geciken başarı yanıtı planı yeniden başlatabiliyordu. Durma isteği diskte saklanır; bütün Maraton geçişleri UUID/aşama/tamamlanan sayıyı aynı disk kilidinde denetler. Eski ekranın geç yanıtı yeni odağı ezemez. İki durum için regresyon geçti.
4. Dispose/ön plana dönüş kaydı eski Maraton aşamasını ve durma isteğini ezemez. Durdurma yalnız aynı planı temizler; başka yeni plan/normal seans kaydı korunur. Sonraki odağa geçmeden önce başlangıç diske güvenle yazılır.
5. Geç kalan odak iptali mola alarmını kaldırabiliyordu. Alarm kimlikleri ayrıldı: odak0, ongoing1, mola2. Bütün bitiş alarm mutasyonları sıraya alındı. Tercih kapatma ve auth kaybı iki bitiş alarmını da temizler. Kuyrukta beklemiş foreground ses isteği tercihi tekrar kontrol eder.
6. Android PopScope mola sırasında geri tuşunu doğrudan geçirebiliyordu. Mola da seans uyarısına dahil edildi.
7. Sosyal iptal/mola/başlat istekleri sıraya alındı; eski bir iptal yeni odağı silemez. Kullanıcı değişimi/çıkış eski hesabın yeni hesaba durum yazmasını engeller.
8. Lig devrinde eski veride birden çok aktif üyelik varsa ek bonus her üyeliğe yazılabiliyordu. Normal RPC'nin seçtiği tek üyelik çağrıdan önce yakalanır; normal puan ve ek puan aynı carry satırına gider. Kapanmış geçmiş dönem bonusu bugünkü lige yazılmaz. Duraklatmanın normal puan cezası korunur, Maraton bonusu sabit kalır.
9. Çıkış/uzaktan oturum düşmesi native temizlik beklerken mola dolup yeni odak ve alarm başlatabiliyordu. Çıkışın başlangıcında canlı bir devam kapısı kapanır; dispose odak alarmını da temizler. Başlangıç disk yazısı beklerken çıkış/arka plan/ekran kapanışı olursa önceki JSON aynı disk kilidinde geri alınır. Yeni ekran bu geçici, hiç başlamamış odağı tamamlanmış seans olarak kaydedemez. Geciktirilmiş native temizlik, alarm iptali ve gerçek prefs yazısı regresyonları bu pencereleri doğruladı. Prefs hem false hem exception döndürdüğünde önbellek ve disk önceki kayda döner; başarısız ilk kayıt hayalî odak bırakmaz.

Test düzenindeki sorunlar da kaydedildi: 3 sn mola iki ardışık API sorgusu arasında sona erdiği için ilk Android testinin eski focus-only listesi doğal olarak yeni odağı gördü; son matris daha uzun yerel QA molasıyla koşuldu. Native alarm teslimi sabit5sn bekleme yerine en çok20sn içinde gerçek teslimi sorgular. Android NotificationManager iptal çağrısının yanıtından sonra da işi tamamlayabilir: son native koşuda hemen sorgulama bunu yakaladı; en çok3sn içinde gerçek kaldırılmayı doğrulayan koşu geçti. İlk hata günlüğü korunur. Çalışan koşucu betiğini değiştirmek önceki native test geçtikten sonra shell parse hatası üretti; son betiklerde `bash -n` temizdir. Test ve release derlemesini paralel çalıştırmak üretilmiş integration_test plugin kaydını release'e karıştırdı; derlemeler sırayla yeniden üretilerek iki platformda geçti. Native izin/ses/bannerin fiziksel cihazda davranışı bu testten çıkarılmadı.

## Sunucu ve yayın sınırı

Yeni istemci `get_marathon_config` yoksa Maraton seçeneklerini kapatır; normal tek seans ve eski arkadaş listesi devam eder. Canlıdaki yeni Maraton için iki SQL paketi gerekir. [Kurulum/DRYRUN/down rehberi](../supabase/tests/20261007_marathon_README.md): önce mola görünürlüğü, sonra ödül. Kaynak ön koşulları güncel canlı tanımla yeniden karşılaştırılmalıdır. `AGENTS.md §2.4` gereği SQL'i kullanıcı SQL Editor'de çalıştırır.

Fiziksel cihaz, gerçek Google/Apple sağlayıcıları, kilit ekranı/uygulama askısı altında uzun süre, imzalı TestFlight dağıtımı ve önceki yayın raporundaki hukuki/mağaza/Edge dağıtım işleri bu özellik turunda tamamlanmış sayılmaz. Maratona özel gerçek OS force-stop/terminate bu turda koşulmadı; Maraton restore/kapanış yarışları widget testlerinde, normal seans gerçek süreç ölümü önceki yayın turunda denetlendi. Apple Developer ve RevenueCat entegrasyonu bu işte yapılmadı.

## Kanıt ve yeniden koşma

- SQL/yarış/rollback kanıtı (ham çıktı §37 temizliğinde kaldırıldı).
- Tam Flutter, mobil koşular, normal release ve baseline kanıtı (ham çıktı §37 temizliğinde kaldırıldı).
- Ekranlar `ekranlar/20261007_marathon/{ios,android,legacy}/` içine kaydedildi; görüntüler yerel QA hesaplarına aittir.
- Mobil matris `integration_test/o_marathon_test.dart`; native `j_android_notifications_test.dart` ve `k_ios_native_test.dart`. Eski sunucu uyum senaryosu `p_marathon_compat_test.dart`.
- Lokal şemada test için uygulanan paketler QA RPC'leri ve iki down ile kaldırıldı; ana yerel kopyanın baseline paritesi ayrıca doğrulandı. Simülatör/emülatör kapatıldı; yerel Supabase hizmetleri korunuyor.
- Normal süreli release çıktıları ve semboller ignore edilen `release_artifacts/20261007_marathon/` ve `release_symbols/1.0.0+1/marathon_*` yollarında. APK SHA256: `de225b937fe666f56850bc2a2737150ad5eb66e521b9a3e5d6ea577bfe1c4a0b`. Kanıttaki `summary.json` diğer boyut/hash bilgilerini içerir. Bu derlemeler mağazaya yüklenmedi; Maraton hızlı UI testinin yerine normal release üzerinde uzun Maraton koşusu yapılmış sayılmaz.

Bu raporda alt kümeler tam Flutter sayısına eklenmedi; SQL assert, widget ve gerçek mobil akış sayıları tek bir “test toplamı” yapılmadı.

## Son devir kaydı

7 Ekim 2026: geliştirme, yerel test ve kanıt toplama tamamlandı; sonuçlar [PROJE_DEVIR.md](../PROJE_DEVIR.md) §15 ve [AGENTS.md](../AGENTS.md) §5.7 ile eşlendi. Yeni oturum bu iki belgeyi okuyup mevcut çalışma ağacını koruyarak devam etmelidir. Canlı SQL, fiziksel cihaz ve mağaza dağıtımı yukarıdaki kapsam sınırlarıyla beklemektedir; çalışma henüz commit/push edilmemiştir. Son belge güncellemesi yeni test koşusu veya canlı doğrulama değildir.
