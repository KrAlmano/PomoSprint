-- ============================================================================
-- YEREL BULGU YENİDEN ÜRETİMİ: test ajanlarının sunucu bulguları (5 Ekim 2026)
-- ve supabase/proposed/20–25 önerileri. YALNIZCA YEREL kopyada çalıştırın;
-- her şey tek bir transaction'da yapılır ve sonda ROLLBACK edilir (kalıcı
-- hiçbir şey yazılmaz). Eşzamanlılık bulguları (t1-01, t2-07, t4-F1, t4-F7)
-- ayrı: proposed_20_25_race_local.sh.
--
-- Aynı dosya üç durumda çalışır ve her bulgu için 'BUG' / 'düzgün' yazar:
--   canlı = ana yerel kopya:
--     psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -X -f supabase/tests/proposed_20_25_bulgu_repro_local.sql
--   zincir (12 → 15 → 16 → 19 → 13 → 14) ve zincir + 20–25:
--     UNTIL=14 KEEP_DB=1 CHAIN_DB=pomosprint_chain tool/local_supabase/proposed_chain_check.sh
--     psql postgresql://postgres:postgres@127.0.0.1:54322/pomosprint_chain -X -f supabase/tests/proposed_20_25_bulgu_repro_local.sql
--
-- process_weekly_leagues'i çağıran senaryolar kopyadaki bitmiş TÜM ligleri de
-- işler; işlem geri alındığı için kalıcı değildir.
-- ============================================================================
\set ON_ERROR_STOP on
\pset pager off
BEGIN;
SET LOCAL client_min_messages = warning;

CREATE TEMP TABLE rr (seq serial, id text, durum text, ayrinti text) ON COMMIT DROP;

CREATE FUNCTION pg_temp.u(p_tag text, p_meta jsonb DEFAULT '{"name":"Repro Kisi"}',
                          p_provider text DEFAULT 'email', p_email text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v uuid := gen_random_uuid();
BEGIN
  INSERT INTO auth.users (id, email, raw_user_meta_data, raw_app_meta_data, aud, role)
  VALUES (v, coalesce(p_email, 'repro-' || p_tag || '-' || left(v::text, 8) || '@example.invalid'), p_meta,
          jsonb_build_object('provider', p_provider, 'providers', jsonb_build_array(p_provider)),
          'authenticated', 'authenticated');
  RETURN v;
END $$;

CREATE FUNCTION pg_temp.as_(p uuid) RETURNS void LANGUAGE sql AS
$$ SELECT set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true) $$;

CREATE FUNCTION pg_temp.cat(p uuid, p_name text DEFAULT 'Repro Ders') RETURNS uuid LANGUAGE sql AS
$$ INSERT INTO public.categories (user_id, name, color_hex, icon_name) VALUES (p, p_name, '#123456', 'book') RETURNING id $$;

CREATE FUNCTION pg_temp.r(p_id text, p_bug boolean, p_detail text) RETURNS void LANGUAGE sql AS
$$ INSERT INTO rr (id, durum, ayrinti)
   VALUES (p_id, CASE WHEN p_bug IS NULL THEN 'BELİRSİZ' WHEN p_bug THEN 'BUG' ELSE 'düzgün' END, p_detail) $$;

CREATE FUNCTION pg_temp.info(p_id text, p_detail text) RETURNS void LANGUAGE sql AS
$$ INSERT INTO rr (id, durum, ayrinti) VALUES (p_id, 'bilgi', p_detail) $$;

-- ---------------------------------------------------------------- t1-02 / t3-L7
DO $$
DECLARE u uuid := pg_temp.u('t102'); v_err text; v_ends timestamptz; v_len int;
BEGIN
  PERFORM pg_temp.as_(u);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.start_study_session(100000, repeat('X', 5000));
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  SELECT active_session_ends_at, char_length(active_session_category_name) INTO v_ends, v_len
    FROM public.profiles WHERE id = u;
  PERFORM pg_temp.r('t1-02/t3-L7 start_study_session(100000, 5000 karakter)',
    v_err IS NULL AND (v_ends > now() + interval '51 minutes' OR v_len > 50),
    coalesce('reddedildi: ' || v_err, format('kabul: bitiş now+%s, ad %s karakter', date_trunc('minute', v_ends - now()), v_len)));
END $$;

-- ---------------------------------------------------------------- t1-05
DO $$
DECLARE u uuid := pg_temp.u('t105'); c uuid; v_day date; v_start timestamptz; r jsonb;
BEGIN
  v_day := ((now() AT TIME ZONE 'Europe/Istanbul') - interval '4 hours')::date;
  v_start := ((v_day + time '04:00') AT TIME ZONE 'Europe/Istanbul') - interval '30 minutes';
  IF v_start < now() - interval '23 hours 30 minutes' OR v_start + interval '25 minutes' > now() THEN
    PERFORM pg_temp.r('t1-05 geç gelen (önceki güne ait) seansın bonusu', NULL, 'saat 04:00 sınırına çok yakın, sonra tekrar deneyin');
    RETURN;
  END IF;
  UPDATE public.profiles SET current_streak = 3, longest_streak = 3, last_study_date = v_day WHERE id = u;
  c := pg_temp.cat(u);
  PERFORM pg_temp.as_(u);
  EXECUTE 'SET LOCAL ROLE authenticated';
  r := public.complete_study_session(gen_random_uuid(), c, 25, false, 1500, v_start);
  EXECUTE 'RESET ROLE';
  PERFORM pg_temp.r('t1-05 geç gelen (önceki güne ait) seansın bonusu (bugün seri 3, o gün en çok 2)',
    coalesce((r->>'bonus_pct')::int, 0) > 0,
    format('bonus_pct=%s bonus_points=%s total=%s streak=%s', r->>'bonus_pct', r->>'bonus_points', r->>'total_points', r->>'streak'));
END $$;

-- ---------------------------------------------------------------- t1-06
DO $$
DECLARE v_sun interval; v_mon interval;
BEGIN
  SELECT ((date_trunc('week', ('2026-10-11 23:50+03'::timestamptz AT TIME ZONE 'Europe/Istanbul')::date::timestamp)
           + interval '13 days') + time '23:59:59') AT TIME ZONE 'Europe/Istanbul' - '2026-10-11 23:50+03'::timestamptz,
         ((date_trunc('week', ('2026-10-05 00:30+03'::timestamptz AT TIME ZONE 'Europe/Istanbul')::date::timestamp)
           + interval '13 days') + time '23:59:59') AT TIME ZONE 'Europe/Istanbul' - '2026-10-05 00:30+03'::timestamptz
    INTO v_sun, v_mon;
  PERFORM pg_temp.info('t1-06 yeni oda süresi (ensure_user_in_league ifadesi)',
    format('Pazar 23:50 açılan oda %s, Pazartesi 00:30 açılan oda %s sürer (ilk dönem 7–14 gün; ürün kararı / belge)', v_sun, v_mon));
END $$;

-- ---------------------------------------------------------------- t1-07
DO $$
DECLARE u uuid := pg_temp.u('t107'); c uuid; v_err text;
BEGIN
  c := pg_temp.cat(u);
  PERFORM pg_temp.as_(u);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.complete_study_session(gen_random_uuid(), c, 25, false, 1500, now() - interval '24 hours 1 minute');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  PERFORM pg_temp.info('t1-07 24 saatten eski seans', coalesce('reddedildi: ' || v_err, 'kabul edildi') || ' (bilinçli kural; ürün kararı)');
END $$;

-- ---------------------------------------------------------------- t1-08
DO $$
DECLARE v text;
BEGIN
  SELECT string_agg(p.proname || '=' || coalesce(array_to_string(p.proconfig, ','), ''), '; ' ORDER BY p.proname) INTO v
    FROM pg_proc p
   WHERE p.pronamespace = 'public'::regnamespace AND p.prosecdef
     AND NOT EXISTS (SELECT 1 FROM unnest(coalesce(p.proconfig, '{}')) c WHERE c LIKE 'search_path=%pg_temp%');
  PERFORM pg_temp.r('t1-08 search_path''inde pg_temp olmayan SECURITY DEFINER', v IS NOT NULL, coalesce(v, 'yok'));
END $$;

-- ---------------------------------------------------------------- t2-01
DO $$
DECLARE u uuid := pg_temp.u('t201', '{"name":"Repro Gorunurluk"}'); v_show boolean;
BEGIN
  PERFORM pg_temp.as_(u);
  EXECUTE 'SET LOCAL ROLE authenticated';
  -- show_in_social_feed GÖNDERİLMEYEN onboarding PATCH'i (taslaktan dönen istemci)
  UPDATE public.profiles SET birth_year = 2000, daily_goal_minutes = 60, onboarding_completed_at = now() WHERE id = u;
  EXECUTE 'RESET ROLE';
  SELECT show_in_social_feed INTO v_show FROM public.profiles WHERE id = u;
  PERFORM pg_temp.r('t2-01 görünürlük seçilmeden biten onboarding', v_show, 'show_in_social_feed=' || v_show);
END $$;

-- ---------------------------------------------------------------- t2-03
DO $$
DECLARE u uuid := pg_temp.u('t203a'); v_err text; v_active text; v_bug boolean;
BEGIN
  PERFORM pg_temp.as_(u);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.setup_onboarding_categories(
      '[{"name":"Matematik","color_hex":"#2196F3","icon_name":"calculate"},{"name":"Fizik","color_hex":"#F44336","icon_name":"science"},
        {"name":"Kimya","color_hex":"#4CAF50","icon_name":"biotech"},{"name":"Biyoloji","color_hex":"#8BC34A","icon_name":"biotech"},
        {"name":"Türkçe","color_hex":"#FF9800","icon_name":"menu_book"},{"name":"Tarih","color_hex":"#795548","icon_name":"book"},
        {"name":"Coğrafya","color_hex":"#009688","icon_name":"language"},{"name":"Felsefe","color_hex":"#9C27B0","icon_name":"book"}]');
    -- profil PATCH'i zaman aşımına uğradı (onboarding_completed_at NULL); kullanıcı 'work'ü seçip yeniden bitirir
    PERFORM public.setup_onboarding_categories(
      '[{"name":"Derin Çalışma","color_hex":"#3F51B5","icon_name":"book"},{"name":"Okuma","color_hex":"#FF5722","icon_name":"menu_book"},
        {"name":"Öğrenme","color_hex":"#00BCD4","icon_name":"language"},{"name":"Proje","color_hex":"#607D8B","icon_name":"calculate"}]');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  SELECT string_agg(name, ', ' ORDER BY sort_order, name) INTO v_active FROM public.categories WHERE user_id = u AND NOT is_archived;
  v_bug := v_err IS NOT NULL OR (SELECT count(*) FROM public.categories WHERE user_id = u AND NOT is_archived
                                   AND name IN ('Derin Çalışma', 'Okuma', 'Öğrenme', 'Proje')) < 4
           OR EXISTS (SELECT 1 FROM public.categories WHERE user_id = u AND NOT is_archived AND name = 'Fizik');
  PERFORM pg_temp.r('t2-03a yeniden denenen onboarding (YKS 8 → work 4)', v_bug, coalesce('hata: ' || v_err, 'aktif: ' || v_active));
END $$;

DO $$
DECLARE u uuid := pg_temp.u('t203b'); v_err text; v_active text;
BEGIN
  PERFORM pg_temp.as_(u);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.setup_onboarding_categories(
      '[{"name":"Matematik","color_hex":"#2196F3","icon_name":"calculate"},{"name":"Fen Bilimleri","color_hex":"#4CAF50","icon_name":"science"},
        {"name":"Türkçe","color_hex":"#FF9800","icon_name":"menu_book"}]');
    PERFORM public.setup_onboarding_categories(
      '[{"name":"Mathematics","color_hex":"#2196F3","icon_name":"calculate"},{"name":"Science","color_hex":"#4CAF50","icon_name":"science"}]');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  SELECT string_agg(name, ', ' ORDER BY sort_order, name) INTO v_active FROM public.categories WHERE user_id = u AND NOT is_archived;
  PERFORM pg_temp.r('t2-03b dil değişince TR + EN çift kategori',
    v_err IS NOT NULL OR EXISTS (SELECT 1 FROM public.categories WHERE user_id = u AND NOT is_archived AND name = 'Matematik'),
    coalesce('hata: ' || v_err, 'aktif: ' || v_active));
END $$;

-- ---------------------------------------------------------------- t2-04
DO $$
DECLARE u uuid := pg_temp.u('t204'); v_err text;
BEGIN
  PERFORM pg_temp.as_(u);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    UPDATE public.profiles SET user_segment = 'kpss' WHERE id = u;
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  PERFORM pg_temp.info('t2-04 KPSS segmenti', coalesce('reddedildi: ' || v_err, 'kabul edildi') || ' (ürün kararı)');
END $$;

-- ---------------------------------------------------------------- t2-05
DO $$
DECLARE u uuid := pg_temp.u('t205'); v_err text;
BEGIN
  PERFORM pg_temp.as_(u);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    UPDATE public.profiles SET birth_year = extract(year FROM now())::int - 5, daily_goal_minutes = 60,
                               show_in_social_feed = false, onboarding_completed_at = now()
     WHERE id = u;
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  PERFORM pg_temp.r('t2-05 5 yaşında doğum yılıyla onboarding', v_err IS NULL, coalesce('reddedildi: ' || v_err, 'kabul edildi'));
END $$;

-- ---------------------------------------------------------------- t2-06
DO $$
DECLARE u uuid := pg_temp.u('t206a'); v_err text; v_rows text; v_n int;
BEGIN
  PERFORM pg_temp.as_(u);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.setup_onboarding_categories(jsonb_build_array(
      jsonb_build_object('name', '', 'color_hex', '#111111', 'icon_name', 'book'),
      jsonb_build_object('name', '   ', 'color_hex', '#111111', 'icon_name', 'book'),
      jsonb_build_object('name', repeat('Y', 300), 'color_hex', '#111111', 'icon_name', 'book'),
      jsonb_build_object('name', 'RenkBozuk', 'color_hex', 'kirmizi', 'icon_name', '<script>'),
      jsonb_build_object('name', 'Gecerli Ders', 'color_hex', '#ABCDEF', 'icon_name', 'book')));
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  SELECT count(*), string_agg(left(name, 12) || '/' || color_hex || '/' || coalesce(icon_name, '-'), ', ') INTO v_n, v_rows
    FROM public.categories WHERE user_id = u;
  PERFORM pg_temp.r('t2-06a boş/boşluk/300 karakter ad, bozuk renk ve ikon',
    v_err IS NOT NULL OR EXISTS (SELECT 1 FROM public.categories WHERE user_id = u
                                  AND (btrim(name) = '' OR char_length(name) > 40 OR color_hex !~ '^#[0-9A-Fa-f]{6}$'
                                       OR icon_name !~ '^[a-z0-9_]{1,40}$')),
    coalesce('RPC tamamen düştü: ' || v_err, v_n || ' satır: ' || coalesce(v_rows, '-')));
END $$;

DO $$
DECLARE u uuid := pg_temp.u('t206b'); v_err text; v_rows text; v_n int;
BEGIN
  PERFORM pg_temp.as_(u);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.setup_onboarding_categories(
      '[{"name":"Matematik","color_hex":"#2196F3","icon_name":"calculate"},{"name":"matematik","color_hex":"#2196F3","icon_name":"calculate"},
        {"name":"Matematik ","color_hex":"#2196F3","icon_name":"calculate"}]');
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  SELECT count(*), string_agg('"' || name || '"', ', ') INTO v_n, v_rows FROM public.categories WHERE user_id = u AND NOT is_archived;
  PERFORM pg_temp.r('t2-06b Matematik / matematik / ''Matematik '' tek kategori olmalı',
    v_err IS NOT NULL OR v_n > 1, coalesce('RPC tamamen düştü: ' || v_err, v_n || ' aktif: ' || v_rows));
END $$;

DO $$
DECLARE u uuid := pg_temp.u('t206c'); v_err text; c uuid;
BEGIN
  c := pg_temp.cat(u, 'Matematik');
  PERFORM pg_temp.as_(u);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.create_category('MATEMATİK', 'kirmizi', '<script>');
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  PERFORM pg_temp.r('t2-06c create_category(''MATEMATİK'', ''kirmizi'', ''<script>'') (Matematik varken)',
    v_err IS NULL, coalesce('reddedildi: ' || v_err, 'kabul edildi'));
END $$;

-- ---------------------------------------------------------------- t2-08
DO $$
DECLARE u uuid := pg_temp.u('t208'); v_err text; v_tz text;
BEGIN
  PERFORM pg_temp.as_(u);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    UPDATE public.profiles SET timezone = 'Europe/Berlin' WHERE id = u;
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  SELECT timezone INTO v_tz FROM public.profiles WHERE id = u;
  PERFORM pg_temp.info('t2-08 istemci timezone yazabiliyor mu', coalesce('hayır: ' || v_err, 'evet, timezone=' || v_tz) || ' (eksik olan istemci yazımı)');
END $$;

-- ---------------------------------------------------------------- t3-AF1
DO $$
DECLARE a uuid := pg_temp.u('af1a'); b uuid := pg_temp.u('af1b'); v_n int; v_err text;
BEGIN
  INSERT INTO public.friendships (user_id, friend_id, status) VALUES (a, b, 'accepted'), (b, a, 'accepted');
  UPDATE public.profiles SET show_in_social_feed = true WHERE id = b;
  INSERT INTO public.activity_feed (user_id, activity_type, activity_date, payload)
  VALUES (b, 'daily_summary', current_date, '{"top_category":"Gizli Ders","session_count":1,"total_minutes":25}');
  UPDATE public.profiles SET show_in_social_feed = false WHERE id = b;
  PERFORM pg_temp.as_(a);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    SELECT count(*) INTO v_n FROM public.activity_feed WHERE user_id = b;
  EXCEPTION WHEN OTHERS THEN v_err := SQLSTATE || ' ' || SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  PERFORM pg_temp.r('t3-AF1 arkadaş, görünürlüğü kapalı kişinin activity_feed''ini okuyor', coalesce(v_n, 0) > 0,
    coalesce('okunamadı: ' || v_err, v_n || ' satır'));
END $$;

-- ---------------------------------------------------------------- t3-EM1
DO $$
DECLARE v_local text := 'repro.yilmaz.' || floor(random() * 1e6)::int; u uuid; v_name text;
BEGIN
  u := pg_temp.u('em1', '{}', 'apple', v_local || '@icloud.invalid');
  SELECT name INTO v_name FROM public.profiles WHERE id = u;
  PERFORM pg_temp.r('t3-EM1 ad bilgisi olmayan Apple hesabında ad = e-posta yerel kısmı', v_name = v_local,
    'profiles.name=' || v_name || ', maske: ' || coalesce(public.mask_public_name(v_name), '-'));
END $$;

-- ---------------------------------------------------------------- t3-K1
DO $$
DECLARE a uuid := pg_temp.u('k1a'); b uuid := pg_temp.u('k1b'); v_code text; r jsonb; v_rl boolean := false;
BEGIN
  SELECT friend_code INTO v_code FROM public.profiles WHERE id = b;
  PERFORM pg_temp.as_(a);
  EXECUTE 'SET LOCAL ROLE authenticated';
  r := public.add_friend_by_code(v_code);
  FOR i IN 1..25 LOOP
    IF public.add_friend_by_code('ZZZZZ' || i)->>'code' = 'rate_limited' THEN v_rl := true; END IF;
  END LOOP;
  EXECUTE 'RESET ROLE';
  PERFORM pg_temp.r('t3-K1 bekleyen istekte karşı tarafın id''si dönüyor', (r->'friend') ? 'id', r::text);
  PERFORM pg_temp.r('t3-K1 26 denemede hız sınırı yok', NOT v_rl, 'rate_limited görüldü=' || v_rl);
  PERFORM pg_temp.r('t3-K1 kodunu yenileme RPC''si yok', to_regprocedure('public.rotate_friend_code()') IS NULL,
    coalesce(to_regprocedure('public.rotate_friend_code()')::text, 'rotate_friend_code yok'));
END $$;

-- ---------------------------------------------------------------- t3-K2
DO $$
BEGIN
  PERFORM pg_temp.r('t3-K2 handle_new_user friend_code çakışmasında yeniden denemiyor',
    pg_get_functiondef('public.handle_new_user()'::regprocedure) NOT ILIKE '%profiles_friend_code_key%',
    'gövdede profiles_friend_code_key yakalama: '
      || (pg_get_functiondef('public.handle_new_user()'::regprocedure) ILIKE '%profiles_friend_code_key%')::text);
END $$;

-- ---------------------------------------------------------------- t3-LG5
DO $$
DECLARE a uuid := pg_temp.u('lg5a'); b uuid := pg_temp.u('lg5b'); e uuid := pg_temp.u('lg5e'); l uuid;
        v_m int; v_l int; v_err1 text; v_err2 text;
BEGIN
  INSERT INTO public.leagues (tier, end_date) VALUES (1, now() + interval '5 days') RETURNING id INTO l;
  INSERT INTO public.league_memberships (league_id, user_id, weekly_points) VALUES (l, a, 5), (l, b, 7);
  PERFORM pg_temp.as_(a);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    SELECT count(*) INTO v_m FROM public.league_memberships WHERE user_id = b;
  EXCEPTION WHEN OTHERS THEN v_err1 := SQLSTATE;
  END;
  EXECUTE 'RESET ROLE';
  PERFORM pg_temp.as_(e);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    SELECT count(*) INTO v_l FROM public.leagues;
  EXCEPTION WHEN OTHERS THEN v_err2 := SQLSTATE;
  END;
  EXECUTE 'RESET ROLE';
  PERFORM pg_temp.r('t3-LG5 oda arkadaşının league_memberships satırı (user_id) doğrudan okunuyor', coalesce(v_m, 0) > 0,
    coalesce('okunamadı: ' || v_err1, v_m || ' satır'));
  PERFORM pg_temp.r('t3-LG5 ligi olmayan kullanıcı tüm leagues satırlarını okuyor', coalesce(v_l, 0) > 0,
    coalesce('okunamadı: ' || v_err2, v_l || ' satır'));
END $$;

-- ---------------------------------------------------------------- t3-F14
DO $$
DECLARE a uuid := pg_temp.u('f14a'); c uuid := pg_temp.u('f14c'); v_code text; r1 jsonb; r2 jsonb; r3 jsonb;
BEGIN
  SELECT friend_code INTO v_code FROM public.profiles WHERE id = a;
  PERFORM pg_temp.as_(c);
  EXECUTE 'SET LOCAL ROLE authenticated';
  r1 := public.add_friend_by_code(v_code);
  EXECUTE 'RESET ROLE';
  PERFORM pg_temp.as_(a);
  EXECUTE 'SET LOCAL ROLE authenticated';
  r2 := public.respond_friend_request(c, false);
  EXECUTE 'RESET ROLE';
  PERFORM pg_temp.as_(c);
  EXECUTE 'SET LOCAL ROLE authenticated';
  r3 := public.add_friend_by_code(v_code);
  EXECUTE 'RESET ROLE';
  PERFORM pg_temp.r('t3-F14 reddedilen kişi hemen yeniden istek gönderebiliyor', (r3->>'success')::boolean,
    'ret: ' || r2::text || ' / yeniden: ' || r3::text);
END $$;

-- ---------------------------------------------------------------- t4-F2 / t4-F10 / t4-F8
DO $$
DECLARE l2 uuid; l1 uuid; u uuid; p1 uuid; v_end timestamptz; v_joined timestamptz; v_pos int; v_demo int; v_n int;
BEGIN
  -- tier-2 odası, öbür hafta paritesinde (bitişine 7 gün var), 12 üye 10..120 puan
  INSERT INTO public.leagues (tier, start_date, end_date) VALUES (2, '2000-01-01', now() + interval '7 days') RETURNING id INTO l2;
  FOR i IN 1..12 LOOP
    u := pg_temp.u('f2t' || i);
    UPDATE public.profiles SET league_tier = 2 WHERE id = u;
    INSERT INTO public.league_memberships (league_id, user_id, weekly_points, joined_at)
    VALUES (l2, u, 10 * i, now() - interval '7 days' + make_interval(mins => i));
  END LOOP;
  -- tier-1 odası, şimdi bitti; 3 üye 29/28/27 puan → ilk 2 terfi
  INSERT INTO public.leagues (tier, start_date, end_date) VALUES (1, '2000-01-01', now() - interval '1 minute') RETURNING id INTO l1;
  FOR i IN 1..3 LOOP
    u := pg_temp.u('f2p' || i);
    IF i = 1 THEN p1 := u; END IF;
    INSERT INTO public.league_memberships (league_id, user_id, weekly_points, joined_at)
    VALUES (l1, u, 30 - i, now() - interval '13 days');
  END LOOP;
  PERFORM public.process_weekly_leagues();
  SELECT l.end_date, lm.joined_at INTO v_end, v_joined
    FROM public.league_memberships lm JOIN public.leagues l ON l.id = lm.league_id WHERE lm.user_id = p1;
  PERFORM pg_temp.as_(p1);
  EXECUTE 'SET LOCAL ROLE authenticated';
  SELECT x.pos, x.demotion_zone_start, x.member_count INTO v_pos, v_demo, v_n
    FROM (SELECT row_number() OVER () AS pos, r.* FROM public.get_my_league_ranking() r) x WHERE x.is_me;
  EXECUTE 'RESET ROLE';
  PERFORM pg_temp.r('t4-F2 terfi eden yarılanmış (7 gün kalan) üst kademe odasına giriyor', v_end - now() < interval '13 days',
    format('oda bitişi now+%s; sıra %s/%s, düşme sınırı %s', date_trunc('hour', v_end - now()), v_pos, v_n, v_demo));
  PERFORM pg_temp.r('t4-F10 taşınan üyenin joined_at''ı eski kalıyor', v_joined < now() - interval '1 day',
    'joined_at=now-' || date_trunc('hour', now() - v_joined));
  PERFORM pg_temp.r('t4-F8 league_promotion activity_date UTC tarihinden',
    pg_get_functiondef('public.process_weekly_leagues()'::regprocedure) ILIKE '%(v_new_period_start - interval ''1 day'')::date%',
    'gövdede (now() - 1 gün)::date: '
      || (pg_get_functiondef('public.process_weekly_leagues()'::regprocedure) ILIKE '%(v_new_period_start - interval ''1 day'')::date%')::text);
END $$;

-- ---------------------------------------------------------------- t4-F3
DO $$
DECLARE l uuid; d1 uuid := pg_temp.u('f3d1'); v_tier int; v_aw text; v_knobs text := 'düğme yok';
BEGIN
  IF to_regclass('public.app_config') IS NOT NULL THEN
    EXECUTE $q$SELECT coalesce(string_agg(key || '=' || value::text, ', ' ORDER BY key), 'düğme yok')
                 FROM public.app_config WHERE key LIKE 'league_%'$q$ INTO v_knobs;
  END IF;
  UPDATE public.profiles SET league_tier = 4 WHERE id = d1;
  INSERT INTO public.leagues (tier, start_date, end_date) VALUES (4, '2000-01-01', now() - interval '1 minute') RETURNING id INTO l;
  INSERT INTO public.league_memberships (league_id, user_id, weekly_points) VALUES (l, d1, 5);
  PERFORM public.process_weekly_leagues();
  SELECT league_tier INTO v_tier FROM public.profiles WHERE id = d1;
  SELECT string_agg(avatar_id, ',') INTO v_aw FROM public.avatar_unlocks WHERE user_id = d1 AND unlock_type = 'league_award';
  PERFORM pg_temp.r('t4-F3 tek üyeli odada 5 puanla şampiyonluk + terfi (varsayılan ayarla)', v_tier = 5 AND v_aw IS NOT NULL,
    format('tier=%s ödül=%s; %s (proposed/20: düğmeler varsayılan bugünkü kural, ürün kararıyla 3/25/25)', v_tier, coalesce(v_aw, '-'), v_knobs));
END $$;

-- ---------------------------------------------------------------- t4-F4
DO $$
DECLARE l uuid; p uuid := pg_temp.u('f4p'); c uuid; e timestamptz := now() - interval '30 minutes'; r jsonb; v_before int; v_after int;
BEGIN
  c := pg_temp.cat(p);
  INSERT INTO public.leagues (tier, start_date, end_date) VALUES (1, '2000-01-01', e) RETURNING id INTO l;
  INSERT INTO public.league_memberships (league_id, user_id, weekly_points, joined_at) VALUES (l, p, 3, now() - interval '13 days');
  PERFORM public.process_weekly_leagues();
  SELECT weekly_points INTO v_before FROM public.league_memberships WHERE user_id = p;
  PERFORM pg_temp.as_(p);
  EXECUTE 'SET LOCAL ROLE authenticated';
  r := public.complete_study_session(gen_random_uuid(), c, 25, false, 1500, e - interval '35 minutes');
  EXECUTE 'RESET ROLE';
  SELECT weekly_points INTO v_after FROM public.league_memberships WHERE user_id = p;
  PERFORM pg_temp.r('t4-F4 önceki dönemde biten, cron''dan sonra gelen seans yeni döneme yazılıyor', v_after > v_before,
    format('yeni dönem puanı %s → %s; league_period_closed=%s', v_before, v_after, coalesce(r->>'league_period_closed', '-')));
END $$;

-- ---------------------------------------------------------------- t4-F5
DO $$
DECLARE rg uuid; x uuid := pg_temp.u('f5x'); z uuid := pg_temp.u('f5z'); cx uuid; cz uuid; v_x int; v_zl uuid; v_carry text;
BEGIN
  UPDATE public.profiles SET league_tier = 4 WHERE id IN (x, z);
  cx := pg_temp.cat(x); cz := pg_temp.cat(z);
  INSERT INTO public.leagues (tier, start_date, end_date) VALUES (4, '1990-01-01', now() - interval '30 seconds') RETURNING id INTO rg;
  INSERT INTO public.league_memberships (league_id, user_id, weekly_points, joined_at) VALUES (rg, x, 0, now() - interval '13 days');
  PERFORM pg_temp.as_(x);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.complete_study_session(gen_random_uuid(), cx, 25, false, 1500, now() - interval '25 minutes');
  EXECUTE 'RESET ROLE';
  PERFORM pg_temp.as_(z);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.complete_study_session(gen_random_uuid(), cz, 25, false, 1500, now() - interval '25 minutes');
  EXECUTE 'RESET ROLE';
  SELECT weekly_points INTO v_x FROM public.league_memberships WHERE user_id = x AND league_id = rg;
  SELECT league_id INTO v_zl FROM public.league_memberships WHERE user_id = z;
  v_carry := CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public'
                                 AND table_name = 'league_memberships' AND column_name = 'carry_points')
                  THEN (SELECT 'carry=' || (to_jsonb(lm)->>'carry_points') FROM public.league_memberships lm WHERE lm.user_id = x)
                  ELSE 'carry yok' END;
  PERFORM pg_temp.r('t4-F5 bitmiş (işlenmemiş) odaya, bitişten sonra biten seansın puanı yazılıyor', v_x > 0,
    format('eski oda puanı %s; %s', v_x, v_carry));
  PERFORM pg_temp.r('t4-F5 yeni kullanıcı bitmiş odaya yerleşiyor', v_zl = rg, 'z odası = bitmiş oda: ' || (v_zl = rg)::text);
END $$;

-- ---------------------------------------------------------------- t4-F6
DO $$
DECLARE u uuid := pg_temp.u('f6'); v_n int; v_cnt int;
BEGIN
  PERFORM pg_temp.as_(u);
  EXECUTE 'SET LOCAL ROLE authenticated';
  SELECT count(*), max(r.member_count) INTO v_cnt, v_n FROM public.get_my_league_ranking() r;
  EXECUTE 'RESET ROLE';
  PERFORM pg_temp.r('t4-F6 ligsiz satır tek kişilik gerçek odayla aynı (member_count=1)', v_n = 1,
    format('%s satır, member_count=%s', v_cnt, v_n));
END $$;

-- ---------------------------------------------------------------- t4-F9
DO $$
DECLARE u uuid := pg_temp.u('f9'); v_err text;
BEGIN
  INSERT INTO public.avatars (id, name_tr, name_en, asset_key, cost_coins, is_default, is_active)
  VALUES ('repro_new_default', 'Yeni', 'New', 'avatar_16_basic.png', 0, true, true);
  PERFORM pg_temp.as_(u);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.set_equipped_avatar('repro_new_default');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  PERFORM pg_temp.r('t4-F9 sonradan eklenen varsayılan avatar kuşanılamıyor', v_err IS NOT NULL, coalesce('hata: ' || v_err, 'kuşanıldı'));
END $$;

SELECT id AS bulgu, durum, ayrinti FROM rr ORDER BY seq;
ROLLBACK;
