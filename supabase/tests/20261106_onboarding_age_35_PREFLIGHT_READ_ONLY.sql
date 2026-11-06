-- READ ONLY. Displays only schema status and aggregate counts, never user data.
BEGIN READ ONLY;
SELECT jsonb_build_object(
 'function_hash_matches',coalesce(md5(pg_get_functiondef(to_regprocedure('public.enforce_minimum_age()')))='03080f9bcaf3550a6c005fe3bd640f35',false),
 'trigger_matches',EXISTS(SELECT 1 FROM pg_trigger t WHERE t.tgrelid='public.profiles'::regclass AND t.tgname='enforce_minimum_age' AND t.tgenabled='O' AND NOT t.tgisinternal AND t.tgfoid=to_regprocedure('public.enforce_minimum_age()') AND t.tgtype=23 AND pg_get_triggerdef(t.oid)='CREATE TRIGGER enforce_minimum_age BEFORE INSERT OR UPDATE OF birth_year, onboarding_completed_at ON public.profiles FOR EACH ROW EXECUTE FUNCTION enforce_minimum_age()'),
 'function_acl_matches',(SELECT proacl::text='{postgres=X/postgres,service_role=X/postgres}' FROM pg_proc WHERE oid=to_regprocedure('public.enforce_minimum_age()')),
 'profile_rls_enabled',(SELECT relrowsecurity FROM pg_class WHERE oid='public.profiles'::regclass),
 'marker_absent',NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261106220000'),
 'completed_missing_birth_year_count',(SELECT count(*) FROM public.profiles WHERE onboarding_completed_at IS NOT NULL AND birth_year IS NULL)
) checks;
ROLLBACK;
