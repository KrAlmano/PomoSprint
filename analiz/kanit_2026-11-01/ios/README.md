# iOS gerçek süreli 25 dakika kontrolü — 1 Kasım 2026

**Sonuç:** Ayrı QA uygulamasında gerçek 25 dakikalık seansın başlangıç, süre dolmadan yeniden açılış ve doğal bitiş sonrası doğrulaması geçti. Test, mevcut kişisel uygulamaların verisini kullanmadı; yeni bir yerel QA hesabı ve yerel Supabase kullanıldı. Üretim veritabanına yazılmadı.

| Aşama | Gözlem | Sonuç |
|---|---|---|
| Başlangıç | İstanbul saatine göre 15:26:21'de 1.500 saniyelik gerçek seans başladı; bitiş 15:51:21. Sunucuda rezervasyon vardı, henüz seans/ödül yoktu. | Native test geçti; [güvenli kayıt](start-safe.txt), [ekran](start.png) |
| Ara açılış | Aynı uygulama verisi ve hesapla geri dönüldü. Aynı seans kimliği ve başlangıç/bitiş korundu; kalan süre azaldı, tamamlanmadan ödül yazılmadı. | Native test geçti; [güvenli kayıt](intermediate-safe.txt) |
| Bitiş sonrası | Saat dolduktan sonra aynı seans geri yüklendi. Tek 25 dakika kaydı, +5 normal puan, +20 kum, değişmeyen Deneme cüzdanı, tek lig olayı ve çalışma günü/seri doğrulandı. Aynı tamamlamanın tekrar gönderimi ikinci kayıt veya ödül üretmedi. | Native test geçti; [güvenli kayıt](final-safe.txt), [ekran](final.png) |

Bu test iPhone 17 / iOS 27 simülatöründeki ayrı `com.pomosprint.qa.nov1` paketinde yürütüldü. Normal PomoSprint veya HocamMacVar uygulaması sıfırlanmadı. Kontrol edilen uygulama sürümü 15:22'de alınan QA kopyasıdır; sonradan düzenlenen Deneme/rapor görsellerinin native doğrulaması bu testten çıkarılamaz. Bildirim teslimi ve fiziksel cihaz test edilmedi.

## Parite uyarısı

Her üç aşamada Flutter native testi **All tests passed** dedi. Ancak çalıştırıcının en sonundaki tarihsel `--reviewed-night-20261028-with-start-atomic` kaynak-hash kontrolü, güncel 27/28/29 kaynakları ve sınav kataloğu tarihsel referansla eşleşmediği için başarısız oldu; bu yüzden çalıştırıcının genel çıkış kodu **1**. Kontrol şema karşılaştırmasına geçmedi; sonuç tek başına yerel şemanın bozuk olduğunu veya native testin başarısızlığını göstermez. Bunun yerine geçtiği iddia edilmemelidir. Güncel KPSS profili için ayrı parite sonuçları ilgili sunucu raporundadır.

## Diğer uygulamaların veri kontrolünün sınırı

QA başlangıcından sonra iki normal uygulama açılmadan, yalnız container içindeki `Documents`, `Library/Preferences` ve `Library/Application Support` dosyalarının bütünlük özeti alındı ve hem ara hem son turdan sonra karşılaştırıldı. PomoSprint'te kapsamdaki bir dosya aynı kaldı; HocamMacVar'da bu üç konumda dosya yoktu. Bu karşılaştırma QA başlangıcından **önceki** durumu, Keychain'i veya diğer dizinleri kapsamaz. Dosya içerikleri, kişisel bilgiler ve hash değerleri bu kanıta kaydedilmedi.

Daha sonra iOS QA bildirim izni penceresini kapatmak için simülatör veriler silinmeden yeniden başlatıldı. İki normal uygulama açılmadan aynı üç konum tekrar okundu; aynı bir PomoSprint dosyası değişmemişti ve HocamMacVar'da bu konumlarda yine dosya yoktu. Aynı kapsam ve başlangıç zamanı sınırlamaları geçerlidir.

Gerçek 25 dakikalık çevrimdışı/yeniden eşitleme turu bu koşuda başlatılmadı: ilk faz uzun süre Flutter test sürecini tutuyor ve diğer gerçek süreli testlerin zamanlamasıyla çakışıyordu. Mevcut kayıtların veya uygulama verilerinin silinmesi gerekmez.

## İmzasız iOS release derlemesi

Güncel `lib/` kaynakları ayrı QA kopyasına eşitlendikten sonra fiziksel iOS hedefi için `flutter build ios --release --no-codesign --no-pub` başarılı oldu. Yerel QA backend yapılandırması kullanıldı; uygulama cihaza kurulmadı. Çıktı arm64 `Runner.app` yaklaşık **55,2 MB** ve `codesign` kontrolüne göre imzasızdır. Bu, App Store indirme boyutu, mağazaya yüklenebilir imzalı IPA veya fiziksel cihazda çalışma testi değildir. [Güvenli derleme özeti](release-safe.txt).

Bu Flutter sürümünde simülatör yalnız debug modunu desteklediğinden, bu release derlemesi simülatör hedefi için değildir. Simülatördeki güncel arayüz testi ayrı bir debug native testidir.
