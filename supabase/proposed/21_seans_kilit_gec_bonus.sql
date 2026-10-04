-- ============================================================================
-- ÖNERİ 21: SEANS KİLİDİ, GEÇ SEANS BONUSU, DÖNEM ARASI LİG PUANI   ÖNCELİK: P1
-- ============================================================================
-- Test ajanı bulguları (5 Ekim 2026, yerel kopyada yeniden üretildi:
-- supabase/tests/proposed_20_25_race_local.sh ve
-- proposed_20_25_bulgu_repro_local.sql):
--  t1-01  (medium) Eşzamanlı gelen çakışan seansların ikisi de kabul
--         ediliyor: çakışma denetimi profil kilidinden ÖNCE çalışıyor; puan,
--         kum, lig ve dakika iki kat. Aynı hesapla iki cihazda (telefon +
--         tablet) aynı anda biten seanslar. Aynı client_uuid yarışı 23505
--         ile düşüyor (duplicate:true yerine).
--  t1-05  Geç gelen (önceki güne ait) seans BUGÜNKÜ serinin bonusunu alıyor.
--         ÜRÜN KARARI: burada "o günün serisi" seçildi (bugünkü seri o günden
--         bu yana kesintisizse seri - gün farkı, değilse 1); alternatif "geç
--         seansa bonus yok" için v_bonus_streak := 1 yazın. Kural metni
--         (get_points_config, league_info_sheet) değişmez: seri bonusu
--         seansın ait olduğu günün serisine göre.
--  t4-F5  Oda bitişi (Pazar 23:59:59 TR) ile cron (Pazartesi 00:01 TR)
--         arasında, oda bitişinden SONRA biten seansın lig puanı eski odaya
--         yazılıyor. Artık carry_points'e (20) yazılır; process_weekly_leagues
--         yeni dönemi onunla başlatır.
--
-- SIRA: 20'den SONRA (carry_points kolonu 20'de). Gövde zincir uygulanmış
-- hâldeki complete_study_session'dan (= proposed/13 gövdesi) türetildi;
-- "proposed/21" yorumlu satırlar dışında birebir aynı. İlk adım md5'i denetler.
--
-- DEĞİŞİKLİKLER (complete_study_session)
--  1. Kimlik denetiminden hemen sonra PERFORM ... FROM profiles WHERE id =
--     v_uid FOR UPDATE: tekrar (client_uuid), doğrulama, çakışma ve yazma
--     kullanıcı başına sıralı. Bekleyen işlem kilidi alınca öteki işlemin
--     COMMIT ettiği seansı görür: çakışan seans {error:'overlap'}, aynı
--     client_uuid {duplicate:true}. (İstenirse ek güvence: btree_gist +
--     EXCLUDE USING gist (user_id WITH =, tstzrange(started_at, completed_at)
--     WITH &&); önce mevcut çakışan satırlar temizlenmeli; bu dosyada YOK.)
--  6. Seri bonusu, geç seansta o günün serisiyle (v_bonus_streak).
--  8. Üyeliğin odası bitmiş (end_date < seans bitişi) ama işlenmemişse puan
--     carry_points'e; yanıtta league_points_next_period = true.
--  11. Yanıta league_points_next_period (bool) EKLENİR; diğer anahtarlar,
--     hata metinleri ve imza aynı (classifySessionError değişmez).
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- ADIMLAR (SQL Editor, kullanıcı çalıştırır; 20'den SONRA)
--  1. supabase/tests/proposed_21_seans_kilit_gec_bonus_dryrun.sql → sonda
--     DRYRUN_RESULT; her madde 'true'.
--  2. Bu dosya \echo/\quit satırları silinerek (geçmişe 20261005121000
--     seans_kilit_gec_bonus). Birkaç saniye profiles kilitlenir.
--  3. Eşzamanlılık yerelde: supabase/tests/proposed_20_25_race_local.sh
--     (iki bağlantılı senaryolar; SQL Editor'de sınanamaz).
--  4. Geri alma: 21_seans_kilit_gec_bonus_down.sql (13'ün gövdesine döner).
-- ============================================================================

\echo 'supabase/proposed/21: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

-- ---------------------------------------------------------------------------
-- 0) Ön koşul: 20 uygulanmış, complete_study_session zincirdeki (13) hâlinde
-- ---------------------------------------------------------------------------
DO $pre$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = 'league_memberships'
                      AND column_name = 'carry_points') THEN
        RAISE EXCEPTION 'proposed/21 ön koşulu: önce proposed/20_lig_donemi.sql uygulanmalı.';
    END IF;
    IF md5(pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamp with time zone)'::regprocedure))
       IS DISTINCT FROM '727180a06df013420417885367ab0ee1' THEN
        RAISE EXCEPTION 'proposed/21 ön koşulu: canlı tanım beklenenden farklı: complete_study_session (proposed/13 uygulanmış gövde bekleniyor). Dosyayı yeni gövdeye uyarlayın.';
    END IF;
END
$pre$;

-- ---------------------------------------------------------------------------
-- 1) complete_study_session: proposed/13 gövdesi + kilit + geç seans bonusu
--    + dönem arası lig puanı
-- ---------------------------------------------------------------------------
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

REVOKE ALL ON FUNCTION public.complete_study_session(uuid, uuid, integer, boolean, integer, timestamp with time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_study_session(uuid, uuid, integer, boolean, integer, timestamp with time zone) TO authenticated, service_role;

DO $$
BEGIN
    INSERT INTO supabase_migrations.schema_migrations (version, name)
    VALUES ('20261005121000', 'seans_kilit_gec_bonus')
    ON CONFLICT (version) DO NOTHING;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişine yazılamadı: %', SQLERRM;
END $$;

COMMIT;
