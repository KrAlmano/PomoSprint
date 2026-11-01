# iOS Deneme ekranı — 1 Kasım 2026

Güncel ürün kodu, iPhone 17 simülatöründe ayrı `com.pomosprint.qa.nov1exam` uygulaması ve yerel KPSS veritabanıyla test edildi. Türkçe ve İngilizce hedef/KPSS seçimleri, 20 sınavlık katalog, resmî süreli deneme başlatma, üç saniye sonra vazgeçme ve ödülsüzlük ile sonrasında normal odak başlatıp iptal etme doğrulandı. Nihai tur **1/1 PASS, exit 0**: [kısa kayıt](pass-safe.txt), [Türkçe ekran](hedef-kpss-tr.png), [İngilizce ekran](hedef-kpss-en.png). 130 dakikalık sınav süresi doğal olarak tamamlanmadı.

İlk turda KPSS başlatma/vazgeçme adımları geçti; ardından normal odak denemesi iOS'un test paketine ait bildirim izni penceresi açık kaldığından zaman aşımına uğradı ve tur **FAIL** oldu. Simülatör verileri silinmeden yeniden başlatıldı; test, bildirim teslimini ölçmediği için yalnız QA uygulamasında bildirimleri kapatacak şekilde düzeltildi ve yukarıdaki tur tekrarlandı. Bu işlem fiziksel cihaz veya bildirim teslimi doğrulaması değildir.
