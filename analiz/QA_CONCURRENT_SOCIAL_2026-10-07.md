# Beş eşzamanlı hesap / iOS simülatör QA — 7 Ekim 2026

**Sonuç:** Beş farklı iOS simülatöründe beş ayrı yeni hesap aynı anda çalıştırıldı. Arkadaş görünürlüğü, odak/mola ayrımı, gizlilik, eşzamanlı Maraton, rapor ve arkadaş sıralaması geçti. Bu koşuda ürün hatası bulunmadı. Test aracındaki ilk HTTP taşıma hatası düzeltildi; hesap açılmadan durmuş olan bu girişim başarılı koşudan ayrı kaydedildi.

Üç alt ajan istemci protokolünü/native sonuçlarını, koordinatörü ve sosyal kaynak/DB tutarlılığını bağımsız inceledi. Kanıt: koordinatör (ham çıktı §37 temizliğinde kaldırıldı), sosyal inceleme (ham çıktı §37 temizliğinde kaldırıldı), native framework sonuçları (ham çıktı §37 temizliğinde kaldırıldı).

## Ortam ve gerçek eşzamanlılık

Xcode `/Applications/Xcode.app` ve iOS18.6 kullanıldı. Beş cihazın tamamı test boyunca açıktı; aynı derlenmiş integration-test uygulaması her cihaza kuruldu. Her uygulama kendi Auth hesabını oluşturdu, gerçek uygulama giriş ekranından giriş yaptı ve hesap/rol UID eşitliğini doğruladı. Tek uygulamada hesaplar sırayla değiştirilmedi.

| Rol | Simülatör | UDID | Test süreci | Gerçek UI Maratonu |
|---|---|---|---:|---|
| 1 | iPhone 16 Plus | BEA55019-D5C3-420F-90F2-0B0CBD5690CF | 87963 | 25×2 |
| 2 | iPhone 16 Pro | 7B8AF086-0864-42FD-B4D8-37A782C3F6B9 | 87982 | 50×2 |
| 3 | iPhone 16 Pro Max | DEF62A74-521E-4200-A6E4-ECA27D8F5C30 | 88016 | 25×2 |
| 4 | iPhone 16 | 6372AD09-B2C2-4F7F-B1DC-ABDC4F104A80 | 88072 | 50×2 |
| 5 | iPhone 16e | 61FF8969-1BA9-4411-A87F-59FDEC9AE668 | 88104 | 25×2 |

Beş süreç aynı anda çalışırken PID/UDID kanıtı alındı. Başlatma manifesti (ham çıktı §37 temizliğinde kaldırıldı), eşzamanlı süreç kaydı (ham çıktı §37 temizliğinde kaldırıldı), Dart derleme hashleri (ham çıktı §37 temizliğinde kaldırıldı). İlk rezervasyon → son rapor 109,596 sn; beş cihazın native framework'ü teardown sonrasında da **All tests passed!** yazdı. `tearDownAll` satırı ayrıca bir ürün senaryosu olarak sayılmadı.

Backend yalnız `supabase_db_pomosprint-local` Docker projesidir. Beş yeni test hesabı burada kaldı; kişisel/canlı hesaplara dokunulmadı. Yerel kısa kayıt modu 5/10 sn odakları 25/50 dk kaydeder; mola10 sn, Buradayım penceresi gerçek60 sn. Canlı Maraton paketleri uygulanmadı.

## Senaryolar ve kabul ölçütleri

| Senaryo | Yapılan kontrol | Sonuç |
|---|---|---|
| Arkadaşlık tam ağı | Gerçek istemci servisleriyle 10 istek +10 kabul; her hesapta diğer4 UID | 5/5 |
| Herkes odakta | Her gerçek Sosyal ekranda diğer4 kişi birer kart; Matematik kategorisi; authenticated RPC'de tam ID/durum kümesi | 5/5 |
| Karma durum | 1–2 odakta/Fizik, 3–4 molada, 5 durmuş; iki filtrede yalnız beklenen kişiler | 5/5 |
| Görünürlük kapalı | 1. hesabın kendi gizlilik tercihi kapatıldı; diğer4 hesapta kayboldu | 5/5 |
| Görünürlük geri açıldı | Beş hesap yeniden odakta; eski mola/durmuş durumu kalmadı | 5/5 |
| Gerçek Maraton | Popup →2 seans→25/50→Başlat→ilk odak→mola→Buradayım→ikinci odak→tamamlanma | 5/5 |
| Rapor / ödül | Her kullanıcı kendi50/100 dk raporu,12/28 puanı,40 kumu; boş outbox/aktif kayıt | 5/5 |
| Arkadaş sıralaması | Beş katılımcı adı ve kendi Sen işareti gerçek UI'da; DB puanları ayrıca eşlendi | 5/5 |
| Tamamlanma sonrası | Her Sosyal ekranda iki filtre de boş; kendi satırı/duplicate/yanlış kişi yok | 5/5 |

17 bariyerin tamamı beş istemciyle tamamlandı. Beş sosyal gözlem türü×beş hesap = **25/25 tam UI/RPC matrisi**. Host yalnız beş kayıtlı ayrı UID, açılmış finished bariyeri, abort olmaması ve beş değişmez başarılı rapor varsa başarı üretir. Host DB'ye ilişki veya seans yazmaz. Ham sonuç (ham çıktı §37 temizliğinde kaldırıldı), bağımsız doğrulama (ham çıktı §37 temizliğinde kaldırıldı).

Sosyal görünürlük matrisinde durumlar gerçek servis/RPC çağrılarıyla kontrollü yayımlandı: 25/50 dk odak son tarihi veya3 dk mola son tarihi. Bunlar tamamlanmış Pomodoro değildir ve rapor/puan üretmedi. Ardından beş cihazdaki gerçek timer/popup/Buradayım akışıyla ayrı seanslar tamamlandı. İki aşama birbirinin yerine gösterilmez.

## Veritabanı mutabakatı

Bağımsız salt okuma, yalnız bu beş UID'yi kapsar: SQL (ham çıktı §37 temizliğinde kaldırıldı), sonuç (ham çıktı §37 temizliğinde kaldırıldı).

Ek bağımsız API kontrolünde beş hesabın her biriyle yeniden gerçek yerel Auth girişi yapıldı. `get_my_friends` dört arkadaşın tam ID→puan kümesini döndürdü; kendi profil puanıyla birleştirilen beş kişilik küme12/28 değerleriyle eşleşti. Kendi lig puanı ve `get_live_friends_with_breaks` boşluğu da doğrulandı. Bu kontrol ayrı bir arkadaş sıralama RPC'si iddiası değildir; gerçek UI sıralaması önceki senaryodadır. Credential/e-posta/token saklanmadı. Authenticated API kanıtı (ham çıktı §37 temizliğinde kaldırıldı).

| Değer | Beklenen | DB sonucu |
|---|---:|---:|
| Auth / profil / seans sahibi | 5 | 5 |
| Kabul edilmiş arkadaşlık çifti / yönlü satır | 10 /20 | 10 /20 |
| Her hesabın kabul edilmiş arkadaşı | 4 | 4 |
| Benzersiz odak seansı / client UUID | 10 /10 | 10 /10 |
| Çalışma dakikası | 350 | 350 |
| Taban puan +Maraton bonusu | 78 +14 | 78 +14 |
| Seans / profil / lig toplam puanı | 92 | 92 |
| Kum | 200 | 200 |
| Tamamlanmış Maraton / onay bileti | 5 /5 | 5 /5 |
| Onay penceresi | 60 sn | 60 sn |
| Sahip/indeks/onay saati uyuşmazlığı | 0 | 0 |
| Geçersiz plan / mükerrer seans / kalan sosyal durum | 0 | 0 |

25×2 hesapları12 puan/50 dk/40 kum,50×2 hesapları28 puan/100 dk/40 kum aldı. Bonuslar +2/+4 birer kez verildi. Bonus final seansın `bonus_points` değerine dahil olduğundan toplam puana ikinci kez eklenmedi. Mola/onay süresi çalışma dakikasına eklenmedi.

## Yenilenme, hata ve kapsam sınırı

Sosyal ekran **polling** kullanıyor: görünür ve ön plandayken normal uygulamada30 sn, kayıtlı yerel QA'da2 sn; sekmeye/ön plana dönüşte hemen sorgular. Bu koşuda odak filtresinde doğru kümenin görülmesi bariyerden1,673–2,413 sn sürdü. Mola gözlemi3,041–7,763 sn; önceki odak ekran görüntüsü ve filtre geçişini de içerir. Bunlar saf ağ/push gecikmesi veya üretim30 sn ölçümü değildir.

Force-kill'de heartbeat/disconnect mekanizması yok; sunucuya yazılmış odak son tarihine veya iptal isteğine kadar görünebilir. Bu tur beş cihazlı sosyal matris ve eşzamanlı kısa Maraton testidir. Önceki tek cihaz kapanma/60 sn timeout/Android sonuçları [popup QA](QA_MARATON_POPUP_2026-10-07.md) içinde; burada tekrar koşulmuş sayılmaz. Fiziksel cihaz, canlı backend, normal25/50 dk duvar saati seansları, push bildirimleri ve Android eşzamanlı beş cihaz bu koşuya dahil değildir. Yerel onay60 sn kaldı, yeni timeout testi bu tur yapılmadı.

İlk yalnız1. cihaz denemesinde koordinatör POST'u chunked gönderildi, host Content-Length beklediği için400 döndü. Test helper'ına UTF-8 byte uzunluğu eklendi; yeniden derleme18,9 sn ve sonraki beş cihaz koşusu geçti. Ürün kodu değişmedi. İlk girişim notu (ham çıktı §37 temizliğinde kaldırıldı).

Eklenen tek widget regresyonu, ters sırada tamamlanan iki sosyal istekte eski yanıtın yeni listeyi ezmemesini kontrol eder. **Tam Flutter1159/1159**, SCREENSHOTS=true,0 atlama; analiz temiz. Koordinatör protokol testleri7/7. Tarihsel8 screenshot aynı SHA-256 ile geri kondu. Flutter test logu (ham çıktı §37 temizliğinde kaldırıldı), analiz (ham çıktı §37 temizliğinde kaldırıldı), komut/restore kaydı (ham çıktı §37 temizliğinde kaldırıldı).

## Son ortam ve tekrar çalışma

Ek4 simülatör ve test koordinatörü kapatıldı; Android emülatörü açılmadı. iPhone16Plus/iOS18.6'da önceki normal yerel Maraton önizlemesi dikey/TR/boşta geri açıldı: PID90334,62 puan/140 kum. Beş test hesabı kullanıcı önizleme hesabına karışmadı. Geri açılmış ekran (ham çıktı §37 temizliğinde kaldırıldı), ortam kaydı (ham çıktı §37 temizliğinde kaldırıldı), toplu sonuç (ham çıktı §37 temizliğinde kaldırıldı). Yerel üç paket/helper ve Docker açık kalır. Kullanıcı komutu `tool/local_supabase/run_marathon.sh`; kişisel canlı hesap veya dış e-posta bu modda kullanılmaz. Commit/push/deploy/canlı SQL yapılmadı.

Tekrarında önce `tool/local_supabase/run_marathon.sh --prepare-only`, sonra beş uygun iOS18.6 cihazı boot edip bootstatus tamamlanmasını bekle. Koordinatörü cihazların başlatılacağı UDID sırasıyla aç:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
python3 tool/local_supabase/e2e/sim/concurrent_social_host.py \
  --devices UDID1,UDID2,UDID3,UDID4,UDID5 --port 54401
```

Başka terminalde yalnız bir binary derle; run ID her yeni koşuda farklı olmalı:

```sh
flutter build ios --simulator --debug \
  -t integration_test/r_concurrent_social_test.dart \
  --dart-define-from-file=tool/local_supabase/.runtime/marathon-ios.json \
  --dart-define=E2E_HOST_PORT=54401 \
  --dart-define=E2E_RUN_ID=YENI_BENZERSIZ_KOSU \
  --dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false
```

Bu private define dosyası açık yerel URL/anon, QUICK_TIMER=true,QUICK_TIMER_SAVE=true ve10 sn mola içermelidir. `simctl install <UDID> build/ios/iphonesimulator/Runner.app` ile aynı .app'i beşine kur. Hepsi kurulmadan ilkini başlatma. `simctl launch --terminate-running-process <UDID> com.pomosprint.app` ile sırayla aç; her açılışın ardından `/concurrent/status` reserved_count değerinin o slot sayısına ulaşmasını bekleyip sonrakini başlat. Tam hesap kaydını beklemek gerekmez; bütün hesaplar accounts_ready bariyerinde buluşur. Yanlış sıra/ek istemci koşuyu geçersiz yapar.

Final `/concurrent/results` için all_passed=true yanında her PID'nin Unified Log'daki teardown/All tests passed satırlarını denetle; macOS'ta Flutter stdout dosyası boş kalabilir. Fotoğraflar slot'a bağlıdır. Sonra beş UID'yle salt okuma mutabakatı yap, ek4 cihazı/hostu kapat ve normal önizlemeyi geri aç. Aynı çalışma ağacında Flutter build/test/analyze komutlarını paralel çalıştırma; beş uygulama süreci eşzamanlıdır, derleme tek yapılır.
