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
- Supabase URL ve anon anahtar yalnızca `js/config.js` içinde durur.
- Yeni avatar eklenince `assets/avatars/<id>.png` dosyasını `avatars/<id>.webp` olarak ekle: `cwebp -q 80 -resize 160 160 in.png -o avatars/<id>.webp`.
- `_partials/`, `tools/` ve `*.md` `.assetsignore` ile yayından hariç tutulur; `_headers` tutulmaz (Workers okur, yayınlamaz).
- Özellikler sayfasındaki telefon videoları `js/main.js` içindeki `SHOT_VIDEOS` listesinden gelir (540x1174, sessiz döngü). Her video için ilk kareden bir poster (`videos/<ad>.webp`) olmalı: `ffmpeg -i <ad>.mp4 -frames:v 1 kare.png && cwebp -q 72 kare.png -o videos/<ad>.webp`. Listede olmayan ekranlarda yer tutucu ya da "Örnek görünüm" kartı görünür. Eski arayüzü gösteren `leaderboard.mp4` ve `reports.mp4` güncel kayıt gelene kadar listeden çıkarıldı ve `.assetsignore` ile yayınlanmıyor.
- Ana sayfadaki canlı aylık sıralama bölümü (`#siralama`) gizli başlar; en az 3 kişi puan topladığında görünür.

## Yardımcı sayfalar

Üçü de Türkçe ve İngilizcedir: dil bağlantıdaki `?lang=tr|en` parametresinden, yoksa tarayıcı dilinden seçilir (`js/auth-i18n.js`). E-posta şablonları İngilizce kullanıcılar için bağlantıya `lang=en` eklemelidir.

- `reset-password`: `#access_token=...&type=recovery` (implicit akış) ve `?token_hash=...&type=recovery` (e-posta şablonu) bağlantılarını kabul eder; token_hash form gönderilince doğrulanır.
- `confirmed`: e-posta onayı dönüşü; parametresiz açılınca "onaylandı" demez.
- `unsubscribe`: `?email=...&token=...`; çıkış yalnızca butona basınca yapılır.
