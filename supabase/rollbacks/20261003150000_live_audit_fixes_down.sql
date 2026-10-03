-- ============================================================================
-- GERİ ALMA: 20261003150000_live_audit_fixes
-- Yalnızca acil durumda çalıştırın. Fonksiyonları 3 Ekim 2026 öncesi CANLI
-- tanımlarına (pg_get_functiondef ile alındı) ve eski yetkilere döndürür.
--
-- DİKKAT:
--  * Eski hâl GÜVENLİK AÇIKLARINI geri getirir (istemcinin coins/puan/premium
--    yazabilmesi, çevrimdışı 2.+ seansların kaybolması, 0 puanla terfi).
--  * study_sessions.completed_at geri doldurması geri alınamaz (eski değerler
--    senkron anıydı, saklanmadı).
--  * marketing_subscribers.unsubscribe_token kolonunu düşürür; yeni
--    unsubscribe/send-welcome-email edge function'ları da eski sürüme
--    döndürülmelidir.
-- ============================================================================

-- Yeni nesneler
DROP TRIGGER IF EXISTS sanitize_profile_insert ON public.profiles;
DROP TRIGGER IF EXISTS validate_profile_timezone ON public.profiles;
DROP TRIGGER IF EXISTS enforce_category_limit_on_unarchive ON public.categories;
DROP FUNCTION IF EXISTS public.sanitize_profile_insert();
DROP FUNCTION IF EXISTS public.validate_profile_timezone();
DROP FUNCTION IF EXISTS public.get_my_league_ranking();
DROP FUNCTION IF EXISTS public.get_my_friends();
DROP FUNCTION IF EXISTS public.get_incoming_friend_requests();
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_name_length_check;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_daily_goal_range_check;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_birth_year_range_check;
DROP INDEX IF EXISTS public.idx_study_sessions_user_started;
DROP INDEX IF EXISTS public.idx_study_sessions_completed_at;
DROP INDEX IF EXISTS public.marketing_subscribers_unsubscribe_token_key;
DROP INDEX IF EXISTS public.marketing_subscribers_email_lower_key;
ALTER TABLE public.marketing_subscribers DROP COLUMN IF EXISTS unsubscribe_token;
ALTER TABLE public.marketing_subscribers DROP COLUMN IF EXISTS welcome_sent_at;

-- Eski yetkiler (Supabase varsayılanı)
GRANT ALL ON public.profiles, public.study_sessions, public.categories, public.friendships,
             public.leagues, public.league_memberships, public.avatar_unlocks,
             public.activity_feed, public.marketing_subscribers, public.avatars
  TO anon, authenticated;

SELECT cron.schedule('weekly_leagues_job', '59 20 * * 0', 'SELECT public.process_weekly_leagues()');

-- Eski fonksiyon gövdeleri ------------------------------------------------------

CREATE OR REPLACE FUNCTION public.complete_study_session(p_client_uuid uuid, p_category_id uuid, p_duration_minutes integer, p_was_paused boolean, p_is_verified integer, p_started_at timestamp with time zone)
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid; v_base_points integer; v_bonus_points integer := 0; v_total_points integer; v_coins_earned integer := 20;
    v_current_streak integer; v_longest_streak integer; v_last_study_date date; v_user_tz text; v_study_day date;
    v_bonus_pct integer := 0; v_session_id uuid; v_daily_sessions integer; v_daily_limit_reached boolean := false;
    v_daily_minutes integer; v_top_category text; v_existing RECORD; v_last_completed_at timestamptz; v_show_in_social_feed boolean;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
    SELECT * INTO v_existing FROM public.study_sessions WHERE client_uuid = p_client_uuid AND user_id = v_uid LIMIT 1;
    IF FOUND THEN
        RETURN jsonb_build_object('base_points', v_existing.base_points, 'bonus_points', v_existing.bonus_points,
            'total_points', v_existing.base_points + v_existing.bonus_points,
            'streak', (SELECT current_streak FROM public.profiles WHERE id = v_uid), 'bonus_pct', 0,
            'duplicate', true, 'daily_limit_reached', false);
    END IF;
    IF p_duration_minutes NOT IN (25, 50) THEN RAISE EXCEPTION 'invalid duration: only 25 or 50 allowed'; END IF;
    IF p_started_at > now() THEN RAISE EXCEPTION 'started_at cannot be in the future'; END IF;
    IF p_started_at < now() - interval '24 hours' THEN RAISE EXCEPTION 'started_at is older than 24 hours'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.categories WHERE id = p_category_id AND user_id = v_uid) THEN
        RAISE EXCEPTION 'category does not belong to this user';
    END IF;
    SELECT completed_at INTO v_last_completed_at FROM public.study_sessions WHERE user_id = v_uid ORDER BY completed_at DESC LIMIT 1;
    IF v_last_completed_at IS NOT NULL AND p_started_at < v_last_completed_at THEN
        RETURN jsonb_build_object('error', 'overlap');
    END IF;
    IF p_duration_minutes = 25 THEN v_base_points := 5; ELSE v_base_points := 12; END IF;
    IF p_was_paused THEN v_base_points := v_base_points - ceil(v_base_points * 0.20); END IF;
    SELECT current_streak, longest_streak, last_study_date, COALESCE(timezone, 'Europe/Istanbul'), show_in_social_feed
    INTO v_current_streak, v_longest_streak, v_last_study_date, v_user_tz, v_show_in_social_feed
    FROM public.profiles WHERE id = v_uid FOR UPDATE;
    v_study_day := ((p_started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date;
    IF v_last_study_date IS NULL THEN v_current_streak := 1;
    ELSIF v_last_study_date = v_study_day THEN NULL;
    ELSIF v_last_study_date = v_study_day - 1 THEN v_current_streak := v_current_streak + 1;
    ELSE v_current_streak := 1;
    END IF;
    IF v_current_streak > COALESCE(v_longest_streak, 0) THEN v_longest_streak := v_current_streak; END IF;
    SELECT count(*) INTO v_daily_sessions FROM public.study_sessions
    WHERE user_id = v_uid AND ((started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date = v_study_day;
    IF v_daily_sessions >= 16 THEN v_daily_limit_reached := true; END IF;
    IF v_current_streak >= 14 THEN v_bonus_pct := 30; ELSIF v_current_streak >= 7 THEN v_bonus_pct := 20;
    ELSIF v_current_streak >= 3 THEN v_bonus_pct := 10; ELSE v_bonus_pct := 0; END IF;
    v_bonus_points := ceil(v_base_points::numeric * v_bonus_pct / 100.0);
    v_total_points := v_base_points + v_bonus_points;
    IF v_daily_limit_reached THEN v_base_points := 0; v_bonus_points := 0; v_total_points := 0; v_coins_earned := 0; END IF;
    UPDATE public.profiles SET total_minutes = total_minutes + p_duration_minutes, lifetime_points = lifetime_points + v_total_points,
        coins = coins + v_coins_earned, current_streak = v_current_streak, longest_streak = v_longest_streak, last_study_date = v_study_day
    WHERE id = v_uid;
    IF NOT v_daily_limit_reached THEN PERFORM public.ensure_user_in_league(v_uid, v_total_points); END IF;
    INSERT INTO public.study_sessions (user_id, category, category_id, duration_minutes, base_points, bonus_points,
        was_paused, is_verified, client_uuid, started_at, completed_at)
    VALUES (v_uid, (SELECT name FROM public.categories WHERE id = p_category_id), p_category_id, p_duration_minutes,
        v_base_points, v_bonus_points, p_was_paused, p_is_verified, p_client_uuid, p_started_at, now())
    RETURNING id INTO v_session_id;
    IF v_show_in_social_feed THEN
        SELECT SUM(duration_minutes), COUNT(*) INTO v_daily_minutes, v_daily_sessions FROM public.study_sessions
        WHERE user_id = v_uid AND ((started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date = v_study_day;
        SELECT category INTO v_top_category FROM public.study_sessions
        WHERE user_id = v_uid AND ((started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date = v_study_day
        GROUP BY category ORDER BY SUM(duration_minutes) DESC LIMIT 1;
        INSERT INTO public.activity_feed (user_id, activity_type, activity_date, payload)
        VALUES (v_uid, 'daily_summary', v_study_day, jsonb_build_object('total_minutes', COALESCE(v_daily_minutes, 0),
            'session_count', COALESCE(v_daily_sessions, 0), 'top_category', v_top_category))
        ON CONFLICT (user_id, activity_type, activity_date) DO UPDATE SET payload = EXCLUDED.payload, updated_at = now();
        IF v_current_streak IN (7, 14, 30, 60, 100) AND v_last_study_date IS DISTINCT FROM v_study_day THEN
            INSERT INTO public.activity_feed (user_id, activity_type, activity_date, payload)
            VALUES (v_uid, 'streak_milestone', v_study_day, jsonb_build_object('streak', v_current_streak))
            ON CONFLICT (user_id, activity_type, activity_date) DO NOTHING;
        END IF;
        IF COALESCE(v_daily_minutes, 0) >= 240 THEN
            INSERT INTO public.activity_feed (user_id, activity_type, activity_date, payload)
            VALUES (v_uid, 'daily_4h_milestone', v_study_day, jsonb_build_object('total_minutes', v_daily_minutes))
            ON CONFLICT (user_id, activity_type, activity_date) DO NOTHING;
        END IF;
    END IF;
    RETURN jsonb_build_object('base_points', v_base_points, 'bonus_points', v_bonus_points, 'total_points', v_total_points,
        'coins_earned', v_coins_earned, 'streak', v_current_streak, 'bonus_pct', v_bonus_pct, 'duplicate', false,
        'daily_limit_reached', v_daily_limit_reached);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_league_zones(p_member_count integer)
 RETURNS TABLE(promotion_zone_end integer, demotion_zone_start integer) LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF p_member_count < 10 THEN
        promotion_zone_end := 3; demotion_zone_start := 999;
    ELSIF p_member_count < 20 THEN
        promotion_zone_end := 3; demotion_zone_start := GREATEST(p_member_count - 2, 4);
    ELSE
        promotion_zone_end := 7; demotion_zone_start := GREATEST(p_member_count - 6, 8);
    END IF;
    RETURN NEXT;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_league_ranking(p_user_id uuid)
 RETURNS TABLE(name text, avatar_id text, weekly_points integer, tier integer, end_date timestamp with time zone, is_me boolean, promotion_zone_end integer, demotion_zone_start integer, member_count integer)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
DECLARE
    v_league_id UUID; v_tier INTEGER; v_end_date TIMESTAMPTZ; v_member_count INTEGER; v_promo_end INTEGER; v_demo_start INTEGER;
BEGIN
    SELECT l.id, l.tier, l.end_date INTO v_league_id, v_tier, v_end_date
    FROM public.league_memberships lm JOIN public.leagues l ON l.id = lm.league_id
    WHERE lm.user_id = p_user_id AND l.is_active = true LIMIT 1;
    IF v_league_id IS NULL THEN
        SELECT league_tier INTO v_tier FROM public.profiles WHERE id = p_user_id;
        v_end_date := ((date_trunc('week', (current_timestamp AT TIME ZONE 'Europe/Istanbul')::date) + interval '6 days') + time '23:59:59') AT TIME ZONE 'Europe/Istanbul';
        RETURN QUERY SELECT p.name, p.avatar_id, 0, v_tier, v_end_date, true, 3, 999, 1 FROM public.profiles p WHERE p.id = p_user_id;
        RETURN;
    END IF;
    SELECT count(*) INTO v_member_count FROM public.league_memberships WHERE league_id = v_league_id;
    SELECT z.promotion_zone_end, z.demotion_zone_start INTO v_promo_end, v_demo_start FROM public.get_league_zones(v_member_count) z;
    RETURN QUERY
    SELECT p.name, COALESCE(public.league_award_avatar_id(v_tier, ranked.rnk::integer), p.avatar_id) AS avatar_id,
        ranked.weekly_points, v_tier, v_end_date, (ranked.user_id = p_user_id), v_promo_end, v_demo_start, v_member_count
    FROM (
        SELECT lm.user_id, lm.weekly_points, lm.joined_at,
               row_number() OVER (ORDER BY lm.weekly_points DESC, lm.joined_at ASC) AS rnk
        FROM public.league_memberships lm WHERE lm.league_id = v_league_id
    ) ranked
    JOIN public.profiles p ON p.id = ranked.user_id
    ORDER BY ranked.rnk ASC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.process_weekly_leagues()
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_promo_end integer; v_demo_start integer; v_current_league_id uuid; v_higher_tier integer; v_lower_tier integer;
    v_league record; v_member record; v_target_league_id uuid; v_award_avatar_id text;
    v_new_period_start timestamptz := now(); v_new_end_date timestamptz; v_fresh_end_date timestamptz;
BEGIN
    v_fresh_end_date := (date_trunc('week', ((current_timestamp AT TIME ZONE 'Europe/Istanbul') + interval '1 day')::date::timestamp) + interval '13 days' + time '23:59:59') AT TIME ZONE 'Europe/Istanbul';
    FOR v_league IN SELECT id, tier, end_date FROM public.leagues WHERE is_active = true AND end_date <= now()
    LOOP
        v_current_league_id := v_league.id;
        v_higher_tier := CASE WHEN v_league.tier < 5 THEN v_league.tier + 1 ELSE NULL END;
        v_lower_tier := CASE WHEN v_league.tier > 1 THEN v_league.tier - 1 ELSE NULL END;
        v_new_end_date := v_league.end_date + interval '14 days';
        SELECT promotion_zone_end, demotion_zone_start INTO v_promo_end, v_demo_start
        FROM public.get_league_zones( (SELECT count(*)::integer FROM public.league_memberships WHERE league_id = v_current_league_id) );
        FOR v_member IN (
            SELECT user_id, weekly_points, rank() OVER (ORDER BY weekly_points DESC) as rnk
            FROM public.league_memberships WHERE league_id = v_current_league_id
        )
        LOOP
            v_award_avatar_id := public.league_award_avatar_id(v_league.tier, v_member.rnk::integer);
            IF v_award_avatar_id IS NOT NULL THEN
                INSERT INTO public.avatar_unlocks (user_id, avatar_id, unlock_type, coins_spent)
                VALUES (v_member.user_id, v_award_avatar_id, 'league_award', 0) ON CONFLICT (user_id, avatar_id) DO NOTHING;
            END IF;
            IF v_member.rnk <= v_promo_end AND v_higher_tier IS NOT NULL THEN
                SELECT l.id INTO v_target_league_id FROM public.leagues l LEFT JOIN public.league_memberships lm ON lm.league_id = l.id
                WHERE l.is_active = true AND l.tier = v_higher_tier GROUP BY l.id HAVING COUNT(lm.id) < 30 ORDER BY l.start_date ASC LIMIT 1;
                IF v_target_league_id IS NULL THEN
                    INSERT INTO public.leagues (tier, end_date) VALUES (v_higher_tier, v_fresh_end_date) RETURNING id INTO v_target_league_id;
                END IF;
                UPDATE public.league_memberships SET league_id = v_target_league_id, weekly_points = 0 WHERE user_id = v_member.user_id;
                UPDATE public.profiles SET league_tier = v_higher_tier WHERE id = v_member.user_id;
                INSERT INTO public.activity_feed (user_id, activity_type, activity_date, payload)
                VALUES (v_member.user_id, 'league_promotion', (v_new_period_start - interval '1 day')::date, jsonb_build_object('league_id', v_target_league_id, 'tier', v_higher_tier))
                ON CONFLICT (user_id, activity_type, activity_date) DO NOTHING;
            ELSIF v_member.rnk >= v_demo_start AND v_lower_tier IS NOT NULL THEN
                SELECT l.id INTO v_target_league_id FROM public.leagues l LEFT JOIN public.league_memberships lm ON lm.league_id = l.id
                WHERE l.is_active = true AND l.tier = v_lower_tier GROUP BY l.id HAVING COUNT(lm.id) < 30 ORDER BY l.start_date ASC LIMIT 1;
                IF v_target_league_id IS NULL THEN
                    INSERT INTO public.leagues (tier, end_date) VALUES (v_lower_tier, v_fresh_end_date) RETURNING id INTO v_target_league_id;
                END IF;
                UPDATE public.league_memberships SET league_id = v_target_league_id, weekly_points = 0 WHERE user_id = v_member.user_id;
                UPDATE public.profiles SET league_tier = v_lower_tier WHERE id = v_member.user_id;
            ELSE
                UPDATE public.league_memberships SET weekly_points = 0 WHERE user_id = v_member.user_id;
            END IF;
        END LOOP;
        UPDATE public.leagues SET end_date = v_new_end_date WHERE id = v_current_league_id;
    END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_live_friends()
 RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE v_uid uuid := auth.uid(); v_result jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(jsonb_build_object('id', p.id, 'name', p.name, 'avatar_id', p.avatar_id,
            'category_name', p.active_session_category_name, 'ends_at', p.active_session_ends_at)), '[]'::jsonb)
    INTO v_result
    FROM public.friendships f
    JOIN public.profiles p ON (p.id = f.user_id OR p.id = f.friend_id) AND p.id != v_uid
    WHERE f.status = 'accepted' AND (f.user_id = v_uid OR f.friend_id = v_uid)
      AND p.show_in_social_feed = true AND p.active_session_ends_at > now();
    RETURN v_result;
END;
$function$;

DROP FUNCTION IF EXISTS public.get_public_monthly_leaderboard(integer);
CREATE FUNCTION public.get_public_monthly_leaderboard(p_limit integer DEFAULT 10)
 RETURNS TABLE(name text, avatar_id text, total_points integer, total_minutes integer)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p.name, p.avatar_id, SUM(ss.base_points + ss.bonus_points)::integer AS total_points, SUM(ss.duration_minutes)::integer AS total_minutes
  FROM public.study_sessions ss JOIN public.profiles p ON p.id = ss.user_id
  WHERE ss.completed_at >= date_trunc('month', now()) AND p.show_in_social_feed = true
  GROUP BY p.id, p.name, p.avatar_id
  ORDER BY total_points DESC, total_minutes DESC
  LIMIT GREATEST(p_limit, 0);
$function$;

DROP FUNCTION IF EXISTS public.get_public_alltime_leaderboard(integer);
CREATE FUNCTION public.get_public_alltime_leaderboard(p_limit integer DEFAULT 50)
 RETURNS TABLE(name text, avatar_id text, total_minutes integer, lifetime_points integer, is_premium boolean)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT p.name, p.avatar_id, p.total_minutes, p.lifetime_points, p.is_premium
  FROM public.profiles p WHERE p.show_in_social_feed = true
  ORDER BY p.lifetime_points DESC
  LIMIT GREATEST(p_limit, 0);
$function$;

DROP FUNCTION IF EXISTS public.mask_public_name(text);

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $function$
begin
  insert into public.profiles (id, name, email, avatar_id, total_minutes, lifetime_points, friend_code)
  values (new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)), new.email,
    coalesce(new.raw_user_meta_data->>'avatar_id', 'avatar_1_gamer'), 0, 0,
    upper(substr(replace(gen_random_uuid()::text,'-',''),1,6)))
  on conflict (id) do update set email = excluded.email, name = coalesce(excluded.name, public.profiles.name);
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.give_default_avatars()
 RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    INSERT INTO public.avatar_unlocks (user_id, avatar_id, unlock_type, coins_spent)
    SELECT NEW.id, a.id, 'default', 0 FROM public.avatars a WHERE a.is_default = true
    ON CONFLICT (user_id, avatar_id) DO NOTHING;
    IF NEW.avatar_id IS NULL THEN NEW.avatar_id := 'avatar_2_glasses'; END IF;
    RETURN NEW;
END;
$function$;

-- Eski fonksiyon yetkileri (anon dahil herkes çağırabiliyordu)
DO $$
DECLARE f text;
BEGIN
    FOREACH f IN ARRAY ARRAY['add_friend_by_code(text)','cancel_study_session()','cleanup_unconfirmed_duplicate_identity(text)',
        'complete_study_session(uuid,uuid,integer,boolean,integer,timestamp with time zone)','create_category(text,text,text)',
        'delete_own_account()','get_friends_feed(integer)','get_league_ranking(uuid)','get_live_friends()','get_my_league_ids()',
        'purchase_avatar(text)','respond_friend_request(uuid,boolean)','set_equipped_avatar(text)','setup_onboarding_categories(jsonb)',
        'start_study_session(integer,text)','get_public_monthly_leaderboard(integer)','get_public_alltime_leaderboard(integer)']
    LOOP
        EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO PUBLIC, anon, authenticated', f);
    END LOOP;
END $$;
