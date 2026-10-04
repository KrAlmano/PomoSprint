-- ============================================================================
-- GERİ ALMA: supabase/proposed/20_lig_donemi.sql
-- ============================================================================
-- Zincir (12 → 15 → 16 → 19 → 13 → 14) uygulanmış hâle döner:
-- ensure_user_in_league (canlı gövde + 13'ün pg_temp'i), process_weekly_leagues
-- (canlı gövde) ve get_league_ranking (14'ün gövdesi) pg_get_functiondef
-- çıktısıyla BİREBİR; carry_points kolonu ve üç app_config anahtarı silinir.
-- 21 uygulanmışsa hiçbir şey yapmadan durur (önce 21_seans_kilit_gec_bonus_down.sql).
--
-- VERİ: Bekleyen carry_points (oda bitişinden sonra biten, dönem sonu henüz
-- işlenmemiş seansların puanı) bugünkü davranıştaki gibi eski odadaki
-- weekly_points'e eklenir. Taşınmış üyelerin joined_at'ı geri alınmaz
-- (yalnızca eşitlik sırası). Yerelde doğrulama: tool/local_supabase/
-- proposed_chain_check.sh (geri alma sonrası şema 14 hâliyle birebir).
-- ============================================================================

\echo 'supabase/proposed/20_down: doğrudan çalıştırılmaz; \echo/\quit satırlarını silip SQL Editor''de çalıştırın.'
\quit

BEGIN;

DO $pre$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = 'league_memberships'
                      AND column_name = 'carry_points') THEN
        RAISE EXCEPTION 'proposed/20_down: 20 uygulanmamış görünüyor (carry_points yok); yapılacak bir şey yok.';
    END IF;
    IF pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamp with time zone)'::regprocedure)
       LIKE '%carry_points%' THEN
        RAISE EXCEPTION 'proposed/20_down: önce 21_seans_kilit_gec_bonus_down.sql uygulanmalı (21, carry_points''e yazıyor).';
    END IF;
END
$pre$;

UPDATE public.league_memberships
   SET weekly_points = weekly_points + carry_points
 WHERE carry_points <> 0;

CREATE OR REPLACE FUNCTION public.ensure_user_in_league(p_user_id uuid, p_points integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_tier INTEGER;
    v_league_id UUID;
    v_membership_id UUID;
    v_end_date TIMESTAMPTZ;
BEGIN
    IF p_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'not authorized';
    END IF;

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
        v_end_date := ((date_trunc('week', (current_timestamp AT TIME ZONE 'Europe/Istanbul')::date::timestamp) + interval '13 days') + time '23:59:59') AT TIME ZONE 'Europe/Istanbul';
        
        INSERT INTO public.leagues (tier, end_date)
        VALUES (v_tier, v_end_date)
        RETURNING id INTO v_league_id;
    END IF;

    INSERT INTO public.league_memberships (league_id, user_id, weekly_points)
    VALUES (v_league_id, p_user_id, p_points);
END;
$function$;

CREATE OR REPLACE FUNCTION public.process_weekly_leagues()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_promo_end integer;
    v_demo_start integer;
    v_member_count integer;

    v_higher_tier integer;
    v_lower_tier integer;

    v_league record;
    v_member record;
    v_target_league_id uuid;
    v_award_avatar_id text;

    v_new_period_start timestamptz := now();
    v_new_end_date timestamptz;
    v_fresh_end_date timestamptz;

    -- Bu koşuda işlenen (ve başka lige taşınan) üyeler, taşındıkları
    -- ligin dönemi de aynı koşuda bitiyorsa ikinci kez işlenmez.
    v_processed uuid[] := '{}';
BEGIN
    -- Bu koşuda yeni açılacak odalar için: bugünden itibaren 2. Pazar 23:59 (TR saati)
    v_fresh_end_date := (date_trunc('week', ((current_timestamp AT TIME ZONE 'Europe/Istanbul') + interval '1 day')::date::timestamp) + interval '13 days' + time '23:59:59') AT TIME ZONE 'Europe/Istanbul';

    FOR v_league IN
        SELECT id, tier, end_date FROM public.leagues
        WHERE is_active = true AND end_date <= now() + interval '5 minutes'
        ORDER BY tier, start_date
    LOOP
        v_higher_tier := CASE WHEN v_league.tier < 5 THEN v_league.tier + 1 ELSE NULL END;
        v_lower_tier := CASE WHEN v_league.tier > 1 THEN v_league.tier - 1 ELSE NULL END;
        v_new_end_date := v_league.end_date + interval '14 days';
        IF v_new_end_date <= now() THEN
            -- cron kaçırıldıysa geçmişte kalan bir bitişe değil, sıradaki
            -- normal döneme ayarla
            v_new_end_date := v_fresh_end_date;
        END IF;

        SELECT count(*)::integer INTO v_member_count
        FROM public.league_memberships
        WHERE league_id = v_league.id AND NOT (user_id = ANY (v_processed));

        SELECT z.promotion_zone_end, z.demotion_zone_start
        INTO v_promo_end, v_demo_start
        FROM public.get_league_zones(v_member_count) z;

        FOR v_member IN (
            SELECT lm.user_id, lm.weekly_points,
                   row_number() OVER (ORDER BY lm.weekly_points DESC, lm.joined_at ASC, lm.user_id) AS rnk
            FROM public.league_memberships lm
            WHERE lm.league_id = v_league.id AND NOT (lm.user_id = ANY (v_processed))
        )
        LOOP
            v_processed := v_processed || v_member.user_id;

            -- Dönem sonu lig ödülü: yalnızca puan toplamış ilk 3
            IF v_member.weekly_points > 0 THEN
                v_award_avatar_id := public.league_award_avatar_id(v_league.tier, v_member.rnk::integer);
                IF v_award_avatar_id IS NOT NULL THEN
                    INSERT INTO public.avatar_unlocks (user_id, avatar_id, unlock_type, coins_spent)
                    VALUES (v_member.user_id, v_award_avatar_id, 'league_award', 0)
                    ON CONFLICT (user_id, avatar_id) DO NOTHING;
                END IF;
            END IF;

            IF v_member.weekly_points > 0 AND v_member.rnk <= v_promo_end AND v_higher_tier IS NOT NULL THEN
                SELECT l.id INTO v_target_league_id
                FROM public.leagues l
                LEFT JOIN public.league_memberships lm ON lm.league_id = l.id
                WHERE l.is_active = true AND l.tier = v_higher_tier
                GROUP BY l.id
                HAVING COUNT(lm.id) < 30
                ORDER BY l.start_date ASC
                LIMIT 1;

                IF v_target_league_id IS NULL THEN
                    INSERT INTO public.leagues (tier, end_date)
                    VALUES (v_higher_tier, v_fresh_end_date)
                    RETURNING id INTO v_target_league_id;
                END IF;

                UPDATE public.league_memberships
                SET league_id = v_target_league_id, weekly_points = 0
                WHERE user_id = v_member.user_id;

                UPDATE public.profiles SET league_tier = v_higher_tier WHERE id = v_member.user_id;

                INSERT INTO public.activity_feed (user_id, activity_type, activity_date, payload)
                VALUES (v_member.user_id, 'league_promotion', (v_new_period_start - interval '1 day')::date, jsonb_build_object('league_id', v_target_league_id, 'tier', v_higher_tier))
                ON CONFLICT (user_id, activity_type, activity_date) DO NOTHING;

            ELSIF v_member.rnk >= v_demo_start AND v_lower_tier IS NOT NULL THEN
                SELECT l.id INTO v_target_league_id
                FROM public.leagues l
                LEFT JOIN public.league_memberships lm ON lm.league_id = l.id
                WHERE l.is_active = true AND l.tier = v_lower_tier
                GROUP BY l.id
                HAVING COUNT(lm.id) < 30
                ORDER BY l.start_date ASC
                LIMIT 1;

                IF v_target_league_id IS NULL THEN
                    INSERT INTO public.leagues (tier, end_date)
                    VALUES (v_lower_tier, v_fresh_end_date)
                    RETURNING id INTO v_target_league_id;
                END IF;

                UPDATE public.league_memberships
                SET league_id = v_target_league_id, weekly_points = 0
                WHERE user_id = v_member.user_id;

                UPDATE public.profiles SET league_tier = v_lower_tier WHERE id = v_member.user_id;
            ELSE
                UPDATE public.league_memberships
                SET weekly_points = 0
                WHERE user_id = v_member.user_id;
            END IF;
        END LOOP;

        UPDATE public.leagues SET end_date = v_new_end_date WHERE id = v_league.id;
    END LOOP;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_league_ranking(p_user_id uuid)
 RETURNS TABLE(name text, avatar_id text, weekly_points integer, tier integer, end_date timestamp with time zone, is_me boolean, promotion_zone_end integer, demotion_zone_start integer, member_count integer, id uuid, is_blocked boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_league_id UUID;
    v_tier INTEGER;
    v_end_date TIMESTAMPTZ;
    v_member_count INTEGER;
    v_promo_end INTEGER;
    v_demo_start INTEGER;
BEGIN
    -- Yalnızca kendi ligini görebilirsin (önceden herhangi bir kullanıcı id'si
    -- ile, oturumsuz bile çağrılabiliyordu).
    IF p_user_id IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'not authorized';
    END IF;

    SELECT l.id, l.tier, l.end_date
    INTO v_league_id, v_tier, v_end_date
    FROM public.league_memberships lm
    JOIN public.leagues l ON l.id = lm.league_id
    WHERE lm.user_id = p_user_id AND l.is_active = true
    LIMIT 1;

    IF v_league_id IS NULL THEN
        SELECT pr.league_tier INTO v_tier FROM public.profiles pr WHERE pr.id = p_user_id;
        -- ensure_user_in_league ile aynı 14 günlük dönem sonu
        v_end_date := ((date_trunc('week', (current_timestamp AT TIME ZONE 'Europe/Istanbul')::date::timestamp) + interval '13 days') + time '23:59:59') AT TIME ZONE 'Europe/Istanbul';
        RETURN QUERY
        SELECT
            p.name, p.avatar_id, 0, v_tier, v_end_date, true, 1, 999, 1, p.id, false
        FROM public.profiles p WHERE p.id = p_user_id;
        RETURN;
    END IF;

    SELECT count(*) INTO v_member_count FROM public.league_memberships lm2 WHERE lm2.league_id = v_league_id;

    SELECT z.promotion_zone_end, z.demotion_zone_start
    INTO v_promo_end, v_demo_start
    FROM public.get_league_zones(v_member_count) z;

    -- İlk 3'teki (ve puanı olan) üyeler bu ekranda lig ödülü avatarıyla
    -- görünür; profiles.avatar_id'ye dokunulmaz. Sıralama, dönem sonu
    -- işlemiyle (process_weekly_leagues) birebir aynı kuraldır.
    RETURN QUERY
    SELECT
        CASE WHEN b.blocked_id IS NOT NULL THEN NULL ELSE p.name END,
        CASE WHEN b.blocked_id IS NOT NULL THEN NULL ELSE
            COALESCE(
                CASE WHEN ranked.weekly_points > 0
                     THEN public.league_award_avatar_id(v_tier, ranked.rnk::integer) END,
                p.avatar_id)
        END,
        ranked.weekly_points,
        v_tier,
        v_end_date,
        (ranked.user_id = p_user_id),
        v_promo_end,
        v_demo_start,
        v_member_count,
        ranked.user_id,
        (b.blocked_id IS NOT NULL)
    FROM (
        SELECT lm.user_id, lm.weekly_points, lm.joined_at,
               row_number() OVER (ORDER BY lm.weekly_points DESC, lm.joined_at ASC, lm.user_id) AS rnk
        FROM public.league_memberships lm
        WHERE lm.league_id = v_league_id
    ) ranked
    JOIN public.profiles p ON p.id = ranked.user_id
    LEFT JOIN public.user_blocks b ON b.blocker_id = p_user_id AND b.blocked_id = ranked.user_id
    ORDER BY ranked.rnk ASC;
END;
$function$;

REVOKE ALL ON FUNCTION public.ensure_user_in_league(uuid, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_user_in_league(uuid, integer) TO service_role;
REVOKE ALL ON FUNCTION public.process_weekly_leagues() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_weekly_leagues() TO service_role;
REVOKE ALL ON FUNCTION public.get_league_ranking(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_league_ranking(uuid) TO authenticated, service_role;

ALTER TABLE public.league_memberships DROP COLUMN carry_points;

DELETE FROM public.app_config
 WHERE key IN ('league_award_min_members', 'league_award_min_points', 'league_promotion_min_points');

DO $$
BEGIN
    DELETE FROM supabase_migrations.schema_migrations WHERE version = '20261005120000';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişinden silinemedi: %', SQLERRM;
END $$;

COMMIT;
