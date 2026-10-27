# Pozitif süre–net içgörüsü — 28 Ekim 2026

## Veri ve güvenli kapsam

`aa_exam_insights_test.dart`, yalnız açıkça verilen yeni yerel QA hesabını
okur. `create_exam_insight_fixture.py`, önce mevcut Mailpit onaylı hesap
hazırlayıcısını kullanır. Aynı e-posta zaten varsa hiçbir değişiklik yapmadan
durur; başka kullanıcı veya canlı sunucu üzerinde çalışmaz.

Kontrollü geçmiş: iki standart 165 dakikalık TYT, Türkçe netleri
**19,25 → 27,50** ve aralarında Türkçe kategorisinde **25 dakika** normal
çalışma. Normal kayıt ve netler gerçek yerel RPC'lerle yazılmıştır; geçmiş
zamanları test verisidir. **355 dakikanın hiçbiri bu senaryoda doğal süre
beklenerek oluşturulmamıştır.** Normal ekonomi 5 puan/20 kum, Deneme ekonomisi
66 puan/12 kumdur. Katalog, global saat veya eski kullanıcı verisi değiştirilmez.

Yerel manifest:
`build/overnight_backend/exam_insight_fixture_989835df-a1fc-4a6a-8321-857302001d31.json`.

## iOS 18.6 sonucu

İlk koşu, test sorgusunun `exam_attempts.catalog_version` kolonunu varsayması
nedeniyle uygulama açılmadan başarısız oldu. Değer, gerçek şemadaki
`definition` JSON alanından okunacak şekilde düzeltildi. Tam sorgu `WHERE false`
ile şemada doğrulandı; ilk başarısız günlük korunur:
`/tmp/pomosprint_ios18_aa_01.log`.

İkinci koşu **1/1 native + incelenmiş yerel parite PASS**:
`/tmp/pomosprint_ios18_aa_02.log`.

- Aynı hesaba gerçek giriş formundan giriş yapıldı.
- Profil ekranındaki seçeneklerle Türkçe ve İngilizce seçildi.
- Gerçek Denemelerim ekranında 25 dakika ve 19,25 → 27,50 cümlesi görüldü.
- İngilizce karşılığı 19.25 → 27.50 biçiminde doğrulandı.
- İçgörünün nedensellik kanıtı olmadığını açıklayan metin iki dilde görüldü.
- Paragrafların ekran sınırlarına sığdığı ve iki ekonominin değişmediği doğrulandı.

Görseller: `analiz/ekran_gece_2026-10-28/ios18-insights/`.
Bu akış, ilk veri yükleme hatası/önbellek yarışları için birim testlerinin
yerine geçmez; onları gerçek görünüm ve dil seçimi ile tamamlar.

## Android

Aynı kontrollü veriyle ayrı Android native koşusu planlıdır. Henüz PASS
olarak sayılmaz. Önce devam eden gerçek süreli cevapsız Maraton testi bitmelidir.

Çalıştırma bayrakları: `E2E_EXAM_INSIGHTS=true`, `E2E_EXAM_INSIGHT_EMAIL`
ve `E2E_EXAM_INSIGHT_OWNER`. Kaynak test, e-posta ad alanını, owner etiketini,
12 saatlik hesap yaşını ve bitmemiş yerel kayıtları kontrol eder. Bu kontrol
başarısızsa mevcut aktif seans veya kuyruk silinmez.
