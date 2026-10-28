# Deneme ve aylık lig sözleşmesi — 28 Ekim 2026

Bu sözleşme yalnız hazırlanmış yerel paket içindir; canlıya uygulanmadı. Sıra: **27 TUS/DUS → 28 deneme çekirdeği → 29 birleşik aylık lig**. Eski sunucuda bulunmayan RPC (`PGRST202`) yeni özelliği kapatır; ağ/yetki hatası başarı veya eski sunucu sayılmaz.

**Bağımsız32 eki:** [AYT erken bitiş ve deneme ayrıntıları](32_exam_details_early_finish_README.md) 27–30 üstünde,31 kurulmadan doğrulandı. Aşağıdaki çekirdek davranış korunur;32 varsa capability ile açılan yeni alan/işlemler aşağıda eklenir. Canlıda bulunmuş sayılmaz.

## Deneme

- `get_exam_config()` → `{schema_version:1,available:true,server_time,exams:[...]}`. Her sınav: `id`, `name_tr`, `name_en`, `segment`, `group`, `duration_seconds`, `total_questions`, `wrong_answer_divisor`, `catalog_version`, `subjects:[{id,name_tr,name_en,question_count,category_keys:[]}]`.
- `start_exam_attempt(p_client_uuid uuid,p_exam_id text)` → `{server_time,duplicate,attempt}`. Süre ve başlangıç sunucudan; istemci 3-2-1 sonrasında çağırır. Aynı owner/UUID aynı sınavı döndürür; başka sınav metadata çatışmasıdır. İstek öncesi UUID cihazda kalıcı tutulur.
- `complete_exam_attempt(p_attempt_id uuid)` → aynı zarf. Tam süre dolmadan `exam_not_elapsed`; ayrı saat, duration veya net kabul edilmez. Başarılı ilk çağrıda ekonomi bir kez yazılır. Duplicate aynı kazanılmış snapshot'ı döndürür; `duplicate:true` yeniden delta ekletmez.
- `abandon_exam_attempt(p_attempt_id uuid)` → aynı zarf. `status:abandoned`, geçen süre sunucuda saklanır; toplam çalışma, seri, normal/deneme puanı ve kum katkısı **sıfırdır**. Daha önce tamamlananı geriye alamaz. Tam süre dolmuş aktif deneme tamamlamaya yönlendirilir.
- `get_my_exam_attempts(p_limit integer DEFAULT 100,p_before timestamptz DEFAULT NULL)` → `{server_time,attempts:[]}`. Limit 1–1000; `next_cursor` son satırın başlangıcıdır. İlk sayfada aktif kayıt en üstte ve limit içine kesin alınır. Diğerleri başlangıç azalan. Sahip dışı kayıt yoktur.
- `save_exam_results(p_attempt_id uuid,p_subject_results jsonb)` → aynı zarf. Dizi girdisi yalnız `{subject_id,correct,wrong,blank}`. Her sayı tamsayı ve ≥0; toplam dersin soru sayısına eşit; bilinmeyen/tekrarlanan ders reddedilir. Gönderilen dersler güncellenir, gönderilmeyenler korunur. Boş dizi değiştirmez. Net sunucuda `correct - wrong / divisor` olarak hesaplanır; negatif net geçerlidir. Netler normal/deneme ekonomisini ve ligi değiştirmez.

`attempt`: `id`, `client_uuid`, `exam_id`, `catalog_version`, `name_tr`, `name_en`, `started_at`, `ends_at`, `completed_at`, `finished_at`, `duration_seconds`, `elapsed_seconds`, `total_questions`, `wrong_answer_divisor`, `status` (`active|completed|abandoned`), `points_earned`, `exam_coins_earned`, `subject_results`, `definition` (sürümü sabit tam katalog), `subjects`. Tüm zamanlar ISO8601 UTC; widget kalan süreyi `ends_at - serverAdjustedNow` ile hesaplar.

Hata kodları PostgreSQL `P0001` mesajında sabittir: `exam_not_elapsed` geçici; `exam_overlap`, `exam_not_active`, `exam_not_found`, `exam_metadata_conflict`, `exam_result_invalid`, `exam_unavailable` kullanıcıya açıklanır. Auth hatası `not authenticated`; başka sahibin UUID'si `exam_not_found` ile ifşa edilmez.

Katalog kimlikleri: `tyt`, `ayt`, `ydt`, `lgs_verbal`, `lgs_quantitative`, `tus_basic`, `tus_clinical`, `dus`; KPSS GY–GK için `kpss_bachelor_gygk`, `kpss_associate_gygk`, `kpss_secondary_gygk`; Alan Bilgisi için `kpss_field_business`, `kpss_field_accounting`, `kpss_field_law`, `kpss_field_public_administration`, `kpss_field_economics`, `kpss_field_finance`, `kpss_field_international_relations`, `kpss_field_labour_economics`, `kpss_field_statistics`. TUS iki ayrı100soru/135dk oturumdur. DUS tek120soru/150dk oturumdur;16ders,40temel/80klinik standart dağılım. LGS iki ayrı oturumdur;45dk ara çalışma veya ödül değildir. KPSS GY–GK130dk/120 sorudur;60 Genel Yetenek ve60 Genel Kültür sonucu girilir. Alan Bilgisi dokuz ayrı40 soruluk testtir; İstatistik60dk, diğerleri50dk. KPSS net böleni4, hedef/grup `kpss`tir. Yaklaşık alt ders ağırlıkları sabit soru kotasına çevrilmez. Katalogdaki standart sınav sayacı resmî standardize sınav puanını hesaplamaz; AGS/ÖABT eklenmez.

## Aylık lig

- `get_monthly_league_ranking(p_kind text DEFAULT 'study',p_scope text DEFAULT 'segment')` → `{schema_version:1,server_time,kind,scope,segment,pending_segment,segment_effective_at,tier,period_start,period_end,competition_phase,room_capacity,rows:[]}`.
- `get_my_exam_league_ranking(p_scope text DEFAULT 'segment')` aynı sözleşmenin `kind:exam` yedeğidir.
- `p_kind`: `study|exam`; `p_scope`: `segment|global`. Segment sunucu sahibinin ay boyunca sabit hedefidir; istemci başka hedef seçemez. Global bütün hedefleri kapsayan sıralamadır; ikinci ödül veya ikinci cüzdan oluşturmaz.
- Satır: `id`, `name`, `avatar_id`, `is_me`, `is_blocked`, `points`, `rank`, `tier`, `promotion_eligible`, `award_eligible`, `demotion_eligible`, `has_league`, `member_count`, `active_member_count`, `end_date`. Eski normal V2 ek `weekly_points` eşdeğer alanını korur.
- `get_competition_target()` → `{current_segment,pending_segment,effective_at}`; `set_competition_target(p_segment text)` aynı cevabı döndürür. Orta ay değişimi bir sonraki İstanbul takvim ayından etkilidir; mevcut puan ve üyelik taşınmaz. İlk seans öncesi onboarding hedefi hemen uygulanır.

Normal lig puanı yalnız Pomodoro/Maraton; deneme ligi puanı tamamlanan denemeden gelir.32 öncesinde yalnız tam süreli;32 ile AYT erken bitişinde gerçek her5 dakikaya1 puan, en fazla snapshot tam puanı. Takvim ayı sınırı `Europe/Istanbul`00:00; çalışma günü/seri04:00. Düşük nüfusta hazırlık/ödülsüz durum; eksik deneme-avatar görseli gerçek ödül gibi gösterilmez.

## Sosyal ve toplamlar

`get_live_friends_with_breaks()` eski sözleşmeye `status:exam`, `exam_type`, `exam_name_tr`, `exam_name_en` ekler. Görünürlük, arkadaşlık, engel filtresi korunur. Gecikmiş normal iptal deneme tablosuna dokunmaz.

Tamamlanan denemeler profil toplam dakikasına ve04:00 serisine eklenir; normal puan/kum değişmez. Raporlar ayrı deneme listesini okur ve yalnız `completed` kayıtları `Deneme` satırında birleştirir.32 öncesinde tam süre,32 erken AYT'de gerçek süre kullanılır.1–59 saniye tamamlanan deneme1 adet,0 dakika ve0 seri katkısı verir. Derslere süre paylaştırılmaz; netler yalnız kişisel rapor/içgörü girdisidir.

## 32: Erken AYT ve özel deneme ayrıntıları

- `get_exam_config().capabilities`: `exam_details`, `ayt_modules_version:1`, `ayt_early_finish`. Eski sunucuda bu alanlar yoktur; yeni düğmeler kapalı kalır.
- `finish_ayt_early(p_attempt_id uuid)` aynı completion zarfını döndürür. Yalnız AYT; server zamanına göre en az1 tam saniye gerekir. Süre dolmuşsa normal tamamlama; mevcut terminal sonuç tekrar değiştirilmez. Kum `floor(snapshot_full_coins × elapsed / planned)` ve en fazla snapshot tam ödülüdür. Yeni AYT90 dk72 kum/18 puan; eski7 kumluk snapshot90 dk3,önceki175kumluk snapshot87kum alır.
- `save_exam_details(p_attempt_id uuid,p_details jsonb,p_subject_results jsonb DEFAULT NULL,p_expected_revision integer DEFAULT NULL)` atomik metadata/net kaydıdır. Başlık120, not2000 Unicode karakter; başlık tek satır, not LF/TAB dışında kontrol karakteri içermez. Eksik alan korunur; title/note null temizler. AYT `selected_module_ids` verilmişse1–4 benzersiz test ID'sidir; null yeni girişte reddedilir. Kaydedilmiş sonucu olan modül çıkarılamaz. Aynı patch/sonuç duplicate; farklı içerikte eski revision conflict olur.
- Attempt'e `planned_duration_seconds`, `credited_minutes`, `completion_kind`, `title`, `note`, `selected_module_ids`, `details_revision` eklenir. Tamamlanmış `duration_seconds` gerçekleşen saniyedir; `ends_at` planlanan, `finished_at` gerçek bitiştir. `definition` içindeki bilinen AYT modülleri görünümde genişletilebilir; saklı eski reward snapshot'ı değişmez.
- Başlık/not owner-only alanlardır. Sosyal/lig payload'ına, kategori adına veya telemetriye eklenmez. Net kaydı/metadata güncellemesi ödül ve lig olayı üretmez. `save_exam_results` de varsa seçili modül kapsamını korur ve gerçek değişimde revision artırır.

Tam ödüller: LGS Sözel60,LGS Sayısal70,YDT95,TUS Temel110,TUS Klinik110,DUS120,TYT130,AYT145; üç KPSS GY–GK105, sekiz50dk Alan Bilgisi40,60dk İstatistik50. Yirmi tanımda reward_policy_version2. KPSS puanları sırasıyla26/10/12; erken bitişi yoktur. Normal kum/puan/lig ve Deneme cüzdanı ayrı kalır. Önceden başlayan veya tamamlanan denemelerin ödül snapshot'ı değiştirilmez. Ayrıntılı hata, rollback ve yerel test kanıtı [32 rehberindedir](32_exam_details_early_finish_README.md).

## Ders–çalışma kategorisi eşlemesi

TUS Fizyoloji ile Histoloji/Embriyoloji, `Fizyoloji, Histoloji ve Embriyoloji` çalışma kategorisine; AYT edebiyatı `Edebiyat` ve `Türkçe` kategorilerine bağlanır. Birleşik kategorinin aynı dakika toplamı her ilgili net karşılaştırmasına bağlam olur; derslere paylaştırılmaz ve toplam çalışma süresini artırmaz. Arayüz bu yüzden “İlişkili çalışma kategorilerinde …” der. “Küçük Stajlar” için resmî ayrı soru kotası veya uydurma ders eşlemesi yoktur; yetersiz sonuç içgörü oluşturmaz. İstemci `category_keys` değerlerini TR/EN adlar için `categoryMatchKey` ile normalize eder; kategori oturumunun UUID'si aynı karşılaştırmada bir kez sayılır. Eşleşen çalışma yokken geçerli iki net sonucu varsa gösterilen 0 dakika yalnız kayıtlı eşleşen süreyi ifade eder, çalışma yapılmadığı iddiası değildir.

## Ortak rapor için çalışma metaverisi

`get_my_study_sessions_v2(p_since timestamptz DEFAULT NULL,p_limit integer DEFAULT 1000,p_offset integer DEFAULT 0)` → kendi `study_sessions` satırlarından JSON dizi. Ek alanlar: `session_kind:normal|marathon`, `marathon_uuid`, `marathon_target_sessions`, `marathon_session_index`, `marathon_completed_at`. Tam ve geçerli planda son alan bütün odaklarda aynı son tamamlama zamanıdır; plan adedi distinct UUID ile sayılır. Yarım/geçersiz plan odağı süreye katılır ama plan tamamlanması NULL kalır.
