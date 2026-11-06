-- PROPOSED ROLLBACK ONLY: restores the earlier NULL-year bypass. Review before use.
\echo 'DO NOT EXECUTE: local evaluation only.'
\quit
BEGIN;
SET LOCAL lock_timeout = '2s';
SET LOCAL statement_timeout = '15s';
DO $guard$
DECLARE definition text; old_block text; new_block text;
BEGIN
 IF to_regprocedure('public.enforce_minimum_age()') IS NULL
    OR md5(pg_get_functiondef('public.enforce_minimum_age()'::regprocedure)) <> '9db6b98a4cff323ae9a02f02256a53f2'
    OR NOT coalesce((SELECT relrowsecurity FROM pg_class WHERE oid='public.profiles'::regclass),false)
    OR NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid='public.profiles'::regclass AND t.tgname='enforce_minimum_age' AND t.tgenabled='O' AND NOT t.tgisinternal AND t.tgfoid='public.enforce_minimum_age()'::regprocedure AND t.tgtype=23
      AND pg_get_triggerdef(t.oid) = 'CREATE TRIGGER enforce_minimum_age BEFORE INSERT OR UPDATE OF birth_year, onboarding_completed_at ON public.profiles FOR EACH ROW EXECUTE FUNCTION enforce_minimum_age()')
    OR (SELECT proacl::text FROM pg_proc WHERE oid='public.enforce_minimum_age()'::regprocedure) IS DISTINCT FROM '{postgres=X/postgres,service_role=X/postgres}'
    OR NOT EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261106220000' AND name='onboarding_birth_year_guard')
 THEN RAISE EXCEPTION 'birth_year_guard_down_baseline_changed'; END IF;
 SELECT pg_get_functiondef('public.enforce_minimum_age()'::regprocedure) INTO definition;
 old_block := E'BEGIN\n    IF NEW.onboarding_completed_at IS NOT NULL\n       AND NEW.birth_year IS NOT NULL';
 new_block := E'BEGIN\n -- Existing completed legacy profiles with no birth year are grandfathered.\n -- New completions, newly missing years and modified completion dates fail.\n IF NEW.onboarding_completed_at IS NOT NULL AND NEW.birth_year IS NULL THEN\n  IF TG_OP = ''INSERT'' THEN\n   RAISE EXCEPTION ''birth_year_required'' USING ERRCODE = ''check_violation'';\n  ELSIF OLD.onboarding_completed_at IS NULL OR OLD.birth_year IS NOT NULL\n     OR NEW.onboarding_completed_at IS DISTINCT FROM OLD.onboarding_completed_at THEN\n   RAISE EXCEPTION ''birth_year_required'' USING ERRCODE = ''check_violation'';\n  END IF;\n END IF;\n    IF NEW.onboarding_completed_at IS NOT NULL\n       AND NEW.birth_year IS NOT NULL';
 IF (length(definition)-length(replace(definition,new_block,'')))/length(new_block)<>1 THEN RAISE EXCEPTION 'birth_year_guard_down_marker_changed'; END IF;
 EXECUTE replace(definition,new_block,old_block);
 IF md5(pg_get_functiondef('public.enforce_minimum_age()'::regprocedure)) <> '03080f9bcaf3550a6c005fe3bd640f35' THEN RAISE EXCEPTION 'birth_year_guard_down_hash_mismatch'; END IF;
END
$guard$;
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261106220000' AND name='onboarding_birth_year_guard';
COMMIT;
