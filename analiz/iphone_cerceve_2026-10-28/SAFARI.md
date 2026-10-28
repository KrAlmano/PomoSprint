# Safari çerçeve kontrolü — 28 Ekim 2026

CSS `20261028c` yerel önizlemede iki temsilci kareyle incelendi (375 × 844 CSS px).

- TR Özellikler sayfasının sayaç videosunda ada merkezli; 09:41, pil/sinyal ve uygulama içeriği açık. Siyah ince çerçeve ve köşeler düzgün. [Gerçek Safari karesi](iphone-frame-c-tr-timer-375.jpg).
- TR ana sayfanın sosyal ekran galerisi örneğinde ada, çerçeve, köşe ve gölge mobil genişliğe sığıyor; başlık/içerik örtülmüyor. [Gerçek Safari karesi](iphone-frame-c-tr-gallery-375.jpg).

İki JPEG, CUA `getScreenshot` çıktısının değiştirilmemiş baytlarıdır; yerel QA indirme alanı kullanılarak kaydedildi, boyut ve SHA-256 birebir doğrulandı. Ayrıntılar [manifestte](safari-frame-check.json). Görüntüler Safari pencere çerçevesi ve QA iframe'ini içerir; kırpılmış tam sayfa çıktısı değildir.

Bu çalışma bütün 40 çerçevenin ayrı ayrı görsel testi veya yeni 72 durumluk tarama değildir. Daha sonra tespit edilen `weekly-en` içindeki gömülü ada ayrı bir kök ajan düzeltmesidir; bu iki temsilci karede görülmemiştir. Önceki yayın kanıtları değiştirilmedi.

Aktarım sırasında Safari odağı kişisel bir sayfaya değişince işlem durduruldu. Kişisel gövde okunmadı/etkileşim kurulmadı; ayrı yerel QA penceresinde yalnız kanıt baytlarının indirilmesi tamamlandı. Bu ajan kod, commit veya deploy işlemi yapmadı.
