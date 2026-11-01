-- READ ONLY. Run after a successful 33 installation; do not run the apply twice.
SELECT
 md5(pg_get_functiondef('public.start_exam_attempt(uuid,text)'::regprocedure)) =
   (SELECT value FROM public.exam_start_rate_backup_33 WHERE key='installed_hash') AS installed_hash_matches,
 (SELECT md5(value)='8928a4a7c25c61fe1f92f874935d208d' FROM public.exam_start_rate_backup_33 WHERE key='previous') AS previous_hash_preserved,
 (SELECT proacl::text='{postgres=X/postgres,authenticated=X/postgres}' AND prosecdef AND proconfig=ARRAY['search_path=public, pg_temp'] FROM pg_proc WHERE oid='public.start_exam_attempt(uuid,text)'::regprocedure) AS function_acl_unchanged,
 (SELECT relrowsecurity FROM pg_class WHERE oid='public.exam_start_rate_backup_33'::regclass) AND NOT has_table_privilege('anon','public.exam_start_rate_backup_33','SELECT') AND NOT has_table_privilege('authenticated','public.exam_start_rate_backup_33','SELECT') AS backup_private_rls,
 EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101225000' AND name='exam_start_rate_guard') AS migration_marker_present,
 (SELECT relrowsecurity FROM pg_class WHERE oid='public.exam_attempts'::regclass) AS attempts_rls_still_enabled;
