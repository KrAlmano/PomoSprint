# Deneme ekranı görünüm güncellemesi — 6 Kasım 2026

`lib/screens/exam_screen.dart` içindeki katalog kartları, aktif deneme, geçmiş içgörü kartı ve lig bilgi kartı uygulamanın mevcut renkleriyle yeniden düzenlendi. Kartların 260 ms giriş hareketi, sekme geçişleri ve gerçek kalan zamana bağlı ilerleme göstergesi eklendi; hareketi azalt ayarı bu animasyonları kapatır. Sınav kuralları, süreler, puan, kum, kayıt ve RPC davranışı değiştirilmedi.

`flutter analyze`: temiz. Son durumda ilgili 10 test dosyası: **58 başarılı**; TR/EN, küçük ekran, 2× yazı, yatay, geçmişin raporlarda gösterimi, başlatma ve dil kontrolü dahil. `test/exam_progress_animation_test.dart` hareketi azalt, gerçek zamana göre ilerleme, bekleyen başlangıç ve ödülün değişmemesi senaryolarını kapsar. Bütün uygulamanın testleri bu görsel değişiklikten sonra yeniden çalıştırılmadı.

iPhone 17 iOS 27 simülatöründe ayrı `com.pomosprint.qa.examdesign` uygulaması ve sahte backend ile [Türkçe katalog](katalog-tr.png) ve [aktif TYT](aktif-tr.png) görseli kontrol edildi. Sahte saat sabit olduğundan aktif çekim doğal geri sayım testi değildir. İngilizce ve yatay native olarak bu turda doğrulanmadı; ilgili widget testleri çalıştırıldı. Test uygulaması kaldırıldı; gerçek hesap ve sunucu kullanılmadı. Kullanıcının cihazı veya diğer uygulamaları silinmedi.

Bu yerel kaynak değişikliği mağazaya, siteye veya canlı sunucuya dağıtılmadı. Önceki [yayın ve güvenlik raporundaki](../YAYIN_HAZIRLIK_RAPORU_2026-11-06.md) açık konular sürer.
