# pomosprint.app (landing)

Statik site; Cloudflare Workers static assets ile yayınlanır (`wrangler.jsonc`). Derleme adımı yok.

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
- Özellikler sayfasındaki telefon videoları `js/main.js` içindeki `SHOT_VIDEOS` listesinden gelir (540x1174, sessiz döngü). Her video için ilk kareden bir poster (`videos/<ad>.webp`) olmalı: `ffmpeg -i <ad>.mp4 -frames:v 1 kare.png && cwebp -q 72 kare.png -o videos/<ad>.webp`. Listede olmayan ekranlarda yer tutucu ya da "Örnek görünüm" kartı görünür. Eski arayüzü gösteren `leaderboard.mp4` ve `reports.mp4` güncel kayıt gelene kadar listeden çıkarıldı ve `.assetsignore` ile yayınlanmıyor.
- Ana sayfadaki canlı aylık sıralama bölümü (`#siralama`) gizli başlar; en az 3 kişi puan topladığında görünür.

## Yasal sayfalar

| TR | EN | Kim bağlanıyor |
|---|---|---|
| `/privacy` | `/en/privacy` | Uygulama (Profil ve Ayarlar), App Store ve Google Play gizlilik URL'si |
| `/terms` | `/en/terms` | Uygulama, kayıt ekranındaki onay |
| `/kvkk` | `/en/kvkk` | Kayıt ekranındaki aydınlatma teyidi, bekleme listesi formu |
| `/hesap-silme` | `/en/delete-account` | Google Play Data safety "hesap silme URL'si" |
| `/destek` | `/en/support` | App Store "Support URL", Play "Web sitesi"/destek; iletişim, sık sorunlar, hesap silme ve veri başvurusu yolları |

- Bu adresleri değiştirme; mağaza kayıtları ve uygulama sürümleri bunlara bağlı.
- **Veri sorumlusu kimliği eksik (KVKK-15):** `/privacy` ve `/kvkk` (iki dil) §1'de `<mark data-fill-in="KVKK-15">` ile işaretli yer tutucular var; bilgi uydurulmadı. Yayından önce gerçek ad-soyad/unvan ve adresle doldur, `<mark>`'ı kaldır: `grep -rn 'data-fill-in' landing/` boş dönmeli. Aynı bilgi `MAIL_SENDER_NAME` / `MAIL_SENDER_ADDRESS` (e-posta altbilgisi) ve mağazadaki geliştirici adıyla aynı olmalı.
- Metin değişince "Son güncelleme" tarihini yenile ve uygulamadaki `terms_version` / `privacy_version` değerleriyle eşleştir (iki dil birlikte).
- Uzun tablolar `.prose .data-table` ile yazılır; her `<td>` için `data-label` ver (dar ekranda kart düzeninde sütun adı olarak görünür).

## Yardımcı sayfalar

Üçü de Türkçe ve İngilizcedir: dil bağlantıdaki `?lang=tr|en` parametresinden, yoksa tarayıcı dilinden seçilir (`js/auth-i18n.js`). E-posta şablonları İngilizce kullanıcılar için bağlantıya `lang=en` eklemelidir.

- `reset-password`: `#access_token=...&type=recovery` (implicit akış) ve `?token_hash=...&type=recovery` (e-posta şablonu) bağlantılarını kabul eder; token_hash form gönderilince doğrulanır.
- `confirmed`: e-posta onayı dönüşü; parametresiz açılınca "onaylandı" demez.
- `unsubscribe`: `?token=<uuid>` (3 Ekim sonrası e-postalar; adres URL'de taşınmaz). Eski e-postalardaki `?email=...&token=...` de çalışır: sayfa adresi okuyup adres çubuğundan siler, istekte e-postayı yalnızca POST gövdesine koyar. Çıkış yalnızca butona basınca yapılır. Test: `cd scripts && npm test`.

## Bekleme listesi formu

Ana sayfadaki "Yayınlanınca haber ver" formunda ayrı, önceden işaretsiz ticari ileti onay kutusu (`#notify-consent`) vardır. `js/main.js` kutu işaretlenmeden POST göndermez; fakat istek gövdesi şu anda yalnızca `{ email }` olduğundan onay **sunucuya kaydedilmez**. Canlı waitlist tablosunda `proposed/19` A ile gelen `marketing_consent`, `consent_text_version`, `consented_at` ve `unsubscribe_token` kolonları bulunur; yeni satırlar onay metadatası olmadan kalır (`NULL`). Önce site bu alanları ve `waitlist-2026-10-03` sürümünü göndermeli, sonra `proposed/19` B uygulama planı yeniden incelenmeli; B onaylı kayıt dışında insert'i engeller. Bu yapılana kadar waitlist listesini pazarlama postası için onaylı sayma. Test: `scripts/test/landing_waitlist_form.test.mjs`.
