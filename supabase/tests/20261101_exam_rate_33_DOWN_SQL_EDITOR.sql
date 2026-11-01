-- REVIEWED CANDIDATE: restores exact previous function if installed hash and ACL match.
BEGIN;
SET LOCAL lock_timeout = '1s';
SET LOCAL statement_timeout = '12s';
LOCK TABLE public.profiles, public.exam_attempts, supabase_migrations.schema_migrations IN ACCESS EXCLUSIVE MODE NOWAIT;
DO $$ DECLARE original text; installed_hash text; BEGIN
 IF to_regclass('public.exam_start_rate_backup_33') IS NULL THEN RAISE EXCEPTION 'exam_rate_backup_missing'; END IF;
 SELECT value INTO original FROM public.exam_start_rate_backup_33 WHERE key='previous';
 SELECT value INTO installed_hash FROM public.exam_start_rate_backup_33 WHERE key='installed_hash';
 IF NOT EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=to_regprocedure('public.start_exam_attempt(uuid,text)') AND p.prosecdef AND p.proconfig=ARRAY['search_path=public, pg_temp'] AND p.proacl::text='{postgres=X/postgres,authenticated=X/postgres}') THEN RAISE EXCEPTION 'exam_rate_rollback_acl_changed'; END IF;
 IF original IS NULL OR installed_hash IS NULL OR md5(original)<>'8928a4a7c25c61fe1f92f874935d208d' OR md5(pg_get_functiondef('public.start_exam_attempt(uuid,text)'::regprocedure))<>installed_hash THEN RAISE EXCEPTION 'exam_rate_rollback_guard'; END IF;
 EXECUTE original;
END $$;
DROP TABLE public.exam_start_rate_backup_33;
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261101225000';
COMMIT;
