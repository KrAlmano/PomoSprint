# Site sadeleştirme QA — 8 Ekim 2026

Kullanıcının istediği üç düzenleme yapıldı ve `https://pomosprint.app` / `www.pomosprint.app` üzerinde yayınlandı. Son Worker **`840fd4f1-0779-493a-ad5b-e41fcd27a3c3`**. Önceki lig açıklaması Worker'ı `6bdb8f56` tarihsel kalır; uygulama ve sunucu sözleşmesi bu tur değişmedi.

## Yapılanlar

- Özellikler koleksiyon yörüngesinin iki dekoratif nokta öğesi kaldırıldı. Üç normal avatar yerine mevcut **Bronz, Gümüş, Altın, Safir ve Elmas kupalı** `league_*_monthly.webp` görselleri kullanılır; toplam beş avatar vardır. Yeni görsel üretilmedi. Merkez kum saati ve kesikli yörünge korunur.
- Beş avatar ortak18 saniyelik yörüngede72° aralıklarla döner; ters görsel dönüşü avatarları dik tutar. Reduced-motion’da aynı eşit dağılım sabittir. `.orbit-dot/.ot-cycle` kuralları başka sayfadaki Pomodoro döngüsü için korunur; yalnız koleksiyonun `.ot-d1/.ot-d2` öğeleri ve kullanılmayan ters yörünge kuralı kaldırıldı.
- SSS'deki **“Bir sorum var, nasıl ulaşabilirim?”** sorusu görünür listeden ve JSON-LD'den kaldırıldı. Kalan11 soru/cevap eşleşir; alt iletişim alanı ve e-posta bağlantısı aynıdır.
- Destek → Yasal Metinler bölümündeki Gizlilik Politikası bağlantısının parantezli veri sorumlusu açıklaması TR/EN'de kaldırıldı. Listede yalnız dört yasal bağlantı vardır. Link başlığı doğru biçimiyle **Gizlilik Politikası** olarak korunur; gerçek gizlilik metninin içeriği değiştirilmedi.
- Ortak CSS cache sürümü **`20261008e`**, üç auth yardımcı sayfa dahil18 HTML'de eşitlendi. Ana JS ve video dosyaları `20261008d` olarak kalır. Telefon çerçevesi, video açıklamaları, otomatik sessiz döngü ve önceki lig metinleri korunur.

## Gerçek doğrulama

| Kontrol | Sonuç / kanıt |
|---|---|
| Safari yerel masaüstü ve320×844 | Beş kupa avatarı görünür/dik, yatay taşma veya çakışma yok; SSS son cevap açılır ve alt iletişim alanı kalır; Destek dört link |
| Safari canlı masaüstü ve320×844 | Koleksiyon beş avatarla doğru; canlı SSS AX11 soru/son cevap açılımı; canlı Destek liste yalnız dört link |
| Statik preflight |18 HTML,741 iç referans/70 hedef,16 CSS referansı,30 SRI,42 ARIA ID;60img/3video; hata0; SSS11/schema11; ana sayfa içerik ağacı cache tokenları dışında aynı |
| `sync_partials.py --check`, `git diff --check` | Çıkış0 |
| `cd scripts && npm test` |133/133, atlama0; helper cache eşitlemesinden sonra tekrar geçti |
| `flutter analyze` | Temiz;10,58sn |
| Tam Flutter paketi |1215/1215, atlama0; `--concurrency=1 --dart-define=SCREENSHOTS=true --reporter expanded`;260,25sn |
| Wrangler dry-run / final deploy | Her ikisi çıkış0;83 public varlık; ilk güncellemede16 yükleme/67 mevcut, son cache eşitlemesinde3 yükleme/80 mevcut |
| Son Worker HTTP regresyonu |17 GET isteğinde52/52: kaynak HTML/CSS/JS ve medya SHA-256/MIME, iki MP4 Range206/birebir bayt, güvenlik/cache başlıkları, sorgu koruyan yönlendirmeler ve private404 |
| Bağımsız canlı kapsam kontrolü |21 GET isteğinde120/120: beş kupa WebP SHA/MIME, yörüngede5img/0nokta, SSS11/schema11, TR/EN destek4link, sekiz yasal sayfa200, CSS e ve üç yardımcı kaynak doğrulaması |
| Bağımsız kaynak incelemesi | Beş kupa/eşit yörünge/reduced-motion, SSS11 ve iki dil destek doğru; cache ve kanıt yolu notları düzeltildi |

Kanıt kökü: `qa_evidence_20261008/site_cleanup_20261008/` (ham çıktı §37 temizliğinde kaldırıldı). `source_preflight.json`, `http_post_deploy.json`, `flutter_checks.json`, `protected_before.json` / `protected_after.json`, test/deploy günlükleri ve `safari_observations.json` bu turu kaydeder. Safari ekranları ve AX sonuçları CUA konuşmasında görüntülendi; yeni yerel PNG arşivi oluşturulmadı. Reduced-motion kaynak kuralları incelendi; bu tur OS tercihi değiştirilip ayrı fiziksel cihaz testi yapılmadı.

Bağımsız HTTP ilk turunda114/117 geçti: yalnız üç auth yardımcı HTML'in ham SHA'sı farklıydı. Teşhis, farkın tek mevcut Cloudflare Analytics beacon satırından ibaret olduğunu gösterdi. Tam gözlenen satır allowlist ile çıkarılınca kaynaklar birebir eşleşti; başka normalizasyon yapılmadı. Ham/çıkarılmış SHA'lar ve ilk kırmızı sonuç `independent_http_initial_raw_hash.*`, `independent_http_helper_diagnosis.json`, son120/120 sonucu `independent_http.json` / `.md` içinde korunur. İlk+teşhis+son toplam45 GET; final21 GET, en fazla dört paralel. Bu edge ekinin davranışı değiştirilmedi. Root'un17/52 kontrolü ayrı kapsamdır; iki süitin sayıları birbirine eklenip tek sonuç gösterilmez. İlk görev dağıtımı `f40acb9b` sonrası52/52 sonuç `initial_http_post_deploy.json` olarak tarihsel tutulur; son cache eşitlemesi Worker840fd4f1 ile tekrar52/52 geçti.

## Korunan ortam ve devam

Worker kodu, ana JS, Wrangler yapılandırması, iki MP4 ve kritik üretim Dart dosyaları öncesi/sonrası SHA-256 ile aynı. Flutter koşusu sonrası44 mevcut tarihsel PNG birebir geri yüklendi. Bu tur canlı hesap/seans/Auth/SMTP/DB yazımı veya uygulama native derlemesi yapılmadı; önceki §29 ürün/backend doğrulamaları bu site turunun yeni sonuçları sayılmaz. Kullanıcıların yasal kimlik/adres bilgisi için mevcut bekleyen iş değişmedi.

Yalnız görev için açılan8792 yerel preview kapatıldı. Safari Responsive Design Mode'dan çıkıldı; ayrı görev penceresi canlı Özellikler sayfasında bırakıldı. Chrome ve diğer Safari pencereleri değiştirilmedi. Normal uygulamanın canlı ortam/gerçek25–50dk yapılandırmasına dokunulmadı. Yeni ürün isteği gelene kadar başka özellik ekleme; devam için [PROJE_DEVIR §30](../PROJE_DEVIR.md) ve [AGENTS §8](../AGENTS.md) oku.
