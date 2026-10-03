-- ============================================================================
-- KURU ÇALIŞTIRMA (canlıda hiçbir şeyi kalıcı DEĞİŞTİRMEZ)
-- Supabase Dashboard > SQL Editor'e yapıştırıp Run'a basın.
-- Migration + 28 senaryo sentetik kullanıcılarla çalışır, en sonda bilinçli
-- bir hata (DRYRUN_RESULT) fırlatılır ve tüm işlem geri alınır.
-- Hata mesajındaki her satırın sonu 'true' olmalı.
-- ============================================================================
BEGIN;
-- ============================================================================
-- 20261003150000_live_audit_fixes
-- Canlı veritabanının 3 Ekim 2026 denetiminde bulunan hataların düzeltmesi.
-- Tüm fonksiyon gövdeleri CANLI tanımlar (pg_get_functiondef) esas alınarak
-- yazıldı; repodaki eski migration sürümlerinden değil.
--
-- Kapsam:
--  1. profiles: istemcinin coins/lifetime_points/is_premium/league_tier/seri
--     alanlarını doğrudan yazabilmesi kapatıldı (kolon bazlı yetki).
--  2. complete_study_session: completed_at artık seansın gerçek bitişi
--     (started_at + süre); çakışma kontrolü gerçek aralıkla yapılıyor
--     (çevrimdışı kuyruktaki 2.+ seanslar artık reddedilmiyor); bitmemiş
--     seans reddediliyor; geç gelen eski seans seriyi bozmuyor.
--  3. Lig: get_my_league_ranking eklendi (istemci bunu çağırıyor, canlıda
--     yoktu); get_league_ranking yalnızca kendi ligini döndürüyor; 0 puanla
--     terfi/ödül yok; deterministik sıralama; aynı koşuda taşınan üyeler
--     ikinci kez işlenmiyor; küçük liglerde terfi kotası; cron bir hafta
--     geç çalışıyordu (20:59:00 < 20:59:59) — düzeltildi.
--  4. Arkadaşlar: get_my_friends / get_incoming_friend_requests eklendi
--     (istemci başkalarının profillerini RLS yüzünden okuyamıyordu);
--     get_live_friends her arkadaşı iki kez döndürüyordu.
--  5. Herkese açık sıralamalar: is_me eklendi, oturumsuz (web) çağrıda
--     isim maskeleniyor, ay sınırı Türkiye saatine göre.
--  6. Yeni kullanıcıya ücretli avatar takılması; avatar_id sanitize.
--  7. Anon rolünün oturum gerektiren RPC'leri çağırma yetkisi kaldırıldı;
--     tablolardaki gereksiz yazma yetkileri kaldırıldı.
--  8. Arşivden çıkarma kategori limitini atlıyordu.
--  9. timezone doğrulaması, CHECK kısıtları, indeksler.
-- 10. marketing_subscribers: abonelikten çıkma token'ı ve hoş geldin
--     e-postası tekrar koruması.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1) PROFILES YETKİLERİ
-- ---------------------------------------------------------------------------
REVOKE ALL ON public.profiles FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.profiles FROM authenticated;
GRANT SELECT ON public.profiles TO authenticated;
GRANT INSERT (id, email, name, avatar_id) ON public.profiles TO authenticated;
GRANT UPDATE (name, show_in_social_feed, user_segment, daily_goal_minutes,
              birth_year, onboarding_completed_at, timezone)
  ON public.profiles TO authenticated;

-- İstemci doğrudan profil oluşturursa (normalde handle_new_user yapar)
-- yalnızca varsayılan bir avatar takabilir.
CREATE OR REPLACE FUNCTION public.sanitize_profile_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF current_user IN ('authenticated', 'anon') THEN
        IF NEW.avatar_id IS NULL OR NOT EXISTS (
            SELECT 1 FROM public.avatars a
            WHERE a.id = NEW.avatar_id AND a.is_default AND a.is_active
        ) THEN
            NEW.avatar_id := 'avatar_16_basic';
        END IF;
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS sanitize_profile_insert ON public.profiles;
CREATE TRIGGER sanitize_profile_insert
  BEFORE INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sanitize_profile_insert();

-- Geçersiz saat dilimi complete_study_session'ı (AT TIME ZONE) kırar.
CREATE OR REPLACE FUNCTION public.validate_profile_timezone()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF NEW.timezone IS NULL
       OR NOT EXISTS (SELECT 1 FROM pg_timezone_names t WHERE t.name = NEW.timezone) THEN
        RAISE EXCEPTION 'invalid timezone: %', NEW.timezone USING ERRCODE = '22023';
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS validate_profile_timezone ON public.profiles;
CREATE TRIGGER validate_profile_timezone
  BEFORE INSERT OR UPDATE OF timezone ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.validate_profile_timezone();

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_name_length_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_name_length_check
  CHECK (char_length(btrim(name)) BETWEEN 1 AND 50);
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_daily_goal_range_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_daily_goal_range_check
  CHECK (daily_goal_minutes IS NULL OR daily_goal_minutes BETWEEN 5 AND 1440);
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_birth_year_range_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_birth_year_range_check
  CHECK (birth_year IS NULL OR birth_year BETWEEN 1900 AND 2100);

-- ---------------------------------------------------------------------------
-- 2) TABLO YETKİLERİ (RLS'e ek savunma katmanı)
-- ---------------------------------------------------------------------------
REVOKE ALL ON public.study_sessions, public.categories, public.friendships,
              public.leagues, public.league_memberships, public.avatar_unlocks,
              public.activity_feed, public.marketing_subscribers
  FROM anon;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON
  public.study_sessions, public.friendships, public.leagues,
  public.league_memberships, public.avatar_unlocks, public.activity_feed
  FROM authenticated;
GRANT SELECT ON public.study_sessions, public.friendships, public.leagues,
                public.league_memberships, public.avatar_unlocks,
                public.activity_feed
  TO authenticated;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.categories, public.marketing_subscribers FROM authenticated;
-- Abonelik satırlarını yalnızca handle_newsletter_subscription trigger'ı
-- ekler; istemci başka bir adresi ekleyip hoş geldin e-postası
-- tetikleyemesin. Kullanıcı kendi aboneliğini görebilir ve silebilir.
REVOKE INSERT, UPDATE ON public.marketing_subscribers FROM authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.avatars FROM anon, authenticated;
GRANT SELECT ON public.avatars TO anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3) KATEGORİ LİMİTİ: arşivden çıkarma da limite tabi
-- ---------------------------------------------------------------------------
DROP TRIGGER IF EXISTS enforce_category_limit_on_unarchive ON public.categories;
CREATE TRIGGER enforce_category_limit_on_unarchive
  BEFORE UPDATE OF is_archived ON public.categories
  FOR EACH ROW WHEN (OLD.is_archived AND NOT NEW.is_archived)
  EXECUTE FUNCTION public.enforce_category_limit();

-- ---------------------------------------------------------------------------
-- 4) SEANS KAYDI
-- ---------------------------------------------------------------------------
-- Mevcut kayıtlarda completed_at senkron anıydı; gerçek bitişe çek.
UPDATE public.study_sessions
   SET completed_at = started_at + make_interval(mins => duration_minutes)
 WHERE started_at IS NOT NULL
   AND completed_at IS DISTINCT FROM started_at + make_interval(mins => duration_minutes);

CREATE INDEX IF NOT EXISTS idx_study_sessions_user_started
  ON public.study_sessions (user_id, started_at);
CREATE INDEX IF NOT EXISTS idx_study_sessions_completed_at
  ON public.study_sessions (completed_at);

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
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

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

    IF p_started_at IS NULL OR p_started_at > now() THEN
        RAISE EXCEPTION 'started_at cannot be in the future';
    END IF;

    IF p_started_at < now() - interval '24 hours' THEN
        RAISE EXCEPTION 'started_at is older than 24 hours';
    END IF;

    v_ends_at := p_started_at + make_interval(mins => p_duration_minutes);

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
          AND s.completed_at > p_started_at
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

    v_study_day := ((p_started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date;

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

    -- 6. STREAK BONUS
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

    IF v_daily_limit_reached THEN
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

    -- 8. LEAGUE POINTS
    IF NOT v_daily_limit_reached THEN
        PERFORM public.ensure_user_in_league(v_uid, v_total_points);
    END IF;

    -- 9. INSERT STUDY SESSION (completed_at = gerçek bitiş)
    INSERT INTO public.study_sessions (
        user_id, category, category_id, duration_minutes,
        base_points, bonus_points, was_paused, is_verified,
        client_uuid, started_at, completed_at
    ) VALUES (
        v_uid,
        (SELECT name FROM public.categories WHERE id = p_category_id),
        p_category_id, p_duration_minutes,
        v_base_points, v_bonus_points, p_was_paused, p_is_verified,
        p_client_uuid, p_started_at, v_ends_at
    )
    RETURNING id INTO v_session_id;

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
        'daily_limit_reached', v_daily_limit_reached
    );
END;
$function$;

-- ---------------------------------------------------------------------------
-- 5) LİG
-- ---------------------------------------------------------------------------
-- Küçük liglerde (10'dan az üye) en fazla üyelerin yarısı terfi eder.
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

CREATE OR REPLACE FUNCTION public.get_league_ranking(p_user_id uuid)
 RETURNS TABLE(name text, avatar_id text, weekly_points integer, tier integer, end_date timestamp with time zone, is_me boolean, promotion_zone_end integer, demotion_zone_start integer, member_count integer)
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
        SELECT league_tier INTO v_tier FROM public.profiles WHERE id = p_user_id;
        -- ensure_user_in_league ile aynı 14 günlük dönem sonu
        v_end_date := ((date_trunc('week', (current_timestamp AT TIME ZONE 'Europe/Istanbul')::date::timestamp) + interval '13 days') + time '23:59:59') AT TIME ZONE 'Europe/Istanbul';
        RETURN QUERY
        SELECT
            p.name, p.avatar_id, 0, v_tier, v_end_date, true, 1, 999, 1
        FROM public.profiles p WHERE p.id = p_user_id;
        RETURN;
    END IF;

    SELECT count(*) INTO v_member_count FROM public.league_memberships WHERE league_id = v_league_id;

    SELECT z.promotion_zone_end, z.demotion_zone_start
    INTO v_promo_end, v_demo_start
    FROM public.get_league_zones(v_member_count) z;

    -- İlk 3'teki (ve puanı olan) üyeler bu ekranda lig ödülü avatarıyla
    -- görünür; profiles.avatar_id'ye dokunulmaz. Sıralama, dönem sonu
    -- işlemiyle (process_weekly_leagues) birebir aynı kuraldır.
    RETURN QUERY
    SELECT
        p.name,
        COALESCE(
            CASE WHEN ranked.weekly_points > 0
                 THEN public.league_award_avatar_id(v_tier, ranked.rnk::integer) END,
            p.avatar_id) AS avatar_id,
        ranked.weekly_points,
        v_tier,
        v_end_date,
        (ranked.user_id = p_user_id),
        v_promo_end,
        v_demo_start,
        v_member_count
    FROM (
        SELECT lm.user_id, lm.weekly_points, lm.joined_at,
               row_number() OVER (ORDER BY lm.weekly_points DESC, lm.joined_at ASC, lm.user_id) AS rnk
        FROM public.league_memberships lm
        WHERE lm.league_id = v_league_id
    ) ranked
    JOIN public.profiles p ON p.id = ranked.user_id
    ORDER BY ranked.rnk ASC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_league_ranking()
 RETURNS TABLE(name text, avatar_id text, weekly_points integer, tier integer, end_date timestamp with time zone, is_me boolean, promotion_zone_end integer, demotion_zone_start integer, member_count integer)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT r.name, r.avatar_id, r.weekly_points, r.tier, r.end_date,
           r.is_me, r.promotion_zone_end, r.demotion_zone_start, r.member_count
    FROM public.get_league_ranking(auth.uid()) AS r
    WHERE auth.uid() IS NOT NULL;
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

-- Dönemler Pazar 23:59:59 (TR) = 20:59:59 UTC'de bitiyor; iş 20:59:00'da
-- çalıştığı için her dönem bir hafta geç işleniyordu. 21:01 UTC'ye al.
SELECT cron.schedule('weekly_leagues_job', '1 21 * * 0', 'SELECT public.process_weekly_leagues()');

-- ---------------------------------------------------------------------------
-- 6) ARKADAŞLAR
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_live_friends()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_result jsonb;
BEGIN
    IF v_uid IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    -- Kabul edilen arkadaşlıklar iki yönlü satırla tutuluyor; önceki
    -- OR-join her arkadaşı iki kez döndürüyordu.
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'name', p.name,
            'avatar_id', p.avatar_id,
            'category_name', p.active_session_category_name,
            'ends_at', p.active_session_ends_at
        ) ORDER BY p.active_session_ends_at
    ), '[]'::jsonb)
    INTO v_result
    FROM public.profiles p
    WHERE p.id <> v_uid
      AND p.id IN (
          SELECT CASE WHEN f.user_id = v_uid THEN f.friend_id ELSE f.user_id END
          FROM public.friendships f
          WHERE f.status = 'accepted' AND (f.user_id = v_uid OR f.friend_id = v_uid)
      )
      AND p.show_in_social_feed = true
      AND p.active_session_ends_at > now();

    RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_friends()
 RETURNS TABLE(id uuid, name text, avatar_id text, lifetime_points integer, total_minutes integer)
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT p.id, p.name, p.avatar_id, p.lifetime_points, COALESCE(p.total_minutes, 0)
    FROM public.profiles p
    WHERE auth.uid() IS NOT NULL
      AND p.id <> auth.uid()
      AND p.id IN (
          SELECT CASE WHEN f.user_id = auth.uid() THEN f.friend_id ELSE f.user_id END
          FROM public.friendships f
          WHERE f.status = 'accepted' AND (f.user_id = auth.uid() OR f.friend_id = auth.uid())
      )
    ORDER BY p.lifetime_points DESC, p.name;
$function$;

CREATE OR REPLACE FUNCTION public.get_incoming_friend_requests()
 RETURNS TABLE(id uuid, name text, avatar_id text, lifetime_points integer, total_minutes integer, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT p.id, p.name, p.avatar_id, p.lifetime_points, COALESCE(p.total_minutes, 0), f.created_at
    FROM public.friendships f
    JOIN public.profiles p ON p.id = f.user_id
    WHERE auth.uid() IS NOT NULL
      AND f.friend_id = auth.uid()
      AND f.status = 'pending'
    ORDER BY f.created_at DESC;
$function$;

-- ---------------------------------------------------------------------------
-- 7) HERKESE AÇIK SIRALAMALAR
-- ---------------------------------------------------------------------------
-- Oturumsuz (web sitesi) çağrıda tam ad yerine "Ad S." gösterilir.
CREATE OR REPLACE FUNCTION public.mask_public_name(p_name text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT CASE
        WHEN p_name IS NULL OR btrim(p_name) = '' THEN NULL
        WHEN array_length(regexp_split_to_array(btrim(p_name), '\s+'), 1) = 1 THEN btrim(p_name)
        ELSE (regexp_split_to_array(btrim(p_name), '\s+'))[1] || ' '
             || upper(left((regexp_split_to_array(btrim(p_name), '\s+'))[2], 1)) || '.'
    END;
$function$;

DROP FUNCTION IF EXISTS public.get_public_monthly_leaderboard(integer);
CREATE FUNCTION public.get_public_monthly_leaderboard(p_limit integer DEFAULT 10)
 RETURNS TABLE(name text, avatar_id text, total_points integer, total_minutes integer, is_me boolean)
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT
        CASE WHEN auth.uid() IS NULL THEN public.mask_public_name(p.name) ELSE p.name END,
        p.avatar_id,
        SUM(ss.base_points + ss.bonus_points)::integer AS total_points,
        SUM(ss.duration_minutes)::integer AS total_minutes,
        COALESCE(p.id = auth.uid(), false) AS is_me
    FROM public.study_sessions ss
    JOIN public.profiles p ON p.id = ss.user_id
    WHERE ss.completed_at >= (date_trunc('month', now() AT TIME ZONE 'Europe/Istanbul') AT TIME ZONE 'Europe/Istanbul')
      AND p.show_in_social_feed = true
    GROUP BY p.id, p.name, p.avatar_id
    ORDER BY 3 DESC, 4 DESC, p.id
    LIMIT LEAST(GREATEST(p_limit, 0), 100);
$function$;

DROP FUNCTION IF EXISTS public.get_public_alltime_leaderboard(integer);
CREATE FUNCTION public.get_public_alltime_leaderboard(p_limit integer DEFAULT 50)
 RETURNS TABLE(name text, avatar_id text, total_minutes integer, lifetime_points integer, is_premium boolean, is_me boolean)
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT
        CASE WHEN auth.uid() IS NULL THEN public.mask_public_name(p.name) ELSE p.name END,
        p.avatar_id,
        COALESCE(p.total_minutes, 0),
        p.lifetime_points,
        COALESCE(p.is_premium, false),
        COALESCE(p.id = auth.uid(), false) AS is_me
    FROM public.profiles p
    WHERE p.show_in_social_feed = true
    ORDER BY p.lifetime_points DESC, COALESCE(p.total_minutes, 0) DESC, p.id
    LIMIT LEAST(GREATEST(p_limit, 0), 100);
$function$;

-- ---------------------------------------------------------------------------
-- 8) YENİ KULLANICI / AVATAR
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.profiles (id, name, email, avatar_id, total_minutes, lifetime_points, friend_code)
  values (
    new.id,
    left(coalesce(nullif(btrim(new.raw_user_meta_data->>'name'), ''),
                  nullif(btrim(new.raw_user_meta_data->>'full_name'), ''),
                  split_part(new.email, '@', 1)), 50),
    new.email,
    -- Yalnızca varsayılan (ücretsiz) avatarlar kayıtta seçilebilir;
    -- önceden 200 kumluk avatar_1_gamer bedava takılıyordu.
    coalesce(
      (select a.id from public.avatars a
        where a.id = new.raw_user_meta_data->>'avatar_id' and a.is_default and a.is_active),
      'avatar_16_basic'),
    0,
    0,
    upper(substr(replace(gen_random_uuid()::text,'-',''),1,6))
  )
  on conflict (id) do update set
    email = excluded.email,
    name = coalesce(excluded.name, public.profiles.name);
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.give_default_avatars()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    INSERT INTO public.avatar_unlocks (user_id, avatar_id, unlock_type, coins_spent)
    SELECT NEW.id, a.id, 'default', 0
    FROM public.avatars a
    WHERE a.is_default = true AND a.is_active = true
    ON CONFLICT (user_id, avatar_id) DO NOTHING;

    RETURN NEW;
END;
$function$;

-- Sahip olmadığı avatarı takılı olan mevcut kullanıcılar (eski hatadan)
-- o avatarı korur.
INSERT INTO public.avatar_unlocks (user_id, avatar_id, unlock_type, coins_spent)
SELECT p.id, p.avatar_id, 'default', 0
FROM public.profiles p
JOIN public.avatars a ON a.id = p.avatar_id
WHERE NOT EXISTS (
    SELECT 1 FROM public.avatar_unlocks u WHERE u.user_id = p.id AND u.avatar_id = p.avatar_id
)
ON CONFLICT (user_id, avatar_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 9) BÜLTEN: abonelikten çıkma token'ı + hoş geldin e-postası tekrar koruması
-- ---------------------------------------------------------------------------
ALTER TABLE public.marketing_subscribers
  ADD COLUMN IF NOT EXISTS unsubscribe_token uuid NOT NULL DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS welcome_sent_at timestamptz;
CREATE UNIQUE INDEX IF NOT EXISTS marketing_subscribers_unsubscribe_token_key
  ON public.marketing_subscribers (unsubscribe_token);
CREATE UNIQUE INDEX IF NOT EXISTS marketing_subscribers_email_lower_key
  ON public.marketing_subscribers (lower(email));

-- ---------------------------------------------------------------------------
-- 10) RPC ÇAĞRI YETKİLERİ
-- ---------------------------------------------------------------------------
DO $$
DECLARE
    f text;
BEGIN
    -- Oturum gerektiren RPC'ler: anon çağıramaz.
    FOREACH f IN ARRAY ARRAY[
        'add_friend_by_code(text)',
        'cancel_study_session()',
        'cleanup_unconfirmed_duplicate_identity(text)',
        'complete_study_session(uuid,uuid,integer,boolean,integer,timestamp with time zone)',
        'create_category(text,text,text)',
        'delete_own_account()',
        'get_friends_feed(integer)',
        'get_league_ranking(uuid)',
        'get_my_league_ranking()',
        'get_live_friends()',
        'get_my_league_ids()',
        'get_my_friends()',
        'get_incoming_friend_requests()',
        'purchase_avatar(text)',
        'respond_friend_request(uuid,boolean)',
        'set_equipped_avatar(text)',
        'setup_onboarding_categories(jsonb)',
        'start_study_session(integer,text)'
    ]
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon', f);
        EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO authenticated, service_role', f);
    END LOOP;

    -- Herkese açık (web sitesi de kullanıyor)
    FOREACH f IN ARRAY ARRAY[
        'get_public_monthly_leaderboard(integer)',
        'get_public_alltime_leaderboard(integer)',
        'get_points_config()',
        'get_league_zones(integer)',
        'league_award_avatar_id(integer,integer)'
    ]
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC', f);
        EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO anon, authenticated, service_role', f);
    END LOOP;

    -- Yalnızca sunucu içi
    FOREACH f IN ARRAY ARRAY[
        'mask_public_name(text)',
        'sanitize_profile_insert()',
        'validate_profile_timezone()'
    ]
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon, authenticated', f);
    END LOOP;
END $$;
DO $dry$
DECLARE
  u1 uuid := gen_random_uuid();
  u2 uuid := gen_random_uuid();
  v_cat uuid; r jsonb; v_txt text; v_int int; v_bool boolean; v_league uuid;
  res text[] := '{}';
  v_code text;
BEGIN
  -- Sentetik kullanıcılar (işlem sonunda geri alınır)
  INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
  VALUES (u1, 'dryrun1-' || u1 || '@example.invalid', '{"name":"Dry Run","avatar_id":"avatar_1_gamer"}', 'authenticated', 'authenticated'),
         (u2, 'dryrun2-' || u2 || '@example.invalid', '{"name":"Dry Two"}', 'authenticated', 'authenticated');

  SELECT avatar_id INTO v_txt FROM public.profiles WHERE id = u1;
  res := res || ('T01 ücretli avatar kayıtta reddedilir: ' || (v_txt = 'avatar_16_basic')::text);
  SELECT count(*) INTO v_int FROM public.avatar_unlocks WHERE user_id = u1;
  res := res || ('T02 varsayılan avatarlar açıldı(' || v_int || '): ' || (v_int >= 7)::text);

  SELECT friend_code INTO v_code FROM public.profiles WHERE id = u2;
  -- u1 olarak oturum
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u1, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';

  v_cat := public.create_category('Dry Test', '#FF0000', 'book');

  r := public.complete_study_session(gen_random_uuid(), v_cat, 25, false, 1500, now() - interval '2 hours');
  res := res || ('T03 1. seans kabul: ' || (NOT r ? 'error')::text || ' pts=' || coalesce(r->>'total_points','?') || ' coins=' || coalesce(r->>'coins_earned','?'));

  r := public.complete_study_session(gen_random_uuid(), v_cat, 25, false, 1500, now() - interval '1 hour');
  res := res || ('T04 kuyruktaki 2. seans (eskiden overlap) kabul: ' || (NOT r ? 'error')::text);

  r := public.complete_study_session(gen_random_uuid(), v_cat, 25, false, 1500, now() - interval '50 minutes');
  res := res || ('T05 gerçek çakışma reddedilir: ' || coalesce(((r->>'error') = 'overlap')::text, 'false'));

  BEGIN
    r := public.complete_study_session(gen_random_uuid(), v_cat, 25, false, 1500, now() - interval '5 minutes');
    res := res || 'T06 bitmemiş seans reddedilir: false'::text;
  EXCEPTION WHEN OTHERS THEN
    res := res || ('T06 bitmemiş seans reddedilir: ' || (SQLERRM = 'session_not_finished')::text);
  END;

  SELECT count(*) INTO v_int FROM public.study_sessions
   WHERE user_id = u1 AND completed_at = started_at + make_interval(mins => duration_minutes);
  res := res || ('T07 completed_at = gerçek bitiş (2 seans): ' || (v_int = 2)::text);

  BEGIN
    UPDATE public.profiles SET coins = 999999 WHERE id = u1;
    res := res || 'T08 coins doğrudan yazılamaz: false'::text;
  EXCEPTION WHEN insufficient_privilege THEN
    res := res || 'T08 coins doğrudan yazılamaz: true'::text;
  END;

  BEGIN
    UPDATE public.profiles SET lifetime_points = 999999, is_premium = true WHERE id = u1;
    res := res || 'T09 puan/premium doğrudan yazılamaz: false'::text;
  EXCEPTION WHEN insufficient_privilege THEN
    res := res || 'T09 puan/premium doğrudan yazılamaz: true'::text;
  END;

  BEGIN
    DELETE FROM public.profiles WHERE id = u1;
    res := res || 'T10 profil silinemez: false'::text;
  EXCEPTION WHEN insufficient_privilege THEN
    res := res || 'T10 profil silinemez: true'::text;
  END;

  UPDATE public.profiles SET name = 'Dry Renamed', show_in_social_feed = true, daily_goal_minutes = 90,
                             timezone = 'Europe/Berlin' WHERE id = u1;
  SELECT name INTO v_txt FROM public.profiles WHERE id = u1;
  res := res || ('T11 izinli alanlar yazılır: ' || coalesce((v_txt = 'Dry Renamed')::text, 'false'));

  BEGIN
    UPDATE public.profiles SET timezone = 'Mars/Olympus' WHERE id = u1;
    res := res || 'T12 geçersiz saat dilimi reddedilir: false'::text;
  EXCEPTION WHEN invalid_parameter_value THEN
    res := res || 'T12 geçersiz saat dilimi reddedilir: true'::text;
  END;

  SELECT count(*), bool_or(is_me) INTO v_int, v_bool FROM public.get_my_league_ranking();
  res := res || ('T13 get_my_league_ranking çalışır (' || v_int || ' satır, is_me=' || coalesce(v_bool::text, 'null') || '): ' || coalesce((v_int >= 1 AND v_bool)::text, 'false'));

  BEGIN
    PERFORM * FROM public.get_league_ranking(u2);
    res := res || 'T14 başkasının ligi okunamaz: false'::text;
  EXCEPTION WHEN OTHERS THEN
    res := res || ('T14 başkasının ligi okunamaz: ' || (SQLERRM = 'not authorized')::text);
  END;

  -- Arkadaşlık: u1 -> u2 istek
  PERFORM public.add_friend_by_code(v_code);
  -- u1 kendi profilini görür, u2'yi doğrudan göremez
  SELECT count(*) INTO v_int FROM public.profiles WHERE id = u2;
  res := res || ('T15 başka profil doğrudan okunamaz: ' || (v_int = 0)::text);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', u2, 'role', 'authenticated')::text, true);
  SELECT count(*) INTO v_int FROM public.get_incoming_friend_requests();
  res := res || ('T16 gelen istek görünür: ' || (v_int = 1)::text);
  PERFORM public.respond_friend_request(u1, true);
  SELECT count(*) INTO v_int FROM public.get_my_friends();
  res := res || ('T17 arkadaş listesi (u2 tarafı) 1 kişi: ' || (v_int = 1)::text);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', u1, 'role', 'authenticated')::text, true);
  SELECT count(*) INTO v_int FROM public.get_my_friends();
  res := res || ('T18 arkadaş listesi (u1 tarafı) 1 kişi, tekrar yok: ' || (v_int = 1)::text);

  SELECT count(*) INTO v_int FROM public.get_public_monthly_leaderboard(100) WHERE is_me;
  res := res || ('T19 aylık sıralamada is_me: ' || (v_int = 1)::text);

  BEGIN
    INSERT INTO public.marketing_subscribers (user_id, email) VALUES (u1, 'victim@example.invalid');
    res := res || 'T20 abonelik tablosuna istemci yazamaz: false'::text;
  EXCEPTION WHEN insufficient_privilege THEN
    res := res || 'T20 abonelik tablosuna istemci yazamaz: true'::text;
  END;

  EXECUTE 'RESET ROLE';

  -- anon RPC yetkileri
  SELECT has_function_privilege('anon', 'public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamp with time zone)', 'execute') INTO v_bool;
  res := res || ('T21 anon seans RPC çağıramaz: ' || (NOT v_bool)::text);
  SELECT has_function_privilege('anon', 'public.get_public_monthly_leaderboard(integer)', 'execute') INTO v_bool;
  res := res || ('T22 anon herkese açık sıralamayı çağırabilir: ' || v_bool::text);

  -- Anon (web) çağrıda isim maskelenir
  PERFORM set_config('request.jwt.claims', '', true);
  SELECT name INTO v_txt FROM public.get_public_monthly_leaderboard(100) WHERE name LIKE 'Dry R%' LIMIT 1;
  res := res || ('T23 web sıralamasında isim maskeli (' || coalesce(v_txt, 'yok') || '): ' || coalesce((v_txt = 'Dry R.')::text, 'false'));

  -- Lig dönem sonu: sentetik bitmiş lig, u1=10 puan, u2=0 puan
  INSERT INTO public.leagues (tier, end_date, start_date) VALUES (1, now() - interval '1 hour', now() - interval '15 days') RETURNING id INTO v_league;
  DELETE FROM public.league_memberships WHERE user_id IN (u1, u2);
  INSERT INTO public.league_memberships (league_id, user_id, weekly_points, joined_at)
  VALUES (v_league, u1, 10, now() - interval '10 days'), (v_league, u2, 0, now() - interval '9 days');
  UPDATE public.profiles SET league_tier = 1 WHERE id IN (u1, u2);
  PERFORM public.process_weekly_leagues();
  SELECT league_tier INTO v_int FROM public.profiles WHERE id = u1;
  res := res || ('T24 puanlı üye terfi eder: ' || (v_int = 2)::text);
  SELECT league_tier INTO v_int FROM public.profiles WHERE id = u2;
  res := res || ('T25 0 puanlı üye terfi ETMEZ: ' || (v_int = 1)::text);
  SELECT count(*) INTO v_int FROM public.avatar_unlocks WHERE user_id = u2 AND unlock_type = 'league_award';
  res := res || ('T26 0 puanlıya ödül avatarı yok: ' || (v_int = 0)::text);
  SELECT count(*) INTO v_int FROM public.avatar_unlocks WHERE user_id = u1 AND avatar_id = 'league_bronze_monthly';
  res := res || ('T27 1. olana ödül avatarı: ' || (v_int = 1)::text);

  SELECT schedule INTO v_txt FROM cron.job WHERE jobname = 'weekly_leagues_job';
  res := res || ('T28 cron 21:01 UTC: ' || (v_txt = '1 21 * * 0')::text);

  RAISE EXCEPTION 'DRYRUN_RESULT >> %', array_to_string(res, ' || ');
END
$dry$;
