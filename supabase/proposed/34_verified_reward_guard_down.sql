-- PROPOSED ONLY. Feature gate remains OFF. Never run on production without explicit rollout.
\echo 'DO NOT EXECUTE: inspect README and DRYRUN first.'
\quit
BEGIN;
DO $$ DECLARE a text; b text; c text; la text; ll text; ia text; ib text; ic text; ila text; ill text; BEGIN
 IF to_regclass('public.verified_reward_backup_34') IS NULL THEN RAISE EXCEPTION 'verified_reward_backup_missing'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.app_config WHERE key='unverified_session_daily_cap' AND value='null'::jsonb) THEN RAISE EXCEPTION 'verified_reward_disable_policy_before_rollback'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.app_config WHERE key='verified_reward_activation_at_34' AND value='null'::jsonb) OR EXISTS(SELECT 1 FROM public.verified_reward_streak_anchor_34) OR EXISTS(SELECT 1 FROM public.verified_reward_legacy_session_anchor_34) THEN RAISE EXCEPTION 'verified_reward_anchor_rollback_refused'; END IF;
 SELECT value INTO a FROM public.verified_reward_backup_34 WHERE key='complete_before';
 SELECT value INTO b FROM public.verified_reward_backup_34 WHERE key='trigger_before';
 SELECT value INTO c FROM public.verified_reward_backup_34 WHERE key='marathon_before';
 SELECT value INTO la FROM public.verified_reward_backup_34 WHERE key='legacy_activity_before';
 SELECT value INTO ll FROM public.verified_reward_backup_34 WHERE key='legacy_launch_before';
 SELECT value INTO ila FROM public.verified_reward_backup_34 WHERE key='legacy_activity_installed';
 SELECT value INTO ill FROM public.verified_reward_backup_34 WHERE key='legacy_launch_installed';
 SELECT value INTO ia FROM public.verified_reward_backup_34 WHERE key='complete_installed';
 SELECT value INTO ib FROM public.verified_reward_backup_34 WHERE key='trigger_installed';
 SELECT value INTO ic FROM public.verified_reward_backup_34 WHERE key='marathon_installed';
 IF a IS NULL OR b IS NULL OR c IS NULL OR ia IS NULL OR ib IS NULL OR ic IS NULL OR md5(a)<>'e2ca96d1ad14fa01af1e76b3a660609f' OR md5(b)<>'3ef67eff0e11ba87570b089c0919f17c' OR md5(c)<>'68615a917cffc7a3cbbe75094a6520a6' OR la IS NULL OR ll IS NULL OR ila IS NULL OR ill IS NULL OR md5(la)<>'f4844666583b5c65a07c17b321ae8bf9' OR md5(ll)<>'02c8684e66de0ec5db7ec0eb69f52a1e' OR md5(pg_get_functiondef('public._league_period_activity(timestamptz,timestamptz)'::regprocedure))<>ila OR md5(pg_get_functiondef('public._league_refresh_start()'::regprocedure))<>ill OR md5(pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure))<>ia OR md5(pg_get_functiondef('public._competition_study_event()'::regprocedure))<>ib OR md5(pg_get_functiondef('public._complete_marathon_study_session_before_presence(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)'::regprocedure))<>ic THEN RAISE EXCEPTION 'verified_reward_rollback_guard'; END IF;
 EXECUTE a; EXECUTE b; EXECUTE c; EXECUTE la; EXECUTE ll;
END $$;
DELETE FROM public.app_config WHERE key='verified_reward_activation_at_34';
DROP TABLE public.verified_reward_streak_anchor_34;
DROP TABLE public.verified_reward_legacy_session_anchor_34;
DROP TABLE public.verified_reward_backup_34;
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261101230000';
COMMIT;
