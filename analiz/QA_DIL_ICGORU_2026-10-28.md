# TR/EN ve süre–net bağımsız kaynak incelemesi — 28 Ekim 2026

Bu tur I-18 yerelleştirme ve I-07 içgörü akışını yeniden okur. Başlangıçta `DENETIM.md` okundu; denetçinin 23:48 turunda D-01…D-05 kapalıdır. İnceleme anındaki HEAD `f82f999` idi. Aşağıdaki yeni ekran düzeltmesi bu belge hazırlanırken henüz ayrı commit'e alınmamıştı.

**Yeni iki yürütme yolu hatası bulundu ve düzeltildi.** Yeni dil/ürün özelliği eklenmedi, süre/puan/ekonomi kuralları değiştirilmedi. Canlı servis, fiziksel cihaz ve native kayıt bu incelemenin kapsamında değildir.

## 1. Okunamayan çalışma geçmişinin 0 dakika sayılması

Üretim yolu: `MainNavigationShell`, Deneme ekranına gerçek `fetchStudySessions` yükleyicisini verir. [ExamScreen._loadStudies](../lib/screens/exam_screen.dart:104) önceki halinde istisnayı yutuyordu. İlk istekte hata olursa `_studies=[]` kalıyordu. İki geçerli Deneme sonucu bulunduğunda [içgörü görünümü](../lib/screens/exam_screen.dart:447) bu okunmamış veriden “İlişkili çalışma kategorilerinde 0 dk” çıkarıyordu. Sunucuda sıfır çalışma olduğuna ilişkin kanıt yoktu.

Cache önceden dolmuşsa sayılar korunuyordu, fakat yenilemenin başarısız olduğu belirtilmiyordu. Bu ikinci görünüm sayısal kayıp yaratmıyordu; veriyi güncelmiş gibi gösteriyordu.

Düzeltme:

- İlk başarılı çalışma okumasına kadar sayısal içgörü hesaplanmaz; başarısızlıkta mevcut iki dilli `statsLoadErrorGeneric` ve `examRetry` gösterilir.
- Önceki başarılı çalışma geçmişi varsa korunur; mevcut `statsStaleNotice` ile eski veri olduğu açıklanır.
- Başarılı tekrar, eski veri uyarısını kaldırır ve içgörüyü yeni çalışma toplamından hesaplar.
- İlk okuma eksikken “karşılaştırma için iki sonuç gerekir” boş durumu da yanlış açıklama olarak gösterilmez.

## 2. Eski çalışma yanıtının yeni toplamı ezmesi

Üretim yolu: ilk ekran yüklemesi çalışma geçmişini okurken kullanıcı Denemelerim'e geçebilir veya yenileyebilir. İki `_loadStudies` isteği aynı hesap için çakışabiliyordu. Önceden yalnız hesap kimliği kontrol ediliyordu; ikinci isteğin güncel 100 dakikası göründükten sonra ilk isteğin eski 50 dakikası gelirse görünür toplam geri gidiyordu.

Düzeltme: her isteğe artan bir sürüm verilir; yalnız aynı hesap ve en yeni istek sonucu uygulanır. Hesap değişimi bu sürümü artırıp yüklenmiş/eski veri durumunu temizler. Gecikmiş başarısızlık da başarılı yeni sonucu eski olarak işaretleyemez. Veri kaynakları veya hesap sahipliği sözleşmesi değiştirilmedi.

## 3. Gerçek FAIL → PASS kanıtı

Yeni [exam_insights_loading_test.dart](../test/exam_insights_loading_test.dart) sahte backend ve sabit saatle gerçek `ExamScreen` widget'ını çalıştırır:

| Regresyon | Önce | Sonra | Kanıtlanan |
|---|---|---|---|
| İlk çalışma okuması ağ hatası | FAIL: ekranda yanlış 0 dakika bulundu | PASS | Bilinmeyen çalışma toplamı sıfır gibi gösterilmiyor; hata açıklanıyor |
| Eski yavaş istek, yeni istekten sonra geliyor | FAIL: güncel 100 dakika kayboldu | PASS | Eski 50 dakika yanıtı güncel toplamı ezmiyor |
| Cache varken yenileme hatası, TR→EN ve retry | FAIL: eski veri uyarısı yoktu | PASS | 50 dakika korunuyor; uyarı ve Fizik/Physics ile ondalık ayırıcı dil değiştiriyor; retry 75 dakikayı gösterip uyarıyı kaldırıyor |

Günlükler:

- İlk iki hatanın keşfi: `/tmp/pomosprint_insights_loading_before.log`.
- Üç regresyonun düzeltme öncesi sonucu: `/tmp/pomosprint_insights_loading_before_3.log`, **0 geçti / 3 başarısız**.
- Düzeltme sonrası: `/tmp/pomosprint_insights_loading_after.log`, **3/3 geçti**.
- Etkilenen ekran/kategori eşlemesi ile dar tekrar: `/tmp/pomosprint_insights_loading_related.log`, **11/11 geçti**. Bu sayı önceki 3 testi içerir; sayılar toplanmaz.
- `dart analyze lib/screens/exam_screen.dart test/exam_insights_loading_test.dart`: temiz. `git diff --check`: temiz.

Genel Flutter turunu ve native ekran kontrolünü ana ajan ayrıca yapar. Bu 11 test tüm uygulamanın veya doğal süreli bir Deneme'nin başarı sonucu değildir.

## 4. TR/EN kaynak kontrolünde doğrulanan yollar

Bu bölüm kaynak okumasıdır; önceki tüm testlerin bu tur tekrar çalıştırıldığı iddia edilmez.

- Sınav ve ders adı [ExamDefinition/ExamSubject](../lib/models/exam_model.dart:25) üzerinden iki ayrı dil alanıyla gelir. Boş veya yalnız boşluk içeren ad kabul edilmez. Ekranlar aktif locale üzerinden `name(...)` çağırır; ham sınav kimliği kullanıcı adı yerine gösterilmez.
- Lig kademeleri [league_tiers.dart](../lib/widgets/social/league_tiers.dart:10) içindeki ARB adlarına bağlanır. Hedefler doğrulanan enum kümesinden alınır ve `competitionTargetLabel` ile yerelleşir. İsim olarak ham `work`/`language` gibi hedef enum'u gösteren yeni yol bulunmadı.
- Bilinen çalışma kategorileri [category_names.dart](../lib/utils/category_names.dart:57) ile Türkçe/İngilizce ve boşluk/büyük-küçük harf eşlemesi kullanır. Kullanıcının özel adı çevrilmez veya hayalî derse bulanık eşlenmez.
- Avatar kataloğunda iki dilde dolu ad gerekir; bilinen eski avatarın eksik adı yerel katalogdan tamamlanır. Bilinmeyen eksik çeviri sessiz teknik kimlikle gösterilmez. Lig ödül adları iki dilde tutarlıdır.
- Deneme boş/hata/terminal durumları, net başlıkları ve yeni içgörü hataları ARB'den gelir. Yeni uyarı için ARB anahtarı veya üçüncü dil eklenmedi. TR netleri virgül, EN netleri nokta kullanır.

## 5. Yeterli karşılaştırmalı veri ve sınırlar

[buildExamTimeInsights](../lib/models/exam_insights.dart:23) son 21 gün içindeki tamamlanmış kayıtları; aynı sınav, katalog sürümü, ders ve soru toplamıyla gruplar. En az iki geçerli ders sonucu ve başlangıçlar arasında en az bir gün gerekir. Vazgeçilen, gelecekteki, aynı günkü veya farklı sürümlü kayıtlar karşılaştırma oluşturmaz. Eşleşen çalışma bir kez sayılır; aynı kategori iki dersin bağlamı olduğunda toplam çalışma süresi artırılmaz. Kaynak, yerleştirme puanı veya nedensellik hesaplamaz.

Sıfır çalışma **başarılı okuma sonrasında** gerçek bir sonuç olabilir; bu politika korundu. Hata, okunamamış geçmişi sıfır sanmaktı. Küçük Stajlar'a uydurma soru payı veya ders eşlemesi eklenmedi. Bu incelemede mevcut yeterlilik/hesaplama algoritması için başka somut kusur gösterilemedi; sırf test sayısını artırmak için yeni örnek eklenmedi.

Uzak katalog içeriğinin gelecekteki tüm sürümleri, her hata kombinasyonu, cihazda ekran okuyucu kullanımı veya gerçek bildirim teslimi bu kaynak incelemesiyle kanıtlanmaz. Önceki genel literal tarayıcısı da tam veri akışı analizi değildir.
