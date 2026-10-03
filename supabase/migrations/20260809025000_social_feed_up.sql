BEGIN;

-- 1. Add active session tracking to profiles
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS active_session_ends_at timestamptz,
  ADD COLUMN IF NOT EXISTS active_session_category_name text;

-- 2. Create activity_feed table
CREATE TABLE IF NOT EXISTS public.activity_feed (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    activity_type text NOT NULL CHECK (activity_type IN ('daily_summary', 'streak_milestone', 'league_promotion')),
    payload jsonb NOT NULL,
    activity_date date NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, activity_type, activity_date)
);

CREATE INDEX IF NOT EXISTS idx_activity_feed_user_created ON public.activity_feed (user_id, created_at DESC);

-- Enable RLS on activity_feed
ALTER TABLE public.activity_feed ENABLE ROW LEVEL SECURITY;

-- Policy: User can see their own feed and their friends' feed
CREATE POLICY "Users can see their own and friends activity feed"
ON public.activity_feed
FOR SELECT
TO authenticated
USING (
    user_id = auth.uid() OR
    user_id IN (
        SELECT CASE WHEN user_id = auth.uid() THEN friend_id ELSE user_id END
        FROM public.friendships
        WHERE status = 'accepted' AND (user_id = auth.uid() OR friend_id = auth.uid())
    )
);

-- Service role has full access
CREATE POLICY "Service role full access on activity_feed"
ON public.activity_feed
USING (current_user = 'postgres' OR current_role = 'service_role');


-- 3. Update complete_study_session (Remove hourly limit, Add activity_feed logic, Clear active session)
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
    
    -- New validation variables
    v_last_completed_at timestamptz;
    v_daily_sessions integer;
    v_daily_limit_reached boolean := false;
    
    -- Activity Feed variables
    v_daily_minutes integer;
    v_top_category text;
BEGIN
    -- ============================================================
    -- AUTH CHECK
    -- ============================================================
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

    -- Clear active session from profile (always clear when complete is called)
    UPDATE public.profiles
    SET active_session_ends_at = NULL,
        active_session_category_name = NULL
    WHERE id = v_uid;

    -- ============================================================
    -- 1. IDEMPOTENCY: If this client_uuid already exists, return it
    -- ============================================================
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

    -- ============================================================
    -- 2. VALIDATION (Basic)
    -- ============================================================
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

    -- ============================================================
    -- 3. SANITY RULES (Overlapping Check Only)
    -- ============================================================
    SELECT completed_at INTO v_last_completed_at 
    FROM public.study_sessions 
    WHERE user_id = v_uid 
    ORDER BY completed_at DESC 
    LIMIT 1;
    
    IF v_last_completed_at IS NOT NULL AND p_started_at < v_last_completed_at THEN
        -- Silently reject overlapping session
        RETURN jsonb_build_object('error', 'overlap');
    END IF;

    -- HOURLY LIMIT REMOVED (User Request)

    -- ============================================================
    -- 4. BASE POINTS & STREAK
    -- ============================================================
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

    -- ============================================================
    -- 5. DAILY LEAGUE CEILING CHECK (16 sessions)
    -- ============================================================
    SELECT count(*) INTO v_daily_sessions
    FROM public.study_sessions
    WHERE user_id = v_uid 
      AND ((started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date = v_study_day;

    IF v_daily_sessions >= 16 THEN
        v_daily_limit_reached := true;
    END IF;

    -- ============================================================
    -- 6. STREAK BONUS
    -- ============================================================
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

    -- ============================================================
    -- 7. UPDATE PROFILES
    -- ============================================================
    UPDATE public.profiles
    SET total_minutes = total_minutes + p_duration_minutes,
        lifetime_points = lifetime_points + v_total_points,
        coins = coins + v_total_points,
        points = COALESCE(points, 0) + v_total_points,  
        current_streak = v_current_streak,
        longest_streak = v_longest_streak,
        last_study_date = v_study_day
    WHERE id = v_uid;

    -- ============================================================
    -- 8. LEAGUE POINTS
    -- ============================================================
    IF NOT v_daily_limit_reached THEN
        PERFORM public.ensure_user_in_league(v_uid, v_total_points);
    END IF;

    -- ============================================================
    -- 9. INSERT STUDY SESSION
    -- ============================================================
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

    -- ============================================================
    -- 10. ACTIVITY FEED
    -- ============================================================
    -- Upsert daily_summary
    -- We get total minutes and top category for today
    SELECT SUM(duration_minutes), COUNT(*) INTO v_daily_minutes, v_daily_sessions
    FROM public.study_sessions
    WHERE user_id = v_uid AND ((started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date = v_study_day;

    SELECT category INTO v_top_category
    FROM public.study_sessions
    WHERE user_id = v_uid AND ((started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date = v_study_day
    GROUP BY category
    ORDER BY SUM(duration_minutes) DESC
    LIMIT 1;

    INSERT INTO public.activity_feed (user_id, activity_type, activity_date, payload)
    VALUES (
        v_uid, 
        'daily_summary', 
        v_study_day, 
        jsonb_build_object(
            'total_minutes', COALESCE(v_daily_minutes, 0), 
            'session_count', COALESCE(v_daily_sessions, 0), 
            'top_category', v_top_category
        )
    )
    ON CONFLICT (user_id, activity_type, activity_date) 
    DO UPDATE SET 
        payload = EXCLUDED.payload, 
        updated_at = now();

    -- Insert streak_milestone
    IF v_current_streak IN (7, 14, 30, 60, 100) AND v_last_study_date IS DISTINCT FROM v_study_day THEN
        -- Notice the AND v_last_study_date check: we only award it the FIRST time today
        INSERT INTO public.activity_feed (user_id, activity_type, activity_date, payload)
        VALUES (v_uid, 'streak_milestone', v_study_day, jsonb_build_object('streak', v_current_streak))
        ON CONFLICT (user_id, activity_type, activity_date) DO NOTHING;
    END IF;

    -- ============================================================
    -- 11. RETURN RESULT
    -- ============================================================
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


-- 4. New RPC: start_study_session
CREATE OR REPLACE FUNCTION public.start_study_session(p_duration_minutes integer, p_category_name text)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE public.profiles 
  SET 
    active_session_ends_at = now() + (p_duration_minutes * interval '1 minute'),
    active_session_category_name = p_category_name
  WHERE id = auth.uid();
$$;

-- 5. New RPC: cancel_study_session
CREATE OR REPLACE FUNCTION public.cancel_study_session()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE public.profiles 
  SET 
    active_session_ends_at = NULL,
    active_session_category_name = NULL
  WHERE id = auth.uid();
$$;


-- 6. New RPC: get_live_friends
CREATE OR REPLACE FUNCTION public.get_live_friends()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_result jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'name', p.name,
            'avatar_id', p.avatar_id,
            'category_name', p.active_session_category_name,
            'ends_at', p.active_session_ends_at
        )
    ), '[]'::jsonb)
    INTO v_result
    FROM public.friendships f
    JOIN public.profiles p 
        ON (p.id = f.user_id OR p.id = f.friend_id) AND p.id != v_uid
    WHERE f.status = 'accepted'
      AND (f.user_id = v_uid OR f.friend_id = v_uid)
      AND p.show_in_social_feed = true
      AND p.active_session_ends_at > now();
      
    RETURN v_result;
END;
$$;


-- 7. New RPC: get_friends_feed
CREATE OR REPLACE FUNCTION public.get_friends_feed(p_limit integer DEFAULT 50)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_result jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', a.id,
            'user_id', p.id,
            'name', p.name,
            'avatar_id', p.avatar_id,
            'activity_type', a.activity_type,
            'payload', a.payload,
            'activity_date', a.activity_date,
            'created_at', a.created_at
        )
    ), '[]'::jsonb)
    INTO v_result
    FROM public.activity_feed a
    JOIN public.profiles p ON p.id = a.user_id
    WHERE p.show_in_social_feed = true
      AND (
          a.user_id = v_uid OR 
          a.user_id IN (
              SELECT CASE WHEN user_id = v_uid THEN friend_id ELSE user_id END
              FROM public.friendships
              WHERE status = 'accepted' AND (user_id = v_uid OR friend_id = v_uid)
          )
      )
    ORDER BY a.created_at DESC, a.id
    LIMIT p_limit;
    
    RETURN v_result;
END;
$$;


-- 8. Update process_weekly_leagues to log league_promotion
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
    
    -- New week start date
    v_new_week_start timestamptz := now();
BEGIN
    -- We loop over all leagues (order doesn't matter for independent processing)
    FOR v_league IN SELECT id, tier FROM public.leagues
    LOOP
        v_current_league_id := v_league.id;
        
        v_higher_league_id := CASE v_league.tier
            WHEN 1 THEN (SELECT id FROM public.leagues WHERE tier = 2 LIMIT 1)
            WHEN 2 THEN (SELECT id FROM public.leagues WHERE tier = 3 LIMIT 1)
            WHEN 3 THEN (SELECT id FROM public.leagues WHERE tier = 4 LIMIT 1)
            WHEN 4 THEN (SELECT id FROM public.leagues WHERE tier = 5 LIMIT 1)
            WHEN 5 THEN NULL -- no higher tier
        END;

        v_lower_league_id := CASE v_league.tier
            WHEN 5 THEN (SELECT id FROM public.leagues WHERE tier = 4 LIMIT 1)
            WHEN 4 THEN (SELECT id FROM public.leagues WHERE tier = 3 LIMIT 1)
            WHEN 3 THEN (SELECT id FROM public.leagues WHERE tier = 2 LIMIT 1)
            WHEN 2 THEN (SELECT id FROM public.leagues WHERE tier = 1 LIMIT 1)
            WHEN 1 THEN NULL -- no lower tier
        END;
        
        -- Get zones
        SELECT threshold, promote_count, demote_count
        INTO v_threshold, v_promote_count, v_demote_count
        FROM public.get_league_zones( (SELECT count(*)::integer FROM public.league_memberships WHERE league_id = v_current_league_id) );
        
        -- Process members
        FOR v_member IN (
            SELECT user_id, weekly_points, rank() OVER (ORDER BY weekly_points DESC) as rnk
            FROM public.league_memberships
            WHERE league_id = v_current_league_id
        )
        LOOP
            IF v_member.rnk <= v_promote_count AND v_higher_league_id IS NOT NULL THEN
                -- Promote
                UPDATE public.league_memberships
                SET league_id = v_higher_league_id, weekly_points = 0
                WHERE user_id = v_member.user_id;

                -- Log promotion activity to activity_feed
                INSERT INTO public.activity_feed (user_id, activity_type, activity_date, payload)
                VALUES (v_member.user_id, 'league_promotion', (v_new_week_start - interval '1 day')::date, jsonb_build_object('league_id', v_higher_league_id))
                ON CONFLICT (user_id, activity_type, activity_date) DO NOTHING;
                
            ELSIF v_member.rnk > v_threshold - v_demote_count AND v_lower_league_id IS NOT NULL THEN
                -- Demote
                UPDATE public.league_memberships
                SET league_id = v_lower_league_id, weekly_points = 0
                WHERE user_id = v_member.user_id;
            ELSE
                -- Stay
                UPDATE public.league_memberships
                SET weekly_points = 0
                WHERE user_id = v_member.user_id;
            END IF;
        END LOOP;
    END LOOP;
    
    -- Update league week_start
    UPDATE public.leagues SET week_start = v_new_week_start;
END;
$function$;


-- 9. pg_cron for cleanup
-- Only run this if pg_cron is enabled
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
    ) THEN
        -- Safe to schedule
        IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup_activity_feed_job') THEN
            PERFORM cron.unschedule('cleanup_activity_feed_job');
        END IF;
        PERFORM cron.schedule('cleanup_activity_feed_job', '0 3 * * *', $cron$
          DELETE FROM public.activity_feed WHERE activity_date < CURRENT_DATE - 30;
        $cron$);
    END IF;
END $$;

COMMIT;
