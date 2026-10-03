BEGIN;

-- ==========================================
-- 1) RLS POLICIES FOR LEAGUES
-- ==========================================

-- LEAGUES table
ALTER TABLE public.leagues ENABLE ROW LEVEL SECURITY;

-- Select: anyone authenticated can read
DROP POLICY IF EXISTS "Leagues select policy" ON public.leagues;
CREATE POLICY "Leagues select policy" 
ON public.leagues FOR SELECT 
USING (auth.uid() IS NOT NULL);

-- Insert/Update/Delete: NO policies created (only service_role can do this)

-- LEAGUE_MEMBERSHIPS table
ALTER TABLE public.league_memberships ENABLE ROW LEVEL SECURITY;

-- Select: user can see memberships of any league they are a member of
CREATE OR REPLACE FUNCTION public.get_my_league_ids()
RETURNS SETOF uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
    SELECT league_id FROM public.league_memberships WHERE user_id = auth.uid();
$$;

DROP POLICY IF EXISTS "Memberships select policy" ON public.league_memberships;
CREATE POLICY "Memberships select policy" 
ON public.league_memberships FOR SELECT 
USING (
    league_id IN (SELECT public.get_my_league_ids())
);

-- Insert/Update/Delete: NO policies created (only security definer functions can update)

-- ==========================================
-- 2) GET_LEAGUE_ZONES FUNCTION
-- ==========================================
CREATE OR REPLACE FUNCTION public.get_league_zones(p_member_count integer)
RETURNS TABLE (
    promotion_zone_end integer,
    demotion_zone_start integer
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_member_count < 10 THEN
        promotion_zone_end := 3;
        demotion_zone_start := 999; -- No demotion
    ELSIF p_member_count < 20 THEN
        promotion_zone_end := 3;
        demotion_zone_start := GREATEST(p_member_count - 2, 4); -- Last 3 (e.g. 10 users: 8, 9, 10 demote)
    ELSE
        promotion_zone_end := 7;
        demotion_zone_start := GREATEST(p_member_count - 6, 8); -- Last 7
    END IF;
    
    RETURN NEXT;
END;
$$;

-- ==========================================
-- 3) PG_CRON SCHEDULE FIX
-- ==========================================
-- Use cron.unschedule and cron.schedule to avoid permission errors on cron.job table
SELECT cron.unschedule('weekly_leagues_job');
SELECT cron.schedule('weekly_leagues_job', '59 20 * * 0', 'SELECT public.process_weekly_leagues()');


-- ==========================================
-- 4) UPDATE RPCs FOR TIMEZONE & DYNAMIC ZONES
-- ==========================================

-- A. ensure_user_in_league
CREATE OR REPLACE FUNCTION public.ensure_user_in_league(p_user_id uuid, p_points integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_tier INTEGER;
    v_league_id UUID;
    v_membership_id UUID;
    v_end_date TIMESTAMPTZ;
BEGIN
    SELECT lm.id, lm.league_id 
    INTO v_membership_id, v_league_id
    FROM public.league_memberships lm
    JOIN public.leagues l ON l.id = lm.league_id
    WHERE lm.user_id = p_user_id AND l.is_active = true
    LIMIT 1;

    IF FOUND THEN
        UPDATE public.league_memberships
        SET weekly_points = weekly_points + p_points
        WHERE id = v_membership_id;
        RETURN;
    END IF;

    SELECT league_tier INTO v_tier
    FROM public.profiles
    WHERE id = p_user_id;

    IF v_tier IS NULL THEN
        v_tier := 1;
    END IF;

    SELECT l.id INTO v_league_id
    FROM public.leagues l
    LEFT JOIN public.league_memberships lm ON lm.league_id = l.id
    WHERE l.is_active = true AND l.tier = v_tier
    GROUP BY l.id
    HAVING COUNT(lm.id) < 30
    ORDER BY l.start_date ASC
    LIMIT 1;

    IF v_league_id IS NULL THEN
        -- Fix timezone: week end is 23:59:59 Istanbul time
        v_end_date := ((date_trunc('week', (current_timestamp AT TIME ZONE 'Europe/Istanbul')::date) + interval '6 days') + time '23:59:59') AT TIME ZONE 'Europe/Istanbul';
        
        INSERT INTO public.leagues (tier, end_date)
        VALUES (v_tier, v_end_date)
        RETURNING id INTO v_league_id;
    END IF;

    INSERT INTO public.league_memberships (league_id, user_id, weekly_points)
    VALUES (v_league_id, p_user_id, p_points);
END;
$function$;

-- B. get_league_ranking (Modified to return zones)
DROP FUNCTION IF EXISTS public.get_league_ranking(uuid);
CREATE OR REPLACE FUNCTION public.get_league_ranking(p_user_id uuid)
 RETURNS TABLE(
    name text, 
    email text, 
    avatar_id text, 
    weekly_points integer, 
    tier integer, 
    end_date timestamptz, 
    is_me boolean,
    promotion_zone_end integer,
    demotion_zone_start integer,
    member_count integer
 )
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_league_id UUID;
    v_tier INTEGER;
    v_end_date TIMESTAMPTZ;
    v_member_count INTEGER;
    v_promo_end INTEGER;
    v_demo_start INTEGER;
BEGIN
    SELECT l.id, l.tier, l.end_date
    INTO v_league_id, v_tier, v_end_date
    FROM public.league_memberships lm
    JOIN public.leagues l ON l.id = lm.league_id
    WHERE lm.user_id = p_user_id AND l.is_active = true
    LIMIT 1;

    IF v_league_id IS NULL THEN
        SELECT league_tier INTO v_tier FROM public.profiles WHERE id = p_user_id;
        v_end_date := ((date_trunc('week', (current_timestamp AT TIME ZONE 'Europe/Istanbul')::date) + interval '6 days') + time '23:59:59') AT TIME ZONE 'Europe/Istanbul';
        RETURN QUERY
        SELECT 
            p.name, p.email, p.avatar_id, 0, v_tier, v_end_date, true, 3, 999, 1
        FROM public.profiles p WHERE p.id = p_user_id;
        RETURN;
    END IF;

    SELECT count(*) INTO v_member_count FROM public.league_memberships WHERE league_id = v_league_id;
    
    SELECT z.promotion_zone_end, z.demotion_zone_start 
    INTO v_promo_end, v_demo_start 
    FROM public.get_league_zones(v_member_count) z;

    RETURN QUERY
    SELECT 
        p.name,
        p.email,
        p.avatar_id,
        lm.weekly_points,
        v_tier,
        v_end_date,
        (lm.user_id = p_user_id),
        v_promo_end,
        v_demo_start,
        v_member_count
    FROM public.league_memberships lm
    JOIN public.profiles p ON p.id = lm.user_id
    WHERE lm.league_id = v_league_id
    ORDER BY lm.weekly_points DESC, lm.joined_at ASC;
END;
$function$;


-- C. process_weekly_leagues
CREATE OR REPLACE FUNCTION public.process_weekly_leagues()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    r_league RECORD;
    r_member RECORD;
    v_rank INTEGER;
    v_new_tier INTEGER;
    v_member_count INTEGER;
    v_promo_end INTEGER;
    v_demo_start INTEGER;
BEGIN
    FOR r_league IN 
        SELECT id, tier FROM public.leagues WHERE is_active = true 
    LOOP
        SELECT count(*) INTO v_member_count FROM public.league_memberships WHERE league_id = r_league.id;
        
        SELECT z.promotion_zone_end, z.demotion_zone_start 
        INTO v_promo_end, v_demo_start 
        FROM public.get_league_zones(v_member_count) z;

        v_rank := 1;
        FOR r_member IN 
            SELECT user_id, weekly_points 
            FROM public.league_memberships 
            WHERE league_id = r_league.id 
            ORDER BY weekly_points DESC 
        LOOP
            v_new_tier := r_league.tier;
            
            IF v_rank <= v_promo_end AND r_league.tier < 5 THEN
                v_new_tier := r_league.tier + 1;
            ELSIF v_rank >= v_demo_start AND r_league.tier > 1 THEN
                v_new_tier := r_league.tier - 1;
            END IF;
            
            UPDATE public.profiles SET league_tier = v_new_tier WHERE id = r_member.user_id;
            v_rank := v_rank + 1;
        END LOOP;
        
        UPDATE public.leagues SET is_active = false WHERE id = r_league.id;
    END LOOP;
END;
$function$;

COMMIT;
