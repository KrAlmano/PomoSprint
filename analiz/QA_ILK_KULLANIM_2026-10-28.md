# Aynı hesapta ilk kullanım — 28 Ekim 2026

**Durum: senaryo hazır; native koşu henüz yapılmadı.** Kaynak:
[integration_test/h_first_use_journey_test.dart](../integration_test/h_first_use_journey_test.dart).
Bu belge planlanan gerçek süreli koşuları tamamlanmış göstermez.

## Akış ve başarı ölçütü

Tek, yeni yerel QA hesabı bütün zinciri izler:

1. Gerçek uygulama kayıt formu; iki zorunlu onay açık, ticari ileti kapalı.
2. Yerel Auth'ta hesabın önce onaysız olduğunun kontrolü; Mailpit e-postasıyla
   onay; ardından gerçek giriş formunda aynı hesapla giriş.
3. Türkçe dil seçimi, yaş, TUS hedefi, sekiz otomatik kategori, görünürlük,
   kurallar, iki saatlik hedef ve sekiz bölüm içeren ekran rehberi.
4. Normal sayaçta **kısaltılmamış 1.500 saniye / 25 dakika**. Başlangıç UUID'si
   ve tarihleri diskte saklanır; bağımsız `Stopwatch` en az 25 gerçek dakika
   geçtiğini doğrular. Süre, katalog, veritabanı tarihi veya cihaz saati
   değiştirilmez; geçmiş fixture kullanılmaz.
5. Sunucuda tek normal kayıt, 25 dakika, 5 puan, 20 kum, seri 1 ve tek lig
   olayı; başarı diyaloğunda 5 puan/20 kum görünür. Diyalog kapatıldıktan
   sonra günlük, haftalık ve aylık rapor listeleri bağımsız SQL ile
   karşılaştırılır.
6. Aynı hesapta TUS Temel Bilimler denemesi başlatılır. Sunucu ve disk
   başlangıcı **8.100 saniyelik** standart süreyi taşır. Erken tamamlama
   `exam_not_elapsed` ile reddedilir. Kullanıcı arayüzünden vazgeçilir;
   deneme 0 puan/0 deneme kumu kazanır, normal 25 dakika/5 puan/20 kum
   korunur ve raporlara deneme süresi eklenmez.

Son adım **135 dakika tamamlanmış TUS kanıtı değildir**; yalnız gerçek
başlatma, erken bitirmeyi reddetme ve vazgeçme akışıdır. Tamamlanmış TUS
kanıtı ayrı `r` koşusuna aittir.

## Çalıştırma ve koruma

Gerekli seçenekler: `E2E_FIRST_USE_REAL25=true`, her koşuya ayrı
`E2E_RUN_ID` (1–40 küçük harf/rakam/tire), yerel Supabase URL/anon key ve
yerel E2E host. Hesap adresi
`e2e-sim-first-use-<E2E_RUN_ID>@pomosprint.local` olur. Native wrapper
çalıştırmasını root yönetir.

Bayrak verilmezse test **SKIP** olur; `initE2e`, API, kayıt veya cihaz
durumu temizliği çağrılmaz. Etkin koşu 35 dakika zaman aşımına sahiptir;
uzun bekleyiş boyunca 30 saniyede bir ilerleme yazılır.

Başlangıçtan önce bitmemiş `r`, `w` veya önceki `h` işaretçisi, aktif sayaç,
aktif/bekleyen deneme işlemi ve dolu normal outbox kontrol edilir. Böyle
bir kayıt varken hazırlık durur; bozuk işaretçi/journal da silinmez. Aynı
koşu kimliği/e-posta yeniden kullanılamaz. Kayıt sonrasında bütün SQL ve
API doğrulamaları aynı UID ile sınırlıdır. Başarıda veya hatada hesap,
seans, marker ve auth için cleanup/signout yapılmaz; hata kanıtı korunur.

Mailpit **yerel SMTP kutusudur**. Bu senaryo kişisel/gerçek internet
e-posta kutusuna teslimi veya Resend teslim edilebilirliğini test etmez.
Onay yardımcısı alıcıyı doğrular, yalnız sabit loopback Auth verify adresine
gider, redirect takip etmez ve tokenı loglamaz. Canlı hizmet çağrısı yoktur.

## Planlanan native koşular

Saatler Europe/Istanbul'dur; bunlar sonuç değil, çalışma planıdır.

| Platform | Planlanan başlangıç | Amaç / önkoşul |
|---|---|---|
| iOS 27 | Yaklaşık 02:10 | Önce aktif TUS `r` finali doğrulanacak; ardından ayrı yeni ilk-kullanım hesabı. |
| iOS 18 | Yaklaşık 03:42 | Doğal 04:00 çalışma günü sınırını geçen 25 dakika hedeflenir. |
| Android | Yaklaşık 04:45 | Önce aktif LGS koşusu bitecek; sonra ayrı yeni ilk-kullanım hesabı. |

Seansın çalışma günü profil saat diliminde **başlangıç − 4 saat** kuralına,
lig ayı tamamlanmanın İstanbul 00:00 takvim ayına göre SQL ile doğrulanır.
Marker `crossed_04_boundary` alanı gerçekten geçilip geçilmediğini kaydeder.
04:00'ten önce başlayıp sonra biten seans önceki güne aittir; bugünün günlük
kartının 0 göstermesi bu durumda doğrudur. Planlanan saatte başlamak tek
başına sınır geçişi kanıtı sayılmaz.

## Hazırlık kanıtı ve sınırlar

- Hedefli `flutter analyze --no-pub` temiz:
  `/tmp/pomosprint_first_use_h_analyze.log`.
- Kritik normal seans / lig olayı / deneme SELECT alanları yerel şemada
  `WHERE false` ile doğrulandı; çıkış 0. Kullanıcı satırı okunmadı veya
  değiştirilmedi: `/tmp/pomosprint_first_use_h_schema_check.log`.
- Bağımsız kaynak incelemesinde `competition_events.id` varsayımı düzeltildi;
  tablonun bileşik anahtarı `(kind, source_id)` olduğu için final kontrolü
  `source_id` okur.
- Normal bitişte açılan başarı diyaloğu için bekle → puan/kum kontrolü →
  ekran görüntüsü → `sessionCompletedOk` dokunuşu eklendi. Böylece rapor
  sekmelerine modalın arkasından dokunulmaz.
- Bu iki düzeltme **QA senaryosuna** aittir; ürün hatası veya ürün kodu
  değişikliği değildir. Kayıt/onboarding seçicileri, opt-in/binding davranışı
  ve Mailpit alıcı sözleşmesi ayrıca kaynak incelemesinden geçti.

Native başarı ancak ilgili platformun koşu logu, gerçek geçen süre,
korunan marker, sunucu sonuçları ve ekran kanıtları geldikten sonra
raporlanabilir. Şu an bu belge üç platform için PASS iddiası içermez.

## iOS27 gerçek sonuç — tamamlandı
`night-first-ios27-h1`, `/tmp/pomosprint_ios27_first_use_h1.log`: **1/1 + yerelparite PASS**. Aynı UI-kayıtlı hesap yerelMailpit onayı, parola girişi, TRseçimi/TUS/yaş/kategori/rehber, gerçek25dakika, görünür5puan20kum, günlük/haftalık/aylık bağımsızSQLkarşılaştırmaları ve gerçekTUSstart/erkenret/vazgeçmeyi tamamladı. İlkodak 23:07:33.710918Z→23:32:33.710918Z, bağımsız1503duvarsaatisaniyesi.04:00 sınırı bu turda **geçilmedi**; flagfalse. Vazgeçmeden sonra tek25dakika/5normalpuan20kum ve0denemeödülü kaldı. Kanıt `build/overnight_backend/first_use_ios27_final.json`. iOS18 veAndroidHsonuçları henüzbekleniyor.
