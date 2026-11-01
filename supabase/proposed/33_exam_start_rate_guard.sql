-- PROPOSED ONLY. Never apply to production without review and client compatibility.
\echo 'DO NOT EXECUTE: inspect README and DRYRUN first.'
\quit
BEGIN;
SET LOCAL lock_timeout = '1s';
SET LOCAL statement_timeout = '12s';
-- Fail immediately if an application query or another migration is active.
-- Held only until COMMIT/ROLLBACK; rerun later if the NOWAIT lock fails.
LOCK TABLE public.profiles, public.exam_attempts, supabase_migrations.schema_migrations IN ACCESS EXCLUSIVE MODE NOWAIT;
DO $$ BEGIN
 IF to_regprocedure('public.start_exam_attempt(uuid,text)') IS NULL OR md5(pg_get_functiondef('public.start_exam_attempt(uuid,text)'::regprocedure))<>'8928a4a7c25c61fe1f92f874935d208d' THEN RAISE EXCEPTION 'exam_rate_source_changed'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=to_regprocedure('public.start_exam_attempt(uuid,text)') AND p.prosecdef AND p.proconfig=ARRAY['search_path=public, pg_temp'] AND p.proacl::text='{postgres=X/postgres,authenticated=X/postgres}') THEN RAISE EXCEPTION 'exam_rate_acl_changed'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_class WHERE oid='public.exam_attempts'::regclass AND relrowsecurity) THEN RAISE EXCEPTION 'exam_rate_rls_disabled'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_index WHERE indexrelid=to_regclass('public.exam_attempt_owner_started') AND indrelid='public.exam_attempts'::regclass AND indisvalid AND indisready) THEN RAISE EXCEPTION 'exam_rate_index_missing'; END IF;
 IF to_regclass('public.exam_start_rate_backup_33') IS NOT NULL OR EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101225000') THEN RAISE EXCEPTION 'exam_rate_already_installed'; END IF;
END $$;
CREATE TABLE public.exam_start_rate_backup_33 (key text PRIMARY KEY,value text NOT NULL);
ALTER TABLE public.exam_start_rate_backup_33 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.exam_start_rate_backup_33 FROM PUBLIC,anon,authenticated,service_role;
INSERT INTO public.exam_start_rate_backup_33 VALUES ('previous',pg_get_functiondef('public.start_exam_attempt(uuid,text)'::regprocedure));
DO $$ DECLARE original text; modified text; marker text:=' v_now:=clock_timestamp();
 IF EXISTS(SELECT 1 FROM public.exam_attempts WHERE user_id=v_uid AND status=''active'')'; BEGIN
 SELECT value INTO original FROM public.exam_start_rate_backup_33 WHERE key='previous';
 IF (length(original)-length(replace(original,marker,'')))/length(marker)<>1 THEN RAISE EXCEPTION 'exam_rate_marker_mismatch'; END IF;
 modified:=replace(original,marker,' v_now:=clock_timestamp();
 -- Per-account burst/cost guard; profile row lock serializes simultaneous starts.
 IF (SELECT count(*) FROM public.exam_attempts WHERE user_id=v_uid AND started_at>v_now-interval ''24 hours'') >= 100 THEN
  RAISE EXCEPTION ''exam_start_rate_limited'';
 END IF;
 IF EXISTS(SELECT 1 FROM public.exam_attempts WHERE user_id=v_uid AND status=''active'')');
 EXECUTE modified;
END $$;
INSERT INTO public.exam_start_rate_backup_33 VALUES ('installed_hash',md5(pg_get_functiondef('public.start_exam_attempt(uuid,text)'::regprocedure)));
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261101225000','exam_start_rate_guard');
COMMIT;
