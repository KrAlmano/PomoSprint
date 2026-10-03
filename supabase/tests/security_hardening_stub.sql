-- Yerel, tek kullanımlık bir Postgres üzerinde Supabase'in en küçük taklidi.
-- CANLI veritabanına UYGULAMAYIN. Kullanım: supabase/tests/run_local.sh
--
-- Bu dosya YALNIZCA migration'ların oluşturmadığı (canlıda elle yaratılmış)
-- şeyleri sağlar: roller, auth şeması (auth.uid/auth.jwt/auth.users),
-- pg_cron taklidi ve baseline tablolar. Fonksiyonların tamamı (ör.
-- complete_study_session) gerçek migration zincirinden gelir; böylece
-- testler repodaki gerçek RPC davranışını doğrular. Canlıda olup repoda
-- olmayan fonksiyonlar (get_points_config, add_friend_by_code,
-- respond_friend_request ...) burada YOKTUR; onlar
-- scripts/security_regression_test.js ile canlıda test edilir.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role NOLOGIN BYPASSRLS;
    END IF;
END $$;

-- Supabase varsayılan yetkileri: public şemasındaki yeni tablo ve
-- fonksiyonlar API rollerine açıktır; kısıtlamayı migration'lar yapar.
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon, authenticated, service_role;

-- ------------------------------------------------------------
-- auth
-- ------------------------------------------------------------
CREATE SCHEMA auth;
CREATE TABLE auth.users (
    id uuid PRIMARY KEY,
    email text,
    email_confirmed_at timestamptz
);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
    SELECT COALESCE(
        nullif(current_setting('request.jwt.claim.sub', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
    )::uuid
$$;
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
    SELECT COALESCE(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA auth TO anon, authenticated, service_role;

-- ------------------------------------------------------------
-- pg_cron taklidi (20260809022700 cron.unschedule/cron.schedule çağırır)
-- ------------------------------------------------------------
CREATE SCHEMA cron;
CREATE TABLE cron.job (
    jobid bigserial PRIMARY KEY,
    jobname text UNIQUE,
    schedule text,
    command text
);
CREATE FUNCTION cron.schedule(text, text, text) RETURNS bigint LANGUAGE sql AS $$
    INSERT INTO cron.job (jobname, schedule, command) VALUES ($1, $2, $3)
    ON CONFLICT (jobname) DO UPDATE SET schedule = EXCLUDED.schedule, command = EXCLUDED.command
    RETURNING jobid
$$;
CREATE FUNCTION cron.unschedule(text) RETURNS boolean LANGUAGE sql AS $$
    WITH d AS (DELETE FROM cron.job WHERE jobname = $1 RETURNING 1)
    SELECT EXISTS (SELECT 1 FROM d)
$$;

-- ------------------------------------------------------------
-- Baseline tablolar (hiçbir migration'da CREATE TABLE'ı yok)
-- Kolonlar migration'ların ve istemcinin kullandıklarından türetildi.
-- ------------------------------------------------------------
CREATE TABLE public.profiles (
    id uuid PRIMARY KEY,
    email text,
    name text,
    avatar_id text,
    points integer DEFAULT 0,
    total_minutes integer NOT NULL DEFAULT 0,
    current_streak integer NOT NULL DEFAULT 0,
    last_study_date date,
    league_tier integer DEFAULT 1,
    is_premium boolean DEFAULT false,
    show_in_social_feed boolean DEFAULT true,
    friend_code text UNIQUE,
    categories jsonb,
    unlocked_avatars text[],
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.study_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    category text,
    duration_minutes integer NOT NULL,
    completed_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Own sessions select" ON public.study_sessions
    FOR SELECT USING (user_id = auth.uid());

CREATE TABLE public.leagues (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tier integer NOT NULL,
    start_date timestamptz NOT NULL DEFAULT now(),
    end_date timestamptz,
    is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE public.league_memberships (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    league_id uuid NOT NULL REFERENCES public.leagues(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    weekly_points integer NOT NULL DEFAULT 0,
    joined_at timestamptz NOT NULL DEFAULT now()
);

-- Tek satır (istek gönderen -> alan) ve iki satır modellerinin ikisi de
-- test edilir; UNIQUE (user_id, friend_id) user_id ile başlayan bir index
-- oluşturduğundan audit_fixes yalnızca friend_id index'ini ekler.
CREATE TABLE public.friendships (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    friend_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted')),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, friend_id)
);
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Own friendships select" ON public.friendships
    FOR SELECT USING (auth.uid() IN (user_id, friend_id));
