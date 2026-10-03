# Kendi alan adımızdan sunulan yazı tipleri

Site, ziyaretçinin IP adresini Google'a göndermemek için yazı tiplerini
`fonts.googleapis.com` / `fonts.gstatic.com` yerine buradan yükler (KVKK-19).
`@font-face` tanımları `landing/css/fonts.css` içinde.

| Dosya | Yazı tipi | Alt küme |
|---|---|---|
| `baloo2-v23-latin.woff2`, `baloo2-v23-latin-ext.woff2` | Baloo 2 (600, 700; değişken) | latin, latin-ext |
| `nunito-v32-latin.woff2`, `nunito-v32-latin-ext.woff2` | Nunito (400-900; değişken) | latin, latin-ext |
| `nunito-v32-italic-latin.woff2`, `nunito-v32-italic-latin-ext.woff2` | Nunito İtalik (700) | latin, latin-ext |

- **Kaynak:** 3 Ekim 2026'da Google Fonts'un sitenin kullandığı CSS adresinden
  (`css2?family=Baloo+2:wght@600;700&family=Nunito:ital,wght@0,400;0,600;0,700;0,800;0,900;1,700`)
  indirilen woff2 dosyaları; yalnızca adları değişti. Türkçe karakterler
  (ğ, ş, İ) latin-ext alt kümesinde, ı latin alt kümesinde.
- **Lisans:** iki yazı tipi de SIL Open Font License 1.1 ile dağıtılır
  (https://openfontlicense.org). Lisans bilgisi woff2 dosyalarının ad
  tablosunda da bulunur. OFL web'de kullanıma ve yeniden dağıtıma izin verir;
  koşullar için lisans metnine bak.
- **Önbellek:** `_headers` `/fonts/*` için bir yıllık `immutable` önbellek
  verir. Bir dosyayı değiştirirsen adındaki sürümü de değiştir
  (ör. `nunito-v33-latin.woff2`) ve `fonts.css`'i güncelle.
- **Yeni ağırlık ya da alt küme:** aynı CSS adresini modern bir tarayıcı
  kimliğiyle (`User-Agent`) indirip ilgili `@font-face` bloklarını
  `fonts.css`'e, woff2 dosyalarını buraya ekle. Google'a bağlantı geri
  eklenmesin; CSP (`font-src 'self'`) zaten engeller.
