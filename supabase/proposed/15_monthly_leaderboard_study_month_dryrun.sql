-- ============================================================================
-- KURU ÇALIŞTIRMA: 15_monthly_leaderboard_study_month
-- Canlıda hiçbir şeyi kalıcı DEĞİŞTİRMEZ. Supabase Dashboard > SQL Editor'e
-- yapıştırıp çalıştırın. Değişiklik + senaryolar sentetik kullanıcılarla
-- çalışır, en sonda bilinçli bir hata (DRYRUN_RESULT) fırlatılır ve tüm işlem
-- geri alınır. Hata mesajındaki T satırlarının sonu 'true' olmalı (BİLGİ
-- satırı yalnızca eski kuralla karşılaştırmadır).
-- ============================================================================
BEGIN;

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
    WHERE ss.started_at IS NOT NULL
      AND ss.started_at >= (
            (date_trunc('month', (now() AT TIME ZONE p.timezone) - interval '4 hours') + interval '4 hours')
            AT TIME ZONE p.timezone
          )
      AND p.show_in_social_feed = true
    GROUP BY p.id, p.name, p.avatar_id
    ORDER BY 3 DESC, 4 DESC, p.id
    LIMIT LEAST(GREATEST(p_limit, 0), 100);
$function$;
REVOKE ALL ON FUNCTION public.get_public_monthly_leaderboard(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_monthly_leaderboard(integer) TO anon, authenticated;

DO $dry$
DECLARE
  u1 uuid := gen_random_uuid();   -- profil dilimi Europe/Istanbul
  u2 uuid := gen_random_uuid();   -- profil dilimi America/New_York
  m_ist timestamptz;              -- İstanbul çalışma ayının başı (ayın 1'i 04:00)
  m_ny timestamptz;               -- New York çalışma ayının başı
  v_min int; v_pts int; v_bool boolean; v_txt text;
  res text[] := '{}';
BEGIN
  INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
  VALUES (u1, 'dryrun12a-' || u1 || '@example.invalid', '{"name":"Dry Ay"}', 'authenticated', 'authenticated'),
         (u2, 'dryrun12b-' || u2 || '@example.invalid', '{"name":"Dry Ny"}', 'authenticated', 'authenticated');
  UPDATE public.profiles SET show_in_social_feed = true WHERE id IN (u1, u2);
  UPDATE public.profiles SET timezone = 'America/New_York' WHERE id = u2;

  m_ist := (date_trunc('month', (now() AT TIME ZONE 'Europe/Istanbul') - interval '4 hours') + interval '4 hours')
           AT TIME ZONE 'Europe/Istanbul';
  m_ny := (date_trunc('month', (now() AT TIME ZONE 'America/New_York') - interval '4 hours') + interval '4 hours')
          AT TIME ZONE 'America/New_York';

  -- Sentetik seanslar (yüksek puan: ilk 100'e girsinler).
  INSERT INTO public.study_sessions (user_id, category, duration_minutes, started_at, completed_at, base_points, bonus_points, client_uuid)
  VALUES
    -- u1: ayın 1'i 03:50 → 04:15 (04:00 öncesi başladı → önceki ay)
    (u1, 'Dry', 25, m_ist - interval '10 minutes', m_ist + interval '15 minutes', 1000000, 0, gen_random_uuid()),
    -- u1: önceki ayın son günü 23:50 → 1'i 00:15 (gece yarısını geçen → önceki ay)
    (u1, 'Dry', 25, m_ist - interval '4 hours 10 minutes', m_ist - interval '3 hours 45 minutes', 1000000, 0, gen_random_uuid()),
    -- u1: ayın 1'i 04:00 → bu ay
    (u1, 'Dry', 25, m_ist, m_ist + interval '25 minutes', 1000000, 0, gen_random_uuid()),
    -- u2: New York'ta 1'i 03:50 → önceki ay; 04:00 → bu ay
    (u2, 'Dry', 25, m_ny - interval '10 minutes', m_ny + interval '15 minutes', 5, 0, gen_random_uuid()),
    (u2, 'Dry', 50, m_ny, m_ny + interval '50 minutes', 2000000, 0, gen_random_uuid());

  SELECT sum(duration_minutes) INTO v_min FROM public.study_sessions
   WHERE user_id = u1
     AND completed_at >= (date_trunc('month', now() AT TIME ZONE 'Europe/Istanbul') AT TIME ZONE 'Europe/Istanbul');
  res := res || ('BİLGİ eski kuralla (completed_at, gece yarısı) u1 = ' || coalesce(v_min, 0) || ' dk');

  -- u1 olarak
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u1, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  SELECT total_minutes, total_points INTO v_min, v_pts FROM public.get_public_monthly_leaderboard(100) WHERE is_me;
  res := res || ('T1 İstanbul: yalnız bu çalışma ayında BAŞLAYAN seans (25 dk = ' || coalesce(v_min::text, 'yok')
                 || '): ' || coalesce((v_min = 25 AND v_pts = 1000000)::text, 'false'));

  -- u2 olarak
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u2, 'role', 'authenticated')::text, true);
  SELECT total_minutes INTO v_min FROM public.get_public_monthly_leaderboard(100) WHERE is_me;
  res := res || ('T2 New York profili kendi diliminde 04:00 (50 dk = ' || coalesce(v_min::text, 'yok')
                 || '): ' || coalesce((v_min = 50)::text, 'false'));
  SELECT name INTO v_txt FROM public.get_public_monthly_leaderboard(100) WHERE NOT is_me AND name = 'Dry Ay';
  res := res || ('T3 oturum açıkken tam ad: ' || coalesce((v_txt = 'Dry Ay')::text, 'false'));

  EXECUTE 'RESET ROLE';

  SELECT has_function_privilege('anon', 'public.get_public_monthly_leaderboard(integer)', 'execute') INTO v_bool;
  res := res || ('T4 anon (landing) çağırabilir: ' || v_bool::text);
  SELECT has_function_privilege('authenticated', 'public.get_public_monthly_leaderboard(integer)', 'execute') INTO v_bool;
  res := res || ('T5 authenticated çağırabilir: ' || v_bool::text);

  PERFORM set_config('request.jwt.claims', '', true);
  SELECT name INTO v_txt FROM public.get_public_monthly_leaderboard(100) WHERE name LIKE 'Dry A%' LIMIT 1;
  res := res || ('T6 oturumsuz çağrıda ad maskeli (' || coalesce(v_txt, 'yok') || '): ' || coalesce((v_txt = 'Dry A.')::text, 'false'));

  RAISE EXCEPTION 'DRYRUN_RESULT >> %', array_to_string(res, ' || ');
END
$dry$;
