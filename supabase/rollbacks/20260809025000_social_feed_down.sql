-- ============================================================
-- UYARI: CANLIYA UYGULAMADAN ÖNCE OKUYUN
-- ------------------------------------------------------------
-- Bu dosya bir GERİ ALMA (rollback) betiğidir, migration DEĞİLDİR.
-- supabase/migrations/ dışında tutulur; aksi halde `supabase db push`
-- onu aynı sürüm numaralı ileri migration sanıp _up dosyasından ÖNCE
-- uygular. Repodaki migration'lar canlı şemanın gerisinde olduğu için
-- bu betik canlıdaki güncel fonksiyon gövdelerini ESKİ sürümlerle
-- ezebilir ve geri alınamaz şekilde VERİ SİLEBİLİR.
-- Uygulamadan önce `supabase db dump` ile yedek alın, dosyayı satır
-- satır okuyun ve önce staging/branch üzerinde deneyin.
--
-- Bu dosyaya özel riskler:
--   activity_feed tablosunu ve profiles.active_session_* kolonlarını
--   SİLER; get_live_friends/get_friends_feed/start/cancel_study_session
--   fonksiyonlarını siler (istemcinin canlı arkadaş listesi bozulur).
--   complete_study_session'ı activity_feed'siz eski sürüme çevirir:
--   canlıdaki gövde (coins_earned vb.) EZİLİR.
--   Düzeltildi: process_weekly_leagues artık 025000'deki bozuk sürüm
--   yerine 20260809022700'deki çalışan sürüme döner.
-- ============================================================

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
-- Önceki ÇALIŞAN sürüm (20260809022700). Bu dosyanın eski hâli 025000'deki
-- bozuk gövdeyi (integer lig id'si, var olmayan threshold/week_start
-- kolonları) geri yüklüyordu; o gövde her çalışmada hata verir.
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
            -- Eşitlikte get_league_ranking ile aynı deterministik sıra (SOCIAL-08)
            ORDER BY weekly_points DESC, joined_at ASC, user_id
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
