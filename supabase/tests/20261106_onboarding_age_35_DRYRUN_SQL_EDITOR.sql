-- SQL EDITOR DRYRUN: transactional function change and metadata insert are ROLLED BACK.
-- LOCAL DRYRUN ONLY. Transaction is rolled back; no production use.
BEGIN;
SET LOCAL lock_timeout = '2s';
SET LOCAL statement_timeout = '15s';
DO $guard$
DECLARE definition text; old_block text; new_block text;
BEGIN
 IF to_regprocedure('public.enforce_minimum_age()') IS NULL
    OR md5(pg_get_functiondef('public.enforce_minimum_age()'::regprocedure)) <> '03080f9bcaf3550a6c005fe3bd640f35'
    OR NOT coalesce((SELECT relrowsecurity FROM pg_class WHERE oid='public.profiles'::regclass),false)
    OR NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid='public.profiles'::regclass AND t.tgname='enforce_minimum_age' AND t.tgenabled='O' AND NOT t.tgisinternal AND t.tgfoid='public.enforce_minimum_age()'::regprocedure AND t.tgtype=23
      AND pg_get_triggerdef(t.oid) = 'CREATE TRIGGER enforce_minimum_age BEFORE INSERT OR UPDATE OF birth_year, onboarding_completed_at ON public.profiles FOR EACH ROW EXECUTE FUNCTION enforce_minimum_age()')
    OR (SELECT proacl::text FROM pg_proc WHERE oid='public.enforce_minimum_age()'::regprocedure) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'
    OR EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261106220000')
 THEN RAISE EXCEPTION 'birth_year_guard_baseline_changed'; END IF;
 SELECT pg_get_functiondef('public.enforce_minimum_age()'::regprocedure) INTO definition;
 old_block := E'BEGIN\n    IF NEW.onboarding_completed_at IS NOT NULL\n       AND NEW.birth_year IS NOT NULL';
 new_block := E'BEGIN\n -- Existing completed legacy profiles with no birth year are grandfathered.\n -- New completions, newly missing years and modified completion dates fail.\n IF NEW.onboarding_completed_at IS NOT NULL AND NEW.birth_year IS NULL THEN\n  IF TG_OP = ''INSERT'' THEN\n   RAISE EXCEPTION ''birth_year_required'' USING ERRCODE = ''check_violation'';\n  ELSIF OLD.onboarding_completed_at IS NULL OR OLD.birth_year IS NOT NULL\n     OR NEW.onboarding_completed_at IS DISTINCT FROM OLD.onboarding_completed_at THEN\n   RAISE EXCEPTION ''birth_year_required'' USING ERRCODE = ''check_violation'';\n  END IF;\n END IF;\n    IF NEW.onboarding_completed_at IS NOT NULL\n       AND NEW.birth_year IS NOT NULL';
 IF (length(definition)-length(replace(definition,old_block,'')))/length(old_block)<>1 THEN RAISE EXCEPTION 'birth_year_guard_marker_changed'; END IF;
 EXECUTE replace(definition,old_block,new_block);
END
$guard$;
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261106220000','onboarding_birth_year_guard');
DO $post$
BEGIN
 IF md5(pg_get_functiondef('public.enforce_minimum_age()'::regprocedure)) <> '9db6b98a4cff323ae9a02f02256a53f2'
    OR (SELECT proacl::text FROM pg_proc WHERE oid='public.enforce_minimum_age()'::regprocedure) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'
    OR NOT coalesce((SELECT relrowsecurity FROM pg_class WHERE oid='public.profiles'::regclass),false)
    OR NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid='public.profiles'::regclass AND t.tgname='enforce_minimum_age' AND t.tgenabled='O' AND NOT t.tgisinternal AND t.tgfoid='public.enforce_minimum_age()'::regprocedure AND t.tgtype=23
      AND pg_get_triggerdef(t.oid) = 'CREATE TRIGGER enforce_minimum_age BEFORE INSERT OR UPDATE OF birth_year, onboarding_completed_at ON public.profiles FOR EACH ROW EXECUTE FUNCTION enforce_minimum_age()')
 THEN RAISE EXCEPTION 'birth_year_guard_postcondition_failed'; END IF;
END
$post$;
DO $$ BEGIN
 IF md5(pg_get_functiondef('public.enforce_minimum_age()'::regprocedure)) <> '9db6b98a4cff323ae9a02f02256a53f2'
 OR NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261106220000' AND name='onboarding_birth_year_guard')
 THEN RAISE EXCEPTION 'birth_year_guard_dryrun_postcondition_failed'; END IF;
END $$;
ROLLBACK;
SELECT '35 structural DRYRUN passed; transaction rolled back' AS result;
