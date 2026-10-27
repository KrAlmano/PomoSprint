# Özellikler sayfası düzeltmesi — 8 Ekim 2026

## Sonuç ve kapsam

Canlı site sürümü **2711a1e9-2098-4fe6-ada3-382c58e8d61b**. Cloudflare deploy exit0: 79 varlık, 16 yüklenen/değişen, 63 mevcut. Ana sayfanın içeriği ve tasarımı korunur; yalnız ortak JS cache adresi güncellendi. CSS `20261008b`, ortak JS `20261008c`. Önceki medya yayını ve testleri [site medya QA](QA_SITE_MEDIA_RELEASE_2026-10-08.md) içinde tarihseldir.

Kullanıcı Özellikler sayfasındaki hatayı düzeltmemizi ve tüm özellikleri orada anlatmamızı istedi. HTTP tarafında /features200, .html307, www301, CSP ve kaynak hash'leri doğruydu; 404 veya JavaScript exception yeniden üretilmedi. Kullanıcının gördüğü hataya ilişkin özel hata metni bu tur gelmedi. **Safari'de yerel #support-heading bağlantısında gerçek bir yerleşim kusuru görüldü:** y32 giriş hareketi bittikten sonra başlık sabit menünün altında kalıyordu. Önceki/sonraki PNG'lerle düzeltildiği doğrulandı; bu bulgu kullanıcının belirsiz hata tarifinin kesin kök nedeni diye sunulmaz.

## Değişiklik

- Features başlıkları, açıklamaları, madde listeleri, destek kartları ve CTA sabit kalır. GSAP görünürlük/transform başlangıcı bu öğelere uygulanmaz; geciken tetikleyici açıklamaları gizlemez. Hafif telefon/medya ve hero hareketi korunur. Diğer sayfaların mevcut animasyonları değişmez.
- Yedi gerçek ekranlı dönüşümlü satır korunur: Pomo, Maraton, Günlük, Haftalık, Aylık, Sosyal, Sıralama. Koleksiyon bölümü korunur. Maraton 25dk 2/3/4 için +2/+3/+5, 50dk için +4/+6/+10 açıkça yazılır.
- Mevcut destek kartı tasarımıyla altı kısa açıklama: çevrimdışı, kategori/hedef, dil/tema, bildirim/kilit ekranı, profil/hesap, sosyal görünürlük/güvenlik. Yeni uygulama özelliği eklenmedi.
- Açıklamalar gerçek koşulları belirtir: tema başlangıçta sistem/Profil'de açık-koyu; şifre değişimi e-posta/şifre hesabında; mola bitiş bildirimi içindeki1 dk onayı; görünürlük aylık/web/canlı, lig/arkadaş listesi hariç. SSS'de eski ayar etiketi hem görünür metin hem JSON-LD'de yenilendi.

## Gerçek doğrulamalar

| Kontrol | Sonuç | Kanıt |
|---|---|---|
| Ağsız Node/Edge/site paketi | **125/125**,0 atlama | features_fix_20261008/node_test_final.log |
| Features davranışı + MP4 Range birim testleri |17/17 (tam paketin içinde) | build/site_media_20261008/node-features-static-anchor.log |
| Görünürlük/anker davranışı |5 vaka: geciken trigger, sabit metin, GSAP yok, reduced-motion, Home animasyonu | scripts/test/landing_features_visibility.test.mjs |
| Statik preflight |18 HTML, 739 iç referans/65 hedef, 30 SRI, 44 ARIA, 58 img/3 video; hatasız | features_fix_20261008/source_preflight.json |
| SSS |12/12 görünür metin/JSON-LD eşleşmesi | source_preflight.json |
| Yayın sonrası |13 gerçek HTTP isteği / **32/32 kontrol** | http_post_deploy.json |
| Canlı dosyalar |Features/mainc/SSS/home/CSSb yerel SHA-256 ile aynı | http_post_deploy.json |
| Medya ve güvenlik |İki MP4 Range206 + gerçek byte eşleşmesi; CSP/nosniff, .html/query/www ve3özel yol404 | http_post_deploy.json |
| Ortak parçalar/sözdizimi |sync_partials --check, node --check ve hedefli diff --check exit0 | kaynak/CLI kontrolleri |
| Ana sayfa koruması |Önce/sonra yalnız cache tokenı normalize edilince birebir | source_preflight.json, index_before.html |
| Zorunlu Flutter analizi |`flutter analyze` temiz, çıkış 0 | flutter_analyze.log |
| Zorunlu tam Flutter paketi |**1176/1176**, 0 başarısız/atlanan; `--concurrency=1 --dart-define=SCREENSHOTS=true`, 291,5 sn | flutter_test.log, flutter_required_checks.json |
| Tarihsel PNG koruması |Sekiz eski PNG birebir SHA-256 ile geri yüklendi; yeni çıktılar ayrı klasörde | flutter_required_checks.json, generated_flutter_screenshots/ |

Safari: yerel masaüstü anker önce/sonra; yerel390/320×844 kartlar; canlı masaüstü başlık ve altı kart, canlı320×844 mobil menüyle Ana Sayfa→Özellikler geçişi, canlı390×844 bildirim/profil kartları taşmadan görüldü. Yerel konsolda yükleme hatası görülmedi. Bu fiziksel iPhone Safari veya Chrome testi değildir. Yeni tam video oynatma/seek turu yapılmadı; değişmeyen önceki oynatma kanıtı ile bu turun iki canlı Range kontrolü ayrı tutulur. Arka plandaki Safari pencere yakalaması bazen boş gövde verdi; kendi sekmesi etkinleştirilip tekrar kontrol edildi, bu yakalama ürün hatası sayılmadı.

Kanıt kökü: `analiz/qa_evidence_20261008/features_fix_20261008/`. PNG'ler `local_anchor_before.png`, `local_anchor_after.png`, `production_desktop_anchor.png`, `production_320_menu_features.png`, `production_390_notifications.png`; ilgili AX metinleri de kayıtlıdır. Kaynak/HTTP denetim betikleri bu klasördedir; web varlığı olarak yayınlanmaz.

## Son ortam ve devam

Bu tur mobil kaynak/DB/SMTP/Resend/plan/DNS değişikliği veya yeni hesap/seans/mail yok. Depo rehberinin zorunlu Flutter analizi ve tam birim/widget paketi ayrıca geçti; yeni native simülatör/emülatör veya backend koşusu yapılmadı. Önceki §26 native/canlı Maraton sonucu korunur. Safari ayrı çalışma penceresi normal canlı Özellikler görünümünde bırakılır; Chrome değiştirilmedi. Yerel 8789 önizlemesi kapatıldı; 8788/8789 dinleyici yok (`final_environment.json`). Git commit/push yapılmadı. Mağaza, fiziksel cihaz ve kullanıcı tarafından en son verilecek yasal kimlik işleri §26'daki kapsamda bekler. Yeni oturum önce PROJE_DEVIR §27 ve bu raporu okusun.
