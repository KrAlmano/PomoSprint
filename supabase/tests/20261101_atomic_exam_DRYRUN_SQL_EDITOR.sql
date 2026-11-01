-- SQL EDITOR DRYRUN: değişiklikler yalnız işlem içinde denenir ve ROLLBACK yapılır.
-- Generated from 27,28,29,30,32; 31 is intentionally absent.
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
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname=current_user AND (rolsuper OR rolbypassrls))
 THEN RAISE EXCEPTION 'release_requires_bypassrls'; END IF;
 IF (SELECT count(*) FROM cron.job WHERE jobname='weekly_leagues_job' AND active AND database=current_database() AND username=current_user AND schedule='1 21 * * 0' AND command='SELECT public.process_weekly_leagues()') <> 1
 OR (SELECT count(*) FROM cron.job WHERE jobname='weekly_leagues_job') <> 1
 THEN RAISE EXCEPTION 'release_legacy_cron_changed'; END IF;
 IF EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101210000')
 THEN RAISE EXCEPTION 'release_atomic_marker_exists'; END IF;
END $$;
CREATE TEMP TABLE release_cron_before(snapshot jsonb NOT NULL) ON COMMIT DROP;
INSERT INTO release_cron_before SELECT to_jsonb(j) FROM cron.job j WHERE jobname='weekly_leagues_job';
CREATE TEMP TABLE release_before(name text PRIMARY KEY,digest text NOT NULL) ON COMMIT DROP;
INSERT INTO release_before VALUES
 ('profiles', (SELECT md5(coalesce(string_agg(to_jsonb(t)::text, '|' ORDER BY to_jsonb(t)::text), '')) FROM public.profiles t)),
 ('sessions', (SELECT md5(coalesce(string_agg(to_jsonb(t)::text, '|' ORDER BY to_jsonb(t)::text), '')) FROM public.study_sessions t)),
 ('leagues', (SELECT md5(coalesce(string_agg(to_jsonb(t)::text, '|' ORDER BY to_jsonb(t)::text), '')) FROM public.leagues t)),
 ('memberships', (SELECT md5(coalesce(string_agg(to_jsonb(t)::text, '|' ORDER BY to_jsonb(t)::text), '')) FROM public.league_memberships t)),
 ('starts', (SELECT md5(coalesce(string_agg(to_jsonb(t)::text, '|' ORDER BY to_jsonb(t)::text), '')) FROM public.session_starts t)),
 ('unlocks', (SELECT md5(coalesce(string_agg(to_jsonb(t)::text, '|' ORDER BY to_jsonb(t)::text), '')) FROM public.avatar_unlocks t));

-- START 27_tus_segment
-- HAZIRLANDI / CANLIYA UYGULANMADI. TUS + DUS. Sıra: 27 → 28 → 29.
-- SQL Editor'de çalıştırmadan önce eşlik eden DRYRUN ve README'yi okuyun.
DO $$
DECLARE v_definition text;
BEGIN
 SELECT pg_get_constraintdef(oid) INTO v_definition FROM pg_constraint
 WHERE conrelid='public.profiles'::regclass AND conname='profiles_user_segment_check';
 IF v_definition IS DISTINCT FROM 'CHECK ((user_segment = ANY (ARRAY[''lgs''::text, ''yks''::text, ''kpss''::text, ''language''::text, ''university''::text, ''work''::text])))' THEN
  RAISE EXCEPTION 'tus_segment_precondition_changed';
 END IF;
 IF EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261028010000') THEN
  RAISE EXCEPTION 'tus_segment_already_applied';
 END IF;
END $$;
ALTER TABLE public.profiles DROP CONSTRAINT profiles_user_segment_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_user_segment_check
 CHECK(user_segment=ANY(ARRAY['lgs','yks','tus','dus','kpss','language','university','work']::text[]));
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261028010000','tus_segment');
-- END 27_tus_segment

-- START 28_exam_core
-- PROPOSED ONLY. Never db push. Run 27, then this package, then 29.
-- Full server-timed attempts; net declarations never affect rewards.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261028010000') THEN RAISE EXCEPTION 'exam_requires_tus_segment'; END IF;
 IF to_regclass('public.exam_attempts') IS NOT NULL THEN RAISE EXCEPTION 'exam_core_already_installed'; END IF;
 IF md5(pg_get_functiondef('public.start_study_session(integer,text)'::regprocedure)) <> '56a13ce596649189df480f5e39454f95'
 OR md5(pg_get_functiondef('public.get_live_friends_with_breaks()'::regprocedure)) <> '342b58cfe59ef5766d85ec66f4aee2ce'
 OR md5(pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure)) <> '72023f3f4d8636363cf0231f42d4c7e1'
 THEN RAISE EXCEPTION 'exam_core_precondition_changed'; END IF;
END $$;
CREATE TABLE public.exam_install_backup (signature text PRIMARY KEY,definition text NOT NULL);
ALTER TABLE public.exam_install_backup ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.exam_install_backup FROM PUBLIC,anon,authenticated,service_role;
INSERT INTO public.exam_install_backup SELECT 'public.start_study_session(integer,text)',pg_get_functiondef('public.start_study_session(integer,text)'::regprocedure);
CREATE TABLE public.exam_catalog (
 id text PRIMARY KEY, definition jsonb NOT NULL, enabled boolean NOT NULL DEFAULT true,
 CHECK(definition->>'id'=id),CHECK((definition->>'duration_seconds')::int>0),
 CHECK((definition->>'total_questions')::int>0)
);
CREATE TABLE public.exam_attempts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
 client_uuid uuid NOT NULL,exam_id text NOT NULL REFERENCES public.exam_catalog(id),definition jsonb NOT NULL,
 started_at timestamptz NOT NULL,ends_at timestamptz NOT NULL,finished_at timestamptz,
 status text NOT NULL DEFAULT 'active' CHECK(status IN('active','completed','abandoned')),
 elapsed_seconds integer NOT NULL DEFAULT 0 CHECK(elapsed_seconds>=0),
 points_earned integer NOT NULL DEFAULT 0 CHECK(points_earned>=0),
 exam_coins_earned integer NOT NULL DEFAULT 0 CHECK(exam_coins_earned>=0),
 UNIQUE(user_id,client_uuid),CHECK(ends_at>started_at),
 CHECK((status='active' AND finished_at IS NULL) OR (status<>'active' AND finished_at IS NOT NULL)),
 CHECK(status='completed' OR (points_earned=0 AND exam_coins_earned=0))
);
CREATE UNIQUE INDEX exam_one_active_owner ON public.exam_attempts(user_id) WHERE status='active';
CREATE INDEX exam_attempt_owner_started ON public.exam_attempts(user_id,started_at DESC,id);
CREATE TABLE public.exam_subject_results (
 attempt_id uuid NOT NULL REFERENCES public.exam_attempts(id) ON DELETE CASCADE,
 subject_id text NOT NULL,correct integer NOT NULL CHECK(correct>=0),wrong integer NOT NULL CHECK(wrong>=0),
 blank integer NOT NULL CHECK(blank>=0),net numeric NOT NULL,updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(attempt_id,subject_id)
);
CREATE TABLE public.exam_wallets (
 user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
 coins integer NOT NULL DEFAULT 0 CHECK(coins>=0),lifetime_points integer NOT NULL DEFAULT 0 CHECK(lifetime_points>=0)
);
ALTER TABLE public.exam_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_subject_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_wallets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.exam_catalog,public.exam_attempts,public.exam_subject_results,public.exam_wallets FROM PUBLIC,anon,authenticated,service_role;
GRANT SELECT ON public.exam_attempts,public.exam_subject_results,public.exam_wallets TO authenticated;
CREATE POLICY exam_owner_read ON public.exam_attempts FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
CREATE POLICY exam_results_owner_read ON public.exam_subject_results FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.exam_attempts a WHERE a.id=attempt_id AND a.user_id=(SELECT auth.uid())));
CREATE POLICY exam_wallet_owner_read ON public.exam_wallets FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
INSERT INTO public.exam_catalog(id,definition) VALUES ('tyt','{"id": "tyt", "name_tr": "TYT", "name_en": "TYT", "segment": "yks", "group": "yks", "duration_seconds": 9900, "total_questions": 120, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 33, "reward_coins": 6, "subjects": [{"id": "turkish", "name_tr": "Türkçe", "name_en": "Turkish", "question_count": 40, "category_keys": ["Türkçe"]}, {"id": "mathematics", "name_tr": "Temel Matematik", "name_en": "Basic Mathematics", "question_count": 40, "category_keys": ["Matematik"]}, {"id": "history", "name_tr": "Tarih", "name_en": "History", "question_count": 5, "category_keys": ["Tarih"]}, {"id": "geography", "name_tr": "Coğrafya", "name_en": "Geography", "question_count": 5, "category_keys": ["Coğrafya"]}, {"id": "philosophy", "name_tr": "Felsefe", "name_en": "Philosophy", "question_count": 5, "category_keys": ["Felsefe"]}, {"id": "religion", "name_tr": "Din Kültürü / İlave Felsefe", "name_en": "Religious Culture / Additional Philosophy", "question_count": 5, "category_keys": ["Din Kültürü"]}, {"id": "physics", "name_tr": "Fizik", "name_en": "Physics", "question_count": 7, "category_keys": ["Fizik"]}, {"id": "chemistry", "name_tr": "Kimya", "name_en": "Chemistry", "question_count": 7, "category_keys": ["Kimya"]}, {"id": "biology", "name_tr": "Biyoloji", "name_en": "Biology", "question_count": 6, "category_keys": ["Biyoloji"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('ayt','{"id": "ayt", "name_tr": "AYT", "name_en": "AYT", "segment": "yks", "group": "yks", "duration_seconds": 10800, "total_questions": 160, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 36, "reward_coins": 7, "subjects": [{"id": "literature", "name_tr": "Türk Dili ve Edebiyatı", "name_en": "Turkish Language and Literature", "question_count": 24, "category_keys": ["Edebiyat", "Türkçe"]}, {"id": "history_1", "name_tr": "Tarih-1", "name_en": "History-1", "question_count": 10, "category_keys": ["Tarih"]}, {"id": "geography_1", "name_tr": "Coğrafya-1", "name_en": "Geography-1", "question_count": 6, "category_keys": ["Coğrafya"]}, {"id": "history_2", "name_tr": "Tarih-2", "name_en": "History-2", "question_count": 11, "category_keys": ["Tarih"]}, {"id": "geography_2", "name_tr": "Coğrafya-2", "name_en": "Geography-2", "question_count": 11, "category_keys": ["Coğrafya"]}, {"id": "philosophy_group", "name_tr": "Felsefe Grubu", "name_en": "Philosophy Group", "question_count": 12, "category_keys": ["Felsefe"]}, {"id": "religion", "name_tr": "Din Kültürü / İlave Felsefe", "name_en": "Religious Culture / Additional Philosophy", "question_count": 6, "category_keys": ["Din Kültürü"]}, {"id": "mathematics", "name_tr": "Matematik", "name_en": "Mathematics", "question_count": 40, "category_keys": ["Matematik"]}, {"id": "physics", "name_tr": "Fizik", "name_en": "Physics", "question_count": 14, "category_keys": ["Fizik"]}, {"id": "chemistry", "name_tr": "Kimya", "name_en": "Chemistry", "question_count": 13, "category_keys": ["Kimya"]}, {"id": "biology", "name_tr": "Biyoloji", "name_en": "Biology", "question_count": 13, "category_keys": ["Biyoloji"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('ydt','{"id": "ydt", "name_tr": "YDT", "name_en": "YDT", "segment": "yks", "group": "yks", "duration_seconds": 7200, "total_questions": 80, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 24, "reward_coins": 4, "subjects": [{"id": "foreign_language", "name_tr": "Yabancı Dil", "name_en": "Foreign Language", "question_count": 80, "category_keys": ["İngilizce"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('lgs_verbal','{"id": "lgs_verbal", "name_tr": "LGS Sözel", "name_en": "LGS Verbal", "segment": "lgs", "group": "lgs", "duration_seconds": 4500, "total_questions": 50, "wrong_answer_divisor": 3, "catalog_version": 1, "reward_points": 15, "reward_coins": 3, "subjects": [{"id": "turkish", "name_tr": "Türkçe", "name_en": "Turkish", "question_count": 20, "category_keys": ["Türkçe"]}, {"id": "revolution_history", "name_tr": "T.C. İnkılap Tarihi", "name_en": "Turkish Revolution History", "question_count": 10, "category_keys": ["T.C. İnkılap Tarihi"]}, {"id": "religion", "name_tr": "Din Kültürü", "name_en": "Religious Culture", "question_count": 10, "category_keys": ["Din Kültürü"]}, {"id": "foreign_language", "name_tr": "Yabancı Dil", "name_en": "Foreign Language", "question_count": 10, "category_keys": ["İngilizce"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('lgs_quantitative','{"id": "lgs_quantitative", "name_tr": "LGS Sayısal", "name_en": "LGS Quantitative", "segment": "lgs", "group": "lgs", "duration_seconds": 4800, "total_questions": 40, "wrong_answer_divisor": 3, "catalog_version": 1, "reward_points": 16, "reward_coins": 3, "subjects": [{"id": "mathematics", "name_tr": "Matematik", "name_en": "Mathematics", "question_count": 20, "category_keys": ["Matematik"]}, {"id": "science", "name_tr": "Fen Bilimleri", "name_en": "Science", "question_count": 20, "category_keys": ["Fen Bilimleri"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('tus_basic','{"id": "tus_basic", "name_tr": "TUS Temel Tıp", "name_en": "TUS Basic Medicine", "segment": "tus", "group": "tus", "duration_seconds": 8100, "total_questions": 100, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 27, "reward_coins": 5, "subjects": [{"id": "anatomy", "name_tr": "Anatomi", "name_en": "Anatomy", "question_count": 13, "category_keys": ["Anatomi"]}, {"id": "histology_embryology", "name_tr": "Histoloji ve Embriyoloji", "name_en": "Histology and Embryology", "question_count": 7, "category_keys": ["Fizyoloji, Histoloji ve Embriyoloji"]}, {"id": "physiology", "name_tr": "Fizyoloji", "name_en": "Physiology", "question_count": 8, "category_keys": ["Fizyoloji, Histoloji ve Embriyoloji"]}, {"id": "biochemistry", "name_tr": "Biyokimya", "name_en": "Biochemistry", "question_count": 18, "category_keys": ["Biyokimya"]}, {"id": "microbiology", "name_tr": "Mikrobiyoloji", "name_en": "Microbiology", "question_count": 18, "category_keys": ["Mikrobiyoloji"]}, {"id": "pathology", "name_tr": "Patoloji", "name_en": "Pathology", "question_count": 18, "category_keys": ["Patoloji"]}, {"id": "pharmacology", "name_tr": "Farmakoloji", "name_en": "Pharmacology", "question_count": 18, "category_keys": ["Farmakoloji"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('tus_clinical','{"id": "tus_clinical", "name_tr": "TUS Klinik Tıp", "name_en": "TUS Clinical Medicine", "segment": "tus", "group": "tus", "duration_seconds": 8100, "total_questions": 100, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 27, "reward_coins": 5, "subjects": [{"id": "internal_medicine_group", "name_tr": "Dahiliye Grubu", "name_en": "Internal Medicine Group", "question_count": 35, "category_keys": ["Dahiliye"]}, {"id": "pediatrics", "name_tr": "Pediatri", "name_en": "Pediatrics", "question_count": 25, "category_keys": ["Pediatri"]}, {"id": "surgery_group", "name_tr": "Cerrahi Grubu", "name_en": "Surgery Group", "question_count": 30, "category_keys": ["Genel Cerrahi"]}, {"id": "obstetrics_gynecology", "name_tr": "Kadın Hastalıkları ve Doğum", "name_en": "Obstetrics and Gynecology", "question_count": 10, "category_keys": ["Kadın Hastalıkları ve Doğum"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('dus','{"id": "dus", "name_tr": "DUS", "name_en": "DUS", "segment": "dus", "group": "dus", "duration_seconds": 9000, "total_questions": 120, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 30, "reward_coins": 6, "subjects": [{"id": "anatomy", "name_tr": "Anatomi", "name_en": "Anatomy", "question_count": 6, "category_keys": ["Anatomi"]}, {"id": "histology_embryology", "name_tr": "Histoloji ve Embriyoloji", "name_en": "Histology and Embryology", "question_count": 4, "category_keys": ["Histoloji ve Embriyoloji"]}, {"id": "physiology", "name_tr": "Fizyoloji", "name_en": "Physiology", "question_count": 6, "category_keys": ["Fizyoloji"]}, {"id": "biochemistry", "name_tr": "Tıbbi Biyokimya", "name_en": "Medical Biochemistry", "question_count": 6, "category_keys": ["Biyokimya"]}, {"id": "microbiology", "name_tr": "Tıbbi Mikrobiyoloji", "name_en": "Medical Microbiology", "question_count": 6, "category_keys": ["Mikrobiyoloji"]}, {"id": "pathology", "name_tr": "Tıbbi Patoloji", "name_en": "Medical Pathology", "question_count": 4, "category_keys": ["Patoloji"]}, {"id": "pharmacology", "name_tr": "Tıbbi Farmakoloji", "name_en": "Medical Pharmacology", "question_count": 4, "category_keys": ["Farmakoloji"]}, {"id": "medical_biology_genetics", "name_tr": "Tıbbi Biyoloji ve Genetik", "name_en": "Medical Biology and Genetics", "question_count": 4, "category_keys": ["Tıbbi Biyoloji ve Genetik"]}, {"id": "restorative_dentistry", "name_tr": "Restoratif Diş Tedavisi", "name_en": "Restorative Dentistry", "question_count": 10, "category_keys": ["Restoratif Diş Tedavisi"]}, {"id": "prosthetic_dentistry", "name_tr": "Protetik Diş Tedavisi", "name_en": "Prosthodontics", "question_count": 10, "category_keys": ["Protetik Diş Tedavisi"]}, {"id": "oral_maxillofacial_surgery", "name_tr": "Ağız, Diş ve Çene Cerrahisi", "name_en": "Oral and Maxillofacial Surgery", "question_count": 10, "category_keys": ["Ağız, Diş ve Çene Cerrahisi"]}, {"id": "oral_maxillofacial_radiology", "name_tr": "Ağız, Diş ve Çene Radyolojisi", "name_en": "Oral and Maxillofacial Radiology", "question_count": 10, "category_keys": ["Ağız, Diş ve Çene Radyolojisi"]}, {"id": "periodontology", "name_tr": "Periodontoloji", "name_en": "Periodontology", "question_count": 10, "category_keys": ["Periodontoloji"]}, {"id": "orthodontics", "name_tr": "Ortodonti", "name_en": "Orthodontics", "question_count": 10, "category_keys": ["Ortodonti"]}, {"id": "endodontics", "name_tr": "Endodonti", "name_en": "Endodontics", "question_count": 10, "category_keys": ["Endodonti"]}, {"id": "pediatric_dentistry", "name_tr": "Çocuk Diş Hekimliği", "name_en": "Pediatric Dentistry", "question_count": 10, "category_keys": ["Çocuk Diş Hekimliği"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('kpss_bachelor_gygk','{"id": "kpss_bachelor_gygk", "name_tr": "KPSS Lisans · Genel Yetenek–Genel Kültür", "name_en": "KPSS Bachelor’s · General Ability–General Knowledge", "segment": "kpss", "group": "kpss", "duration_seconds": 7800, "total_questions": 120, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 26, "reward_coins": 5, "subjects": [{"id": "general_ability", "name_tr": "Genel Yetenek", "name_en": "General Ability", "question_count": 60, "category_keys": ["Türkçe", "Matematik", "Genel Yetenek"]}, {"id": "general_knowledge", "name_tr": "Genel Kültür", "name_en": "General Knowledge", "question_count": 60, "category_keys": ["Tarih", "Coğrafya", "Vatandaşlık", "Güncel Bilgiler", "Genel Kültür"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('kpss_associate_gygk','{"id": "kpss_associate_gygk", "name_tr": "KPSS Ön Lisans · Genel Yetenek–Genel Kültür", "name_en": "KPSS Associate Degree · General Ability–General Knowledge", "segment": "kpss", "group": "kpss", "duration_seconds": 7800, "total_questions": 120, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 26, "reward_coins": 5, "subjects": [{"id": "general_ability", "name_tr": "Genel Yetenek", "name_en": "General Ability", "question_count": 60, "category_keys": ["Türkçe", "Matematik", "Genel Yetenek"]}, {"id": "general_knowledge", "name_tr": "Genel Kültür", "name_en": "General Knowledge", "question_count": 60, "category_keys": ["Tarih", "Coğrafya", "Vatandaşlık", "Güncel Bilgiler", "Genel Kültür"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('kpss_secondary_gygk','{"id": "kpss_secondary_gygk", "name_tr": "KPSS Ortaöğretim · Genel Yetenek–Genel Kültür", "name_en": "KPSS Secondary Education · General Ability–General Knowledge", "segment": "kpss", "group": "kpss", "duration_seconds": 7800, "total_questions": 120, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 26, "reward_coins": 5, "subjects": [{"id": "general_ability", "name_tr": "Genel Yetenek", "name_en": "General Ability", "question_count": 60, "category_keys": ["Türkçe", "Matematik", "Genel Yetenek"]}, {"id": "general_knowledge", "name_tr": "Genel Kültür", "name_en": "General Knowledge", "question_count": 60, "category_keys": ["Tarih", "Coğrafya", "Vatandaşlık", "Güncel Bilgiler", "Genel Kültür"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('kpss_field_business','{"id": "kpss_field_business", "name_tr": "KPSS Alan Bilgisi · İşletme", "name_en": "KPSS Field Knowledge · Business Administration", "segment": "kpss", "group": "kpss", "duration_seconds": 3000, "total_questions": 40, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 10, "reward_coins": 2, "subjects": [{"id": "business", "name_tr": "İşletme", "name_en": "Business Administration", "question_count": 40, "category_keys": ["İşletme"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('kpss_field_accounting','{"id": "kpss_field_accounting", "name_tr": "KPSS Alan Bilgisi · Muhasebe", "name_en": "KPSS Field Knowledge · Accounting", "segment": "kpss", "group": "kpss", "duration_seconds": 3000, "total_questions": 40, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 10, "reward_coins": 2, "subjects": [{"id": "accounting", "name_tr": "Muhasebe", "name_en": "Accounting", "question_count": 40, "category_keys": ["Muhasebe"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('kpss_field_law','{"id": "kpss_field_law", "name_tr": "KPSS Alan Bilgisi · Hukuk", "name_en": "KPSS Field Knowledge · Law", "segment": "kpss", "group": "kpss", "duration_seconds": 3000, "total_questions": 40, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 10, "reward_coins": 2, "subjects": [{"id": "law", "name_tr": "Hukuk", "name_en": "Law", "question_count": 40, "category_keys": ["Hukuk"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('kpss_field_public_administration','{"id": "kpss_field_public_administration", "name_tr": "KPSS Alan Bilgisi · Kamu Yönetimi", "name_en": "KPSS Field Knowledge · Public Administration", "segment": "kpss", "group": "kpss", "duration_seconds": 3000, "total_questions": 40, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 10, "reward_coins": 2, "subjects": [{"id": "public_administration", "name_tr": "Kamu Yönetimi", "name_en": "Public Administration", "question_count": 40, "category_keys": ["Kamu Yönetimi"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('kpss_field_economics','{"id": "kpss_field_economics", "name_tr": "KPSS Alan Bilgisi · İktisat", "name_en": "KPSS Field Knowledge · Economics", "segment": "kpss", "group": "kpss", "duration_seconds": 3000, "total_questions": 40, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 10, "reward_coins": 2, "subjects": [{"id": "economics", "name_tr": "İktisat", "name_en": "Economics", "question_count": 40, "category_keys": ["İktisat"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('kpss_field_finance','{"id": "kpss_field_finance", "name_tr": "KPSS Alan Bilgisi · Maliye", "name_en": "KPSS Field Knowledge · Public Finance", "segment": "kpss", "group": "kpss", "duration_seconds": 3000, "total_questions": 40, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 10, "reward_coins": 2, "subjects": [{"id": "finance", "name_tr": "Maliye", "name_en": "Public Finance", "question_count": 40, "category_keys": ["Maliye"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('kpss_field_international_relations','{"id": "kpss_field_international_relations", "name_tr": "KPSS Alan Bilgisi · Uluslararası İlişkiler", "name_en": "KPSS Field Knowledge · International Relations", "segment": "kpss", "group": "kpss", "duration_seconds": 3000, "total_questions": 40, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 10, "reward_coins": 2, "subjects": [{"id": "international_relations", "name_tr": "Uluslararası İlişkiler", "name_en": "International Relations", "question_count": 40, "category_keys": ["Uluslararası İlişkiler"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('kpss_field_labour_economics','{"id": "kpss_field_labour_economics", "name_tr": "KPSS Alan Bilgisi · Çalışma Ekonomisi ve Endüstri İlişkileri", "name_en": "KPSS Field Knowledge · Labour Economics and Industrial Relations", "segment": "kpss", "group": "kpss", "duration_seconds": 3000, "total_questions": 40, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 10, "reward_coins": 2, "subjects": [{"id": "labour_economics", "name_tr": "Çalışma Ekonomisi ve Endüstri İlişkileri", "name_en": "Labour Economics and Industrial Relations", "question_count": 40, "category_keys": ["Çalışma Ekonomisi ve Endüstri İlişkileri"]}]}'::jsonb);
INSERT INTO public.exam_catalog(id,definition) VALUES ('kpss_field_statistics','{"id": "kpss_field_statistics", "name_tr": "KPSS Alan Bilgisi · İstatistik", "name_en": "KPSS Field Knowledge · Statistics", "segment": "kpss", "group": "kpss", "duration_seconds": 3600, "total_questions": 40, "wrong_answer_divisor": 4, "catalog_version": 1, "reward_points": 12, "reward_coins": 2, "subjects": [{"id": "statistics", "name_tr": "İstatistik", "name_en": "Statistics", "question_count": 40, "category_keys": ["İstatistik"]}]}'::jsonb);
CREATE FUNCTION public._exam_payload(p_id uuid) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT jsonb_build_object('id',a.id,'client_uuid',a.client_uuid,'exam_id',a.exam_id,'catalog_version',(a.definition->>'catalog_version')::integer,
 'name_tr',a.definition->>'name_tr','name_en',a.definition->>'name_en','started_at',a.started_at,'ends_at',a.ends_at,
 'finished_at',a.finished_at,'completed_at',CASE WHEN a.status='completed' THEN a.finished_at END,
 'status',a.status,'duration_seconds',(a.definition->>'duration_seconds')::integer,'total_questions',(a.definition->>'total_questions')::integer,
 'wrong_answer_divisor',(a.definition->>'wrong_answer_divisor')::integer,'elapsed_seconds',a.elapsed_seconds,
 'points_earned',a.points_earned,'exam_coins_earned',a.exam_coins_earned,'definition',a.definition,'subjects',a.definition->'subjects',
 'subject_results',coalesce((SELECT jsonb_agg(jsonb_build_object('subject_id',r.subject_id,'correct',r.correct,'wrong',r.wrong,'blank',r.blank,'net',r.net) ORDER BY r.subject_id) FROM public.exam_subject_results r WHERE r.attempt_id=a.id),'[]'::jsonb))
 FROM public.exam_attempts a WHERE a.id=p_id
$$;
CREATE FUNCTION public.get_exam_config() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT jsonb_build_object('schema_version',1,'available',to_regprocedure('public.get_my_exam_league_ranking(text)') IS NOT NULL,
 'server_time',clock_timestamp(),'exams',coalesce((SELECT jsonb_agg(definition ORDER BY id) FROM public.exam_catalog WHERE enabled),'[]'::jsonb))
$$;
CREATE FUNCTION public._exam_has_overlap(p_user uuid,p_start timestamptz,p_end timestamptz) RETURNS boolean
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT EXISTS(SELECT 1 FROM public.exam_attempts a WHERE a.user_id=p_user AND a.status IN('active','completed') AND a.started_at<p_end AND a.ends_at>p_start)
$$;
CREATE FUNCTION public._exam_guard_study_insert() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 PERFORM 1 FROM public.profiles WHERE id=NEW.user_id FOR UPDATE;
 IF public._exam_has_overlap(NEW.user_id,NEW.started_at,NEW.completed_at) THEN RAISE EXCEPTION 'exam_overlap'; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER exam_guard_normal_study BEFORE INSERT ON public.study_sessions FOR EACH ROW EXECUTE FUNCTION public._exam_guard_study_insert();
CREATE OR REPLACE FUNCTION public.start_study_session(p_duration_minutes integer,p_category_name text)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_name text;v_now timestamptz;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 IF p_duration_minutes IS NULL OR p_duration_minutes<0 OR p_duration_minutes>50 THEN RAISE EXCEPTION 'invalid duration: 0..50 minutes allowed'; END IF;
 PERFORM 1 FROM public.profiles WHERE id=auth.uid() FOR UPDATE;
 v_now:=clock_timestamp();
 IF p_duration_minutes>0 AND public._exam_has_overlap(auth.uid(),v_now,v_now+make_interval(mins=>p_duration_minutes)) THEN RAISE EXCEPTION 'exam_overlap'; END IF;
 v_name:=nullif(btrim(left(public.clean_display_text(p_category_name),40)),'');
 IF v_name IS NOT NULL AND NOT public.display_text_is_allowed(v_name) THEN v_name:=NULL; END IF;
 UPDATE public.profiles SET active_session_ends_at=v_now+make_interval(mins=>p_duration_minutes),active_session_category_name=v_name,active_break_ends_at=NULL WHERE id=auth.uid();
END $$;
CREATE FUNCTION public.start_exam_attempt(p_client_uuid uuid,p_exam_id text) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_uid uuid:=auth.uid();v_id uuid;v_existing record;v_expired record;v_definition jsonb;v_now timestamptz;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 IF p_client_uuid IS NULL OR p_exam_id IS NULL THEN RAISE EXCEPTION 'exam_metadata_conflict'; END IF;
 PERFORM 1 FROM public.profiles WHERE id=v_uid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'not authenticated'; END IF;
 SELECT * INTO v_existing FROM public.exam_attempts WHERE user_id=v_uid AND client_uuid=p_client_uuid;
 IF FOUND THEN
  IF v_existing.exam_id<>p_exam_id THEN RAISE EXCEPTION 'exam_metadata_conflict'; END IF;
  -- D-05: a lost completion reply/local journal must not leave an expired
  -- attempt active forever. Keep the original UUID and frozen reward rule.
  IF v_existing.status='active' AND v_existing.ends_at<=clock_timestamp() THEN
   PERFORM public.complete_exam_attempt(v_existing.id);
  END IF;
  RETURN jsonb_build_object('server_time',clock_timestamp(),'duplicate',true,'attempt',public._exam_payload(v_existing.id));
 END IF;
 IF to_regprocedure('public.get_my_exam_league_ranking(text)') IS NULL THEN RAISE EXCEPTION 'exam_unavailable'; END IF;
 SELECT definition INTO v_definition FROM public.exam_catalog WHERE id=p_exam_id AND enabled;
 IF NOT FOUND THEN RAISE EXCEPTION 'exam_unavailable'; END IF;
 v_now:=clock_timestamp();
 FOR v_expired IN SELECT id FROM public.exam_attempts WHERE user_id=v_uid AND status='active' AND ends_at<=v_now FOR UPDATE LOOP
  PERFORM public.complete_exam_attempt(v_expired.id);
 END LOOP;
 v_now:=clock_timestamp();
 IF EXISTS(SELECT 1 FROM public.exam_attempts WHERE user_id=v_uid AND status='active')
 OR EXISTS(SELECT 1 FROM public.profiles WHERE id=v_uid AND active_session_ends_at>v_now)
 OR EXISTS(SELECT 1 FROM public.study_sessions WHERE user_id=v_uid AND started_at<v_now+make_interval(secs=>(v_definition->>'duration_seconds')::integer) AND completed_at>v_now)
 THEN RAISE EXCEPTION 'exam_overlap'; END IF;
 INSERT INTO public.exam_attempts(user_id,client_uuid,exam_id,definition,started_at,ends_at)
 VALUES(v_uid,p_client_uuid,p_exam_id,v_definition,v_now,v_now+make_interval(secs=>(v_definition->>'duration_seconds')::integer)) RETURNING id INTO v_id;
 -- Presence is sourced from the attempt, never a mutable profile flag.
 UPDATE public.profiles SET active_session_ends_at=NULL,active_session_category_name=NULL,active_break_ends_at=NULL WHERE id=v_uid;
 RETURN jsonb_build_object('server_time',clock_timestamp(),'duplicate',false,'attempt',public._exam_payload(v_id));
END $$;
CREATE FUNCTION public.complete_exam_attempt(p_attempt_id uuid) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_uid uuid:=auth.uid();a public.exam_attempts%ROWTYPE;v_now timestamptz;v_day date;v_profile record;v_streak integer;v_duration integer;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 PERFORM 1 FROM public.profiles WHERE id=v_uid FOR UPDATE;
 SELECT * INTO a FROM public.exam_attempts WHERE id=p_attempt_id AND user_id=v_uid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'exam_not_found'; END IF;
 IF a.status='completed' THEN RETURN jsonb_build_object('server_time',clock_timestamp(),'duplicate',true,'attempt',public._exam_payload(a.id)); END IF;
 IF a.status<>'active' THEN RAISE EXCEPTION 'exam_not_active'; END IF;
 v_now:=clock_timestamp();
 IF v_now<a.ends_at THEN RAISE EXCEPTION 'exam_not_elapsed'; END IF;
 v_duration:=(a.definition->>'duration_seconds')::integer;
 IF EXISTS(SELECT 1 FROM public.study_sessions WHERE user_id=v_uid AND started_at<a.ends_at AND completed_at>a.started_at) THEN RAISE EXCEPTION 'exam_overlap'; END IF;
 SELECT * INTO v_profile FROM public.profiles WHERE id=v_uid;
 v_day:=((a.started_at AT TIME ZONE v_profile.timezone)-interval '4 hours')::date;
 v_streak:=coalesce(v_profile.current_streak,0);
 IF v_profile.last_study_date IS NULL THEN v_streak:=1;
 ELSIF v_profile.last_study_date=v_day-1 THEN v_streak:=v_streak+1;
 ELSIF v_profile.last_study_date<v_day THEN v_streak:=1; END IF;
 UPDATE public.profiles SET total_minutes=coalesce(total_minutes,0)+v_duration/60,
 current_streak=v_streak,longest_streak=greatest(coalesce(longest_streak,0),v_streak),
 last_study_date=greatest(coalesce(last_study_date,v_day),v_day) WHERE id=v_uid;
 UPDATE public.exam_attempts SET status='completed',finished_at=ends_at,elapsed_seconds=v_duration,
 points_earned=(definition->>'reward_points')::integer,exam_coins_earned=(definition->>'reward_coins')::integer WHERE id=a.id;
 INSERT INTO public.exam_wallets(user_id,coins,lifetime_points) VALUES(v_uid,(a.definition->>'reward_coins')::integer,(a.definition->>'reward_points')::integer)
 ON CONFLICT(user_id) DO UPDATE SET coins=exam_wallets.coins+EXCLUDED.coins,lifetime_points=exam_wallets.lifetime_points+EXCLUDED.lifetime_points;
 RETURN jsonb_build_object('server_time',clock_timestamp(),'duplicate',false,'attempt',public._exam_payload(a.id));
END $$;
CREATE FUNCTION public.abandon_exam_attempt(p_attempt_id uuid) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_uid uuid:=auth.uid();a public.exam_attempts%ROWTYPE;v_now timestamptz;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 PERFORM 1 FROM public.profiles WHERE id=v_uid FOR UPDATE;
 SELECT * INTO a FROM public.exam_attempts WHERE id=p_attempt_id AND user_id=v_uid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'exam_not_found'; END IF;
 IF a.status<>'active' THEN RETURN jsonb_build_object('server_time',clock_timestamp(),'duplicate',true,'attempt',public._exam_payload(a.id)); END IF;
 v_now:=clock_timestamp();
 IF v_now>=a.ends_at THEN RETURN public.complete_exam_attempt(a.id); END IF;
 UPDATE public.exam_attempts SET status='abandoned',finished_at=v_now,elapsed_seconds=greatest(0,floor(extract(epoch FROM(v_now-started_at)))::integer) WHERE id=a.id;
 RETURN jsonb_build_object('server_time',clock_timestamp(),'duplicate',false,'attempt',public._exam_payload(a.id));
END $$;
CREATE FUNCTION public.get_my_exam_attempts(p_limit integer DEFAULT 100,p_before timestamptz DEFAULT NULL) RETURNS jsonb
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_rows jsonb;v_cursor timestamptz;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 SELECT coalesce(jsonb_agg(public._exam_payload(q.id) ORDER BY(q.status='active') DESC,q.started_at DESC,q.id),'[]'::jsonb),min(q.started_at)
 INTO v_rows,v_cursor FROM(SELECT id,status,started_at FROM public.exam_attempts WHERE user_id=auth.uid() AND(p_before IS NULL OR started_at<p_before)
 ORDER BY(status='active') DESC,started_at DESC,id LIMIT greatest(1,least(coalesce(p_limit,100),1000))) q;
 RETURN jsonb_build_object('server_time',clock_timestamp(),'attempts',v_rows,'next_cursor',v_cursor);
END $$;
CREATE FUNCTION public.get_my_study_sessions_v2(p_since timestamptz DEFAULT NULL,p_limit integer DEFAULT 1000,p_offset integer DEFAULT 0) RETURNS jsonb
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_rows jsonb;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 SELECT coalesce(jsonb_agg(q.payload ORDER BY q.started_at DESC,q.id),'[]'::jsonb) INTO v_rows FROM(
 SELECT s.id,s.started_at,to_jsonb(s)||jsonb_build_object('session_kind',CASE WHEN m.study_session_id IS NULL THEN 'normal' ELSE 'marathon' END,'marathon_uuid',m.marathon_uuid,'marathon_target_sessions',r.target_sessions,'marathon_session_index',m.session_index,
 'marathon_completed_at',CASE WHEN NOT r.is_invalid AND (SELECT count(*) FROM public.marathon_run_sessions allm WHERE allm.user_id=r.user_id AND allm.marathon_uuid=r.client_uuid)=r.target_sessions THEN (SELECT max(alls.completed_at) FROM public.marathon_run_sessions allm JOIN public.study_sessions alls ON alls.id=allm.study_session_id WHERE allm.user_id=r.user_id AND allm.marathon_uuid=r.client_uuid) END)payload
 FROM public.study_sessions s LEFT JOIN public.marathon_run_sessions m ON m.user_id=s.user_id AND m.study_session_id=s.id LEFT JOIN public.marathon_runs r ON r.user_id=m.user_id AND r.client_uuid=m.marathon_uuid
 WHERE s.user_id=auth.uid() AND(p_since IS NULL OR coalesce(s.started_at,s.completed_at)>=p_since)
 ORDER BY s.started_at DESC,s.id LIMIT greatest(1,least(coalesce(p_limit,1000),1000))OFFSET greatest(0,coalesce(p_offset,0)))q;
 RETURN v_rows;
END $$;
CREATE FUNCTION public.save_exam_results(p_attempt_id uuid,p_subject_results jsonb) RETURNS jsonb
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_uid uuid:=auth.uid();a public.exam_attempts%ROWTYPE;r jsonb;s jsonb;c integer;w integer;b integer;seen text[]:=ARRAY[]::text[];sid text;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 PERFORM 1 FROM public.profiles WHERE id=v_uid FOR UPDATE;
 SELECT * INTO a FROM public.exam_attempts WHERE id=p_attempt_id AND user_id=v_uid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'exam_not_found'; END IF;
 IF a.status<>'completed' THEN RAISE EXCEPTION 'exam_not_active'; END IF;
 IF p_subject_results IS NULL OR jsonb_typeof(p_subject_results)<>'array' OR jsonb_array_length(p_subject_results)>100 THEN RAISE EXCEPTION 'exam_result_invalid'; END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(p_subject_results) LOOP
  sid:=r->>'subject_id';
  IF sid IS NULL OR sid=ANY(seen) OR jsonb_typeof(r)<>'object' OR EXISTS(SELECT 1 FROM jsonb_object_keys(r) k WHERE k NOT IN('subject_id','correct','wrong','blank')) THEN RAISE EXCEPTION 'exam_result_invalid'; END IF;
  SELECT value INTO s FROM jsonb_array_elements(a.definition->'subjects') WHERE value->>'id'=sid;
  IF NOT FOUND THEN RAISE EXCEPTION 'exam_result_invalid'; END IF;
  IF coalesce(r->>'correct','') !~ '^[0-9]{1,4}$' OR coalesce(r->>'wrong','') !~ '^[0-9]{1,4}$' OR coalesce(r->>'blank','') !~ '^[0-9]{1,4}$'
    OR jsonb_typeof(r->'correct')<>'number' OR jsonb_typeof(r->'wrong')<>'number' OR jsonb_typeof(r->'blank')<>'number' THEN RAISE EXCEPTION 'exam_result_invalid'; END IF;
  c:=(r->>'correct')::int;w:=(r->>'wrong')::int;b:=(r->>'blank')::int;
  IF c+w+b<>(s->>'question_count')::int THEN RAISE EXCEPTION 'exam_result_invalid'; END IF;
  INSERT INTO public.exam_subject_results(attempt_id,subject_id,correct,wrong,blank,net) VALUES(a.id,sid,c,w,b,c-w/(a.definition->>'wrong_answer_divisor')::numeric)
  ON CONFLICT(attempt_id,subject_id) DO UPDATE SET correct=EXCLUDED.correct,wrong=EXCLUDED.wrong,blank=EXCLUDED.blank,net=EXCLUDED.net,updated_at=clock_timestamp();
  seen:=array_append(seen,sid);
 END LOOP;
 RETURN jsonb_build_object('server_time',clock_timestamp(),'duplicate',false,'attempt',public._exam_payload(a.id));
END $$;
INSERT INTO public.exam_install_backup SELECT 'public.get_live_friends_with_breaks()',pg_get_functiondef('public.get_live_friends_with_breaks()'::regprocedure);
CREATE OR REPLACE FUNCTION public.get_live_friends_with_breaks() RETURNS jsonb
 LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_uid uuid:=auth.uid();v_result jsonb;
BEGIN
 IF v_uid IS NULL THEN RETURN '[]'::jsonb; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'avatar_id',p.avatar_id,
 'category_name',CASE WHEN e.id IS NULL AND p.active_session_ends_at>now() THEN p.active_session_category_name END,
 'ends_at',coalesce(e.ends_at,CASE WHEN p.active_session_ends_at>now() THEN p.active_session_ends_at ELSE p.active_break_ends_at END),
 'status',CASE WHEN e.id IS NOT NULL THEN 'exam' WHEN p.active_session_ends_at>now() THEN 'focus' ELSE 'break' END,
 'exam_type',e.exam_id,'exam_name_tr',e.definition->>'name_tr','exam_name_en',e.definition->>'name_en') ORDER BY p.id),'[]'::jsonb)
 INTO v_result FROM public.profiles p LEFT JOIN public.exam_attempts e ON e.user_id=p.id AND e.status='active' AND e.ends_at>now()
 WHERE p.id<>v_uid AND p.show_in_social_feed AND(e.id IS NOT NULL OR p.active_session_ends_at>now() OR p.active_break_ends_at>now())
 AND EXISTS(SELECT 1 FROM public.friendships f WHERE f.status='accepted' AND((f.user_id=v_uid AND f.friend_id=p.id) OR(f.friend_id=v_uid AND f.user_id=p.id)))
 AND NOT EXISTS(SELECT 1 FROM public.user_blocks b WHERE(b.blocker_id=v_uid AND b.blocked_id=p.id) OR(b.blocker_id=p.id AND b.blocked_id=v_uid));
 RETURN v_result;
END $$;
-- Store the original social function too, for exact rollback.
-- Its definition is inserted by the generator BEFORE the replacement above.
DO $$ DECLARE r regprocedure; BEGIN
 FOR r IN SELECT p.oid::regprocedure FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND(p.proname LIKE '\_exam\_%' ESCAPE '\' OR p.proname IN('get_exam_config','start_exam_attempt','complete_exam_attempt','abandon_exam_attempt','get_my_exam_attempts','get_my_study_sessions_v2','save_exam_results')) LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role',r);
 END LOOP;
END $$;
GRANT EXECUTE ON FUNCTION public.get_exam_config() TO anon,authenticated;
GRANT EXECUTE ON FUNCTION public.start_exam_attempt(uuid,text),public.complete_exam_attempt(uuid),public.abandon_exam_attempt(uuid),public.get_my_exam_attempts(integer,timestamptz),public.save_exam_results(uuid,jsonb),public.get_my_study_sessions_v2(timestamptz,integer,integer) TO authenticated;
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261028020000','exam_core');
NOTIFY pgrst,'reload schema';
-- END 28_exam_core

-- START 29_monthly_competitions
-- PROPOSED ONLY: unified monthly study/exam, segment rooms and global views.
-- Requires 27 then 28. Preserves legacy leagues/economy and existing earned awards.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261028020000') THEN RAISE EXCEPTION 'competition_requires_exam_core'; END IF;
 IF to_regclass('public.competition_policy') IS NOT NULL THEN RAISE EXCEPTION 'competition_already_installed'; END IF;
 IF md5(pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure))<>'72023f3f4d8636363cf0231f42d4c7e1' THEN RAISE EXCEPTION 'competition_normal_precondition_changed'; END IF;
END $$;
CREATE TABLE public.competition_install_backup(signature text PRIMARY KEY,definition text NOT NULL);
ALTER TABLE public.competition_install_backup ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.competition_install_backup FROM PUBLIC,anon,authenticated,service_role;
INSERT INTO public.competition_install_backup SELECT p.oid::regprocedure::text,pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN('complete_study_session','process_weekly_leagues','get_my_league_ranking_v2','get_league_config','get_public_monthly_leaderboard','get_league_ranking','get_my_league_ranking','ensure_user_in_league');
CREATE FUNCTION public._competition_month(p_at timestamptz) RETURNS date LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $$ SELECT date_trunc('month',p_at AT TIME ZONE 'Europe/Istanbul')::date $$;
CREATE FUNCTION public._competition_month_time(p_month date) RETURNS timestamptz LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $$ SELECT p_month::timestamp AT TIME ZONE 'Europe/Istanbul' $$;
CREATE TABLE public.competition_policy(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),activates_at timestamptz NOT NULL,legacy_finalized boolean NOT NULL DEFAULT false,legacy_snapshot jsonb NOT NULL,legacy_decisions jsonb NOT NULL DEFAULT '[]'::jsonb);
INSERT INTO public.competition_policy(singleton,activates_at,legacy_snapshot) SELECT true,public._competition_month_time((public._competition_month(now())+interval '1 month')::date),jsonb_build_object('state',(SELECT jsonb_build_object('start_at',s.start_at,'initialized',s.initialized,'period_started_at',s.period_started_at) FROM public.league_competition_state s WHERE singleton),'rooms',coalesce((SELECT jsonb_agg(to_jsonb(l)) FROM public.leagues l),'[]'::jsonb),'members',coalesce((SELECT jsonb_agg(to_jsonb(m)) FROM public.league_memberships m),'[]'::jsonb),'cron',coalesce((SELECT jsonb_agg(to_jsonb(j)) FROM cron.job j WHERE jobname='weekly_leagues_job'),'[]'::jsonb));
CREATE TABLE public.competition_target_history(user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,from_month date NOT NULL,segment text NOT NULL CHECK(segment IN('lgs','yks','tus','dus','kpss','language','university','work','other')),PRIMARY KEY(user_id,from_month));
INSERT INTO public.competition_target_history SELECT id,public._competition_month(now()),coalesce(user_segment,'other') FROM public.profiles;
CREATE TABLE public.competition_profiles(user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,kind text NOT NULL CHECK(kind IN('study','exam')),tier integer NOT NULL CHECK(tier BETWEEN 1 AND 5),PRIMARY KEY(user_id,kind));
INSERT INTO public.competition_profiles SELECT id,'study',league_tier FROM public.profiles;
CREATE TABLE public.competition_rooms(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),kind text NOT NULL CHECK(kind IN('study','exam')),period_month date NOT NULL,segment text NOT NULL,tier integer NOT NULL CHECK(tier BETWEEN 1 AND 5),created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX competition_room_lookup ON public.competition_rooms(kind,period_month,segment,tier,created_at);
CREATE TABLE public.competition_memberships(user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,kind text NOT NULL CHECK(kind IN('study','exam')),period_month date NOT NULL,room_id uuid NOT NULL REFERENCES public.competition_rooms(id),joined_at timestamptz NOT NULL,PRIMARY KEY(user_id,kind,period_month));
CREATE INDEX competition_members_by_room ON public.competition_memberships(room_id);
CREATE TABLE public.competition_events(kind text NOT NULL CHECK(kind IN('study','exam')),source_id uuid NOT NULL,user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,completed_at timestamptz NOT NULL,period_month date NOT NULL,points integer NOT NULL CHECK(points>=0),minutes integer NOT NULL CHECK(minutes>0),study_day date NOT NULL,PRIMARY KEY(kind,source_id));
CREATE INDEX competition_events_period_owner ON public.competition_events(period_month,kind,user_id);
CREATE TABLE public.competition_results(user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,kind text NOT NULL,period_month date NOT NULL,rank integer NOT NULL,from_tier integer NOT NULL,to_tier integer NOT NULL,award_id text REFERENCES public.avatars(id),snapshot jsonb NOT NULL,PRIMARY KEY(user_id,kind,period_month));
CREATE TABLE public.competition_periods(period_month date PRIMARY KEY,processed_at timestamptz NOT NULL);
CREATE TABLE public.competition_avatar_rewards(kind text NOT NULL CHECK(kind IN('study','exam')),tier integer NOT NULL CHECK(tier BETWEEN 1 AND 5),rank_position integer NOT NULL CHECK(rank_position BETWEEN 1 AND 3),avatar_id text REFERENCES public.avatars(id),PRIMARY KEY(kind,tier,rank_position));
INSERT INTO public.competition_avatar_rewards SELECT 'study',t,p,public.league_award_avatar_id(t,p) FROM generate_series(1,5)t CROSS JOIN generate_series(1,3)p;
INSERT INTO public.competition_avatar_rewards SELECT 'exam',t,p,NULL FROM generate_series(1,5)t CROSS JOIN generate_series(1,3)p;
DO $$ DECLARE n text; BEGIN FOREACH n IN ARRAY ARRAY['competition_policy','competition_target_history','competition_profiles','competition_rooms','competition_memberships','competition_events','competition_results','competition_periods','competition_avatar_rewards'] LOOP EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',n);EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated,service_role',n);END LOOP;END $$;
CREATE FUNCTION public._competition_purge_deleted_identity() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 UPDATE public.competition_policy SET legacy_snapshot=jsonb_set(jsonb_set(legacy_snapshot,'{members}',coalesce((SELECT jsonb_agg(x)FROM jsonb_array_elements(coalesce(legacy_snapshot->'members','[]'::jsonb))x WHERE x->>'user_id' IS DISTINCT FROM OLD.id::text),'[]'::jsonb)),'{final_members}',coalesce((SELECT jsonb_agg(x)FROM jsonb_array_elements(coalesce(legacy_snapshot->'final_members','[]'::jsonb))x WHERE x->>'user_id' IS DISTINCT FROM OLD.id::text),'[]'::jsonb)),legacy_decisions=coalesce((SELECT jsonb_agg(x)FROM jsonb_array_elements(legacy_decisions)x WHERE x->>'user_id' IS DISTINCT FROM OLD.id::text),'[]'::jsonb) WHERE singleton;
 RETURN OLD;
END $$;
CREATE TRIGGER competition_delete_identity BEFORE DELETE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public._competition_purge_deleted_identity();
CREATE FUNCTION public._competition_segment(p_user uuid,p_month date) RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$ SELECT coalesce((SELECT h.segment FROM public.competition_target_history h WHERE h.user_id=p_user AND h.from_month<=p_month ORDER BY h.from_month DESC LIMIT 1),(SELECT coalesce(p.user_segment,'other') FROM public.profiles p WHERE p.id=p_user),'other') $$;
CREATE FUNCTION public._competition_track_target() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_month date:=public._competition_month(clock_timestamp());
BEGIN
 IF TG_OP='UPDATE' AND NEW.user_segment IS NOT DISTINCT FROM OLD.user_segment THEN RETURN NEW; END IF;
 IF coalesce(NEW.lifetime_points,0)>0 OR NEW.active_session_ends_at>clock_timestamp() OR EXISTS(SELECT 1 FROM public.study_sessions WHERE user_id=NEW.id) OR EXISTS(SELECT 1 FROM public.exam_attempts WHERE user_id=NEW.id) THEN v_month:=(v_month+interval '1 month')::date; END IF;
 INSERT INTO public.competition_target_history(user_id,from_month,segment) VALUES(NEW.id,v_month,coalesce(NEW.user_segment,'other')) ON CONFLICT(user_id,from_month) DO UPDATE SET segment=EXCLUDED.segment;
 RETURN NEW;
END $$;
CREATE TRIGGER competition_target_change AFTER INSERT OR UPDATE OF user_segment ON public.profiles FOR EACH ROW EXECUTE FUNCTION public._competition_track_target();
CREATE FUNCTION public.get_competition_target() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_month date:=public._competition_month(now());v_pending record;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 SELECT h.* INTO v_pending FROM public.competition_target_history h WHERE h.user_id=auth.uid() AND h.from_month>v_month ORDER BY h.from_month LIMIT 1;
 RETURN jsonb_build_object('current_segment',public._competition_segment(auth.uid(),v_month),'pending_segment',v_pending.segment,'effective_at',CASE WHEN v_pending.from_month IS NOT NULL THEN public._competition_month_time(v_pending.from_month) END);
END $$;
CREATE FUNCTION public.set_competition_target(p_segment text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 IF p_segment IS NOT NULL AND p_segment NOT IN('lgs','yks','tus','dus','kpss','language','university','work','other') THEN RAISE EXCEPTION 'competition_invalid_segment'; END IF;
 PERFORM 1 FROM public.profiles WHERE id=auth.uid() FOR UPDATE;
 UPDATE public.profiles SET user_segment=nullif(p_segment,'other') WHERE id=auth.uid();
 RETURN public.get_competition_target();
END $$;
CREATE FUNCTION public._competition_place(p_user uuid,p_kind text,p_month date,p_joined timestamptz) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_segment text;v_tier integer;v_room uuid;
BEGIN
 IF EXISTS(SELECT 1 FROM public.competition_memberships WHERE user_id=p_user AND kind=p_kind AND period_month=p_month) THEN RETURN; END IF;
 v_segment:=public._competition_segment(p_user,p_month);
 INSERT INTO public.competition_profiles(user_id,kind,tier) SELECT p_user,p_kind,CASE WHEN p_kind='study' THEN league_tier ELSE 1 END FROM public.profiles WHERE id=p_user ON CONFLICT DO NOTHING;
 SELECT tier INTO v_tier FROM public.competition_profiles WHERE user_id=p_user AND kind=p_kind;
 PERFORM pg_advisory_xact_lock(hashtextextended('competition:'||p_kind||':'||p_month||':'||v_segment||':'||v_tier,0));
 SELECT r.id INTO v_room FROM public.competition_rooms r LEFT JOIN public.competition_memberships m ON m.room_id=r.id WHERE r.kind=p_kind AND r.period_month=p_month AND r.segment=v_segment AND r.tier=v_tier GROUP BY r.id HAVING count(m.user_id)<25 ORDER BY count(m.user_id) DESC,r.created_at,r.id LIMIT 1;
 IF v_room IS NULL THEN INSERT INTO public.competition_rooms(kind,period_month,segment,tier) VALUES(p_kind,p_month,v_segment,v_tier) RETURNING id INTO v_room; END IF;
 INSERT INTO public.competition_memberships(user_id,kind,period_month,room_id,joined_at) VALUES(p_user,p_kind,p_month,v_room,p_joined) ON CONFLICT DO NOTHING;
END $$;
CREATE FUNCTION public._competition_record(p_kind text,p_source uuid,p_user uuid,p_started timestamptz,p_completed timestamptz,p_minutes integer,p_points integer) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_month date:=public._competition_month(p_completed);v_day date;
BEGIN
 PERFORM 1 FROM public.profiles WHERE id=p_user FOR UPDATE;
 SELECT ((p_started AT TIME ZONE timezone)-interval '4 hours')::date INTO v_day FROM public.profiles WHERE id=p_user;
 INSERT INTO public.competition_events(kind,source_id,user_id,completed_at,period_month,points,minutes,study_day) VALUES(p_kind,p_source,p_user,p_completed,v_month,p_points,p_minutes,v_day)
 ON CONFLICT(kind,source_id) DO UPDATE SET points=EXCLUDED.points;
 IF p_points>0 THEN PERFORM public._competition_place(p_user,p_kind,v_month,p_completed); END IF;
END $$;
CREATE FUNCTION public._competition_study_event() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$ BEGIN PERFORM public._competition_record('study',NEW.id,NEW.user_id,NEW.started_at,NEW.completed_at,NEW.duration_minutes,NEW.base_points+NEW.bonus_points);RETURN NEW;END $$;
CREATE TRIGGER competition_study_accept AFTER INSERT OR UPDATE OF base_points,bonus_points ON public.study_sessions FOR EACH ROW EXECUTE FUNCTION public._competition_study_event();
CREATE FUNCTION public._competition_exam_event() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$ BEGIN IF NEW.status='completed' THEN PERFORM public._competition_record('exam',NEW.id,NEW.user_id,NEW.started_at,NEW.ends_at,(NEW.definition->>'duration_seconds')::integer/60,NEW.points_earned);END IF;RETURN NEW;END $$;
CREATE TRIGGER competition_exam_accept AFTER UPDATE OF status ON public.exam_attempts FOR EACH ROW EXECUTE FUNCTION public._competition_exam_event();
-- Existing month records are preserved as monthly events; no profile economy update.
DO $$ DECLARE r record;BEGIN FOR r IN SELECT * FROM public.study_sessions WHERE completed_at>=public._competition_month_time(public._competition_month(now())) ORDER BY completed_at,id LOOP PERFORM public._competition_record('study',r.id,r.user_id,r.started_at,r.completed_at,r.duration_minutes,r.base_points+r.bonus_points);END LOOP; FOR r IN SELECT * FROM public.exam_attempts WHERE status='completed' LOOP PERFORM public._competition_record('exam',r.id,r.user_id,r.started_at,r.ends_at,(r.definition->>'duration_seconds')::integer/60,r.points_earned);END LOOP;END $$;
CREATE FUNCTION public._competition_room_rows(p_room uuid) RETURNS TABLE(user_id uuid,points bigint,minutes bigint,days integer,rank_position bigint,joined_at timestamptz,active_count integer,member_count integer,tier integer)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 WITH totals AS(SELECT e.user_id,sum(e.points)points,sum(e.minutes)minutes,count(DISTINCT e.study_day)::integer days FROM public.competition_events e JOIN public.competition_rooms room ON room.id=p_room AND room.kind=e.kind AND room.period_month=e.period_month GROUP BY e.user_id),base AS(SELECT m.user_id,coalesce(t.points,0)::bigint points,coalesce(t.minutes,0)::bigint minutes,coalesce(t.days,0)days,m.joined_at,r.tier FROM public.competition_memberships m JOIN public.competition_rooms r ON r.id=m.room_id LEFT JOIN totals t ON t.user_id=m.user_id WHERE m.room_id=p_room)
 SELECT b.user_id,b.points,b.minutes,b.days,row_number() OVER(ORDER BY b.points DESC,b.joined_at,b.user_id),b.joined_at,(count(*) FILTER(WHERE b.minutes>0) OVER())::integer,(count(*) OVER())::integer,b.tier FROM base b
$$;
CREATE FUNCTION public.get_monthly_league_ranking(p_kind text DEFAULT 'study',p_scope text DEFAULT 'segment') RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_uid uuid:=auth.uid();v_month date:=public._competition_month(now());v_start timestamptz:=public._competition_month_time(v_month);v_end timestamptz:=public._competition_month_time((v_month+interval '1 month')::date);v_target jsonb;v_room uuid;v_tier integer;v_rows jsonb;v_activation timestamptz;v_active integer:=0;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 IF p_kind IS NULL OR p_scope IS NULL OR p_kind NOT IN('study','exam') OR p_scope NOT IN('segment','global') THEN RAISE EXCEPTION 'competition_invalid_scope'; END IF;
 SELECT activates_at INTO v_activation FROM public.competition_policy WHERE singleton;
 v_target:=public.get_competition_target();
 SELECT cp.tier INTO v_tier FROM public.competition_profiles cp WHERE cp.user_id=v_uid AND cp.kind=p_kind;
 v_tier:=coalesce(v_tier,CASE WHEN p_kind='study' THEN(SELECT league_tier FROM public.profiles WHERE id=v_uid)ELSE 1 END,1);
 IF p_scope='segment' THEN
  SELECT room_id INTO v_room FROM public.competition_memberships WHERE user_id=v_uid AND kind=p_kind AND period_month=v_month;
  IF v_room IS NOT NULL THEN
   SELECT max(active_count) INTO v_active FROM public._competition_room_rows(v_room);
   SELECT coalesce(jsonb_agg(jsonb_build_object('id',CASE WHEN p.id=v_uid OR(p.show_in_social_feed AND b.blocked_id IS NULL)THEN p.id END,'name',CASE WHEN p.id=v_uid OR(p.show_in_social_feed AND b.blocked_id IS NULL)THEN p.name END,'avatar_id',CASE WHEN p.id=v_uid OR(p.show_in_social_feed AND b.blocked_id IS NULL)THEN p.avatar_id END,'is_me',p.id=v_uid,'is_blocked',b.blocked_id IS NOT NULL,'points',r.points,'weekly_points',r.points,'rank',r.rank_position,'tier',r.tier,'end_date',v_end-interval '1 microsecond','has_league',true,'member_count',r.member_count,'active_member_count',r.active_count,'promotion_zone_end',CASE WHEN r.active_count>=3 THEN r.active_count/3 ELSE 0 END,'demotion_zone_start',CASE WHEN r.active_count>=10 THEN r.member_count-r.active_count/3+1 ELSE 999 END,
   'promotion_eligible',now()>=v_activation AND r.active_count>=3 AND r.rank_position<=r.active_count/3 AND r.points>0 AND r.days>=3 AND r.minutes>=300 AND r.tier<5,
   'award_eligible',now()>=v_activation AND r.active_count>=10 AND r.rank_position<=3 AND r.points>0 AND r.days>=3 AND r.minutes>=300 AND EXISTS(SELECT 1 FROM public.competition_avatar_rewards ar WHERE ar.kind=p_kind AND ar.tier=r.tier AND ar.rank_position=r.rank_position AND ar.avatar_id IS NOT NULL),
   'demotion_eligible',now()>=v_activation AND r.active_count>=10 AND r.rank_position>r.member_count-r.active_count/3 AND r.tier>1 AND r.joined_at<=v_end-interval '72 hours') ORDER BY r.rank_position),'[]'::jsonb)
   INTO v_rows FROM public._competition_room_rows(v_room)r JOIN public.profiles p ON p.id=r.user_id LEFT JOIN LATERAL(SELECT p.id AS blocked_id WHERE EXISTS(SELECT 1 FROM public.user_blocks ub WHERE(ub.blocker_id=v_uid AND ub.blocked_id=p.id)OR(ub.blocker_id=p.id AND ub.blocked_id=v_uid)))b ON true;
  END IF;
 ELSE
  WITH totals AS(SELECT e.user_id,sum(e.points)::bigint points,sum(e.minutes)::bigint minutes FROM public.competition_events e WHERE e.kind=p_kind AND e.period_month=v_month GROUP BY e.user_id),visible AS(SELECT p.id,p.name,p.avatar_id,t.points,t.minutes,row_number()OVER(ORDER BY t.points DESC,t.minutes DESC,p.id)rank_position FROM totals t JOIN public.profiles p ON p.id=t.user_id WHERE p.show_in_social_feed AND NOT EXISTS(SELECT 1 FROM public.user_blocks b WHERE(b.blocker_id=v_uid AND b.blocked_id=p.id)OR(b.blocker_id=p.id AND b.blocked_id=v_uid)))
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'avatar_id',avatar_id,'points',points,'weekly_points',points,'rank',rank_position,'tier',v_tier,'is_me',id=v_uid,'is_blocked',false,'has_league',true,'end_date',v_end-interval '1 microsecond','promotion_eligible',false,'award_eligible',false,'demotion_eligible',false)ORDER BY rank_position),'[]'::jsonb),count(*)::integer INTO v_rows,v_active FROM(SELECT * FROM visible ORDER BY rank_position LIMIT 100)q;
 END IF;
 IF v_rows IS NULL OR v_rows='[]'::jsonb THEN
  SELECT jsonb_build_array(jsonb_build_object('id',id,'name',name,'avatar_id',avatar_id,'points',0,'weekly_points',0,'rank',1,'tier',v_tier,'is_me',true,'is_blocked',false,'has_league',false,'member_count',0,'active_member_count',0,'end_date',v_end-interval '1 microsecond','promotion_zone_end',0,'demotion_zone_start',999,'promotion_eligible',false,'award_eligible',false,'demotion_eligible',false)) INTO v_rows FROM public.profiles WHERE id=v_uid;
 END IF;
 RETURN jsonb_build_object('schema_version',1,'server_time',clock_timestamp(),'kind',p_kind,'scope',p_scope,'segment',v_target->'current_segment','pending_segment',v_target->'pending_segment','segment_effective_at',v_target->'effective_at','tier',v_tier,'period_start',v_start,'period_end',v_end,'competition_phase',CASE WHEN now()<v_activation OR v_active<3 THEN 'preparing' ELSE 'active' END,'competition_starts_at',v_activation,'room_capacity',25,'exam_coins',coalesce((SELECT coins FROM public.exam_wallets WHERE user_id=v_uid),0),'rows',v_rows);
END $$;
CREATE FUNCTION public.get_my_exam_league_ranking(p_scope text DEFAULT 'segment') RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$ SELECT public.get_monthly_league_ranking('exam',p_scope) $$;
CREATE OR REPLACE FUNCTION public.get_my_league_ranking_v2() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT coalesce(jsonb_agg(r||jsonb_build_object('competition_phase',s->'competition_phase','competition_starts_at',s->'competition_starts_at','room_capacity',25,'league_config',public.get_league_config())),'[]'::jsonb) FROM(SELECT public.get_monthly_league_ranking('study','segment')s)q CROSS JOIN LATERAL jsonb_array_elements(s->'rows')r
$$;
CREATE OR REPLACE FUNCTION public.get_league_ranking(p_user_id uuid)
RETURNS TABLE(name text,avatar_id text,weekly_points integer,tier integer,end_date timestamptz,is_me boolean,promotion_zone_end integer,demotion_zone_start integer,member_count integer,id uuid,is_blocked boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF p_user_id IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'not authorized';END IF;
 RETURN QUERY SELECT r.name,r.avatar_id,r.weekly_points,r.tier,r.end_date,r.is_me,r.promotion_zone_end,r.demotion_zone_start,r.member_count,r.id,r.is_blocked FROM jsonb_to_recordset(public.get_my_league_ranking_v2())r(name text,avatar_id text,weekly_points integer,tier integer,end_date timestamptz,is_me boolean,promotion_zone_end integer,demotion_zone_start integer,member_count integer,id uuid,is_blocked boolean);
END $$;
CREATE OR REPLACE FUNCTION public.get_my_league_ranking()
RETURNS TABLE(name text,avatar_id text,weekly_points integer,tier integer,end_date timestamptz,is_me boolean,promotion_zone_end integer,demotion_zone_start integer,member_count integer,id uuid,is_blocked boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$ SELECT * FROM public.get_league_ranking(auth.uid()) $$;
CREATE OR REPLACE FUNCTION public.get_league_config() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT jsonb_build_object('policy_version',2,'period_kind','calendar_month','period_timezone','Europe/Istanbul','reset_hour',0,'period_start',public._competition_month_time(public._competition_month(now())),'period_end',public._competition_month_time((public._competition_month(now())+interval '1 month')::date),'server_time',clock_timestamp(),'league_room_capacity',25,'league_launch_min_active_users',3,'league_promotion_min_active_members',3,'league_qualification_min_days',3,'league_qualification_min_minutes',300,'league_award_min_members',10,'league_award_min_points',1,'league_promotion_min_points',1,'competition_phase',CASE WHEN now()<activates_at THEN 'preparing' ELSE 'active' END,'competition_starts_at',activates_at) FROM public.competition_policy WHERE singleton
$$;
CREATE FUNCTION public.get_public_monthly_competition(p_limit integer DEFAULT 10) RETURNS TABLE(name text,avatar_id text,total_points bigint,total_minutes bigint,period_end timestamptz)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT public.mask_public_name(p.name),p.avatar_id,sum(e.points)::bigint,sum(e.minutes)::bigint,public._competition_month_time((public._competition_month(now())+interval '1 month')::date)
 FROM public.competition_events e JOIN public.profiles p ON p.id=e.user_id WHERE e.kind='study' AND e.period_month=public._competition_month(now()) AND p.show_in_social_feed GROUP BY p.id,p.name,p.avatar_id ORDER BY 3 DESC,4 DESC,p.id LIMIT greatest(0,least(coalesce(p_limit,10),10))
$$;
CREATE OR REPLACE FUNCTION public.get_public_monthly_leaderboard(p_limit integer DEFAULT 10) RETURNS TABLE(name text,avatar_id text,total_points integer,total_minutes integer,is_me boolean,id uuid,is_blocked boolean)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT CASE WHEN auth.uid() IS NULL THEN public.mask_public_name(p.name)WHEN b.blocked_id IS NOT NULL THEN NULL ELSE p.name END,CASE WHEN b.blocked_id IS NOT NULL THEN NULL ELSE p.avatar_id END,sum(e.points)::integer,sum(e.minutes)::integer,coalesce(p.id=auth.uid(),false),CASE WHEN auth.uid() IS NOT NULL THEN p.id END,b.blocked_id IS NOT NULL
 FROM public.competition_events e JOIN public.profiles p ON p.id=e.user_id LEFT JOIN LATERAL(SELECT p.id AS blocked_id WHERE EXISTS(SELECT 1 FROM public.user_blocks ub WHERE(ub.blocker_id=auth.uid() AND ub.blocked_id=p.id)OR(ub.blocker_id=p.id AND ub.blocked_id=auth.uid())))b ON true WHERE e.kind='study' AND e.period_month=public._competition_month(now()) AND p.show_in_social_feed GROUP BY p.id,p.name,p.avatar_id,b.blocked_id ORDER BY 3 DESC,4 DESC,p.id LIMIT CASE WHEN auth.uid() IS NULL THEN greatest(0,least(coalesce(p_limit,10),10))ELSE greatest(0,least(coalesce(p_limit,10),100))END
$$;
-- Legacy rollover remains private for the transition month only. The new
-- scheduler never interprets normal study-day 04:00 as a month boundary.
CREATE FUNCTION public._competition_finalize_legacy() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE pol public.competition_policy%ROWTYPE;st public.league_competition_state%ROWTYPE;room record;r record;v_start timestamptz;v_tier integer;v_award text;v_decisions jsonb:='[]'::jsonb;
BEGIN
 SELECT * INTO pol FROM public.competition_policy WHERE singleton FOR UPDATE;
 IF pol.legacy_finalized OR now()<pol.activates_at THEN RETURN; END IF;
 SELECT * INTO st FROM public.league_competition_state WHERE singleton;
 v_start:=coalesce(st.period_started_at,st.start_at);
 IF v_start IS NOT NULL AND v_start<pol.activates_at THEN
 FOR room IN SELECT id,tier FROM public.leagues WHERE is_active ORDER BY id LOOP
  FOR r IN WITH a AS(SELECT * FROM public._league_period_activity(v_start,pol.activates_at)),base AS(SELECT m.user_id,m.joined_at,coalesce(a.points,0)points,coalesce(a.focus_minutes,0)minutes,coalesce(a.study_days,0)days FROM public.league_memberships m LEFT JOIN a ON a.user_id=m.user_id WHERE m.league_id=room.id) SELECT *,row_number()OVER(ORDER BY points DESC,joined_at,user_id)rank_position,count(*)FILTER(WHERE minutes>0)OVER()active_count,count(*)OVER()member_count FROM base LOOP
   v_tier:=room.tier;v_award:=NULL;
   IF r.active_count>=3 AND r.rank_position<=r.active_count/3 AND r.points>0 AND r.days>=3 AND r.minutes>=300 THEN v_tier:=least(5,room.tier+1);
   ELSIF r.active_count>=10 AND r.rank_position>r.member_count-r.active_count/3 AND r.joined_at<=pol.activates_at-interval '72 hours' THEN v_tier:=greatest(1,room.tier-1);END IF;
   IF r.active_count>=10 AND r.rank_position<=3 AND r.points>0 AND r.days>=3 AND r.minutes>=300 THEN v_award:=public.league_award_avatar_id(room.tier,r.rank_position::integer);END IF;
   IF v_award IS NOT NULL THEN INSERT INTO public.avatar_unlocks(user_id,avatar_id,unlock_type,coins_spent)VALUES(r.user_id,v_award,'league_award',0)ON CONFLICT(user_id,avatar_id)DO NOTHING;END IF;
   UPDATE public.profiles SET league_tier=v_tier WHERE id=r.user_id;
   UPDATE public.competition_profiles SET tier=v_tier WHERE user_id=r.user_id AND kind='study';
   v_decisions:=v_decisions||jsonb_build_array(jsonb_build_object('user_id',r.user_id,'rank',r.rank_position,'from_tier',room.tier,'to_tier',v_tier,'award_id',v_award,'points',r.points));
  END LOOP;
 END LOOP;
 END IF;
 UPDATE public.competition_policy SET legacy_finalized=true,legacy_decisions=v_decisions,legacy_snapshot=legacy_snapshot||jsonb_build_object('finalized_at',clock_timestamp(),'final_state',jsonb_build_object('start_at',st.start_at,'initialized',st.initialized,'period_started_at',st.period_started_at),'final_members',coalesce((SELECT jsonb_agg(to_jsonb(m))FROM public.league_memberships m),'[]'::jsonb)) WHERE singleton;
END $$;
CREATE FUNCTION public._competition_repack_current() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE m record;
BEGIN
 FOR m IN SELECT cm.* FROM public.competition_memberships cm JOIN public.competition_rooms r ON r.id=cm.room_id JOIN public.competition_profiles cp ON cp.user_id=cm.user_id AND cp.kind=cm.kind WHERE cm.period_month=public._competition_month(now()) AND r.tier<>cp.tier ORDER BY cm.user_id,cm.kind LOOP
  DELETE FROM public.competition_memberships WHERE user_id=m.user_id AND kind=m.kind AND period_month=m.period_month;
  PERFORM public._competition_place(m.user_id,m.kind,m.period_month,m.joined_at);
 END LOOP;
END $$;
CREATE FUNCTION public.process_monthly_competitions() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE pol public.competition_policy%ROWTYPE;v_month date;v_end timestamptz;room record;r record;v_tier integer;v_award text;
BEGIN
 -- D-03: ordinary daily runs need no profile locks. Check immutable month
 -- boundaries and completed-period records before entering the global lock.
 SELECT * INTO pol FROM public.competition_policy WHERE singleton;
 IF NOT FOUND THEN RETURN; END IF;
 IF (pol.legacy_finalized OR now()<pol.activates_at) AND NOT EXISTS(
  SELECT 1 FROM generate_series(public._competition_month(pol.activates_at)::timestamp,
   (public._competition_month(now())-interval '1 month')::timestamp,interval '1 month') due(month)
  WHERE NOT EXISTS(SELECT 1 FROM public.competition_periods done WHERE done.period_month=due.month::date)
 ) THEN RETURN; END IF;
 -- Same lock order as normal completion: profiles first, then competition locks.
 PERFORM 1 FROM public.profiles ORDER BY id FOR UPDATE;
 PERFORM pg_advisory_xact_lock(71028003);
 -- Another worker may have finished while this one waited: recheck under lock.
 SELECT * INTO pol FROM public.competition_policy WHERE singleton;
 IF NOT FOUND THEN RETURN; END IF;
 IF (pol.legacy_finalized OR now()<pol.activates_at) AND NOT EXISTS(
  SELECT 1 FROM generate_series(public._competition_month(pol.activates_at)::timestamp,
   (public._competition_month(now())-interval '1 month')::timestamp,interval '1 month') due(month)
  WHERE NOT EXISTS(SELECT 1 FROM public.competition_periods done WHERE done.period_month=due.month::date)
 ) THEN RETURN; END IF;
 PERFORM public._competition_finalize_legacy();
 SELECT * INTO pol FROM public.competition_policy WHERE singleton;
 v_month:=public._competition_month(pol.activates_at);
 WHILE v_month<public._competition_month(now()) LOOP
 IF NOT EXISTS(SELECT 1 FROM public.competition_periods WHERE period_month=v_month) THEN
  v_end:=public._competition_month_time((v_month+interval '1 month')::date);
  FOR room IN SELECT * FROM public.competition_rooms WHERE period_month=v_month ORDER BY kind,segment,tier,id LOOP
   FOR r IN SELECT * FROM public._competition_room_rows(room.id) ORDER BY rank_position LOOP
    v_tier:=room.tier;v_award:=NULL;
    IF r.active_count>=3 AND r.rank_position<=r.active_count/3 AND r.points>0 AND r.days>=3 AND r.minutes>=300 THEN v_tier:=least(5,room.tier+1);
    ELSIF r.active_count>=10 AND r.rank_position>r.member_count-r.active_count/3 AND r.joined_at<=v_end-interval '72 hours' THEN v_tier:=greatest(1,room.tier-1); END IF;
    IF r.active_count>=10 AND r.rank_position<=3 AND r.points>0 AND r.days>=3 AND r.minutes>=300 THEN SELECT avatar_id INTO v_award FROM public.competition_avatar_rewards WHERE kind=room.kind AND tier=room.tier AND rank_position=r.rank_position; END IF;
    INSERT INTO public.competition_results(user_id,kind,period_month,rank,from_tier,to_tier,award_id,snapshot)VALUES(r.user_id,room.kind,v_month,r.rank_position,room.tier,v_tier,v_award,to_jsonb(r)) ON CONFLICT DO NOTHING;
    UPDATE public.competition_profiles SET tier=v_tier WHERE user_id=r.user_id AND kind=room.kind;
    IF room.kind='study' THEN UPDATE public.profiles SET league_tier=v_tier WHERE id=r.user_id;END IF;
    IF v_award IS NOT NULL THEN INSERT INTO public.avatar_unlocks(user_id,avatar_id,unlock_type,coins_spent)VALUES(r.user_id,v_award,'league_award',0)ON CONFLICT(user_id,avatar_id)DO NOTHING;END IF;
   END LOOP;
  END LOOP;
  INSERT INTO public.competition_periods VALUES(v_month,clock_timestamp());
 END IF;
 v_month:=(v_month+interval '1 month')::date;
 END LOOP;
 PERFORM public._competition_repack_current();
END $$;
-- Keep old cron function/signature. Before activation it delegates to its exact
-- archived body; afterwards only the monthly engine runs.
DO $$ DECLARE source text; BEGIN SELECT definition INTO source FROM public.competition_install_backup WHERE signature='process_weekly_leagues()'; IF source IS NULL THEN SELECT definition INTO source FROM public.competition_install_backup WHERE signature='public.process_weekly_leagues()';END IF; IF source IS NULL THEN RAISE EXCEPTION 'competition_legacy_source_missing'; END IF;EXECUTE replace(source,'FUNCTION public.process_weekly_leagues()','FUNCTION public._competition_legacy_weekly()');END $$;
CREATE OR REPLACE FUNCTION public.process_weekly_leagues() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$ BEGIN IF now()<(SELECT activates_at FROM public.competition_policy WHERE singleton)THEN PERFORM public._competition_legacy_weekly();ELSE PERFORM public.process_monthly_competitions();END IF;END $$;
DO $$ DECLARE source text; BEGIN
 SELECT pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure) INTO source;
 IF position('    -- 8. LEAGUE POINTS' IN source)=0 OR position('    -- 9. INSERT STUDY SESSION' IN source)=0 THEN RAISE EXCEPTION 'competition_normal_source_changed';END IF;
 source:=replace(source,'    -- 8. LEAGUE POINTS','    IF clock_timestamp() < (SELECT activates_at FROM public.competition_policy WHERE singleton) THEN'||chr(10)||'    -- 8. LEAGUE POINTS');
 source:=replace(source,'    -- 9. INSERT STUDY SESSION','    ELSE'||chr(10)||'      v_league_points := CASE WHEN public._competition_month(v_ends_at)=public._competition_month(now()) THEN v_total_points ELSE 0 END;'||chr(10)||'      v_league_period_closed := public._competition_month(v_ends_at)<public._competition_month(now());'||chr(10)||'    END IF;'||chr(10)||'    -- 9. INSERT STUDY SESSION');
 EXECUTE source;
END $$;
DO $$ DECLARE source text;BEGIN SELECT definition INTO source FROM public.competition_install_backup WHERE signature IN('ensure_user_in_league(uuid,integer)','public.ensure_user_in_league(uuid,integer)');IF source IS NULL THEN RAISE EXCEPTION 'competition_legacy_ensure_missing';END IF;EXECUTE replace(source,'FUNCTION public.ensure_user_in_league(','FUNCTION public._competition_legacy_ensure_user_in_league(');END $$;
CREATE OR REPLACE FUNCTION public.ensure_user_in_league(p_user_id uuid,p_points integer) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$ BEGIN IF now()<(SELECT activates_at FROM public.competition_policy WHERE singleton)THEN PERFORM public._competition_legacy_ensure_user_in_league(p_user_id,p_points);END IF;END $$;
-- Daily at 00:01 Istanbul; harmless idempotent no-op outside rollover.
SELECT cron.schedule('weekly_leagues_job','1 21 * * *','SELECT public.process_weekly_leagues();');
DO $$ DECLARE r regprocedure; BEGIN FOR r IN SELECT p.oid::regprocedure FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND(p.proname LIKE '\_competition\_%' ESCAPE '\' OR p.proname IN('process_monthly_competitions','get_monthly_league_ranking','get_my_exam_league_ranking','get_public_monthly_competition','get_competition_target','set_competition_target')) LOOP EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role',r);END LOOP;END $$;
GRANT EXECUTE ON FUNCTION public.get_monthly_league_ranking(text,text),public.get_my_exam_league_ranking(text),public.get_competition_target(),public.set_competition_target(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_monthly_competition(integer) TO anon,authenticated;
INSERT INTO supabase_migrations.schema_migrations(version,name)VALUES('20261028030000','monthly_competitions');
NOTIFY pgrst,'reload schema';
-- END 29_monthly_competitions

-- START 30_session_start_atomic
-- HAZIRLANDI / CANLIYA UYGULANMADI. 13'ün register_session_start RPC'si gerekir.
-- 27/28/29'dan bağımsız ek güvenlik düzeltmesi; onların tablolarını değiştirmez.
DO $$ BEGIN
 IF to_regclass('public.session_starts') IS NULL THEN RAISE EXCEPTION 'session_start_atomic_requires_session_starts'; END IF;
 IF EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261028040000') THEN RAISE EXCEPTION 'session_start_atomic_already_applied'; END IF;
 IF md5(pg_get_functiondef('public.register_session_start(uuid,integer)'::regprocedure))<>'9500c7c45503a3e5031e52c879b1dba2' THEN RAISE EXCEPTION 'session_start_atomic_precondition_changed'; END IF;
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
    v_duration integer;
    v_created boolean;
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

    -- proposed/30: aynı kullanıcıda kota ve UUID denetimi tek sırada yapılır.
    -- Kilit sırası normal tamamlama/avatar satın alma ile aynıdır: profil önce.
    PERFORM 1 FROM public.profiles WHERE id = v_uid FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'not authenticated: profile_not_found';
    END IF;

    -- Var olan kayıt değişmez: başlangıç sonradan kaydırılamaz.
    SELECT s.server_started_at, s.duration_minutes INTO v_started, v_duration
      FROM public.session_starts s
     WHERE s.user_id = v_uid AND s.client_uuid = p_client_uuid;
    IF FOUND THEN
        IF v_duration <> p_duration_minutes THEN
            RAISE EXCEPTION 'invalid duration: session_start_metadata_conflict';
        END IF;
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

    v_created := v_started IS NOT NULL;
    IF v_started IS NULL THEN
        SELECT s.server_started_at INTO v_started
          FROM public.session_starts s
         WHERE s.user_id = v_uid AND s.client_uuid = p_client_uuid;
    END IF;

    RETURN jsonb_build_object('client_uuid', p_client_uuid, 'server_started_at', v_started,
                              'server_now', now(), 'created', v_created);
END;
$function$;
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261028040000','session_start_atomic');
-- END 30_session_start_atomic

-- START 32_exam_details_early_finish
-- PROPOSED ONLY. Requires 27 -> 28 -> 29 and 30; 31 is neither required nor applied.
-- User-approved policy: floor(snapshot full coins * elapsed / planned), capped at the frozen full reward.
DO $$
DECLARE r record;
BEGIN
 IF NOT (SELECT count(*)=4 FROM supabase_migrations.schema_migrations WHERE version IN ('20261028010000','20261028020000','20261028030000','20261028040000')) THEN RAISE EXCEPTION 'exam32_requires_27_through_30'; END IF;
 IF EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261028050000') THEN RAISE EXCEPTION 'exam32_requires_31_absent'; END IF;
 IF to_regclass('public.exam_extension_32_backup') IS NOT NULL OR EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261028060000') THEN RAISE EXCEPTION 'exam32_already_installed'; END IF;
 FOR r IN SELECT * FROM (VALUES
  ('public._exam_payload(uuid)','123cdc46703b9d5f63ffd1ce1e62d500'),
  ('public.get_exam_config()','b30eb2af01e29bc2c9a47480045e6ca6'),
  ('public._exam_has_overlap(uuid,timestamp with time zone,timestamp with time zone)','64c8c0de1f26810e6df4107b817ba8b0'),
  ('public._competition_exam_event()','0e5d282c147c27089c838a4de5598919'),
  ('public.save_exam_results(uuid,jsonb)','24dd963f3265de9a7eeff547a39a9cf9'),
  ('public.complete_exam_attempt(uuid)','7448ba3186326bce16babf5399b9aaf3'),
  ('public.start_exam_attempt(uuid,text)','8928a4a7c25c61fe1f92f874935d208d'),
  ('public.abandon_exam_attempt(uuid)','287efddd226b8f6782d662d0da1bb76c')
 ) x(signature,digest) LOOP
  IF to_regprocedure(r.signature) IS NULL OR md5(pg_get_functiondef(to_regprocedure(r.signature)))<>r.digest THEN RAISE EXCEPTION 'exam32_precondition_changed: %',r.signature; END IF;
 END LOOP;
 -- Exact official v1 catalogue guard is generated from the reviewed repository JSON.
 IF (SELECT jsonb_object_agg(id,jsonb_build_object('definition',definition,'enabled',enabled)) FROM public.exam_catalog)<>'{"tyt":{"definition":{"id":"tyt","name_tr":"TYT","name_en":"TYT","segment":"yks","group":"yks","duration_seconds":9900,"total_questions":120,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":33,"reward_coins":6,"subjects":[{"id":"turkish","name_tr":"Türkçe","name_en":"Turkish","question_count":40,"category_keys":["Türkçe"]},{"id":"mathematics","name_tr":"Temel Matematik","name_en":"Basic Mathematics","question_count":40,"category_keys":["Matematik"]},{"id":"history","name_tr":"Tarih","name_en":"History","question_count":5,"category_keys":["Tarih"]},{"id":"geography","name_tr":"Coğrafya","name_en":"Geography","question_count":5,"category_keys":["Coğrafya"]},{"id":"philosophy","name_tr":"Felsefe","name_en":"Philosophy","question_count":5,"category_keys":["Felsefe"]},{"id":"religion","name_tr":"Din Kültürü / İlave Felsefe","name_en":"Religious Culture / Additional Philosophy","question_count":5,"category_keys":["Din Kültürü"]},{"id":"physics","name_tr":"Fizik","name_en":"Physics","question_count":7,"category_keys":["Fizik"]},{"id":"chemistry","name_tr":"Kimya","name_en":"Chemistry","question_count":7,"category_keys":["Kimya"]},{"id":"biology","name_tr":"Biyoloji","name_en":"Biology","question_count":6,"category_keys":["Biyoloji"]}]},"enabled":true},"ayt":{"definition":{"id":"ayt","name_tr":"AYT","name_en":"AYT","segment":"yks","group":"yks","duration_seconds":10800,"total_questions":160,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":36,"reward_coins":7,"subjects":[{"id":"literature","name_tr":"Türk Dili ve Edebiyatı","name_en":"Turkish Language and Literature","question_count":24,"category_keys":["Edebiyat","Türkçe"]},{"id":"history_1","name_tr":"Tarih-1","name_en":"History-1","question_count":10,"category_keys":["Tarih"]},{"id":"geography_1","name_tr":"Coğrafya-1","name_en":"Geography-1","question_count":6,"category_keys":["Coğrafya"]},{"id":"history_2","name_tr":"Tarih-2","name_en":"History-2","question_count":11,"category_keys":["Tarih"]},{"id":"geography_2","name_tr":"Coğrafya-2","name_en":"Geography-2","question_count":11,"category_keys":["Coğrafya"]},{"id":"philosophy_group","name_tr":"Felsefe Grubu","name_en":"Philosophy Group","question_count":12,"category_keys":["Felsefe"]},{"id":"religion","name_tr":"Din Kültürü / İlave Felsefe","name_en":"Religious Culture / Additional Philosophy","question_count":6,"category_keys":["Din Kültürü"]},{"id":"mathematics","name_tr":"Matematik","name_en":"Mathematics","question_count":40,"category_keys":["Matematik"]},{"id":"physics","name_tr":"Fizik","name_en":"Physics","question_count":14,"category_keys":["Fizik"]},{"id":"chemistry","name_tr":"Kimya","name_en":"Chemistry","question_count":13,"category_keys":["Kimya"]},{"id":"biology","name_tr":"Biyoloji","name_en":"Biology","question_count":13,"category_keys":["Biyoloji"]}]},"enabled":true},"ydt":{"definition":{"id":"ydt","name_tr":"YDT","name_en":"YDT","segment":"yks","group":"yks","duration_seconds":7200,"total_questions":80,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":24,"reward_coins":4,"subjects":[{"id":"foreign_language","name_tr":"Yabancı Dil","name_en":"Foreign Language","question_count":80,"category_keys":["İngilizce"]}]},"enabled":true},"lgs_verbal":{"definition":{"id":"lgs_verbal","name_tr":"LGS Sözel","name_en":"LGS Verbal","segment":"lgs","group":"lgs","duration_seconds":4500,"total_questions":50,"wrong_answer_divisor":3,"catalog_version":1,"reward_points":15,"reward_coins":3,"subjects":[{"id":"turkish","name_tr":"Türkçe","name_en":"Turkish","question_count":20,"category_keys":["Türkçe"]},{"id":"revolution_history","name_tr":"T.C. İnkılap Tarihi","name_en":"Turkish Revolution History","question_count":10,"category_keys":["T.C. İnkılap Tarihi"]},{"id":"religion","name_tr":"Din Kültürü","name_en":"Religious Culture","question_count":10,"category_keys":["Din Kültürü"]},{"id":"foreign_language","name_tr":"Yabancı Dil","name_en":"Foreign Language","question_count":10,"category_keys":["İngilizce"]}]},"enabled":true},"lgs_quantitative":{"definition":{"id":"lgs_quantitative","name_tr":"LGS Sayısal","name_en":"LGS Quantitative","segment":"lgs","group":"lgs","duration_seconds":4800,"total_questions":40,"wrong_answer_divisor":3,"catalog_version":1,"reward_points":16,"reward_coins":3,"subjects":[{"id":"mathematics","name_tr":"Matematik","name_en":"Mathematics","question_count":20,"category_keys":["Matematik"]},{"id":"science","name_tr":"Fen Bilimleri","name_en":"Science","question_count":20,"category_keys":["Fen Bilimleri"]}]},"enabled":true},"tus_basic":{"definition":{"id":"tus_basic","name_tr":"TUS Temel Tıp","name_en":"TUS Basic Medicine","segment":"tus","group":"tus","duration_seconds":8100,"total_questions":100,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":27,"reward_coins":5,"subjects":[{"id":"anatomy","name_tr":"Anatomi","name_en":"Anatomy","question_count":13,"category_keys":["Anatomi"]},{"id":"histology_embryology","name_tr":"Histoloji ve Embriyoloji","name_en":"Histology and Embryology","question_count":7,"category_keys":["Fizyoloji, Histoloji ve Embriyoloji"]},{"id":"physiology","name_tr":"Fizyoloji","name_en":"Physiology","question_count":8,"category_keys":["Fizyoloji, Histoloji ve Embriyoloji"]},{"id":"biochemistry","name_tr":"Biyokimya","name_en":"Biochemistry","question_count":18,"category_keys":["Biyokimya"]},{"id":"microbiology","name_tr":"Mikrobiyoloji","name_en":"Microbiology","question_count":18,"category_keys":["Mikrobiyoloji"]},{"id":"pathology","name_tr":"Patoloji","name_en":"Pathology","question_count":18,"category_keys":["Patoloji"]},{"id":"pharmacology","name_tr":"Farmakoloji","name_en":"Pharmacology","question_count":18,"category_keys":["Farmakoloji"]}]},"enabled":true},"tus_clinical":{"definition":{"id":"tus_clinical","name_tr":"TUS Klinik Tıp","name_en":"TUS Clinical Medicine","segment":"tus","group":"tus","duration_seconds":8100,"total_questions":100,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":27,"reward_coins":5,"subjects":[{"id":"internal_medicine_group","name_tr":"Dahiliye Grubu","name_en":"Internal Medicine Group","question_count":35,"category_keys":["Dahiliye"]},{"id":"pediatrics","name_tr":"Pediatri","name_en":"Pediatrics","question_count":25,"category_keys":["Pediatri"]},{"id":"surgery_group","name_tr":"Cerrahi Grubu","name_en":"Surgery Group","question_count":30,"category_keys":["Genel Cerrahi"]},{"id":"obstetrics_gynecology","name_tr":"Kadın Hastalıkları ve Doğum","name_en":"Obstetrics and Gynecology","question_count":10,"category_keys":["Kadın Hastalıkları ve Doğum"]}]},"enabled":true},"dus":{"definition":{"id":"dus","name_tr":"DUS","name_en":"DUS","segment":"dus","group":"dus","duration_seconds":9000,"total_questions":120,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":30,"reward_coins":6,"subjects":[{"id":"anatomy","name_tr":"Anatomi","name_en":"Anatomy","question_count":6,"category_keys":["Anatomi"]},{"id":"histology_embryology","name_tr":"Histoloji ve Embriyoloji","name_en":"Histology and Embryology","question_count":4,"category_keys":["Histoloji ve Embriyoloji"]},{"id":"physiology","name_tr":"Fizyoloji","name_en":"Physiology","question_count":6,"category_keys":["Fizyoloji"]},{"id":"biochemistry","name_tr":"Tıbbi Biyokimya","name_en":"Medical Biochemistry","question_count":6,"category_keys":["Biyokimya"]},{"id":"microbiology","name_tr":"Tıbbi Mikrobiyoloji","name_en":"Medical Microbiology","question_count":6,"category_keys":["Mikrobiyoloji"]},{"id":"pathology","name_tr":"Tıbbi Patoloji","name_en":"Medical Pathology","question_count":4,"category_keys":["Patoloji"]},{"id":"pharmacology","name_tr":"Tıbbi Farmakoloji","name_en":"Medical Pharmacology","question_count":4,"category_keys":["Farmakoloji"]},{"id":"medical_biology_genetics","name_tr":"Tıbbi Biyoloji ve Genetik","name_en":"Medical Biology and Genetics","question_count":4,"category_keys":["Tıbbi Biyoloji ve Genetik"]},{"id":"restorative_dentistry","name_tr":"Restoratif Diş Tedavisi","name_en":"Restorative Dentistry","question_count":10,"category_keys":["Restoratif Diş Tedavisi"]},{"id":"prosthetic_dentistry","name_tr":"Protetik Diş Tedavisi","name_en":"Prosthodontics","question_count":10,"category_keys":["Protetik Diş Tedavisi"]},{"id":"oral_maxillofacial_surgery","name_tr":"Ağız, Diş ve Çene Cerrahisi","name_en":"Oral and Maxillofacial Surgery","question_count":10,"category_keys":["Ağız, Diş ve Çene Cerrahisi"]},{"id":"oral_maxillofacial_radiology","name_tr":"Ağız, Diş ve Çene Radyolojisi","name_en":"Oral and Maxillofacial Radiology","question_count":10,"category_keys":["Ağız, Diş ve Çene Radyolojisi"]},{"id":"periodontology","name_tr":"Periodontoloji","name_en":"Periodontology","question_count":10,"category_keys":["Periodontoloji"]},{"id":"orthodontics","name_tr":"Ortodonti","name_en":"Orthodontics","question_count":10,"category_keys":["Ortodonti"]},{"id":"endodontics","name_tr":"Endodonti","name_en":"Endodontics","question_count":10,"category_keys":["Endodonti"]},{"id":"pediatric_dentistry","name_tr":"Çocuk Diş Hekimliği","name_en":"Pediatric Dentistry","question_count":10,"category_keys":["Çocuk Diş Hekimliği"]}]},"enabled":true},"kpss_bachelor_gygk":{"definition":{"id":"kpss_bachelor_gygk","name_tr":"KPSS Lisans · Genel Yetenek–Genel Kültür","name_en":"KPSS Bachelor’s · General Ability–General Knowledge","segment":"kpss","group":"kpss","duration_seconds":7800,"total_questions":120,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":26,"reward_coins":5,"subjects":[{"id":"general_ability","name_tr":"Genel Yetenek","name_en":"General Ability","question_count":60,"category_keys":["Türkçe","Matematik","Genel Yetenek"]},{"id":"general_knowledge","name_tr":"Genel Kültür","name_en":"General Knowledge","question_count":60,"category_keys":["Tarih","Coğrafya","Vatandaşlık","Güncel Bilgiler","Genel Kültür"]}]},"enabled":true},"kpss_associate_gygk":{"definition":{"id":"kpss_associate_gygk","name_tr":"KPSS Ön Lisans · Genel Yetenek–Genel Kültür","name_en":"KPSS Associate Degree · General Ability–General Knowledge","segment":"kpss","group":"kpss","duration_seconds":7800,"total_questions":120,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":26,"reward_coins":5,"subjects":[{"id":"general_ability","name_tr":"Genel Yetenek","name_en":"General Ability","question_count":60,"category_keys":["Türkçe","Matematik","Genel Yetenek"]},{"id":"general_knowledge","name_tr":"Genel Kültür","name_en":"General Knowledge","question_count":60,"category_keys":["Tarih","Coğrafya","Vatandaşlık","Güncel Bilgiler","Genel Kültür"]}]},"enabled":true},"kpss_secondary_gygk":{"definition":{"id":"kpss_secondary_gygk","name_tr":"KPSS Ortaöğretim · Genel Yetenek–Genel Kültür","name_en":"KPSS Secondary Education · General Ability–General Knowledge","segment":"kpss","group":"kpss","duration_seconds":7800,"total_questions":120,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":26,"reward_coins":5,"subjects":[{"id":"general_ability","name_tr":"Genel Yetenek","name_en":"General Ability","question_count":60,"category_keys":["Türkçe","Matematik","Genel Yetenek"]},{"id":"general_knowledge","name_tr":"Genel Kültür","name_en":"General Knowledge","question_count":60,"category_keys":["Tarih","Coğrafya","Vatandaşlık","Güncel Bilgiler","Genel Kültür"]}]},"enabled":true},"kpss_field_business":{"definition":{"id":"kpss_field_business","name_tr":"KPSS Alan Bilgisi · İşletme","name_en":"KPSS Field Knowledge · Business Administration","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":2,"subjects":[{"id":"business","name_tr":"İşletme","name_en":"Business Administration","question_count":40,"category_keys":["İşletme"]}]},"enabled":true},"kpss_field_accounting":{"definition":{"id":"kpss_field_accounting","name_tr":"KPSS Alan Bilgisi · Muhasebe","name_en":"KPSS Field Knowledge · Accounting","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":2,"subjects":[{"id":"accounting","name_tr":"Muhasebe","name_en":"Accounting","question_count":40,"category_keys":["Muhasebe"]}]},"enabled":true},"kpss_field_law":{"definition":{"id":"kpss_field_law","name_tr":"KPSS Alan Bilgisi · Hukuk","name_en":"KPSS Field Knowledge · Law","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":2,"subjects":[{"id":"law","name_tr":"Hukuk","name_en":"Law","question_count":40,"category_keys":["Hukuk"]}]},"enabled":true},"kpss_field_public_administration":{"definition":{"id":"kpss_field_public_administration","name_tr":"KPSS Alan Bilgisi · Kamu Yönetimi","name_en":"KPSS Field Knowledge · Public Administration","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":2,"subjects":[{"id":"public_administration","name_tr":"Kamu Yönetimi","name_en":"Public Administration","question_count":40,"category_keys":["Kamu Yönetimi"]}]},"enabled":true},"kpss_field_economics":{"definition":{"id":"kpss_field_economics","name_tr":"KPSS Alan Bilgisi · İktisat","name_en":"KPSS Field Knowledge · Economics","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":2,"subjects":[{"id":"economics","name_tr":"İktisat","name_en":"Economics","question_count":40,"category_keys":["İktisat"]}]},"enabled":true},"kpss_field_finance":{"definition":{"id":"kpss_field_finance","name_tr":"KPSS Alan Bilgisi · Maliye","name_en":"KPSS Field Knowledge · Public Finance","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":2,"subjects":[{"id":"finance","name_tr":"Maliye","name_en":"Public Finance","question_count":40,"category_keys":["Maliye"]}]},"enabled":true},"kpss_field_international_relations":{"definition":{"id":"kpss_field_international_relations","name_tr":"KPSS Alan Bilgisi · Uluslararası İlişkiler","name_en":"KPSS Field Knowledge · International Relations","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":2,"subjects":[{"id":"international_relations","name_tr":"Uluslararası İlişkiler","name_en":"International Relations","question_count":40,"category_keys":["Uluslararası İlişkiler"]}]},"enabled":true},"kpss_field_labour_economics":{"definition":{"id":"kpss_field_labour_economics","name_tr":"KPSS Alan Bilgisi · Çalışma Ekonomisi ve Endüstri İlişkileri","name_en":"KPSS Field Knowledge · Labour Economics and Industrial Relations","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":2,"subjects":[{"id":"labour_economics","name_tr":"Çalışma Ekonomisi ve Endüstri İlişkileri","name_en":"Labour Economics and Industrial Relations","question_count":40,"category_keys":["Çalışma Ekonomisi ve Endüstri İlişkileri"]}]},"enabled":true},"kpss_field_statistics":{"definition":{"id":"kpss_field_statistics","name_tr":"KPSS Alan Bilgisi · İstatistik","name_en":"KPSS Field Knowledge · Statistics","segment":"kpss","group":"kpss","duration_seconds":3600,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":12,"reward_coins":2,"subjects":[{"id":"statistics","name_tr":"İstatistik","name_en":"Statistics","question_count":40,"category_keys":["İstatistik"]}]},"enabled":true}}'::jsonb THEN RAISE EXCEPTION 'exam32_requires_exact_v1_catalog'; END IF;
END $$;

CREATE TABLE public.exam_extension_32_backup(kind text NOT NULL,key text NOT NULL,payload jsonb NOT NULL,PRIMARY KEY(kind,key));
ALTER TABLE public.exam_extension_32_backup ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.exam_extension_32_backup FROM PUBLIC,anon,authenticated,service_role;
INSERT INTO public.exam_extension_32_backup SELECT 'catalog',id,jsonb_build_object('definition',definition,'enabled',enabled) FROM public.exam_catalog;
INSERT INTO public.exam_extension_32_backup
 SELECT 'function',p.oid::regprocedure::text,jsonb_build_object('definition',pg_get_functiondef(p.oid),'acl',to_jsonb(p.proacl),'md5',md5(pg_get_functiondef(p.oid)))
 FROM pg_proc p WHERE p.oid IN ('public._exam_payload(uuid)'::regprocedure,'public.get_exam_config()'::regprocedure,'public._exam_has_overlap(uuid,timestamptz,timestamptz)'::regprocedure,'public._competition_exam_event()'::regprocedure,'public.save_exam_results(uuid,jsonb)'::regprocedure);

ALTER TABLE public.exam_attempts
 ADD COLUMN title text,
 ADD COLUMN note text,
 ADD COLUMN selected_module_ids text[],
 ADD COLUMN details_revision integer NOT NULL DEFAULT 0,
 ADD CONSTRAINT exam_title32_valid CHECK(title IS NULL OR (char_length(title) BETWEEN 1 AND 120 AND title !~ '[[:cntrl:]]' AND position(chr(133) IN title)=0 AND position(chr(8232) IN title)=0 AND position(chr(8233) IN title)=0)),
 ADD CONSTRAINT exam_note32_valid CHECK(note IS NULL OR (char_length(note)<=2000 AND regexp_replace(note,E'[\n\t]','','g') !~ '[[:cntrl:]]')),
 ADD CONSTRAINT exam_details32_revision CHECK(details_revision>=0),
 ADD CONSTRAINT exam_modules32_basic CHECK(selected_module_ids IS NULL OR (exam_id='ayt' AND cardinality(selected_module_ids) BETWEEN 1 AND 4 AND selected_module_ids <@ ARRAY['turkish_social_1','social_2','mathematics','science']::text[] AND array_position(selected_module_ids,NULL) IS NULL));

CREATE TABLE public.exam_extension_policy(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),early_enabled boolean NOT NULL,early_coin_mode text NOT NULL CHECK(early_coin_mode='proportional'));
ALTER TABLE public.exam_extension_policy ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.exam_extension_policy FROM PUBLIC,anon,authenticated,service_role;
INSERT INTO public.exam_extension_policy VALUES(true,true,'proportional');

CREATE FUNCTION public._exam_ayt_modules32(p_definition jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SET search_path=public,pg_temp AS $$
DECLARE actual jsonb;
BEGIN
 IF p_definition->>'id'<>'ayt' OR jsonb_typeof(p_definition->'subjects')<>'array' THEN RETURN '[]'::jsonb; END IF;
 SELECT jsonb_agg(jsonb_build_object('id',s->>'id','question_count',s->'question_count') ORDER BY s->>'id') INTO actual FROM jsonb_array_elements(p_definition->'subjects')s;
 IF actual<>'[{"id":"biology","question_count":13},{"id":"chemistry","question_count":13},{"id":"geography_1","question_count":6},{"id":"geography_2","question_count":11},{"id":"history_1","question_count":10},{"id":"history_2","question_count":11},{"id":"literature","question_count":24},{"id":"mathematics","question_count":40},{"id":"philosophy_group","question_count":12},{"id":"physics","question_count":14},{"id":"religion","question_count":6}]'::jsonb THEN RETURN '[]'::jsonb; END IF;
 RETURN '[{"id":"turkish_social_1","name_tr":"Türk Dili ve Edebiyatı–Sosyal Bilimler-1","name_en":"Turkish Language and Literature–Social Sciences-1","subject_ids":["literature","history_1","geography_1"]},{"id":"social_2","name_tr":"Sosyal Bilimler-2","name_en":"Social Sciences-2","subject_ids":["history_2","geography_2","philosophy_group","religion"]},{"id":"mathematics","name_tr":"Matematik","name_en":"Mathematics","subject_ids":["mathematics"]},{"id":"science","name_tr":"Fen Bilimleri","name_en":"Science","subject_ids":["physics","chemistry","biology"]}]'::jsonb;
END $$;

UPDATE public.exam_catalog SET definition=definition||jsonb_build_object('reward_coins',CASE id WHEN 'tyt' THEN 130 WHEN 'ayt' THEN 145 WHEN 'ydt' THEN 95 WHEN 'lgs_verbal' THEN 60 WHEN 'lgs_quantitative' THEN 70 WHEN 'tus_basic' THEN 110 WHEN 'tus_clinical' THEN 110 WHEN 'dus' THEN 120 WHEN 'kpss_bachelor_gygk' THEN 105 WHEN 'kpss_associate_gygk' THEN 105 WHEN 'kpss_secondary_gygk' THEN 105 WHEN 'kpss_field_business' THEN 40 WHEN 'kpss_field_accounting' THEN 40 WHEN 'kpss_field_law' THEN 40 WHEN 'kpss_field_public_administration' THEN 40 WHEN 'kpss_field_economics' THEN 40 WHEN 'kpss_field_finance' THEN 40 WHEN 'kpss_field_international_relations' THEN 40 WHEN 'kpss_field_labour_economics' THEN 40 WHEN 'kpss_field_statistics' THEN 50 END,'reward_policy_version',2) WHERE id IN('tyt','ayt','ydt','lgs_verbal','lgs_quantitative','tus_basic','tus_clinical','dus','kpss_bachelor_gygk','kpss_associate_gygk','kpss_secondary_gygk','kpss_field_business','kpss_field_accounting','kpss_field_law','kpss_field_public_administration','kpss_field_economics','kpss_field_finance','kpss_field_international_relations','kpss_field_labour_economics','kpss_field_statistics');
UPDATE public.exam_catalog SET definition=definition||jsonb_build_object('modules',public._exam_ayt_modules32(definition),'modules_version',1) WHERE id='ayt';

CREATE OR REPLACE FUNCTION public._exam_payload(p_id uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT jsonb_build_object('id',a.id,'client_uuid',a.client_uuid,'exam_id',a.exam_id,'catalog_version',(a.definition->>'catalog_version')::integer,
 'name_tr',a.definition->>'name_tr','name_en',a.definition->>'name_en','started_at',a.started_at,'ends_at',a.ends_at,
 'finished_at',a.finished_at,'completed_at',CASE WHEN a.status='completed' THEN a.finished_at END,
 'status',a.status,'duration_seconds',CASE WHEN a.status='completed' THEN a.elapsed_seconds ELSE (a.definition->>'duration_seconds')::integer END,
 'planned_duration_seconds',(a.definition->>'duration_seconds')::integer,'credited_minutes',CASE WHEN a.status='completed' THEN a.elapsed_seconds/60 ELSE 0 END,
 'completion_kind',CASE WHEN a.status='completed' THEN CASE WHEN a.finished_at<a.ends_at THEN 'early' ELSE 'full' END END,
 'total_questions',(a.definition->>'total_questions')::integer,'wrong_answer_divisor',(a.definition->>'wrong_answer_divisor')::integer,'elapsed_seconds',a.elapsed_seconds,
 'points_earned',a.points_earned,'exam_coins_earned',a.exam_coins_earned,
 'definition',CASE WHEN a.exam_id='ayt' AND jsonb_array_length(public._exam_ayt_modules32(a.definition))=4 THEN a.definition||jsonb_build_object('modules',public._exam_ayt_modules32(a.definition),'modules_version',1) ELSE a.definition END,
 'subjects',a.definition->'subjects','title',a.title,'note',a.note,'selected_module_ids',to_jsonb(a.selected_module_ids),'details_revision',a.details_revision,
 'subject_results',coalesce((SELECT jsonb_agg(jsonb_build_object('subject_id',r.subject_id,'correct',r.correct,'wrong',r.wrong,'blank',r.blank,'net',r.net) ORDER BY r.subject_id) FROM public.exam_subject_results r WHERE r.attempt_id=a.id),'[]'::jsonb))
 FROM public.exam_attempts a WHERE a.id=p_id
$$;

CREATE OR REPLACE FUNCTION public.get_exam_config() RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT jsonb_build_object('schema_version',1,'available',to_regprocedure('public.get_my_exam_league_ranking(text)') IS NOT NULL,
 'server_time',clock_timestamp(),'capabilities',jsonb_build_object('exam_details',true,'ayt_modules_version',1,'ayt_early_finish',coalesce((SELECT early_enabled AND early_coin_mode='proportional' FROM public.exam_extension_policy WHERE singleton),false)),
 'exams',coalesce((SELECT jsonb_agg(definition ORDER BY id) FROM public.exam_catalog WHERE enabled),'[]'::jsonb))
$$;

CREATE OR REPLACE FUNCTION public._exam_has_overlap(p_user uuid,p_start timestamptz,p_end timestamptz) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT EXISTS(SELECT 1 FROM public.exam_attempts a WHERE a.user_id=p_user AND a.status IN('active','completed') AND a.started_at<p_end AND (CASE WHEN a.status='completed' THEN a.finished_at ELSE a.ends_at END)>p_start)
$$;

CREATE OR REPLACE FUNCTION public._competition_exam_event() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF NEW.status='completed' AND NEW.elapsed_seconds/60>0 THEN
  PERFORM public._competition_record('exam',NEW.id,NEW.user_id,NEW.started_at,NEW.finished_at,NEW.elapsed_seconds/60,NEW.points_earned);
 END IF;
 RETURN NEW;
END $$;

CREATE FUNCTION public.finish_ayt_early(p_attempt_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_uid uuid:=auth.uid();a public.exam_attempts%ROWTYPE;v_now timestamptz;v_elapsed integer;v_minutes integer;v_points integer;v_coins integer;v_mode text;v_enabled boolean;v_profile record;v_day date;v_streak integer;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 PERFORM 1 FROM public.profiles WHERE id=v_uid FOR UPDATE;
 SELECT * INTO a FROM public.exam_attempts WHERE id=p_attempt_id AND user_id=v_uid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'exam_not_found'; END IF;
 IF a.exam_id<>'ayt' THEN RAISE EXCEPTION 'exam_early_finish_not_supported'; END IF;
 IF a.status='completed' THEN RETURN jsonb_build_object('server_time',clock_timestamp(),'duplicate',true,'attempt',public._exam_payload(a.id)); END IF;
 IF a.status<>'active' THEN RAISE EXCEPTION 'exam_not_active'; END IF;
 v_now:=clock_timestamp();
 IF v_now>=a.ends_at THEN RETURN public.complete_exam_attempt(a.id); END IF;
 SELECT early_enabled,early_coin_mode INTO v_enabled,v_mode FROM public.exam_extension_policy WHERE singleton;
 IF NOT coalesce(v_enabled,false) OR v_mode IS DISTINCT FROM 'proportional' THEN RAISE EXCEPTION 'exam_early_finish_unavailable'; END IF;
 IF jsonb_array_length(public._exam_ayt_modules32(a.definition))<>4 THEN RAISE EXCEPTION 'exam_definition_unsupported'; END IF;
 v_elapsed:=floor(extract(epoch FROM(v_now-a.started_at)))::integer;
 IF v_elapsed<1 THEN RAISE EXCEPTION 'exam_early_finish_too_soon'; END IF;
 IF v_elapsed>(a.definition->>'duration_seconds')::integer THEN RAISE EXCEPTION 'exam_metadata_conflict'; END IF;
 IF EXISTS(SELECT 1 FROM public.study_sessions WHERE user_id=v_uid AND started_at<v_now AND completed_at>a.started_at) THEN RAISE EXCEPTION 'exam_overlap'; END IF;
 v_minutes:=v_elapsed/60;
 v_points:=least(v_elapsed/300,(a.definition->>'reward_points')::integer);
 v_coins:=least((a.definition->>'reward_coins')::integer,floor((a.definition->>'reward_coins')::numeric*v_elapsed/(a.definition->>'duration_seconds')::integer)::integer);
 IF v_minutes>0 THEN
  SELECT * INTO v_profile FROM public.profiles WHERE id=v_uid;
  v_day:=((a.started_at AT TIME ZONE v_profile.timezone)-interval '4 hours')::date;
  v_streak:=coalesce(v_profile.current_streak,0);
  IF v_profile.last_study_date IS NULL THEN v_streak:=1;
  ELSIF v_profile.last_study_date=v_day-1 THEN v_streak:=v_streak+1;
  ELSIF v_profile.last_study_date<v_day THEN v_streak:=1; END IF;
  UPDATE public.profiles SET total_minutes=coalesce(total_minutes,0)+v_minutes,current_streak=v_streak,longest_streak=greatest(coalesce(longest_streak,0),v_streak),last_study_date=greatest(coalesce(last_study_date,v_day),v_day) WHERE id=v_uid;
 END IF;
 UPDATE public.exam_attempts SET status='completed',finished_at=v_now,elapsed_seconds=v_elapsed,points_earned=v_points,exam_coins_earned=v_coins WHERE id=a.id;
 INSERT INTO public.exam_wallets(user_id,coins,lifetime_points) VALUES(v_uid,v_coins,v_points)
 ON CONFLICT(user_id) DO UPDATE SET coins=exam_wallets.coins+EXCLUDED.coins,lifetime_points=exam_wallets.lifetime_points+EXCLUDED.lifetime_points;
 RETURN jsonb_build_object('server_time',clock_timestamp(),'duplicate',false,'attempt',public._exam_payload(a.id));
END $$;

CREATE FUNCTION public._exam_validate_results32(p_definition jsonb,p_modules text[],p_results jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SET search_path=public,pg_temp AS $$
DECLARE r jsonb;s jsonb;sid text;seen text[]:=ARRAY[]::text[];allowed text[];c integer;w integer;b integer;result jsonb:='[]'::jsonb;
BEGIN
 IF p_results IS NULL THEN RETURN result; END IF;
 IF jsonb_typeof(p_results)<>'array' OR jsonb_array_length(p_results)>100 THEN RAISE EXCEPTION 'exam_result_invalid'; END IF;
 IF p_modules IS NOT NULL THEN
  SELECT array_agg(q.subject_id) INTO allowed FROM jsonb_array_elements(public._exam_ayt_modules32(p_definition))m CROSS JOIN LATERAL jsonb_array_elements_text(m->'subject_ids')q(subject_id) WHERE m->>'id'=ANY(p_modules);
 END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(p_results) LOOP
  IF jsonb_typeof(r)<>'object' THEN RAISE EXCEPTION 'exam_result_invalid'; END IF;
  sid:=r->>'subject_id';
  IF sid IS NULL OR sid=ANY(seen) OR EXISTS(SELECT 1 FROM jsonb_object_keys(r)k WHERE k NOT IN('subject_id','correct','wrong','blank')) THEN RAISE EXCEPTION 'exam_result_invalid'; END IF;
  IF p_modules IS NOT NULL AND NOT coalesce(sid=ANY(allowed),false) THEN RAISE EXCEPTION 'exam_scope_conflict'; END IF;
  SELECT value INTO s FROM jsonb_array_elements(p_definition->'subjects') WHERE value->>'id'=sid;
  IF NOT FOUND THEN RAISE EXCEPTION 'exam_result_invalid'; END IF;
  IF coalesce(r->>'correct','') !~ '^[0-9]{1,4}$' OR coalesce(r->>'wrong','') !~ '^[0-9]{1,4}$' OR coalesce(r->>'blank','') !~ '^[0-9]{1,4}$' OR jsonb_typeof(r->'correct')<>'number' OR jsonb_typeof(r->'wrong')<>'number' OR jsonb_typeof(r->'blank')<>'number' THEN RAISE EXCEPTION 'exam_result_invalid'; END IF;
  c:=(r->>'correct')::integer;w:=(r->>'wrong')::integer;b:=(r->>'blank')::integer;
  IF c+w+b<>(s->>'question_count')::integer THEN RAISE EXCEPTION 'exam_result_invalid'; END IF;
  result:=result||jsonb_build_array(jsonb_build_object('subject_id',sid,'correct',c,'wrong',w,'blank',b,'net',c-w/(p_definition->>'wrong_answer_divisor')::numeric));
  seen:=array_append(seen,sid);
 END LOOP;
 RETURN result;
END $$;

CREATE FUNCTION public._exam_apply_results32(p_attempt_id uuid,p_validated jsonb) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE changed integer;
BEGIN
 INSERT INTO public.exam_subject_results(attempt_id,subject_id,correct,wrong,blank,net)
 SELECT p_attempt_id,r->>'subject_id',(r->>'correct')::integer,(r->>'wrong')::integer,(r->>'blank')::integer,(r->>'net')::numeric FROM jsonb_array_elements(p_validated)r
 ON CONFLICT(attempt_id,subject_id) DO UPDATE SET correct=EXCLUDED.correct,wrong=EXCLUDED.wrong,blank=EXCLUDED.blank,net=EXCLUDED.net,updated_at=clock_timestamp()
 WHERE (exam_subject_results.correct,exam_subject_results.wrong,exam_subject_results.blank) IS DISTINCT FROM (EXCLUDED.correct,EXCLUDED.wrong,EXCLUDED.blank);
 GET DIAGNOSTICS changed=ROW_COUNT;
 RETURN changed;
END $$;

CREATE OR REPLACE FUNCTION public.save_exam_results(p_attempt_id uuid,p_subject_results jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_uid uuid:=auth.uid();a public.exam_attempts%ROWTYPE;validated jsonb;changed integer;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 PERFORM 1 FROM public.profiles WHERE id=v_uid FOR UPDATE;
 SELECT * INTO a FROM public.exam_attempts WHERE id=p_attempt_id AND user_id=v_uid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'exam_not_found'; END IF;
 IF a.status<>'completed' THEN RAISE EXCEPTION 'exam_not_active'; END IF;
 IF p_subject_results IS NULL THEN RAISE EXCEPTION 'exam_result_invalid'; END IF;
 validated:=public._exam_validate_results32(a.definition,a.selected_module_ids,p_subject_results);
 changed:=public._exam_apply_results32(a.id,validated);
 IF changed>0 THEN UPDATE public.exam_attempts SET details_revision=details_revision+1 WHERE id=a.id; END IF;
 RETURN jsonb_build_object('server_time',clock_timestamp(),'duplicate',changed=0,'attempt',public._exam_payload(a.id));
END $$;

CREATE FUNCTION public.save_exam_details(p_attempt_id uuid,p_details jsonb,p_subject_results jsonb DEFAULT NULL,p_expected_revision integer DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_uid uuid:=auth.uid();a public.exam_attempts%ROWTYPE;v_title text;v_note text;v_modules text[];raw_modules text[];allowed text[];validated jsonb;metadata_changed boolean;results_changed boolean;v_ignored integer;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 PERFORM 1 FROM public.profiles WHERE id=v_uid FOR UPDATE;
 SELECT * INTO a FROM public.exam_attempts WHERE id=p_attempt_id AND user_id=v_uid FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'exam_not_found'; END IF;
 IF a.status<>'completed' THEN RAISE EXCEPTION 'exam_not_active'; END IF;
 IF p_details IS NULL OR jsonb_typeof(p_details)<>'object' OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_details)k WHERE k NOT IN('title','note','selected_module_ids')) OR p_expected_revision<0 THEN RAISE EXCEPTION 'exam_details_invalid'; END IF;
 v_title:=a.title;v_note:=a.note;v_modules:=a.selected_module_ids;
 IF p_details?'title' THEN
  IF jsonb_typeof(p_details->'title') NOT IN('null','string') THEN RAISE EXCEPTION 'exam_details_invalid'; END IF;
  v_title:=nullif(btrim(p_details->>'title'),'');
  IF v_title IS NOT NULL AND (char_length(v_title)>120 OR v_title~'[[:cntrl:]]' OR position(chr(133) IN v_title)>0 OR position(chr(8232) IN v_title)>0 OR position(chr(8233) IN v_title)>0) THEN RAISE EXCEPTION 'exam_details_invalid'; END IF;
 END IF;
 IF p_details?'note' THEN
  IF jsonb_typeof(p_details->'note') NOT IN('null','string') THEN RAISE EXCEPTION 'exam_details_invalid'; END IF;
  v_note:=nullif(p_details->>'note','');
  IF v_note IS NOT NULL AND (char_length(v_note)>2000 OR regexp_replace(v_note,E'[\n\t]','','g')~'[[:cntrl:]]') THEN RAISE EXCEPTION 'exam_details_invalid'; END IF;
 END IF;
 IF p_details?'selected_module_ids' THEN
  IF a.exam_id<>'ayt' OR jsonb_typeof(p_details->'selected_module_ids')<>'array' OR jsonb_array_length(p_details->'selected_module_ids') NOT BETWEEN 1 AND 4 THEN RAISE EXCEPTION 'exam_details_invalid'; END IF;
  IF jsonb_array_length(public._exam_ayt_modules32(a.definition))<>4 THEN RAISE EXCEPTION 'exam_definition_unsupported'; END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_details->'selected_module_ids')x WHERE jsonb_typeof(x)<>'string') THEN RAISE EXCEPTION 'exam_details_invalid'; END IF;
  SELECT array_agg(x) INTO raw_modules FROM jsonb_array_elements_text(p_details->'selected_module_ids')x;
  IF cardinality(raw_modules)<>(SELECT count(DISTINCT x) FROM unnest(raw_modules)x) OR NOT raw_modules<@ARRAY['turkish_social_1','social_2','mathematics','science']::text[] THEN RAISE EXCEPTION 'exam_details_invalid'; END IF;
  SELECT array_agg(m->>'id' ORDER BY ord) INTO v_modules FROM jsonb_array_elements(public._exam_ayt_modules32(a.definition)) WITH ORDINALITY q(m,ord) WHERE m->>'id'=ANY(raw_modules);
 END IF;
 IF v_modules IS NOT NULL THEN
  SELECT array_agg(q.subject_id) INTO allowed FROM jsonb_array_elements(public._exam_ayt_modules32(a.definition))m CROSS JOIN LATERAL jsonb_array_elements_text(m->'subject_ids')q(subject_id) WHERE m->>'id'=ANY(v_modules);
  IF EXISTS(SELECT 1 FROM public.exam_subject_results WHERE attempt_id=a.id AND NOT coalesce(subject_id=ANY(allowed),false)) THEN RAISE EXCEPTION 'exam_scope_conflict'; END IF;
 END IF;
 validated:=public._exam_validate_results32(a.definition,v_modules,p_subject_results);
 metadata_changed:=(a.title,a.note,a.selected_module_ids) IS DISTINCT FROM (v_title,v_note,v_modules);
 SELECT EXISTS(SELECT 1 FROM jsonb_array_elements(validated)r LEFT JOIN public.exam_subject_results s ON s.attempt_id=a.id AND s.subject_id=r->>'subject_id' WHERE s.attempt_id IS NULL OR (s.correct,s.wrong,s.blank) IS DISTINCT FROM ((r->>'correct')::integer,(r->>'wrong')::integer,(r->>'blank')::integer)) INTO results_changed;
 -- Equality is checked before revision: a lost-ACK retry cannot overwrite a newer value.
 IF NOT metadata_changed AND NOT results_changed THEN RETURN jsonb_build_object('server_time',clock_timestamp(),'duplicate',true,'attempt',public._exam_payload(a.id)); END IF;
 IF p_expected_revision IS NOT NULL AND p_expected_revision<>a.details_revision THEN RAISE EXCEPTION 'exam_details_conflict'; END IF;
 UPDATE public.exam_attempts SET title=v_title,note=v_note,selected_module_ids=v_modules,details_revision=details_revision+1 WHERE id=a.id;
 v_ignored:=public._exam_apply_results32(a.id,validated);
 RETURN jsonb_build_object('server_time',clock_timestamp(),'duplicate',false,'attempt',public._exam_payload(a.id));
END $$;

REVOKE ALL ON FUNCTION public._exam_ayt_modules32(jsonb),public._exam_validate_results32(jsonb,text[],jsonb),public._exam_apply_results32(uuid,jsonb),public.finish_ayt_early(uuid),public.save_exam_details(uuid,jsonb,jsonb,integer) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.finish_ayt_early(uuid),public.save_exam_details(uuid,jsonb,jsonb,integer) TO authenticated;
INSERT INTO public.exam_extension_32_backup SELECT 'installed_function',p.oid::regprocedure::text,jsonb_build_object('md5',md5(pg_get_functiondef(p.oid)),'acl',to_jsonb(p.proacl)) FROM pg_proc p WHERE p.oid IN ('public._exam_payload(uuid)'::regprocedure,'public.get_exam_config()'::regprocedure,'public._exam_has_overlap(uuid,timestamptz,timestamptz)'::regprocedure,'public._competition_exam_event()'::regprocedure,'public.save_exam_results(uuid,jsonb)'::regprocedure,'public._exam_ayt_modules32(jsonb)'::regprocedure,'public._exam_validate_results32(jsonb,text[],jsonb)'::regprocedure,'public._exam_apply_results32(uuid,jsonb)'::regprocedure,'public.finish_ayt_early(uuid)'::regprocedure,'public.save_exam_details(uuid,jsonb,jsonb,integer)'::regprocedure);
INSERT INTO public.exam_extension_32_backup SELECT 'installed_catalog',id,jsonb_build_object('definition',definition,'enabled',enabled) FROM public.exam_catalog;
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261028060000','exam_details_early_finish');
-- END 32_exam_details_early_finish
DO $$ DECLARE n timestamptz:=clock_timestamp(); start_month timestamptz;
BEGIN
 start_month := date_trunc('month', n AT TIME ZONE 'Europe/Istanbul') AT TIME ZONE 'Europe/Istanbul';
 IF date_trunc('month', now() AT TIME ZONE 'Europe/Istanbul') <>
    date_trunc('month', n AT TIME ZONE 'Europe/Istanbul') OR
    n < start_month + interval '5 minutes' OR
    n >= ((start_month AT TIME ZONE 'Europe/Istanbul' + interval '1 month') AT TIME ZONE 'Europe/Istanbul') - interval '5 minutes'
 THEN RAISE EXCEPTION 'release_month_boundary_unsafe'; END IF;
END $$;

CREATE TEMP TABLE release_checks(name text PRIMARY KEY, passed boolean NOT NULL) ON COMMIT DROP;
INSERT INTO release_checks VALUES
 ('unchanged_profiles', (SELECT digest FROM release_before WHERE name='profiles') = (SELECT md5(coalesce(string_agg(to_jsonb(t)::text, '|' ORDER BY to_jsonb(t)::text), '')) FROM public.profiles t)),
 ('unchanged_sessions', (SELECT digest FROM release_before WHERE name='sessions') = (SELECT md5(coalesce(string_agg(to_jsonb(t)::text, '|' ORDER BY to_jsonb(t)::text), '')) FROM public.study_sessions t)),
 ('unchanged_leagues', (SELECT digest FROM release_before WHERE name='leagues') = (SELECT md5(coalesce(string_agg(to_jsonb(t)::text, '|' ORDER BY to_jsonb(t)::text), '')) FROM public.leagues t)),
 ('unchanged_memberships', (SELECT digest FROM release_before WHERE name='memberships') = (SELECT md5(coalesce(string_agg(to_jsonb(t)::text, '|' ORDER BY to_jsonb(t)::text), '')) FROM public.league_memberships t)),
 ('unchanged_starts', (SELECT digest FROM release_before WHERE name='starts') = (SELECT md5(coalesce(string_agg(to_jsonb(t)::text, '|' ORDER BY to_jsonb(t)::text), '')) FROM public.session_starts t)),
 ('unchanged_unlocks', (SELECT digest FROM release_before WHERE name='unlocks') = (SELECT md5(coalesce(string_agg(to_jsonb(t)::text, '|' ORDER BY to_jsonb(t)::text), '')) FROM public.avatar_unlocks t)),
 ('twenty_exact_catalog_definitions',
  (SELECT count(*)=20 AND bool_and(enabled) FROM public.exam_catalog) AND
  (SELECT jsonb_object_agg(id,definition) FROM public.exam_catalog) =
  (SELECT jsonb_object_agg(value->>'id',value) FROM jsonb_array_elements('[{"id":"tyt","name_tr":"TYT","name_en":"TYT","segment":"yks","group":"yks","duration_seconds":9900,"total_questions":120,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":33,"reward_coins":130,"subjects":[{"id":"turkish","name_tr":"Türkçe","name_en":"Turkish","question_count":40,"category_keys":["Türkçe"]},{"id":"mathematics","name_tr":"Temel Matematik","name_en":"Basic Mathematics","question_count":40,"category_keys":["Matematik"]},{"id":"history","name_tr":"Tarih","name_en":"History","question_count":5,"category_keys":["Tarih"]},{"id":"geography","name_tr":"Coğrafya","name_en":"Geography","question_count":5,"category_keys":["Coğrafya"]},{"id":"philosophy","name_tr":"Felsefe","name_en":"Philosophy","question_count":5,"category_keys":["Felsefe"]},{"id":"religion","name_tr":"Din Kültürü / İlave Felsefe","name_en":"Religious Culture / Additional Philosophy","question_count":5,"category_keys":["Din Kültürü"]},{"id":"physics","name_tr":"Fizik","name_en":"Physics","question_count":7,"category_keys":["Fizik"]},{"id":"chemistry","name_tr":"Kimya","name_en":"Chemistry","question_count":7,"category_keys":["Kimya"]},{"id":"biology","name_tr":"Biyoloji","name_en":"Biology","question_count":6,"category_keys":["Biyoloji"]}],"reward_policy_version":2},{"id":"ayt","name_tr":"AYT","name_en":"AYT","segment":"yks","group":"yks","duration_seconds":10800,"total_questions":160,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":36,"reward_coins":145,"subjects":[{"id":"literature","name_tr":"Türk Dili ve Edebiyatı","name_en":"Turkish Language and Literature","question_count":24,"category_keys":["Edebiyat","Türkçe"]},{"id":"history_1","name_tr":"Tarih-1","name_en":"History-1","question_count":10,"category_keys":["Tarih"]},{"id":"geography_1","name_tr":"Coğrafya-1","name_en":"Geography-1","question_count":6,"category_keys":["Coğrafya"]},{"id":"history_2","name_tr":"Tarih-2","name_en":"History-2","question_count":11,"category_keys":["Tarih"]},{"id":"geography_2","name_tr":"Coğrafya-2","name_en":"Geography-2","question_count":11,"category_keys":["Coğrafya"]},{"id":"philosophy_group","name_tr":"Felsefe Grubu","name_en":"Philosophy Group","question_count":12,"category_keys":["Felsefe"]},{"id":"religion","name_tr":"Din Kültürü / İlave Felsefe","name_en":"Religious Culture / Additional Philosophy","question_count":6,"category_keys":["Din Kültürü"]},{"id":"mathematics","name_tr":"Matematik","name_en":"Mathematics","question_count":40,"category_keys":["Matematik"]},{"id":"physics","name_tr":"Fizik","name_en":"Physics","question_count":14,"category_keys":["Fizik"]},{"id":"chemistry","name_tr":"Kimya","name_en":"Chemistry","question_count":13,"category_keys":["Kimya"]},{"id":"biology","name_tr":"Biyoloji","name_en":"Biology","question_count":13,"category_keys":["Biyoloji"]}],"reward_policy_version":2,"modules":[{"id":"turkish_social_1","name_tr":"Türk Dili ve Edebiyatı–Sosyal Bilimler-1","name_en":"Turkish Language and Literature–Social Sciences-1","subject_ids":["literature","history_1","geography_1"]},{"id":"social_2","name_tr":"Sosyal Bilimler-2","name_en":"Social Sciences-2","subject_ids":["history_2","geography_2","philosophy_group","religion"]},{"id":"mathematics","name_tr":"Matematik","name_en":"Mathematics","subject_ids":["mathematics"]},{"id":"science","name_tr":"Fen Bilimleri","name_en":"Science","subject_ids":["physics","chemistry","biology"]}],"modules_version":1},{"id":"ydt","name_tr":"YDT","name_en":"YDT","segment":"yks","group":"yks","duration_seconds":7200,"total_questions":80,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":24,"reward_coins":95,"subjects":[{"id":"foreign_language","name_tr":"Yabancı Dil","name_en":"Foreign Language","question_count":80,"category_keys":["İngilizce"]}],"reward_policy_version":2},{"id":"lgs_verbal","name_tr":"LGS Sözel","name_en":"LGS Verbal","segment":"lgs","group":"lgs","duration_seconds":4500,"total_questions":50,"wrong_answer_divisor":3,"catalog_version":1,"reward_points":15,"reward_coins":60,"subjects":[{"id":"turkish","name_tr":"Türkçe","name_en":"Turkish","question_count":20,"category_keys":["Türkçe"]},{"id":"revolution_history","name_tr":"T.C. İnkılap Tarihi","name_en":"Turkish Revolution History","question_count":10,"category_keys":["T.C. İnkılap Tarihi"]},{"id":"religion","name_tr":"Din Kültürü","name_en":"Religious Culture","question_count":10,"category_keys":["Din Kültürü"]},{"id":"foreign_language","name_tr":"Yabancı Dil","name_en":"Foreign Language","question_count":10,"category_keys":["İngilizce"]}],"reward_policy_version":2},{"id":"lgs_quantitative","name_tr":"LGS Sayısal","name_en":"LGS Quantitative","segment":"lgs","group":"lgs","duration_seconds":4800,"total_questions":40,"wrong_answer_divisor":3,"catalog_version":1,"reward_points":16,"reward_coins":70,"subjects":[{"id":"mathematics","name_tr":"Matematik","name_en":"Mathematics","question_count":20,"category_keys":["Matematik"]},{"id":"science","name_tr":"Fen Bilimleri","name_en":"Science","question_count":20,"category_keys":["Fen Bilimleri"]}],"reward_policy_version":2},{"id":"tus_basic","name_tr":"TUS Temel Tıp","name_en":"TUS Basic Medicine","segment":"tus","group":"tus","duration_seconds":8100,"total_questions":100,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":27,"reward_coins":110,"subjects":[{"id":"anatomy","name_tr":"Anatomi","name_en":"Anatomy","question_count":13,"category_keys":["Anatomi"]},{"id":"histology_embryology","name_tr":"Histoloji ve Embriyoloji","name_en":"Histology and Embryology","question_count":7,"category_keys":["Fizyoloji, Histoloji ve Embriyoloji"]},{"id":"physiology","name_tr":"Fizyoloji","name_en":"Physiology","question_count":8,"category_keys":["Fizyoloji, Histoloji ve Embriyoloji"]},{"id":"biochemistry","name_tr":"Biyokimya","name_en":"Biochemistry","question_count":18,"category_keys":["Biyokimya"]},{"id":"microbiology","name_tr":"Mikrobiyoloji","name_en":"Microbiology","question_count":18,"category_keys":["Mikrobiyoloji"]},{"id":"pathology","name_tr":"Patoloji","name_en":"Pathology","question_count":18,"category_keys":["Patoloji"]},{"id":"pharmacology","name_tr":"Farmakoloji","name_en":"Pharmacology","question_count":18,"category_keys":["Farmakoloji"]}],"reward_policy_version":2},{"id":"tus_clinical","name_tr":"TUS Klinik Tıp","name_en":"TUS Clinical Medicine","segment":"tus","group":"tus","duration_seconds":8100,"total_questions":100,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":27,"reward_coins":110,"subjects":[{"id":"internal_medicine_group","name_tr":"Dahiliye Grubu","name_en":"Internal Medicine Group","question_count":35,"category_keys":["Dahiliye"]},{"id":"pediatrics","name_tr":"Pediatri","name_en":"Pediatrics","question_count":25,"category_keys":["Pediatri"]},{"id":"surgery_group","name_tr":"Cerrahi Grubu","name_en":"Surgery Group","question_count":30,"category_keys":["Genel Cerrahi"]},{"id":"obstetrics_gynecology","name_tr":"Kadın Hastalıkları ve Doğum","name_en":"Obstetrics and Gynecology","question_count":10,"category_keys":["Kadın Hastalıkları ve Doğum"]}],"reward_policy_version":2},{"id":"dus","name_tr":"DUS","name_en":"DUS","segment":"dus","group":"dus","duration_seconds":9000,"total_questions":120,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":30,"reward_coins":120,"subjects":[{"id":"anatomy","name_tr":"Anatomi","name_en":"Anatomy","question_count":6,"category_keys":["Anatomi"]},{"id":"histology_embryology","name_tr":"Histoloji ve Embriyoloji","name_en":"Histology and Embryology","question_count":4,"category_keys":["Histoloji ve Embriyoloji"]},{"id":"physiology","name_tr":"Fizyoloji","name_en":"Physiology","question_count":6,"category_keys":["Fizyoloji"]},{"id":"biochemistry","name_tr":"Tıbbi Biyokimya","name_en":"Medical Biochemistry","question_count":6,"category_keys":["Biyokimya"]},{"id":"microbiology","name_tr":"Tıbbi Mikrobiyoloji","name_en":"Medical Microbiology","question_count":6,"category_keys":["Mikrobiyoloji"]},{"id":"pathology","name_tr":"Tıbbi Patoloji","name_en":"Medical Pathology","question_count":4,"category_keys":["Patoloji"]},{"id":"pharmacology","name_tr":"Tıbbi Farmakoloji","name_en":"Medical Pharmacology","question_count":4,"category_keys":["Farmakoloji"]},{"id":"medical_biology_genetics","name_tr":"Tıbbi Biyoloji ve Genetik","name_en":"Medical Biology and Genetics","question_count":4,"category_keys":["Tıbbi Biyoloji ve Genetik"]},{"id":"restorative_dentistry","name_tr":"Restoratif Diş Tedavisi","name_en":"Restorative Dentistry","question_count":10,"category_keys":["Restoratif Diş Tedavisi"]},{"id":"prosthetic_dentistry","name_tr":"Protetik Diş Tedavisi","name_en":"Prosthodontics","question_count":10,"category_keys":["Protetik Diş Tedavisi"]},{"id":"oral_maxillofacial_surgery","name_tr":"Ağız, Diş ve Çene Cerrahisi","name_en":"Oral and Maxillofacial Surgery","question_count":10,"category_keys":["Ağız, Diş ve Çene Cerrahisi"]},{"id":"oral_maxillofacial_radiology","name_tr":"Ağız, Diş ve Çene Radyolojisi","name_en":"Oral and Maxillofacial Radiology","question_count":10,"category_keys":["Ağız, Diş ve Çene Radyolojisi"]},{"id":"periodontology","name_tr":"Periodontoloji","name_en":"Periodontology","question_count":10,"category_keys":["Periodontoloji"]},{"id":"orthodontics","name_tr":"Ortodonti","name_en":"Orthodontics","question_count":10,"category_keys":["Ortodonti"]},{"id":"endodontics","name_tr":"Endodonti","name_en":"Endodontics","question_count":10,"category_keys":["Endodonti"]},{"id":"pediatric_dentistry","name_tr":"Çocuk Diş Hekimliği","name_en":"Pediatric Dentistry","question_count":10,"category_keys":["Çocuk Diş Hekimliği"]}],"reward_policy_version":2},{"id":"kpss_bachelor_gygk","name_tr":"KPSS Lisans · Genel Yetenek–Genel Kültür","name_en":"KPSS Bachelor’s · General Ability–General Knowledge","segment":"kpss","group":"kpss","duration_seconds":7800,"total_questions":120,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":26,"reward_coins":105,"subjects":[{"id":"general_ability","name_tr":"Genel Yetenek","name_en":"General Ability","question_count":60,"category_keys":["Türkçe","Matematik","Genel Yetenek"]},{"id":"general_knowledge","name_tr":"Genel Kültür","name_en":"General Knowledge","question_count":60,"category_keys":["Tarih","Coğrafya","Vatandaşlık","Güncel Bilgiler","Genel Kültür"]}],"reward_policy_version":2},{"id":"kpss_associate_gygk","name_tr":"KPSS Ön Lisans · Genel Yetenek–Genel Kültür","name_en":"KPSS Associate Degree · General Ability–General Knowledge","segment":"kpss","group":"kpss","duration_seconds":7800,"total_questions":120,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":26,"reward_coins":105,"subjects":[{"id":"general_ability","name_tr":"Genel Yetenek","name_en":"General Ability","question_count":60,"category_keys":["Türkçe","Matematik","Genel Yetenek"]},{"id":"general_knowledge","name_tr":"Genel Kültür","name_en":"General Knowledge","question_count":60,"category_keys":["Tarih","Coğrafya","Vatandaşlık","Güncel Bilgiler","Genel Kültür"]}],"reward_policy_version":2},{"id":"kpss_secondary_gygk","name_tr":"KPSS Ortaöğretim · Genel Yetenek–Genel Kültür","name_en":"KPSS Secondary Education · General Ability–General Knowledge","segment":"kpss","group":"kpss","duration_seconds":7800,"total_questions":120,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":26,"reward_coins":105,"subjects":[{"id":"general_ability","name_tr":"Genel Yetenek","name_en":"General Ability","question_count":60,"category_keys":["Türkçe","Matematik","Genel Yetenek"]},{"id":"general_knowledge","name_tr":"Genel Kültür","name_en":"General Knowledge","question_count":60,"category_keys":["Tarih","Coğrafya","Vatandaşlık","Güncel Bilgiler","Genel Kültür"]}],"reward_policy_version":2},{"id":"kpss_field_business","name_tr":"KPSS Alan Bilgisi · İşletme","name_en":"KPSS Field Knowledge · Business Administration","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":40,"subjects":[{"id":"business","name_tr":"İşletme","name_en":"Business Administration","question_count":40,"category_keys":["İşletme"]}],"reward_policy_version":2},{"id":"kpss_field_accounting","name_tr":"KPSS Alan Bilgisi · Muhasebe","name_en":"KPSS Field Knowledge · Accounting","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":40,"subjects":[{"id":"accounting","name_tr":"Muhasebe","name_en":"Accounting","question_count":40,"category_keys":["Muhasebe"]}],"reward_policy_version":2},{"id":"kpss_field_law","name_tr":"KPSS Alan Bilgisi · Hukuk","name_en":"KPSS Field Knowledge · Law","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":40,"subjects":[{"id":"law","name_tr":"Hukuk","name_en":"Law","question_count":40,"category_keys":["Hukuk"]}],"reward_policy_version":2},{"id":"kpss_field_public_administration","name_tr":"KPSS Alan Bilgisi · Kamu Yönetimi","name_en":"KPSS Field Knowledge · Public Administration","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":40,"subjects":[{"id":"public_administration","name_tr":"Kamu Yönetimi","name_en":"Public Administration","question_count":40,"category_keys":["Kamu Yönetimi"]}],"reward_policy_version":2},{"id":"kpss_field_economics","name_tr":"KPSS Alan Bilgisi · İktisat","name_en":"KPSS Field Knowledge · Economics","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":40,"subjects":[{"id":"economics","name_tr":"İktisat","name_en":"Economics","question_count":40,"category_keys":["İktisat"]}],"reward_policy_version":2},{"id":"kpss_field_finance","name_tr":"KPSS Alan Bilgisi · Maliye","name_en":"KPSS Field Knowledge · Public Finance","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":40,"subjects":[{"id":"finance","name_tr":"Maliye","name_en":"Public Finance","question_count":40,"category_keys":["Maliye"]}],"reward_policy_version":2},{"id":"kpss_field_international_relations","name_tr":"KPSS Alan Bilgisi · Uluslararası İlişkiler","name_en":"KPSS Field Knowledge · International Relations","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":40,"subjects":[{"id":"international_relations","name_tr":"Uluslararası İlişkiler","name_en":"International Relations","question_count":40,"category_keys":["Uluslararası İlişkiler"]}],"reward_policy_version":2},{"id":"kpss_field_labour_economics","name_tr":"KPSS Alan Bilgisi · Çalışma Ekonomisi ve Endüstri İlişkileri","name_en":"KPSS Field Knowledge · Labour Economics and Industrial Relations","segment":"kpss","group":"kpss","duration_seconds":3000,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":10,"reward_coins":40,"subjects":[{"id":"labour_economics","name_tr":"Çalışma Ekonomisi ve Endüstri İlişkileri","name_en":"Labour Economics and Industrial Relations","question_count":40,"category_keys":["Çalışma Ekonomisi ve Endüstri İlişkileri"]}],"reward_policy_version":2},{"id":"kpss_field_statistics","name_tr":"KPSS Alan Bilgisi · İstatistik","name_en":"KPSS Field Knowledge · Statistics","segment":"kpss","group":"kpss","duration_seconds":3600,"total_questions":40,"wrong_answer_divisor":4,"catalog_version":1,"reward_points":12,"reward_coins":50,"subjects":[{"id":"statistics","name_tr":"İstatistik","name_en":"Statistics","question_count":40,"category_keys":["İstatistik"]}],"reward_policy_version":2}]'::jsonb))),
 ('exam_available_and_details_enabled',
  coalesce((public.get_exam_config()->>'available')::boolean,false) AND
  coalesce((public.get_exam_config()->'capabilities'->>'exam_details')::boolean,false) AND
  coalesce((public.get_exam_config()->'capabilities'->>'ayt_early_finish')::boolean,false)),
 ('all_five_versions_and_no_31',
  (SELECT count(*)=5 FROM supabase_migrations.schema_migrations WHERE version IN
    ('20261028010000','20261028020000','20261028030000','20261028040000','20261028060000')) AND
  NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261028050000')),
 ('next_month_activation',
  (SELECT activates_at=public._competition_month_time((public._competition_month(now())+interval '1 month')::date)
          AND NOT legacy_finalized FROM public.competition_policy WHERE singleton)),
 ('monthly_backfill_count',
  (SELECT count(*) FROM public.competition_events WHERE kind='study') =
  (SELECT count(*) FROM public.study_sessions WHERE completed_at>=public._competition_month_time(public._competition_month(now())))),
 ('new_cron_daily',
  (SELECT count(*)=1 AND bool_and(active AND schedule='1 21 * * *' AND command='SELECT public.process_weekly_leagues();' AND database=current_database() AND username=current_user) FROM cron.job WHERE jobname='weekly_leagues_job') AND
  (SELECT to_jsonb(j)-'schedule'-'command' FROM cron.job j WHERE jobname='weekly_leagues_job') =
  (SELECT snapshot-'schedule'-'command' FROM release_cron_before)),
 ('private_attempts_and_wallets',
  (SELECT bool_and(relrowsecurity) FROM pg_class WHERE oid IN ('public.exam_attempts'::regclass,'public.exam_subject_results'::regclass,'public.exam_wallets'::regclass)) AND
  NOT has_table_privilege('authenticated','public.exam_attempts','INSERT,UPDATE,DELETE') AND
  NOT has_function_privilege('anon','public.finish_ayt_early(uuid)','EXECUTE')),
 ('no_existing_exam_data',NOT EXISTS(SELECT 1 FROM public.exam_attempts) AND NOT EXISTS(SELECT 1 FROM public.exam_wallets));
DO $$ DECLARE failures text; BEGIN
 SELECT string_agg(name, ', ' ORDER BY name) INTO failures FROM release_checks WHERE NOT passed;
 IF failures IS NOT NULL THEN RAISE EXCEPTION 'release_postconditions_failed: %',failures; END IF;
END $$;
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261101210000','atomic_exam_release');
SELECT name,passed FROM release_checks ORDER BY name;
ROLLBACK;

SELECT '14/14 kontrol başarılı; işlem geri alındı. Kurulum yapılmadı.' AS dryrun_sonucu;
