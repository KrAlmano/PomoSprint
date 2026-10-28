-- DRYRUN: deliberately rolls everything back with DRYRUN_RESULT.
BEGIN;
CREATE TEMP TABLE qa_before(k text primary key,n bigint);
INSERT INTO qa_before VALUES('profiles',(select count(*)from public.profiles)),('sessions',(select count(*)from public.study_sessions)),('unlocks',(select count(*)from public.avatar_unlocks));
-- >>> PROPOSED BODY

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

-- <<< PROPOSED BODY
CREATE TEMP TABLE qa_checks(name text,passed boolean);
INSERT INTO qa_checks VALUES('T00 DUS constraint',coalesce((position('dus' in (select pg_get_constraintdef(oid)from pg_constraint where conrelid='public.profiles'::regclass and conname='profiles_user_segment_check'))>0),false));
INSERT INTO qa_checks VALUES('T01 TUS constraint',coalesce((position('tus' in (select pg_get_constraintdef(oid)from pg_constraint where conrelid='public.profiles'::regclass and conname='profiles_user_segment_check'))>0),false));
INSERT INTO qa_checks VALUES('T02 existing segment names',coalesce((position('kpss' in (select pg_get_constraintdef(oid)from pg_constraint where conrelid='public.profiles'::regclass and conname='profiles_user_segment_check'))>0),false));
INSERT INTO qa_checks VALUES('T03 migration once',coalesce(((select count(*)from supabase_migrations.schema_migrations where version='20261028010000')=1),false));
INSERT INTO qa_checks VALUES('T98 existing profile count',coalesce(((select count(*)from public.profiles)=(select n from qa_before where k='profiles')),false));
INSERT INTO qa_checks VALUES('T99 existing sessions unchanged',coalesce(((select count(*)from public.study_sessions)=(select n from qa_before where k='sessions')),false));
DO $$ DECLARE v text;BEGIN SELECT string_agg(name||': '||passed::text,' || ' ORDER BY name) INTO v FROM qa_checks;RAISE EXCEPTION 'DRYRUN_RESULT >> %',v;END $$;
ROLLBACK;
