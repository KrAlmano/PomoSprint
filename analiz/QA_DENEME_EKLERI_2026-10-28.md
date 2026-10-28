# Deneme ayrıntıları ve AYT erken bitiş — yerel doğrulama

> Tarihsel ilk32 fazı: burada TYT150/AYT175 politikası o günkü koşuyu anlatır. Son kullanıcı kararı DUS ve yeni130/145 tablosuyla bunun yerini aldı; [güncel DUS raporunu](QA_DUS_ISTEMCI_2026-10-28.md) ve ana doğrulama raporunu esas alın. Eski kazanım snapshotlarının korunması bilinçlidir.

Tarih: 28 Ekim 2026. Bu rapor öneri32 istemcisini, izole SQL testlerini ve yeni native kontrollerini kapsar. **Canlıya uygulanmadı/deploy edilmedi.** Ana yerel 27–30 veritabanı ve31 paketi değiştirilmedi. Buradaki test hesapları kurmaca ve yereldir.

**Son durum:** İlgili istemci regresyonları113/113, dar analiz temiz; Android a3 ve iOS a2 son native turları PASS. Her platformun bağımsız SQL kontrolü21/21 geçti; Android son paritesi5/5 temiz. Önceki iOS turunun izin penceresi nedeniyle olan FAIL kaydı ayrıca korundu.

## Kullanıcı kararları ve uygulanan davranış

- Erken bitiş yalnız AYT'de ve sunucu capability'si açıksa kullanılabilir. Diğer altı deneme süre dolmadan tamamlanamaz; normal tam süre yolu korunur.
- Yeni tam süre Deneme kumu: LGS Sözel60, TYT150, AYT175. Diğer dört tür ve eski attempt'ın dondurulmuş ödül snapshot'ı korunur.
- Kullanıcı erken AYT kumunu **geçen süreyle orantılı, en fazla tam175** olarak seçti. Formül `floor(snapshot_full_coins × server_elapsed_seconds / planned_seconds)`; eski snapshot'ın sınırı kendi tam ödülüdür. Puan `min(snapshot_full_points, floor(elapsed_seconds / 300))` olur. Bu sayılar normal puan/kum cüzdanını değiştirmez.
- Süre istemcinin tıklama saatinden veya planlanan 180 dakikadan uydurulmaz; sunucu kabulündeki gerçek geçen süredir. Ağ yoksa erken bitiş niyeti bekler ve ekranda onay beklediği açıklanır. İstek deadline sonrasında ulaşırsa sunucu tam süre sonucunu döndürebilir.
- En az1 gerçek saniye gerekir.1–59 saniyede tamamlanan deneme1 adet sayılır,0 rapor dakikası/0 puan/0 seri katkısı/0 lig olayı üretir. Dakika aşağı yuvarlanır; erken testin bitişi kalan planlanan zamanı normal/Maraton oturumuna engel yapmaz.
- AYT net girişinde önce dört testten seçim yapılır. Yalnız seçilen testlerin dersleri açılır; her dersin doğru/yanlış değişiminde boş otomatik hesaplanır, boş ayrıca düzenlenebilir. Kaydedilmeyen dersler “sıfır net girilmiş” sayılmaz.
- İsteğe bağlı başlık/not tüm tamamlanan deneme türlerinde vardır. Başlık/not, seçim ve değişen netler **tek atomik Save** ile gönderilir. Yalnız başlık/not kaydı da mümkündür. Eksik key eski değeri korur, açık `null` yalnız başlık/notu temizler.
- Sonucu kayıtlı bir testi kapsam dışına çıkarma sessiz veri silmez. Revision çakışması açık inceleme ister; güncel kayıt yüklenmeden başka cihazın verisi üstüne yazılmaz. Aynı canonical isteğin tekrarında eski revision verilse bile duplicate kabul edilir.

## Resmî AYT yapısı

Dört test40'ar sorudur; toplam160 korunur. Seçilen80 gibi kapsam, toplamın yerine geçirilmez.

| Test | Alt dersler |
|---|---|
| Türk Dili ve Edebiyatı–Sosyal Bilimler-1 | Edebiyat24, Tarih-1 10, Coğrafya-1 6 |
| Sosyal Bilimler-2 | Tarih-2 11, Coğrafya-2 11, Felsefe12, DKAB/ek felsefe6 |
| Matematik |40 |
| Fen Bilimleri | Fizik14, Kimya13, Biyoloji13 |

Dağılım [ÖSYM'nin2026 YKS açıklamasında](https://www.osym.gov.tr/2026-yks-sonuclari-aciklandi) doğrulandı. [2026 YKS Başvuru Kılavuzu](https://dokuman.osym.gov.tr/pdfdokuman/2026/YKS/basvuru_kilavuz06022026.pdf) sözleşmede de bağlantılanmıştır. DKAB/ek felsefe aynı6 soruluk alternatif kapsamdır; iki kez sayılmaz. Bu ürün ÖSYM'nin resmî puan hesaplamasını yapmaz; yukarıdaki kum/odak puanı uygulamanın kullanıcı tarafından seçilen politikasıdır.

## İstemci ve kalıcılık sınırları

İlgili kaynaklar: `lib/models/exam_model.dart`, `exam_details.dart`, `lib/services/exam_service.dart`, `exam_persistence.dart`, `lib/screens/exam_screen.dart`, `lib/widgets/exam_results_dialog.dart` ve iki ARB/üretilen çeviri.

- DTO/diske `planned_duration_seconds`, `elapsed_seconds`, `credited_minutes`, `completion_kind`, `title`, `note`, `selected_module_ids`, `details_revision` taşınır. Tamamlanmış DTO'nun eski `duration_seconds` alanı gerçek süredir; mevcut rapor tüketicisi böylece doğru dakikayı kullanır.
- Yeni journal sürümü2'dir. `completeEarly` ve `details` niyetleri ayrı tutulur. Gönderilecek patch, net altkümesi ve formun açıldığı revision değişmez bir zarf oluşturur. Otomatik retry bu zarfı değiştirmez.
- Gönderilmemiş form taslağı bu zarftan ayrıdır. Owner/epoch değişirse eski hesabın geç yanıtı yeni hesaba yazılmaz. Kullanıcı değişiminde açık özel form bir kez güvenli kapatılır.
- Tanınmayan journal sürümü/eylemi veya geçersiz kayıt sessizce düşürülüp üzerine yazılmaz. Mevcut bozuk ham kayıt korunur ve hata görünür kalır.
- Eski sunucuda capability yokken yeni eylemler/başlık/not UI'sı kapalı; mevcut tam süre ve eski net RPC akışı test edildi. Yeni istemci journal'ını eski uygulamaya indirgemek desteklenmiş bir veri dönüşümü değildir; eski sürüme otomatik downgrade yapılmaz.
- Sunucu32 down betiği özel veri oluştuğunda `exam32_rollback_would_lose_data` ile durur. Erken sonuçları180 dakika göstermek, metadata/netleri silmek veya kazanımları geri almak için otomatik geri dönüş yapılmaz. Capability/early_enabled kapısı operasyonel durdurma için kullanılır, geçmiş yeni projection korunur.

## Bağımsız incelemenin yakaladığı P1

Aşırı uzun başlık/not alanında limit olmadığı için5001/20001 karakterlik giriş autosave ile yazılabiliyor, aynı uygulamanın coldstart okuyucusu bunu reddederek owner'ın tüm journal'ını `journal_invalid` yapabiliyordu. [Bağımsız bulgu ve iki yeniden üretim](kanit_exam32_native_2026-10-28/android/client_validation/independent_review.md) arşivdedir. Bu2/2 sonuç, kusurun kanıtıdır; düzeltmenin testi diye sayılmaz.

Düzeltme üç sınırda yapıldı:

1. UI başlığı120, notu2000 **Unicode scalar** ile sınırlar; aşırı yapıştırma sessiz kırpılmaz, yerelleştirilmiş hata gösterilerek reddedilir. Görünür ve erişilebilir uzunluk sayaçları vardır.
2. `updateDetailsDraft` aynı uzunluk sınırını doğrular. Draftın JSON'u kendi okuyucusundan geçmiyorsa kaydetmez.
3. Persistence bütün satırları aynı coldstart parser'ından geçirir; okunamaz satırı eski journal'a dokunmadan reddeder.

Önceden okunabilir121 karakter gibi legacy taslaklar silinmez; formda düzeltilebilir. Reader'ın eski5000/20000 sınırı daraltılmadı. Önceden zaten bozuk ham veri de otomatik temizlenmez; açık hata ve ham veri korunur. Yeni UI/service artık böyle kayıt üretemez.

Diğer iki gerçek UI bulgusu da düzeltildi: hesap değişiminde tekrarlı route kaldırma ve320 px/2× metinde yeni uzun başlığın taşması. Başlık/içerik beraber kaydırılır; ilgili regresyonlar geçti. Eski genel intro'nun “tam süreyi kullan” ifadesi AYT erken bitişiyle çelişiyordu; yalnız yeni capability açıkken doğru TR/EN açıklaması gösterilir.

## Koşulan doğrulamalar

| Kontrol | Sonuç | Kanıt ve sınırı |
|---|---|---|
| İlgili22 Flutter dosyası | **113/113 PASS** | [Tam dar regresyon günlüğü](kanit_exam32_native_2026-10-28/android/client_validation/exam_and_locale_113.log); bütün proje testleri yerine geçmez. |
| Yeni model/service/widget grubu | **35 test** |19 service/model/disk,16 widget; yukarıdaki113'e dahildir, ayrıca toplanmaz. |
| Dar analiz | **10 dosyada temiz** | [Analiz](kanit_exam32_native_2026-10-28/android/client_validation/analyze.log). |
| Root'un mahremiyet testi | **7/7 PASS** | [Ayrı günlük](kanit_exam32_native_2026-10-28/android/client_validation/privacy_7.log); title/note/details payload'larının telemetriye girmemesi.113'e dahil değildir. |
| İzole nihai SQL | **104/104 PASS** | [Sunucu arşivi](kanit_exam32_2026-10-28/INDEX.md); kontrollü timestamp fixture'ları, doğal90 dk testi değildir. |
| Sunucu altyapı/güvenlik | **33/33 ve 5 HTTP kontrolü** | Aynı sunucu arşivi; native UI veya canlı hizmet kanıtı değildir. |
| Android a3 | **PASS, exit 0** | [Taşınabilir kaynak/hash kanıtı](kanit_exam32_native_2026-10-28/android/a3/proof.json), [native günlük](kanit_exam32_native_2026-10-28/android/a3/native.log). |
| Android bağımsız SQL | **21/21 PASS** | [Son SQL sonucu](kanit_exam32_native_2026-10-28/android/a3/independent_sql.json). |
| Android son parite | **5/5 PASS** | [Parite günlüğü](kanit_exam32_native_2026-10-28/android/verification/a3_parity.log). |
| iOS a1 | **Koşu FAIL** | TR/EN erken bitiş,details,duplicate,report adımları geçti; final normal-start bildirim izin penceresinde kaldı. Root izin verdi. Bütün koşu PASS diye sunulmaz. |
| iOS a2 | **PASS, exit 0** | [Native günlük](kanit_exam32_native_2026-10-28/ios/a2/native.log), [kaynak/hash kanıtı](kanit_exam32_native_2026-10-28/ios/a2/proof.json); root'un koşusu, arşivleyicinin cihaz müdahalesi yok. |
| iOS bağımsız SQL | **21/21 PASS** | [Salt okunur son kontrol](kanit_exam32_native_2026-10-28/ios/a2/independent_sql.json). |

Yeni testler: sınır/+1/emoji ve aşırı yapıştırma;250 msautosave; kapat/aç ve coldstart; diğer valid kayıtların korunması; eski bozukraw'ın silinmemesi; offline değişmez zarf; duplicate/lostACK; owner değişimi; eski revision; modül kapsamı; metadata-only7 tür×2 dil; küçük dikey/yatay ve2×yazı; eski capability ve intro.

## Android doğal native sonuç

A3 testinde mevcut tek `emulator-5554` kullanıldı; wipe/uninstall yapılmadı. API yalnız final review clone'una54351, host54369. Başta exactDB adı, boş yeni QA owner ve cihazda önceki aktif/pending iş bulunmadığı doğrulanır.

Türkçe AYT **5 gerçek saniyede**, İngilizce **6 gerçek saniyede** erken tamamlandı. Her ikisinde planlanan 10800 sn korundu; rapor dakikası0 oldu. Matematik+Fen80/160 seçildi; matematik25/4/11 ve fizik10/1/3 tekSave ile kaydoldu; diğer derslere uydurma sonuç yazılmadı. Başlık/not ve metadata revision1 doğrulandı. Aynı patch'in revision0 tekrarı ve early RPC tekrarı duplicate döndü; ek ödül/revision oluşmadı. Rapor deneme sayısı1→2, normal seans0. Sonra gerçek normal odak UI'den başlatılıp yalnız tamamlanmamış QA odak sıfırlandı.

Bağımsız SQL gerçek timestamp farkları, planned/actual, floor dakikalar, kapsam/netler, başlık/not,0 normal cüzdan etkisi ve 0 seri katkısını 21 kontrolde doğruladı. Bu çok kısa native tur pozitif 90 dk ödül miktarının doğal doğrulaması değildir;90 dk→87 kum ve eski snapshot→3 kum kontrollü SQL testindedir.

Başarısız ve önceki turlar korunur:

- **a1 FAIL:**10.0.2.2 Host başlığı gateway'de403 foreign_host aldı; build başarılıydı, signup öncesi kaldı. ExactQA hesabı0 doğrulandı. API allowlist gevşetilmedi; adb reverse+127.0.0.1 ile düzeltildi.
- **a2 PASS:** P1 öncesi native baz çizgi; TR 6 sn/EN 5 sn ve bağımsız 21/21. Önceki owner'ın 2 completed kaydı, metadata revision'ları ve 8 PNG'si korundu.
- **a3 PASS:** P1 ve intro düzeltmesi sonrası son native sonuç; yeni owner, önceki owner korunmuş olarak doğrulandı.

A3'te doğrudan görüntülenen ENrunning ve ENdetails, doğru erkenbitirme açıklamasını ve14/120 başlık–22/2000 not sayaçlarını gösterdi; bu iki görüntüde klavye/taşma yok. A2'de TRform ve ENrunning/history/report ayrıca incelendi. History'deki beklenen başarı toast'ı gizlenmedi. Görülmeyen tüm görüntüler için ayrı görsel inceleme iddiası yapılmaz.

## iOS son native sonucu

Root'un a2 koşusu iOS 18.6 QA iPhone 16'da exit 0 ile tamamlandı. Türkçe ve İngilizce AYT'nin her biri 5 doğal saniye, planlanan 10800 sn ve 0 rapor dakikası verdi. Aynı modül/net/başlık/not/duplicate/history/report akışı ve son normal odak başlatma–iptal adımı geçti. Bu raporu yazan ajan cihazı tekrar çalıştırmadı; root'un native günlüğünü arşivledi ve exact `e2e-sim-exam32-ex32-ios-a2` sahibini final DB'de salt okunur21 kontrolle bağımsız doğruladı.

Önceki iOSa1 son adımda FAIL kaldı. Saklanan görüntüde iOS bildirim izni penceresi doğrudan görüldü; root izin verdikten sonra yeni a2 turu başarılı oldu. A1 ve A2 sekizer PNG, a1 izin görüntüsü, native günlükleri ve a2 SQL ayrı klasörlerdedir. [iOS arşiv indeksi](kanit_exam32_native_2026-10-28/ios/INDEX.md).

## Arşiv ve kalan sınırlar

[Android arşiv indeksi](kanit_exam32_native_2026-10-28/android/INDEX.md) ve manifest kaynak/çıktı hash'lerini içerir. A2 ve A3 görselleri ayrı klasörlerde tutulur. Secrets, `.env`, ham prefs, token, sertifika, derleme paketi veya tüm Xcode/Gradle verbose çıktısı eklenmez.

Son iOS/Android kısa native akışları geçti; bu, bütün uygulama özelliklerinin veya her gerçek süre kombinasyonunun yeniden çalıştırıldığı anlamına gelmez. Fiziksel cihazlar, gerçek e-posta teslimi, mağaza imzalama/yayın, canlı migration ve operasyonel kill-switch yönetimi bu yerel 32 paketinin dışında kalır. Başka onaylı 31 veya canlı deploy yapılmadı.
