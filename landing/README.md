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

## Yardımcı sayfalar

- `reset-password`: `#access_token=...&type=recovery` (implicit akış) ve `?token_hash=...&type=recovery` (e-posta şablonu) bağlantılarını kabul eder; token_hash form gönderilince doğrulanır.
- `confirmed`: e-posta onayı dönüşü; parametresiz açılınca "onaylandı" demez.
- `unsubscribe`: `?email=...&token=...`; çıkış yalnızca butona basınca yapılır.
