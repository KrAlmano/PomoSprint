-- REVIEW ONLY: rollback only in the disposable local test database.
\echo 'DO NOT EXECUTE: local evaluation only.'
\quit
BEGIN;
SET LOCAL lock_timeout = '2s';
SET LOCAL statement_timeout = '15s';
DO $check$
BEGIN
 IF to_regprocedure('public._onboarding_activity_guard()') IS NULL
   OR md5(pg_get_functiondef('public._onboarding_activity_guard()'::regprocedure)) <> '98c99cbdb2efa465b1ec5ff051b91738'
   OR NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations
     WHERE version='20261106230000' AND name='onboarding_activity_guard_review')
   OR (SELECT count(*) FROM pg_trigger WHERE NOT tgisinternal
     AND tgname='onboarding_activity_guard' AND tgenabled='O' AND tgtype=7 AND tgfoid='public._onboarding_activity_guard()'::regprocedure
     AND tgrelid IN ('public.session_starts'::regclass,'public.study_sessions'::regclass,'public.exam_attempts'::regclass))<>3
   THEN RAISE EXCEPTION 'onboarding_activity_guard_down_baseline_changed';
 END IF;
END
$check$;
DROP TRIGGER onboarding_activity_guard ON public.session_starts;
DROP TRIGGER onboarding_activity_guard ON public.study_sessions;
DROP TRIGGER onboarding_activity_guard ON public.exam_attempts;
DROP FUNCTION public._onboarding_activity_guard();
DELETE FROM supabase_migrations.schema_migrations
WHERE version='20261106230000' AND name='onboarding_activity_guard_review';
COMMIT;
