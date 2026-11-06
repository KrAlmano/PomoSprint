-- REVIEW ONLY: synthetic local test required; do not install on production.
\echo 'DO NOT EXECUTE: local evaluation only.'
\quit
BEGIN;
SET LOCAL lock_timeout = '2s';
SET LOCAL statement_timeout = '15s';
DO $check$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations
    WHERE version='20261106220000' AND name='onboarding_birth_year_guard')
    OR to_regprocedure('public.enforce_minimum_age()') IS NULL
    OR md5(pg_get_functiondef('public.enforce_minimum_age()'::regprocedure)) <> '9db6b98a4cff323ae9a02f02256a53f2'
    OR (SELECT proacl::text FROM pg_proc WHERE oid='public.enforce_minimum_age()'::regprocedure)
       IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'
    OR NOT coalesce((SELECT relrowsecurity FROM pg_class WHERE oid='public.profiles'::regclass),false)
    OR NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid='public.profiles'::regclass
      AND t.tgname='enforce_minimum_age' AND t.tgenabled='O' AND NOT t.tgisinternal
      AND t.tgfoid='public.enforce_minimum_age()'::regprocedure AND t.tgtype=23
      AND pg_get_triggerdef(t.oid)='CREATE TRIGGER enforce_minimum_age BEFORE INSERT OR UPDATE OF birth_year, onboarding_completed_at ON public.profiles FOR EACH ROW EXECUTE FUNCTION enforce_minimum_age()')
    OR to_regprocedure('public._onboarding_activity_guard()') IS NOT NULL
    OR EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261106230000')
    OR EXISTS (SELECT 1 FROM pg_trigger WHERE NOT tgisinternal
      AND tgname='onboarding_activity_guard' AND tgrelid IN
      ('public.session_starts'::regclass,'public.study_sessions'::regclass,'public.exam_attempts'::regclass))
    THEN RAISE EXCEPTION 'onboarding_activity_guard_baseline_changed';
  END IF;
END
$check$;

-- Birth-year validation belongs to 35. Historical completed profiles with
-- null year remain eligible; an incomplete/missing profile cannot create new
-- reward-bearing work. Existing data are never modified by this migration.
CREATE FUNCTION public._onboarding_activity_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,pg_temp AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles p
                 WHERE p.id=NEW.user_id AND p.onboarding_completed_at IS NOT NULL) THEN
    RAISE EXCEPTION 'onboarding_required' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END
$$;
REVOKE ALL ON FUNCTION public._onboarding_activity_guard() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER onboarding_activity_guard BEFORE INSERT ON public.session_starts
FOR EACH ROW EXECUTE FUNCTION public._onboarding_activity_guard();
CREATE TRIGGER onboarding_activity_guard BEFORE INSERT ON public.study_sessions
FOR EACH ROW EXECUTE FUNCTION public._onboarding_activity_guard();
CREATE TRIGGER onboarding_activity_guard BEFORE INSERT ON public.exam_attempts
FOR EACH ROW EXECUTE FUNCTION public._onboarding_activity_guard();
INSERT INTO supabase_migrations.schema_migrations(version,name)
VALUES('20261106230000','onboarding_activity_guard_review');
DO $post$
BEGIN
  IF (SELECT count(*) FROM pg_trigger t WHERE NOT t.tgisinternal AND t.tgenabled='O'
      AND t.tgname='onboarding_activity_guard' AND t.tgtype=7 AND t.tgfoid='public._onboarding_activity_guard()'::regprocedure
      AND t.tgrelid IN ('public.session_starts'::regclass,'public.study_sessions'::regclass,'public.exam_attempts'::regclass)) <> 3
    OR md5(pg_get_functiondef('public._onboarding_activity_guard()'::regprocedure)) <> '98c99cbdb2efa465b1ec5ff051b91738'
    OR has_function_privilege('anon','public._onboarding_activity_guard()','EXECUTE')
    OR has_function_privilege('authenticated','public._onboarding_activity_guard()','EXECUTE')
    OR has_function_privilege('service_role','public._onboarding_activity_guard()','EXECUTE')
    THEN RAISE EXCEPTION 'onboarding_activity_guard_postcondition_failed';
  END IF;
END
$post$;
ROLLBACK;
