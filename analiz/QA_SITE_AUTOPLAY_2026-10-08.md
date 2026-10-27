# Site — telefon oranı ve sessiz otomatik kayıt QA

Tarih: 8 Ekim 2026. Güncel devir: [PROJE_DEVIR.md §28](../PROJE_DEVIR.md). Kullanıcı telefon çerçevesi içinde üst/alt gri boşlukları gösterip videoların GIF gibi otomatik, sessiz ve sürekli oynatılmasını istedi. Ana sayfa ve Özellikler düzeni korunur; yeni ürün özelliği veya bölüm eklenmez. Root yalnız ayrı Safari çalışma penceresini kullandı; Chrome kullanıcıya bırakıldı.

**Canlı Worker `96fb9b24-e276-4a91-986b-e5a48180b4e4`**, 83 public varlık (24 yeni/değişmiş, 59 mevcut). CSS/ana JS `20261008d`. Yayın sonrası 17 HTTP isteğinde 52/52 kontrol geçti. Bu web yayını uygulamanın mağazada hazır olduğu anlamına gelmez. Önceki [Features QA](QA_SITE_FEATURES_2026-10-08.md) / §27 ve [medya QA](QA_SITE_MEDIA_RELEASE_2026-10-08.md) / §26 kendi tarihsel kapsamlarıyla korunur.

## Değişiklik ve gerçek kusur

`.phone` dış kutusu 540/1170 oranını 8 px padding dahil taşıyordu. 260 px dış genişlikte iç ekran 244×547,3 olurken gerçek görüntü 244×528,7'ydi; `object-fit:contain` üst/altta yaklaşık 9,3 px gri alan bırakıyordu. Oran iç `.phone-screen` üzerine taşındı (`height:auto; aspect-ratio:540/1170`); dış yükseklik iç ekran+padding'den gelir. `contain` korunur; kırpma veya esnetme yoktur. Yerel 320/390 geometri kontrolü root tarafından görüldü. Features başlık/metin/liste/kart/CTA öğeleri §27'deki gibi statiktir; yeni medya davranışı anker düzeltmesini geri almaz.

Değişen ürün kaynakları: `landing/css/style.css`, `landing/index.html`, `landing/features.html`, `landing/js/main.js`; ortak cache/partials ve diğer HTML cache adresleri root tarafından güncellendi. `landing/worker.js` yalnız yeni açık MP 4 yollarını allowlist'e ekler; `.assetsignore`/private yollar ve mevcut yardımcı no-store/CSP davranışı korunur. Regresyonlar `scripts/test/landing_media.test.mjs`, `landing_worker_range.test.mjs`; mevcut Features ve waitlist davranışları da tam pakette koşulur.

## Gerçek kayıt ve imleç açıklaması

Kayıt doğrudan iPhone 16 Plus/iOS 18.6 simctl capture'ıdır; native 1290×2796 görüntü 540×1170'e normalize edilir. Simctl macOS imlecini ham videoya yazmaz. **Görünen imleç ve dokunma halkası, gerçek CUA tıklama koordinat/zamanlarına hizalanmış editorial overlay'dir**; ürün UI'si native kayıttır. Beklemeler kısaltılır. Pomo kaydı 6 gerçek dokunmada süre/kategori, başlat/duraklat/devam; Maraton kaydı 7 dokunmada plan/seans/süre seçimi ve başlatmayı gösterir. Tam 25/50 dk odak veya tamamlanmış Maraton videosu değildir.

| Medya | Bayt | Süre | Kare | SHA-256 |
|---|---:|---:|---:|---|
| `timer-demo-20261008d.mp4` | 251085 | 28,166667 sn | 676 | `6112903f34247f648fb33b8351172fb8ee16c5d06a1a4f26efccef215c2b0517` |
| `marathon-demo-20261008d.mp4` | 206935 | 26,416667 sn | 634 | `433551e05fd0f92194ebe90062cd43745828681e6d38fc6f641b1555f4641ac2` |

İki dosya da 540×1170,24 fps, H.264/yuv420p,sessiz,faststart'tır. Aynı adlı WebP posterler de 540×1170'dir. İki gerçek video dosyası üç HTML alanda kullanılır: Home Maraton, Features Pomo ve Features Maraton.

İlk VFR trim/concat denetiminde klip toplamı ve tap projeksiyonu son video zaman çizelgesiyle uyuşmadı. İlk denetim başarısız sayılır; dosyaları silinmedi. Root native kaydı CFR mezzanine'e normalize edip klip PTS'lerini sıfırladı; sabit kare sayısı/gerçek çıktı offsetleriyle tekrar encode etti. Bağımsız packet demux son 676/634 kare ve 35/35 zamanlama kontrolünü doğruladı. Native packet denetim aracında B-frame decode sırası PTS'e göre sıralanarak ayrıca düzeltildi; önceki harness çıktısı korunur. İlk kanıtlar: `capture_timing_initial.json`, `native_packet_timing_initial.json`, `native_packet_timing_initial_before_pts_sort.json`, `media_preflight_before_timing_fix.json`. Son zamanlama 35/35 (ham çıktı §37 temizliğinde kaldırıldı) ve format 16/16 (ham çıktı §37 temizliğinde kaldırıldı).

## Oynatma sözleşmesi

- HTML: `data-demo-video`, lazy `data-src`, `autoplay muted loop playsinline preload="none"`, gerçek poster ve kardeş `<img>`. Native controls/play overlay yoktur.
- JS görünürlük denetimi autoplay'i devralır; MP 4 adresi ancak yeterince görünürken `src`e taşınır. Ekran/sekme dışına çıkınca pause, geri gelince aynı konumdan resume vardır. Yüklenmiş video gereksiz yeniden indirilmez.
- Video alanı focusable `role=button/tabindex=0`; tıklama veya Space/Enter isteğe bağlı duraklat/devam. Erişilebilir ad eyleme göre değişir. Kullanıcının manuel duraklatması viewport/sekme dönüşünde korunur; yeni görünür düğme yoktur.
- Reduced-motion başlangıçta ve canlı tercih değişiminde statik gerçek görüntü verir. Başlangıçta MP 4 yüklenmez; CSS video katmanını gizler. JS yokluğunda da gerçek görüntü kalır.
- Yükleme veya autoplay reddi Promise'ı yakalanır; kayıt gizlenip gerçek poster kalır. Geç başlayan/önceki iptal edilen play isteği güncel görünürlük ve manuel tercihi bozamaz. IntersectionObserver olmayan ortam ebeveyn ekran rect'ini ölçer.

Davranış 11/11 medya regresyonunda kontrol edildi: lazy/sessiz döngü, viewport/sekme pause-resume, başlangıç/live reduced-motion, autoplay reddi, yükleme hatası, geç play çözülmesi, eski AbortError izolasyonu, observer fallback, tıklama/Space/Enter tercihi ve oran/HTML sözleşmesi. Features 5/5 + waitlist 7/7 ile ilgili 23/23; bunlar 133 testin alt kümeleridir, ayrıca toplam sayıya eklenmez.

## Worker ve public veri sınırı

Range yalnız eski `videos/{timer,marathon}-20261008.mp4` ve yeni `videos/{timer,marathon}-demo-20261008d.mp4` olmak üzere dört açık yol içindir. **256 KiB/262144 bayt üst sınırı değişmedi**; iki yeni kayıt sınırın altındadır. GET tek Range 206/416 güvenlik/cache/ETag başlıklarını korur; büyük dosyada iptal/normal streaming fallback vardır. Normal GET/HEAD,304/404 ve başka varlıklar aynen geçer. Yeni dosya için sınırı büyütmek yerine encode boyutunu sınırın altında tut.

Canlı 17 gerçek istekte 52/52 kontrol: home/features/FAQ/CSS/main ve yeni dört medya gövdesi SHA eşitliği; d cache adresleri, CSP/nosniff/cache; sorgu koruyan www/.html yönlendirmeleri; iki MP 4 Range 206 gövdesinin gerçek dosya dilimiyle birebir eşleşmesi; üç özel yol 404. Canlı HTTP (ham çıktı §37 temizliğinde kaldırıldı). Önceki 32/32 veya 59/59 sonuçlarla toplanmaz. Private kimlik bilgileri build alanında kalır; landing public listesinde credential/test/doc kaynakları yoktur.

## Son koşulan kontroller

| Kontrol | Sonuç | Kanıt |
|---|---|---|
| Medya formatı/sessiz/faststart/boyut/allowlist |16/16|media_preflight.json (ham çıktı §37 temizliğinde kaldırıldı)|
| Gerçek klip/kare/tap saatleri + veri izolasyonu |35/35|capture_timing_final.json (ham çıktı §37 temizliğinde kaldırıldı)|
| Ağsız Node tüm paket |133/133; 0 hata/atlama|verification_summary.json (ham çıktı §37 temizliğinde kaldırıldı)|
| `flutter analyze` |Temiz|flutter_required_checks.json (ham çıktı §37 temizliğinde kaldırıldı)|
| Tam Flutter screenshot açık/concurrency 1 |1176/1176; 0 hata/atlama; 405,35 sn|verification_summary.json (ham çıktı §37 temizliğinde kaldırıldı)|
| Sekiz özgün PNG geri yükleme |8/8 birebir hash|flutter_required_checks.json (ham çıktı §37 temizliğinde kaldırıldı)|
| Statik kaynak |18 HTML/739 referans/65 hedef/30 SRI/44 ARIA/58 img/3 video|source_preflight.json (ham çıktı §37 temizliğinde kaldırıldı)|
| Partial/diff |Temiz|local_final_status.json (ham çıktı §37 temizliğinde kaldırıldı)|
| Canlı HTTP |17 istek/52 kontrol, 52 geçti|http_post_deploy.json (ham çıktı §37 temizliğinde kaldırıldı)|

Flutter tekrarları birim/widget kapsamıdır; bu tur yeni fiziksel/native tam seans veya provider testi değildir. Node son gerçek encode dosyalarıyla tekrarlandı; dosya hash'leri test sonrası aynı kaldı. Kaynak/Worker bağımsız salt okuma incelemesi yeni açık bulgu üretmedi.

## Safari ve kapanış gözlemi

Root Safari yerel 320/390 geometri, tıklama duraklatma ve Space devamı doğruladı. Final canlı masaüstü Maraton kaydı 26,416667 sn, muted/loop true, paused false, readyState 4 ve native 540×1170 /iç ekran yaklaşık 244×529 olarak gözlendi. **Gerçek otomatik döngü 13,080 → 26,146 → 0,228 sn** sarılarak doğrulandı; oynatmaya basılması gerekmedi. Aynı anda görüş dışı Pomo videosunun MP 4 adresi boş, currentTime 0 ve paused true kaldı. `safari_live_playback.ax.txt` /`safari_live_loop.ax.txt` kanıtları saklıdır.

Canlı Features 320×844'te gerçek sayaç 2 sn + editorial imleç, üst/alt gri boşluk ve yatay taşma olmadan görüldü (`production_features_320.png`). Canlı Home 390×844'te yeni kaydın ilk imleçli karesi/açıklaması görsel olarak yatay taşmasız görüldü (`production_home_390.png`, `safari_live_home_390.ax.txt`). Bu sonuçlar native Safari görsel kontrolüdür; RDM+Inspector ek DOM sorgusu tamamlanmadı, DOM scrollWidth ölçümü yapıldığı iddia edilmez. Yerel AX kanıtları `safari_local_playback.ax.txt`, `safari_local_keyboard_toggle.ax.txt`, `local_320_frame.png`; canlı masaüstü `production_desktop.png` aynı klasördedir. Chrome kullanılmadı.

Restore sonrası canlı Supabase'e bağlı normal TR giriş ekranı root tarafından `production_simulator_login.ax.txt` ile doğrulandı. Kendi 8789 Python önizleme süreci (PID 34279) kapatılıp komutuyla doğrulandı. Kendi Safari çalışma penceresi Inspector/RDM kapatılarak normal canlı Home URL'sinde bırakıldı. Ek RDM/Inspector sorgularında değerlendirme sonucu gelmemesi ve native CUA AX odak/çerçeve kararsızlığı görüldü; mobil DOMwidth veya ikinci Home tam döngüsü doğrulanmış sayılmaz. Bu ek araç gözlemi belirli bir kaynak kodu hatasına kesin atfedilmedi; ürün koduna yeni değişiklik yapılmadı.

## Örnek veri, ortam ve kalan işler

Yerel Deniz örneği capture öncesi/sonrası **20 kayıt/650 dk/163 puan/400 kum aynı**; yeni hesap 0, tamamlanan yeni seans 0, canlı yazım 0, mail gönderimi 0. sample_invariants.json (ham çıktı §37 temizliğinde kaldırıldı). Bu 650 dakika bu tur beklenmiş gerçek süre testi değildir. Eski yerel önizleme/gece cohort'u korunur; canlı kişisel hesap medyada kullanılmaz. Mobil ürün kodu, backend/SMTP/Resend/provider/plan/DNS değiştirilmedi.

Native capture süreci bitti. `production-before.app` binary'si Runner/dylib/App.framework hash eşitliğiyle geri yüklendi; yerel örnek hesaptan çıkıldı ve status override temizlendi. simulator_restore.json (ham çıktı §37 temizliğinde kaldırıldı). Restore sonrası TR üretim giriş ekranı AX kanıtıyla (ham çıktı §37 temizliğinde kaldırıldı) doğrulandı. Kendi 8789 önizleme süreci, Inspector/RDM ve diğer pencere/süreç sınırı environment_final.json (ham çıktı §37 temizliğinde kaldırıldı) içindedir. Public olmayan capture credential dosyaları landing'de yayınlanmaz. Commit/push yok; site deploy GitHub push değildir.

Fiziksel iOS/Android, gerçek Google/Apple, AppleDeveloper/provisioning/IPA/TestFlight, mağaza veri/bildirim beyanları, kullanıcı tarafından en son verilecek gerçek yasal/gönderici kimliği ve bekleyen Edge/waitlist operasyonları ayrı açık işlerdir. Bu turda tekrar kullanıcı kimliği istenmedi. Yeni AI önce bu QA + PROJE_DEVIR§28 + landing/README + AGENTS§8'i okuyup git status'u korusun; canlıda uygulanmış dört SQL paketini tekrar uygulamasın.
