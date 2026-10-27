# Deneme ve aylık lig sözleşmesi — 28 Ekim 2026

Bu sözleşme yalnız hazırlanmış yerel paket içindir; canlıya uygulanmadı. Sıra: **27 TUS → 28 deneme çekirdeği → 29 birleşik aylık lig**. Eski sunucuda bulunmayan RPC (`PGRST202`) yeni özelliği kapatır; ağ/yetki hatası başarı veya eski sunucu sayılmaz.

## Deneme

- `get_exam_config()` → `{schema_version:1,available:true,server_time,exams:[...]}`. Her sınav: `id`, `name_tr`, `name_en`, `segment`, `group`, `duration_seconds`, `total_questions`, `wrong_answer_divisor`, `catalog_version`, `subjects:[{id,name_tr,name_en,question_count,category_keys:[]}]`.
- `start_exam_attempt(p_client_uuid uuid,p_exam_id text)` → `{server_time,duplicate,attempt}`. Süre ve başlangıç sunucudan; istemci 3-2-1 sonrasında çağırır. Aynı owner/UUID aynı sınavı döndürür; başka sınav metadata çatışmasıdır. İstek öncesi UUID cihazda kalıcı tutulur.
- `complete_exam_attempt(p_attempt_id uuid)` → aynı zarf. Tam süre dolmadan `exam_not_elapsed`; ayrı saat, duration veya net kabul edilmez. Başarılı ilk çağrıda ekonomi bir kez yazılır. Duplicate aynı kazanılmış snapshot'ı döndürür; `duplicate:true` yeniden delta ekletmez.
- `abandon_exam_attempt(p_attempt_id uuid)` → aynı zarf. `status:abandoned`, geçen süre sunucuda saklanır; toplam çalışma, seri, normal/deneme puanı ve kum katkısı **sıfırdır**. Daha önce tamamlananı geriye alamaz. Tam süre dolmuş aktif deneme tamamlamaya yönlendirilir.
- `get_my_exam_attempts(p_limit integer DEFAULT 100,p_before timestamptz DEFAULT NULL)` → `{server_time,attempts:[]}`. Limit 1–1000; `next_cursor` son satırın başlangıcıdır. İlk sayfada aktif kayıt en üstte ve limit içine kesin alınır. Diğerleri başlangıç azalan. Sahip dışı kayıt yoktur.
- `save_exam_results(p_attempt_id uuid,p_subject_results jsonb)` → aynı zarf. Dizi girdisi yalnız `{subject_id,correct,wrong,blank}`. Her sayı tamsayı ve ≥0; toplam dersin soru sayısına eşit; bilinmeyen/tekrarlanan ders reddedilir. Gönderilen dersler güncellenir, gönderilmeyenler korunur. Boş dizi değiştirmez. Net sunucuda `correct - wrong / divisor` olarak hesaplanır; negatif net geçerlidir. Netler normal/deneme ekonomisini ve ligi değiştirmez.

`attempt`: `id`, `client_uuid`, `exam_id`, `catalog_version`, `name_tr`, `name_en`, `started_at`, `ends_at`, `completed_at`, `finished_at`, `duration_seconds`, `elapsed_seconds`, `total_questions`, `wrong_answer_divisor`, `status` (`active|completed|abandoned`), `points_earned`, `exam_coins_earned`, `subject_results`, `definition` (sürümü sabit tam katalog), `subjects`. Tüm zamanlar ISO8601 UTC; widget kalan süreyi `ends_at - serverAdjustedNow` ile hesaplar.

Hata kodları PostgreSQL `P0001` mesajında sabittir: `exam_not_elapsed` geçici; `exam_overlap`, `exam_not_active`, `exam_not_found`, `exam_metadata_conflict`, `exam_result_invalid`, `exam_unavailable` kullanıcıya açıklanır. Auth hatası `not authenticated`; başka sahibin UUID'si `exam_not_found` ile ifşa edilmez.

Katalog kimlikleri: `tyt`, `ayt`, `ydt`, `lgs_verbal`, `lgs_quantitative`, `tus_basic`, `tus_clinical`. TUS iki ayrı100soru/135dk oturumdur. LGS iki ayrı oturumdur;45dk ara çalışma veya ödül değildir. Katalogdaki standart sınav sayacı gerçek sınav puanını hesaplamaz.

## Aylık lig

- `get_monthly_league_ranking(p_kind text DEFAULT 'study',p_scope text DEFAULT 'segment')` → `{schema_version:1,server_time,kind,scope,segment,pending_segment,segment_effective_at,tier,period_start,period_end,competition_phase,room_capacity,rows:[]}`.
- `get_my_exam_league_ranking(p_scope text DEFAULT 'segment')` aynı sözleşmenin `kind:exam` yedeğidir.
- `p_kind`: `study|exam`; `p_scope`: `segment|global`. Segment sunucu sahibinin ay boyunca sabit hedefidir; istemci başka hedef seçemez. Global bütün hedefleri kapsayan sıralamadır; ikinci ödül veya ikinci cüzdan oluşturmaz.
- Satır: `id`, `name`, `avatar_id`, `is_me`, `is_blocked`, `points`, `rank`, `tier`, `promotion_eligible`, `award_eligible`, `demotion_eligible`, `has_league`, `member_count`, `active_member_count`, `end_date`. Eski normal V2 ek `weekly_points` eşdeğer alanını korur.
- `get_competition_target()` → `{current_segment,pending_segment,effective_at}`; `set_competition_target(p_segment text)` aynı cevabı döndürür. Orta ay değişimi bir sonraki İstanbul takvim ayından etkilidir; mevcut puan ve üyelik taşınmaz. İlk seans öncesi onboarding hedefi hemen uygulanır.

Normal lig puanı yalnız Pomodoro/Maraton; deneme ligi puanı yalnız tam süreli denemeden. Takvim ayı sınırı `Europe/Istanbul`00:00; çalışma günü/seri04:00. Düşük nüfusta hazırlık/ödülsüz durum; eksik deneme-avatar görseli gerçek ödül gibi gösterilmez.

## Sosyal ve toplamlar

`get_live_friends_with_breaks()` eski sözleşmeye `status:exam`, `exam_type`, `exam_name_tr`, `exam_name_en` ekler. Görünürlük, arkadaşlık, engel filtresi korunur. Gecikmiş normal iptal deneme tablosuna dokunmaz.

Tamamlanan denemeler profil toplam dakikasına ve04:00 serisine eklenir; normal puan/kum değişmez. Raporlar ayrı deneme listesini okur ve yalnız `completed` kayıtların tam süresini `Deneme` satırında birleştirir. Derslere süre paylaştırılmaz; netler yalnız kişisel rapor/içgörü girdisidir.

## Ortak rapor için çalışma metaverisi

`get_my_study_sessions_v2(p_since timestamptz DEFAULT NULL,p_limit integer DEFAULT 1000,p_offset integer DEFAULT 0)` → kendi `study_sessions` satırlarından JSON dizi. Ek alanlar: `session_kind:normal|marathon`, `marathon_uuid`, `marathon_target_sessions`, `marathon_session_index`, `marathon_completed_at`. Tam ve geçerli planda son alan bütün odaklarda aynı son tamamlama zamanıdır; plan adedi distinct UUID ile sayılır. Yarım/geçersiz plan odağı süreye katılır ama plan tamamlanması NULL kalır.
