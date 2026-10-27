# pomosprint.app (landing)

## Güncel native videolar — 28 Ekim 2026 / yerel hazırlık

Mevcut ana sayfa Maraton ve Özellikler Pomo/Maraton alanları, iOS18.6'daki gerçek uygulamadan yeniden kaydedildi. Düzen değişmedi; yeni alan eklenmedi. Sessiz, otomatik dönen ve görünmezken duran davranış korunur. Hareket azaltmada gerçek poster gösterilir. Bu dosyalar **henüz deploy edilmedi**; yeni site, sunucu27→28→29 ve yeni uygulama yayını sonrasında yayımlanmalıdır (D-06).

| Kayıt | Bayt | Gerçek sahne süresi | Boyut/format |
|---|---:|---:|---|
| `videos/timer-demo-20261008d.mp4` | 205761 | 24,595sn | 540×1170,24fps,H.264,yuv420p,sessiz |
| `videos/marathon-demo-20261008d.mp4` | 199294 | 20,464sn | 540×1170,24fps,H.264,yuv420p,sessiz |

Eski dosya adları mevcut Worker Range izin listesiyle uyum için korunur; HTML'de video/poster adresleri `?v=20261028` taşır. Her dosya256KiB sınırının altındadır. Gerçek kayıtta süre hızlandırılmaz, kırpma/esnetme yoktur. Beyaz imleç ve küçük dokunma halkası, gerçek dokunma konumları ve UTC zamanlarından sonradan üretilen açıklama katmanıdır; işletim sisteminin kaydettiği imleç diye sunulmaz. Flutter'ın renkli test artısı son kayıtta yoktur. Maraton posteri açık planlama penceresinden seçilir.

Kaynak/çıktı SHA-256, sahne aralıkları, dokunuşlar ve format bilgileri [manifestte](videos/manifest-20261028.json); araç ve native kanıtlar [video QA raporunda](../analiz/QA_SITE_VIDEO_TOOLS_2026-10-28.md). Yerel hesapta seanslar kısa gösterim sonunda iptal edildi; bitmiş seans veya ödül üretilmedi. Bu görsel kayıt 25/50 dakikalık tamamlama testi yerine geçmez. Safari'nin son otomasyon denemesi `cgWindowNotFound` ile engellendiği için yeni dosyalarda gerçek Safari oynatma sonucu henüz yoktur; kaynak, format, Range ve görsel kare kontrolleri ayrı kaydedilir.

## Yerel gece güncellemesi — 28 Ekim 2026 / I-13

**Bu bölüm yerel hazırlığı anlatır; yeni site deploy edilmedi.** Türkçe ana sayfa, Özellikler ve SSS güncellendi; `/en/`, `/en/features` ve `/en/faq` İngilizce karşılıkları eklendi. Eski URL'ler ve yasal metinler korunur. Ortak menüde dil bağlantıları vardır; canonical/hreflang ve sitemap eşlenir.

- Hero başlık, açıklama ve CTA ilk HTML boyamasında görünür; GSAP yüklenmesini beklemez. Yalnız dekoratif hero kum saatine kısa giriş hareketi uygulanır. Sayfanın arkasındaki sabit kum saati kaldırıldı.
- Deneme, TUS, kişisel süre–net takibi ve hedefe göre aylık ligler anlatılır. Lig özeti Bronz–Elmas merdiveniyle gösterilir; ayrıntılar erişilebilir yerel `details/summary` içinde kalır.
- Site aylık sıralaması yalnız yeni `get_public_monthly_competition(p_limit:10)` kullanır. Dönem İstanbul ay başı00:00'dır; eski profil-saatdilimi04:00 RPC'sine fallback yapılmaz. Eksik RPC hazırlık açıklaması; boş sonuç gerçek boş durum; ağ/bozuk veri açıklamalı hata olur. Net veya deneme puanı burada karıştırılmaz. Backend paketi canlıya uygulanana kadar gerçek sitede bu bölüm hazırlık gösterir.
- `notify-form` iki dilde `method="post"`; ticari ileti kutusu önceden işaretsiz kalır. Gizlilik/KVKK bağlantılarının hedefi44px. JavaScript kapalıyken e-posta URL'ye taşınmaz; statik sunucu POST'u kayıt olarak işlemez. Client consent ve sürüm sözleşmesi değişmedi; bilinen sunucu consent/limiter eksikleri bu UI işiyle çözülmüş değildir.
- Koleksiyon sayısı42:7 başlangıç +4 kumla +21 özel +10 normal lig ödülü. Ücretli/Premium erişimi olmayan5 karakter ve henüz hazırlanmamış deneme ödül görselleri bu sayıya alınmaz. Node testi sayıyı istemci kataloğuna bağlar.
- Mevcut gerçek native ekran ve videolar korundu. Yeni Deneme/TUS/sosyal/lig native kayıtları gelmeden sahte ekran veya HTML telefon görseli konmadı; medya yenilemesi ayrı kanıtlanır. SSS görünür14 cevap ve JSON-LD14 cevap birlikte doğrulanır.

`cd scripts && npm test`: bu ara sürümde148/148 geçti (beşli lig grid regresyonu dahil). `python3 landing/tools/sync_partials.py --check` temiz.21 HTML,687 yerel varlık/yol referansı,H1 ve yinelenenID kontrolü geçti. Bu rakamlar yeni medya veya sonraki testler eklenirse yenilenmelidir. Kök ajan, CUA ile Safari masaüstünde yerel ana sayfanın hero/başlık/hedef kitle/CTA görünümünü doğruladı; bu dosyadaki otomatik sayılar tarayıcı ölçümü sayılmaz. Yerel önizleme dış bağlantıları engelleyerek çalıştırılmalıdır; canlı site veya Supabase'e deneme istekleri gönderilmez.

Resmî sınav dayanakları: [Sınav kaynakları](../analiz/SINAV_KAYNAKLARI_2026-10-28.md). Geçmiş yayın kayıtları aşağıdadır; yeni yerel durumla karıştırılmamalıdır.



### İlk güncel native ekran paketi

28 Ekim: `timer-20261028-tr.png`, `social-20261028-tr.png`, `social-20261028-en.png` gerçek iOS uygulamasından, yerel örnek hesaplarla alındı. Her PNG604×1311; yeniden kodlama, kırpma veya boyutlandırma yapılmadan birebir kopyalandı. Kaynak ve SHA-256 listesi [ekran manifestinde](screenshots/README.md). Sosyal kadrajında yedi kişi görünür; sitede sekiz kişi göründüğü iddia edilmez.

Ana sayfadaki Pomo görseli, TR/EN sosyal görselleri ve İngilizce Özellikler Pomo görseli yenilendi. Daha sonra Deneme bölümüne Türkçe gerçek katalog ve İngilizce çalışan TYT sayacı eklendi; her iki görsel de604×1311 ham PNG kopyasıdır. Sonraki gerçek lig karesi YKS hedefinin bu ay, TUS hedefinin sonraki ay uygulanmasını gösterir; TR/EN Özellikler satırındaki eski sıralama karesinin yerini alır. İngilizce alt yazı ekranın Türkçe olduğunu belirtir. Kullanılmayan vazgeçilmiş Deneme geçmişi karesi yayın klasöründen çıkarılmış, asıl kanıt `analiz/` altında korunmuştur. o1 native turu geçti; o2 net/geçmiş fixture testi bu turda parametre verilmediği için atlandı, görseller net girme testinin kanıtı sayılmaz. İngilizce sosyal ekran gerçekten İngilizcedir; henüz İngilizce Pomo karesi olmadığından Türkçe Pomo karesinin dili açıklanır. Var olan sessiz videolar ve düzen korunur; tamamlama/net girişi için ek native kayıtlar ayrıca doğrulanmalıdır. Deneme görselleri ve medya bağlantıları eklendikten sonraki kontrol: Node150/150 ve partial sync geçti. Son bağımsız kaynak turunda menünün Escape/dış tıklama/link/geniş pencere kapatması, SSS tek-açık davranışı ve21 HTML yerel bağlantı/ARIA/hedef/dil eşliği regresyonlarıyla Node154/154 geçti. Bunlar sahte DOM ve statik kaynak kontrolleridir; gerçek Safari etkileşimi veya ekran ölçümü değildir. Son bağımsız Safari turunda CUA `cgWindowNotFound` verdi; yeni açılır-kural etkileşimi, dar pencere/taşma ve sayfa içi medya okunabilirliği bu turda doğrulanamadı. Önceki masaüstü hero gözlemi bu eksiklerin yerine geçmez. Bunlar yeni site yayını değildir.

Lig görseli güncellemesi: mevcut TR/EN Özellikler lig satırında `league-target-20261028-tr.png` kullanılır. Ham dosya kaynakla bayt düzeyinde aynıdır; SHA-256 manifestte ve regresyonda doğrulanır. Kullanılmayan eski Deneme geçmişi PNG’si yayın varlıklarından çıkarıldı; kaynak kanıtı korunur. Son Node turu **155/155**, partial sync ve `git diff --check` temizdir. Bu kaynak/medya kontrolüdür; yeni Safari görsel veya etkileşim başarısı iddia edilmez.

## Güncel site sadeleştirmesi — 8 Ekim 2026 / devir §30

**Son Worker `840fd4f1-0779-493a-ad5b-e41fcd27a3c3`**,83 public varlık. Özellikler yörüngesi yalnız mevcut Bronz/Gümüş/Altın/Safir/Elmas kupalı lig avatarlarından oluşur. İki dekoratif nokta kaldırıldı; beş avatar72° aralıklı/dik döner, reduced-motion’da sabit kalır. Pomodoro Nedir için kullanılan genel `.orbit-dot/.ot-cycle` kuralları korunur. SSS son iletişim sorusu görünür içerikten ve JSON-LD'den kaldırıldı:11/11 eşleşir, alttaki iletişim CTA'sı aynıdır. TR/EN Destek yasal listesi yalnız dört bağlantıdır. CSS cache `20261008e` tüm18 HTML'de; ana JS/medya `20261008d`, telefon çerçevesi ve sessiz video döngüsü değişmedi. Node133/133, temiz analiz/tam Flutter1215/1215, Safari masaüstü/320px ve canlı HTTP kontrolü geçti. [Site QA](../analiz/QA_SITE_CLEANUP_2026-10-08.md), kanıt dizini (ham çıktı §37 temizliğinde kaldırıldı). Aşağıdaki §29 site sürümü tarihsel kalır.

Statik site; Cloudflare Workers static assets ile yayınlanır (`wrangler.jsonc`). Derleme adımı yok.

## Önceki lig açıklamaları — 8 Ekim 2026 / devir §29

**Önceki Worker `6bdb8f56-a8c5-4973-8b18-74344edee7f4`**,83 public varlık: yalnız index/features/FAQ üç HTML yüklendi,80 varlık aynı. Lig kapasitesi25, hazırlık/25 farklı aktif kullanıcı/global14 gün/3 gün300 dakika/10 aktif üyede avatar koşulları açıklandı. FAQ görünür cevap ve JSON-LD birlikte güncel. Kapasite30 olursa bu statik metinleri ayrıca güncelle. Medya, telefon oranı, otomatik döngü, CSS/JSd ve Range Worker değişmedi. Node133/133, partial sync, deploy dry-run ve deploy exit0; bağımsız11 HTTP isteğinde68/68 kontrol. Varsayılan curl yanıtında üç HTML body hash aynı; SSS12/JSON-LD, medya adresleri ve MP4 Range206 baytları doğru. Cloudflare'ın bazı User-Agent'lere eklediği mevcut Analytics betiği varyantı ayrıca kaydedildi. [Lig QA](../analiz/QA_LEAGUE_LAUNCH_2026-10-08.md), kanıt (ham çıktı §37 temizliğinde kaldırıldı). Yeni Safari UI koşusu sayılmaz.

## Önceki sessiz video döngüsü — 8 Ekim 2026 / devir §28

**Önceki medya Worker: `96fb9b24-e276-4a91-986b-e5a48180b4e4`**. 83 public varlık: 24 yeni/değişmiş, 59 mevcut. CSS ve ana JS cache sürümü `20261008d`. Ana sayfanın ve Özellikler sayfasının yapısı korunur; yeni bölüm veya ürün özelliği eklenmedi. Önceki §27 anker düzeltmesi sürer: Features başlık/metin/liste/kart/CTA statik, yalnız medya/telefon ve hafif hero hareketlidir.

Gri üst/alt boşluk, 8 px paddingli dış `.phone` üzerindeki aspect-ratio yüzünden oluşuyordu. Oran artık iç `.phone-screen` üzerindedir: `aspect-ratio: 540 / 1170; height: auto`; dış çerçevenin yüksekliği ekran + padding'den gelir. `object-fit: contain` korunur; görüntü kırpılıp gerilmez.

| Güncel kayıt | Bayt | Süre | Kare |
|---|---:|---:|---:|
| `videos/timer-demo-20261008d.mp4` | 251085 | 28,166667 sn | 676 |
| `videos/marathon-demo-20261008d.mp4` | 206935 | 26,416667 sn | 634 |

İki MP 4 de 540×1170, 24 fps H.264/yuv420p, sessiz ve faststart; aynı adlı WebP posterleri vardır. Native iPhone 16 Plus/iOS 18.6 görüntüsü doğrudan simctl ile alınmıştır. Simctl OS imlecini kaydetmediği için gerçek dokunma koordinat/zamanlarına hizalı editorial imleç ve dokunma halkası sonradan eklenir; uygulama UI'si gerçek kayıttır. Beklemeler kısaltılır; ilk VFR trim/zamanlama kusuru CFR normalize ve sabit kare sayılı kliplerle düzeltilmiştir. İlk başarısız denetim dosyaları korunur.

Üç HTML video alanı vardır: Home Maraton, Features Pomo ve Features Maraton. HTML `autoplay muted loop playsinline preload="none"`, lazy `data-src`, poster ve kardeş gerçek `<img>` içerir; native controls/play overlay yoktur. `main.js` MP 4 adresini yalnız görünürken yükler, ekran/sekme dışında durdurur ve dönüşte kaldığı yerden sürdürür. Video alanına tıklama veya Space/Enter isteğe bağlı duraklat/devam sağlar; `role="button" tabindex="0"` ve erişilebilir ad güncellenir. Manuel duraklatma görünürlük dönüşünde ezilmez. Reduced-motion canlı değişimi durdurur; JS kapalıyken, yükleme/autoplay reddinde veya reduced-motion'da statik gerçek poster kalır.

**Son doğrulama:** medya 16/16, gerçek klip/kare/tap zamanlaması 35/35, Node 133/133 (0 atlama/hata), analiz temiz, tam Flutter 1176/1176 (0 atlama/hata, 405,35 sn, screenshot açık/eşzamanlılık 1). Sekiz tarihsel PNG birebir geri kondu. Kaynak 18 HTML /739 referans /65 hedef /30 SRI /44 ARIA /58 img /3 video; canlı 17 istekte 52/52 kontrol (tam gövde hash, güvenlik/cache, yönlendirme, Range byte eşleşmesi ve private 404). Bunlar birbirine veya önceki tur toplamlarına eklenmez. [Otomatik video QA](../analiz/QA_SITE_AUTOPLAY_2026-10-08.md), [devir §28](../PROJE_DEVIR.md), kanıt özeti (ham çıktı §37 temizliğinde kaldırıldı), canlı HTTP (ham çıktı §37 temizliğinde kaldırıldı).

Safari yerel 320/390 yerleşimi, tıklama duraklatma ve Space devam kontrolü geçti. Final canlı Maraton kaydı otomatik döngüde 13,080 → 26,146 → 0,228 sn sarıldı; 320×844 Features'ta gerçek sayaç ve imleç, 390×844 Home'da ilk imleçli kare/açıklama yatay taşma olmadan görüldü. Bu mobil sonuçlar görsel kontroldür; tamamlanmayan Inspector sorgusu scrollWidth ölçümü diye sayılmaz. Restore sonrası canlı Supabase'e bağlı TR giriş ekranı AX ile doğrulandı; kendi yerel 8789 önizleme süreci kapatıldı. Chrome kullanılmadı. Kayıt yalnız yerel örnek hesapla yapıldı:20 kayıt/650 dk/163 puan/400 kum değişmedi; yeni hesap, bitmiş seans, canlı DB/SMTP/mail/provider değişikliği yok. Üretim öncesi binary hash ile geri yüklendi. Yasal kimlik, fiziksel cihaz, Apple/provider/imzalı mağaza ve bekleyen Edge işleri aynı kalır; site yayını mağaza yayını değildir.

## Önceki Özellikler düzenlemesi — 8 Ekim 2026 (tarihsel)

**Bu turdaki canlı sürüm: `2711a1e9-2098-4fe6-ada3-382c58e8d61b`**: 79 varlık, 16 yüklenen, 63 mevcut. Ana sayfanın içeriği ve görünümü korunur; yalnız ortak JS cache adresi `20261008c` oldu, CSS `20261008b` kaldı. Özellikler'de yedi gerçek ekranlı dönüşümlü satır ve koleksiyon korunur. Altı kısa destek kartı çevrimdışı, kategori/hedef, dil/tema, bildirim/kilit ekranı, profil/hesap ve sosyal güvenliği anlatır. Maratonun altı bonus değeri yazılır. SSS ayar adı günceldir.

Features metni/başlığı/liste/kart/CTA öğelerini GSAP ile gizleme veya taşıma: ankerle gelen başlık sabit menünün altına kayıyordu. Yalnız medya/telefon ve hafif hero hareketi kalır; diğer sayfaların mevcut animasyonları korunur. Kullanıcı ana sayfaya yeni bölüm eklenmesini istemiyor.

Son Node **125/125**, yeni beş görünürlük/anker/fallback/Home davranışı dahil. Yayın sonrası odaklı HTTP **32/32**, 13 gerçek istek. Statik 18 HTML / 739 referans / 30 SRI / 44 ARIA ve SSS12/12 temiz. Safari canlı masaüstü, 320×844 menü geçişi ve 390×844 kartlar doğrulandı. Mobil ürün kodu değişmeden depo rehberinin zorunlu `flutter analyze` ve tam Flutter paketi de tekrarlandı: temiz analiz, **1176/1176**, 0 atlama, screenshot açık/eşzamanlılık 1; sekiz eski PNG birebir geri kondu. [Özellikler QA](../analiz/QA_SITE_FEATURES_2026-10-08.md), kaynak (ham çıktı §37 temizliğinde kaldırıldı), canlı HTTP (ham çıktı §37 temizliğinde kaldırıldı), Flutter kanıtı (ham çıktı §37 temizliğinde kaldırıldı). Aşağıdaki medya yayını sürümü/testleri tarihsel kalır.

## Önceki ekran yenilemesi — 8 Ekim 2026

**Önceki medya yayın durumu:** 8 Ekim 2026 Cloudflare sürümü `2e2d842b-2b03-4779-94d8-e9ff5a71c8c5`, `pomosprint.app` ve `www.pomosprint.app` alanlarında yayınlandı (79 varlık; 19 yeni/değişmiş, 60 aynı). Bu sürüm yedi dönüşümlü Özellikler satırını ve ana sayfa Maraton video bölümünü içerir. Önceki içerik sürümü `8e30ae76-7258-45d9-a71e-30dcae08cb3d`, video Range düzeltmesi `3aefb719-f008-4c44-b6a7-31319c7e7963` tarihsel dağıtımlardır. Bağımsız canlı HTTP **59/59**: önceki 57 kontrolün aynısı + güncel `20261008b` CSS/main JS hash kontrolü. Ana sayfa/Özellikler/SSS/reset ve 11 medya dosyası yerel SHA-256 ile eşleşti; 22 Range/If-Range/HEAD/304 varyantı, yardımcı no-store/CSP, sorgu koruyan yönlendirmeler ve 14 özel/eski yol 404 geçti. Node 120/120 (12 Range regresyonu), değişmeyen Worker için yerel HTTP 21/21. Kanıtlar: son canlı HTTP (ham çıktı §37 temizliğinde kaldırıldı), son statik preflight (ham çıktı §37 temizliğinde kaldırıldı), son dry-run (ham çıktı §37 temizliğinde kaldırıldı).

Ana sayfada gerçek Pomo/günlük rapor/sosyal ekranlarının galerisi ve ayrı Maraton planlama video bölümü vardır. Özellikler sayfası Pomo, Maraton, Günlük, Haftalık, Aylık, Sosyal ve Sıralama ekranlarını yedi satırda sırayla gösterir: görsel/metin yönü satırdan satıra değişir. Haftalık ve aylık ekranlar ayrı satırdadır; eski ek mini galeri kaldırıldı. İnternetsiz tek seans, kategori/hedef ve dil bilgisi en altta üç destek kartındadır. Görüntüler iOS simülatöründeki ayrı yerel örnek hesaplardan alınır; canlı kişisel hesap bilgileri kullanılmaz. WebP çıktılarının boyutu 540 × 1170 piksel olmalıdır.

| Dosya | Ekran |
|---|---|
| `screenshots/timer.webp` | Pomo; 25/50 dk ve kompakt Maraton girişi |
| `screenshots/marathon.webp` | Maraton planlama penceresi |
| `screenshots/reports.webp` | Günlük çalışma raporu |
| `screenshots/weekly.webp` | Pazartesi–Pazar haftalık rapor |
| `screenshots/monthly.webp` | Aylık yoğunluk takvimi |
| `screenshots/social.webp` | Arkadaşların; Odaklanıyor / Molada |
| `screenshots/ranking.webp` | Sıralama; Arkadaşlar sekmesi |

**Önceki manuel-video davranışı (tarihsel §26):** İki ayrı kısa, sessiz H.264 kayıt `videos/timer-20261008.mp4` ve `videos/marathon-20261008.mp4` adıyla kullanılır; her birinin aynı adlı WebP posteri vardır. HTML’de üç video öğesi bulunur: iki Özellikler kaydı ve ana sayfada tekrar kullanılan Maraton kaydı. Videolar HTML'de `controls muted playsinline preload="none"` ile tanımlanır. Otomatik oynatma ve döngü yoktur; kullanıcı oynatır ve duraklatır. Ekran dışına veya başka sekmeye geçince JS kaydı duraklatır, geri dönünce kendiliğinden başlatmaz. Video ya da kaynak yüklenemezse video gizlenir, kardeş gerçek ekran görüntüsü kalır. JS kapalıyken de statik görüntüler ve yerel video kontrolleri bulunur; hareket azaltma tercihinde kendiliğinden hareket başlamaz. Önceki `3aefb719` canlı sürümünde ayrı Safari penceresinde Maraton kaydı kullanıcı tarafından başlatılıp 21 sn boyunca tamamlandı; yerel video kontrol çubuğuna tıklayınca 21 → 10 sn sarma, yeniden oynatınca 11. saniyeye ilerleme ve düğmenin “Pause” durumuna geçmesi doğrulandı. “Pause” düğmesi oynatmanın sürdüğünü gösterdi. Pomo kaydı da 23 sn boyunca tamamlandı. Masaüstünde Maraton görünümü ve önceki canlı 320×740 poster/metin yerleşimi taşmadan gözlendi. Canlı ana sayfanın 390×844 tek sütunlu galerisinde Pomo/Raporlar/Sosyal görselleri yüklendi ve yatay taşma görülmedi; 390×844 galeri ayrıca yerel önizlemede de kontrol edildi. HTTP byte seek aralıkları gerçek içerikle doğrulandı. Son `2e2d842b` sürümünde canlı masaüstü Maraton satırı sol metin/sağ video düzeninde doğrulandı. Canlı Özellikler 390×844 görünümünde Maraton metni tek sütuna sığıyor; sonraki kaydırmada poster ve açıklama da yatay taşmadan görünüyor. Ana sayfadaki yeni Maraton videosunda kullanıcı başlatmasından sonra 14/21 sn ilerleme ve arka plana geçince duraklama gözlendi. Son canlı ana sayfa 390×844 Maraton görünümünde başlık, açıklama, üç madde ve CTA tek sütuna sığıyor; poster bu içeriğin altında başlıyor. Yerel masaüstünde Günlük/Aylık ters yön ile Sosyal normal yön arasındaki akış da kontrol edildi.

**Maraton:** 2/3/4 seans, aralarda 5 dk mola ve mola bitince 1 dk içinde “Buradayım” onayı anlatılır. Kullanıcının 8 Ekim açık isteğiyle üç Maraton sunucu paketi canlı Supabase'e uygulandı; 96/96 işlev/geri alma ve 13/13 güvenlik/yapılandırma kontrolüyle doğrulandı (sözleşme ve kanıt: [AGENTS.md §5.7](../AGENTS.md)). Site ürün metnindeki önizleme/kapalı ibareleri bu doğrulamadan sonra kaldırıldı. Uygulama mağaza yayını hâlâ ayrıca hazırlanır; web sitesi yayını mağazaya yükleme değildir.

Ürün metinleri ve SSS'nin JSON-LD cevapları güncellendi: cihaz diline göre TR/EN seçimi, tek sosyal liste, yalnız Maraton molasında “Molada”, ilk puanlı seansta en fazla 30 kişilik lig odası, yeni odanın 7–14 günlük ilk dönemi. Premium için yakın tarihli satış vaadi kaldırıldı. Ana sayfa, Özellikler ve SSS sitemap tarihi 2026-10-08; yasal metin sürümleri değişmedi. CSS ve ortak JS sürümü `20261008b`.

## Ortak parçalar

Header, footer, ortak `<head>` satırları ve script etiketleri `_partials/` altında tek kaynaktır.
Bir parçayı değiştirdikten sonra sayfaları güncelle:

```sh
python3 landing/tools/sync_partials.py          # sayfalara işler
python3 landing/tools/sync_partials.py --check  # fark varsa 1 ile çıkar
```

`en/` altındaki sayfalar `*.en.html` parçalarını kullanır. Aktif menü linki `<body data-page="...">` ile belirlenir.

## Kurallar

- İç linkler uzantısız ve köke göre yazılır: `/features`, `/privacy`, `/en/terms`. Workers `.html` adreslerini 307 ile uzantısız adrese yönlendirir (uygulamanın eski linkleri çalışmaya devam eder).
- CSS/JS değişince `?v=` değerini `_partials/head.html`, `_partials/scripts.html` ve yardımcı sayfalarda (reset-password, confirmed, unsubscribe) güncelle; `_headers` bu dosyaları 1 saat önbelleğe alır.
- `_headers` sıkı bir CSP içerir: inline `<script>`/`style=""` kullanma (JSON-LD veri blokları hariç). Yeni bir dış kaynak gerekiyorsa CSP'ye ekle.
- Yazı tipleri (`fonts/`, `css/fonts.css`) ve GSAP (`vendor/gsap-3.13.0/`) kendi alan adımızdan sunulur; ziyaretçinin IP adresi Google Fonts'a ve jsDelivr'e gitmez (KVKK-19). CSP'de `font-src 'self'`, `style-src 'self'`; `script-src`'te yalnızca `'self'` ve Cloudflare Web Analytics var. Dış CDN'e geri dönme: gizlilik metinleri (`/privacy`, `/kvkk`, iki dil) bu sağlayıcıları artık saymıyor. GSAP dosyaları jsDelivr'deki `gsap@3.13.0/dist` ile birebir aynı (SRI `integrity` değerleri değişmedi); sürüm yükseltirken klasör adını ve `integrity`'yi birlikte değiştir. Yazı tipi ayrıntısı: `fonts/README.md`.
- Supabase URL ve anon anahtar yalnızca `js/config.js` içinde durur.
- Yeni avatar eklenince `assets/avatars/<id>.png` dosyasını `avatars/<id>.webp` olarak ekle: `cwebp -q 80 -resize 160 160 in.png -o avatars/<id>.webp`.
- `_partials/`, `tools/` ve `*.md` `.assetsignore` ile yayından hariç tutulur; `_headers` tutulmaz (Workers okur, yayınlamaz).
- Gerçek ekranlar `<img>` ile HTML'de tanımlanır; anlamlı `alt`, gerçek `width`/`height`, `loading="lazy"` ve `decoding="async"` ver. Video `data-demo-video`, lazy `data-src`, `autoplay muted loop playsinline preload="none"` ve gerçek poster/fallback img kullanır; native controls yok. Görünürlük/sekme/reduced-motion ve kullanıcının tıklama/Space/Enter duraklatma tercihi `main.js` tarafından birlikte denetlenir. JS yokluğunda veya autoplay/yükleme hatasında gerçek görüntü kalır. `.phone-screen` oranı 540/1170'dir; paddingli dış `.phone` üzerine aspect-ratio veya sabit yükseklik koyma. Eski `SHOT_VIDEOS` ve çizilmiş sosyal örnek geri gelmez. MP4 H.264/yuv420p/sessiz/24fps/faststart; ekranlar/medya self-hosted (`img-src` / `media-src self`). Native kayıt üzerindeki editorial imleç, gerçek tap zamanlarına göre eklenir; kare sayısı ve PTS zamanlamasını doğrula.
- `screenshots/` bir saat, sürümlü `videos/` bir gün önbelleğe alınır. Yeni kayıt için dosya sürümünü ve poster bağlantısını birlikte değiştir; ekran görüntüsü isimleri korunursa yeni görselin önbellek süresini hesaba kat.
- `worker.js` dört allowlist MP4 yolunda tek byte Range verir: eski `videos/{timer,marathon}-20261008.mp4` ve güncel `videos/{timer,marathon}-demo-20261008d.mp4`. 206/416'da ASSETS güvenlik/cache/ETag başlıkları korunur. Okuma en fazla 256 KiB (262144 bayt); sınır aşılırsa iptal/normal streaming fallback. Yeni dosya bu sınırın altında tutulmalı; dosya büyüdü diye sınırı artırma. Normal GET/HEAD,304/404 ve başka dosyalar aynen geçer. Yeni sürümde allowlist ile `scripts/test/landing_worker_range.test.mjs` gerçek dosya testlerini birlikte güncelle. Güncel Node133/133 ve canlı52/52 HTTP; önceki21/21 yerel/59/59 canlı sayılar tarihseldir.
- Ana sayfadaki aylık sıralama bölümü görünür başlar. Yeni `get_public_monthly_competition` yoksa hazırlık, sıfır satırsa boş, ağ/yanıt hatasında açıklayıcı durum gösterir; gerçek1–2satır da render edilir. Eski üç kişi eşiği kaldırıldı.
- Yeni site RPC'si aylık normal çalışma yarışını İstanbul ayın1'i00:00 sınırıyla döndürür. `period_end` sunucudan gelir; eski profil04:00 çalışma ayı RPC'sine fallback yapılmaz. Çalışma raporu/seri04:00 kuralı ayrı kalır. Paket29 canlıya uygulanmadığından site yeni API için hazırlık gösterebilir.

## Yasal sayfalar

| TR | EN | Kim bağlanıyor |
|---|---|---|
| `/privacy` | `/en/privacy` | Uygulama (Profil ve Ayarlar), App Store ve Google Play gizlilik URL'si |
| `/terms` | `/en/terms` | Uygulama, kayıt ekranındaki onay |
| `/kvkk` | `/en/kvkk` | Kayıt ekranındaki aydınlatma teyidi, bekleme listesi formu |
| `/hesap-silme` | `/en/delete-account` | Google Play Data safety "hesap silme URL'si" |
| `/destek` | `/en/support` | App Store "Support URL", Play "Web sitesi"/destek; iletişim, sık sorunlar, hesap silme ve veri başvurusu yolları |

- Bu adresleri değiştirme; mağaza kayıtları ve uygulama sürümleri bunlara bağlı.
- **Veri sorumlusu kimliği eksik (KVKK-15):** `/privacy` ve `/kvkk` (iki dil) §1'de `data-fill-in="KVKK-15"` işaretli yer tutucular var; bilgi uydurulmadı. Kullanıcı gerçek ad-soyad/unvan ve adresi en son verecek; görsel site güncellemesi için yeniden soru sorma. Mağaza yayını öncesinde gerçek bilgilerle doldurup işaretleri kaldır: `rg -n 'data-fill-in' landing/` boş dönmeli. Aynı bilgi `MAIL_SENDER_NAME` / `MAIL_SENDER_ADDRESS` (e-posta altbilgisi) ve mağazadaki geliştirici adıyla aynı olmalı.
- Metin değişince "Son güncelleme" tarihini yenile ve uygulamadaki `terms_version` / `privacy_version` değerleriyle eşleştir (iki dil birlikte).
- Uzun tablolar `.prose .data-table` ile yazılır; her `<td>` için `data-label` ver (dar ekranda kart düzeninde sütun adı olarak görünür).

## Yardımcı sayfalar

Üçü de Türkçe ve İngilizcedir: dil bağlantıdaki `?lang=tr|en` parametresinden, yoksa tarayıcı dilinden seçilir (`js/auth-i18n.js`). E-posta şablonları İngilizce kullanıcılar için bağlantıya `lang=en` eklemelidir. `config.js` zaman aşımı yanıt gövdesi tamamlanana kadar etkin kalır; başlıkların gelmesi ağ beklemesini sonlandırmaz.

- `reset-password`: `#access_token=...&type=recovery` (implicit akış) ve `?token_hash=...&type=recovery` (e-posta şablonu) bağlantılarını kabul eder; token_hash form gönderilince doğrulanır.
- 7 Ekim takip düzeltmesi 8 Ekim site dağıtımıyla canlıda: verify 5xx / bilinmeyen 429 / bozuk yanıt geçersiz token sayılmaz; form yeniden denemeye açık kalır. Bilinen token hataları ve 401/403 formu kapatır. Script cache `20261007b`; canlı SHA-256 `d3d3b2a7c8688cfd65c4b1ce486d5cb7358ca565264cfb969aa58e72d51af05a` yerelle eşleşti. Son Node kapsamı 120/120. [Reset QA](../analiz/QA_PASSWORD_RESET_2026-10-07.md), canlı HTTP kanıtı (ham çıktı §37 temizliğinde kaldırıldı).
- `confirmed`: e-posta onayı dönüşü; parametresiz açılınca "onaylandı" demez.
- `unsubscribe`: `?token=<uuid>` (3 Ekim sonrası e-postalar; adres URL'de taşınmaz). Eski e-postalardaki `?email=...&token=...` de çalışır: sayfa adresi okuyup adres çubuğundan siler, istekte e-postayı yalnızca POST gövdesine koyar. Çıkış yalnızca butona basınca yapılır. Test: `cd scripts && npm test`.

## Bekleme listesi formu

Ana sayfadaki "Yayınlanınca haber ver" formunda ayrı, önceden işaretsiz ticari ileti onay kutusu (`#notify-consent`) vardır. `js/main.js` kutu işaretlenmeden POST göndermez; 7 Ekim düzeltmesiyle `{ email, marketing_consent: true, consent_text_version: "waitlist-2026-10-03" }` gönderir. Onay zamanını istemci göndermez; `waitlist_set_consent_time` trigger'ı `consented_at` değerini sunucuda belirler. `proposed/19` A kolonları kayıtlı canlı şemada mevcut; 8 Ekim site yayını bu istemci gövdesini canlıya taşıdı; bu görsel yenilemede waitlist SQL değiştirilmedi. `proposed/19` B uygulama planı güncel canlı tanımlardan ayrıca incelenmeli; B onaylı kayıt dışında insert'i engeller. Önceki NULL onaylı kayıtları pazarlama postası için onaylı sayma. Test: `scripts/test/landing_waitlist_form.test.mjs`.
