# Saat dilimi değişimi ve 04:00 sınırı — kapsam incelemesi

28 Ekim 2026. Salt okunur kaynak/kanıt incelemesi; yeni ürün davranışı, veritabanı işlemi veya native koşu yapılmadı. Aşağıdaki saat dönüşümü ayrıca Python `zoneinfo` ile doğrulandı; bu, uygulama E2E testi değildir.

## Sonuç

**Sabit profil saat diliminde 04:00 hesabının kanıtı var. Kabul edilmiş geçmiş varken profil saat dilimi değişiminin uçtan uca tutarlılığı kanıtlanmış değil.** Kaynakta iki farklı yaklaşım birlikte bulunuyor: raporlar geçmişi güncel profil diliminde yeniden grupluyor; yeni lig olayları kabul anında hesaplanan `study_day` değerini saklıyor. Seyahatte geçmişin hangi güne ait kalacağı açık bir ürün sözleşmesine bağlanmalı. Bu inceleme toplam sürenin/ödülün kaybolduğunu veya bir çökme yaşandığını göstermez.

## Doğrulanan kod yolları

| Alan | Mevcut davranış ve kaynak |
|---|---|
| Profil dilimi | [`_syncProfileTimeZone`](../lib/services/supabase_service.dart), satır 1212–1253: native IANA adı kendi `profiles.timezone` alanına yazılır; başarısızlıkta mevcut dilim korunur. Kullanıcı bildirimi etkin `study_day` dilimini değiştirir (aynı dosya, satır 77). Kabuk ön plana dönüşte senkronu çağırır ([`main_shell.dart`](../lib/app/main_shell.dart), satır 161). |
| Normal/Maraton geçmiş API’si | [`get_my_study_sessions_v2`](../supabase/proposed/28_exam_core.sql), satır 190–201: kendi `study_sessions` satırı, tür ve Maraton metaverisi döner. Seans şemasında ayrı kabul günü/dilimi yoktur ([yerel şema](../tool/local_supabase/supabase/migrations/20261004120000_live_snapshot.sql), satır 131–144). |
| Normal/Maraton rapor günü | [`StudySession.studyDay`](../lib/models/study_session.dart), satır 69: başlangıç anını `studyDayOf` ile hesaplar; modelde kayıt anının dilimi yoktur. [`StatSession.fromStudySession`](../lib/utils/stats_calculator.dart), satır 52 ve kuyruk dönüşümü güncel etkin dilimi kullanır. Maraton plan adedi bitiş gününe, her odak süresi kendi başlangıç gününe yazılır. |
| Deneme geçmiş API’si | [`_exam_payload` / `get_my_exam_attempts`](../supabase/proposed/28_exam_core.sql), satır 63–72 ve 180–188: başlangıç/bitiş, durum, süre, ödül ve ders/net bilgileri döner; kabul günü/dilimi dönmez. `exam_attempts` tablosu ve [`ExamAttempt`](../lib/models/exam_model.dart), satır 207 sonrası, bu alanları saklamaz. |
| Deneme rapor günü | [`StatSession.fromExamAttempt`](../lib/utils/stats_calculator.dart), satır 102: yalnız tamamlanan kaydı alır; `startedAt` gününü güncel/isteğe bağlı profil diliminde hesaplar. [`reports_screen.dart`](../lib/screens/reports_screen.dart), satır 293–305 ve 491–494: normal geçmişi yeniden dönüştürür ve Denemeyi etkin dilimle birleştirir. Dilim senkronu istatistik yenilemesi tetikler. |
| Sunucu seri ve lig günü | Deneme tamamlama güncel profil diliminde başlangıç gününü hesaplayıp `last_study_date`/seriyi günceller ([paket 28](../supabase/proposed/28_exam_core.sql), satır 151–159). Normal tamamlama aynı kuralı kullanır ([kaynak](../supabase/migrations/20261003150000_live_audit_fixes.sql), satır 245–275). [`_competition_record`](../supabase/proposed/29_monthly_competitions.sql), satır 78–95, kabul anındaki günü `competition_events.study_day` olarak saklar; aynı olay güncellemesinde yalnız puan değişir. Terfi için gün adedi bu sabit olay günlerinden sayılır. |

## Kaynaktan çıkan somut seyahat örneği

Başlangıç anı `2026-10-28T01:30:00Z` olan kabul edilmiş bir seans düşünelim:

| Profil dilimi | Başlangıcın yerel karşılığı | 04:00 çalışma günü |
|---|---|---|
| Kabul sırasında `Europe/Istanbul` | 28 Ekim 04:30 | 28 Ekim |
| Sonradan `America/New_York` | 27 Ekim 21:30 | 27 Ekim |

Normal/Maraton ya da tamamlanmış Deneme raporu yeniden yüklendiğinde kayıt 27 Ekim’e gruplanabilir. Daha önce kabul edilmiş lig olayında 28 Ekim kalır. `last_study_date` de yalnız saat dilimi güncellendi diye yeniden hesaplanmaz; [`effectiveStreak`](../lib/utils/study_day.dart), satır 116 sonrası, bu saklı tarihi yeni dilimdeki bugün ile karşılaştırır. Ay sınırına yakın benzer kayıtta rapor ayı da değişebilir. **Bu örnek mevcut kodun çıkarımıdır; yerel DB/native üzerinde seyahat senaryosu olarak koşulmadı.**

Çevrimdışı kayıt da başlangıç anını ve saat düzeltmesini saklar, kabulde kullanılacak profil dilimini dondurmaz. Bu nedenle ağ kesintisi sırasında dilim değişimi, geçmiş kabulden sonra dilim değişimiyle ayrı sınanmalıdır. Lig ayının İstanbul 00:00 olması ise tasarlanmış başka bir kuraldır; raporun 04:00 ayıyla aynı olması beklenmez.

## Mevcut kanıtın sınırı

- [`study_day_test.dart`](../test/study_day_test.dart): `04:00 öncesi bir önceki güne sayılır`, `04:00 ve sonrası aynı gün`, `ay ve yıl sınırında takvim aritmetiği`, `yaz saati geçiş günlerinde gün kayması yok`, `gün cihazın değil profilin diliminde hesaplanır`. Sabit dilim ve açık anların takvim hesabıdır.
- [`unified_study_stats_test.dart`](../test/unified_study_stats_test.dart): `exam start before 04:00 stays in previous working month; marathon completion uses end working day`, `New York repeated DST hour and 04:00 use profile timezone rather than device zone`, `offline normal and marathon outbox deduplicate against server and never complete a run early`. Karışık normal/Maraton/Deneme, ay, DST ve kuyruk hesabı kontrollü verilerle sınanır; kabul edilmiş geçmişle dilim değiştirme yoktur.
- [`l_followup_management_test.dart`](../integration_test/l_followup_management_test.dart): yeni/çalışma geçmişi olmayan hesapta gerçek native IANA okuması; ardından taklit kanal üzerinden New York profil senkronu ve geçersiz dilimin reddi. Gerçek seyahat veya geçmişin yeniden gruplanması testi değildir.
- [`overnight_transition_metadata.py`](../tool/local_supabase/e2e/overnight_transition_metadata.py): mevcut [20/20 artefakt](../build/overnight_backend/transition_metadata_results.json) kontrollü Denemeyi **02:30–03:50** aralığına koyar; `exam_workday_before04_is_yesterday` bunu önceki güne atar. Sonraki 05:00 Pomodoro ile iki günlük seri ve ayrı cüzdanlar doğrulanır. Denemenin kendisi 04:00’ü geçmez. Yanlış “spanning” yorumu bu incelemede düzeltildi; senaryo veya sonuç değiştirilmedi, yeniden koşturulmadı.
- [H18 bağımsız final artefaktı](../build/overnight_backend/first_use_ios18_final.json), `proof`: `night-first-ios18-h1`, gerçek **1503 duvar saniyesi**, 03:44:57–04:09:57 İstanbul, `crossed_04_boundary=true`, `study_day=2026-10-27`; `independent_verified` sonucu ve SQL olay günü bunu destekler. Bu gerçek **normal 25 dakika** sınır kanıtıdır; Deneme, ay değişimi veya seyahat kanıtı değildir.

Bu turda yeni Flutter, SQL veya native test koşulmadı. Mevcut başarılı sonuçların tamamı burada yeniden yürütülmüş gibi sunulmamalı.

## Güvenli politika seçenekleri ve gerekli regresyon

1. **Kabul gününü korumak:** normal/Maraton ve Deneme için sunucuda kabul edilmiş çalışma günü/dilimi saklanır, API rapora aynı günü verir; eski veri için açıklanmış geri doldurma kuralı gerekir. Saat dilimi değişimi yalnız sonraki kabulleri etkiler. Lig günleri ve rapor geçmişi birlikte tutarlı tutulabilir; seri geçişinin davranışı ayrıca belirlenmelidir.
2. **Geçmişi güncel dilimde yeniden yorumlamak:** raporun mevcut davranışı açıkça korunur; lig yeterlilik günleri ve seriyle olan fark ya sözleşmede açıklanır ya da sunucuda tek bir yetkili kurala taşınır. Ödül/lig geçmişi kendiliğinden yeniden yazılmamalıdır.
3. **Lig dönemi boyunca sabit hesap dilimi:** cihaz dilimi ayrı tutulur; çalışma muhasebesi dönem diliminde sürer. Dönem dışındaki değişim ve kullanıcıya gösterimi tanımlanmadan uygulanmamalıdır.

Bu seçeneklerden biri kullanıcı kararı olmadan seçilmedi. Karar sonrası anlamlı test: aynı hesapta kabul edilmiş normal + bitmiş Maraton + tamamlanmış/vazgeçilmiş Deneme + gönderilmemiş kuyruk kaydı oluştur; İstanbul→New York→İstanbul değiştir; API, günlük/haftalık/aylık rapor, seri ve `competition_events` günlerini seçilen sözleşmeye göre karşılaştır. Tamamlama öncesi/sonrası değişim, 04:00, ay sınırı ve yeniden gönderim ayrı dallar olmalı; UUID ve ekonomi tekliği her dalda korunmalı. Şimdiden bir seçeneği başarı ölçütü yapan test eklemek ürün kararını gizlice belirlerdi; eklenmedi.

## I-16…I-19 doğrulama matrisine aktarılacak notlar

- **I-16:** hedef/Global kapsamın ayrı 46/46 kanıtı korunur. Seyahat sonrası terfi gün sayısı ayrı politika boşluğudur; oda/Global ayrımı testleri bunu kanıtlamaz.
- **I-17:** rehberin iki dilde sayfa/boyut testleri karşılama anlatımını kanıtlar; tarih muhasebesini kanıtlamaz. Ürün kararı verilirse rehber açıklaması onunla uyumlu olmalıdır.
- **I-18:** ARB anahtar/eşleşme, görünür sabit metin taraması ve katalog çeviri testleri dil kapsamıdır; saat dilimi seyahati testi değildir.
- **I-19:** 340 dakika model verisi ve W’nin 430 dakikalık toplamı (405 kontrollü geçmiş + 25 gerçek dakika) bu ayrımla kalmalı. H18 artık normal odağın gerçek 04:00 geçiş kanıtıdır. Denemenin 02:30–03:50 fixture’ı “04:00’ü geçen Deneme” diye yazılmamalı. Profil dilimi değiştikten sonra kabul edilmiş geçmişin rapor/seri/lig tutarlılığı **bekleyen politika ve test** olarak belirtilmeli; “tüm saat dilimi/seyahat senaryoları geçti” denmemeli.
