-- ============================================================================
-- KURU ÇALIŞTIRMA: supabase/proposed/20_lig_donemi.sql
-- (canlıda hiçbir şeyi kalıcı DEĞİŞTİRMEZ)
-- Supabase Dashboard > SQL Editor'e yapıştırıp Run'a basın. Öneri bir
-- transaction içinde uygulanır, senaryolar sentetik kullanıcılar
-- (@example.invalid) ve sentetik liglerle çalışır, en sonda bilinçli bir hata
-- (DRYRUN_RESULT) fırlatılır ve her şey geri alınır. Hata mesajındaki her
-- maddenin sonu 'true' olmalı.
--
-- SIRA: zincir (12 → 15 → 16 → 19 → 13 → 14) uygulandıktan SONRA, 20'den
-- ÖNCE. Zincir eksikse ya da gövdeler farklıysa 'proposed/20 ön koşulu: ...'
-- hatası görürsünüz.
--
-- Notlar
--  * process_weekly_leagues birkaç kez çağrılır: dönemi bitmiş (işlenmemiş)
--    GERÇEK ligler varsa onlar da işlenmiş görünür; işlem geri alındığı için
--    kalıcı değildir. Cron'un çalıştığı dakikada (Pazartesi 00:01 TR)
--    çalıştırmayın.
--  * ops.activity_feed_enabled() (14) T07 için işlem içinde geçici olarak
--    true yapılır; geri alınır.
--  * Gövde 20_lig_donemi.sql ile birebir aynıdır (BEGIN/COMMIT hariç);
--    tool/local_supabase/proposed_chain_check.sh bunu denetler.
-- ============================================================================
BEGIN;

-- >>> ÖNERİ GÖVDESİ (supabase/proposed/20_lig_donemi.sql, BEGIN/COMMIT hariç, birebir) >>>

-- ---------------------------------------------------------------------------
-- 0) Ön koşul: zincir (13, 14) uygulanmış ve gövdeler beklenen hâlde mi?
-- ---------------------------------------------------------------------------
DO $pre$
DECLARE
    v_expected constant jsonb := '{
        "ensure_user_in_league(uuid,integer)": "a2cfcc948e79cb5263f79b40e4b10df6",
        "process_weekly_leagues()": "3d547d20a94f32e3cf531a7c3888d536",
        "get_league_ranking(uuid)": "b78d3d06e5c4e7823a72a870cd79a0ef"
    }';
    r record;
    v_bad text[] := '{}';
BEGIN
    IF to_regclass('public.app_config') IS NULL
       OR to_regprocedure('public.app_config_int(text)') IS NULL
       OR to_regclass('public.user_blocks') IS NULL
       OR NOT EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_schema = 'public' AND table_name = 'league_memberships'
                         AND column_name = 'period_started_at') THEN
        RAISE EXCEPTION 'proposed/20 ön koşulu: önce zincir uygulanmalı (12 → 15 → 16 → 19 → 13 → 14).';
    END IF;
    FOR r IN SELECT key, value FROM jsonb_each_text(v_expected) LOOP
        IF to_regprocedure('public.' || r.key) IS NULL
           OR md5(pg_get_functiondef(to_regprocedure('public.' || r.key))) IS DISTINCT FROM r.value THEN
            v_bad := v_bad || r.key;
        END IF;
    END LOOP;
    IF array_length(v_bad, 1) > 0 THEN
        RAISE EXCEPTION 'proposed/20 ön koşulu: canlı tanım beklenenden farklı: %. Dosyayı yeni gövdeye uyarlayın.',
            array_to_string(v_bad, ', ');
    END IF;
END
$pre$;

-- ---------------------------------------------------------------------------
-- A) carry_points ve ürün düğmeleri
-- ---------------------------------------------------------------------------
ALTER TABLE public.league_memberships ADD COLUMN carry_points integer NOT NULL DEFAULT 0;
COMMENT ON COLUMN public.league_memberships.carry_points IS
  'proposed/20: bitmiş ama dönem sonu işlenmemiş odadaki üyenin, oda bitişinden SONRA biten seanslarının lig puanı. process_weekly_leagues yeni dönemi bununla başlatır.';

INSERT INTO public.app_config (key, value, is_public, description) VALUES
  ('league_award_min_members', '1', true,
   't4-F3: lig ödülü avatarı için odadaki en az üye sayısı (dönem sonunda). 1 = bugünkü kural. Önerilen 3.'),
  ('league_award_min_points', '1', true,
   't4-F3: lig ödülü avatarı için en az dönem puanı. 1 = bugünkü kural (puanı > 0). Önerilen 25.'),
  ('league_promotion_min_points', '1', true,
   't4-F3: terfi için en az dönem puanı. 1 = bugünkü kural (puanı > 0). Önerilen 25.')
ON CONFLICT (key) DO NOTHING;

-- ---------------------------------------------------------------------------
-- B) ensure_user_in_league: kilitli yerleştirme, bitmiş odaya yerleştirme yok
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- C) process_weekly_leagues
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- D) get_league_ranking: ligsiz satırda member_count = 0 (proposed/14 gövdesi)
-- ---------------------------------------------------------------------------
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

-- ---------------------------------------------------------------------------
-- E) Yetkiler (CREATE OR REPLACE korur; zincirdeki hâl açıkça yazılır)
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.ensure_user_in_league(uuid, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_user_in_league(uuid, integer) TO service_role;
REVOKE ALL ON FUNCTION public.process_weekly_leagues() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_weekly_leagues() TO service_role;
REVOKE ALL ON FUNCTION public.get_league_ranking(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_league_ranking(uuid) TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- F) Migration geçmişi
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    INSERT INTO supabase_migrations.schema_migrations (version, name)
    VALUES ('20261005120000', 'lig_donemi')
    ON CONFLICT (version) DO NOTHING;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişine yazılamadı: %', SQLERRM;
END $$;

-- <<< ÖNERİ GÖVDESİ SONU <<<

-- ---------------------------------------------------------------------------
-- Senaryolar
-- ---------------------------------------------------------------------------
CREATE FUNCTION pg_temp.d20_user(p_tag text, p_tier integer DEFAULT 1) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v uuid := gen_random_uuid();
BEGIN
  INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
  VALUES (v, 'dryrun20-' || p_tag || '-' || v || '@example.invalid', '{"name":"Dry Lig"}', 'authenticated', 'authenticated');
  UPDATE public.profiles SET league_tier = p_tier WHERE id = v;
  RETURN v;
END $$;

CREATE FUNCTION pg_temp.d20_as(p uuid) RETURNS void LANGUAGE sql AS
$$ SELECT set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true) $$;

CREATE FUNCTION pg_temp.d20_member(p_league uuid, p_user uuid, p_points integer, p_joined timestamptz, p_carry integer DEFAULT 0)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO public.league_memberships (league_id, user_id, weekly_points, joined_at, carry_points)
  VALUES (p_league, p_user, p_points, p_joined, p_carry)
$$;

DO $dry$
DECLARE
  res text[] := '{}';
  v_int integer;
  v_int2 integer;
  v_bool boolean;
  v_ts timestamptz;
  v_txt text;
  v_league uuid;
  v_league2 uuid;
  u uuid;
  ua uuid; ub uuid;
  p1 uuid; p2 uuid; p3 uuid;
  d1 uuid; e1 uuid; f1 uuid; f2 uuid; f3 uuid; g1 uuid; h1 uuid; un uuid;
  l_cap uuid := gen_random_uuid();
  l_ended uuid := gen_random_uuid();
  l_t2 uuid := gen_random_uuid();
  l_t1 uuid := gen_random_uuid();
  l_t4 uuid := gen_random_uuid();
  l_k1 uuid := gen_random_uuid();
  l_k3 uuid := gen_random_uuid();
  l_c uuid := gen_random_uuid();
  l_c2 uuid := gen_random_uuid();
  v_end1 timestamptz := now() - interval '1 minute';
BEGIN
  -- ======================= Şema ve düğmeler =======================
  SELECT count(*) INTO v_int FROM public.app_config
   WHERE key IN ('league_award_min_members', 'league_award_min_points', 'league_promotion_min_points')
     AND value = '1'::jsonb;
  SELECT column_default = '0' AND is_nullable = 'NO' INTO v_bool
    FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'league_memberships' AND column_name = 'carry_points';
  res := res || ('T01 carry_points (varsayılan 0) ve üç düğme (= 1, bugünkü kural): ' || coalesce(v_bool AND v_int = 3, false)::text);

  -- ======================= ensure_user_in_league =======================
  -- 29 üyeli tier-2 odası (en eski başlangıç → ilk aday)
  INSERT INTO public.leagues (id, tier, start_date, end_date) VALUES (l_cap, 2, '1980-01-01', now() + interval '10 days');
  FOR i IN 1..29 LOOP
    PERFORM pg_temp.d20_member(l_cap, pg_temp.d20_user('cap' || i, 2), i, now() - interval '3 days');
  END LOOP;
  ua := pg_temp.d20_user('capa', 2);
  ub := pg_temp.d20_user('capb', 2);
  PERFORM pg_temp.d20_as(ua);
  PERFORM public.ensure_user_in_league(ua, 5);
  PERFORM pg_temp.d20_as(ub);
  PERFORM public.ensure_user_in_league(ub, 5);
  SELECT count(*) INTO v_int FROM public.league_memberships WHERE league_id = l_cap;
  SELECT league_id INTO v_league FROM public.league_memberships WHERE user_id = ub;
  res := res || ('T02 29 üyeli oda 30''a dolar, sonraki yeni kullanıcı başka odaya (' || v_int || '): '
                 || coalesce(v_int = 30 AND v_league <> l_cap, false)::text);

  SELECT EXISTS (SELECT 1 FROM pg_locks
                  WHERE locktype = 'advisory' AND pid = pg_backend_pid() AND objsubid = 2 AND objid = 2)
    INTO v_bool;
  res := res || ('T03 yeni yerleştirme kademe kilidini alır (pg_advisory_xact_lock, tier 2): ' || v_bool::text);

  -- Bitmiş (işlenmemiş) en eski tier-3 odası seçilmez
  INSERT INTO public.leagues (id, tier, start_date, end_date) VALUES (l_ended, 3, '1970-01-01', now() - interval '30 seconds');
  u := pg_temp.d20_user('t04', 3);
  PERFORM pg_temp.d20_as(u);
  PERFORM public.ensure_user_in_league(u, 5);
  SELECT lm.league_id, l.end_date INTO v_league, v_ts
    FROM public.league_memberships lm JOIN public.leagues l ON l.id = lm.league_id WHERE lm.user_id = u;
  res := res || ('T04 yeni kullanıcı bitmiş odaya yerleşmez (oda bitişi now+' || date_trunc('hour', v_ts - now()) || '): '
                 || coalesce(v_league <> l_ended AND v_ts > now() + interval '5 minutes', false)::text);
  DELETE FROM public.leagues WHERE id = l_ended;

  -- ======================= process_weekly_leagues =======================
  -- 14'ün activity_feed kapısını işlem içinde aç (T07 için; geri alınır)
  CREATE OR REPLACE FUNCTION ops.activity_feed_enabled() RETURNS boolean LANGUAGE sql STABLE AS 'SELECT true';

  -- tier-2 odası öbür hafta paritesinde (bitişine 7 gün), 12 üye
  INSERT INTO public.leagues (id, tier, start_date, end_date) VALUES (l_t2, 2, '1975-01-01', now() + interval '7 days');
  FOR i IN 1..12 LOOP
    PERFORM pg_temp.d20_member(l_t2, pg_temp.d20_user('t2m' || i, 2), 10 * i, now() - interval '7 days' + make_interval(mins => i));
  END LOOP;
  -- tier-1 odası şimdi bitti, 3 üye: ilk 2 terfi (n=3 → ceil(3/2) = 2)
  INSERT INTO public.leagues (id, tier, start_date, end_date) VALUES (l_t1, 1, '1975-01-01', v_end1);
  p1 := pg_temp.d20_user('p1', 1); p2 := pg_temp.d20_user('p2', 1); p3 := pg_temp.d20_user('p3', 1);
  UPDATE public.profiles SET show_in_social_feed = true WHERE id = p1;
  PERFORM pg_temp.d20_member(l_t1, p1, 29, now() - interval '13 days');
  PERFORM pg_temp.d20_member(l_t1, p2, 28, now() - interval '13 days');
  PERFORM pg_temp.d20_member(l_t1, p3, 27, now() - interval '13 days');

  -- tek üyeli tier-4 odası (T08)
  INSERT INTO public.leagues (id, tier, start_date, end_date) VALUES (l_t4, 4, '1975-01-01', v_end1);
  d1 := pg_temp.d20_user('d1', 4);
  PERFORM pg_temp.d20_member(l_t4, d1, 5, now() - interval '13 days');

  -- carry (T10): tier-1 tek üye (terfi eder), tier-5 tek üye (kalır)
  INSERT INTO public.leagues (id, tier, start_date, end_date) VALUES (l_c, 1, '1976-01-01', v_end1), (l_c2, 5, '1976-01-01', v_end1);
  g1 := pg_temp.d20_user('g1', 1); h1 := pg_temp.d20_user('h1', 5);
  PERFORM pg_temp.d20_member(l_c, g1, 4, now() - interval '13 days', 7);
  PERFORM pg_temp.d20_member(l_c2, h1, 3, now() - interval '13 days', 6);

  PERFORM public.process_weekly_leagues();

  SELECT lm.league_id, l.end_date, lm.joined_at INTO v_league, v_ts, v_txt
    FROM public.league_memberships lm JOIN public.leagues l ON l.id = lm.league_id WHERE lm.user_id = p1;
  SELECT league_id INTO v_league2 FROM public.league_memberships WHERE user_id = p2;
  SELECT count(*) INTO v_int FROM public.league_memberships WHERE league_id = l_t2;
  res := res || ('T05 terfi eden yarılanmış (7 gün kalan) odaya değil, aynı dönem sonlu odaya (bitiş now+'
                 || date_trunc('hour', v_ts - now()) || '): '
                 || coalesce(v_league <> l_t2 AND v_ts = v_end1 + interval '14 days' AND v_league2 = v_league
                             AND v_int = 12 AND (SELECT league_tier FROM public.profiles WHERE id = p1) = 2, false)::text);
  res := res || ('T06 taşınan üyenin joined_at''ı taşınma anı: ' || coalesce(v_txt::timestamptz = now(), false)::text);
  SELECT activity_date::text INTO v_txt FROM public.activity_feed WHERE user_id = p1 AND activity_type = 'league_promotion';
  res := res || ('T07 league_promotion tarihi dönemin bittiği TR günü (' || coalesce(v_txt, '-') || '): '
                 || coalesce(v_txt::date = (v_end1 AT TIME ZONE 'Europe/Istanbul')::date, false)::text);
  SELECT league_tier INTO v_int FROM public.profiles WHERE id = d1;
  SELECT string_agg(avatar_id, ',') INTO v_txt FROM public.avatar_unlocks WHERE user_id = d1 AND unlock_type = 'league_award';
  res := res || ('T08 düğmeler varsayılan: tek üyeli odada 5 puanla ödül + terfi (bugünkü kural, ' || coalesce(v_txt, '-') || '): '
                 || coalesce(v_int = 5 AND v_txt = 'league_sapphire_monthly', false)::text);
  SELECT weekly_points, carry_points INTO v_int, v_int2 FROM public.league_memberships WHERE user_id = g1;
  SELECT weekly_points INTO v_txt FROM public.league_memberships WHERE user_id = h1 AND carry_points = 0;
  res := res || ('T09 yeni dönem carry ile başlar, carry sıfırlanır (terfi eden ' || v_int || ', kalan ' || coalesce(v_txt, '-') || '): '
                 || coalesce(v_int = 7 AND v_int2 = 0 AND v_txt = '6'
                             AND (SELECT league_tier FROM public.profiles WHERE id = g1) = 2, false)::text);

  -- Düğmeler: ödül en az 3 üye ve 25 puan, terfi en az 25 puan
  UPDATE public.app_config SET value = '3' WHERE key = 'league_award_min_members';
  UPDATE public.app_config SET value = '25' WHERE key IN ('league_award_min_points', 'league_promotion_min_points');
  INSERT INTO public.leagues (id, tier, start_date, end_date) VALUES (l_k1, 4, '1977-01-01', v_end1), (l_k3, 3, '1977-01-01', v_end1);
  e1 := pg_temp.d20_user('e1', 4);
  PERFORM pg_temp.d20_member(l_k1, e1, 5, now() - interval '13 days');
  f1 := pg_temp.d20_user('f1', 3); f2 := pg_temp.d20_user('f2', 3); f3 := pg_temp.d20_user('f3', 3);
  PERFORM pg_temp.d20_member(l_k3, f1, 30, now() - interval '13 days');
  PERFORM pg_temp.d20_member(l_k3, f2, 26, now() - interval '13 days');
  PERFORM pg_temp.d20_member(l_k3, f3, 10, now() - interval '13 days');
  PERFORM public.process_weekly_leagues();
  UPDATE public.app_config SET value = '1'
   WHERE key IN ('league_award_min_members', 'league_award_min_points', 'league_promotion_min_points');
  SELECT count(*) INTO v_int FROM public.avatar_unlocks WHERE user_id = e1 AND unlock_type = 'league_award';
  res := res || ('T10 düğmeler 3/25/25: tek üyeli odada 5 puanla ödül ve terfi yok: '
                 || coalesce(v_int = 0 AND (SELECT league_tier FROM public.profiles WHERE id = e1) = 4, false)::text);
  SELECT string_agg(a.avatar_id, ',' ORDER BY a.avatar_id) INTO v_txt
    FROM public.avatar_unlocks a WHERE a.user_id IN (f1, f2, f3) AND a.unlock_type = 'league_award';
  res := res || ('T11 düğmeler 3/25/25: 3 üyeli odada 30 ve 26 puan ödül + terfi, 10 puan ikisini de almaz (' || coalesce(v_txt, '-') || '): '
                 || coalesce(v_txt = 'league_gold_monthly,league_gold_weekly'
                             AND (SELECT league_tier FROM public.profiles WHERE id = f1) = 4
                             AND (SELECT league_tier FROM public.profiles WHERE id = f2) = 4
                             AND (SELECT league_tier FROM public.profiles WHERE id = f3) = 3, false)::text);

  -- ======================= get_league_ranking (t4-F6) =======================
  un := pg_temp.d20_user('nolg', 1);
  PERFORM pg_temp.d20_as(un);
  EXECUTE 'SET LOCAL ROLE authenticated';
  SELECT member_count INTO v_int FROM public.get_my_league_ranking();
  EXECUTE 'RESET ROLE';
  -- tek üyeli gerçek oda
  INSERT INTO public.leagues (tier, start_date, end_date) VALUES (1, '1978-01-01', now() + interval '5 days') RETURNING id INTO v_league;
  h1 := pg_temp.d20_user('solo', 1);
  PERFORM pg_temp.d20_member(v_league, h1, 0, now());
  PERFORM pg_temp.d20_as(h1);
  EXECUTE 'SET LOCAL ROLE authenticated';
  SELECT member_count INTO v_int2 FROM public.get_my_league_ranking() WHERE is_me;
  EXECUTE 'RESET ROLE';
  res := res || ('T12 ligsiz satır member_count = 0, tek kişilik gerçek oda 1 (' || coalesce(v_int::text, 'null') || ', ' || coalesce(v_int2::text, 'null') || '): ' || coalesce(v_int = 0 AND v_int2 = 1, false)::text);

  -- ======================= Yetkiler, yapılandırma, geçmiş =======================
  res := res || ('T13 ensure/process API rollerine kapalı, get_league_ranking yalnız authenticated: '
                 || (NOT has_function_privilege('authenticated', 'public.ensure_user_in_league(uuid,integer)', 'EXECUTE')
                     AND NOT has_function_privilege('anon', 'public.ensure_user_in_league(uuid,integer)', 'EXECUTE')
                     AND NOT has_function_privilege('authenticated', 'public.process_weekly_leagues()', 'EXECUTE')
                     AND has_function_privilege('authenticated', 'public.get_league_ranking(uuid)', 'EXECUTE')
                     AND NOT has_function_privilege('anon', 'public.get_league_ranking(uuid)', 'EXECUTE'))::text);
  EXECUTE 'SET LOCAL ROLE anon';
  SELECT public.get_app_config() ?& ARRAY['league_award_min_members', 'league_award_min_points', 'league_promotion_min_points'] INTO v_bool;
  EXECUTE 'RESET ROLE';
  res := res || ('T14 düğmeler get_app_config ile herkese açık: ' || coalesce(v_bool, false)::text);
  SELECT count(*) INTO v_int FROM supabase_migrations.schema_migrations WHERE version = '20261005120000';
  res := res || ('T15 migration geçmişine yazıldı: ' || (v_int = 1)::text);

  RAISE EXCEPTION 'DRYRUN_RESULT >> %', array_to_string(res, ' || ');
END
$dry$;

ROLLBACK;
