# Site ekranları ve canlı yayın QA — 8 Ekim 2026

**Sonuç:** [pomosprint.app](https://pomosprint.app) güncel gerçek uygulama görüntüleriyle yayınlandı. Ana sayfaya Pomo/Raporlar/Sosyal galerisi ve ayrı Maraton video bölümü, Özellikler sayfasına görsel/metin yönü dönüşümlü yedi ekran satırı yerleştirildi. İki ayrı sessiz kayıt toplam üç video öğesinde kullanılır. Maraton'un canlı sunucu açılışı [ayrı raporda](QA_MARATHON_LIVE_2026-10-08.md). Mağazaya uygulama yüklenmedi.

## Yayın

Cloudflare Workers static assets, `pomosprint-website`, apex ve www custom domain. Kullanıcı mevcut siteyi güncelleyip yayına almamızı açıkça istedi. Cloudflare/Wrangler skill'leri okundu; mevcut auth kullanıldı; plan veya DNS ayarı değiştirilmedi.

- İlk içerik yayını: `8e30ae76-7258-45d9-a71e-30dcae08cb3d`,79varlık;32değişen/47mevcut.
- Önceki Range yayını: `3aefb719-f008-4c44-b6a7-31319c7e7963`. Safari için MP4 Range düzeltmesi içerir; ikinci yayında asset içerikleri aynı kaldı.
- **Nihai yayın:** `2e2d842b-2b03-4779-94d8-e9ff5a71c8c5`. Dönüşümlü yedi özellik satırı, üç destek kartı, ana sayfa Maraton video bölümü ve CSS/main `20261008b`. 79 varlık: 19 yeni/değişmiş, 60 mevcut.
- Kanıtlar: ilk deploy (ham çıktı §37 temizliğinde kaldırıldı), Range deploy (ham çıktı §37 temizliğinde kaldırıldı), nihai deploy (ham çıktı §37 temizliğinde kaldırıldı), 59 canlı HTTP kontrolü (ham çıktı §37 temizliğinde kaldırıldı).

## Gerçek ekran ve video kaynakları

Tek iPhone16Plus/iOS18.6 kullanıldı. Ham PNG/MP4 `build/landing_media_20261008/raw/` altında; sitede gerçek native capture'ların küçültülmüş sürümleri var. Telefon içeriği çizilmedi/üretilmedi. Dolu raporlar için yalnız **yerel örnek hesaplar** kullanıldı; kişisel kullanıcı hesabına girilmedi.

| Site varlığı | İçerik |
|---|---|
| `screenshots/timer.webp` | Normal25:00, kategoriler, küçük Maraton girişi, eski kum saati ölçüsü |
| `screenshots/reports.webp` | Günlük125dk, hedef ve kategori dağılımı |
| `screenshots/weekly.webp` | Pazartesi–Pazar haftalık rapor |
| `screenshots/monthly.webp` | Aylık ısı haritası ve çalışma dağılımı |
| `screenshots/ranking.webp` | Arkadaşlar sıralaması; genel lig diye etiketlenmedi |
| `screenshots/social.webp` | Mert yeşil Molada, Ece kırmızı Odaklanıyor |
| `screenshots/marathon.webp` | Daireli2/3/4,50×4,+10bonus ve215dk planlama popup'ı |
| `videos/timer-20261008.mp4` | Gerçek25dk sayacın kısa başlangıcı/kum saati,23,25sn |
| `videos/marathon-20261008.mp4` | Planlama seçimleri2→3→4 ve25→50dk,21,667sn |

Tüm yedi WebP ve iki video/poster **540×1170**. Videolar H264/yuv420p,24fps,sessiz,faststart;218.007 ve149.897bayt. Bu kayıtlar tamamlanmış uzun Maratonun videosu değildir. Pomo kaydı tamamlanmadan iptal edildi; demo hesabının kayıt/puanı artmadı. Yerel Deniz fikstürü20örnek/650dk/163puan/400kum; bugün4örnek/125dk. Geçmiş kayıtlar rapor gösterimi için oluşturulmuş fikstürdür,25/50dk gerçekten beklenmiş yeni QA sonucu değildir. Sosyal görüntü ayrı eski önizleme hesabından alındı; örnek hesaplar açıklaması buna uygun.

Önceki gece10Auth/22kayıt/750dk/172puan/440kum grubu ve eski67puan/160kum önizleme hesabının DB verileri korunur. Ham çekimler/özel launcher JSON ve hesap bilgileri siteye konmadı; public asset SHA256'ları canlıyla eşleşiyor.

## Sayfa ve davranış değişiklikleri

Orijinal sıcak renkler, hero ve animasyonlu kum saati korundu. Boş eski telefon çizimleri gerçek ekranlarla değişti; yeni ürün özelliği eklenmedi. Ana sayfa üç ekran kartı ve ayrı Maraton video bölümü içerir. Özellikler sırası Pomo → Maraton → Günlük → Haftalık → Aylık → Sosyal → Sıralama; yedi satırda görsel/metin yönü dönüşümlüdür. Haftalık ve aylık ekranlar ayrı satırlara çıkarıldı; eski ek mini galeri kaldırıldı. İnternetsiz tek seans, kategori/hedef ve dil bilgileri en altta üç destek kartındadır. İki ayrı MP4 toplam üç video öğesinde kullanılır (Özellikler2 + ana sayfa Maraton1). Görüntüler alt metin/boyut/telefon oranı/lazy yükleme kullanır. Video `controls`, `muted`, `playsinline`, `preload=none`; autoplay yok. Kaynak hatasında gerçek ekran görüntüsü kalır; görünmeyen/arka plan videoları durur.

SSS görünür12yanıt/JSON-LD eşitlendi; Maraton300+60sn, bonuslar, erken çıkışın normal seansları koruması, sosyal odak/mola ve lig14gün kuralı güncel. Cihaz diliTürkçe iseTR/diğerEN, bildirim izin+tercih koşulu ve Apple hazırlık durumu doğru yazıldı. Spekülatif Premium vaadi çıkarıldı. Kişisel resmî geliştirici bilgileri uydurulmadı; uygulama yayın hazırlığında açıklaması korunur.

CSS/ana JS cache sürümü `20261008b`; önceden test edilmiş resetJS`20261007b` korunarak **bu yayında canlıya çıktı**. Güncel resetJS SHA256 `d3d3b2a7c8688cfd65c4b1ce486d5cb7358ca565264cfb969aa58e72d51af05a` yerel/canlı eşit. Token sayfalarında no-store/noindex/no-referrer, CSP ve URL sözleşmeleri korunur. Bu yeni inbox teslimi/parola değişikliği testi değildir.

## Bulunan ve giderilen yayın hatası

İlk yayında iki MP4'ün `Range:bytes=0-1023` isteği206yerine tam200dönüyordu. Cloudflare asset handler'ın mevcut davranışı resmî kaynaktan doğrulandı. `worker.js` yalnız iki küçük sürümlü MP4 GET isteğine tek byte-range206/416 ekler; en çok256KiB okuyabilir. Geçersiz/çoklu Range, değişmiş/zayıf If-Range, büyük gövde normal200akışına döner. Normal GET/HEAD/304/404, yönlendirmeler ve token sayfaları değişmez. ETag/cache/CSP/nosniff başlıkları korunur.12anlamlı regresyon ve gerçek workerdHTTP ile kontrol edilip yeniden yayınlandı.

İlk gerçek Range başarısızlığı ayrı kanıtta (ham çıktı §37 temizliğinde kaldırıldı) korunur. Statik link denetimindeki reserved `#top` ve curlHEAD çift delimiter hataları yalnız denetim aracında düzeltildi; ürün hatası olarak sayılmaz.

## Gerçekten koşulan doğrulamalar

| Kontrol | Sonuç |
|---|---:|
| Ağsız tüm Node/Edge/site suite | **120/120**,0başarısız/0atlama |
| Yeni video Range alt kümesi | **12/12**,yukarıdaki toplamın içindedir |
| Gerçek yerel workerd HTTP Range/If-Range/helper | **21/21** |
| Nihai canlı HTTP medya/yönlendirme/helper/özel yol + CSS/main | **59/59** (aynı 57 kontrol +2 sürümlü CSS/main hash) |
| Medya SHA256 canlı/yerel | **11/11** |
| Özel/eski yayınlanmayan yollar | **14/14 HTTP404** |
| Statik HTML/iç link/SRI |18 HTML, 739 iç referans /65 hedef +16 CSS varlık referansı, 30 SRI eşleşmesi, 44 geçerli ARIA ID bağlantısı |
| HTML medya / public varlık |58 img, 3 video öğesi /2 ayrı MP4; 79 public, private0 |
| Görünür FAQ/JSON-LD | **12/12** |
| Partial sync / Wrangler dry-run / diff whitespace | Temiz |

Son Node log node_test_alternating.log (ham çıktı §37 temizliğinde kaldırıldı), son statik audit (ham çıktı §37 temizliğinde kaldırıldı), son dry-run (ham çıktı §37 temizliğinde kaldırıldı), yerelHTTP (ham çıktı §37 temizliğinde kaldırıldı). Eski108toplamına yeni120eklenmez. Bu tur mobil analyze temiz ve Maraton/sosyal53/53 alt kümesi geçti; son tam Flutter1176/1176 önceki [gece raporunun](QA_OVERNIGHT_REAL_2026-10-08.md) kapsamıdır.

**Gerçek Safari GUI — önceki 3aef sürümü:** Masaüstü Maraton görsel/metni doğru. Canlı320×740Maraton poster/açıklama, canlı390×844ana sayfa tek sütun Pomo/Raporlar/Sosyal galeri taşmadan görüldü. Yerel320raporlar/390galeri de kontrol edildi; yerel HTTP preview productionCSP'nin yerine sayılmadı. Nihai canlı Maraton videosu21sn sonuna, Pomo23sn sonuna oynadı. Native timeline Maraton21→10sn geri sardı; yeniden Play sonrası11sn ve Pause düğmesi ilerleyen oynatmayı doğruladı,11sn'de durdurulduğu iddia edilmez. Görsel GUI kanıtı bu oturumun cua_repl kayıtlarıdır; ayrı Safari PNG dosyası oluşturulmuş sayılmaz. Chrome kullanılmadı; kullanıcının diğer sekmeleri değiştirilmedi.

**Son dönüşümlü akışın yerel Safari kontrolü:** 390 px Maraton metni/posteri, masaüstünde Maraton sol metin/sağ medya → Günlük ters yön, Aylık sol görsel → Sosyal sağ görsel akışı ve ana sayfa yeni Maraton bölümü root tarafından kontrol edildi; kaydırma düzgün ve yerleşimler sığıyor. Son `2e2d842b` canlı Safari masaüstünde Maraton sol metin/sağ video düzeni doğrulandı. Canlı Özellikler390×844: Maraton metni tek sütuna sığıyor; sonraki kaydırmada poster/açıklama yatay taşmadan görünüyor. Yeni ana sayfa Maraton kaydı 14/21 sn ilerledi ve arka planda durakladı. Son canlı ana sayfa 390×844 Maraton görünümünde başlık, açıklama, üç madde ve CTA tek sütuna sığıyor; poster bu içeriğin altında başlıyor. Bu son sürümde tekrar tam21sn oynatma veya yeni seek sonucu olarak sayılmaz; önceki3aef tam oynatma/seek kanıtı yukarıda ayrı tutulur. İnaktif pencerede ara sıra boş cua_repl HTML görüntüsü alınması ürün çökmesi olarak sayılmadı; ayrı WebKitDevelopment telemetrisi gerçek Safari testinin yerine kullanılmadı.

## Son ortam ve sınırlar

Normal `lib/main.dart` simülatörde **canlı Supabase**, gerçek25/50dk, TR giriş ekranında açık; son CUA kontrolünde giriş formu görüldü. Bu tur oluşturulan tek üretim QA hesabı test sonrası kaldırıldı; sanitize native/temizlik kanıtı (ham çıktı §37 temizliğinde kaldırıldı). Eski yerel önizleme artık ön plandaki uygulama değildir; verisi ve özel ayarları korunur. Durum çubuğu override temizlendi. Bu işin8788/8789yerel preview süreçleri kapandı, listener0; Docker/başka projeler durdurulmadı. Wrangler watcher geçici deploy klasörünün kaldırılması nedeniyle ENOENT/exit1 ile kapanmıştı; bu yerel preview sonucu ayrı korunur, başarılı canlıdeploy/59HTTP sonucunu değiştirmez. Son ortam kaydı (ham çıktı §37 temizliğinde kaldırıldı). `.env`/SMTP/DNS/plan değişmedi; commit/push yok.

Canlı Maraton ve site yayınlandı; fiziksel cihaz/gerçek Google-Apple girişleri, Apple Auth/token revoke/imzalıIPA-TestFlight, mağaza veri/bildirim beyanları, gerçek geliştirici/yasal kimlik ve bekleyen Edge/operasyon işleri ayrı kalır. Bu rapor tüm mağaza şartlarının bittiği veya hatasız çalışmanın garantisi değildir. Yeni AI önce `PROJE_DEVIR.md §26`, bu rapor, [canlıMaraton](QA_MARATHON_LIVE_2026-10-08.md) ve [şikâyetkilidi](QA_REPORT_SUBMISSION_LIVE_2026-10-08.md) okusun; mevcut canlı migration'ları tekrar uygulamasın.
