-- Proposed32 transaction-only structure check; intentional error rolls everything back.
BEGIN;
CREATE TEMP TABLE qa32_before AS SELECT (SELECT count(*) FROM public.profiles) profiles,(SELECT count(*) FROM public.exam_attempts) attempts,(SELECT coalesce(jsonb_agg(to_jsonb(w) ORDER BY user_id),'[]'::jsonb) FROM public.exam_wallets w) wallets,(SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY kind,source_id),'[]'::jsonb) FROM public.competition_events e) events;
-- >>> PROPOSED BODY
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

-- <<< PROPOSED BODY
CREATE TEMP TABLE qa32_checks(name text PRIMARY KEY,passed boolean NOT NULL);
INSERT INTO qa32_checks VALUES
 ('D01 migration32 present',EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261028060000')),
 ('D02 migration31 absent',NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261028050000')),
 ('D03 twenty exam definitions preserved',(SELECT count(*)=20 FROM public.exam_catalog)),
 ('D04 exact full coins',(SELECT bool_and((definition->>'reward_coins')::integer=CASE id WHEN 'tyt' THEN 130 WHEN 'ayt' THEN 145 WHEN 'ydt' THEN 95 WHEN 'lgs_verbal' THEN 60 WHEN 'lgs_quantitative' THEN 70 WHEN 'tus_basic' THEN 110 WHEN 'tus_clinical' THEN 110 WHEN 'dus' THEN 120 WHEN 'kpss_bachelor_gygk' THEN 105 WHEN 'kpss_associate_gygk' THEN 105 WHEN 'kpss_secondary_gygk' THEN 105 WHEN 'kpss_field_business' THEN 40 WHEN 'kpss_field_accounting' THEN 40 WHEN 'kpss_field_law' THEN 40 WHEN 'kpss_field_public_administration' THEN 40 WHEN 'kpss_field_economics' THEN 40 WHEN 'kpss_field_finance' THEN 40 WHEN 'kpss_field_international_relations' THEN 40 WHEN 'kpss_field_labour_economics' THEN 40 WHEN 'kpss_field_statistics' THEN 50 END) FROM public.exam_catalog)),
 ('D05 all question versions remain1',(SELECT bool_and((definition->>'catalog_version')::integer=1) FROM public.exam_catalog)),
 ('D06 four AYT modules',jsonb_array_length((SELECT definition->'modules' FROM public.exam_catalog WHERE id='ayt'))=4),
 ('D07 existing profile count unchanged',(SELECT count(*) FROM public.profiles)=(SELECT profiles FROM qa32_before)),
 ('D08 existing attempts unchanged',(SELECT count(*) FROM public.exam_attempts)=(SELECT attempts FROM qa32_before)),
 ('D09 wallets unchanged',(SELECT coalesce(jsonb_agg(to_jsonb(w) ORDER BY user_id),'[]'::jsonb) FROM public.exam_wallets w)=(SELECT wallets FROM qa32_before)),
 ('D10 competition events unchanged',(SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY kind,source_id),'[]'::jsonb) FROM public.competition_events e)=(SELECT events FROM qa32_before)),
 ('D11 private backup and policy',NOT has_table_privilege('authenticated','public.exam_extension_32_backup','SELECT') AND NOT has_table_privilege('authenticated','public.exam_extension_policy','SELECT')),
 ('D12 helpers private',NOT has_function_privilege('authenticated','public._exam_apply_results32(uuid,jsonb)','EXECUTE') AND NOT has_function_privilege('anon','public.finish_ayt_early(uuid)','EXECUTE')),
 ('D13 owner RPC granted',has_function_privilege('authenticated','public.finish_ayt_early(uuid)','EXECUTE') AND has_function_privilege('authenticated','public.save_exam_details(uuid,jsonb,jsonb,integer)','EXECUTE')),
 ('D14 columns owner-read only',NOT has_column_privilege('authenticated','public.exam_attempts','title','UPDATE')),
 ('D15 all reward policy v2',(SELECT bool_and((definition->>'reward_policy_version')::integer=2) FROM public.exam_catalog)),
 ('D16 KPSS family complete',(SELECT count(*)=12 FROM public.exam_catalog WHERE definition->>'segment'='kpss')),
 ('D17 KPSS GY GK official totals',(SELECT count(*)=3 AND bool_and((definition->>'duration_seconds')::int=7800 AND (definition->>'total_questions')::int=120 AND (definition->>'reward_coins')::int=105) FROM public.exam_catalog WHERE id LIKE 'kpss_%_gygk'));
DO $$ DECLARE result jsonb;BEGIN SELECT jsonb_object_agg(name,passed ORDER BY name) INTO result FROM qa32_checks;RAISE EXCEPTION 'DRYRUN_RESULT >> %',result;END $$;
ROLLBACK;
