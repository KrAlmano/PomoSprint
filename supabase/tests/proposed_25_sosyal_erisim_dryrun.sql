-- ============================================================================
-- KURU ÇALIŞTIRMA: supabase/proposed/25_sosyal_erisim.sql
-- (canlıda hiçbir şeyi kalıcı DEĞİŞTİRMEZ)
-- Supabase Dashboard > SQL Editor'e yapıştırıp Run'a basın. Öneri bir
-- transaction içinde uygulanır, senaryolar sentetik kullanıcılarla
-- (@example.invalid) çalışır, en sonda bilinçli bir hata (DRYRUN_RESULT)
-- fırlatılır ve her şey geri alınır. Her maddenin sonu 'true' olmalı.
--
-- Not: Gövde 25_sosyal_erisim.sql ile birebir aynıdır (BEGIN/COMMIT hariç);
-- tool/local_supabase/proposed_chain_check.sh bunu denetler.
-- ============================================================================
BEGIN;

-- >>> ÖNERİ GÖVDESİ (supabase/proposed/25_sosyal_erisim.sql, BEGIN/COMMIT hariç, birebir) >>>

-- ---------------------------------------------------------------------------
-- 0) Ön koşul: 13 uygulanmış (generate_friend_code, app_config_int)
-- ---------------------------------------------------------------------------
DO $pre$
BEGIN
    IF to_regprocedure('public.generate_friend_code(integer)') IS NULL
       OR to_regprocedure('public.app_config_int(text)') IS NULL THEN
        RAISE EXCEPTION 'proposed/25 ön koşulu: önce zincir uygulanmalı (13: generate_friend_code, app_config).';
    END IF;
    IF to_regprocedure('public.rotate_friend_code()') IS NOT NULL THEN
        RAISE EXCEPTION 'proposed/25 ön koşulu: rotate_friend_code zaten var (25 uygulanmış görünüyor).';
    END IF;
END
$pre$;

-- ---------------------------------------------------------------------------
-- A) Lig tabloları yalnızca RPC ile (t3-LG5)
-- ---------------------------------------------------------------------------
REVOKE SELECT ON public.leagues FROM authenticated, anon;
REVOKE SELECT ON public.league_memberships FROM authenticated, anon;

-- ---------------------------------------------------------------------------
-- B) Arkadaş kodunu yenileme (t3-K1)
-- ---------------------------------------------------------------------------
CREATE TABLE public.friend_code_rotations (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    rotated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.friend_code_rotations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.friend_code_rotations FROM PUBLIC, anon, authenticated;
COMMENT ON TABLE public.friend_code_rotations IS
  'proposed/25: kullanıcının arkadaş kodunu son yenilediği an (24 saatte bir). Yalnızca rotate_friend_code.';

CREATE FUNCTION public.rotate_friend_code()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_last timestamptz;
    v_code text;
    v_length integer;
    v_constraint text;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

    PERFORM 1 FROM public.profiles WHERE id = v_uid FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

    SELECT r.rotated_at INTO v_last FROM public.friend_code_rotations r WHERE r.user_id = v_uid;
    IF v_last IS NOT NULL AND v_last > now() - interval '24 hours' THEN
        RETURN jsonb_build_object('success', false, 'code', 'rate_limited',
                                  'retry_after', v_last + interval '24 hours',
                                  'message', 'Arkadaş kodunu günde bir kez yenileyebilirsin.');
    END IF;

    v_length := coalesce(public.app_config_int('friend_code_length'), 6);
    FOR v_attempt IN 1..8 LOOP
        v_code := public.generate_friend_code(v_length);
        BEGIN
            UPDATE public.profiles SET friend_code = v_code WHERE id = v_uid;
            EXIT;
        EXCEPTION WHEN unique_violation THEN
            GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
            IF v_constraint IS DISTINCT FROM 'profiles_friend_code_key' OR v_attempt = 8 THEN
                RAISE;
            END IF;
        END;
    END LOOP;

    INSERT INTO public.friend_code_rotations (user_id, rotated_at)
    VALUES (v_uid, now())
    ON CONFLICT (user_id) DO UPDATE SET rotated_at = excluded.rotated_at;

    RETURN jsonb_build_object('success', true, 'code', 'rotated', 'friend_code', v_code);
END;
$function$;
REVOKE ALL ON FUNCTION public.rotate_friend_code() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rotate_friend_code() TO authenticated, service_role;

DO $$
BEGIN
    INSERT INTO supabase_migrations.schema_migrations (version, name)
    VALUES ('20261005125000', 'sosyal_erisim')
    ON CONFLICT (version) DO NOTHING;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişine yazılamadı: %', SQLERRM;
END $$;

-- <<< ÖNERİ GÖVDESİ SONU <<<

-- ---------------------------------------------------------------------------
-- Senaryolar
-- ---------------------------------------------------------------------------
DO $dry$
DECLARE
  res text[] := '{}';
  v_txt text;
  v_int integer;
  v_res jsonb;
  v_res2 jsonb;
  v_old text;
  ua uuid := gen_random_uuid();
  ub uuid := gen_random_uuid();
  c uuid;
  l uuid;
BEGIN
  INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role) VALUES
    (ua, 'dryrun25-a-' || ua || '@example.invalid', '{"name":"Dry Sosyal A"}', 'authenticated', 'authenticated'),
    (ub, 'dryrun25-b-' || ub || '@example.invalid', '{"name":"Dry Sosyal B"}', 'authenticated', 'authenticated');
  INSERT INTO public.leagues (tier, end_date) VALUES (1, now() + interval '5 days') RETURNING id INTO l;
  INSERT INTO public.league_memberships (league_id, user_id, weekly_points) VALUES (l, ub, 7);

  -- ======================= t3-LG5 =======================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_txt := '';
  BEGIN PERFORM count(*) FROM public.leagues;
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLSTATE || '|'; END;
  BEGIN PERFORM count(*) FROM public.league_memberships;
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLSTATE || '|'; END;
  c := public.create_category('Dry Lig Ders', '#123456', 'book');
  v_res := public.complete_study_session(gen_random_uuid(), c, 25, false, 1500, now() - interval '30 minutes');
  EXECUTE 'RESET ROLE';
  res := res || ('T01 authenticated leagues ve league_memberships''i doğrudan okuyamaz (' || v_txt || '): '
                 || (v_txt = '42501|42501|')::text);
  res := res || ('T02 seans yine lig puanı yazar (RPC SECURITY DEFINER): '
                 || coalesce((v_res->>'league_points')::int = 5
                             AND (SELECT weekly_points FROM public.league_memberships WHERE user_id = ua) = 5, false)::text);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', ub, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  SELECT count(*), max(weekly_points) INTO v_int, v_txt FROM public.get_my_league_ranking();
  EXECUTE 'RESET ROLE';
  res := res || ('T03 get_my_league_ranking çalışır: ' || coalesce(v_int >= 1 AND v_txt::int >= 7, false)::text);
  res := res || ('T04 anon lig tablolarını da okuyamaz: '
                 || (NOT has_table_privilege('anon', 'public.leagues', 'SELECT')
                     AND NOT has_table_privilege('anon', 'public.league_memberships', 'SELECT')
                     AND NOT has_table_privilege('authenticated', 'public.leagues', 'SELECT')
                     AND NOT has_table_privilege('authenticated', 'public.league_memberships', 'SELECT'))::text);

  -- ======================= t3-K1: kodu yenile =======================
  SELECT friend_code INTO v_old FROM public.profiles WHERE id = ua;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_res := public.rotate_friend_code();
  v_res2 := public.rotate_friend_code();
  EXECUTE 'RESET ROLE';
  res := res || ('T05 kod yenilenir (Crockford, ' || coalesce(v_res->>'friend_code', '-') || '), 24 saat içinde ikinci deneme rate_limited: '
                 || coalesce((v_res->>'success')::boolean AND v_res->>'code' = 'rotated'
                             AND v_res->>'friend_code' ~ '^[0-9A-HJKMNP-TV-Z]{6,8}$'
                             AND v_res->>'friend_code' <> v_old
                             AND (SELECT friend_code FROM public.profiles WHERE id = ua) = v_res->>'friend_code'
                             AND NOT (v_res2->>'success')::boolean AND v_res2->>'code' = 'rate_limited', false)::text);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', ub, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_res2 := public.add_friend_by_code(v_old);
  v_txt := public.add_friend_by_code(v_res->>'friend_code')->>'code';
  EXECUTE 'RESET ROLE';
  res := res || ('T06 eski kod artık bulunamaz, yeni kod çalışır: '
                 || coalesce(v_res2->>'code' = 'not_found' AND v_txt = 'request_sent', false)::text);

  UPDATE public.friend_code_rotations SET rotated_at = now() - interval '25 hours' WHERE user_id = ua;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_res2 := public.rotate_friend_code();
  EXECUTE 'RESET ROLE';
  res := res || ('T07 24 saat sonra yeniden yenilenebilir; bekleyen istek korunur: '
                 || coalesce((v_res2->>'success')::boolean
                             AND EXISTS (SELECT 1 FROM public.friendships WHERE user_id = ub AND friend_id = ua AND status = 'pending'), false)::text);

  res := res || ('T08 yetkiler: rotate_friend_code yalnız authenticated, tablo API rollerine kapalı: '
                 || (has_function_privilege('authenticated', 'public.rotate_friend_code()', 'EXECUTE')
                     AND NOT has_function_privilege('anon', 'public.rotate_friend_code()', 'EXECUTE')
                     AND NOT has_table_privilege('authenticated', 'public.friend_code_rotations', 'SELECT'))::text);
  SELECT count(*) INTO v_int FROM supabase_migrations.schema_migrations WHERE version = '20261005125000';
  res := res || ('T09 migration geçmişine yazıldı: ' || (v_int = 1)::text);

  RAISE EXCEPTION 'DRYRUN_RESULT >> %', array_to_string(res, ' || ');
END
$dry$;

ROLLBACK;
