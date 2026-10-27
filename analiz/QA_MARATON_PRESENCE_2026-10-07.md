# Maraton kartı ve devam onayı — 7 Ekim 2026

Bu tur kullanıcının adımlı kart, seans sonunda ilerleme animasyonu ve her mola sonrası bir dakikada “Buradayım” isteğini uygular. Önceki [Maraton raporu](QA_MARATON_2026-10-07.md) tarihsel otomatik geçişi doğrular; güncel davranış bu belgededir. Çalışma yereldedir; canlı SQL, site yayını ve Git push yapılmadı.

## Güncel davranış

- Ana ekranda 2/3/4 adımlı Maraton kartı, seans rozeti, bilgi düğmesi, tamamlanan işaretleri ve bağlantı ilerlemesi vardır. Her kabul edilen odakta 650 ms dolum/pop animasyonu çalışır. Yeni açılışta eski adımlar yeniden canlandırılmaz; Hareketi Azalt ayarına uyulur, boşta dönen animasyon yoktur.
- Her ara odak güvenle kaydedilince 5 dakikalık mola başlar. Sonra **60 saniyelik “Buradayım”** ekranı açılır. Açık uygulamada kullanıcı dokunup sunucu onaylayınca sonraki odak başlar. Tick, bildirim, arka plan veya geri yükleme kendiliğinden odak üretmez.
- Son tarih dolarsa kalan plan durur. Tamamlanmış seansların dakika, normal puan, kum ve rapor kayıtları korunur; eksik plan Maraton bonusu kazanmaz. Mola/onay süresi çalışma dakikasına eklenmez.
- Sunucu başarılı kayıt yanıtında değişmez mola bitişi ve son tarih döndürür; istemci bunları cihaz saatine çevirir. Gecikmiş veya duplicate yanıt yeni pencere yaratmaz. Çevrimdışı kuyruğa yazılan odak kendi özgün pencere çıpasını korur; sonra eşitleme pencereyi uzatmaz.
- Tam plan bonusu değişmedi: 25 dk ×2/3/4 için **+2/+3/+5**, 50 dk için **+4/+6/+10**. Gerçek ödül sunucudan alınır; kum bonusu ve seri çarpanı eklenmez.

## Güvenlik ve durum makinesi

`focus → completing → breakTime → awaitingPresence → focus/finished`; yanıtsız pencerede kalan plan kapanır. Mutlak mola bitişi ve sonraki aday UUID diskte tutulur. Aynı UUID onay tekrarı aynı makbuzu döndürür; başka UUID reddedilir. Çift dokunma, hesap değişimi, ön plandan çıkış, son tarih dolması ve geç disk/HTTP yanıtları yeni odağı başlatamaz. Aktif plan CAS kilidi, sunucu profil kilidi ve seans idempotency anahtarı birlikte çalışır.

Sunucu `confirm_marathon_presence` öncesinde önceki kabul edilmiş indeksleri, plan sahibini ve sunucu saatini denetler. Sonraki seans başlangıcı onayla bağlı UUID ve 10 saniyelik başlangıç aralığını sağlamalıdır. Eksik/yanlış/geç onayda tamamlanan meşru normal seans kaybolmaz, plan bonusu kalıcı olarak kapanır. Özel ödül gövdesi ve bilet/ayar tabloları istemci rollerine kapalıdır. Bu akış fiziksel kullanıcı varlığının cihaz tasdiki değildir; değiştirilmiş istemciden yapılan geçerli zamanlı API çağrısını fiziksel dokunuştan ayırt etmez.

## Çalıştırılan kontroller

Yeni davranış için çalıştırılan kontroller (hedefli alt kümeler genel toplama tekrar eklenmez):

| Kontrol | Sonuç | Kanıt |
|---|---|---|
| `flutter analyze` | Temiz, 0 bulgu | analiz (ham çıktı §37 temizliğinde kaldırıldı) |
| `flutter test --concurrency=2` | 1142 geçti; 5 isteğe bağlı görüntü testi ayrı etkinleştirildi | tam paket (ham çıktı §37 temizliğinde kaldırıldı) |
| Üç görüntü dosyası, `--dart-define=SCREENSHOTS=true` | 5/5 geçti; toplam 1147 test çalıştırıldı | görüntü koşusu (ham çıktı §37 temizliğinde kaldırıldı) |
| Model/sayaç kayıt ve yarış alt kümesi | 12/12 | hedefli koşu (ham çıktı §37 temizliğinde kaldırıldı) |
| Makbuz/servis ve kuyruk alt kümesi | 15/15 | servis (ham çıktı §37 temizliğinde kaldırıldı) |
| Son gerçek font/kabuk başlangıç düğmesi görünürlüğü regresyonu | 1/1; TR/EN ×2/3/4, kaydırma yok | ek koşu (ham çıktı §37 temizliğinde kaldırıldı) |
| İzole yerel 700 DRYRUN | 73/73 | özet (ham çıktı §37 temizliğinde kaldırıldı) |
| Ek gerçek iki bağlantı yarışı, kısa gerçek akış, ACL ve rollback | 20/20 | Aynı özet ve izole koşucu |
| iPhone 16 Plus / iOS 18.6, `o`: altı onaylı plan + arkadaş sosyal ekranı | 6/6; 6 yeni odak hesabı +1 arkadaş, 18 ayrı odak | o (ham çıktı §37 temizliğinde kaldırıldı) |
| Android 16 ARM64, `o`: altı onaylı plan + arkadaş sosyal ekranı | 6/6; 6 yeni odak hesabı +1 arkadaş, 18 ayrı odak | o (ham çıktı §37 temizliğinde kaldırıldı) |
| iOS 18.6, gerçek 60 sn yanıtsız onay + widget-tree yeniden açılış | Geçti; aynı son tarih, yalnız 1×25 dk/5 puan/20 kum | q (ham çıktı §37 temizliğinde kaldırıldı) |
| iOS native bildirim teslim/iptal, ActivityKit başlat/duraklat/devam/temizle, mola alarmı | Geçti; ActivityKit `true` | k (ham çıktı §37 temizliğinde kaldırıldı) |
| Android 16 native ongoing sayaç, odak/mola alarmı teslim/iptal, izin ve tercih kapatma | Geçti | j (ham çıktı §37 temizliğinde kaldırıldı) |
| Android 16 gerçek 60 sn yanıtsız onay + widget-tree yeniden açılış, ikinci koşu | Geçti; aynı son tarih, yalnız 1×25 dk/5 puan/20 kum | q tekrar (ham çıktı §37 temizliğinde kaldırıldı) |
| Android 16 üçüncü `q`, monotonik süre/duvar saati/aşama zaman çizelgesi | Geçti; sabit son tarihte durdu, kayıt/puan/kum korundu | zaman çizelgesi (ham çıktı §37 temizliğinde kaldırıldı) |
| Üç paket kaldırılınca Android gerçek eski-sunucu `p` | Geçti; Maraton kapalı, tek seans/rapor/eski sosyal çalışıyor | p (ham çıktı §37 temizliğinde kaldırıldı) |
| Son temiz Flutter analiz ve yerel şema paritesi | Temiz; normal seans gövdesi aynı, QA RPC yok | analiz (ham çıktı §37 temizliğinde kaldırıldı), parite (ham çıktı §37 temizliğinde kaldırıldı) |

Üretim 300+60 saniye sözleşmesi ve SQL sınırları testlerde korunur. Mobilde bekleme yükünü azaltmak için **yalnızca yerel debug QA** odakları 5/10 saniye, molayı 10 saniye kullanır; bunlar raporda 25/50 dakika kaydolur. Devam onayı mobilde gerçek 60 saniye kalır. Bu hızlandırma canlı/release uygulamada etkin değildir.

Tam paket yaklaşık 60 saniye, ayrı beş görüntü testi 4 saniye sürdü. Ekran görüntüsü bayrağı shell ortam değişkeni yerine Dart define olarak verildi. Eski üç sayaç PNG’si testten önce yedeklenip aynı byte’larla geri getirildi. Kartta TR/EN, altı boyut, büyük yazı, koyu tema ve Hareketi Azalt; sayaçta odak/mola/onay ve 48 dp düğme erişimi kontrol edildi.

Her plan için ayrı UUID, mola/onaydan çalışma kaydı çıkmaması, onaydan önce odak başlamaması, bonusun yalnız finalde verilmesi, normal rapor/lig/puan/kum toplamı ve boş outbox kontrol edilir. iOS `o` test gövdesi 355 saniye sürdü; gerçek 60 sn yanıtsız `q` 90 saniye, native `k` 8 saniye. Derleme/kurulum süreleri bunlara dahil değildir. `q` yeniden açılışı widget ağacı ve gerçek `main()` üzerinden yapılır; OS süreç ölümü olarak sunulmaz.

| Plan | Rapor dakikası | Toplam puan | İçindeki Maraton bonusu | Kum | iOS / Android |
|---|---:|---:|---:|---:|---|
| 25 ×2 | 50 | 12 | 2 | 40 | Geçti / Geçti |
| 25 ×3 | 75 | 18 | 3 | 60 | Geçti / Geçti |
| 25 ×4 | 100 | 25 | 5 | 80 | Geçti / Geçti |
| 50 ×2 | 100 | 28 | 4 | 40 | Geçti / Geçti |
| 50 ×3 | 150 | 42 | 6 | 60 | Geçti / Geçti |
| 50 ×4 | 200 | 58 | 10 | 80 | Geçti / Geçti |

Seçilmiş gerçek iOS görüntüleri: ana kart (ham çıktı §37 temizliğinde kaldırıldı), tamamlanmış adım ve mola (ham çıktı §37 temizliğinde kaldırıldı), onay ekranı (ham çıktı §37 temizliğinde kaldırıldı), süre aşımı (ham çıktı §37 temizliğinde kaldırıldı). Görüntüler final yerleşimi gösterir; ekran görüntüsü tek başına animasyonun süresine kanıt değildir, animasyon widget testinde denetlenir.

Android görüntüleri: ana kart (ham çıktı §37 temizliğinde kaldırıldı), onay (ham çıktı §37 temizliğinde kaldırıldı), 50×4 raporu (ham çıktı §37 temizliğinde kaldırıldı). Android `o` test gövdesi 436 saniye sürdü. Testler tek emülatör, 2 çekirdek ve 2048 MB bellekle çalıştı; iOS bu sırada kapalıydı.

## Bulunup düzeltilenler

- Başarılı odak kaydında sunucu ile istemcinin mola başlangıcı ayrışabiliyordu. Değişmez sunucu makbuzu ve saat farkı dönüşümü eklendi; gecikme/duplicate ve kuyruk son tarihi regresyonları geçti.
- Yanıt kaybı ve yeniden açılışta yeni devam UUID’si üretme riski kaldırıldı; aday UUID RPC’den önce kalıcılaştırıldı. Ağ hatası, geç ACK, çift dokunma, sahip değişimi ve yavaş disk testleri geçti.
- İlk gerçek iOS görüntüsünde Maraton başlangıç düğmesi gezinme alanına taşıyordu. Kart açıkken kum saati kalan alana küçülür; normal tek seansın düzeni korunur. Son iOS görüntüsünde düğme tamamen görünür.
- Kabul edilmiş normal seansı “kayıt reddedildi” diye açıklayan metin ayrıldı; yalnız plan doğrulaması başarısızsa kaydın korunduğu açıkça söylenir.
- İlk iOS `o` denemesi eski metin etiketini aradığı için test harness’inde durdu. Bulucu gerçek kartın odak aşaması ve adım sayısını denetleyecek şekilde güncellendi. İlk Android `o`, onay başarılı olup düğme kalktıktan sonra düğmeyi okumaya çalışan retry kontrolünde durdu; pump sonrası görünürlük tekrar denetlenir. Bu iki ilk deneme başarılı cihaz sonucu sayılmadı.

İlk Android `q` koşusunda zaman aşımı metni 75 sn içinde bulunamadı; DB’de yalnız ilk 25 dk kayıt vardı. İkinci ve ek zaman çizelgeli üçüncü koşu değişmemiş ürün koduyla geçti. Üçüncü koşuda orijinal son tarih 16:13:35.034 olarak kaldı; 0/15/30/46 sn gözlemlerinde `awaitingPresence/checkIn` görüldü, son tarihte plan temizlendi ve yeni odak oluşmadı. İlk başarısız koşu (ham çıktı §37 temizliğinde kaldırıldı) korunur. İlk gecikmenin nedeni belirlenemedi; iki tekrarda görülmedi. Bu ilk başarısız kontrol geçmişten silinmedi veya nedeninin çözüldüğü iddia edilmedi.

## Devir ve canlıya uygulama

Yeni dosyalar `lib/widgets/marathon_progress_card.dart`, `lib/services/marathon_presence.dart`, ilgili testler ve `integration_test/q_marathon_presence_test.dart`; timer/persistence, Shell, outbox sonucu, TR/EN ve bildirim metinleri güncellendi.

Canlıda üç SQL paketi bekliyor: 150000 mola → 160000 ödül → **170000 devam onayı**. [Uygulama/down/DRYRUN rehberi](../supabase/tests/20261007_marathon_README.md) hazırdır. `AGENTS.md §2.4` gereği bunları kullanıcı SQL Editor'de çalıştırır; güncel canlı gövdeler önce salt okunup parmak izleri karşılaştırılmalıdır. Yeni istemci eski/eksik güvenlik sözleşmesinde Maratonu kapalı tutar; normal tek seans çalışır. Yerel test geçmesi canlıya uygulanmış veya mağazaya hazır sayıldığı anlamına gelmez.

Fiziksel cihaz bildirim/kilit ekranı, gerçek sağlayıcı girişleri, signed mağaza dağıtımı ve normal 25/50 dakikalık uzun çalışma doğrulamaları bu turun kapsamında değildir.

## Test sonrası ortam

Önce QA yardımcıları, ardından 700→600→500 down çalıştırıldı. Eski sunucu `p` için yalnız normal kısa seans helper’ı geçici açıldı, bu kontrol geçince o da kaldırıldı. Son parite **yerel kopya canlıyla aynı (bilinçli farklar hariç)**: `complete_study_session` md5 `f0f2b9bcc09ae8440a66d889b5f22fcc`; QA ve devam-onayı RPC sayısı 0. Kazanılmış normal test seansları/puanlar silinmedi. Bu tur açılan 24 test hesabı yalnız yerel kopyada kaldı; kişisel/canlı hesap açılmadı.

Android emülatörü kapatıldı; bir Gradle daemon durduruldu. Docker yerel Supabase hizmetleri açık bırakıldı. iPhone 16 Plus/iOS18.6 normal `lib/main.dart`, kök `.env` ile 17,3 sn’de derlendi ve giriş ekranında açık bırakıldı. `QUICK_TIMER`/`QUICK_TIMER_SAVE` yoktur; normal sayaçlar 25/50 dk. Derlenen backend asset’i kök `.env` ile eşit ve yerel URL değildir. Anahtar/parola belgeye alınmadı. Normal açılış özeti (ham çıktı §37 temizliğinde kaldırıldı).

Canlı SQL paketleri uygulanmadığı için bu normal uygulamada Maraton kapalıdır. Animasyonlu/onaylı kart bu tur yalnız yerel QA sunucusunda çalıştırıldı. Kullanıcının normal e-posta/şifre denemesi yerel Mailpit’e yönlendirilmez.
