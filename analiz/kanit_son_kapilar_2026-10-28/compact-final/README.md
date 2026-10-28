# Son arayüz, normal uygulama ve kapılar

Bu arşiv `641cc16` Deneme arayüzüne aittir. Önceki üst dizin `gate1-*` kayıtları tarihsel 1476 testlik sonucu korur.

- Son UI turu: 1482 Flutter PASS, 5 isteğe bağlı PNG atlaması, 172 Node PASS; analiz ve partial eşliği temiz.
- Normal `lib/main.dart` iki cihaza yüklendi; yerel site/review backend, gerçek 25/50 dk. iOS’ta yeni Deneme ekranı CUA ile ayrıca açıldı.
- iOS unsigned release ve Android universal release üretildi; bunlar mağaza imzası/yayını veya fiziksel cihaz testi değildir.
- İlk tam UI turundaki 5 eski metin bulucu hatası `initial-finder-failure/` içinde korunur; işlevsel assertion’lar değiştirilmedi.
- `ios-normal-main.png` erken açılış/splash karesidir. Yüklenmiş ana ekran `ios-normal-main-settled.png`, yeni ekran `ios-normal-exam.png` dosyasındadır.
- Loglardan yalnız mutlak proje öneki kaldırıldı; ham `.env`, token dosyası veya APK commit’e alınmadı.
- Kapanış tekrarı `closing-gate/` altında: analiz temiz, 1482 Flutter PASS/5 PNG atlaması, Node172/172, partial eşliği temiz. İlk son-UI turundan ayrı tutulur.

Kaynak hashleri ve gerçek boyutlar `proof.json` ile `manifest.json` içindedir.
