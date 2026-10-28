# Canlı Safari görsel kontrolü — 28 Ekim 2026

Yayımlanan `https://pomosprint.app` doğrudan, ayrı Safari QA sekmesinde açıldı. Canlı sayfa iframe içine yüklenmedi. Worker sürümü: `e1bb6541-5794-4241-ab5e-66ded59a9298`.

TR/EN ana sayfa, Özellikler ve SSS sayfaları 375, 1024 ve 1440 CSS piksel genişlikte açılıp görsel olarak incelendi: **18/18 görsel smoke kontrolü başarılı**. Bu sayı eski yerel 72-case testinin tekrarı değildir. Başlıklar, menü ve seçili içerik alanları kontrol edildi; tüm sayfaların her pikseli veya bütün etkileşimler test edilmiş sayılmaz. Tam liste ve gerçek ziyaret saatleri `live_visual_checks.json` içindedir.

- Yeni Deneme/DUS kartları, kısa Yeni/Geçmiş/Lig sekmeleri ve TR/EN net giriş ekranları doğru görünüyor. Soru/süre bilgileri ve görseller yükleniyor; gözlenen alanlarda taşma/kırılma yok.
- Mobil menü aç/kapat ve Escape; gerçek dil bağlantısı ve Özellikler menüsü çalıştı. TR SSS'de ikinci yanıt açılırken ilk kapandı; EN yanıtı açıldı.
- TR/EN sayaç ve Maraton olmak üzere **dört video oynarken görüldü**. Görüntülerin değişmesi ve oynat/duraklat etiket geçişleri kontrol edildi. Her birinde duraklatma ve devam eylemi yapıldı. Sayısal `currentTime`, `muted` ve `loop` DOM alanları canlıda ayrıca okunmadı; bütün videolar için tam bir döngü turu beklenmedi. Bu teknik özelliklerin önceki yerel kanıtları ve root'un canlı byte/HTTP kontrolü ayrı değerlendirilir.
- Ana sayfadaki dinamik sıralama: **“Aylık sıralama hazırlanıyor. Odak zamanı!”**. Kalıcı yükleniyor ifadesi veya uydurulmuş kullanıcı/puan satırı görülmedi. Bu, henüz canlı olmayan aylık RPC için beklenen hazırlık görünümüdür.

## Gerçek görsel kanıt

`live-tr-home-375.jpg`, `live-en-features-1024.jpg`, `live-en-home-1440.jpg` doğrudan canlı sekmenin CUA ekran görüntüleridir. CUA kaynağı JPEG olduğundan biçim değiştirilmedi. Byte-hash ve kaynak URL eşlemesi `screenshots.json` içindedir; kaynak RAM hashleri indirilen dosyalarla birebir eşleşir. Ekran görüntüleri Safari çerçevesi ve RDM araçlarını içerir, saf tam-sayfa resimleri değildir. Yerel indirme yardımcısı yalnız bu gerçek baytların dosyaya aktarımı için kullanıldı; canlı site içine helper veya script enjekte edilmedi.

## Sınırlar

JavaScript konsolunu açma eylemi CUA görünümünde okunabilir konsol içeriği vermedi; **“konsol hatasız” denmiyor**. Kesin ilk paint, Chrome ve fiziksel cihaz tarayıcısı bu kontrolün kapsamında değil. Form gönderimi, hesap işlemi, veritabanına yazma veya deploy bu ajan tarafından yapılmadı. Kod ve yayın root tarafından yönetildi; bu klasör yalnız gözlem kanıtıdır.
