-- REVIEW ONLY: do not execute before the verified-start client is distributed
-- and compatibility, pending queues, minimum versions and rollback are reviewed.
\echo 'DO NOT EXECUTE: manual release verification required.'
\quit
BEGIN;
-- A deliberate fail-closed gate also protects SQL Editor, which ignores psql guards.
-- Remove this entire DO block only in a reviewed future rollout after both
-- platforms have a verifiable minimum supported build and users are informed.
DO $$ BEGIN RAISE EXCEPTION 'verified_reward_client_rollout_not_verified'; END $$;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='120s';
LOCK TABLE public.profiles IN ACCESS EXCLUSIVE MODE NOWAIT;
LOCK TABLE public.app_config IN SHARE ROW EXCLUSIVE MODE NOWAIT;
DO $$ DECLARE k text; expected text; actual text; BEGIN
 IF NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101230000')
 OR NOT EXISTS(SELECT 1 FROM public.app_config WHERE key='unverified_session_daily_cap' AND value='null'::jsonb)
 OR NOT EXISTS(SELECT 1 FROM public.app_config WHERE key='verified_reward_activation_at_34' AND value='null'::jsonb)
 OR EXISTS(SELECT 1 FROM public.verified_reward_streak_anchor_34)
 OR EXISTS(SELECT 1 FROM public.verified_reward_legacy_session_anchor_34)
 THEN RAISE EXCEPTION 'verified_reward_activation_precondition_changed'; END IF;
 FOR k IN SELECT unnest(ARRAY['complete_installed','trigger_installed','marathon_installed','legacy_activity_installed','legacy_launch_installed']) LOOP
   SELECT value INTO expected FROM public.verified_reward_backup_34 WHERE key=k;
   actual:=CASE k
     WHEN 'complete_installed' THEN md5(pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure))
     WHEN 'trigger_installed' THEN md5(pg_get_functiondef('public._competition_study_event()'::regprocedure))
     WHEN 'marathon_installed' THEN md5(pg_get_functiondef('public._complete_marathon_study_session_before_presence(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)'::regprocedure))
     WHEN 'legacy_activity_installed' THEN md5(pg_get_functiondef('public._league_period_activity(timestamptz,timestamptz)'::regprocedure))
     ELSE md5(pg_get_functiondef('public._league_refresh_start()'::regprocedure)) END;
   IF expected IS NULL OR actual IS DISTINCT FROM expected THEN RAISE EXCEPTION 'verified_reward_activation_source_changed: %',k; END IF;
 END LOOP;
END $$;
INSERT INTO public.verified_reward_streak_anchor_34(user_id,last_study_day,streak_count)
 SELECT id,least(last_study_date,((clock_timestamp() AT TIME ZONE timezone)-interval '4 hours')::date),least(greatest(current_streak,0),14)
 FROM public.profiles WHERE last_study_date IS NOT NULL AND current_streak>0;
-- Snapshot pre-activation accepted sessions used by legacy launch/activity.
-- Profiles are exclusively locked, so normal completion cannot race this list.
-- Keep at least the last 14 days and any still-open older legacy period.
INSERT INTO public.verified_reward_legacy_session_anchor_34(session_id)
 SELECT s.id FROM public.study_sessions s
 WHERE s.completed_at >= least(clock_timestamp()-interval '14 days',
   coalesce((SELECT coalesce(period_started_at,start_at)
               FROM public.league_competition_state WHERE singleton),
            clock_timestamp()-interval '14 days'));
UPDATE public.app_config SET value=to_jsonb(clock_timestamp()::text),updated_at=now()
 WHERE key='verified_reward_activation_at_34' AND value='null'::jsonb;
UPDATE public.app_config SET value='0'::jsonb,updated_at=now()
 WHERE key='unverified_session_daily_cap' AND value='null'::jsonb;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM public.app_config WHERE key='unverified_session_daily_cap' AND value='0'::jsonb)
 OR NOT EXISTS(SELECT 1 FROM public.app_config WHERE key='verified_reward_activation_at_34' AND jsonb_typeof(value)='string')
 THEN RAISE EXCEPTION 'verified_reward_activation_postcondition_failed'; END IF;
END $$;
COMMIT;
