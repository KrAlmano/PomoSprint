-- SALT OKUNUR. Bu kontrol kurulum yapmaz, DB şemasını değiştirmez.
BEGIN READ ONLY;
SET LOCAL statement_timeout='15s';
WITH expected_functions(signature,digest) AS (VALUES
  ('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamp with time zone)','72023f3f4d8636363cf0231f42d4c7e1'),
  ('public.ensure_user_in_league(uuid,integer)','65faa90deaf3f8e988a801d1628aabce'),
  ('public.get_league_config()','bbcb4673dfa311b076789764207e49b5'),
  ('public.get_league_ranking(uuid)','f90981ef879bcfbe3e456190c0929263'),
  ('public.get_live_friends_with_breaks()','342b58cfe59ef5766d85ec66f4aee2ce'),
  ('public.get_my_league_ranking()','a6e5ec04783800080c36b03704c4e320'),
  ('public.get_my_league_ranking_v2()','154eebf5aea8060d104b58d5208807b7'),
  ('public.get_public_monthly_leaderboard(integer)','bc8655aa7e7189efdb4a42e60a90ae55'),
  ('public.league_award_avatar_id(integer,integer)','f6ed7f1c88a233f1a08bc67713b886e6'),
  ('public.process_weekly_leagues()','f6d02ce7217264dcf44e45056b8fd5b6'),
  ('public.register_session_start(uuid,integer)','9500c7c45503a3e5031e52c879b1dba2'),
  ('public.start_study_session(integer,text)','56a13ce596649189df480f5e39454f95')
), bad_functions AS (
 SELECT e.signature FROM expected_functions e
 WHERE to_regprocedure(e.signature) IS NULL OR md5(pg_get_functiondef(to_regprocedure(e.signature))) IS DISTINCT FROM e.digest
), not_owned_functions AS (
 SELECT e.signature FROM expected_functions e JOIN pg_proc p ON p.oid=to_regprocedure(e.signature)
 WHERE pg_get_userbyid(p.proowner)<>current_user
), required_tables(name) AS (VALUES
 ('public.profiles'),('public.study_sessions'),('public.leagues'),('public.league_memberships'),('public.session_starts'),('public.avatar_unlocks')
)
SELECT jsonb_build_object(
 'checked_at_utc',now(),
 'database',current_database(),
 'session_role',current_user,
 'role_sees_all_cron_jobs',(SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname=current_user),
 'functions_12_match',NOT EXISTS(SELECT 1 FROM bad_functions),
 'different_functions',(SELECT coalesce(jsonb_agg(signature ORDER BY signature),'[]'::jsonb) FROM bad_functions),
 'functions_owned_by_role',NOT EXISTS(SELECT 1 FROM not_owned_functions),
 'functions_different_owner',(SELECT coalesce(jsonb_agg(signature ORDER BY signature),'[]'::jsonb) FROM not_owned_functions),
 'lock_table_permissions',(SELECT bool_and(has_table_privilege(current_user,name,'UPDATE,DELETE,TRUNCATE')) FROM required_tables),
 'profiles_owned_by_role',(SELECT pg_get_userbyid(relowner)=current_user FROM pg_class WHERE oid=to_regclass('public.profiles')),
 'cron_schedule_execute',has_function_privilege(current_user,'cron.schedule(text,text,text)','EXECUTE'),
 'cron_baseline_matches',(SELECT count(*)=1 AND bool_and(active AND database=current_database() AND username=current_user AND schedule='1 21 * * 0' AND command='SELECT public.process_weekly_leagues()') FROM cron.job WHERE jobname='weekly_leagues_job'),
 'exam_config_absent',to_regprocedure('public.get_exam_config()') IS NULL,
 'exam_attempts_absent',to_regclass('public.exam_attempts') IS NULL,
 'monthly_league_absent',to_regclass('public.competition_policy') IS NULL,
 'all_six_versions_absent',NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version IN ('20261028010000','20261028020000','20261028030000','20261028040000','20261028050000','20261028060000','20261101210000')),
 'segment_guard_matches',(SELECT pg_get_constraintdef(oid) = 'CHECK ((user_segment = ANY (ARRAY[''lgs''::text, ''yks''::text, ''kpss''::text, ''language''::text, ''university''::text, ''work''::text])))' FROM pg_constraint WHERE conrelid='public.profiles'::regclass AND conname='profiles_user_segment_check'),
 'profiles_count',(SELECT count(*) FROM public.profiles),
 'study_sessions_count',(SELECT count(*) FROM public.study_sessions)
) AS preflight;
COMMIT;
