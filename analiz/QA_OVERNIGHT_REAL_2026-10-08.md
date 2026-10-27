# Gerçek süreli gece test sonucu — 8 Ekim 2026

Testler **07:00 Türkiye saatine kadar sürdürüldü**. Son devam koşusu `overnight1008_05` **80/80** son kontrolle geçti; ek yerel lig/sahiplik sorgusu **18/18** geçti. Manager 04:00:12 UTC / 07:00:12 TR'de tamamlandı. iOS ve Android ham native loglarında `All tests passed` ve `tearDownAll` ayrıca doğrulandı.

Yerel Docker Supabase'e bağlı **iki gerçek uygulama** (iOS 18.6 Pro ve Android 16) ile **üç bağımsız Auth/API gözlem hesabı** kullanıldı. Her koşuda beş ayrı kimlik ve hesap başına dört arkadaş vardı. Run04 ve run05 grupları birbirinden farklı: toplam on yerel Auth kimliği, bunların dördünde tamamlanmış odaklar. Beş hesabın hepsi native ekranda çalışmış gibi sunulmuyor. Canlı üretim DB'sine, kişisel hesaplara veya dış e-posta hizmetlerine bu gece dokunulmadı.

## Gerçek kaydedilen sonuç

| Koşu | Kayıt | Dakika | Puan | Kum | Sonuç |
|---|---:|---:|---:|---:|---|
| `overnight1007_04` | 14 | 500 | 114 | 280 | Kısmi: aylık test bulucu hatasında durdu; 53/72, tam geçiş false |
| `overnight1008_05` | 8 | 250 | 58 | 160 | Devam tamamlandı: 80/80 |
| **Kabul edilmiş toplam** | **22** | **750** | **172** | **440** | İki ayrı grubun DB toplamı |

Toplamlar ayrıca tek yerel salt-okuma sorgusuyla yeniden doğrulandı: 22 farklı `client_uuid`, profil/kayıt dakika ve puan toplamları aynı, kategori sahibi karışması sıfır. Bu toplam önceki yarım koşuyu tam başarıya çevirmez. Birleşik DB kanıtı (ham çıktı §37 temizliğinde kaldırıldı).

Devamda iOS ve Android'in her biri **4 kayıt / 125 dakika / 29 puan / 80 kum** üretti. Her hesapta gerçek 25×2 Maraton, normal 50 ve normal 25 tamamlandı; ayrıca bir normal50 iptali kayıt/ödül üretmedi. Her UUID için native gerçek geçen süre ve sunucu 1500/3000 saniyelik kayıt aralığı ayrı doğrulandı. Kısa sayaca veya QA complete helper'ına başvurulmadı.

## Çalışan davranışlar

- **Puan:** normal25=5, normal50=12. Gerçek25×2 Maraton=12 (+2 yalnız son odakta); önceki koşuda50×2=28 (+4 yalnız son odakta). Önceki gerçek duraklatmalı25=4 ve50=9 kanıtları korunur.
- **Mola/onay:** iki platformda gerçek300 saniye mola ve60 saniye Buradayım penceresi işlendi. Kahve yalnız molada, onayda normal kum saati; onay düğmesi görünür. Önceki koşudaki yanıtsız300+60 sonunda yalnız ilk tamamlanmış25dk/normal5puan korundu; sonraki odak/bonus verilmedi. Bu timeout devam koşusunda tekrarlandı sayılmadı.
- **Raporlar:** çekirdek100dk, dolgu sonrası125dk ve final125dk aşamalarında iki hesapta Günlük/Haftalık/Aylık UUID/dakika/kategori kontrolleri geçti. Final günlükte2sa5dk,29puan/80kum ve5 Pomodoro birimi görünür; 50dk iki Pomodoro birimi olduğundan bu4 DB kaydıyla tutarlıdır. Aylık miktar yalnız PNG'den çıkarılmadı, native hücre/UUID toplamı kontrol edildi.
- **Gün sınırı:** önceki koşuda gerçek04:00 TR rapor geçişi, süren UUID'nin korunması ve sınırı aşan seansın başlangıç gününe yazılması gözlendi. Yeni güne başlayan25dk da8 Ekim'e kaydoldu. Run04'ün tamamlanmamış Android final kontrolleri geçilmiş sayılmadı; yeni devamda gün sınırı yeniden yapıldı iddiası yok.
- **Sosyal:** iki aktörün molasında beş Auth hesabının tam durum haritası denetlendi; moladaki kullanıcıyı dört arkadaşı break, diğer aktörü focus olarak gördü. Odak PNG'lerinde yalnız Odaklanıyor/kırmızı nokta var. Yeni Molada UI PNG'si alınmadı; API kanıtı UI kanıtı olarak sunulmadı. Finalde aktif odak yokken sosyal boş durum doğru.
- **Sıralama/izolasyon:** final arkadaş sıralamasında iki aktör29, üç gözlemci0puan. Beş hesabın dört arkadaşı var; kendi profil/seans RLS okumaları ayrıdır. Lig sorgusunda oda üst sınırı30, global çift aktif üyelik0; iki puanlı aktör20 üyeli aynı Bronz odada birer üyelikle, üç puansız gözlemci ligsiz. UUID/kategori sahibi, duplicate, beklenmeyen kayıt ve bekleyen arkadaş isteği hatası yok.
- **Görünüm:** dikey eski kum saati/kategori düzeni ve kompakt Maraton girişi korundu. İki platform yatayda sayaç,1/1hak,duraklat/durdur görünür; raporlarda taşma/boş içerik bulunmadı. Final sıralama PNG'lerinde yenileme göstergesi ve test dokunma işareti bulunduğu için tamamen durmuş ekran kanıtı diye sunulmadı.

## Bulunan ve giderilen test aracı hataları

Run04 01:30:49 UTC'de aylık250dk'yı tek günlük ısı haritası etiketinde arayan bulucuyla durdu. Ürün verisi doğruydu:7 Ekim225dk +8 Ekim25dk. `s_overnight_real_time_test.dart` artık her günün tam tarih/süre etiketini ve aylık toplamı ayrı denetliyor. İki yeni TR/EN regresyonu eklendi; eski başarısız native log/sonuç silinmedi. [Run04 kısmi rapor](QA_OVERNIGHT_RUN04_PARTIAL_2026-10-08.md).

Görünür düğmeye dokunmadan önce gereksiz `ensureVisible` uygulayan test yardımcısı düzeltildi. Ayrı iPhone16e kontrolünde boşta/odak/duraklat/devam/ikinci duraklatma reddi olmak üzere beş durumda kategori tam görünür ve kaydırma0; aynı UUID/tek hak korundu. Bu kısa kontrol iptal edildi, kayıt/puan üretmedi. Run04 eski helper ile kalır; yeni devam düzeltilmiş helper ile derlendi. Ürün yerleşimi değişmedi.

Aynı adlı PNG üzerine yazılmasını önlemek için hafif dosya arşivleyici kullanıldı. Devamdaki46 olayın46 görüntüsü SHA256 ile ayrı korundu, kayıp/pending0; ana yollar44 çünkü iki ad tekrar kullanıldı. Run04'te daha önce üzerine yazılan4 olay geri getirilemedi ve görsel kanıt sayılmadı. İlk yol hatası ve yüksek yazılım çizici yüküyle duran01–03 girişimleri0kayıtla tarihsel kalır.

## Doğrulama ve son ortam

Son tam Flutter paketi **1176/1176**,0atlama; `SCREENSHOTS=true`, `concurrency=1`,211sn. Yeni iki TR/EN aylık vaka dahil; analiz temiz. Önceki44PNG özgün hash'leri korundu. Ayrı offline sonuç-guard vakaları native başarı sayısına eklenmedi. Test binding uzun odakta az kare çizdi; gerçek Timer/DateTime korundu, bu animasyon akıcılığı ölçümü değildir.

Beş hesaplı API138 örnek (en büyük aralık60.861sn), sunucu config28 örnek (301.72sn) başlangıçtan07TR sınırına gereken kapsamı sağladı. QA complete helper sayısı0, mola300/onay60 ve normal RPC MD5'i değişmedi. [Devamın otomatik80-kontrol raporu](QA_OVERNIGHT_CONTINUATION_2026-10-08.md), nihai JSON (ham çıktı §37 temizliğinde kaldırıldı), lig18-kontrol sonucu (ham çıktı §37 temizliğinde kaldırıldı).

Bana ait Pro/Android/host/caffeinate/arşiv watcher ve boşta Gradle süreci kapandı. Başka çalışmaya ait HMV cihazlarına dokunulmadı. **Plus normal uygulaması açık:25:00,67puan/160kum,TEST etiketi yok;25/50 gerçek modları kullanılabilir.** Docker ve yerel Maraton paketleri bu önizleme için açık kaldı. Sabah ekranı (ham çıktı §37 temizliğinde kaldırıldı), son doğrulama (ham çıktı §37 temizliğinde kaldırıldı).

Bu koşullarda yeni ürün çökmesi veya kayıt/puan/rapor hatası gözlenmedi. Bu gece OS process-kill/background, fiziksel cihaz, gerçek Google/Apple girişleri, imzalı mağaza dağıtımı veya canlı SQL/deploy doğrulaması yapılmadı. Önceki testlerin kapsamı kendi tarihli raporlarında kalır; yayın işleri bu yerel gece koşusuyla tamamlanmış sayılmaz. Normal kök `.env`, global Xcode seçimi ve üretim değişmedi; commit/push/deploy yapılmadı.
