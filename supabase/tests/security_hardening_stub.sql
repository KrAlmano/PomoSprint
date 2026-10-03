-- Yerel, tek kullanımlık bir Postgres üzerinde Supabase'i taklit eden en küçük şema.
-- CANLI veritabanına UYGULAMAYIN. Kullanım: security_hardening_test.sql başlığına bakın.
CREATE ROLE anon NOLOGIN; CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
GRANT USAGE ON SCHEMA auth TO anon, authenticated;
CREATE TABLE public.profiles (id uuid PRIMARY KEY, email text, name text, avatar_id text, is_premium boolean DEFAULT false,
  coins int DEFAULT 0, lifetime_points int DEFAULT 0, total_minutes int DEFAULT 0, league_tier int DEFAULT 1,
  show_in_social_feed boolean DEFAULT true, user_segment text, daily_goal_minutes int, birth_year int, onboarding_completed_at timestamptz);
CREATE TABLE public.categories (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES public.profiles(id),
  name text NOT NULL, color_hex text NOT NULL DEFAULT '#000000', icon_name text, sort_order int DEFAULT 0, is_archived boolean NOT NULL DEFAULT false);
CREATE TABLE public.study_sessions (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL, category_id uuid,
  duration_minutes int NOT NULL, started_at timestamptz, completed_at timestamptz DEFAULT now(), client_uuid uuid);
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
-- canlıya benzer: profili önce güncelleyip sonra seansı ekleyen RPC
CREATE FUNCTION public.complete_study_session(p_client_uuid uuid, p_category_id uuid, p_duration_minutes int, p_started_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN
  UPDATE public.profiles SET coins = coins + 5, total_minutes = total_minutes + p_duration_minutes WHERE id = auth.uid();
  INSERT INTO public.study_sessions (user_id, category_id, duration_minutes, started_at, client_uuid)
  VALUES (auth.uid(), p_category_id, p_duration_minutes, p_started_at, p_client_uuid);
  RETURN jsonb_build_object('ok', true);
END $$;
CREATE FUNCTION public.get_league_ranking(p_user_id uuid)
RETURNS TABLE(name text, email text, avatar_id text, weekly_points int, tier int, end_date timestamptz, is_me boolean,
  promotion_zone_end int, demotion_zone_start int, member_count int)
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
BEGIN RETURN QUERY SELECT p.name, p.email, p.avatar_id, 10, 1, now(), p.id = p_user_id, 3, 999, 2 FROM public.profiles p; END $$;
CREATE FUNCTION public.ensure_user_in_league(p_user_id uuid, p_points int) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$ BEGIN END $$;
CREATE FUNCTION public.start_study_session(p_duration_minutes integer, p_category_name text) RETURNS void LANGUAGE sql SECURITY DEFINER AS $$ SELECT 1 $$;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;
INSERT INTO public.profiles (id, email, name) VALUES ('11111111-1111-1111-1111-111111111111','a@x.com','A'), ('22222222-2222-2222-2222-222222222222','b@x.com','B');
