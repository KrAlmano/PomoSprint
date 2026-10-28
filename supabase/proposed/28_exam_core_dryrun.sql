-- DRYRUN: deliberately rolls everything back with DRYRUN_RESULT.
BEGIN;
CREATE TEMP TABLE qa_before(k text primary key,n bigint);
INSERT INTO qa_before VALUES('profiles',(select count(*)from public.profiles)),('sessions',(select count(*)from public.study_sessions)),('unlocks',(select count(*)from public.avatar_unlocks));
-- >>> PROPOSED BODY

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

-- <<< PROPOSED BODY
CREATE TEMP TABLE qa_checks(name text,passed boolean);
INSERT INTO qa_checks VALUES('T01 eight exam definitions',coalesce(((select count(*)from public.exam_catalog)=8),false));
INSERT INTO qa_checks VALUES('T02 totals match',coalesce((not exists(select 1 from public.exam_catalog c where (c.definition->>'total_questions')::int<>(select sum((value->>'question_count')::int)from jsonb_array_elements(c.definition->'subjects')))),false));
INSERT INTO qa_checks VALUES('T03 no league means unavailable',coalesce((not(public.get_exam_config()->>'available')::boolean),false));
INSERT INTO qa_checks VALUES('T04 attempt owner RLS',coalesce(((select relrowsecurity from pg_class where oid='public.exam_attempts'::regclass)),false));
INSERT INTO qa_checks VALUES('T05 result owner RLS',coalesce(((select relrowsecurity from pg_class where oid='public.exam_subject_results'::regclass)),false));
INSERT INTO qa_checks VALUES('T06 no direct attempt mutation',coalesce((not has_table_privilege('authenticated','public.exam_attempts','INSERT,UPDATE,DELETE')),false));
INSERT INTO qa_checks VALUES('T07 no anon private payload',coalesce((not has_function_privilege('anon','public._exam_payload(uuid)','EXECUTE')),false));
INSERT INTO qa_checks VALUES('T08 owner RPC grant',coalesce((has_function_privilege('authenticated','public.complete_exam_attempt(uuid)','EXECUTE')),false));
INSERT INTO qa_checks VALUES('T09 no caller duration argument',coalesce((to_regprocedure('public.start_exam_attempt(uuid,text)')is not null),false));
INSERT INTO qa_checks VALUES('T10 DUS standard plan',coalesce((select (definition->>'duration_seconds')::integer=9000 AND (definition->>'total_questions')::integer=120 AND jsonb_array_length(definition->'subjects')=16 AND definition->>'segment'='dus' from public.exam_catalog where id='dus'),false));
-- D-05 functional recovery uses only a fresh synthetic owner and rows created
-- in this rollback transaction. It never touches an existing user or sends mail.
CREATE FUNCTION public.get_my_exam_league_ranking(p_scope text) RETURNS jsonb LANGUAGE sql AS $$ SELECT '{}'::jsonb $$;
DO $$
DECLARE owner_id uuid:=gen_random_uuid();first_uuid uuid:=gen_random_uuid();second_uuid uuid:=gen_random_uuid();first_id uuid;second_id uuid;response jsonb;blocked boolean:=false;
BEGIN
 INSERT INTO auth.users(id,email,aud,role,raw_user_meta_data,created_at)
 VALUES(owner_id,'dryrun-d05-'||owner_id||'@pomosprint.local','authenticated','authenticated','{"name":"DRYRUN D05","newsletter":false,"marketing_consent":false}'::jsonb,now());
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',owner_id,'role','authenticated')::text,true);
 response:=public.start_exam_attempt(first_uuid,'lgs_verbal');first_id:=(response->'attempt'->>'id')::uuid;
 UPDATE public.exam_attempts SET started_at=clock_timestamp()-interval '151 minutes',ends_at=clock_timestamp()-interval '76 minutes' WHERE id=first_id;
 response:=public.start_exam_attempt(second_uuid,'lgs_verbal');second_id:=(response->'attempt'->>'id')::uuid;
 INSERT INTO qa_checks VALUES('T30 expired active settles before new start',(SELECT status='completed' AND points_earned=15 AND exam_coins_earned=3 FROM public.exam_attempts WHERE id=first_id) AND response->'attempt'->>'status'='active');
 INSERT INTO qa_checks VALUES('T31 recovered duration credited once',(SELECT total_minutes=75 FROM public.profiles WHERE id=owner_id) AND(SELECT coins=3 AND lifetime_points=15 FROM public.exam_wallets WHERE user_id=owner_id));
 response:=public.start_exam_attempt(second_uuid,'lgs_verbal');
 INSERT INTO qa_checks VALUES('T32 same active UUID remains idempotent',(response->>'duplicate')::boolean AND response->'attempt'->>'status'='active');
 BEGIN PERFORM public.start_exam_attempt(gen_random_uuid(),'lgs_verbal');EXCEPTION WHEN OTHERS THEN blocked:=SQLERRM='exam_overlap';END;
 INSERT INTO qa_checks VALUES('T33 unexpired active still blocks',blocked);
 UPDATE public.exam_attempts SET started_at=clock_timestamp()-interval '75 minutes 1 second',ends_at=clock_timestamp()-interval '1 second' WHERE id=second_id;
 response:=public.start_exam_attempt(second_uuid,'lgs_verbal');
 INSERT INTO qa_checks VALUES('T34 same expired UUID returns completed',(response->>'duplicate')::boolean AND response->'attempt'->>'status'='completed');
 response:=public.start_exam_attempt(second_uuid,'lgs_verbal');
 INSERT INTO qa_checks VALUES('T35 completion retry cannot award twice',(SELECT coins=6 AND lifetime_points=30 FROM public.exam_wallets WHERE user_id=owner_id));
 DELETE FROM auth.users WHERE id=owner_id;
 PERFORM set_config('request.jwt.claims','{}',true);
END $$;
DROP FUNCTION public.get_my_exam_league_ranking(text);
INSERT INTO qa_checks VALUES('T98 existing profile count',coalesce(((select count(*)from public.profiles)=(select n from qa_before where k='profiles')),false));
INSERT INTO qa_checks VALUES('T99 existing sessions unchanged',coalesce(((select count(*)from public.study_sessions)=(select n from qa_before where k='sessions')),false));
DO $$ DECLARE v text;BEGIN SELECT string_agg(name||': '||passed::text,' || ' ORDER BY name) INTO v FROM qa_checks;RAISE EXCEPTION 'DRYRUN_RESULT >> %',v;END $$;
ROLLBACK;
