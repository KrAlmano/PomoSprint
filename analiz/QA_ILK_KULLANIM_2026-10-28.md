# Aynı hesapta ilk kullanım — 28 Ekim 2026

**Durum: iOS27 ve iOS18 aynı hesapta ilk kullanım ayrı ayrı 1/1 + yerel parite PASS; Android H sonucu bekleniyor.** Kaynak:
[integration_test/h_first_use_journey_test.dart](../integration_test/h_first_use_journey_test.dart).
Yalnız aşağıda log ve manifest ile doğrulanan iOS koşuları tamamlanmış sayılır; Android planı sonuç değildir.

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
raporlanabilir. iOS27 ve iOS18 sonuçları aşağıda ayrıdır; Android H için henüz başarı iddiası yoktur.

## iOS27 gerçek sonuç — tamamlandı

`night-first-ios27-h1`: **1/1 native test ve 27/28/29 + 30 yerel parite PASS**. [Özgün günlük](/tmp/pomosprint_ios27_first_use_h1.log), [korunan final işareti](../build/overnight_backend/first_use_ios27_final.json).

Aynı UI-kayıtlı hesap; Mailpit onayı, parolalı giriş, TR seçimi, yaş/TUS/kategori/rehber, gerçek 25 dakikalık odak, görünür 5 puan/20 kum, günlük–haftalık–aylık SQL karşılaştırması ve TUS başlatma/erken tamamlama reddi/vazgeçme adımlarını tamamladı. Odak başlangıcı **27 Ekim 23:07:33.710918Z**, bitişi **23:32:33.710918Z**; bağımsız ölçüm 1503 duvar saati saniyesi. Manifest `stage=complete`, `completion_verified=true`, `uses_historical_fixture=false` içerir.

**04:00 sınırı geçilmedi** (`crossed_04_boundary=false`). Tek 25 dakika/5 normal puan/20 kum ve 1 seri korundu; vazgeçilen Deneme 0 ödül verdi. Bu H koşusu 135 dakika TUS tamamlama değildir; o sonuç ayrı `r135_resume_final` koşusuyla doğrulandı. Android H ve AB finali burada tamamlanmış sayılmaz. Ayrı Android AC postflight başarısı da bu H zincirinin kapsamına dahil değildir.

## iOS18 gerçek sonuç — doğal 04:00 sınırı tamamlandı

`night-first-ios18-h1`: **1/1 native + 27/28/29 + 30 yerel parite PASS**. Aynı UI-kayıtlı hesapla kayıt, yerel Mailpit onayı, giriş, TUS onboarding/rehber, doğal25 dakika, başarı diyaloğu, günlük/haftalık/aylık rapor ve TUS başlatma/erken ret/vazgeçme zinciri tamamlandı. [Özgün günlük](/tmp/pomosprint_ios18_first_use_h1.log), [bağımsız marker/SQL dışa aktarımı](../build/overnight_backend/first_use_ios18_final.json).

İlk odak **28 Ekim03:44:57.400537 İstanbul** anında başladı ve **04:09:57.400537** anında bitti; ham süre1500 saniye, bağımsız duvar ölçümü1503 saniyedir. `stage=complete`, `completion_verified=true`, `uses_historical_fixture=false`, `crossed_04_boundary=true` korunan native marker'dan okundu. Dışa aktarım sonrası yalnız bu QA simülatörü kapatıldı; veri silinmedi.

**Seansın çalışma günü27 Ekim'dir.** Normal seans, tamamlanan Deneme, raporlar ve seri; bitiş günü yerine profil saat dilimindeki **başlangıç −4 saat** tarihini kullanır. Bu nedenle04:00'ten sonra bitse de bu25 dakika27 Ekim'e aittir. SQL'de `last_study_date=2026-10-27`, seri1, tek normal kayıt,25 dakika,5 puan ve20 kum doğrulandı. Bugünün28 Ekim günlük toplamının **0**, önceki günün **25**, haftalık ve aylık toplamın **25** olması doğrudur; seans kaybolmamıştır.

Gün atfı bağımsız olarak [StudySession.studyDay](../lib/models/study_session.dart:60), [normal/Deneme rapor dönüşümleri](../lib/utils/stats_calculator.dart:101), [çalışma günü yardımcısı](../lib/utils/study_day.dart:1) ve gerçek yerel SQL fonksiyonlarıyla karşılaştırıldı. Normal `complete_study_session`, Deneme `complete_exam_attempt` ve `_competition_record` başlangıca göre04:00 çalışma gününü üretir. Lig ayı ise normalde `completed_at`, Denemede `ends_at` üzerinden İstanbul00:00 takvim ayına atanır; bu ayrı kuraldır.

Son TUS denemesi **abandoned** kaldı:0 Deneme puanı,0 Deneme kumu,0 kabul edilmiş çalışma süresi ve ek lig olayı yok. Normal25 dakika korunur. Bu koşu gerçek04:00 sınırı kanıtıdır; doğal ay değişimi, DST veya135 dakika TUS tamamlaması değildir. Ürün veya tarih kuralı değiştirilmedi; bitiş gününü bekleyen varsayım düzeltilerek mevcut başlangıç-günü sözleşmesi doğrulandı.
