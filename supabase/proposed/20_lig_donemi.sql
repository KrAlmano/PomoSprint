-- ============================================================================
-- ÖNERİ 20: LİG DÖNEMİ VE ODA YERLEŞTİRME              ÖNCELİK: P2
-- ============================================================================
-- Test ajanı bulguları (5 Ekim 2026, yerel kopyada yeniden üretildi:
-- supabase/tests/proposed_20_25_bulgu_repro_local.sql ve
-- proposed_20_25_race_local.sh):
--  t4-F2  Terfi/düşen üye, dönemi yarılanmış (öbür hafta paritesindeki)
--         odaya 0 puanla giriyor; ilk dönemi 7 gün, hemen düşme bölgesinde.
--  t4-F3  Tek/az üyeli odada tek seansla (5 puan) şampiyonluk + terfi.
--  t4-F5  Dönem bitişi (Pazar 23:59:59 TR) ile cron (Pazartesi 00:01 TR)
--         arasında: yeni kullanıcı bitmiş odaya yerleşiyor; bitişten SONRA
--         biten seansın puanı eski odaya yazılıyor (bu ikincisi 21'de).
--  t4-F6  Ligsiz kullanıcının satırı tek kişilik gerçek odayla aynı
--         (member_count = 1): istemci terfi edip odasında yalnız kalanı
--         "henüz odada değilsin" diye gösteriyor.
--  t4-F7  ensure_user_in_league oda seçimi kilitsiz: eşzamanlı ilk seanslar
--         ayrı odalar açıyor; 29 üyeli oda 31'e çıkabiliyor.
--  t4-F8  league_promotion activity_date UTC tarihinden (Cumartesi).
--  t4-F10 Taşınan üyenin joined_at'ı korunuyor; yeni odada 0=0 eşitliğinde
--         odaya haftalar önce katılmış üyelerin önüne geçiyor.
--  t1-06  (bilgi) Yeni oda ilk dönemde 7–14 gün sürer; sabit 14 gün ÜRÜN
--         KARARI, bu dosyada değişmedi (AGENTS.md §6.4 belgelendi).
--  t1-08  ensure_user_in_league'in pg_temp'i proposed/13 H'de; burada da korunur.
--
-- SIRA: canlıdaki zincirden SONRA (12 → 15 → 16 → 19 → 13 → 14 → 20 → 21 →
-- 22 → 23 → 24 → 25; supabase/proposed/README.md). Gövdeler zincir uygulanmış
-- hâlden (pg_get_functiondef) türetildi: ensure_user_in_league = canlı gövde +
-- 13'ün pg_temp'i; get_league_ranking = 14'ün gövdesi; process_weekly_leagues
-- = canlı gövde (zincir dokunmuyor). İlk adım bu üç gövdenin md5'ini ve 13/14
-- nesnelerini denetler; farklıysa hiçbir şey yapmadan durur.
--
-- DEĞİŞİKLİKLER
--  A. league_memberships.carry_points (yeni, varsayılan 0): bitmiş ama dönem
--     sonu henüz işlenmemiş odadaki üyenin, oda bitişinden SONRA biten
--     seansının lig puanı (21 yazar). process_weekly_leagues yeni dönemin
--     puanını bununla başlatır (weekly_points = carry_points).
--  B. ensure_user_in_league (yeni yerleştirme yolu):
--     - kademe başına danışma kilidi (pg_advisory_xact_lock): eşzamanlı ilk
--       seanslar aynı odaya girer, sayım kilit altında (30 sınırı aşılmaz);
--     - bitişine 5 dakikadan az kalan / bitmiş odaya yerleştirme yok
--       (process_weekly_leagues'in "end_date <= now() + 5 dk" penceresiyle aynı).
--     Var olan üyelik yolu ve yeni oda bitişi (7–14 gün) DEĞİŞMEDİ.
--  C. process_weekly_leagues:
--     - beş kademenin danışma kilidini alır (B ile aynı anahtar);
--     - terfi/düşme hedefi yalnızca bir sonraki dönem sonu AYNI olan oda
--       (bu koşuda işlenecek ya da işlenmiş aynı takvimli oda ya da bu koşuda
--       açılan oda); yoksa o dönem sonuyla yeni oda (t4-F2);
--     - taşınan üyenin joined_at'ı = now() (t4-F10);
--     - yeni dönemin puanı = carry_points (A), carry sıfırlanır;
--     - league_promotion activity_date = dönemin bittiği TR günü (t4-F8);
--     - kilit sırası profiles → league_memberships (complete_study_session
--       ile aynı; terfi eden üyenin seansı ile kilitlenme döngüsü olmaz);
--     - ÜRÜN DÜĞMELERİ (t4-F3), app_config (13), VARSAYILAN = bugünkü kural:
--         league_award_min_members    (1)  ödül için odadaki en az üye
--         league_award_min_points     (1)  ödül için en az dönem puanı
--         league_promotion_min_points (1)  terfi için en az dönem puanı
--       Önerilen: 3 / 25 / 25 (≈ 5 seans). Değiştirilirse istemci metinleri
--       (leagueInfoPromote, leagueAwardsSub, leagueAwardLocked*) ve
--       ranking_models.isPromotionRank aynı kurala çekilmeli; değerler
--       get_app_config() ile herkese açık okunur.
--  D. get_league_ranking: ligsiz satırda member_count = 0 (t4-F6). Bugünkü
--     istemci (awaitingPlacement: memberCount <= 1) aynı davranır; yeni
--     istemci 0 = "odada değilsin", 1 = "odanda şimdilik yalnızsın" ayırabilir.
--
-- İSTEMCİ SÖZLEŞMESİ: hiçbir RPC imzası ya da hata metni değişmez.
-- get_my_league_ranking / get_league_ranking: ligsiz satırda member_count 0.
-- get_app_config(): üç yeni anahtar (yukarıda).
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- ADIMLAR (SQL Editor, kullanıcı çalıştırır; 14'ten SONRA)
--  1. supabase/tests/proposed_20_lig_donemi_dryrun.sql → sonda
--     DRYRUN_RESULT; her madde 'true' (ön koşul tutmazsa
--     'proposed/20 ön koşulu: ...').
--  2. Bu dosya \echo/\quit satırları silinerek. Migration geçmişine
--     20261005120000 lig_donemi yazılır.
--  3. Doğrulama: select key, value from public.app_config where key like 'league_%';
--     select column_name from information_schema.columns
--      where table_name = 'league_memberships' and column_name = 'carry_points';
--  4. Geri alma: 20_lig_donemi_down.sql (21 uygulandıysa önce 21_down).
-- ============================================================================

\echo 'supabase/proposed/20: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

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

COMMIT;
