# Maraton popup, puan ve güvenlik QA — 7 Ekim 2026

Bu belge ana ekrandaki büyük Maraton kartının kaldırıldığı son kullanıcı takibinin kaydıdır. Önceki [UI/onay](QA_MARATON_PRESENCE_2026-10-07.md) ve [yerel açılış](QA_MARATON_LAUNCH_2026-10-07.md) raporları tarihsel kanıttır. Bu turda canlıya SQL yazılmadı, deploy/commit/push yapılmadı. Testler yerel Docker Supabase ve simülatör/emülatör üzerindedir.

## Uygulanan düzen

- Ana ekranda, sayaç ile 25/50 dk seçenekleri arasında dolgulu, kenarlıklı 48 dp **Maratonu başlat** düğmesi ve aynı yükseklikte ayrı dairesel **?** var. Normal **BAŞLAT** tek Pomodoro başlatır.
- **“Kaç seans yapmak istiyorsunuz?”** sorusunun altında 2/3/4 rakamları eşit aralıklı 56 dp dairelerde seçilir; alt plan seçime göre güncellenir. Ortak 25/50 seçimi aynı, kaydırılabilir popup’tadır. Başlat düğmesi kısa yatay ekranda da görünür. Seçimler taslaktır; kapatma, geri hareketi veya 3-2-1’i iptal etmek normal sayacı Maraton modunda bırakmaz.
- Plan başlatma; sahip, aktif oturum, ön plan, güncel sunucu desteği ve disk yazısı kontrollerinden geçer. Gerçek başlangıçtan sonra **“Maraton başlıyor. İyi çalışmalar!”** gösterilir. Çift tıklama alttaki sayfayı kapatamaz veya ikinci plan oluşturamaz.
- Aktif planda aynı satır tamamlanan/planlanan sayıyı gösterir; buradan canlı animasyonlu ilerleme popup’ı açılır. Ana ekrana büyük kart eklenmez. İlerleme popup’ı açıkken de mola/onay saati işler; hesap değişimi ve ekran kapanışı popup’ı temizler.
- Kum saati ölçüsü `5f99f90` commit’indeki Maraton öncesi düzen formülüyle aynı: normal dikey telefon alt sınırı 220 dp, üst sınır 275 dp; kısa dikey telefonda eski 120–220 dp hesabı, yatayda kum saati solda, sayaç ve seans kontrolleri sağda kalır. Plan seçimi, popup iptali ve restore ölçüyü/konumu değiştirmez. Üç kontrol aralığı daraltılarak duraklatılmış seansta iPhone 16 Pro/SE ana düğmesinin alta taşması giderildi.
- İstenmeyen el simgesi kaldırıldı. Normal odakta ve Buradayım onayında eski kum saati vardır. Kahve sadece **Maraton molasında** görünür: fincan sabit, buhar 4 saniyede çok az hareket eder; Hareketi Azalt ve görünmeyen sekmede animasyon durur. Yeni paket/görsel varlığı eklenmedi.
- **Yatay Pomo** boşta, çalışırken, duraklatılmış, mola ve onay durumlarında yalnız animasyon, sayaç ve gerekli başlat/duraklat/bitir kontrollerini gösterir. Buradayım mevcut devam onayı için erişilebilir kalır. Üst puanlar, kategori, süre seçenekleri, Maraton kutusu, TEST rozeti ve gezinme gizlenir; dikeye dönünce eski düzen ve aynı seans geri gelir.
- TR/EN yardım; plan, ortak seans süresi, 5 dk mola, 1 dk açık **Buradayım / I’m here** onayı, internet gereksinimi, erken bırakma ve bonus koşullarını açıklar. Altı bonus değeri sunucu yapılandırmasından alınır. Yaklaşık toplam süre molaları içerir; onay beklemesi ve duraklatma ayrıca uzatabilir.

## Puanlama ve yarım bırakma

Her tamamlanan odak ayrı normal seanstır. Normal puan hesabı, duraklatma/seri/günlük tavan kuralları sunucudaki mevcut RPC’dedir. Hiç duraklatılmamış, ilk günlük serili QA hesaplarında doğrulanan sonuçlar:

| Süre × sayı | Çalışma | Normal toplam | Maraton ek puanı | Puan toplamı | Kum |
|---|---:|---:|---:|---:|---:|
| 25 × 2 | 50 dk | 10 | 2 | 12 | 40 |
| 25 × 3 | 75 dk | 15 | 3 | 18 | 60 |
| 25 × 4 | 100 dk | 20 | 5 | 25 | 80 |
| 50 × 2 | 100 dk | 24 | 4 | 28 | 40 |
| 50 × 3 | 150 dk | 36 | 6 | 42 | 60 |
| 50 × 4 | 200 dk | 48 | 10 | 58 | 80 |

Bonus sadece bütün ayrı odaklar ve zamanında devam onayları geçerli, kayıtlı ve normal puan kazanmışsa bir kez verilir. Seri yüzdesi bonusu çarpmaz; bonus ekstra kum üretmez ve günlük tavanı aşmaz. Duraklatılmış normal taban 25 dk için 4, 50 dk için 9 puandır; bu mevcut normal kural korunur.

Erken bırakılırsa veya onay kaçırılırsa tamamlanan odakların normal puan/kum/raporları kalır. Bitmemiş odak ve gelecekteki odaklar kaydedilmez, tamamlama bonusu verilmez. Yerel outbox tekrarları aynı UUID’yi ikinci kez ekonomik kazanca çeviremez.

## Mola, kapanma ve zaman sınırı

Üretim sözleşmesi **300 saniye mola +60 saniye onay**. Geliştirme önizlemesinde yalnız yerel debug helper’ı **5/10 saniye odak +10 saniye mola +gerçek 60 saniye onay** kullanır; odaklar raporda 25/50 dk sayılır. Canlı/release hızlı kayıt yapamaz.

Sunucunun daha önce kabul ettiği odaktan gelen mola ve onay biletleri değişmezdir. Mola bitmeden onay yoktur; son tarih dahil ve sonrasında onay reddedilir. Uygulamayı kapatmak, yeniden açmak, duplicate gönderim veya eski bilet pencereyi yenilemez. Onay için ön planda kullanıcı dokunması ve aynı sonraki UUID’ye sunucu makbuzu gerekir.

Önemli sınır: odak uygulama kapalıyken biter ve henüz sunucuya gönderilmemişse kayıt ilk açılışta kabul edilir; ilk sunucu bileti bu kabul anından başlar. Bu, mevcut otoritatif sunucu sözleşmesidir. Uygulama kapalıyken sonraki odaklar kendiliğinden başlatılmaz. Özel istemciyle insan dikkatini taklit etmeyi kriptografik olarak doğrulayan cihaz tasdiki yoktur.

## Bu turdaki doğrulamalar

| Kontrol | Sonuç / kapsam |
|---|---|
| Tam Flutter paketi | **1158/1158**, 59 sn, concurrency 2, `SCREENSHOTS=true`, 0 atlama; analiz temiz |
| Ana ekran ve popup düzeni | Altı boyut, TR/EN, x1/x2 yazı, açık/koyu tema, azaltılmış hareket; eski kum saati formülü, dokunma alanları ve görünür BAŞLAT doğrulandı |
| iOS ilk popup gerçek UI `o` | **Geçti**; altı 25/50 ×2/3/4 plan, 6 yeni odak hesabı +1 arkadaş; ayrı kayıt/puan/kum/lig/rapor ve sosyal Odaklanıyor/Molada |
| iOS son gerçek UI `q` | **Geçti**; gerçek 60 sn yanıtsız onay, widget yeniden açılışında aynı son tarih; yalnız 1×25 dk /5 puan /20 kum, ikinci odak/bonus yok |
| iOS son daireli/minimal UI `o` | **Geçti**, 200 sn; 25×2 ve 50×4, mola kahve/buhar, onay kum saati, aynı plan 0→1 ilerleme, kayıt/puan/rapor/lig/sosyal |
| Backend SQL | **155/155 DRYRUN** (23 mola +59 ödül +73 onay), **25/25 ek/koşucu kontrolü**; ayrı geçici DB temizlendi |
| İki gerçek DB bağlantısı | Çatışan sonraki UUID’lerde tek onay; aynı UUID/final duplicate tek son seans ve tek bonus; tam rollback şema/ACL eşitliği |
| Android ilk gerçek UI `o/q` | **Geçti**; 25×2 ve 50×4, arkadaş/rapor/kum/puan, gerçek 60 sn yanıtsız onay ve korunmuş 1×25 dk |
| Android son daireli/minimal UI `o/q` | **Geçti**; 25×2 ve 50×4, gerçek kahve/buhar/onay kum saati ve 0→1 popup ilerlemesi, rapor/puan/kum/sosyal; gerçek 60 sn yanıtsız onay yalnız 1×25 dk /5 puan /20 kum |
| Son cihaz DB mutabakatı | Her platformda 4 QA hesabı, 7 ayrı/7 benzersiz odak kaydı, **275 dk /75 puan**. Profil dakika/puan/kum farkı **0**; eksik plana veya onaysız plana bonus **0**, tüm onay pencereleri gerçek 60 sn |
| Gerçek iOS süreç sonlandırma | Odak, mola ve onayda `simctl terminate`; onayda simülatör kapanışı. Önceden kabul edilmiş pencere yenilenmedi, açılışta biten odak bir kez kaydoldu, süresi geçen plan bonus almadan durdu |
| Gerçek iOS son görsel/etkileşim | Yeni daireli popup, dikey/yatay yardım, sade odak/mola/onay, yatay Buradayım ile 50×2 tamamlandı: **100 dk /28 puan /40 kum**, bonus 4; bitişte aktif kayıt boş |

İlk tam Flutter turu iki kırmızı sonuç verdi: gerçek duraklatılmış telefon taşması ve yardım metninin artık bonus paragrafıyla birleşmesi nedeniyle eskimiş birebir test eşlemesi. Taşma ürün kodunda düzeltildi; test metnin içerdiğini doğrulayacak şekilde güncellendi. Bu düzeltmelerden sonra tam tur 1153/1153 geçti. Son daireli seçim, sade yatay görünüm, mola animasyonu ve tema geçişiyle nihai tam tur **1158/1158** geçti. İlerleme popup’ındaki küçük onay el simgesi de mevcut sayaç simgesine çevrildi; bu son satırla tam paket tekrar doğrulandı. Sekiz tarihsel ekran görüntüsü baytları aynı kalacak şekilde geri kondu; güncel sayaç görüntüleri ayrı klasöre alındı.

### Son etkileşimlerde bulunan ve giderilen hatalar

Açık yardım penceresiyle iOS cihaz döndürmede `SnackBarThemeData.lerp` assertion’ı yakalandı. Dar/geniş temanın `floating` davranışı eşitlendi; genişlik ve Navigator korunur. Eski kodda aynı hatayı üreten iki regresyon, düzeltmeden sonra ara animasyon kareleriyle geçti; yeniden başlatılmış iOS uygulamasında gerçek dönüş de temizdi. Geçiş kanıtı (ham çıktı §37 temizliğinde kaldırıldı).

Küçük yatay ekran/x2 yazıda duraklatma SnackBar’ı Devam simgesini örtüyordu. Yatayda bu bilgilendirme kutusu gösterilmez; duraklatma, disk kaydı, hak ve puan değişmedi. Ayrıca Maratonu bitirme mesajı önceki odak sonucunun arkasında bekliyordu; şimdi eski SnackBar temizlenir ve “tamamlanan Pomodorolar/normal puanlar korundu” hemen gösterilir.

Flutter araçlarının paralel başlatıldığı ilk nihai denemede üretilmiş Swift package klasöründe `Directory not empty/errno66` çakışması oldu; birim testler başlamamıştı. Log korundu. Native koşu bittikten sonra araçlar sıralandı; iki worker ile nihai tam paket 59 saniyede yeşil geçti. Bu araç hatası uygulama çökmesi olarak sayılmadı.

## Veritabanı ve güvenlik

- İnceleme anındaki yerel Auth’ta 327 hesabın parola alanı yalnız toplam/hash türüyle sorgulandı: **bcrypt, cost 10**. Parola/hash/e-posta/token çıktısı verilmedi. Kullanıcı kimliği UUID’dir; isim/e-posta gibi profil alanlarının tamamı hash değildir. `public` tablolarda parola kolonu yok; anon/authenticated `auth.users` okuyamaz.
- Yerel Maraton tablolarında orphan, farklı sahibin seansı, yanlış süre, eksik plana ödül, yanlış bonus veya süresi dışında onay ihlali **0**. Korunan puan/kum alanlarına istemci doğrudan yazamaz. Özel ödül/bilet gövdeleri istemci rollerine kapalı, SECURITY DEFINER işlevlerinde sabit arama yolu ve sahip/yetki denetimleri mevcut. Normal `complete_study_session` gövde hash’i değişmedi.
- Flutter kilidindeki **132 hosted sürüm** resmi OSV API ile sorgulandı: yayınlanmış advisory eşleşmesi **0**; 8 SDK paketi bu taramaya dahil değil. `pub outdated` 57 satırda advisory/retracted/discontinued işareti göstermedi. Sürüm güncellemesi yapılmadı; sıfır eşleşme tüm güvenlik açıklarının yokluğunu kanıtlamaz.
- Supabase Flutter varsayılanı oturum JSON’unu cihazın uygulama alanında SharedPreferences ile saklar. Parola burada saklanmaz. Özel Keychain/Keystore adaptörü yoktur; cihaz ele geçirilmesi için ek sertleştirme halen ayrı iştir. Android bulut yedeği ve cihaz aktarımı kapalıdır. Paket içindeki kök `.env` yalnız üç kamuya açık istemci ayarı içerir.
- 105 Maven sürümü, 9 SwiftPM sürümü ve 9 native Git revision OSV taraması ile resmi npm audit sonucu bilinen advisory eşleşmesi **0**. Ağsız Auth/reset sayfası regresyonları **22/22** geçti. Eski, tracked yerel Supabase başlatma logunda sekiz demo credential alanı redakte edildi; geçmiş Git blobları değiştirilmedi. Canlı sır sızıntısı bulunmadı; tarama güvenlik garantisi değildir.
- Canlı Supabase connector bu tur mevcut değildi; **canlı DB yeniden okunmadı**. Yerel şema ve repodaki yeni üç paket doğrulandı. Canlıya üç paket uygulamak kullanıcı SQL Editor akışıdır; burada tamamlanmış sayılmaz.

Detaylar: backend incelemesi (ham çıktı §37 temizliğinde kaldırıldı), istemci/dependency incelemesi (ham çıktı §37 temizliğinde kaldırıldı), repository güvenlik incelemesi (ham çıktı §37 temizliğinde kaldırıldı).

Son doğrulama logları: Flutter (ham çıktı §37 temizliğinde kaldırıldı), analiz (ham çıktı §37 temizliğinde kaldırıldı), iOS (ham çıktı §37 temizliğinde kaldırıldı), Android (ham çıktı §37 temizliğinde kaldırıldı), cihaz DB mutabakatı (ham çıktı §37 temizliğinde kaldırıldı), yatay widget matrisi (ham çıktı §37 temizliğinde kaldırıldı).

## Çalıştırma ve devir

Depo kökünde:

```bash
tool/local_supabase/run_marathon.sh
```

Doğru Xcode/iOS18.6, sabit yerel Docker projesi ve güvenli hızlı kayıt önizlemesini hazırlayıp açar. Normal `flutter run` canlı `.env` kullanır; üç Maraton paketi canlıda olmadığı için Maraton orada kapalıdır. Kök `.env` ve sistem `xcode-select` değiştirilmedi.

Son uygulama iPhone 16 Plus/iOS18.6 simülatöründe **dikey/TR/boşta** açık bırakıldı; Flutter run detach edildi, uygulama süreci çalışıyor. Yerel önizleme hesabında 7 seans/250 dk/62 puan/140 kum var; aktif kayıt boş. Android emülatörü ve bu koşunun Gradle daemon’ı kapatıldı.

Üç yerel paket ve QA helper’ları kullanıcı denesin diye açık kalır; test sonunda baseline’a dönülmez. Özel yerel hesap define dosyası Git dışında/600’dür. Fiziksel cihaz, gerçek Google/Apple hesap girişi, mağaza imzalı dağıtım, canlı SQL ve canlı yayın doğrulamaları bu tur kapsamı dışındadır. Kullanıcı onayıyla daha sonra yapılacak işlerdir.

Güncel kaynaklar: `lib/widgets/marathon_plan_dialog.dart`, `lib/widgets/marathon_break_indicator.dart`, `lib/widgets/snackbar_width_scope.dart`, `lib/screens/timer_screen.dart`, `lib/app/main_shell.dart`, TR/EN ARB’ler. Yeni devir noktası: [PROJE_DEVIR §20](../PROJE_DEVIR.md#20-maraton-popup-puan-ve-güvenlik-takibi--7-ekim-2026). Kanıtlar aynı tarihli klasörde (ham çıktı §37 temizliğinde kaldırıldı), ekranlar ayrı klasörde (ham çıktı §37 temizliğinde kaldırıldı).
