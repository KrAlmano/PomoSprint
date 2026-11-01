# Raporlar ve deneme ligi — 1 Kasım 2026

## Rapor görünümü — sonraki düzenleme

Raporların dört sekmesi Türkçe/İngilizce kısa etiketlerle eşit alanlara yerleşir; dar alanda iki sıra, büyük erişilebilirlik yazısında kaydırma kullanılır. Seçili durum, ekran okuyucu adı ve dokunma eylemi korunur. Deneme geçmişinde tamamlanma yeşil onay ve metinle, vazgeçme nötr biçimde gösterilir; içgörü ve metrikler kartlarla düzenlenir. Hesap, süre ve ödül formülleri değiştirilmedi.

Son `flutter analyze` temiz; tam `flutter test --concurrency=2` **1527 başarılı, 5 isteğe bağlı ekran görüntüsü atlaması**. TR/EN, açık/koyu, 320 pt, büyük yazı, sekme görünürlüğü ve durum simgeleri hedefli testlerle kontrol edildi. İlk tam turda eski sekme metnine bağlı iki test başarısız oldu; testler sabit sekme anahtarına taşınarak tekrarda geçti. Ayrı iPhone 17 QA uygulaması örnek kayıtlarla tekrar açıldı; dört sekme ve yeşil tamamlanma etiketi görsel olarak kontrol edildi.

## Kapsam

- Kullanıcının daha sonra planlama isteği doğrultusunda bağımsız alan denemesi prototipi, testleri ve ayrı simülatör uygulaması kaldırıldı. Gerçek bir alan denemesi sunulmadı.
- Raporlar içindeki Denemeler sekmesi mevcut ortak `ExamService` geçmişini ve net/not düzenlemesini kullanır. Normal rapor yüklemesi hata verse bile deneme geçmişi ayrı erişilebilir. Deneme kartlarında durum, tarih, net ve ödül özeti öne çıkar; ayrıntılar açılır. Vazgeçilen denemenin planlanan süresi gerçekleşen süre olarak gösterilmez. AYT'de seçili modüllerin soru kapsamı ayrı gösterilir; eski veya tanınmayan seçim, tüm testlerin seçildiği varsayılmadan açıklanır.
- Haftalık analizde Deneme toplamına dahil sınavların adları ve süreleri alt kırılımda görünür; ikinci kez toplam süreye eklenmez. Tamamlanmamış denemeler bu toplamın dışında kalır. Çalışma günü için mevcut 04.00 ve saat dilimi hesapları korunur.
- Deneme ligi Sıralama bileşenlerini kullanır. Henüz odaya yerleşmemiş kullanıcının sunucu yer tutucusu sahte birincilik olarak gösterilmez. Gizlenmiş kimlikler korunur; bekleyen avatar ödülleri verilmiş gibi gösterilmez.
- Rapor verisi için eşzamanlı aynı hesap `ExamService.refresh` istekleri aynı yenilemeyi bekler; hesap değişiminde eski sonuçlar uygulanmaz. Raporlar tekrar görünür olduğunda süre–net içgörüleri güncellenir.

## Canlı ortam sınırı

Bu değişiklikler yalnız çalışma dalındadır; canlı veritabanına migration uygulanmadı, site veya uygulama yayımlanmadı. Önceki salt okunur kontrolde canlı Deneme RPC/tablosu yoktu; bu koşulda yeni Deneme raporlarının canlıda çalıştığı söylenemez. Önceki cihaz devrinde normal simülatör uygulaması durdurulmuş bir yerel QA sunucusuna bağlıydı; bağlantı uyarısının nedeni çalıştırılan yapılandırmaya göre farklı olabilir. [Sunucu raporu](SUNUCU_RAPORU_2026-11-01.md) ve [önceki QA](QA_2026-11-01.md) başvuru kaynağıdır.

## Doğrulama

- `flutter analyze`: temiz. Son tüm `flutter test --concurrency=2`: **1521 başarılı, 5 isteğe bağlı ekran görüntüsü üretimi atlandı**.
- Hedefli tur: **48 başarılı**. Rapor içi deneme geçmişi, TR/EN net/not düzenleme, normal rapor hatasında erişim, dar ekran/büyük yazı, görünürlük ve hesap değişimi, eşzamanlı yenileme, sahte ilk sıra, haftalık sınav kırılımı ve 04.00 sınırı doğrulandı.
- İlk analiz turunda test dosyasında kullanılmayan import tespit edildi; kaldırılıp analiz ve testler tekrarlandı.
- Simülatörün ilk görsel kontrolünde seçili Denemeler sekmesinin yatay çubuk dışında kalabildiği bulundu; seçimin görünür konuma getirilmesi eklendi. AYT'de yalnız bir alan seçildiğinde üst kartta tüm sınavın soru sayısının çözülen kapsam gibi görünmesi de düzeltildi; her iki değişiklik son test turuna dahildir.
- iPhone 17 simülatöründe ayrı `com.pomosprint.qa.reportpreview` uygulaması, sahte servisler ve örnek TYT/AYT kayıtlarıyla derlenip açıldı. Son ekranda seçili sekme ve AYT 40/160 kapsamı görsel kontrol edildi. Bu önizleme normal uygulama değildir; gerçek hesap, canlı kayıt veya fiziksel cihaz doğrulaması sayılmaz.
- Bu testler yerel sahte servis/veri kullanır; gerçek veritabanı bağlantısını, gerçek teslimi veya mağazaya hazır olmayı kanıtlamaz.
