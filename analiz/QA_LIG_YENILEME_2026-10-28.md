# 28 Ekim — aylık lig istemci/RPC incelemesi ve yenileme düzeltmesi

## Bulgu ve davranış

İki yenileme hatası bulundu ve regresyonla yeniden üretildi:

1. Sıralama ekranı ayın değiştiği anda açık kalırsa eski dönem satırları/pending hedef kalıyordu. `CountdownText` sıfıra geldiğinde yalnız “sıfırlanıyor” yazıp kendi timerını bitiriyor, üst ekranın verisini yenilemiyordu.
2. Deneme Ligi açıkken aşağı çekerek yenileme yalnız deneme geçmişini yeniliyor, alt lig görünümüne yenileme sinyali göndermiyordu. Aynı sekmede cüzdan/sıra eski kalabiliyordu; ay sonu için de tetikleyici yoktu.

İlk üç regresyon eski kodda başarısız oldu (`/tmp/pomosprint_league_refresh_before.log`). Düzeltmeden sonra:

- `CountdownText` her hedef için bir kez `onElapsed` bildirir. Sıralama yalnız görünür ve önplandayken dönemi zorunlu yeniler; normal30sn bayatlık eşiği bu olayı engellemez. Diğer sıralama sekmelerinin önbelleği de bayat işaretlenir. Aynı eski dönem yanıtı tekrar gelirse istek döngüsü oluşmaz.
- Önplana dönüş, geçmiş dönem hedefini kontrol eder. Görünmez/arka plan görünümü ağ isteği başlatmaz. Mevcut requestId+owner yanıt korumaları korunur.
- Deneme ekranı pull-to-refresh ve önplana dönüşte açık bir `refreshRevision` geçirir. Alt lig görünümü bu sinyali ve görünürlük değişimini dinler; her service rebuild'i ağ isteği başlatmaz. Dönem için tek timer kurar, arka planda anında iptal eder. Owner değişiminde eski lig snapshot'ı temizlenir.
- Testlerin saatini denetlemek için Sıralama/Countdown bileşenlerinde isteğe bağlı saat sağlayıcı vardır; normal uygulama `DateTime.now`, Deneme mevcut sunucu-düzeltilmiş servis saatini kullanır. Ürün süreleri veya katalog hızları değişmedi.

## Doğrulama

`test/league_refresh_regression_test.dart` **7/7**: açık dönem yenilenmesi/hedefin değişmesi, Deneme cüzdanının pull-refresh ile güncellenmesi, Deneme ay sonu, görünmez Sıralamada istek olmaması, callback'in hedef başına tek çalışması, Deneme arka plan/önplan ve Sıralamada30sn önbellek süresi dolmadan ay değişimi. Dönem testleri kontrollü saat/yanıtlardır; gerçek ay sonunun beklendiği iddia edilmez.

Mevcut aylık istemci, sıralama modelleri, lig politikası, Deneme UI ve30 hata sınıflandırıcısıyla birlikte **75/75** geçti (`/tmp/pomosprint_league_refresh_final.log`). Sonraki bütün-proje analizinde bildirilen iki çok satırlı `if` süslü-parantez uyarısı düzeltilip dosyalar formatlandı; bunlar işlevsel değişiklik değildir. Tam proje/native kapanış sonuçlarını kök ilerleme kaydı verir.

## RPC eşleşmesi

Yeni, ayrı izole `pomosprint_night_security` hesaplarıyla12/12 sözleşme kontrolü geçti (`build/overnight_backend/league_contract_audit_results.json`):

- Normal ve Deneme aynı geçerli hedefi okur; puan kazanmış kullanıcıdaki yeni hedef sonraki ay tarihçesine yazılır, mevcut hedef korunur.
- Global/segment okuması hedefi değiştirmez. Global diğer hedefleri kapsar, gizli ve iki yönlü engelli kimlikleri dışarıda bırakır; segmentte görünmeyen kimlik/ad maskelenir.
- Deneme kumu ve puanları mevcut PostgreSQL JSON yanıtında tamsayıdır; Dart'ın tamsayı ayrıştırıcısıyla uyumludur. Deneme puanı normal lig puanına karışmaz.
- Eski sunucu `get_my_league_ranking_v2`/`get_league_config` yokluğunda yalnız PGRST202 için eski RPC'lere geri döner. Ağ hatası yeni davranışı yanlışlıkla eski kurala düşürmez.
- Geç gelen offline normal seansın kapanmış aya yazılması ve kesinleşmiş terfi/ödülün değişmemesi önceki15 hedef/dönem testinin konusudur; bu tur yeniden gerçek ay geçişi çalıştırılmış sayılmadı.

İlk ek RPC senaryosunda aynı kullanıcının tarihsel135dk Deneme fixture'ı mevcut25dk normal seansla çakıştığından sunucu doğru `exam_overlap` reddini verdi. Sözleşme testinde Deneme için ayrı yeni kullanıcı kullanılarak12 kontrol tamamlandı. Bu bir ürün hatası olarak kaydedilmedi.

AnaQA şeması değiştirilmedi, canlıya istek yapılmadı.30 güvenlik paketi hâlâ ayrı adaydır; bu UI düzeltmesinin önkoşulu değildir.

## Aynı turda kapatılan yükleme göstergesi köşesi

Özellik lig isteği beklerken `available:false` olursa eski yanıtın revision'ı geçersiz oluyor, fakat erken dönüş `_loading` / `_failed` durumunu temizlemiyordu. İki ek regresyon önce bu hataları yeniden üretti. Kapalı durumda timer, eski snapshot, yükleme ve hata temizleniyor; eski yanıt sonuç yazamıyor. Yeniden açılınca yalnız yeni cevap gösteriliyor. 748. satırdaki aynı erken-dönüşün süslü-parantez uyarısı da giderildi.

Son dar tur: **9 yenileme regresyonu +3 mevcut Deneme UI testi =12/12 PASS**, `/tmp/pomosprint_league_spinner_after.log`. Bu son set yukarıdaki75'in üzerine eklenmiş bağımsız75 yeni kontrol değildir;7 yenileme testinin mevcutlarını da tekrar içerir. Kaynaklar bu turun sonunda formatlandı. AnaQA şeması hâlâ29'da,30 uygulanmadı.
