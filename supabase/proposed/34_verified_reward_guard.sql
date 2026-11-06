-- PROPOSED ONLY. Feature gate remains OFF. Never run on production without explicit rollout.
\echo 'DO NOT EXECUTE: inspect README and DRYRUN first.'
\quit
BEGIN;
DO $$ BEGIN
 IF to_regprocedure('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)') IS NULL OR md5(pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure))<>'e2ca96d1ad14fa01af1e76b3a660609f' THEN RAISE EXCEPTION 'verified_reward_complete_source_changed'; END IF;
 IF to_regprocedure('public._competition_study_event()') IS NULL OR md5(pg_get_functiondef('public._competition_study_event()'::regprocedure))<>'3ef67eff0e11ba87570b089c0919f17c' THEN RAISE EXCEPTION 'verified_reward_trigger_source_changed'; END IF;
 IF to_regprocedure('public._complete_marathon_study_session_before_presence(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)') IS NULL OR md5(pg_get_functiondef('public._complete_marathon_study_session_before_presence(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)'::regprocedure))<>'68615a917cffc7a3cbbe75094a6520a6' THEN RAISE EXCEPTION 'verified_reward_marathon_source_changed'; END IF;
 IF to_regprocedure('public._league_period_activity(timestamptz,timestamptz)') IS NULL OR md5(pg_get_functiondef('public._league_period_activity(timestamptz,timestamptz)'::regprocedure))<>'f4844666583b5c65a07c17b321ae8bf9' THEN RAISE EXCEPTION 'verified_reward_legacy_activity_source_changed'; END IF;
 IF to_regprocedure('public._league_refresh_start()') IS NULL OR md5(pg_get_functiondef('public._league_refresh_start()'::regprocedure))<>'02c8684e66de0ec5db7ec0eb69f52a1e' THEN RAISE EXCEPTION 'verified_reward_legacy_launch_source_changed'; END IF;
 IF to_regclass('public.verified_reward_legacy_session_anchor_34') IS NOT NULL THEN RAISE EXCEPTION 'verified_reward_legacy_anchor_exists'; END IF;
 IF to_regclass('public.verified_reward_backup_34') IS NOT NULL OR EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101230000') THEN RAISE EXCEPTION 'verified_reward_already_installed'; END IF;
 IF to_regclass('public.verified_reward_streak_anchor_34') IS NOT NULL OR EXISTS(SELECT 1 FROM public.app_config WHERE key='verified_reward_activation_at_34') THEN RAISE EXCEPTION 'verified_reward_anchor_exists'; END IF;
 IF NOT EXISTS(SELECT 1 FROM public.app_config WHERE key='unverified_session_daily_cap' AND value='null'::jsonb) THEN RAISE EXCEPTION 'verified_reward_cap_not_disabled'; END IF;
END $$;
CREATE TABLE public.verified_reward_backup_34 (key text PRIMARY KEY,value text NOT NULL);
ALTER TABLE public.verified_reward_backup_34 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.verified_reward_backup_34 FROM PUBLIC,anon,authenticated,service_role;
CREATE TABLE public.verified_reward_streak_anchor_34 (
 user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
 last_study_day date,
 streak_count integer NOT NULL CHECK(streak_count BETWEEN 0 AND 14)
);
ALTER TABLE public.verified_reward_streak_anchor_34 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.verified_reward_streak_anchor_34 FROM PUBLIC,anon,authenticated,service_role;
-- Preserve sessions already accepted before the policy switch, including genuine
-- zero-reward daily-cap sessions. No user's prior league eligibility is removed.
CREATE TABLE public.verified_reward_legacy_session_anchor_34 (
 session_id uuid PRIMARY KEY REFERENCES public.study_sessions(id) ON DELETE CASCADE
);
ALTER TABLE public.verified_reward_legacy_session_anchor_34 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.verified_reward_legacy_session_anchor_34 FROM PUBLIC,anon,authenticated,service_role;
INSERT INTO public.app_config(key,value,is_public,description) VALUES
 ('verified_reward_activation_at_34','null'::jsonb,false,'Activation marker for verified reward streak snapshot; null means disabled.');
INSERT INTO public.verified_reward_backup_34 VALUES
 ('complete_before',pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure)),
 ('trigger_before',pg_get_functiondef('public._competition_study_event()'::regprocedure)),
 ('marathon_before',pg_get_functiondef('public._complete_marathon_study_session_before_presence(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)'::regprocedure)),
 ('legacy_activity_before',pg_get_functiondef('public._league_period_activity(timestamptz,timestamptz)'::regprocedure)),
 ('legacy_launch_before',pg_get_functiondef('public._league_refresh_start()'::regprocedure));
DO $$ DECLARE original text; marker text; BEGIN
 SELECT value INTO original FROM public.verified_reward_backup_34 WHERE key='complete_before';
 marker:='       AND now() >= v_server_started_at + make_interval(mins => p_duration_minutes) - interval ''60 seconds'' THEN';
 IF (length(original)-length(replace(original,marker,'')))/length(marker)<>1 THEN RAISE EXCEPTION 'verified_reward_complete_marker_mismatch'; END IF;
 original:=replace(original,marker,'       AND now() >= v_server_started_at + make_interval(mins => p_duration_minutes) - (CASE WHEN coalesce(public.app_config_int(''unverified_session_daily_cap''),-1)=0 THEN interval ''0 seconds'' ELSE interval ''60 seconds'' END) THEN');
 marker:='    IF v_server_started_at IS NOT NULL
       AND now() >= v_server_started_at + make_interval(mins => p_duration_minutes)';
 IF (length(original)-length(replace(original,marker,'')))/length(marker)<>1 THEN RAISE EXCEPTION 'verified_reward_retry_marker_mismatch'; END IF;
 original:=replace(original,marker,'    -- A matching server start can arrive after the client started its timer.
    -- Keep the completion retryable instead of finalizing it without rewards.
    IF public.app_config_int(''unverified_session_daily_cap'')=0
       AND v_server_started_at IS NOT NULL
       AND now() < v_server_started_at + make_interval(mins => p_duration_minutes) THEN
        RAISE EXCEPTION ''verified_start_not_elapsed'';
    END IF;

    IF v_server_started_at IS NOT NULL
       AND now() >= v_server_started_at + make_interval(mins => p_duration_minutes)');
 marker:='    IF v_bonus_streak >= 14 THEN';
 IF (length(original)-length(replace(original,marker,'')))/length(marker)<>1 THEN RAISE EXCEPTION 'verified_reward_streak_marker_mismatch'; END IF;
 EXECUTE replace(original,marker,'    -- Reward streak uses genuine verified days plus grandfathered historical
    -- rewarded days and server-completed exams; the visible streak is unchanged.
    -- Fourteen calendar days suffice for the highest existing bonus tier.
    IF v_start_verified AND public.app_config_int(''unverified_session_daily_cap'')=0 THEN
      IF NOT EXISTS(SELECT 1 FROM public.app_config WHERE key=''verified_reward_activation_at_34'' AND jsonb_typeof(value)=''string'') THEN
        RAISE EXCEPTION ''verified_reward_activation_incomplete'';
      END IF;
      WITH reward_days(day) AS (
        SELECT v_study_day
        UNION
        SELECT anchor.last_study_day - generated.day_offset
          FROM public.verified_reward_streak_anchor_34 anchor
          CROSS JOIN LATERAL generate_series(0,least(anchor.streak_count-1,13)) generated(day_offset)
         WHERE anchor.user_id=v_uid AND anchor.last_study_day IS NOT NULL
           AND anchor.last_study_day - generated.day_offset BETWEEN v_study_day-13 AND v_study_day
        UNION
        SELECT ((s.started_at AT TIME ZONE v_user_tz)-interval ''4 hours'')::date
          FROM public.study_sessions s
         WHERE s.user_id=v_uid
           AND s.started_at >= (((v_study_day-13)::timestamp+interval ''4 hours'') AT TIME ZONE v_user_tz)
           AND s.started_at < (((v_study_day+1)::timestamp+interval ''4 hours'') AT TIME ZONE v_user_tz)
           AND (s.start_verified IS TRUE OR coalesce(s.base_points,0)+coalesce(s.bonus_points,0)>0)
        UNION
        SELECT ((a.started_at AT TIME ZONE v_user_tz)-interval ''4 hours'')::date
          FROM public.exam_attempts a
         WHERE a.user_id=v_uid AND a.status=''completed'' AND a.elapsed_seconds>=60
           AND a.started_at >= (((v_study_day-13)::timestamp+interval ''4 hours'') AT TIME ZONE v_user_tz)
           AND a.started_at < (((v_study_day+1)::timestamp+interval ''4 hours'') AT TIME ZONE v_user_tz)
      ), ordered_days AS (
        SELECT day,row_number() OVER(ORDER BY day DESC) AS rn FROM reward_days
      )
      SELECT count(*)::integer INTO v_bonus_streak FROM ordered_days WHERE v_study_day-day=rn-1;
    END IF;

    IF v_bonus_streak >= 14 THEN');
 SELECT value INTO original FROM public.verified_reward_backup_34 WHERE key='trigger_before';
 marker:='BEGIN PERFORM public._competition_record(''study'',NEW.id,NEW.user_id,NEW.started_at,NEW.completed_at,NEW.duration_minutes,NEW.base_points+NEW.bonus_points);RETURN NEW;END';
 IF (length(original)-length(replace(original,marker,'')))/length(marker)<>1 THEN RAISE EXCEPTION 'verified_reward_trigger_marker_mismatch'; END IF;
 EXECUTE replace(original,marker,'BEGIN IF NEW.start_verified IS NOT TRUE AND public.app_config_int(''unverified_session_daily_cap'')=0 THEN RETURN NEW; END IF; PERFORM public._competition_record(''study'',NEW.id,NEW.user_id,NEW.started_at,NEW.completed_at,NEW.duration_minutes,NEW.base_points+NEW.bonus_points);RETURN NEW;END');
 -- Legacy leagues must not count unverified new offline sessions towards
 -- eligibility or startup once cap=0, but all snapshotted old sessions and
 -- verified sessions (including zero-point daily-cap sessions) still count.
 SELECT value INTO original FROM public.verified_reward_backup_34 WHERE key='legacy_activity_before';
 marker:='   AND s.duration_minutes IN(25,50)';
 IF (length(original)-length(replace(original,marker,'')))/length(marker)<>1 THEN RAISE EXCEPTION 'verified_reward_legacy_activity_marker_mismatch'; END IF;
 EXECUTE replace(original,marker,marker||'
   AND (coalesce(public.app_config_int(''unverified_session_daily_cap''),-1)<>0
     OR s.start_verified IS TRUE OR EXISTS(SELECT 1 FROM public.verified_reward_legacy_session_anchor_34 a WHERE a.session_id=s.id))');
 SELECT value INTO original FROM public.verified_reward_backup_34 WHERE key='legacy_launch_before';
 marker:='      AND s.duration_minutes IN(25,50) GROUP BY s.user_id LIMIT v_needed';
 IF (length(original)-length(replace(original,marker,'')))/length(marker)<>1 THEN RAISE EXCEPTION 'verified_reward_legacy_launch_marker_mismatch'; END IF;
 EXECUTE replace(original,marker,'      AND s.duration_minutes IN(25,50)
      AND (coalesce(public.app_config_int(''unverified_session_daily_cap''),-1)<>0
        OR s.start_verified IS TRUE OR EXISTS(SELECT 1 FROM public.verified_reward_legacy_session_anchor_34 a WHERE a.session_id=s.id))
      GROUP BY s.user_id LIMIT v_needed');
 SELECT value INTO original FROM public.verified_reward_backup_34 WHERE key='marathon_before';
 marker:='SELECT count(*),bool_and(s.base_points+s.bonus_points>0) INTO v_completed,v_eligible';
 IF (length(original)-length(replace(original,marker,'')))/length(marker)<>1 THEN RAISE EXCEPTION 'verified_reward_marathon_marker_mismatch'; END IF;
 EXECUTE replace(original,marker,'SELECT count(*),bool_and(s.base_points+s.bonus_points>0 AND (coalesce(public.app_config_int(''unverified_session_daily_cap''),-1)<>0 OR s.start_verified IS TRUE)) INTO v_completed,v_eligible');
END $$;
INSERT INTO public.verified_reward_backup_34 VALUES
 ('complete_installed',md5(pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure))),
 ('trigger_installed',md5(pg_get_functiondef('public._competition_study_event()'::regprocedure))),
 ('marathon_installed',md5(pg_get_functiondef('public._complete_marathon_study_session_before_presence(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)'::regprocedure))),
 ('legacy_activity_installed',md5(pg_get_functiondef('public._league_period_activity(timestamptz,timestamptz)'::regprocedure))),
 ('legacy_launch_installed',md5(pg_get_functiondef('public._league_refresh_start()'::regprocedure)));
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261101230000','verified_reward_guard');
COMMIT;
