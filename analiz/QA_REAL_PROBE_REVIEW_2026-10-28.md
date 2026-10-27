# Gerçek süre probe incelemesi — 28 Ekim 2026

Kapsam: `integration_test/r_real_duration_probe_test.dart` ve
`integration_test/w_normal_http_restart_test.dart`; ilgili kalıcılık,
`SessionQueue`, `ServerClock` ve native yardımcı sözleşmeleriyle salt-okuma
karşılaştırması. Ürün kodu/veritabanı/cihaz/saat değiştirilmedi. Bu rapor
beklemekte olan gerçek süreli koşuları tamamlanmış saymaz.

## İki test düzeneği iyileştirmesi

1. **r başlangıç koruması:** yalnız `e2e_real_duration_probe_*` anahtarlarını
   kontrol ediyordu. Aynı uygulama kurulumunda tamamlanmamış bir
   `e2e_normal_http_restart_*` kaydı varsa yeni hesap hazırlığı onu
   temizleyebilirdi. Kontrol iki prefixi de kapsayacak şekilde düzeltildi;
   tamamlanmamış `w` verisi varken yeni `r` başlangıcı reddedilir.
2. **w saat düzeltmesi:** iki sunucu tarihinin aynı küçük miktarda kaydığını
   kontrol etmek, saklanan gerçek saat farkının kullanıldığını tek başına
   kanıtlamıyordu. `SessionQueue`, kayıt üzerindeki `clockOffsetMs` varsa bunu
   güncel HTTP saat ölçümünden önce seçiyor; `ServerClock.correctionFor` bu
   farkı eşiksiz uygular. `w` artık başlangıç ve bitiş kaymalarını doğrudan
   aynı kalıcı `pending.clockOffsetMs` ile karşılaştırır. Tolerans yalnız
   **1.000 mikrosaniyeden az** serileştirme hassasiyetidir; keyfi 5 saniyelik
   bir düzeltme kabulü değildir.

Bu iki değişiklik yalnız test kaynaklarındadır. `r` dosyasının formatlanması
sonucu iki satıra ayrılan mevcut `if` ifadesine lint gereği süslü parantez
eklendi; uygulama davranışı değişmedi.

Doğrulama: hedefli iki dosya `flutter analyze --no-pub` temiz;
`server_clock_test.dart`, `session_queue_test.dart`, `timer_persistence_test.dart`
birlikte **55/55 PASS**. Bunlar saat/kuyruk/kalıcılık birim kontrolleridir;
gerçek25/135 dakika veya native süreç testinin yerine geçmez. Tam proje
kapısı ve gerçek native son koşuları root tarafından ayrıca yürütülür.

## Kanıt sınırları

| Başlık | r probe | w HTTP testi |
|---|---|---|
| Gerçek süre | Üretim sayacı/katalog süresi ve değişmeyen başlangıç-bitiş saklanır; finalde doğal deadline ve tam süre kontrol edilir. `E2E_PROBE_REQUIRE_COMPLETED=true` olmadan erken resume yalnız ara kanıttır. | `Stopwatch` en az1.500 gerçek saniye, üretim sayacı1500, değişmeyen tarihler ve doğal bitiş kontrol edilir. |
| Süreç yeniden başlatma | Kaynak tek başına farklı PID şartı koymaz. Kalıcı marker/aynı owner/timer kontrolüne ek olarak root'un OS terminate/çıkış ve app-container/native-plist manifesti zorunludur. | Farklı OS PID, aynı kalıcı auth, outbox UUID/tarih/clock snapshot ve ilk faz kanıtı şarttır. Root'un süreç kapatma günlüğü ayrıca saklanır. |
| Sunucu ödülü | 25dk5puan20kum;50dk12puan20kum;LGS75dk15deneme puanı3deneme kumu;TUS135dk27/5 bağımsız sabit beklenen değerlerle kontrol edilir. | Tek gerçek25 kaydı,5normal puan20kum; önceki normal/deneme satırları ve deneme cüzdanı değişmez. |
| Tekrar gönderim | Aynı UUID/attempt ile duplicate yanıtı ve değişmeyen ekonomi kontrol edilir. | Aynı UUID tekrar senkron ve RPC ile ikinci satır/ödül üretmemelidir; önceki satırlar korunur. |
| Gün/ay/seri | SQL kaynağından profil saat dilimi/04:00 çalışma günü ve İstanbul00:00 tamamlanma ayı kontrol edilir. | Aynı atıf kontrolüne mevcut geçmişten beklenen seri hesabı da eklenir. |
| Rapor | Native rapor ekranı bu probe'un kapsamı değildir; kalıcı oturum, olay ve ekonomi kontrolüdür. | Günlük/haftalık/aylık gerçek widget verileri bağımsız SQL ile dakika, normal/Maraton/deneme adetleri ve eşdeğer odak sayısı bakımından karşılaştırılır. Görsel piksel doğruluğunu tek başına kanıtlamaz. |

`w` gerçek fiziksel uçak modu/Wi-Fi kapatma testi değildir; localhost HTTP503
altında kalıcı kuyruk ve tekrar bağlanma testidir. Karma geçmiş varsa eski
deneme/Maraton kayıtları açıkça kontrollü fixture'dır; yalnız yeni25 dakika
duvar saatiyle beklenir. `START-STAGE PASS` final başarı değildir.

Saat dilimi/04:00 ve İstanbul00:00 hesaplamalarının SQL ile aynı çıkması,
bu gerçek koşunun ay/DST sınırını geçtiği anlamına gelmez. Bu testler yalnız
çalıştırıldıkları owner'ın saat dilimini kullanır; bütün saat dilimleri
iddiası ayrı parametrik/unit/SQL testlere aittir. Aylar arası offline puan
finalizasyonu da bu tek koşudan kanıtlanmaz.

Uygulama verisinin `--no-uninstall` ile korunması ve dış süreç kayıtları
gerçek native kanıtın parçasıdır. İlk uninstall nedeniyle marker kaybolan
koşular bu nedenle geçerli süreç kalıcılığı kanıtı değildir; yeni kaynak
değişiklikleri eski başarısız koşuları geriye dönük başarılı yapmaz.
