# Son uygulama QA — kapat/aç, çevrimdışı kullanım, rapor ve sıralama

8 Ekim 2026. İki gerçek istemci hatası yeniden üretildi ve düzeltildi. Son tam Flutter paketi **1222/1222**, analiz temizdir. Yerel native ilk tur **4/4**, final tekrar **2/2**, bağımsız lig davranışı **85/85**, on hesaplık kayıt/RLS doğrulaması **94/94** geçti. Gerçek işletim sistemi kapatma/açma denemesinde bekleyen seans korundu; ağ dönünce aynı UUID yalnız bir kez kaydoldu. Normal süreli derleme doğrulandı ve geçici QA ortamı temizlendi; bu rapor mağaza/fiziksel cihaz onayı değildir.

## 1. Ortam ve kapsam

Kullanıcının iPhone16Plus simülatörüne, kişisel hesabına ve diğer iki HMV simülatörüne test kurulumu yapılmadı. Ayrı `PomoSprint Final QA iPhone16Plus`, iOS18.6, `D31C75E6-7BB7-496D-B526-83D398AD5687` oluşturuldu. Testler bir cihazda sırayla yapıldı; bu tur beş eşzamanlı simülatör koşusu değildir.

API `http://127.0.0.1:54321`, canlı şemayla eşleşen yerel Supabase/Docker kopyasıdır. Offline denemede yalnız `supabase_kong_pomosprint-local` durduruldu: uygulamanın bütün Supabase HTTP bağlantısı gerçekten kesildi. Mac'in Wi-Fi'ı ve başka projelerin interneti kapatılmadı. Fiziksel uçuş modu/radyo kaybı testi sayılmaz.

Kayıtlı hızlı sayaç yalnız bu açık yerel debug QA'da kullanıldı: 5/10 saniye, veritabanında 25/50 dakikalık mantıksal kayıt. Üretim süreleri ve normal `flutter run` **1500/3000 saniye** olarak kaldı; canlı kısa seans kaydetme yeteneği yoktur. Bu tur doğal 25/50 dakika tamamlanması veya 14 günlük bekleme testi iddia edilmez. Normal1500sn restore koşusu eski gerçek biçimdeki tamamlanmış kayıt fixture'ını kullanır.

Üretimde yalnız güvenli genel lig yapılandırması salt okundu: HTTP200, preparing, kapasite25. Anonim Maraton yapılandırması HTTP401 verdi; bu kimlik doğrulama sınırıdır, kesinti kanıtı değildir. Canlı hesap/seans/SQL/Auth/e-posta/deploy yazımı yapılmadı.

## 2. Bulunan ve düzeltilen hatalar

**Hesap değişiminde geç dönen bekleyen seans sayısı:** `getPendingSessionCount` eski A hesabı için başlayan disk okumasının sonucunu B hesabının genel sayacına yazabiliyordu. Sahip ve oturum epoch'u dönüşte denetleniyor. A→B, çıkış ve aynı UID ile yeni oturum senaryolarında yeni gösterge korunuyor. Başka hesaba kayıt aktarımı saptanmadı; düzeltme gösterge yarışını giderir. Yeni beş regresyon eski kodla4 başarısız/1 başarılıydı; düzeltme sonrası tüm account dosyası38/38 geçti.

**İlk çevrimdışı lig yardımında eski30 kişilik metin:** Henüz başarılı config okumamış süreçte hem yardım RPC'leri başarısız olunca eski yedek görünüyordu. Başlangıç yedeği güncel25 kişi/10 aktif ödül sınırı/preparing'e hizalandı. Başarılı sunucu yanıtı otoritatif kalır; gerçek eksik RPC için legacy uyumluluk korunur. TR/EN yeni kontroller eski kodla0/2, düzeltme sonrası ilgili paket41/41. Final standalone native binary'de Puan `?` yardımı offline açılıp25 kişilik metin ekranda ayrıca görüldü.

`integration_test/c_session_points_test.dart` kaldırılmış “Sıran” bandını bekliyordu. Eski beklenti güncellendi: bandın yokluğu, gerçek v2 RPC'nin kendi UID/is_me/5puan/25kapasite kaydı ve UI'de kendi puanı denetlenir. Ürüne sıra bandı veya yeni özellik eklenmedi.

Kanıtlar: race önce (ham çıktı §37 temizliğinde kaldırıldı), account sonra (ham çıktı §37 temizliğinde kaldırıldı), lig önce (ham çıktı §37 temizliğinde kaldırıldı), lig sonra (ham çıktı §37 temizliğinde kaldırıldı), offline yardım PNG (ham çıktı §37 temizliğinde kaldırıldı). İlk yanlış odak komutunda bulunmayan test yolu kullanılmıştı; araç hatası ayrı logda (ham çıktı §37 temizliğinde kaldırıldı) korunur, ürün kusuru sayılmaz.

## 3. Koşulan testler

| Paket | Sonuç / sınır | Kanıt |
|---|---|---|
| İki düzeltme sonrası analyze | Temiz, exit0 | analiz (ham çıktı §37 temizliğinde kaldırıldı) |
| Tam Flutter birim/widget | **1222/1222**,0 hata/atlama;135,62sn, concurrency1, screenshots açık | kontroller (ham çıktı §37 temizliğinde kaldırıldı), log (ham çıktı §37 temizliğinde kaldırıldı) |
| İlk gerçek iOS `h/i/d/f` | **4/4**; iki düzeltme hazırlanmadan başlayan binary, kapsamı ayrı | manifest (ham çıktı §37 temizliğinde kaldırıldı) |
| Son native `c/h` | **2/2**, c83,61sn /h99,85sn; frozen kaynak SHA'ları aynı | manifest (ham çıktı §37 temizliğinde kaldırıldı), c (ham çıktı §37 temizliğinde kaldırıldı), h (ham çıktı §37 temizliğinde kaldırıldı) |
| Bağımsız izole lig | **85/85**, review DB temizlendi | sonuç (ham çıktı §37 temizliğinde kaldırıldı), review (ham çıktı §37 temizliğinde kaldırıldı) |
| On native hesap, SELECT/RLS | **94/94**, yalnız salt okuma | sonuç (ham çıktı §37 temizliğinde kaldırıldı) |
| Cold hesabın sıralama/kimlik kontrolü | **21/21**, READ ONLY; aylık50 sınırı doğru | sonuç (ham çıktı §37 temizliğinde kaldırıldı), inceleme (ham çıktı §37 temizliğinde kaldırıldı) |
| Bütün turun final veri mutabakatı | **25/25**,14 hesap/11 kayıt/400dk/87puan/220kum | sonuç (ham çıktı §37 temizliğinde kaldırıldı), yöntem (ham çıktı §37 temizliğinde kaldırıldı) |
| Gerçek OS offline kapat/aç | Bekleyen1 → kapat/aç bekleyen1 → sync0; DB0→1→1 | Aşağıdaki cold snapshot'lar |

38 ve41 odak testleri1222'nin alt kümeleridir. UI, SQL ve veri kontrolleri aynı davranışı kısmen tekrar ölçer; tek dev toplam üretmek için toplanmaz. Önceki Node133 ve lig89 sonuçları bu tur yeniden koşulmuş sayılmaz. 44 tarihsel +4 lig PNG'si48/48 hash ile birebir geri yüklendi; yeni üretilen görseller ayrı kanıt klasöründedir.

## 4. Native seanslar, arkadaşlar ve rapor

`h`: API kapalıyken25dk mantıksal seans outbox'a yazıldı, raporda bekleyen25dk görünürken puan/kum0 kaldı. Ekran ağacı yeniden kurulunca kayıt korundu; ağ dönüşü/resume ve tekrar sync tek kayıt verdi. B izolasyon hesabında A'nın geçmişi/pending/puan/kumu görünmedi; A'ya dönüş kendi verisini verdi.

`i`: 50dk mantıksal seans bir kez duraklatıldı; UUID/başlangıç/kalan süre diskte korundu. Devam ve ikinci duraklatma reddi doğru; tek50dk/9puan/20kum kaydı. %20 duraklatma indirimi sunucudan geldi.

`d`: iki hesapta UI arkadaş isteği/kabul, arkadaş listesi, odaklanma canlı akışı ve arkadaş sıralamasında kendi `is_me` satırı geçti. `f`: beş hesapta gerçek kısa sayaç, günlük/haftalık/aylık rapor, lig puanı, ikişer komşulu arkadaş halkası, sosyal görünürlük ve odak başlat/iptal geçişleri geçti. Bu koşuda bildirim izni notDetermined'dı; teslim/Canlı Etkinlik başarısı iddia edilmez.

| İlk tur fixture | Seans | Dakika | Puan | Kum |
|---|---:|---:|---:|---:|
| offline |1|25|5|20|
| isolation |0|0|0|0|
| pause |1|50|9|20|
| arkadas-a / arkadas-b |0 /0|0 /0|0 /0|0 /0|
| qa1 |2|75|17|40|
| qa2 |1|25|5|20|
| qa3 |1|50|12|20|
| qa4 |1|25|5|20|
| qa5 |1|50|12|20|

Toplam10 hesapta **8 seans/300dk/65puan/160kum** profil ve kayıt toplamlarıyla aynı. UUID tekilliği, kategori/seans sahipliği, authenticated RLS'de yabancı kayıt0, arkadaş kimlikleri ve tek aktif lig üyeliği doğru. Raporda Pomodoro sayısı25dk birimidir: bir50dk seansı2 Pomodoro görünür; veritabanı seans sayısı1 kalır. Örnek 75dk rapor (ham çıktı §37 temizliğinde kaldırıldı).

Final `c` yeni yerel hesapla **QUICK=false/SAVE=false** çalıştı: gerçek biçimde1500sn tamamlanmış fixture normal RPC'ye gitti; tek25dk/5puan/20kum/verified1500, rapor ve v2 kendi kayıt doğrulaması geçti. Final `h` başka A/B hesaplarıyla kesinti/kuyruk/dedup/izolasyonu aynı güncel kaynak SHA'sında yeniden doğruladı. `c`83,61sn, `h`99,85sn; sekiz yeni PNG yalnız `after_fixes/` altındadır. İlk4 koşu veya tam birim/widget1222 ile karıştırılmaz. Üç yeni hesapta iki25dk kayıt,10puan/40kum; ayrı cold hesabı aşağıdadır.

Son salt okuma25/25 mutabakat bütün grupları birlikte kontrol etti: **14 farklı yerel hesap,11 kabul edilmiş seans,400dk,87puan,220kum**.11 client UUID hem cohort hem global düzeyde tek; kategori ownership ve profile/session toplamları aynı. Final c/h'deki üç hesap için authenticated RLS kendi1/1/0 satırını, yabancı0 gösterdi. Bu25 kontrole ilk94 ve cold21 tekrarlarının toplamı gibi bağımsız ürün senaryosu sayısı yüklenmez.

## 5. Gerçek işletim sistemi kapat/aç ve sıralama

İki istemci düzeltmesini içeren standalone yerel debug binary, ayrı cold hesabıyla çalıştı. OS PID'leri32837→34533→36662; `simctl terminate` başarılı olduktan sonra yeni `launch` yapıldı. Integration `launchApp`'in aynı süreçte widget yeniden kurmasıyla karıştırılmaz.

1. API tamamen kapalıyken50dk mantıksal seans tamamlandı. Kalıcı pending1, aktif kayıt yok, DB0, profil0/0/0. Snapshot (ham çıktı §37 temizliğinde kaldırıldı), ekran (ham çıktı §37 temizliğinde kaldırıldı).
2. Uygulama tam kapatılıp API hâlâ kapalıyken açıldı. Yerel hesap/kategoriler ve pending1 kaldı. Rapor “yalnız bu cihazda senkron bekleyen seanslar” uyarısıyla50dk gösterdi; puan/kum0 kaldı. Snapshot (ham çıktı §37 temizliğinde kaldırıldı), ekran (ham çıktı §37 temizliğinde kaldırıldı).
3. Cold-offline sıralama yüklenemedi mesajı ve Tekrar Dene gösterdi; başarılı veri yokken uydurma sıralama göstermedi. Puan `?` rehberinde güncel25 kişilik kural görüldü.
4. API açıldı, bekleyen banner'ından yeniden denendi. Pending0, **tek50dk/12puan/20kum** kayıt. Aynı UUID`687cead4-ec94-40e4-945d-87ded3f94411`; ikinci online OS kapat/aç sonrası kayıt/ekonomi aynıdır. Sync (ham çıktı §37 temizliğinde kaldırıldı), tekrar açılış (ham çıktı §37 temizliğinde kaldırıldı).
5. Lig v2/UI'de kendi12puan satırı ve scheduled başlangıç kartı görüldü. Liste yüklendikten sonra API yeniden kesildi; görünür sekmeye dönüş son listeyi koruyup “Güncellenemedi, son yüklenen veriler gösteriliyor” mesajını verdi. API açılıp Tekrar Dene ile uyarı kalktı. Online lig (ham çıktı §37 temizliğinde kaldırıldı), stale offline (ham çıktı §37 temizliğinde kaldırıldı).

Aylık sıralama gerçek UI'de yüklendi. Ekran ilk50 kişiyi gösterir; yeni cold hesabı12puanla ilk okumada84/140 sırada olduğundan ilk50'de yoktur. Son bağımsız21/21 salt okuma snapshot'ında yeni c/h hesapları nedeniyle84/142 ve kendi lig odası12/25 oldu (ilk okuma10/25).100 satırlık RPC aynı UID'yi12puan/50dk ile döndürür. İlk50'deki iki “Sim Host” başka UID'lerdir ve is_me=false; isimden hesap eşleşmesi yapılmaz. Arkadaşlar RPC'si bu hesapta0 arkadaştır; UI kendi profilini ayrıca ekler (runtime arkadaşlar ekranı ilk d/f koşularında doğrulandı, bu cold hesap için ayrıca elle açıldığı iddia edilmez). Bu ilk50 sınırı mevcut tasarımdır, puan kaybı veya yeni ürün hatası değildir. Sıralamalar push/Realtime ekranı değildir; yenileme veya bayat sekmeye dönüşle güncellenir.

## 6. Lig davranışı ve zaman sınırları

İzole85 kontrol:24 mevcut kullanıcı+2 eşzamanlı ilk yerleşimde25+1 oda; hazırlık ve carry;25 farklı aktif kişi eşiği; global336saat/DST; aktif kullanıcıya bağlı terfi kotası ve3 gün/300dk şartı; avatar/podyum/idempotency/kademe; V2 masking/ACL/legacy; gecikmiş Maraton bonusunun bir kez sayılması; ilk geç gelen/aynı dönem sınırındaki normal seans.

Takvim fixture'ı yalnız ayrı review DB/geri alınan transaction içinde kullanıldı. Ana yerel DB'nin şeması, config'i ve cron job'ları değiştirilmedi; yetkili native test hesapları/seansları ayrıdır. Önceki89'un4 cron metadata kontrolü bu tur tekrar edilmedi. Doğal14 gün veya canlı gerçek dönem devri beklenmedi. Yerel scheduled, canlı preparing farkı QA hesap sayısındandır.

## 7. Son ortam ve kalan sınırlar

Normal standalone debug binary tekrar kuruldu: QUICK_TIMER=false, QUICK_TIMER_SAVE=false; TR Pomo ekranında **25:00**, PUAN12/KUM20, normal25/50 seçimleri ve Maraton girişi görüldü. Normal25:00 PNG (ham çıktı §37 temizliğinde kaldırıldı), son cold disk/DB (ham çıktı §37 temizliğinde kaldırıldı). Bu aşamada50:00 için ayrıca native dokunma yapılamadı: CUA Simulator bağlantısı `cgWindowNotFound` verdi. Daha önceki normal1500sn c ve tam birim/widget1500/3000 testleri geçti; görünmeyen pencerede başka input aracı kullanılmadı. Bu otomasyon bağlantısı hatası uygulama çökmesi diye sayılmaz; simctl screenshot normal çalışan ekranı gösterdi. İlk anlık `normal-launch.png` açılış karesidir, son sayaç ekranı yerine kullanılmaz.

`quick_recording.py --remove` başarılı; yerel QA RPC'leri kaldırıldı. Şema **498 satır/13 kategori**,27 avatar canlı snapshot'ıyla aynı; bilinçli yerel marketing trigger kapalı kaldı. Mola300/onay60 ve normal RPC parmak izi korunur. Kaldırma (ham çıktı §37 temizliğinde kaldırıldı), son parite (ham çıktı §37 temizliğinde kaldırıldı).

Kendi host portları54419/54420 kapalı, Kong açık, yalnız geçici D31 QA cihazı Shutdown. Kullanıcının BEA iPhone16Plus cihazı Booted; mevcut Runner binary ve prefs hash'i önce/sonra aynı. Yeni iki istemci düzeltmesi kullanıcının mevcut eski kurulmuş binary'sine hot patch edilmedi; kod günceldir, sonraki normal `flutter run` derlemesi bu düzeltmeleri içerir. Yerel hızlı QA kullanıcısı normal canlı uygulama gibi açık bırakılmadı. Final ortam kanıtı (ham çıktı §37 temizliğinde kaldırıldı). Kaynaklar/kanıtlar korunur; fixture hesaplar yalnız yerelde saklanır.

Fiziksel iOS/Android, yeni Android native turu, gerçek Google/Apple, tam bildirim/kilit ekranı sunumu, e-posta inbox teslimi, doğal canlı lig devri ve mağaza dağıtımı bu son turun kapsamı değildir. Kullanıcı yasal geliştirici kimliği/adresini en son verecek; tekrar istenmedi. Commit/push/website deploy yapılmadı. Yeni ürün özelliği eklenmedi.
