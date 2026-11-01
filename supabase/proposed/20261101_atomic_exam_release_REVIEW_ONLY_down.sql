-- REVIEW ONLY. DO NOT RUN ON PRODUCTION. Independent review and user action required.
-- Generated from 27,28,29,30,32; 31 is intentionally absent.
\echo 'REVIEW ONLY: do not execute until independently reviewed.'
\quit
-- source 27_tus_segment.sql sha256 9bd539da18f402b09ca8416dab485a8956a686c42847517862cc3552c958d7fd
-- source 28_exam_core.sql sha256 ec98009e6d5652608d88e4f6661079b6ed5c1d19e346446b35b479f2b90b71d6
-- source 29_monthly_competitions.sql sha256 408da466d17267bea6dbbd0527fc57e57399cc84289bde607f9ffdc92cc88a1f
-- source 30_session_start_atomic.sql sha256 c10d8235eb6f6f22372f8ebddb473b7ace186e2504e741705c01b1c15e4c7d73
-- source 32_exam_details_early_finish.sql sha256 21b0e5df5c94d0980129bcb611afa46ed9fab80b985cbf8726c21723a530abcc
BEGIN;
SET LOCAL lock_timeout = '2s';
SET LOCAL statement_timeout = '120s';
-- NOWAIT: if an application transaction is using these tables, abort this
-- transaction instead of waiting while holding a subset of table locks.
LOCK TABLE public.profiles IN ACCESS EXCLUSIVE MODE NOWAIT;
LOCK TABLE public.study_sessions, public.leagues, public.league_memberships,
  public.session_starts, public.avatar_unlocks IN SHARE ROW EXCLUSIVE MODE NOWAIT;
DO $$ DECLARE n timestamptz:=clock_timestamp(); start_month timestamptz;
BEGIN
 start_month := date_trunc('month', n AT TIME ZONE 'Europe/Istanbul') AT TIME ZONE 'Europe/Istanbul';
 IF date_trunc('month', now() AT TIME ZONE 'Europe/Istanbul') <>
    date_trunc('month', n AT TIME ZONE 'Europe/Istanbul') OR
    n < start_month + interval '5 minutes' OR
    n >= ((start_month AT TIME ZONE 'Europe/Istanbul' + interval '1 month') AT TIME ZONE 'Europe/Istanbul') - interval '5 minutes'
 THEN RAISE EXCEPTION 'release_month_boundary_unsafe'; END IF;
END $$;

DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls))
 THEN RAISE EXCEPTION 'release_requires_bypassrls'; END IF;
 IF NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101210000' AND name='atomic_exam_release')
 THEN RAISE EXCEPTION 'release_marker_not_found'; END IF;
END $$;
CREATE TEMP TABLE release_down_cron_before(snapshot jsonb NOT NULL) ON COMMIT DROP;
INSERT INTO release_down_cron_before
 SELECT value FROM public.competition_policy p CROSS JOIN LATERAL jsonb_array_elements(p.legacy_snapshot->'cron')
 WHERE value->>'jobname'='weekly_leagues_job';
DO $$ BEGIN
 IF (SELECT count(*) FROM release_down_cron_before)<>1 OR
    NOT EXISTS(SELECT 1 FROM release_down_cron_before WHERE snapshot->>'database'=current_database() AND snapshot->>'username'=current_user)
 THEN RAISE EXCEPTION 'release_legacy_cron_snapshot_invalid'; END IF;
END $$;

-- START 32_exam_details_early_finish DOWN
-- PROPOSED ONLY. Refuses data-losing rollback. Never removes earned wallets/attempts.
DO $$ DECLARE r record;BEGIN
 IF NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261028060000') OR to_regclass('public.exam_extension_32_backup') IS NULL THEN RAISE EXCEPTION 'exam32_not_installed'; END IF;
 IF EXISTS(SELECT 1 FROM public.exam_attempts WHERE title IS NOT NULL OR note IS NOT NULL OR selected_module_ids IS NOT NULL OR details_revision<>0 OR (status='completed' AND finished_at<ends_at) OR (status='active' AND exam_id='ayt' AND definition?'modules')) THEN RAISE EXCEPTION 'exam32_rollback_would_lose_data'; END IF;
 IF (SELECT jsonb_object_agg(id,jsonb_build_object('definition',definition,'enabled',enabled)) FROM public.exam_catalog) IS DISTINCT FROM (SELECT jsonb_object_agg(key,payload) FROM public.exam_extension_32_backup WHERE kind='installed_catalog') THEN RAISE EXCEPTION 'exam32_down_catalog_changed'; END IF;
 FOR r IN SELECT key,payload FROM public.exam_extension_32_backup WHERE kind='installed_function' LOOP
  IF to_regprocedure(r.key) IS NULL OR md5(pg_get_functiondef(to_regprocedure(r.key))) IS DISTINCT FROM r.payload->>'md5' OR to_jsonb((SELECT proacl FROM pg_proc WHERE oid=to_regprocedure(r.key))) IS DISTINCT FROM r.payload->'acl' THEN RAISE EXCEPTION 'exam32_down_function_changed: %',r.key; END IF;
 END LOOP;
 IF (SELECT count(*) FROM public.exam_extension_32_backup WHERE kind='installed_function')<>10 OR (SELECT count(*) FROM public.exam_extension_32_backup WHERE kind='function')<>5 THEN RAISE EXCEPTION 'exam32_backup_invalid'; END IF;
 IF (SELECT jsonb_object_agg(key,payload) FROM public.exam_extension_32_backup WHERE kind='catalog')<>'{"tyt":{"definition":{"id":"tyt","name_tr":"TYT","name_en":"TYT","segment":"yks","group":"yks","duration_seconds":9900,"total_questions":120,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":33,"reward_coins":6,"subjects":[{"id":"turkish","name_tr":"Türkçe","name_en":"Turkish","question_count":40,"category_keys":["Türkçe"]},{"id":"mathematics","name_tr":"Temel Matematik","name_en":"Basic Mathematics","question_count":40,"category_keys":["Matematik"]},{"id":"history","name_tr":"Tarih","name_en":"History","question_count":5,"category_keys":["Tarih"]},{"id":"geography","name_tr":"Coğrafya","name_en":"Geography","question_count":5,"category_keys":["Coğrafya"]},{"id":"philosophy","name_tr":"Felsefe","name_en":"Philosophy","question_count":5,"category_keys":["Felsefe"]},{"id":"religion","name_tr":"Din Kültürü / İlave Felsefe","name_en":"Religious Culture / Additional Philosophy","question_count":5,"category_keys":["Din Kültürü"]},{"id":"physics","name_tr":"Fizik","name_en":"Physics","question_count":7,"category_keys":["Fizik"]},{"id":"chemistry","name_tr":"Kimya","name_en":"Chemistry","question_count":7,"category_keys":["Kimya"]},{"id":"biology","name_tr":"Biyoloji","name_en":"Biology","question_count":6,"category_keys":["Biyoloji"]}]},"enabled":true},"ayt":{"definition":{"id":"ayt","name_tr":"AYT","name_en":"AYT","segment":"yks","group":"yks","duration_seconds":10800,"total_questions":160,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":36,"reward_coins":7,"subjects":[{"id":"literature","name_tr":"Türk Dili ve Edebiyatı","name_en":"Turkish Language and Literature","question_count":24,"category_keys":["Edebiyat","Türkçe"]},{"id":"history_1","name_tr":"Tarih-1","name_en":"History-1","question_count":10,"category_keys":["Tarih"]},{"id":"geography_1","name_tr":"Coğrafya-1","name_en":"Geography-1","question_count":6,"category_keys":["Coğrafya"]},{"id":"history_2","name_tr":"Tarih-2","name_en":"History-2","question_count":11,"category_keys":["Tarih"]},{"id":"geography_2","name_tr":"Coğrafya-2","name_en":"Geography-2","question_count":11,"category_keys":["Coğrafya"]},{"id":"philosophy_group","name_tr":"Felsefe Grubu","name_en":"Philosophy Group","question_count":12,"category_keys":["Felsefe"]},{"id":"religion","name_tr":"Din Kültürü / İlave Felsefe","name_en":"Religious Culture / Additional Philosophy","question_count":6,"category_keys":["Din Kültürü"]},{"id":"mathematics","name_tr":"Matematik","name_en":"Mathematics","question_count":40,"category_keys":["Matematik"]},{"id":"physics","name_tr":"Fizik","name_en":"Physics","question_count":14,"category_keys":["Fizik"]},{"id":"chemistry","name_tr":"Kimya","name_en":"Chemistry","question_count":13,"category_keys":["Kimya"]},{"id":"biology","name_tr":"Biyoloji","name_en":"Biology","question_count":13,"category_keys":["Biyoloji"]}]},"enabled":true},"ydt":{"definition":{"id":"ydt","name_tr":"YDT","name_en":"YDT","segment":"yks","group":"yks","duration_seconds":7200,"total_questions":80,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":24,"reward_coins":4,"subjects":[{"id":"foreign_language","name_tr":"Yabancı Dil","name_en":"Foreign Language","question_count":80,"category_keys":["İngilizce"]}]},"enabled":true},"lgs_verbal":{"definition":{"id":"lgs_verbal","name_tr":"LGS Sözel","name_en":"LGS Verbal","segment":"lgs","group":"lgs","duration_seconds":4500,"total_questions":50,"wrong_answer_divisor":3,"catalog_version":1,"reward_points":15,"reward_coins":3,"subjects":[{"id":"turkish","name_tr":"Türkçe","name_en":"Turkish","question_count":20,"category_keys":["Türkçe"]},{"id":"revolution_history","name_tr":"T.C. İnkılap Tarihi","name_en":"Turkish Revolution History","question_count":10,"category_keys":["T.C. İnkılap Tarihi"]},{"id":"religion","name_tr":"Din Kültürü","name_en":"Religious Culture","question_count":10,"category_keys":["Din Kültürü"]},{"id":"foreign_language","name_tr":"Yabancı Dil","name_en":"Foreign Language","question_count":10,"category_keys":["İngilizce"]}]},"enabled":true},"lgs_quantitative":{"definition":{"id":"lgs_quantitative","name_tr":"LGS Sayısal","name_en":"LGS Quantitative","segment":"lgs","group":"lgs","duration_seconds":4800,"total_questions":40,"wrong_answer_divisor":3,"catalog_version":1,"reward_points":16,"reward_coins":3,"subjects":[{"id":"mathematics","name_tr":"Matematik","name_en":"Mathematics","question_count":20,"category_keys":["Matematik"]},{"id":"science","name_tr":"Fen Bilimleri","name_en":"Science","question_count":20,"category_keys":["Fen Bilimleri"]}]},"enabled":true},"tus_basic":{"definition":{"id":"tus_basic","name_tr":"TUS Temel Tıp","name_en":"TUS Basic Medicine","segment":"tus","group":"tus","duration_seconds":8100,"total_questions":100,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":27,"reward_coins":5,"subjects":[{"id":"anatomy","name_tr":"Anatomi","name_en":"Anatomy","question_count":13,"category_keys":["Anatomi"]},{"id":"histology_embryology","name_tr":"Histoloji ve Embriyoloji","name_en":"Histology and Embryology","question_count":7,"category_keys":["Fizyoloji, Histoloji ve Embriyoloji"]},{"id":"physiology","name_tr":"Fizyoloji","name_en":"Physiology","question_count":8,"category_keys":["Fizyoloji, Histoloji ve Embriyoloji"]},{"id":"biochemistry","name_tr":"Biyokimya","name_en":"Biochemistry","question_count":18,"category_keys":["Biyokimya"]},{"id":"microbiology","name_tr":"Mikrobiyoloji","name_en":"Microbiology","question_count":18,"category_keys":["Mikrobiyoloji"]},{"id":"pathology","name_tr":"Patoloji","name_en":"Pathology","question_count":18,"category_keys":["Patoloji"]},{"id":"pharmacology","name_tr":"Farmakoloji","name_en":"Pharmacology","question_count":18,"category_keys":["Farmakoloji"]}]},"enabled":true},"tus_clinical":{"definition":{"id":"tus_clinical","name_tr":"TUS Klinik Tıp","name_en":"TUS Clinical Medicine","segment":"tus","group":"tus","duration_seconds":8100,"total_questions":100,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":27,"reward_coins":5,"subjects":[{"id":"internal_medicine_group","name_tr":"Dahiliye Grubu","name_en":"Internal Medicine Group","question_count":35,"category_keys":["Dahiliye"]},{"id":"pediatrics","name_tr":"Pediatri","name_en":"Pediatrics","question_count":25,"category_keys":["Pediatri"]},{"id":"surgery_group","name_tr":"Cerrahi Grubu","name_en":"Surgery Group","question_count":30,"category_keys":["Genel Cerrahi"]},{"id":"obstetrics_gynecology","name_tr":"Kadın Hastalıkları ve Doğum","name_en":"Obstetrics and Gynecology","question_count":10,"category_keys":["Kadın Hastalıkları ve Doğum"]}]},"enabled":true},"dus":{"definition":{"id":"dus","name_tr":"DUS","name_en":"DUS","segment":"dus","group":"dus","duration_seconds":9000,"total_questions":120,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":30,"reward_coins":6,"subjects":[{"id":"anatomy","name_tr":"Anatomi","name_en":"Anatomy","question_count":6,"category_keys":["Anatomi"]},{"id":"histology_embryology","name_tr":"Histoloji ve Embriyoloji","name_en":"Histology and Embryology","question_count":4,"category_keys":["Histoloji ve Embriyoloji"]},{"id":"physiology","name_tr":"Fizyoloji","name_en":"Physiology","question_count":6,"category_keys":["Fizyoloji"]},{"id":"biochemistry","name_tr":"Tıbbi Biyokimya","name_en":"Medical Biochemistry","question_count":6,"category_keys":["Biyokimya"]},{"id":"microbiology","name_tr":"Tıbbi Mikrobiyoloji","name_en":"Medical Microbiology","question_count":6,"category_keys":["Mikrobiyoloji"]},{"id":"pathology","name_tr":"Tıbbi Patoloji","name_en":"Medical Pathology","question_count":4,"category_keys":["Patoloji"]},{"id":"pharmacology","name_tr":"Tıbbi Farmakoloji","name_en":"Medical Pharmacology","question_count":4,"category_keys":["Farmakoloji"]},{"id":"medical_biology_genetics","name_tr":"Tıbbi Biyoloji ve Genetik","name_en":"Medical Biology and Genetics","question_count":4,"category_keys":["Tıbbi Biyoloji ve Genetik"]},{"id":"restorative_dentistry","name_tr":"Restoratif Diş Tedavisi","name_en":"Restorative Dentistry","question_count":10,"category_keys":["Restoratif Diş Tedavisi"]},{"id":"prosthetic_dentistry","name_tr":"Protetik Diş Tedavisi","name_en":"Prosthodontics","question_count":10,"category_keys":["Protetik Diş Tedavisi"]},{"id":"oral_maxillofacial_surgery","name_tr":"Ağız, Diş ve Çene Cerrahisi","name_en":"Oral and Maxillofacial Surgery","question_count":10,"category_keys":["Ağız, Diş ve Çene Cerrahisi"]},{"id":"oral_maxillofacial_radiology","name_tr":"Ağız, Diş ve Çene Radyolojisi","name_en":"Oral and Maxillofacial Radiology","question_count":10,"category_keys":["Ağız, Diş ve Çene Radyolojisi"]},{"id":"periodontology","name_tr":"Periodontoloji","name_en":"Periodontology","question_count":10,"category_keys":["Periodontoloji"]},{"id":"orthodontics","name_tr":"Ortodonti","name_en":"Orthodontics","question_count":10,"category_keys":["Ortodonti"]},{"id":"endodontics","name_tr":"Endodonti","name_en":"Endodontics","question_count":10,"category_keys":["Endodonti"]},{"id":"pediatric_dentistry","name_tr":"Çocuk Diş Hekimliği","name_en":"Pediatric Dentistry","question_count":10,"category_keys":["Çocuk Diş Hekimliği"]}]},"enabled":true},"kpss_bachelor_gygk":{"definition":{"id":"kpss_bachelor_gygk","name_tr":"KPSS Lisans · Genel Yetenek–Genel Kültür","name_en":"KPSS Bachelor’s · General Ability–General Knowledge","segment":"kpss","group":"kpss","duration_seconds":7800,"total_questions":120,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":26,"reward_coins":5,"subjects":[{"id":"general_ability","name_tr":"Genel Yetenek","name_en":"General Ability","question_count":60,"category_keys":["Türkçe","Matematik","Genel Yetenek"]},{"id":"general_knowledge","name_tr":"Genel Kültür","name_en":"General Knowledge","question_count":60,"category_keys":["Tarih","Coğrafya","Vatandaşlık","Güncel Bilgiler","Genel Kültür"]}]},"enabled":true},"kpss_associate_gygk":{"definition":{"id":"kpss_associate_gygk","name_tr":"KPSS Ön Lisans · Genel Yetenek–Genel Kültür","name_en":"KPSS Associate Degree · General Ability–General Knowledge","segment":"kpss","group":"kpss","duration_seconds":7800,"total_questions":120,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":26,"reward_coins":5,"subjects":[{"id":"general_ability","name_tr":"Genel Yetenek","name_en":"General Ability","question_count":60,"category_keys":["Türkçe","Matematik","Genel Yetenek"]},{"id":"general_knowledge","name_tr":"Genel Kültür","name_en":"General Knowledge","question_count":60,"category_keys":["Tarih","Coğrafya","Vatandaşlık","Güncel Bilgiler","Genel Kültür"]}]},"enabled":true},"kpss_secondary_gygk":{"definition":{"id":"kpss_secondary_gygk","name_tr":"KPSS Ortaöğretim · Genel Yetenek–Genel Kültür","name_en":"KPSS Secondary Education · General Ability–General Knowledge","segment":"kpss","group":"kpss","duration_seconds":7800,"total_questions":120,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":26,"reward_coins":5,"subjects":[{"id":"general_ability","name_tr":"Genel Yetenek","name_en":"General Ability","question_count":60,"category_keys":["Türkçe","Matematik","Genel Yetenek"]},{"id":"general_knowledge","name_tr":"Genel Kültür","name_en":"General Knowledge","question_count":60,"category_keys":["Tarih","Coğrafya","Vatandaşlık","Güncel Bilgiler","Genel Kültür"]}]},"enabled":true},"kpss_field_business":{"definition":{"id":"kpss_field_business","name_tr":"KPSS Alan Bilgisi · İşletme","name_en":"KPSS Field Knowledge · Business Administration","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":2,"subjects":[{"id":"business","name_tr":"İşletme","name_en":"Business Administration","question_count":40,"category_keys":["İşletme"]}]},"enabled":true},"kpss_field_accounting":{"definition":{"id":"kpss_field_accounting","name_tr":"KPSS Alan Bilgisi · Muhasebe","name_en":"KPSS Field Knowledge · Accounting","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":2,"subjects":[{"id":"accounting","name_tr":"Muhasebe","name_en":"Accounting","question_count":40,"category_keys":["Muhasebe"]}]},"enabled":true},"kpss_field_law":{"definition":{"id":"kpss_field_law","name_tr":"KPSS Alan Bilgisi · Hukuk","name_en":"KPSS Field Knowledge · Law","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":2,"subjects":[{"id":"law","name_tr":"Hukuk","name_en":"Law","question_count":40,"category_keys":["Hukuk"]}]},"enabled":true},"kpss_field_public_administration":{"definition":{"id":"kpss_field_public_administration","name_tr":"KPSS Alan Bilgisi · Kamu Yönetimi","name_en":"KPSS Field Knowledge · Public Administration","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":2,"subjects":[{"id":"public_administration","name_tr":"Kamu Yönetimi","name_en":"Public Administration","question_count":40,"category_keys":["Kamu Yönetimi"]}]},"enabled":true},"kpss_field_economics":{"definition":{"id":"kpss_field_economics","name_tr":"KPSS Alan Bilgisi · İktisat","name_en":"KPSS Field Knowledge · Economics","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":2,"subjects":[{"id":"economics","name_tr":"İktisat","name_en":"Economics","question_count":40,"category_keys":["İktisat"]}]},"enabled":true},"kpss_field_finance":{"definition":{"id":"kpss_field_finance","name_tr":"KPSS Alan Bilgisi · Maliye","name_en":"KPSS Field Knowledge · Public Finance","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":2,"subjects":[{"id":"finance","name_tr":"Maliye","name_en":"Public Finance","question_count":40,"category_keys":["Maliye"]}]},"enabled":true},"kpss_field_international_relations":{"definition":{"id":"kpss_field_international_relations","name_tr":"KPSS Alan Bilgisi · Uluslararası İlişkiler","name_en":"KPSS Field Knowledge · International Relations","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":2,"subjects":[{"id":"international_relations","name_tr":"Uluslararası İlişkiler","name_en":"International Relations","question_count":40,"category_keys":["Uluslararası İlişkiler"]}]},"enabled":true},"kpss_field_labour_economics":{"definition":{"id":"kpss_field_labour_economics","name_tr":"KPSS Alan Bilgisi · Çalışma Ekonomisi ve Endüstri İlişkileri","name_en":"KPSS Field Knowledge · Labour Economics and Industrial Relations","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":2,"subjects":[{"id":"labour_economics","name_tr":"Çalışma Ekonomisi ve Endüstri İlişkileri","name_en":"Labour Economics and Industrial Relations","question_count":40,"category_keys":["Çalışma Ekonomisi ve Endüstri İlişkileri"]}]},"enabled":true},"kpss_field_statistics":{"definition":{"id":"kpss_field_statistics","name_tr":"KPSS Alan Bilgisi · İstatistik","name_en":"KPSS Field Knowledge · Statistics","segment":"kpss","group":"kpss","duration_seconds":3600,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":12,"reward_coins":2,"subjects":[{"id":"statistics","name_tr":"İstatistik","name_en":"Statistics","question_count":40,"category_keys":["İstatistik"]}]},"enabled":true}}'::jsonb THEN RAISE EXCEPTION 'exam32_backup_invalid'; END IF;
 FOR r IN SELECT * FROM (VALUES
  ('_exam_payload(uuid)','123cdc46703b9d5f63ffd1ce1e62d500'),
  ('get_exam_config()','b30eb2af01e29bc2c9a47480045e6ca6'),
  ('_exam_has_overlap(uuid,timestamp with time zone,timestamp with time zone)','64c8c0de1f26810e6df4107b817ba8b0'),
  ('_competition_exam_event()','0e5d282c147c27089c838a4de5598919'),
  ('save_exam_results(uuid,jsonb)','24dd963f3265de9a7eeff547a39a9cf9')
 )v(signature,digest) LOOP
  IF NOT EXISTS(SELECT 1 FROM public.exam_extension_32_backup WHERE kind='function' AND key=r.signature AND md5(payload->>'definition')=r.digest AND payload->>'md5'=r.digest) THEN RAISE EXCEPTION 'exam32_backup_invalid'; END IF;
 END LOOP;
END $$;
DO $$ DECLARE r record;BEGIN FOR r IN SELECT payload FROM public.exam_extension_32_backup WHERE kind='function' ORDER BY key LOOP EXECUTE r.payload->>'definition';END LOOP;END $$;
DROP FUNCTION public.save_exam_details(uuid,jsonb,jsonb,integer);
DROP FUNCTION public.finish_ayt_early(uuid);
DROP FUNCTION public._exam_apply_results32(uuid,jsonb);
DROP FUNCTION public._exam_validate_results32(jsonb,text[],jsonb);
DROP FUNCTION public._exam_ayt_modules32(jsonb);
ALTER TABLE public.exam_attempts DROP COLUMN title,DROP COLUMN note,DROP COLUMN selected_module_ids,DROP COLUMN details_revision;
UPDATE public.exam_catalog c SET definition=b.payload->'definition',enabled=(b.payload->>'enabled')::boolean FROM public.exam_extension_32_backup b WHERE b.kind='catalog' AND b.key=c.id;
DROP TABLE public.exam_extension_policy;
DROP TABLE public.exam_extension_32_backup;
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261028060000';
-- END 32_exam_details_early_finish DOWN

-- START 30_session_start_atomic DOWN
-- CANLIYA UYGULANMADI. Kayıt/puan/kum silmez; eski kota yarışını geri getirir.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261028040000' AND name='session_start_atomic') THEN RAISE EXCEPTION 'session_start_atomic_not_installed'; END IF;
 IF md5(pg_get_functiondef('public.register_session_start(uuid,integer)'::regprocedure))<>'1582a6da3c5e9ff496a8f2c16455b13e' THEN RAISE EXCEPTION 'session_start_atomic_down_precondition_changed'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.register_session_start(p_client_uuid uuid, p_duration_minutes integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_started timestamptz;
    v_recent integer;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;
    IF p_client_uuid IS NULL THEN
        RAISE EXCEPTION 'invalid client_uuid';
    END IF;
    IF p_duration_minutes IS NULL OR p_duration_minutes NOT IN (25, 50) THEN
        RAISE EXCEPTION 'invalid duration: only 25 or 50 allowed';
    END IF;

    -- Var olan kayıt değişmez: başlangıç sonradan kaydırılamaz.
    SELECT s.server_started_at INTO v_started
      FROM public.session_starts s
     WHERE s.user_id = v_uid AND s.client_uuid = p_client_uuid;
    IF FOUND THEN
        RETURN jsonb_build_object('client_uuid', p_client_uuid, 'server_started_at', v_started,
                                  'server_now', now(), 'created', false);
    END IF;

    -- Tamamlanmamış / terk edilmiş eski başlangıçlar (seans 24 saatten
    -- eskiyse zaten kabul edilmez).
    DELETE FROM public.session_starts
     WHERE user_id = v_uid AND server_started_at < now() - interval '48 hours';

    SELECT count(*) INTO v_recent
      FROM public.session_starts
     WHERE user_id = v_uid AND server_started_at > now() - interval '24 hours';
    IF v_recent >= 100 THEN
        RAISE EXCEPTION 'too_many_session_starts';
    END IF;

    INSERT INTO public.session_starts (user_id, client_uuid, duration_minutes, server_started_at)
    VALUES (v_uid, p_client_uuid, p_duration_minutes, now())
    ON CONFLICT (user_id, client_uuid) DO NOTHING
    RETURNING server_started_at INTO v_started;

    IF v_started IS NULL THEN
        SELECT s.server_started_at INTO v_started
          FROM public.session_starts s
         WHERE s.user_id = v_uid AND s.client_uuid = p_client_uuid;
    END IF;

    RETURN jsonb_build_object('client_uuid', p_client_uuid, 'server_started_at', v_started,
                              'server_now', now(), 'created', true);
END;
$function$;
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261028040000' AND name='session_start_atomic';
-- END 30_session_start_atomic DOWN

-- START 29_monthly_competitions DOWN
-- Reversible only before activation and before pending target choices/results.
-- Canonical study and exam attempts/rewards are never deleted here.
DO $$ BEGIN
 IF to_regclass('public.exam_extension_32_backup') IS NOT NULL THEN RAISE EXCEPTION 'competition_rollback_requires32_down_first';END IF;
 IF now()>=(SELECT activates_at FROM public.competition_policy WHERE singleton)
 OR EXISTS(SELECT 1 FROM public.competition_results)
 OR EXISTS(SELECT 1 FROM public.competition_target_history WHERE from_month>public._competition_month(now()))
 THEN RAISE EXCEPTION 'competition_rollback_refused_active_or_pending_data';END IF;
END $$;
DROP TRIGGER competition_study_accept ON public.study_sessions;
DROP TRIGGER competition_exam_accept ON public.exam_attempts;
DROP TRIGGER competition_target_change ON public.profiles;
DROP TRIGGER competition_delete_identity ON public.profiles;
DO $$ DECLARE r record;j jsonb;BEGIN
 FOR r IN SELECT * FROM public.competition_install_backup LOOP EXECUTE r.definition;END LOOP;
 FOR j IN SELECT value FROM public.competition_policy p CROSS JOIN LATERAL jsonb_array_elements(p.legacy_snapshot->'cron') LOOP
  PERFORM cron.schedule(j->>'jobname',j->>'schedule',j->>'command');
 END LOOP;
END $$;
DROP FUNCTION public.get_monthly_league_ranking(text,text),public.get_my_exam_league_ranking(text),public.get_public_monthly_competition(integer),public.get_competition_target(),public.set_competition_target(text),public.process_monthly_competitions(),public._competition_finalize_legacy(),public._competition_purge_deleted_identity(),public._competition_repack_current(),public._competition_legacy_ensure_user_in_league(uuid,integer),public._competition_legacy_weekly(),public._competition_study_event(),public._competition_exam_event(),public._competition_record(text,uuid,uuid,timestamptz,timestamptz,integer,integer),public._competition_place(uuid,text,date,timestamptz),public._competition_room_rows(uuid),public._competition_track_target(),public._competition_segment(uuid,date);
DROP TABLE public.competition_results,public.competition_events,public.competition_memberships,public.competition_rooms,public.competition_profiles,public.competition_target_history,public.competition_periods,public.competition_avatar_rewards,public.competition_policy,public.competition_install_backup;
DROP FUNCTION public._competition_month_time(date),public._competition_month(timestamptz);
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261028030000' AND name='monthly_competitions';
NOTIFY pgrst,'reload schema';
-- END 29_monthly_competitions DOWN

-- START 28_exam_core DOWN
-- Safe rollback: refusal preserves recorded attempts, results and their rewards.
DO $$ BEGIN
 IF to_regclass('public.exam_extension_32_backup') IS NOT NULL THEN RAISE EXCEPTION 'exam_rollback_requires32_down_first';END IF;
 IF to_regclass('public.competition_policy') IS NOT NULL THEN RAISE EXCEPTION 'exam_rollback_requires_competition_down_first';END IF;
 IF EXISTS(SELECT 1 FROM public.exam_attempts) OR EXISTS(SELECT 1 FROM public.exam_wallets) THEN RAISE EXCEPTION 'exam_rollback_refused_existing_attempts';END IF;
END $$;
DROP TRIGGER exam_guard_normal_study ON public.study_sessions;
DO $$ DECLARE r record;BEGIN FOR r IN SELECT * FROM public.exam_install_backup LOOP EXECUTE r.definition;END LOOP;END $$;
DROP FUNCTION public.get_my_study_sessions_v2(timestamptz,integer,integer),public.get_exam_config(),public.start_exam_attempt(uuid,text),public.complete_exam_attempt(uuid),public.abandon_exam_attempt(uuid),public.get_my_exam_attempts(integer,timestamptz),public.save_exam_results(uuid,jsonb),public._exam_payload(uuid),public._exam_has_overlap(uuid,timestamptz,timestamptz),public._exam_guard_study_insert();
DROP TABLE public.exam_subject_results,public.exam_wallets,public.exam_attempts,public.exam_catalog,public.exam_install_backup;
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261028020000' AND name='exam_core';
NOTIFY pgrst,'reload schema';
-- END 28_exam_core DOWN

-- START 27_tus_segment DOWN
-- CANLIYA UYGULANMADI. TUS veya DUS kullanan profil varsa kayıpsız geri alma mümkün
-- olmadığından bu betik reddeder; kullanıcı hedefini sessizce NULL yapmaz.
DO $$ BEGIN
 IF to_regclass('public.exam_attempts') IS NOT NULL THEN RAISE EXCEPTION 'tus_rollback_requires_exam_down_first'; END IF;
 IF EXISTS(SELECT 1 FROM public.profiles WHERE user_segment IN('tus','dus')) THEN
  RAISE EXCEPTION 'tus_or_dus_segment_in_use';
 END IF;
END $$;
ALTER TABLE public.profiles DROP CONSTRAINT profiles_user_segment_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_user_segment_check
 CHECK(user_segment=ANY(ARRAY['lgs','yks','kpss','language','university','work']::text[]));
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261028010000' AND name='tus_segment';
-- END 27_tus_segment DOWN

DELETE FROM supabase_migrations.schema_migrations WHERE version='20261101210000' AND name='atomic_exam_release';
DO $$ DECLARE r record; BEGIN
 FOR r IN SELECT * FROM (VALUES
  ('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamp with time zone)', '72023f3f4d8636363cf0231f42d4c7e1'),
  ('public.ensure_user_in_league(uuid,integer)', '65faa90deaf3f8e988a801d1628aabce'),
  ('public.get_league_config()', 'bbcb4673dfa311b076789764207e49b5'),
  ('public.get_league_ranking(uuid)', 'f90981ef879bcfbe3e456190c0929263'),
  ('public.get_live_friends_with_breaks()', '342b58cfe59ef5766d85ec66f4aee2ce'),
  ('public.get_my_league_ranking()', 'a6e5ec04783800080c36b03704c4e320'),
  ('public.get_my_league_ranking_v2()', '154eebf5aea8060d104b58d5208807b7'),
  ('public.get_public_monthly_leaderboard(integer)', 'bc8655aa7e7189efdb4a42e60a90ae55'),
  ('public.league_award_avatar_id(integer,integer)', 'f6ed7f1c88a233f1a08bc67713b886e6'),
  ('public.process_weekly_leagues()', 'f6d02ce7217264dcf44e45056b8fd5b6'),
  ('public.register_session_start(uuid,integer)', '9500c7c45503a3e5031e52c879b1dba2'),
  ('public.start_study_session(integer,text)', '56a13ce596649189df480f5e39454f95')
 ) AS expected(signature,digest) LOOP
  IF to_regprocedure(r.signature) IS NULL OR
     md5(pg_get_functiondef(to_regprocedure(r.signature))) IS DISTINCT FROM r.digest
  THEN RAISE EXCEPTION 'release_live_function_changed: %', r.signature; END IF;
 END LOOP;
END $$;

DO $$ BEGIN
 IF (SELECT count(*) FROM cron.job WHERE jobname='weekly_leagues_job')<>1 OR
    (SELECT to_jsonb(j) FROM cron.job j WHERE jobname='weekly_leagues_job') IS DISTINCT FROM
    (SELECT snapshot FROM release_down_cron_before)
 THEN RAISE EXCEPTION 'release_legacy_cron_restore_failed'; END IF;
END $$;
COMMIT;
