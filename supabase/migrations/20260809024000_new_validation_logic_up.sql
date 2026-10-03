BEGIN;

-- 1. Alter is_verified from boolean to integer to store foreground seconds
ALTER TABLE public.study_sessions ALTER COLUMN is_verified DROP DEFAULT;
ALTER TABLE public.study_sessions 
  ALTER COLUMN is_verified TYPE integer 
  USING (CASE WHEN is_verified THEN duration_minutes * 60 ELSE 0 END);
ALTER TABLE public.study_sessions ALTER COLUMN is_verified SET DEFAULT 0;

-- We drop the old one with boolean parameter so Postgres doesn't get confused by overloaded names
DROP FUNCTION IF EXISTS public.complete_study_session(uuid, uuid, integer, boolean, boolean, timestamptz);

-- 2. Update the complete_study_session RPC
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
    v_hourly_minutes integer;
    v_daily_sessions integer;
    v_daily_limit_reached boolean := false;
BEGIN
    -- ============================================================
    -- AUTH CHECK
    -- ============================================================
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

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
    -- 3. SANITY RULES (Overlapping, Hourly)
    -- ============================================================
    
    -- a) Overlapping Session Check
    SELECT completed_at INTO v_last_completed_at 
    FROM public.study_sessions 
    WHERE user_id = v_uid 
    ORDER BY completed_at DESC 
    LIMIT 1;
    
    IF v_last_completed_at IS NOT NULL AND p_started_at < v_last_completed_at THEN
        -- Silently reject overlapping session
        RETURN jsonb_build_object('error', 'overlap');
    END IF;

    -- b) Hourly Limit Check (max 60 minutes in a 60 min window)
    SELECT COALESCE(SUM(duration_minutes), 0) INTO v_hourly_minutes
    FROM public.study_sessions
    WHERE user_id = v_uid 
      AND started_at >= (p_started_at - interval '60 minutes');
      
    IF v_hourly_minutes + p_duration_minutes > 60 THEN
        -- Silently reject exceeding hourly limit
        RETURN jsonb_build_object('error', 'hourly_limit');
    END IF;

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
    -- Find how many sessions were logged today (using the 04:00 boundary rule)
    -- Equivalent to: ((started_at AT TIME ZONE user_tz) - 4 hours)::date = v_study_day
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
    -- Add league points ONLY IF the daily limit is NOT reached.
    -- (We removed the is_verified penalty, so all sessions qualify unless daily limit hit)
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
    -- 10. RETURN RESULT
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

COMMIT;
