BEGIN;

-- 1. Add started_at column to study_sessions (needed for the new RPC)
ALTER TABLE public.study_sessions 
    ADD COLUMN IF NOT EXISTS started_at timestamptz;

-- 2. Add unique constraint on (user_id, client_uuid) for idempotency
CREATE UNIQUE INDEX IF NOT EXISTS study_sessions_user_client_uuid_key 
    ON public.study_sessions (user_id, client_uuid) WHERE client_uuid IS NOT NULL;

-- 3. Create the new complete_study_session RPC
CREATE OR REPLACE FUNCTION public.complete_study_session(
    p_client_uuid uuid,
    p_category_id uuid,
    p_duration_minutes integer,
    p_was_paused boolean,
    p_is_verified boolean,
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
            'duplicate', true
        );
    END IF;

    -- ============================================================
    -- 2. VALIDATION
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

    -- category must belong to this user
    IF NOT EXISTS (
        SELECT 1 FROM public.categories 
        WHERE id = p_category_id AND user_id = v_uid
    ) THEN
        RAISE EXCEPTION 'category does not belong to this user';
    END IF;

    -- ============================================================
    -- 3. BASE POINTS
    -- ============================================================
    IF p_duration_minutes = 25 THEN
        v_base_points := 5;
    ELSE
        v_base_points := 12;  -- 50 min rewards more than 2x25
    END IF;

    -- Paused penalty: 20% reduction (ceil so always at least 1 pt lost)
    IF p_was_paused THEN
        v_base_points := v_base_points - ceil(v_base_points * 0.20);
    END IF;

    -- ============================================================
    -- 4. STREAK - Study day boundary at 04:00 local time
    -- ============================================================
    SELECT current_streak, longest_streak, last_study_date, 
           COALESCE(timezone, 'Europe/Istanbul')
    INTO v_current_streak, v_longest_streak, v_last_study_date, v_user_tz
    FROM public.profiles
    WHERE id = v_uid
    FOR UPDATE;  -- lock the row

    -- "Study day" = (started_at in user's timezone - 4 hours)::date
    -- So midnight-03:59 counts as previous day
    v_study_day := ((p_started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date;

    IF v_last_study_date IS NULL THEN
        v_current_streak := 1;
    ELSIF v_last_study_date = v_study_day THEN
        -- Same study day: streak unchanged
        NULL;
    ELSIF v_last_study_date = v_study_day - 1 THEN
        v_current_streak := v_current_streak + 1;
    ELSE
        v_current_streak := 1;
    END IF;

    -- Update longest_streak
    IF v_current_streak > COALESCE(v_longest_streak, 0) THEN
        v_longest_streak := v_current_streak;
    END IF;

    -- ============================================================
    -- 5. STREAK BONUS
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
    -- 6. UPDATE PROFILES
    -- ============================================================
    UPDATE public.profiles
    SET total_minutes = total_minutes + p_duration_minutes,
        lifetime_points = lifetime_points + v_total_points,
        coins = coins + v_total_points,
        points = COALESCE(points, 0) + v_total_points,  -- keep old column in sync
        current_streak = v_current_streak,
        longest_streak = v_longest_streak,
        last_study_date = v_study_day
    WHERE id = v_uid;

    -- ============================================================
    -- 7. LEAGUE POINTS (only verified sessions count)
    -- ============================================================
    IF p_is_verified THEN
        PERFORM public.ensure_user_in_league(v_uid, v_total_points);
    END IF;

    -- ============================================================
    -- 8. INSERT STUDY SESSION
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
    -- 9. RETURN RESULT
    -- ============================================================
    RETURN jsonb_build_object(
        'base_points', v_base_points,
        'bonus_points', v_bonus_points,
        'total_points', v_total_points,
        'streak', v_current_streak,
        'bonus_pct', v_bonus_pct,
        'duplicate', false
    );
END;
$function$;

COMMIT;
