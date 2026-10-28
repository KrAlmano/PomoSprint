# DUS ve sekiz sınav ödülü — istemci/native kontrolü

28 Ekim 2026. Çalışma yalnız yerel kod ve `pomosprint_review32_dus` kopyasında yapıldı. Canlı SQL, deploy, mağaza yüklemesi, commit/push veya fiziksel cihaz işlemi yapılmadı. Önceki yedi sınavlı/175 kumlu testlerin tarihî kayıtları değiştirilmedi; aşağıdaki tablo yeni istek içindir.

## Güncel referans

| Sınav | Tam süre puanı | Tam süre deneme kumu |
|---|---:|---:|
| LGS Sözel |15|60|
| LGS Sayısal |16|70|
| YDT |24|95|
| TUS Temel |27|110|
| TUS Klinik |27|110|
| DUS |30|120|
| TYT |33|130|
| AYT |36|145|

İstemci referansı `lib/models/exam_reward_policy.dart` içindeki tek tablodur. `ExamDefinition`, sunucudan gelen ödül alanlarını ve policy sürümünü saklar; eski veya açıkça0 olan snapshot'ı güncel varsayılanla ezmez. Geçmişte kazanılan ödülün gösterimi kabul edilen attempt makbuzundan yapılır. AYT90 dakika referansı72 kum/18 puandır;1–59 saniye0. Buradaki90dk miktarı doğal90dk native denemesi değildir.

DUS tanımı150 dakika,120 soru ve16 alandır: ilk8 alan40, son8 alan80 soru. `lib/models/dus_catalog.dart`, soru yapısını ve DUS kategori adlarını tek yerde tutar. Fizyoloji ile Histoloji/Embriyoloji DUS'ta ayrı kategori; TUS'un birleşik kategorisi korunmuştur. Kaynak eşleşmesi [sunucu katalog JSON'u](../supabase/proposed/exam_catalog_32.json) ile test edildi.

## İstemci kapsamı

- Onboarding'de TUS ardından DUS var.16 öneri gösterilir, mevcut ücretsiz8 seçim sınırı korunur. TR/EN eşlemesi, kategori adı eşleştirmesi ve uzun adların dar ekranda görünümü test edildi.
- Eski sunucu DUS hedefini CHECK ile reddederse seçim UID'ye bağlı bekleyen niyette korunur; diğer profil tercihleri kaybolmaz. Sunucu sonradan desteklerse bir kez yeniden uygulanır. Başka owner veya önceden kabul edilmiş non-null hedef üstüne yazılmaz.
- LGS/YKS/TUS/KPSS/dil/üniversite/iş/diğer hedefleri çıkarılmadı. Lig hedefleri DUS'u tanır. Sosyalin genel deneme durumu DUS için de TR/EN “Denemede / Taking an exam” verir.
- Sınav filtreleri sunucuda mevcut ailelerle All → YKS → LGS → TUS → DUS sırasındadır. Eski sunucuda bulunmayan aileye boş çalıştırma düğmesi eklenmez.
- İngilizce “Unanswered” etiketi tek satıra sığdırılır; üç alanın etiket yüksekliği aynı tutulur. Dar ekran ve2× metin testi, giriş kutularının üst hizasının aynı olduğunu doğrular.

## Gerçekten koşulan kontroller

| Kontrol | Sonuç | Kanıt |
|---|---|---|
| Genişletilmiş ilgili Flutter grubu | **164/164 PASS** | [Günlük](kanit_dus_native_2026-10-28/android/verification/client_tests_164.log) |
| Dar istemci/native kaynak analizi | **16 dosya temiz** | [Analiz](kanit_dus_native_2026-10-28/android/verification/client_analyze_16.log) |
| AI resmî DUS Android TR/EN | **PASS, exit0** | [Native günlük](kanit_dus_native_2026-10-28/android/official/native.log) |
| AI bağımsız salt okunur SQL | **14/14 PASS** | [SQL sonucu](kanit_dus_native_2026-10-28/android/official/independent_sql.json) |
| AH güncel8katalog/AYT Android TR/EN | **PASS, exit0** | [Native günlük](kanit_dus_native_2026-10-28/android/ayt/native.log) |
| AH bağımsız salt okunur SQL | **17/17 PASS** | [SQL sonucu](kanit_dus_native_2026-10-28/android/ayt/independent_sql.json) |
| Son Android tam katalog/schema/policy paritesi | **5/5 PASS** | [Parite](kanit_dus_native_2026-10-28/android/verification/full_catalog_parity.log) |
| iOS resmî DUS TR/EN | **PASS** | [Native günlük](kanit_dus_native_2026-10-28/ios/official/native.log); SQL14/14, bağımsız oracle56/56. |
| iOS kontrollü60sn DUS TR/EN | **PASS** | [Native günlük](kanit_dus_native_2026-10-28/ios/short/native.log); SQL18/18, bağımsız oracle94/94. |
| iOS kısa katalog geri alma | **Exact restore ve5/5 parite PASS** | [Koşu durumu](kanit_dus_native_2026-10-28/ios/short/status.json), [son parite](kanit_dus_native_2026-10-28/ios/short/parity-after.log). |

164 sayısı ilgili seçilmiş test dosyalarıdır, bütün projenin tam testi değildir. Sunucu davranış testleri ayrı ajan/root raporundadır; aynı sonucu tekrar bu sayıya eklemeyin.

### AI: resmî DUS

Tek mevcut Android emülatöründe, yeni `dus-android-official-a1` hesabıyla iki dilde DUS açıldı.9000sn/120soru/16alan ve tam30/120 referansı görüldü. Sayaç gerçek3saniye yürüdü; erken bitir ve duraklat kontrolleri bulunmadı. Kullanıcı arayüzünden vazgeçildi; iki kayıt geçmişte kaldı, puan/kum/rapor süresi0 oldu. SQL, DUS profil hedefini, iki terminal kaydı, değişmeyen tam snapshot'ı ve normal/deneme cüzdanlarının etkilenmediğini doğruladı.

Bu test150 dakika beklemedi; tam DUS tamamlama ödülünü doğal süreyle doğruladığı iddia edilmez. Tam150dk/30/120 makbuzunun istemci davranışı model/service testinde, sunucu davranışı ayrı kontrollü SQL testindedir.

### AH: yeni tabloyla AYT

Yeni `ex32-dus-android-a1` hesabında8 sınavın her birinin server tam ödülü merkezi tabloyla eşleştirildi. Türkçe ve İngilizce AYT ayrı ayrı5 doğal saniyede erken tamamlandı; planlanan10800sn korundu,0rapor dakikası/0ödül oluştu. İki modül, iki kısmi net satırı, başlık/not tek atomik Save ile revision1 oldu. Tekrar Save ve tamamlama istekleri duplicate döndü. Rapor1→2deneme gösterdi. Son olarak normal odak UI'den başlatılıp yalnız tamamlanmamış QA odağı sıfırlandı.

Bağımsız SQL, iki AYT kaydının dondurulmuş tam ödülünün36/145 olduğunu ayrıca doğruladı. Böylece önceki175 tablosu yanlışlıkla kullanılmadı.5saniyelik0ödül,72kumluk90dk sonucunun doğal testi olarak sunulmaz.

## 60 saniyelik DUS modu ve devam durumu

`integration_test/ai_dus_native_test.dart` aynı dosyada `E2E_DUS_SHORT=true` modu içerir. Bu mod reset/hesap açmadan önce yalnız izole DUS kataloğunda60sn/0puan/0kum olduğunu doğrular; kalan yedi ödül tablosu aynı kalmalıdır. İki doğal60sn tamamlama,16alanlı formda kısmi net/başlık/not, duplicate ve günlük rapor1→2adet/1→2dk test edilir. Test kendi içinde katalog/SQL/saat değiştirmez; hazırlama ve finally birebir geri alma root'a aittir.

Android'de kısa DUS modu çalıştırılmadı. Root iOS'ta hem resmî başlangıç/vazgeçme hem de iki doğal60sn kontrollü tamamlama turunu başarıyla çalıştırdı. Kısa turda her dilde2kısmi net satırı, başlık/not, revision1, duplicate ve rapor1→2adet/1→2dk geçti. İstemci ajanı bu sırada cihazı kontrol etmedi; kayıtları sonradan yalnız okuyarak doğruladı.

`--profile review` bağımsız oracle, resmî DUS hesabında56/56 ve kısa DUS hesabında94/94PASS verdi; uyarı yoktu. Ek sabit sorgular resmî hesapta14/14, kısa hesapta18/18 geçti. Kısa hesabın iki kaydında snapshot60sn/0puan/0kum olarak kaldı; güncel katalog ise yeniden9000sn/30puan/120kumdu. Profil2dk ve1çalışılmış gün gösterdi, her iki cüzdan0kaldı. Böylece kısa test sonrasında veriye yeni standart120kum yazılmadığı da doğrulandı.

Kısa turdaki1dakika/0ödül, standart150dakika/120kumun doğal tamamlanma kanıtı değildir. Root'un finally dönüş durumu `catalog_restored_exact=true`; son parite5/5PASS. [iOS arşivi](kanit_dus_native_2026-10-28/ios/INDEX.md)16PNG, günlükler, katalog snapshot'ı, parite ve iki oracle'ı ayrı tutar.

## Görsel kontrol ve arşiv

Doğrudan açılan üç yeni Android kare: DUS katalog EN, DUS çalışan sayaç EN, AYT ayrıntı formu EN. DUS adları/150dk/120soru okunaklıdır; sayaç2:29:57 ve erken bitir düğmesinin yokluğu görünür. Formda “Unanswered” tek satır, doğru/yanlış/boş girişleri hizalıdır. Görülmeyen kalan kareler için ayrı görsel inceleme iddiası yoktur.

[Android kanıt indeksi](kanit_dus_native_2026-10-28/android/INDEX.md), `manifest.json` ve `proof.json` kaynak hash'lerini, native sonuçları ve14PNG'yi taşınabilir olarak korur. Secrets/ortam dosyaları/ham prefs/derleme paketleri arşive alınmadı. Özel QA kullanıcıları korunmuştur; sessiz veri sıfırlaması yapılmadı. iOS kısa turdan doğrudan açılan ENhistory ve ENdetails karelerinde1dakika/0ödül, iki dilde girilmiş kullanıcı başlıklarının korunması ve doğru7/2/1=6,50 net görüldü. “Unanswered” tek satırdı; kayıt sonrası başarı snackbar'ı beklenen şekilde vardı, klavye yoktu.
