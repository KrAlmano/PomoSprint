# Son UI değişiklikleri ve beş hesaplı uçtan uca QA — 7 Ekim 2026

**Sonuç:** İstenen UI değişiklikleri, güncel tek cihaz iOS/Android ve beş eşzamanlı iOS hesabı doğrulandı. Son native koşuda ürün hatası/çökme görülmedi; küçük yatay/x2 yazı taşması önceki kontrolde bulunup düzeltildi. Toplam14 kabul edilmiş seans/550 nominal dakika/144 puan/280 kum, tüm hesap raporları ve bağımsız DB/API okumalarıyla eşleşti. Bu rapor önceki `QA_CONCURRENT_SOCIAL` ve `QA_MARATON_POPUP` turlarından yenidir; eski sonuçlar yeni koşuya eklenmez.

Kanıt kökü: `analiz/qa_evidence_20261007/requested_ui/`. Yeni görüntüler: `analiz/ekranlar/20261007_requested_ui/`. Test hesapları yalnız yerel Docker Supabase içindir; canlı hesap oluşturulmadı, canlı SQL, deploy, commit veya push yapılmadı.

## İstenen davranış ve kaynak ilişkileri

| Alan | Güncel davranış | Ana kaynak |
|---|---|---|
| Maraton girişi | En çok 280 dp genişlik, 40 dp görünen yükseklik; sağdaki küçük dairesel ? aynı kutuda. 48 dp dokunma alanları korunur; kum saati eski bütçede kalır. | `timer_screen.dart` |
| Planlama | Popup’ta 2/3/4 daireleri, ortak 25/50 dk seçimi; iptal normal sayacı değiştirmez. | `marathon_plan_dialog.dart` |
| Sosyal | Tek liste. Normal ve Maraton odağı yalnız **Odaklanıyor**, yalnız Maraton molası **Molada**. Sağda hafif hareketli kırmızı/yeşil nokta; filtre ve “Maraton yapıyor” etiketi yok. | `social_screen.dart`, `social/presence_dot.dart` |
| Sıralama | Kişisel “Sıran #…” ve terfi bandı/rozeti kaldırıldı. Bronz, Gümüş, Altın, Safir, Elmas **Lig** adları TR/EN. Lig kuralları ve sunucu puanı değişmedi. | `social/ranking_widgets.dart`, `social/league_tiers.dart`, ARB |
| Yatay Pomo | Animasyon, sayaç ve seans kontrolleri. Odak/boşta/duraklatılmış durumda duraklatma hakkı görünür; mola/onayda gösterilmez. | `timer_screen.dart`, `main_shell.dart` |
| Onboarding | Yedinci ve son adım Pomo, Maraton, Raporlar, Sıralama, Sosyal ve Profil’i anlatır. Kayıt yalnız son **Bitir** düğmesinde yapılır; önceki hedef taslağı korunur. | `post_auth_onboarding_screen.dart`, TR/EN ARB |
| Kısa önizleme | Görünür TEST rozeti/test ifadeleri kaldırıldı. Yerel debug kayıt güvenliği değişmedi; 5/10 sn odak yalnız bu ortamda 25/50 dk kaydolur. | `local_test_mode.dart`, `timer_persistence.dart`, `session_queue.dart` |

Bildirim, puan ve mola kuralları istemci görünümüyle yeniden hesaplanmaz. Her tamamlanmış odak ayrı `client_uuid` ile outbox→RPC→DB zincirinden geçer; Maraton bonusu yalnız tam planın sonunda sunucudan gelir. Normal uygulama/canlı/release 25/50 dakika kullanır. Yerel önizleme molası 10 sn, Buradayım penceresi gerçek 60 sn; üretim 300/60 sn sözleşmesi korunur.

## Bu turda gerçekten çalıştırılan kontroller

| Kontrol | Sonuç / kapsam | Kanıt |
|---|---|---|
| Flutter analiz | **No issues found**, 5,2 sn | `flutter_analyze_final.log` |
| Tam Flutter paketi | **1174/1174**, 0 atlama; SCREENSHOTS=true, concurrency2 | `flutter_test_final.log` |
| Node | **103/103**, ağsız; site/Auth/Edge/newsletter sahte bağımlılıklarla | `node_test.log` |
| Koordinatör protokolü | **8/8**; 21 zorunlu aşama, deadline ve başarısız istemci sınırları | `test_concurrent_social_host.py`; alt ajan araç çıktısı |
| iOS18.6 gerçek uygulama | `a`: 2 kayıt/onboarding senaryosu; `o`: 1 test içinde 25×2 ve 50×4 uç plan | `ios_a_o.log` |
| Android16 ARM64 gerçek uygulama | `a/o/h/i`: 5 framework testi; `j`: 1 bildirim testi. **6/6** | `android_a_o_h_i.log`, `android_j.log` |
| Lig/hesap izolasyonu | 32 yeni Auth hesabı, 32 eşzamanlı ilk seans, **15/15** kabul ölçütü | `league_owner_results.json`, `league_audit.md` |
| Güncel normal release derlemesi | Android universal APK73,8 MB, 3 ABI/73,7 sn; iOS imzasız uygulama30,6 MB/53 sn. QA define yok; mağazaya yüklenmedi. | `android_release_build.log`, `ios_release_build.log`, `release_artifacts.json` |

Native `o` testinin adı altı planı içerir; bu tur `E2E_MARATHON_SMOKE=true` ile yalnız **25×2 ve 50×4** her iki platformda yeniden çalıştırıldı. Sonuçları 50 dk/12 puan/+2 bonus/40 kum ve 200 dk/58 puan/+10 bonus/80 kumdur. Tarihsel popup QA’daki altı kombinasyon iOS’a, Android takip koşusu iki uç plana aittir; daha eski turların platform kapsamları kendi raporlarındadır. Burada yeniden altı plan koşuldu denmez.

Android’de API gerçekten kapatıldı: biten 25 dk seans kalıcı kuyruğa girdi, çevrimdışı raporda göründü, ekran yeniden kurulunca korundu. API dönünce bir kez kaydoldu: 25 dk, 5 puan, 20 kum; iki tekrar sync yeni kayıt/ödül üretmedi. Başka hesap bu seansı görmedi. Duraklat/devam akışında aynı UUID/başlangıç ve tek hak korundu; ikinci duraklatma engellendi, tamamlanan 50 dk seans **9 puan** verdi. Bu iki senaryodaki yeniden kurulum Flutter widget ağacının yeniden kurulmasıdır; yeni OS process-kill testi olarak sayılmaz.

Android `j`, gerçek bildirim eklentisi/AlarmManager ile izin verilmiş durum, süren seans bildirimi, alarm planlama/iptal, 3 sn sonra gerçek bitiş bildirimi, Maraton bildirim yardımcısı, tercih kapatılınca temizlik ve son pending/active boşluğunu doğruladı. İzin host ADB üzerinden verildi; kullanıcıyla sistem ret/kabul penceresi elle denenmedi. Sahte MethodChannel sonucu değildir. Fiziksel cihaz bildirim/kilit ekranı kapsamı bekliyor.

## Beş eşzamanlı iOS istemcisi

**Koşu:** `requestedui1007_03`, host loopback54401. Tek güncel `Runner.app` Xcode31,5 sn’de derlendi; beş cihaza aynı payload kuruldu. Her cihaz kendi yeni Auth hesabıyla gerçek giriş UI’sini kullanır. Host ilişki/seans SQL’i yazmaz. Hesap onboarding başlangıcı bu eşzamanlı testte API ile hazırlanır; gerçek kayıt ve yedinci onboarding ekranı ayrı native `a` testindedir.

1. Önce tam arkadaş ağı: 10 istek, 10 kabul, her hesapta diğer4 kişi.
2. Ayrı gerçek roller: 1. cihaz 50×2 Maraton; 2. cihaz normal50; 3. cihaz önceden açık Sosyal’de odak ve gerçek Maraton molasını gözler; 4. cihaz Sıralama’yı gerçek pull-to-refresh ile okur; 5. cihaz native yatay dönüş, duraklat/devam/iptal ve yeni normal50 seans yapar.
3. İptal edilen UUID’nin DB/outbox/puan üretmemesi ve yeni UUID’nin ayrı tek kayıt olması kontrol edilir. İkinci tamamlanan seans duraklatılmamıştır; puanı12’dir.
4. Beş kontrollü sosyal görünürlük/gizlilik evresi UI/RPC’de tam UID/durum kümesiyle denenir. Bu presence evresi tek başına tamamlanmış çalışma seansı üretmez.
5. Sonra her cihaz gerçek popup→2 seans→mola→Buradayım→final akışı yapar. Her hesapta Günlük/Haftalık/Aylık gerçek rapor UI’sinin owner/UUID/kategori/dakika ve görünür metrikleri karşılaştırılır; son arkadaş sıralaması ve temiz sosyal durum kontrol edilir.

**Gerçek sonuç:** 21/21 aşamada beş ayrı istemci buluştu; 56/56 native görüntü üretildi. Her beş PID’nin kendi Unified Log’unda `(tearDownAll)` ve **All tests passed!** görüldü; framework exception veya abort yok. Host açılışı→son aşama149,177 sn. Eşzamanlılık manifest (ham çıktı §37 temizliğinde kaldırıldı), beş süreç (ham çıktı §37 temizliğinde kaldırıldı), native pass (ham çıktı §37 temizliğinde kaldırıldı) ve 21 aşama (ham çıktı §37 temizliğinde kaldırıldı) ile kayıtlıdır.

| Hesap / cihaz | İlk gerçek rol | Kayıt | Dakika | Puan | Kum |
|---|---|---:|---:|---:|---:|
| 1 / iPhone16Plus | 50×2 Maraton, sonra25×2 | 4 | 150 | 40 | 80 |
| 2 / iPhone16Pro | Normal50, sonra50×2 | 3 | 150 | 40 | 60 |
| 3 / iPhone16ProMax | Sosyal gözlem, sonra25×2 | 2 | 50 | 12 | 40 |
| 4 / iPhone16 | Sıralama gözlem, sonra50×2 | 2 | 100 | 28 | 40 |
| 5 / iPhone16e | Native yatay iptal→yeni normal50, sonra25×2 | 3 | 100 | 24 | 60 |
| **Toplam** | **6 tam Maraton +2 normal odak** | **14** | **550** | **144** | **280** |

14 kayıt14 benzersiz UUID’dir; 50 dk raporda2 Pomodoro birimi sayıldığından toplam22 birim vardır. Puan126 normal+18 Maraton ek puanıdır; 12 Maraton seans eşlemesi ve6 zamanında sunucu onayı vardır. Bonus final seansın puanına zaten dahil; iki kez eklenmedi. Mola/onay çalışma dakikası değildir. İptal UUID’si0 kayıt/0 Maraton eşlemesi; ayrı yeni `was_paused=false` 50 dk UUID’si tek kayıt/12 puandır.

Bağımsız denetim **DB43/43**, ayrı gerçek Auth oturumlarıyla **API5/5**, günlük/haftalık/aylık owner/UUID/kategori/dakika eşlemesi **15/15** geçti. Her hesapta4 arkadaş;10 çift/20 accepted satır, pending0. Final own outbox/aktif timer ve arkadaş presence boştu. DB mutabakatı (ham çıktı §37 temizliğinde kaldırıldı), authenticated API (ham çıktı §37 temizliğinde kaldırıldı), iptal/yeni UUID (ham çıktı §37 temizliğinde kaldırıldı), özet (ham çıktı §37 temizliğinde kaldırıldı).

Root beş hesabın15 rapor görüntüsünü, gerçek odak/mola gözlemini, native844×390 yatay ekranı ve ara Sıralama’yı görsel okudu. Bağımsız ajan da kaynak SHA, native günlükler, salt-okuma SQL/API ve görsel örnekleri denetledi. Güncel native framework toplamı **3 iOS +6 Android +5 eşzamanlı =14**; teardown ayrı ürün senaryosu değildir. Native dilTR, EN rehber/lig/sosyal/yatay metinleri tam widget paketinde denenmiştir.

## Lig kapasitesi ve veri güvenliği

32 hesap onboarding sonrasında ligsizdi. İlk puan kazandıran seansları aynı bariyerden eşzamanlı gönderilince her hesap tam bir aktif odaya yerleşti. Mevcut 3 kişilik oda 27 yeni üye ile30 oldu; kalan5 yeni odaya gitti. Oda üst sınırı30, global birden fazla aktif üyeliği olan kullanıcı0. Bu ayrı kapasite grubu toplam32 UUID/800 dk/160 puan/640 kum üretti; beş cihaz grubunun rapor toplamına eklenmez.

Her hesabın authenticated seans/lig okuması kendi sahibine ait kaldı. Başkasının UID’siyle açık seans sorgusu boş; yabancı kategori reddedildi; aynı UUID iki farklı hesapta iki ayrı kayıt olarak kaldı. Aynı sahibin eşzamanlı duplicate retry’ları puan/kum üretmedi. İç lig yerleştirici authenticated istemciden doğrudan çağrılamıyor. Normal seans/yerleştirme/haftalık lig fonksiyon hash+ACL’leri önceki 7 Ekim canlı katalog kaydıyla karşılaştırıldı; bu yeni canlı DB sorgusu değildir.

Bu tur yeni dependency/advisory taraması veya bcrypt denetimi yapılmadı. Önceki güvenlik sonuçları `QA_MARATON_POPUP` içinde tarihli kapsam olarak kalır; yerel RLS/owner kontrolleri bütün açıkların yokluğu garantisi değildir.

## Bulunan ve giderilen sorunlar

- Küçük yatay ekranda x2 yazı ölçeğiyle hak bittikten sonra duraklatma etiketi saat alanına taşıyordu. Yalnız yatay etiket tek satır `FittedBox(scaleDown)` oldu; gerçek font/sınır denetimi gevşetilmedi.
- Animasyon testinde ön plana dönüşten sonraki ilk ticker karesi örneklenmediğinden yanlış negatif oluşuyordu; test ilk kareyi bekler. Ürün animasyonuna yeni özellik eklenmedi.
- Sıralama regresyonu kaldırılması istenen terfi bandını hâlâ bekliyordu; matcher yeni görünümü kontrol edecek şekilde düzeltildi.
- Yeni rehberde import/format ve analyzer bulguları temizlendi; iki dilin üretilen dosyaları yenilendi.
- Çok cihazlı test koordinatöründe tüm cihazları beklerken özgün mola onayı son tarihinin aşılması riski bulundu. İki onay bariyeri en erken gerçek sunucu deadline’ının12 sn öncesine sınırlandı; ürünün60 sn penceresi uzatılmadı.

İlk başarısız kontroller ayrı loglarda korunur; son yeşil sonuç olarak gösterilmez. Kullanıcının önce “bekle” dediği02 girişimi boot aşamasında **0 yeni istemci/0 hesap** ile durdu; `concurrent_paused_02`, `user_pause.json`, devam yetkisi `user_resume.json` içindedir. Tarihsel8 screenshot aynı SHA-256 ile geri kondu; bu tur görüntüleri ayrı klasördedir.

## Güncellenme ve yayın kapsamı

Sosyal ekran normalde30 sn, kayıtlı yerel QA’da2 sn polling kullanır; sekme/foreground dönüşünde hemen okur. Test gerçek değişimi bu mekanizmayla gözler. Push/Realtime veya force-kill anında offline garantisi yoktur. Sıralama gözleminde pull-to-refresh yapılır; kendiliğinden anlık sıralama güncellemesi iddia edilmez.

Public canlı yetenek kontrolünde `get_marathon_config` **404/PGRST202**, `get_app_config`200 ve lig kuralı1/1/1 görüldü (`live_public_capabilities.json`). Üç Maraton SQL paketi henüz canlıda yoktur. Kullanıcı `supabase/tests/20261007_marathon_README.md` akışıyla SQL Editor’de önce DRYRUN, sonra500→600→700 paketlerini uygulamalıdır; bu tur canlıya yazılmadı. Fiziksel iOS/Android, gerçek Apple/Google OAuth, imzalı mağaza dağıtımı ve ertelenmiş geliştirici/yasal bilgiler ayrı açık yayın işleridir.

**Son ortam:** Güncel yerel launcher yeniden30,9 sn’de derlenip iPhone16Plus/iOS18.6’da dikey/TR/Pomo/boşta açıldı. Flutter `d` ile ayrıldı; PID31010 çalışıyor, önizleme UID doğru, aktif timer yok/outbox0. ? yardım metni manuel okunup kapatıldı; bütün bonuslar, erken bitirme, internet ve5+1 dk açıklaması görünür. Lig yardımında beş Lig adı manuel doğrulandı, ardından Pomo’ya dönüldü. Son ekran (ham çıktı §37 temizliğinde kaldırıldı), lig adları (ham çıktı §37 temizliğinde kaldırıldı), cihaz/yerel durum (ham çıktı §37 temizliğinde kaldırıldı).

Önizleme hesabı8 seans/275 dk/67 puan/160 kum. Son25 dk kaydıUTC17:46:50’de, bu beş cihaz testinin kullanıcı resumeUTC18:33 zamanından önce oluşmuştu; eski7/250/62/140 sayıları tarihsel durumdur. UID yeni cohort’tan ayrıdır, veriler silinmedi veya yeniden puanlanmadı. Salt-okuma kanıtı (ham çıktı §37 temizliğinde kaldırıldı).

Ek4 simülatör, host, Android emülatörü ve işin Gradle daemon’ları kapalı. Docker/üç yerel Maraton paketi/helper kullanıcı denemesi için açık, baseline farkı bilinçlidir. Android release APK mevcut özel key.properties yapılandırmasıyla derlendi; iOS no-codesign’dır. Release derlemesi fiziksel test veya mağaza dağıtımı değildir. Debug açılışında mevcut GoogleSignIn eklentisinin UIScene/lifecycle uyarısı vardır; derleme geçti, providerlogin/fiziksel kapsam ayrıca bekler.

Kullanıcı komutu yine **`tool/local_supabase/run_marathon.sh`**; normal `flutter run` canlıya gider, yerel kısa kayıt ve canlıda olmayan Maraton için bu komut kullanılmalıdır. `.env`, global Xcode seçimi ve private600 define dosyası değişmedi. Commit/push/deploy yok. Son davranış ve sonuçlar README, PROJECT_CONTEXT, AGENTS, PROJE_DEVIR §22 ve yerel test README’sinde güncellendi.

## Yeniden çalıştırma

Tek cihaz senaryolarında `tool/local_supabase/e2e/sim/run_sim_e2e.sh a o` ve `run_android_e2e.sh a o h i j`; bu tur kullanılan ortam: `QUICK_TIMER=true QUICK_TIMER_SAVE=true E2E_MARATHON_BREAK_SECONDS=10 E2E_MARATHON_SMOKE=true`, Android kesinti için ayrıca `E2E_ALLOW_OUTAGE=1`. Run ID/görüntü klasörü yeni seçilir. iOS’ta `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`, Android’de SDK/JDK17 ayarı gerekir; ayrıntılar `tool/local_supabase/README.md`.

Beş cihaz için `r` tek cihaz runner’ıyla çalıştırılmaz. Önce yerel hazırlık, tek iOS simulator debug derlemesi ve yeni run ID; sonra aynı .app’in hepsine install edilmesi, hostun beş UDID sırası ve rezervasyon başına sırayla launch gerekir. Test uygulamaları bundan sonra eşzamanlıdır. 21 aşama `all_passed` yanında her PID’nin native framework pass’i ve salt-okuma DB/API kontrolü zorunludur. Test-only launcher/rollup kaynakları concurrent README (ham çıktı §37 temizliğinde kaldırıldı) yanında korunur; doğru çalışma konumu `build/requested_ui_concurrent/`’tır. Önceki kanıtların üstüne yazma, Flutter build/test/analyze paralel çalıştırma; test sonunda ek4 cihazı ve hostu kapatıp launcher ile normal önizlemeyi geri aç.
