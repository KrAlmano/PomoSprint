-- Hazırlık dönemi geri alması. Resmi başlangıç geçmişse geçmiş terfileri geri
-- almak otomatik/yıkıcı olmaz: durur, ayrı incelenmiş telafi gerekir.
-- Snapshot yalnız oda eşlemesi/config içindir; yeni seans/lifetime/kum/puan silinmez.
BEGIN;
DO $guard$
BEGIN
 PERFORM 1 FROM public.profiles ORDER BY id FOR UPDATE;
 PERFORM pg_advisory_xact_lock(hashtext('pomosprint_league_room'),t) FROM generate_series(1,5) t;
 PERFORM 1 FROM public.league_competition_state WHERE singleton FOR UPDATE;
 IF EXISTS(SELECT 1 FROM public.league_competition_state WHERE singleton AND
  (initialized OR start_at<=now())) THEN
  RAISE EXCEPTION 'league_launch_policy rollback: resmi dönem başladı; incelenmiş telafi ve yedek gerekir.';
 END IF;
END $guard$;

DROP TRIGGER league_schedule_after_completed_session ON public.study_sessions;
DROP FUNCTION public.get_my_league_ranking_v2();
DROP FUNCTION public.get_league_config();

-- BEGIN BASELINE FUNCTIONS (fresh live definitions are appended below)

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

    -- proposed/20 (t4-F7): kademe başına yerleştirme kilidi (işlem sonuna
    -- kadar). Eşzamanlı ilk seanslar sırayla oda seçer; sayım kilit altında.
    -- process_weekly_leagues aynı anahtarla beş kademeyi kilitler.
    PERFORM pg_advisory_xact_lock(hashtext('pomosprint_league_room'), v_tier);

    -- proposed/20 (t4-F5): bitmiş / 5 dakika içinde bitecek (dönem sonu
    -- işlenmemiş) odaya yerleştirme yok.
    SELECT l.id INTO v_league_id
    FROM public.leagues l
    LEFT JOIN public.league_memberships lm ON lm.league_id = l.id
    WHERE l.is_active = true AND l.tier = v_tier
      AND l.end_date > now() + interval '5 minutes'
    GROUP BY l.id
    HAVING COUNT(lm.id) < 30
    ORDER BY l.start_date ASC, l.id
    LIMIT 1;

    IF v_league_id IS NULL THEN
        -- Değişmedi: bu haftanın Pazartesi'si + 13 gün (ilk dönem 7–14 gün, t1-06).
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
    v_target_tier integer;

    v_league record;
    v_member record;
    v_target_league_id uuid;
    v_award_avatar_id text;

    v_new_end_date timestamptz;
    v_fresh_end_date timestamptz;
    v_period_day date;

    -- proposed/20 (t4-F3): ürün düğmeleri; yoksa ya da geçersizse bugünkü kural (1).
    v_award_min_members integer := greatest(coalesce(public.app_config_int('league_award_min_members'), 1), 1);
    v_award_min_points integer := greatest(coalesce(public.app_config_int('league_award_min_points'), 1), 1);
    v_promo_min_points integer := greatest(coalesce(public.app_config_int('league_promotion_min_points'), 1), 1);

    -- Bu koşuda işlenen (ve başka lige taşınan) üyeler, taşındıkları
    -- ligin dönemi de aynı koşuda bitiyorsa ikinci kez işlenmez.
    v_processed uuid[] := '{}';
BEGIN
    -- proposed/20 (t4-F7): ensure_user_in_league'in yerleştirme kilidi; koşu
    -- sürerken yeni üye yerleşmez, oda sayıları değişmez.
    PERFORM pg_advisory_xact_lock(hashtext('pomosprint_league_room'), t) FROM generate_series(1, 5) AS t;

    -- Bu koşuda yeni açılacak odalar için: bugünden itibaren 2. Pazar 23:59 (TR saati)
    v_fresh_end_date := (date_trunc('week', ((current_timestamp AT TIME ZONE 'Europe/Istanbul') + interval '1 day')::date::timestamp) + interval '13 days' + time '23:59:59') AT TIME ZONE 'Europe/Istanbul';

    FOR v_league IN
        SELECT id, tier, end_date FROM public.leagues
        WHERE is_active = true AND end_date <= now() + interval '5 minutes'
        ORDER BY tier, start_date, id
    LOOP
        v_higher_tier := CASE WHEN v_league.tier < 5 THEN v_league.tier + 1 ELSE NULL END;
        v_lower_tier := CASE WHEN v_league.tier > 1 THEN v_league.tier - 1 ELSE NULL END;
        v_new_end_date := v_league.end_date + interval '14 days';
        IF v_new_end_date <= now() THEN
            -- cron kaçırıldıysa geçmişte kalan bir bitişe değil, sıradaki
            -- normal döneme ayarla
            v_new_end_date := v_fresh_end_date;
        END IF;
        -- proposed/20 (t4-F8): dönemin bittiği gün, TR takvimiyle (cron UTC'de çalışır).
        v_period_day := (v_league.end_date AT TIME ZONE 'Europe/Istanbul')::date;

        SELECT count(*)::integer INTO v_member_count
        FROM public.league_memberships
        WHERE league_id = v_league.id AND NOT (user_id = ANY (v_processed));

        SELECT z.promotion_zone_end, z.demotion_zone_start
        INTO v_promo_end, v_demo_start
        FROM public.get_league_zones(v_member_count) z;

        FOR v_member IN (
            SELECT lm.id AS membership_id, lm.user_id, lm.weekly_points,
                   row_number() OVER (ORDER BY lm.weekly_points DESC, lm.joined_at ASC, lm.user_id) AS rnk
            FROM public.league_memberships lm
            WHERE lm.league_id = v_league.id AND NOT (lm.user_id = ANY (v_processed))
        )
        LOOP
            v_processed := v_processed || v_member.user_id;

            -- Dönem sonu lig ödülü: puan toplamış ilk 3 (proposed/20: düğmeler)
            IF v_member.weekly_points >= v_award_min_points AND v_member_count >= v_award_min_members THEN
                v_award_avatar_id := public.league_award_avatar_id(v_league.tier, v_member.rnk::integer);
                IF v_award_avatar_id IS NOT NULL THEN
                    INSERT INTO public.avatar_unlocks (user_id, avatar_id, unlock_type, coins_spent)
                    VALUES (v_member.user_id, v_award_avatar_id, 'league_award', 0)
                    ON CONFLICT (user_id, avatar_id) DO NOTHING;
                END IF;
            END IF;

            v_target_tier := NULL;
            IF v_member.weekly_points >= v_promo_min_points AND v_member.rnk <= v_promo_end AND v_higher_tier IS NOT NULL THEN
                v_target_tier := v_higher_tier;
            ELSIF v_member.rnk >= v_demo_start AND v_lower_tier IS NOT NULL THEN
                v_target_tier := v_lower_tier;
            END IF;

            IF v_target_tier IS NOT NULL THEN
                -- proposed/20 (t4-F2): hedef oda, bir sonraki dönem sonu bu
                -- üyeninkiyle AYNI olan oda (bu koşuda işlenecek ya da işlenmiş
                -- aynı takvimli oda ya da bu koşuda açılan oda); yoksa yeni oda.
                SELECT l.id INTO v_target_league_id
                FROM public.leagues l
                LEFT JOIN public.league_memberships lm ON lm.league_id = l.id
                WHERE l.is_active = true AND l.tier = v_target_tier
                  AND CASE WHEN l.end_date > now() + interval '5 minutes' THEN l.end_date
                           WHEN l.end_date + interval '14 days' <= now() THEN v_fresh_end_date
                           ELSE l.end_date + interval '14 days' END = v_new_end_date
                GROUP BY l.id
                HAVING COUNT(lm.id) < 30
                ORDER BY l.start_date ASC, l.id
                LIMIT 1;

                IF v_target_league_id IS NULL THEN
                    INSERT INTO public.leagues (tier, end_date)
                    VALUES (v_target_tier, v_new_end_date)
                    RETURNING id INTO v_target_league_id;
                END IF;

                -- Kilit sırası profiles → league_memberships (complete_study_session ile aynı).
                UPDATE public.profiles SET league_tier = v_target_tier WHERE id = v_member.user_id;

                -- proposed/20: yeni oda sıralamasında katılım anı = taşınma anı (t4-F10);
                -- yeni dönem, bitişten sonra biten seansların puanıyla başlar (carry).
                UPDATE public.league_memberships
                SET league_id = v_target_league_id,
                    weekly_points = carry_points,
                    carry_points = 0,
                    joined_at = now()
                WHERE id = v_member.membership_id;

                IF v_target_tier = v_higher_tier THEN
                    INSERT INTO public.activity_feed (user_id, activity_type, activity_date, payload)
                    VALUES (v_member.user_id, 'league_promotion', v_period_day, jsonb_build_object('league_id', v_target_league_id, 'tier', v_higher_tier))
                    ON CONFLICT (user_id, activity_type, activity_date) DO NOTHING;
                END IF;
            ELSE
                UPDATE public.league_memberships
                SET weekly_points = carry_points,
                    carry_points = 0
                WHERE id = v_member.membership_id;
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
        -- proposed/20 (t4-F6): member_count = 0 → "henüz odada değil"; tek
        -- kişilik gerçek oda member_count = 1 döner.
        RETURN QUERY
        SELECT
            p.name, p.avatar_id, 0, v_tier, v_end_date, true, 1, 999, 0, p.id, false
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

CREATE OR REPLACE FUNCTION public.get_league_zones(p_member_count integer)
 RETURNS TABLE(promotion_zone_end integer, demotion_zone_start integer)
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF p_member_count < 10 THEN
        promotion_zone_end := LEAST(3, GREATEST(1, ceil(GREATEST(p_member_count, 1) / 2.0)::integer));
        demotion_zone_start := 999; -- düşme yok
    ELSIF p_member_count < 20 THEN
        promotion_zone_end := 3;
        demotion_zone_start := GREATEST(p_member_count - 2, 4); -- son 3
    ELSE
        promotion_zone_end := 7;
        demotion_zone_start := GREATEST(p_member_count - 6, 8); -- son 7
    END IF;

    RETURN NEXT;
END;
$function$;

CREATE OR REPLACE FUNCTION public.complete_study_session(p_client_uuid uuid, p_category_id uuid, p_duration_minutes integer, p_was_paused boolean, p_is_verified integer, p_started_at timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid;
    v_base_points integer;
    v_bonus_points integer := 0;
    v_total_points integer;
    v_coins_earned integer := 20;
    v_current_streak integer;
    v_longest_streak integer;
    v_last_study_date date;
    v_user_tz text;
    v_study_day date;
    v_bonus_pct integer := 0;
    v_session_id uuid;
    v_daily_sessions integer;
    v_daily_limit_reached boolean := false;
    v_daily_minutes integer;
    v_top_category text;
    v_existing RECORD;
    v_ends_at timestamptz;
    v_is_late_session boolean := false;
    v_show_in_social_feed boolean;
    -- proposed/13
    v_started_at timestamptz;
    v_server_started_at timestamptz;
    v_start_verified boolean := false;
    v_unverified_cap integer;
    v_unverified_sessions integer;
    v_unverified_limit_reached boolean := false;
    v_period_start timestamptz;
    v_league_period_closed boolean := false;
    v_league_points integer := 0;
    -- proposed/21
    v_bonus_streak integer;
    v_membership_id uuid;
    v_league_end timestamptz;
    v_league_points_next_period boolean := false;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

    -- proposed/21 (t1-01): kullanıcı başına kilit EN BAŞTA. Aynı hesabın iki
    -- cihazdan eşzamanlı gönderdiği seanslar sırayla işlenir; tekrar
    -- (client_uuid) ve çakışma denetimleri öteki işlemin kaydını görür. Aynı
    -- client_uuid yarışı 23505 yerine duplicate:true döner.
    PERFORM 1 FROM public.profiles WHERE id = v_uid FOR UPDATE;

    -- 1. IDEMPOTENCY CHECK (client_uuid)
    SELECT * INTO v_existing FROM public.study_sessions
    WHERE client_uuid = p_client_uuid AND user_id = v_uid LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'base_points', v_existing.base_points,
            'bonus_points', v_existing.bonus_points,
            'total_points', v_existing.base_points + v_existing.bonus_points,
            'coins_earned', 0,
            'streak', (SELECT current_streak FROM public.profiles WHERE id = v_uid),
            'bonus_pct', 0,
            'duplicate', true,
            'daily_limit_reached', false
        );
    END IF;

    -- 2. VALIDATION
    IF p_duration_minutes NOT IN (25, 50) THEN
        RAISE EXCEPTION 'invalid duration: only 25 or 50 allowed';
    END IF;

    -- 2a. proposed/13 (UX-01): sunucu başlangıç kaydı. Aynı client_uuid ve
    -- süreyle kayıt var VE süre sunucu saatine göre dolmuşsa (60 sn pay)
    -- seans doğrulanmıştır; başlangıç sunucudan alınır (completed_at now()'u
    -- geçmesin diye en geç now() - süre). Aksi halde istemcinin
    -- p_started_at'i bugünkü kurallarla değerlendirilir.
    SELECT s.server_started_at INTO v_server_started_at
      FROM public.session_starts s
     WHERE s.user_id = v_uid
       AND s.client_uuid = p_client_uuid
       AND s.duration_minutes = p_duration_minutes;

    IF v_server_started_at IS NOT NULL
       AND now() >= v_server_started_at + make_interval(mins => p_duration_minutes) - interval '60 seconds' THEN
        v_start_verified := true;
        v_started_at := least(v_server_started_at, now() - make_interval(mins => p_duration_minutes));
    ELSE
        v_started_at := p_started_at;
    END IF;

    IF v_started_at IS NULL OR v_started_at > now() THEN
        RAISE EXCEPTION 'started_at cannot be in the future';
    END IF;

    IF v_started_at < now() - interval '24 hours' THEN
        RAISE EXCEPTION 'started_at is older than 24 hours';
    END IF;

    v_ends_at := v_started_at + make_interval(mins => p_duration_minutes);

    -- Seans gerçekten bitmiş olmalı (küçük saat sapması toleransı: 5 dk).
    IF v_ends_at > now() + interval '5 minutes' THEN
        RAISE EXCEPTION 'session_not_finished';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.categories
        WHERE id = p_category_id AND user_id = v_uid
    ) THEN
        RAISE EXCEPTION 'category does not belong to this user';
    END IF;

    -- 3. ÇAKIŞMA: gerçek zaman aralığıyla (completed_at = gerçek bitiş)
    IF EXISTS (
        SELECT 1 FROM public.study_sessions s
        WHERE s.user_id = v_uid
          AND s.started_at IS NOT NULL
          AND s.started_at < v_ends_at
          AND s.completed_at > v_started_at
    ) THEN
        RETURN jsonb_build_object('error', 'overlap');
    END IF;

    -- 4. BASE POINTS & STREAK
    IF p_duration_minutes = 25 THEN
        v_base_points := 5;
    ELSE
        v_base_points := 12;
    END IF;

    IF p_was_paused THEN
        v_base_points := v_base_points - ceil(v_base_points * 0.20);
    END IF;

    SELECT COALESCE(current_streak, 0), longest_streak, last_study_date,
           COALESCE(timezone, 'Europe/Istanbul'), show_in_social_feed
    INTO v_current_streak, v_longest_streak, v_last_study_date, v_user_tz, v_show_in_social_feed
    FROM public.profiles
    WHERE id = v_uid
    FOR UPDATE;

    v_study_day := ((v_started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date;

    IF v_last_study_date IS NOT NULL AND v_study_day < v_last_study_date THEN
        -- Çevrimdışı kuyruktan geç gelen eski seans: seriyi ve son
        -- çalışma gününü geri almaz.
        v_is_late_session := true;
    ELSIF v_last_study_date IS NULL THEN
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

    -- 5. DAILY CEILING CHECK (16 seans) — lig puanı + lifetime_points + kum
    SELECT count(*) INTO v_daily_sessions
    FROM public.study_sessions
    WHERE user_id = v_uid
      AND ((started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date = v_study_day;

    IF v_daily_sessions >= 16 THEN
        v_daily_limit_reached := true;
    END IF;

    -- 5b. proposed/13 (UX-01): doğrulanmamış seans tavanı. null = kapalı.
    IF NOT v_start_verified THEN
        v_unverified_cap := public.app_config_int('unverified_session_daily_cap');
        IF v_unverified_cap IS NOT NULL THEN
            SELECT count(*) INTO v_unverified_sessions
            FROM public.study_sessions
            WHERE user_id = v_uid
              AND start_verified IS FALSE
              AND ((started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date = v_study_day;

            IF v_unverified_sessions >= greatest(v_unverified_cap, 0) THEN
                v_unverified_limit_reached := true;
            END IF;
        END IF;
    END IF;

    -- 6. STREAK BONUS
    -- proposed/21 (t1-05): geç gelen (önceki güne ait) seans kendi gününün
    -- serisiyle ödüllendirilir: bugünkü seri o günden bu yana kesintisizse
    -- seri - gün farkı, değilse 1 (bonus yok). Seri ve last_study_date
    -- değişmez (13'teki gibi); yanıttaki 'streak' bugünkü seridir.
    IF v_is_late_session THEN
        v_bonus_streak := greatest(1, v_current_streak - (v_last_study_date - v_study_day));
    ELSE
        v_bonus_streak := v_current_streak;
    END IF;

    IF v_bonus_streak >= 14 THEN
        v_bonus_pct := 30;
    ELSIF v_bonus_streak >= 7 THEN
        v_bonus_pct := 20;
    ELSIF v_bonus_streak >= 3 THEN
        v_bonus_pct := 10;
    ELSE
        v_bonus_pct := 0;
    END IF;

    v_bonus_points := ceil(v_base_points::numeric * v_bonus_pct / 100.0);
    v_total_points := v_base_points + v_bonus_points;

    IF v_daily_limit_reached OR v_unverified_limit_reached THEN
        v_base_points := 0;
        v_bonus_points := 0;
        v_total_points := 0;
        v_coins_earned := 0;
    END IF;

    -- 7. UPDATE PROFILES
    UPDATE public.profiles
    SET total_minutes = COALESCE(total_minutes, 0) + p_duration_minutes,
        lifetime_points = lifetime_points + v_total_points,
        coins = coins + v_coins_earned,
        current_streak = v_current_streak,
        longest_streak = v_longest_streak,
        last_study_date = CASE WHEN v_is_late_session THEN last_study_date ELSE v_study_day END
    WHERE id = v_uid;

    -- 8. LEAGUE POINTS — proposed/13: kapanmış döneme ait seans lig puanı almaz.
    IF NOT v_daily_limit_reached AND NOT v_unverified_limit_reached THEN
        SELECT COALESCE(lm.period_started_at, l.end_date - interval '14 days'), lm.id, l.end_date
          INTO v_period_start, v_membership_id, v_league_end
          FROM public.league_memberships lm
          JOIN public.leagues l ON l.id = lm.league_id
         WHERE lm.user_id = v_uid AND l.is_active = true
         LIMIT 1;

        IF v_period_start IS NOT NULL AND v_ends_at <= v_period_start THEN
            v_league_period_closed := true;
        ELSIF v_membership_id IS NOT NULL AND v_ends_at > v_league_end THEN
            -- proposed/21 (t4-F5): oda bitti ama dönem sonu henüz işlenmedi
            -- (Pazar 23:59:59 TR ile cron arası ya da kaçan cron) ve seans
            -- bitişten SONRA bitti: puan sıradaki döneme (carry_points, 20).
            UPDATE public.league_memberships
               SET carry_points = carry_points + v_total_points
             WHERE id = v_membership_id;
            v_league_points := v_total_points;
            v_league_points_next_period := true;
        ELSE
            PERFORM public.ensure_user_in_league(v_uid, v_total_points);
            v_league_points := v_total_points;
        END IF;
    END IF;

    -- 9. INSERT STUDY SESSION (completed_at = gerçek bitiş)
    INSERT INTO public.study_sessions (
        user_id, category, category_id, duration_minutes,
        base_points, bonus_points, was_paused, is_verified,
        client_uuid, started_at, completed_at, start_verified
    ) VALUES (
        v_uid,
        (SELECT name FROM public.categories WHERE id = p_category_id),
        p_category_id, p_duration_minutes,
        v_base_points, v_bonus_points, p_was_paused, p_is_verified,
        p_client_uuid, v_started_at, v_ends_at, v_start_verified
    )
    RETURNING id INTO v_session_id;

    -- proposed/13: kullanılan başlangıç kaydı artık gereksiz.
    DELETE FROM public.session_starts
     WHERE user_id = v_uid AND client_uuid = p_client_uuid;

    -- 10. ACTIVITY FEED
    IF v_show_in_social_feed THEN
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

        IF NOT v_is_late_session
           AND v_current_streak IN (7, 14, 30, 60, 100)
           AND v_last_study_date IS DISTINCT FROM v_study_day THEN
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

    -- 11. RETURN RESULT
    RETURN jsonb_build_object(
        'base_points', v_base_points,
        'bonus_points', v_bonus_points,
        'total_points', v_total_points,
        'coins_earned', v_coins_earned,
        'streak', v_current_streak,
        'bonus_pct', v_bonus_pct,
        'duplicate', false,
        'daily_limit_reached', v_daily_limit_reached,
        'start_verified', v_start_verified,
        'unverified_limit_reached', v_unverified_limit_reached,
        'league_points', v_league_points,
        'league_period_closed', v_league_period_closed,
        'league_points_next_period', v_league_points_next_period
    );
END;
$function$;

-- END BASELINE FUNCTIONS
-- Mevcut üyelerin oda/katılım sınırlarını geri koy; puan/kum/seans verileri kalır.
DO $restore$
DECLARE v_snapshot jsonb;
BEGIN
 SELECT rollback_snapshot INTO STRICT v_snapshot FROM public.league_competition_state WHERE singleton;
 UPDATE public.leagues l SET tier=b.tier,start_date=b.start_date,end_date=b.end_date,is_active=b.is_active
 FROM jsonb_to_recordset(v_snapshot->'leagues') b(id uuid,tier integer,start_date timestamptz,end_date timestamptz,is_active boolean)
 WHERE l.id=b.id;
 UPDATE public.league_memberships m SET league_id=b.league_id,joined_at=b.joined_at
 FROM jsonb_to_recordset(v_snapshot->'memberships') b(id uuid,league_id uuid,joined_at timestamptz)
 WHERE m.id=b.id;
 -- Eski BEFORE UPDATE OF league_id trigger'ından SONRA önceki sınırı koy.
 UPDATE public.league_memberships m SET period_started_at=b.period_started_at
 FROM jsonb_to_recordset(v_snapshot->'memberships') b(id uuid,period_started_at timestamptz)
 WHERE m.id=b.id;
 DELETE FROM public.leagues l WHERE NOT EXISTS(SELECT 1 FROM jsonb_to_recordset(v_snapshot->'leagues') b(id uuid) WHERE b.id=l.id)
  AND NOT EXISTS(SELECT 1 FROM public.league_memberships m WHERE m.league_id=l.id);
 DELETE FROM public.app_config WHERE key IN
  ('league_room_capacity','league_launch_min_active_users','league_promotion_min_active_members',
   'league_qualification_min_days','league_qualification_min_minutes','league_award_min_members',
   'league_award_min_points','league_promotion_min_points');
 INSERT INTO public.app_config SELECT * FROM jsonb_populate_recordset(NULL::public.app_config,v_snapshot->'config');
END $restore$;
DROP FUNCTION public._league_ranking_rows(uuid);
DROP FUNCTION public._league_place_member(uuid,integer);
DROP FUNCTION public._league_repack(timestamptz,timestamptz,boolean);
DROP FUNCTION public._league_period_activity(timestamptz,timestamptz);
DROP FUNCTION public._league_after_completed_session();
DROP FUNCTION public._league_refresh_start();
DROP FUNCTION public._league_grid_start(timestamptz);
DROP FUNCTION public._league_policy_int(text,integer,integer,integer);
DROP TABLE public.league_competition_state;
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261008190000';
NOTIFY pgrst,'reload schema';
COMMIT;
