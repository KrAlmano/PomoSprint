-- ============================================================================
-- GERİ ALMA: ÖNERİ 13 (sunucu bütünlüğü)
-- ============================================================================
-- 3 Ekim 2026 canlı tanımlarına döner. Fonksiyon gövdeleri canlıdan
-- (pg_get_functiondef) birebir alındı; yerel taklitte uygula → geri al
-- sonrası md5'ler canlıyla aynı çıktı (complete_study_session,
-- handle_new_user, add_friend_by_code, start_study_session, ...).
--
-- VERİ ETKİSİ (geri gelmeyenler):
--  - app_config, session_starts, friend_code_attempts, blocked_name_terms
--    tabloları ve içerikleri silinir.
--  - study_sessions.start_verified ve league_memberships.period_started_at
--    kolonları silinir (seanslar ve puanlar kalır).
--  - profiles.email auth.users'tan yeniden doldurulur (e-postası olmayan
--    hesapta '') ve NOT NULL geri gelir.
--  - Öneri uygulandığı sürede üretilen Crockford arkadaş kodları kalır
--    (geçerli kodlardır; eski add_friend_by_code onları da bulur, yalnızca
--    O/I/L eşlemesi ve tire/boşluk temizliği gider).
--  - Kapanmış döneme ait olduğu için lig puanı verilmeyen seanslar ve
--    doğrulanmamış tavana takılan seanslar geri puanlanmaz.
--  - delete_own_account'un search_path'i ('public','pg_temp') BİLEREK geri
--    alınmaz: proposed/12 de aynı ayarı yapar; zararsız hijyendir.
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ (\quit). Gerekirse
-- \echo/\quit satırları olmadan SQL Editor'de çalıştırın.
-- ============================================================================

\echo 'supabase/proposed/13_down: doğrudan çalıştırılmaz.'
\quit

BEGIN;

-- Trigger'lar
DROP TRIGGER IF EXISTS enforce_profile_name ON public.profiles;
DROP TRIGGER IF EXISTS enforce_category_name ON public.categories;
DROP TRIGGER IF EXISTS discard_profile_email ON public.profiles;
DROP TRIGGER IF EXISTS league_membership_period_start ON public.league_memberships;
DROP TRIGGER IF EXISTS league_period_rollover ON public.leagues;

-- Canlı gövdeler (3 Ekim 2026)
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

CREATE OR REPLACE FUNCTION public.add_friend_by_code(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_target record;
  v_reverse_pending boolean;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select id, name, avatar_id, lifetime_points, total_minutes
    into v_target
    from public.profiles
   where friend_code = upper(trim(p_code));

  if v_target.id is null then
    return jsonb_build_object('success', false, 'message', 'Bu kod ile bir kullanıcı bulunamadı.');
  end if;

  if v_target.id = auth.uid() then
    return jsonb_build_object('success', false, 'message', 'Kendini arkadaş olarak ekleyemezsin.');
  end if;

  if exists (select 1 from public.friendships where user_id = auth.uid() and friend_id = v_target.id and status = 'accepted') then
    return jsonb_build_object('success', false, 'message', 'Bu kullanıcı zaten arkadaşın.');
  end if;

  if exists (select 1 from public.friendships where user_id = auth.uid() and friend_id = v_target.id and status = 'pending') then
    return jsonb_build_object('success', false, 'message', 'Bu kullanıcıya zaten istek gönderdin.');
  end if;

  select exists(
    select 1 from public.friendships where user_id = v_target.id and friend_id = auth.uid() and status = 'pending'
  ) into v_reverse_pending;

  if v_reverse_pending then
    update public.friendships set status = 'accepted' where user_id = v_target.id and friend_id = auth.uid();
    insert into public.friendships (user_id, friend_id, status) values (auth.uid(), v_target.id, 'accepted')
      on conflict (user_id, friend_id) do update set status = 'accepted';
    return jsonb_build_object(
      'success', true,
      'auto_accepted', true,
      'friend', jsonb_build_object('id', v_target.id, 'name', v_target.name, 'avatar_id', v_target.avatar_id, 'lifetime_points', v_target.lifetime_points, 'total_minutes', v_target.total_minutes)
    );
  end if;

  insert into public.friendships (user_id, friend_id, status) values (auth.uid(), v_target.id, 'pending')
    on conflict (user_id, friend_id) do update set status = 'pending';

  return jsonb_build_object(
    'success', true,
    'auto_accepted', false,
    'friend', jsonb_build_object('id', v_target.id, 'name', v_target.name, 'avatar_id', v_target.avatar_id)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.start_study_session(p_duration_minutes integer, p_category_name text)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  UPDATE public.profiles 
  SET 
    active_session_ends_at = now() + (p_duration_minutes * interval '1 minute'),
    active_session_category_name = p_category_name
  WHERE id = auth.uid();
$function$;

REVOKE ALL ON FUNCTION public.complete_study_session(uuid, uuid, integer, boolean, integer, timestamp with time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_study_session(uuid, uuid, integer, boolean, integer, timestamp with time zone) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.start_study_session(integer, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_study_session(integer, text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.add_friend_by_code(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_friend_by_code(text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;

-- search_path canlıdaki hâline (delete_own_account hariç, bkz. başlık)
ALTER FUNCTION public.cleanup_unconfirmed_duplicate_identity(text) SET search_path TO 'public';
ALTER FUNCTION public.ensure_user_in_league(uuid, integer) SET search_path TO 'public';
ALTER FUNCTION public.get_my_league_ids() SET search_path TO 'public';
ALTER FUNCTION public.handle_newsletter_subscription() SET search_path TO 'public';
ALTER FUNCTION public.purchase_avatar(text) SET search_path TO 'public';
ALTER FUNCTION public.respond_friend_request(uuid, boolean) SET search_path TO 'public';
ALTER FUNCTION public.set_equipped_avatar(text) SET search_path TO 'public';

-- profiles: friend_code varsayılanı ve e-posta kopyası
ALTER TABLE public.profiles ALTER COLUMN friend_code
  SET DEFAULT upper(substr(replace((gen_random_uuid())::text, '-'::text, ''::text), 1, 6));
UPDATE public.profiles p
   SET email = coalesce(u.email, '')
  FROM auth.users u
 WHERE u.id = p.id AND p.email IS NULL;
UPDATE public.profiles SET email = '' WHERE email IS NULL;
ALTER TABLE public.profiles ALTER COLUMN email SET NOT NULL;
COMMENT ON COLUMN public.profiles.email IS NULL;

-- Kolonlar
ALTER TABLE public.study_sessions DROP COLUMN IF EXISTS start_verified;
ALTER TABLE public.league_memberships DROP COLUMN IF EXISTS period_started_at;

-- Yeni fonksiyonlar
DROP FUNCTION IF EXISTS public.get_app_config();
DROP FUNCTION IF EXISTS public.register_session_start(uuid, integer);
DROP FUNCTION IF EXISTS public.enforce_profile_name();
DROP FUNCTION IF EXISTS public.enforce_category_name();
DROP FUNCTION IF EXISTS public.discard_profile_email();
DROP FUNCTION IF EXISTS public.league_membership_period_start();
DROP FUNCTION IF EXISTS public.league_period_rollover();
DROP FUNCTION IF EXISTS public.display_text_is_allowed(text);
DROP FUNCTION IF EXISTS public.clean_display_text(text);
DROP FUNCTION IF EXISTS public.normalize_friend_code(text);
DROP FUNCTION IF EXISTS public.generate_friend_code(integer);
DROP FUNCTION IF EXISTS public.app_config_int(text);

-- Yeni tablolar
DROP TABLE IF EXISTS public.session_starts;
DROP TABLE IF EXISTS public.friend_code_attempts;
DROP TABLE IF EXISTS public.blocked_name_terms;
DROP TABLE IF EXISTS public.app_config;

-- Migration geçmişi
DO $$
BEGIN
    DELETE FROM supabase_migrations.schema_migrations WHERE version = '20261004120000';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişinden silinemedi: %', SQLERRM;
END $$;

COMMIT;
