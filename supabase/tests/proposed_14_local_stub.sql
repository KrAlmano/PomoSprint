-- ============================================================================
-- YEREL STUB: proposed/14 kuru çalıştırması için canlı şemanın ilgili kısmı
-- ============================================================================
-- YALNIZCA tek kullanımlık yerel Postgres (16+) içindir; CANLIDA ÇALIŞTIRMAYIN.
-- 3 Ekim 2026'da canlıdan okunan tablo/kolon/kısıt, RLS politikası, yetki,
-- trigger ve fonksiyon gövdeleriyle (pg_get_functiondef) kuruldu. Supabase'e
-- özgü parçalar (auth.users, auth.uid(), net.http_post, pg_cron) taklit
-- edilir; varsayılan yetkiler Supabase'deki gibi anon/authenticated'a açıktır
-- (yeni nesnelerde REVOKE unutulursa testler yakalar). Buradaki 26
-- fonksiyonun md5(pg_get_functiondef) değeri canlıyla birebir aynı (3 Ekim
-- 2026'da karşılaştırıldı); proposed/14'ün ön koşul denetimi bu sayede
-- yerelde de çalışır.
--
-- Kullanım (yerel küme, ayrı veritabanı):
--   createdb p14 && psql -X -v ON_ERROR_STOP=1 -d p14 -f supabase/tests/proposed_14_local_stub.sql
--   psql -X -d p14 -f supabase/tests/proposed_14_gizlilik_sosyal_dryrun.sql
--   (Beklenen: ERROR:  DRYRUN_RESULT >> T00 özet 62/62: true ... ; her satır 'true')
-- proposed/15'in de uygulandığı durum için DRYRUN'dan önce 15'in gövdesini
-- (\echo/\quit hariç) aynı veritabanına uygulayın; sonuç yine hepsi 'true'.
-- ============================================================================
SET client_min_messages = warning;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN CREATE ROLE anon NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN CREATE ROLE service_role NOLOGIN BYPASSRLS; END IF;
END $$;

-- ---------------------------------------------------------------------------
-- Supabase taklitleri
-- ---------------------------------------------------------------------------
CREATE SCHEMA auth;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;

CREATE TABLE auth.users (
    instance_id uuid,
    id uuid PRIMARY KEY,
    aud varchar(255),
    role varchar(255),
    email varchar(255),
    encrypted_password varchar(255),
    email_confirmed_at timestamptz,
    invited_at timestamptz,
    last_sign_in_at timestamptz,
    raw_app_meta_data jsonb,
    raw_user_meta_data jsonb,
    created_at timestamptz,
    updated_at timestamptz,
    phone text DEFAULT NULL,
    phone_confirmed_at timestamptz,
    is_sso_user boolean NOT NULL DEFAULT false,
    deleted_at timestamptz,
    is_anonymous boolean NOT NULL DEFAULT false
);

CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  select
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;

CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
  select
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;

CREATE SCHEMA net;
CREATE TABLE net.http_request_queue (id bigserial PRIMARY KEY, url text, body jsonb, headers jsonb);
CREATE FUNCTION net.http_post(url text, body jsonb DEFAULT '{}'::jsonb, params jsonb DEFAULT '{}'::jsonb,
                              headers jsonb DEFAULT '{}'::jsonb, timeout_milliseconds integer DEFAULT 5000)
RETURNS bigint LANGUAGE sql AS $$
    INSERT INTO net.http_request_queue (url, body, headers) VALUES (url, body, headers) RETURNING id;
$$;

CREATE SCHEMA cron;
CREATE TABLE cron.job (
    jobid bigserial PRIMARY KEY,
    schedule text NOT NULL,
    command text NOT NULL,
    username text NOT NULL DEFAULT current_user,
    active boolean NOT NULL DEFAULT true,
    jobname text UNIQUE
);
CREATE FUNCTION cron.schedule(job_name text, schedule text, command text) RETURNS bigint LANGUAGE sql AS $$
    INSERT INTO cron.job (jobname, schedule, command) VALUES (job_name, schedule, command)
    ON CONFLICT (jobname) DO UPDATE SET schedule = excluded.schedule, command = excluded.command
    RETURNING jobid;
$$;
CREATE FUNCTION cron.unschedule(job_id bigint) RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM cron.job WHERE jobid = job_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'could not find valid entry for job %', job_id; END IF;
    RETURN true;
END $$;
INSERT INTO cron.job (jobname, schedule, command) VALUES
    ('cleanup_activity_feed_job', '0 3 * * *', 'DELETE FROM public.activity_feed WHERE activity_date < CURRENT_DATE - 30;'),
    ('weekly_leagues_job', '1 21 * * 0', 'SELECT public.process_weekly_leagues()');

-- Supabase'in public şemasındaki varsayılan yetkileri
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Tablolar (canlı kolonlar ve kısıtlar)
-- ---------------------------------------------------------------------------
CREATE TABLE public.avatars (
    id text PRIMARY KEY,
    name_tr text NOT NULL,
    name_en text NOT NULL,
    asset_key text NOT NULL,
    cost_coins integer NOT NULL DEFAULT 0,
    is_premium_only boolean NOT NULL DEFAULT false,
    is_default boolean NOT NULL DEFAULT false,
    sort_order integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    is_league_award boolean NOT NULL DEFAULT false
);
INSERT INTO public.avatars (id, name_tr, name_en, asset_key, is_default, cost_coins, is_league_award) VALUES
    ('avatar_16_basic', 'Temel', 'Basic', 'a16.png', true, 0, false),
    ('avatar_17_basic', 'Temel 2', 'Basic 2', 'a17.png', true, 0, false),
    ('avatar_1_gamer', 'Oyuncu', 'Gamer', 'a1.png', false, 200, false),
    ('league_bronze_monthly', 'Bronz', 'Bronze', 'lb1.png', false, 0, true),
    ('league_bronze_weekly', 'Bronz H', 'Bronze W', 'lb2.png', false, 0, true);

CREATE TABLE public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name text NOT NULL,
    email text NOT NULL,
    avatar_id text DEFAULT 'avatar_16_basic'::text,
    total_minutes integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    friend_code varchar DEFAULT upper(substr(replace((gen_random_uuid())::text, '-'::text, ''::text), 1, 6)),
    current_streak integer DEFAULT 0,
    last_study_date date,
    is_premium boolean DEFAULT false,
    league_tier integer NOT NULL DEFAULT 1,
    lifetime_points integer NOT NULL DEFAULT 0,
    coins integer NOT NULL DEFAULT 0,
    longest_streak integer NOT NULL DEFAULT 0,
    timezone text NOT NULL DEFAULT 'Europe/Istanbul'::text,
    active_session_ends_at timestamptz,
    active_session_category_name text,
    show_in_social_feed boolean NOT NULL DEFAULT true,
    user_segment text,
    daily_goal_minutes integer,
    birth_year integer,
    onboarding_completed_at timestamptz,
    CONSTRAINT profiles_birth_year_range_check CHECK (((birth_year IS NULL) OR ((birth_year >= 1900) AND (birth_year <= 2100)))),
    CONSTRAINT profiles_daily_goal_range_check CHECK (((daily_goal_minutes IS NULL) OR ((daily_goal_minutes >= 5) AND (daily_goal_minutes <= 1440)))),
    CONSTRAINT profiles_league_tier_check CHECK (((league_tier >= 1) AND (league_tier <= 5))),
    CONSTRAINT profiles_name_length_check CHECK (((char_length(btrim(name)) >= 1) AND (char_length(btrim(name)) <= 50))),
    CONSTRAINT profiles_user_segment_check CHECK ((user_segment = ANY (ARRAY['lgs'::text, 'yks'::text, 'university'::text, 'work'::text])))
);

CREATE TABLE public.avatar_unlocks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    avatar_id text NOT NULL REFERENCES public.avatars(id),
    unlock_type text NOT NULL CHECK ((unlock_type = ANY (ARRAY['coins'::text, 'premium'::text, 'default'::text, 'league_award'::text]))),
    coins_spent integer NOT NULL DEFAULT 0,
    unlocked_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, avatar_id)
);

CREATE TABLE public.categories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name text NOT NULL,
    color_hex text NOT NULL,
    icon_name text,
    sort_order integer NOT NULL DEFAULT 0,
    is_archived boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.study_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    category text NOT NULL,
    duration_minutes integer NOT NULL,
    completed_at timestamptz NOT NULL DEFAULT now(),
    category_id uuid REFERENCES public.categories(id) ON DELETE SET NULL,
    base_points integer NOT NULL DEFAULT 0,
    bonus_points integer NOT NULL DEFAULT 0,
    was_paused boolean NOT NULL DEFAULT false,
    is_verified integer NOT NULL DEFAULT 0,
    client_uuid uuid,
    started_at timestamptz
);

CREATE TABLE public.friendships (
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    friend_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    status text NOT NULL DEFAULT 'accepted'::text CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text]))),
    PRIMARY KEY (user_id, friend_id)
);

CREATE TABLE public.leagues (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tier integer NOT NULL DEFAULT 1 CHECK (((tier >= 1) AND (tier <= 5))),
    start_date timestamptz NOT NULL DEFAULT now(),
    end_date timestamptz NOT NULL,
    is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE public.league_memberships (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    league_id uuid REFERENCES public.leagues(id) ON DELETE CASCADE,
    user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
    weekly_points integer NOT NULL DEFAULT 0,
    joined_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (league_id, user_id)
);

CREATE TABLE public.activity_feed (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    activity_type text NOT NULL CHECK ((activity_type = ANY (ARRAY['daily_summary'::text, 'streak_milestone'::text, 'league_promotion'::text, 'daily_4h_milestone'::text]))),
    payload jsonb NOT NULL,
    activity_date date NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, activity_type, activity_date)
);
CREATE INDEX idx_activity_feed_user_created ON public.activity_feed (user_id, created_at DESC);

CREATE TABLE public.marketing_subscribers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    email text NOT NULL,
    subscribed_at timestamptz DEFAULT now(),
    unsubscribe_token uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    welcome_sent_at timestamptz
);
CREATE UNIQUE INDEX marketing_subscribers_email_lower_key ON public.marketing_subscribers (lower(email));

CREATE TABLE public.waitlist (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email text NOT NULL UNIQUE,
    created_at timestamptz DEFAULT now(),
    CONSTRAINT waitlist_email_format_check CHECK (((email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'::text) AND (length(email) <= 254)))
);

-- ---------------------------------------------------------------------------
-- RLS ve yetkiler (canlı)
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.avatars ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.avatar_unlocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leagues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.league_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_feed ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketing_subscribers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profiles select policy" ON public.profiles FOR SELECT USING ((( SELECT auth.uid() AS uid) = id));
CREATE POLICY "Profiles insert policy" ON public.profiles FOR INSERT WITH CHECK ((( SELECT auth.uid() AS uid) = id));
CREATE POLICY "Profiles update policy" ON public.profiles FOR UPDATE USING ((( SELECT auth.uid() AS uid) = id)) WITH CHECK ((( SELECT auth.uid() AS uid) = id));
CREATE POLICY "Profiles delete policy" ON public.profiles FOR DELETE USING ((( SELECT auth.uid() AS uid) = id));
CREATE POLICY "Users can view own or incoming friendships" ON public.friendships FOR SELECT USING (((auth.uid() = user_id) OR (auth.uid() = friend_id)));
CREATE POLICY "Users can manage their own subscription" ON public.marketing_subscribers FOR ALL USING ((auth.uid() = user_id));
CREATE POLICY "Allow public insert to waitlist" ON public.waitlist FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Service role full access on activity_feed" ON public.activity_feed FOR ALL
    USING (((CURRENT_USER = 'postgres'::name) OR (CURRENT_ROLE = 'service_role'::name)));
CREATE POLICY "Users can see their own and friends activity feed" ON public.activity_feed FOR SELECT
    USING (((user_id = ( SELECT auth.uid() AS uid)) OR (user_id IN ( SELECT
        CASE
            WHEN (f.user_id = ( SELECT auth.uid() AS uid)) THEN f.friend_id
            ELSE f.user_id
        END AS user_id
   FROM public.friendships f
  WHERE ((f.status = 'accepted'::text) AND ((f.user_id = ( SELECT auth.uid() AS uid)) OR (f.friend_id = ( SELECT auth.uid() AS uid))))))));
CREATE POLICY "avatars readable" ON public.avatars FOR SELECT USING (true);
CREATE POLICY "own categories" ON public.categories FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "own sessions" ON public.study_sessions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "own unlocks" ON public.avatar_unlocks FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "leagues readable" ON public.leagues FOR SELECT TO authenticated USING (true);
CREATE POLICY "memberships readable" ON public.league_memberships FOR SELECT TO authenticated USING (true);

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
GRANT SELECT ON public.profiles TO authenticated;
GRANT INSERT (id, email, name, avatar_id) ON public.profiles TO authenticated;
GRANT UPDATE (birth_year, daily_goal_minutes, name, onboarding_completed_at, show_in_social_feed, timezone, user_segment)
    ON public.profiles TO authenticated;
GRANT SELECT ON public.categories TO authenticated;
GRANT INSERT (color_hex, created_at, icon_name, id, is_archived, name, sort_order, user_id),
      UPDATE (color_hex, created_at, icon_name, id, is_archived, name, sort_order, user_id)
    ON public.categories TO authenticated;
GRANT SELECT ON public.study_sessions, public.friendships, public.activity_feed, public.avatar_unlocks,
                public.leagues, public.league_memberships TO authenticated;
GRANT SELECT ON public.avatars TO anon, authenticated;
GRANT SELECT, DELETE ON public.marketing_subscribers TO authenticated;
GRANT INSERT ON public.waitlist TO anon;

-- ---------------------------------------------------------------------------
-- Fonksiyonlar (canlı gövdeler, 3 Ekim 2026)
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

CREATE OR REPLACE FUNCTION public.handle_newsletter_subscription()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Check if email_confirmed_at changed from NULL to NOT NULL
  IF (OLD.email_confirmed_at IS NULL AND NEW.email_confirmed_at IS NOT NULL) THEN
    -- Check if raw_user_meta_data contains "newsletter": true
    IF (NEW.raw_user_meta_data->>'newsletter' = 'true') THEN
      INSERT INTO public.marketing_subscribers (user_id, email)
      VALUES (NEW.id, NEW.email)
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.invoke_send_welcome_email()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Call Edge Function
  PERFORM net.http_post(
    url := 'https://eoosnyakvxmifmexpgxa.supabase.co/functions/v1/send-welcome-email',
    body := json_build_object('record', row_to_json(NEW))::jsonb,
    headers := '{"Content-Type": "application/json"}'::jsonb
  );
  RETURN NEW;
END;
$function$;

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

CREATE OR REPLACE FUNCTION public.enforce_category_limit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_is_premium boolean;
    v_active_count integer;
    v_limit integer;
BEGIN
    IF NEW.is_archived THEN
        RETURN NEW;
    END IF;

    SELECT is_premium INTO v_is_premium FROM public.profiles WHERE id = NEW.user_id;
    v_is_premium := COALESCE(v_is_premium, false);
    v_limit := CASE WHEN v_is_premium THEN 15 ELSE 8 END;

    SELECT count(*) INTO v_active_count
    FROM public.categories
    WHERE user_id = NEW.user_id AND is_archived = false;

    IF v_active_count >= v_limit THEN
        IF v_is_premium THEN
            RAISE EXCEPTION 'Premium planda en fazla 15 kategori ekleyebilirsin.';
        ELSE
            RAISE EXCEPTION 'Ücretsiz planda en fazla 8 kategori ekleyebilirsin. Premium ile 15''e çıkar.';
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_category(p_name text, p_color_hex text, p_icon_name text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_is_premium boolean;
    v_active_count integer;
    v_limit integer;
    v_new_id uuid;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Get user premium status
    SELECT is_premium INTO v_is_premium FROM public.profiles WHERE id = v_uid;
    IF v_is_premium IS NULL THEN
        v_is_premium := false;
    END IF;

    -- Determine limit
    IF v_is_premium THEN
        v_limit := 15;
    ELSE
        v_limit := 8;
    END IF;

    -- Check current active count
    SELECT count(*) INTO v_active_count 
    FROM public.categories 
    WHERE user_id = v_uid AND is_archived = false;

    IF v_active_count >= v_limit THEN
        IF v_is_premium THEN
            RAISE EXCEPTION 'Premium planda en fazla 15 kategori ekleyebilirsin.';
        ELSE
            RAISE EXCEPTION 'Ücretsiz planda en fazla 8 kategori ekleyebilirsin. Premium ile 15''e çıkar.';
        END IF;
    END IF;

    -- Check for exact active name duplicate
    IF EXISTS (
        SELECT 1 FROM public.categories 
        WHERE user_id = v_uid AND name = p_name AND is_archived = false
    ) THEN
        RAISE EXCEPTION 'Bu isimde aktif bir kategori zaten var.';
    END IF;

    -- Insert
    INSERT INTO public.categories (user_id, name, color_hex, icon_name, sort_order)
    VALUES (v_uid, p_name, p_color_hex, p_icon_name, v_active_count)
    RETURNING id INTO v_new_id;

    RETURN v_new_id;
END;
$function$;

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

CREATE OR REPLACE FUNCTION public.league_award_avatar_id(p_tier integer, p_rank integer)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE
    WHEN p_rank = 1 THEN
      CASE p_tier
        WHEN 1 THEN 'league_bronze_monthly'
        WHEN 2 THEN 'league_silver_monthly'
        WHEN 3 THEN 'league_gold_monthly'
        WHEN 4 THEN 'league_sapphire_monthly'
        WHEN 5 THEN 'league_diamond_monthly'
        ELSE NULL
      END
    WHEN p_rank IN (2, 3) THEN
      CASE p_tier
        WHEN 1 THEN 'league_bronze_weekly'
        WHEN 2 THEN 'league_silver_weekly'
        WHEN 3 THEN 'league_gold_weekly'
        WHEN 4 THEN 'league_sapphire_weekly'
        WHEN 5 THEN 'league_diamond_weekly'
        ELSE NULL
      END
    ELSE NULL
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

CREATE OR REPLACE FUNCTION public.get_public_monthly_leaderboard(p_limit integer DEFAULT 10)
 RETURNS TABLE(name text, avatar_id text, total_points integer, total_minutes integer, is_me boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
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

CREATE OR REPLACE FUNCTION public.get_public_alltime_leaderboard(p_limit integer DEFAULT 50)
 RETURNS TABLE(name text, avatar_id text, total_minutes integer, lifetime_points integer, is_premium boolean, is_me boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
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

CREATE OR REPLACE FUNCTION public.respond_friend_request(p_from_user_id uuid, p_accept boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1 from public.friendships
     where user_id = p_from_user_id and friend_id = auth.uid() and status = 'pending'
  ) then
    return jsonb_build_object('success', false, 'message', 'Bekleyen bir istek bulunamadı.');
  end if;

  if p_accept then
    update public.friendships set status = 'accepted'
     where user_id = p_from_user_id and friend_id = auth.uid();
    insert into public.friendships (user_id, friend_id, status) values (auth.uid(), p_from_user_id, 'accepted')
      on conflict (user_id, friend_id) do update set status = 'accepted';
  else
    delete from public.friendships where user_id = p_from_user_id and friend_id = auth.uid();
  end if;

  return jsonb_build_object('success', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_friends()
 RETURNS TABLE(id uuid, name text, avatar_id text, lifetime_points integer, total_minutes integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
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
 STABLE SECURITY DEFINER
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

CREATE OR REPLACE FUNCTION public.cancel_study_session()
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  UPDATE public.profiles 
  SET 
    active_session_ends_at = NULL,
    active_session_category_name = NULL
  WHERE id = auth.uid();
$function$;

CREATE OR REPLACE FUNCTION public.delete_own_account()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  delete from auth.users where id = auth.uid();
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_friends_feed(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_result jsonb;
BEGIN
    SELECT COALESCE(jsonb_agg(row_to_json(t)), '[]'::jsonb)
    INTO v_result
    FROM (
        SELECT
            a.id,
            p.id AS user_id,
            p.name,
            p.avatar_id,
            a.activity_type,
            a.payload,
            a.activity_date,
            a.created_at
        FROM public.activity_feed a
        JOIN public.profiles p ON p.id = a.user_id
        WHERE p.show_in_social_feed = true
          AND (
              a.user_id = v_uid OR
              a.user_id IN (
                  SELECT CASE WHEN user_id = v_uid THEN friend_id ELSE user_id END
                  FROM public.friendships
                  WHERE status = 'accepted' AND (user_id = v_uid OR friend_id = v_uid)
              )
          )
        ORDER BY a.created_at DESC, a.id
        LIMIT p_limit
    ) t;

    RETURN v_result;
END;
$function$;

-- Trigger'lar (canlı)
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
CREATE TRIGGER on_auth_user_confirmed_newsletter AFTER UPDATE OF email_confirmed_at ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_newsletter_subscription();
CREATE TRIGGER after_insert_marketing_subscribers AFTER INSERT ON public.marketing_subscribers FOR EACH ROW EXECUTE FUNCTION public.invoke_send_welcome_email();
CREATE TRIGGER on_profile_created_give_avatars AFTER INSERT ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.give_default_avatars();
CREATE TRIGGER sanitize_profile_insert BEFORE INSERT ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.sanitize_profile_insert();
CREATE TRIGGER validate_profile_timezone BEFORE INSERT OR UPDATE OF timezone ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.validate_profile_timezone();
CREATE TRIGGER enforce_category_limit_trigger BEFORE INSERT ON public.categories FOR EACH ROW EXECUTE FUNCTION public.enforce_category_limit();
CREATE TRIGGER enforce_category_limit_on_unarchive BEFORE UPDATE OF is_archived ON public.categories FOR EACH ROW WHEN ((old.is_archived AND (NOT new.is_archived))) EXECUTE FUNCTION public.enforce_category_limit();

-- Fonksiyon yetkileri (canlı: routine_privileges)
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO service_role;
GRANT EXECUTE ON FUNCTION
    public.add_friend_by_code(text), public.cancel_study_session(), public.complete_study_session(uuid, uuid, integer, boolean, integer, timestamptz),
    public.create_category(text, text, text), public.delete_own_account(), public.get_friends_feed(integer),
    public.get_incoming_friend_requests(), public.get_league_ranking(uuid), public.get_live_friends(),
    public.get_my_friends(), public.get_my_league_ranking(), public.respond_friend_request(uuid, boolean),
    public.start_study_session(integer, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION
    public.get_league_zones(integer), public.get_public_alltime_leaderboard(integer),
    public.get_public_monthly_leaderboard(integer), public.league_award_avatar_id(integer, integer)
  TO anon, authenticated;
