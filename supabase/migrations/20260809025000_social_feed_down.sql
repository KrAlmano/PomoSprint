BEGIN;

-- 1. Remove pg_cron job
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
    ) THEN
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup_activity_feed_job') THEN
            PERFORM cron.unschedule('cleanup_activity_feed_job');
        END IF;
    END IF;
END $$;

-- 2. Drop new RPCs
DROP FUNCTION IF EXISTS public.get_friends_feed(integer);
DROP FUNCTION IF EXISTS public.get_live_friends();
DROP FUNCTION IF EXISTS public.cancel_study_session();
DROP FUNCTION IF EXISTS public.start_study_session(integer, text);

-- 3. Restore process_weekly_leagues
CREATE OR REPLACE FUNCTION public.process_weekly_leagues()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_threshold integer;
    v_promote_count integer;
    v_demote_count integer;
    
    v_current_league_id integer;
    v_higher_league_id integer;
    v_lower_league_id integer;
    
    v_league record;
    v_member record;
    
    v_new_week_start timestamptz := now();
BEGIN
    FOR v_league IN SELECT id, tier FROM public.leagues
    LOOP
        v_current_league_id := v_league.id;
        
        v_higher_league_id := CASE v_league.tier
            WHEN 1 THEN (SELECT id FROM public.leagues WHERE tier = 2 LIMIT 1)
            WHEN 2 THEN (SELECT id FROM public.leagues WHERE tier = 3 LIMIT 1)
            WHEN 3 THEN (SELECT id FROM public.leagues WHERE tier = 4 LIMIT 1)
            WHEN 4 THEN (SELECT id FROM public.leagues WHERE tier = 5 LIMIT 1)
            WHEN 5 THEN NULL
        END;

        v_lower_league_id := CASE v_league.tier
            WHEN 5 THEN (SELECT id FROM public.leagues WHERE tier = 4 LIMIT 1)
            WHEN 4 THEN (SELECT id FROM public.leagues WHERE tier = 3 LIMIT 1)
            WHEN 3 THEN (SELECT id FROM public.leagues WHERE tier = 2 LIMIT 1)
            WHEN 2 THEN (SELECT id FROM public.leagues WHERE tier = 1 LIMIT 1)
            WHEN 1 THEN NULL
        END;
        
        SELECT threshold, promote_count, demote_count
        INTO v_threshold, v_promote_count, v_demote_count
        FROM public.get_league_zones( (SELECT count(*)::integer FROM public.league_memberships WHERE league_id = v_current_league_id) );
        
        FOR v_member IN (
            SELECT user_id, weekly_points, rank() OVER (ORDER BY weekly_points DESC) as rnk
            FROM public.league_memberships
            WHERE league_id = v_current_league_id
        )
        LOOP
            IF v_member.rnk <= v_promote_count AND v_higher_league_id IS NOT NULL THEN
                UPDATE public.league_memberships
                SET league_id = v_higher_league_id, weekly_points = 0
                WHERE user_id = v_member.user_id;
            ELSIF v_member.rnk > v_threshold - v_demote_count AND v_lower_league_id IS NOT NULL THEN
                UPDATE public.league_memberships
                SET league_id = v_lower_league_id, weekly_points = 0
                WHERE user_id = v_member.user_id;
            ELSE
                UPDATE public.league_memberships
                SET weekly_points = 0
                WHERE user_id = v_member.user_id;
            END IF;
        END LOOP;
    END LOOP;
    
    UPDATE public.leagues SET week_start = v_new_week_start;
END;
$function$;


-- 4. Restore complete_study_session (with hourly limit, no activity feed, no active session clearing)
CREATE OR REPLACE FUNCTION public.complete_study_session(
    p_client_uuid uuid,
    p_category_id uuid,
    p_duration_minutes integer,
    p_was_paused boolean,
    p_is_verified integer,
    p_started_at timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_base_points integer;
    v_bonus_points integer := 0;
    v_total_points integer;
    v_bonus_pct integer := 0;
    v_last_study_date date;
    v_current_streak integer;
    v_longest_streak integer;
    v_user_tz text;
    v_study_day date;
    v_existing record;
    v_session_id uuid;
    
    v_last_completed_at timestamptz;
    v_hourly_minutes integer;
    v_daily_sessions integer;
    v_daily_limit_reached boolean := false;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

    SELECT id, base_points, bonus_points, was_paused, is_verified
    INTO v_existing
    FROM public.study_sessions
    WHERE user_id = v_uid AND client_uuid = p_client_uuid;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'base_points', v_existing.base_points,
            'bonus_points', v_existing.bonus_points,
            'total_points', v_existing.base_points + v_existing.bonus_points,
            'streak', (SELECT current_streak FROM public.profiles WHERE id = v_uid),
            'bonus_pct', 0,
            'duplicate', true,
            'daily_limit_reached', false
        );
    END IF;

    IF p_duration_minutes NOT IN (25, 50) THEN
        RAISE EXCEPTION 'invalid duration: only 25 or 50 allowed';
    END IF;

    IF p_started_at > now() THEN
        RAISE EXCEPTION 'started_at cannot be in the future';
    END IF;

    IF p_started_at < now() - interval '24 hours' THEN
        RAISE EXCEPTION 'started_at is older than 24 hours';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.categories 
        WHERE id = p_category_id AND user_id = v_uid
    ) THEN
        RAISE EXCEPTION 'category does not belong to this user';
    END IF;

    SELECT completed_at INTO v_last_completed_at 
    FROM public.study_sessions 
    WHERE user_id = v_uid 
    ORDER BY completed_at DESC 
    LIMIT 1;
    
    IF v_last_completed_at IS NOT NULL AND p_started_at < v_last_completed_at THEN
        RETURN jsonb_build_object('error', 'overlap');
    END IF;

    SELECT COALESCE(SUM(duration_minutes), 0) INTO v_hourly_minutes
    FROM public.study_sessions
    WHERE user_id = v_uid 
      AND started_at >= (p_started_at - interval '60 minutes');
      
    IF v_hourly_minutes + p_duration_minutes > 60 THEN
        RETURN jsonb_build_object('error', 'hourly_limit');
    END IF;

    IF p_duration_minutes = 25 THEN
        v_base_points := 5;
    ELSE
        v_base_points := 12;  
    END IF;

    IF p_was_paused THEN
        v_base_points := v_base_points - ceil(v_base_points * 0.20);
    END IF;

    SELECT current_streak, longest_streak, last_study_date, 
           COALESCE(timezone, 'Europe/Istanbul')
    INTO v_current_streak, v_longest_streak, v_last_study_date, v_user_tz
    FROM public.profiles
    WHERE id = v_uid
    FOR UPDATE;

    v_study_day := ((p_started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date;

    IF v_last_study_date IS NULL THEN
        v_current_streak := 1;
    ELSIF v_last_study_date = v_study_day THEN
        NULL;
    ELSIF v_last_study_date = v_study_day - 1 THEN
        v_current_streak := v_current_streak + 1;
    ELSE
        v_current_streak := 1;
    END IF;

    IF v_current_streak > COALESCE(v_longest_streak, 0) THEN
        v_longest_streak := v_current_streak;
    END IF;

    SELECT count(*) INTO v_daily_sessions
    FROM public.study_sessions
    WHERE user_id = v_uid 
      AND ((started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date = v_study_day;

    IF v_daily_sessions >= 16 THEN
        v_daily_limit_reached := true;
    END IF;

    IF v_current_streak >= 14 THEN
        v_bonus_pct := 30;
    ELSIF v_current_streak >= 7 THEN
        v_bonus_pct := 20;
    ELSIF v_current_streak >= 3 THEN
        v_bonus_pct := 10;
    ELSE
        v_bonus_pct := 0;
    END IF;

    v_bonus_points := ceil(v_base_points::numeric * v_bonus_pct / 100.0);
    v_total_points := v_base_points + v_bonus_points;

    UPDATE public.profiles
    SET total_minutes = total_minutes + p_duration_minutes,
        lifetime_points = lifetime_points + v_total_points,
        coins = coins + v_total_points,
        points = COALESCE(points, 0) + v_total_points,  
        current_streak = v_current_streak,
        longest_streak = v_longest_streak,
        last_study_date = v_study_day
    WHERE id = v_uid;

    IF NOT v_daily_limit_reached THEN
        PERFORM public.ensure_user_in_league(v_uid, v_total_points);
    END IF;

    INSERT INTO public.study_sessions (
        user_id, category, category_id, duration_minutes,
        base_points, bonus_points, was_paused, is_verified,
        client_uuid, started_at, completed_at
    ) VALUES (
        v_uid,
        (SELECT name FROM public.categories WHERE id = p_category_id),
        p_category_id, p_duration_minutes,
        v_base_points, v_bonus_points, p_was_paused, p_is_verified,
        p_client_uuid, p_started_at, now()
    )
    RETURNING id INTO v_session_id;

    RETURN jsonb_build_object(
        'base_points', v_base_points,
        'bonus_points', v_bonus_points,
        'total_points', v_total_points,
        'streak', v_current_streak,
        'bonus_pct', v_bonus_pct,
        'duplicate', false,
        'daily_limit_reached', v_daily_limit_reached
    );
END;
$function$;


-- 5. Drop activity_feed table
DROP TABLE IF EXISTS public.activity_feed;

-- 6. Remove active session columns from profiles
ALTER TABLE public.profiles 
  DROP COLUMN IF EXISTS active_session_ends_at,
  DROP COLUMN IF EXISTS active_session_category_name;

COMMIT;
