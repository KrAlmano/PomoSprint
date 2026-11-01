# Site görünüm kontrolü — 1 Kasım 2026

## Değişiklik

- Özellikler sayfasında yalnız ilk telefonu kaydıran parallax ve telefon gruplarının giriş hareketleri kaldırıldı. Diğer içerik/dekor hareketleri korunur. Eşli telefonlar ortak grid, eşit genişlik ve üst hizayı paylaşır; dar ekranda tek sütuna geçer.
- Hareket azaltma tercihi sayfa açıkken değiştirilince GSAP ve ScrollTrigger temizlenir; tercih kaldırıldığında animasyonlar yeniden kurulur. Video yedeğinde `[hidden]` CSS kuralı korunur.
- Deneme geçmişi metinleri Raporlar konumuna güncellendi. Dört TR/EN Deneme geçmişi/net ekranı iPhone 17 üzerinde ayrı QA uygulamasında, gerçek uygulama widget'ları ve kurgu bellek içi veriyle yeniden çekildi. Gerçek kullanıcı veya veritabanı kullanılmadı. [Çekim kanıtı](site_qa_2026-11-01/README.md), [yeni medya manifesti](../landing/screenshots/manifest-20261101.json). 28 Ekim manifesti ve ham dosyaları korunur; dört eski görsel `.assetsignore` ile yeni yayından dışlanır.
- CSS ve JS cache sürümleri ortak parçalar ve tüm yardımcı sayfalarda güncellendi.

## Doğrulama

- Safari izole yerel önizlemede önce TR/EN 24 sayfa × 375/1024/1440 genişlik = **72/72** kaynak/taşma/sayfa ölçümü geçti. Dört çift 1024/1440 genişliğinde 220×458 px ve aynı hizada, 375 genişliğinde tek sütunda 260×545 px ölçüldü. Kaydırma sonrasında Deneme çiftinin üst/alt koordinatları eşitti ve `transform=none` idi.
- Yeni ekranlar eklendikten sonra TR/EN ana sayfa/Özellikler × üç genişlikte **12/12** tekrar kontrolü geçti; yeni dört PNG tarayıcıda yüklendi, 540×1170 ölçü ve dil kontrolleri geçti. Bu son turda Safari sekmesi gizliydi, yalnız DOM/kaynak/yerleşim ölçümüdür. macOS pencere görüntüsü üretmediği için site görünümü piksel bazında doğrulanmış sayılmaz. Ham simülatör kareleri ayrıca görüntülendi.
- Node testleri **177/177**, `sync_partials.py --check`, JS sözdizimi, `git diff --check` ve `wrangler deploy --dry-run --keep-vars` başarılı. Dry-run yayın yapmaz.
- Simülatörün çekim için geçici durum çubuğu override'ı temizlendi; kullanıcıya ait normal uygulama veya hesap verisi silinmedi.

## Canlı durum

Bu çalışma henüz canlıya yayımlanmadı. Kullanıcının önceki talimatına göre her yeni deploy öncesi onay gerekir. Hazır kaynakta daha önceki yerel KPSS metinleri de vardır; yayımlanacak bütün paketin kapsamı kullanıcıya belirtilmelidir. Bu çalışma uygulama dağıtımı veya yeni Supabase işlemi değildir.
