# Güncel ekran güncellemesi — 1 Kasım 2026

Deneme geçmişi ve net girişi artık Raporlar ekranındaki güncel arayüzü gösterir. Bu dört kare **iPhone 17 / iOS 27.0 simülatöründe**, `com.pomosprint.qa.reportpreview` QA uygulamasının gerçek Raporlar/kabuk bileşenleri ve kurgu TYT/AYT verileriyle çekildi; canlı kullanıcı veya sunucu testi değildir. Durum çubuğu 09:41 ve dolu pil/Wi-Fi/hat değerlerine geçici olarak ayarlandı; işlem sonunda override temizlendi. iOS 27 bu ayarda pili yeşil şarj simgesiyle gösterebilir.

Ham 1206×2622 ekranlar `analiz/site_qa_2026-11-01/native/` altında tutulur. Web çıktıları `sips` ile orantılı 538×1170’e küçültülüp iki yana birer piksel eklenerek 540×1170 yapılır; kırpma veya arayüzü yeniden çizme yoktur. Kaynak ve çıktı ölçüleri ile SHA-256 değerleri [yeni manifestte](manifest-20261101.json) kayıtlıdır. Dynamic Island diğer ekranlar gibi CSS tarafından eklenir.

| Sahne | Türkçe | English |
|---|---|---|
|Raporlar / Deneme geçmişi|[PNG](20261101/exam-history-tr.png)|[PNG](20261101/exam-history-en.png)|
|Net girişi|[PNG](20261101/exam-results-tr.png)|[PNG](20261101/exam-results-en.png)|

Aşağıdaki 28 Ekim manifesti ve 30 kare tarihsel kanıt olarak değiştirilmeden korunur. Eski Deneme geçmişi/net girişine ait dört dosya yayın paketinden hariçtir; diğer 26 kare ve dört video kullanılmaya devam eder.

# Tarihsel uygulama medyası — 28 Ekim 2026

Bu set tek iOS18.6 cihazından, **PomoSprint QA iPhone16 (18.6)** simülatöründen alındı. Uygulama güncel beş sekmelidir. Durum çubuğu09:41, pil100%, Wi-Fi3/hat4 olarak simctl ile sabitlendi ve çekim sonunda geri alındı. Bütün web görselleri **540×1170**; kullanılan iPhone çerçevesi iki dilde aynıdır. Dynamic Island, sitede fotoğraf ve videoların üzerine aynı oranda yerleşen dekoratif CSS katmanıdır; orijinal ekran dosyalarına eklenmez.

Tek kurgu hesap **Deniz**, UID `ca271e26-fc2c-44b6-b88f-9537f809639c`, yalnız `pomosprint_site32_dus` yerel veritabanında. Türkçe/İngilizce için hesap veya veri değiştirilmedi. Altı kurgu arkadaş: Ece,Mert,Ada,Arda,Duru,Can. Gerçek kullanıcı veya kullanım sayısı iddiası değildir.

Kontrollü geçmiş455 toplam dakika:125 Pomodoro/Maraton+330 Deneme;normal29puan/80kum,Deneme66puan/260kum,seri2. İki TYT130’ar kum verir. Fizik75 ilgili çalışma dakikası ve1,75→4,75 net içerir. Bu geçmiş tarihli kurulum455 dakika doğal beklenmiş sayılmaz. Odak/mola arkadaş varlığı yalnız gösterim için yenilendi; doğal Maraton AFK kontrolünün kanıtı değildir.

## 30 ekran (15×2 dil)

| Sahne | Türkçe | English |
|---|---|---|
|timer|[PNG](20261028/timer-tr.png)|[PNG](20261028/timer-en.png)|
|marathon-plan|[PNG](20261028/marathon-plan-tr.png)|[PNG](20261028/marathon-plan-en.png)|
|exam-catalog|[PNG](20261028/exam-catalog-tr.png)|[PNG](20261028/exam-catalog-en.png)|
|exam-running|[PNG](20261028/exam-running-tr.png)|[PNG](20261028/exam-running-en.png)|
|exam-history|[PNG](20261028/exam-history-tr.png)|[PNG](20261028/exam-history-en.png)|
|exam-results|[PNG](20261028/exam-results-tr.png)|[PNG](20261028/exam-results-en.png)|
|exam-insights|[PNG](20261028/exam-insights-tr.png)|[PNG](20261028/exam-insights-en.png)|
|reports-daily|[PNG](20261028/reports-daily-tr.png)|[PNG](20261028/reports-daily-en.png)|
|reports-weekly|[PNG](20261028/reports-weekly-tr.png)|[PNG](20261028/reports-weekly-en.png)|
|reports-monthly|[PNG](20261028/reports-monthly-tr.png)|[PNG](20261028/reports-monthly-en.png)|
|league-category|[PNG](20261028/league-category-tr.png)|[PNG](20261028/league-category-en.png)|
|league-global|[PNG](20261028/league-global-tr.png)|[PNG](20261028/league-global-en.png)|
|league-exam|[PNG](20261028/league-exam-tr.png)|[PNG](20261028/league-exam-en.png)|
|social|[PNG](20261028/social-tr.png)|[PNG](20261028/social-en.png)|
|avatar-collection|[PNG](20261028/avatar-collection-tr.png)|[PNG](20261028/avatar-collection-en.png)|

## Kaynak ve dönüşüm

Ham cihaz1179×2556; native screenshot yardımcısı yüksekliği1311’e ölçekleyerek604×1311 PNG üretir. Bu gerçek kaynak PNG baytları `analiz/ekran_site_2026-10-28/native/` altında korunur. Web türevi Lanczos ile en/boy oranı korunarak540×1170’e küçültülür ve gerektiğinde ince merkezî padding uygulanır. Ekran içeriği yeniden çizilmez,kırpılmaz veya esnetilmez.

[Fotoğraf manifesti](manifest-20261028.json) dosya/hash/ölçü/dil/owner ve gerçek kaynak yolunu taşır. [Video manifesti](../videos/manifest-20261028.json) gerçek kayıt ve dokunma/PTS kanıtlarını taşır. Kaynak cihaz videosu1178×2556’dır; encoder aynı540×1170 web boyutunu üretir.

## Videolar

| Video | Dil | Süre | Boyut |
|---|---|---:|---:|
|[timer](../videos/20261028/timer-tr.mp4)|tr|24.791667sn|216213 bayt|
|[marathon](../videos/20261028/marathon-tr.mp4)|tr|21.958333sn|203877 bayt|
|[timer](../videos/20261028/timer-en.mp4)|en|24.833333sn|202975 bayt|
|[marathon](../videos/20261028/marathon-en.mp4)|en|22.000000sn|224919 bayt|

Dört video gerçek zamanlıdır; hızlandırma yoktur. Sessiz H264/yuv420p/24fps,her biri256KiB altında. Otomatik,sessiz,döngüde,playsinline oynar; reduced-motion ve kullanıcı duraklatması korunur. Beyaz imleç/tıklama halkası yalnız gerçek native dokunma koordinat/zaman kayıtlarından türetilmiştir. Sayaç25/50dk,Maraton5dk+1dk kuralları değiştirilmedi; demo odakları tamamlanmadan UI’den iptal edilir ve ödül üretmez. En sonda tek165dkTYT başlatılıp iki dilde çekilir ve0ödülle vazgeçilir; geçmiş satırı silinmez.

## Kontroller

30 native görsel iki ajan tarafından tek tek incelendi. Yeni ödüller/diller/isimler/durum çubuğu ve hizalar doğrulandı. EN Unanswered başlık bölünmesi düzeltildi ve set yeniden çekildi. Sitenin30PNG/4MP4/4poster boyut/hash/locale/eksik-kullanılmayan medya testleri korunur. [Video görsel/packet QA](../../analiz/ekran_site_2026-10-28/video_review/README.md) ve [Safari manuel QA](../../analiz/ekran_site_2026-10-28/browser/SAFARI_MANUEL_2026-10-28.md).

Küçük sunum sınırları raporlarda açık: kaydırılabilen aylık sekme etiketi dar kadrajda kısalabilir; koleksiyon başlığı ellipsis kullanır; video ortasında gerçek pause/start bilgi snackbar’ları görünür. Kaydırma kadrajı dışında kalan aylık/haftalık toplamlar yalnız fotoğraftan doğrulanmış sayılmaz; native rapor testleri ve bağımsız SQL ayrı kanıttır.

Eski8/27Ekim karışık dil/boyut seti ve27 kullanılmayan public medya dosyası kaldırıldı. Yeni set henüz canlıya deploy edilmedi.
