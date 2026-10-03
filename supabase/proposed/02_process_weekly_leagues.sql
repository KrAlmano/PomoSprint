-- ============================================================
-- ÖNERİ 02: Haftalık lig devri                         ÖNCELİK: P1 (yüksek)
-- ============================================================
-- Bulgular: SOCIAL-02, BACKEND-04 (repodaki son gövde bozuk), SOCIAL-08
-- (eşitlikte deterministik sıra), SOCIAL-V03 (küçük liglerde herkes terfi),
-- SOCIAL-23 (Pazar 23:59 yarışı), BACKEND-V03 / SOCIAL-07 / LANDING-12
-- (dönem uzunluğu tek kaynak)
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- ADIMLAR
--  1. Canlıyı doğrulayın:
--       select pg_get_functiondef('public.process_weekly_leagues()'::regprocedure);
--       select pg_get_functiondef('public.ensure_user_in_league(uuid,integer)'::regprocedure);
--       select pg_get_functiondef('public.get_league_ranking(uuid)'::regprocedure);
--       select jobname, schedule, command from cron.job;
--       select status, return_message, start_time from cron.job_run_details
--       where jobid = (select jobid from cron.job where jobname = 'weekly_leagues_job')
--       order by start_time desc limit 10;
--  2a. Cron başarılı çalışıyor ve lig ödülü avatarları dağıtılıyorsa: canlı
--      gövdeyi koruyun, yalnızca aşağıdaki A/B/C/D değişikliklerini ona
--      uygulayın.
--  2b. Cron hata veriyorsa (repodaki 025000 gövdesi gibi 'invalid input
--      syntax for type integer' / 'column threshold does not exist'):
--      aşağıdaki referans gövdeyi kullanın; canlıdaki ödül bloğunu
--      [CANLI ÖDÜL BLOĞU] işaretli yere taşıyın.
--  3. Ürün kararı: dönem 7 gün mü 14 gün mü? Uygulama ve site '14 gün'
--     diyor, repo mantığı haftalık. Karar league_period_end() içinde TEK
--     yerde verilir; cron haftalık kalabilir (yalnızca süresi dolmuş ligler
--     işlenir). Kararı get_points_config'e 'league_period_days' olarak
--     ekleyin; league_info_sheet, ranking_screen yedeği ve landing metinleri
--     bu değeri göstermeli.
--  4. Yeni bir migration dosyasında uygulayın, staging'de
--     `select public.process_weekly_leagues();` ile deneyin.
-- ============================================================

\echo 'supabase/proposed/02: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

-- ------------------------------------------------------------
-- A) Bölgeler: küçük liglerde terfi sayısı üyeye oranlı (SOCIAL-V03)
-- ------------------------------------------------------------
-- İstemci get_league_zones'u doğrudan çağırıyor; değişiklik UI'daki
-- yeşil/kırmızı bölgelerle otomatik uyumlu olur.
CREATE OR REPLACE FUNCTION public.get_league_zones(p_member_count integer)
RETURNS TABLE (
    promotion_zone_end integer,
    demotion_zone_start integer
)
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
BEGIN
    IF p_member_count < 10 THEN
        promotion_zone_end := 1;
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
$$;

-- ------------------------------------------------------------
-- B) Dönem sonu tek kaynak (SOCIAL-23, BACKEND-V03)
-- ------------------------------------------------------------
-- Dönem sınırı Pazartesi 00:00 (İstanbul). Sona 5 dakikadan az kalmışsa
-- bir sonraki dönem döner; böylece cron'dan hemen önce/sonra açılan lig
-- bitiş tarihi geçmiş halde doğmaz. 14 günlük dönem seçilirse burada
-- değiştirin (ör. sabit bir başlangıç tarihinden itibaren 14'er gün).
CREATE OR REPLACE FUNCTION public.league_period_end(p_at timestamptz DEFAULT now())
RETURNS timestamptz
LANGUAGE sql
STABLE
SET search_path = public
AS $$
    SELECT (date_trunc('week', (p_at + interval '5 minutes') AT TIME ZONE 'Europe/Istanbul')
            + interval '7 days') AT TIME ZONE 'Europe/Istanbul';
$$;

-- ensure_user_in_league (CANLI gövdeye uygulayın):
--   * Yeni lige katılma sorgusu (tier'a göre boş yer arayan SELECT):
--       ESKİ: WHERE l.is_active = true AND l.tier = v_tier
--       YENİ: WHERE l.is_active = true AND l.tier = v_tier
--               AND l.end_date > now() + interval '5 minutes'
--   * Yeni lig açılırken:
--       ESKİ: v_end_date := ((date_trunc('week', ...) + interval '6 days') + time '23:59:59') AT TIME ZONE 'Europe/Istanbul';
--       YENİ: v_end_date := public.league_period_end();
-- get_league_ranking fallback dalındaki v_end_date hesabı da
-- public.league_period_end() olmalı.

-- ------------------------------------------------------------
-- C) Eşitlikte tek sıralama ifadesi (SOCIAL-08)
-- ------------------------------------------------------------
-- get_league_ranking (CANLI gövdeye uygulayın):
--   ESKİ: ORDER BY lm.weekly_points DESC, lm.joined_at ASC;
--   YENİ: ORDER BY lm.weekly_points DESC, lm.joined_at ASC, lm.user_id;
-- process_weekly_leagues aynı ifadeyi row_number() ile kullanır (rank()
-- değil; eşitlerde terfi sayısı bölgeyi aşmasın).

-- ------------------------------------------------------------
-- D) process_weekly_leagues — REFERANS GÖVDE (20260809022700 mantığı)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.process_weekly_leagues()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    -- Terfi için en az ~5 adet 25 dk'lık seans (SOCIAL-V03).
    c_min_promotion_points constant integer := 25;
    r_league record;
    r_member record;
    v_member_count integer;
    v_promo_end integer;
    v_demo_start integer;
    v_new_tier integer;
    v_period_day date := (now() AT TIME ZONE 'Europe/Istanbul')::date - 1;
BEGIN
    -- Yalnızca dönemi bitmiş aktif ligler: cron birkaç saniye erken çalışsa
    -- ya da dönem 14 gün seçilse de henüz bitmemiş lig kapatılmaz.
    FOR r_league IN
        SELECT l.id, l.tier
        FROM public.leagues l
        WHERE l.is_active
          AND l.end_date <= now() + interval '5 minutes'
        ORDER BY l.id
        FOR UPDATE
    LOOP
        SELECT count(*) INTO v_member_count
        FROM public.league_memberships
        WHERE league_id = r_league.id;

        SELECT z.promotion_zone_end, z.demotion_zone_start
        INTO v_promo_end, v_demo_start
        FROM public.get_league_zones(v_member_count) z;

        FOR r_member IN
            SELECT lm.user_id,
                   lm.weekly_points,
                   row_number() OVER (ORDER BY lm.weekly_points DESC, lm.joined_at ASC, lm.user_id) AS rnk
            FROM public.league_memberships lm
            WHERE lm.league_id = r_league.id
            ORDER BY rnk
        LOOP
            v_new_tier := r_league.tier;

            IF r_member.rnk <= v_promo_end
               AND r_league.tier < 5
               AND r_member.weekly_points >= c_min_promotion_points THEN
                v_new_tier := r_league.tier + 1;

                INSERT INTO public.activity_feed (user_id, activity_type, activity_date, payload)
                VALUES (r_member.user_id, 'league_promotion', v_period_day,
                        jsonb_build_object('from_tier', r_league.tier, 'to_tier', v_new_tier))
                ON CONFLICT (user_id, activity_type, activity_date) DO NOTHING;
            ELSIF r_member.rnk >= v_demo_start AND r_league.tier > 1 THEN
                v_new_tier := r_league.tier - 1;
            END IF;

            -- [CANLI ÖDÜL BLOĞU] Canlı gövde ilk 3'e lig ödülü avatarı
            -- veriyorsa o bloğu buraya taşıyın, ör.:
            --   IF r_member.rnk <= 3 AND r_member.weekly_points > 0 THEN
            --       INSERT INTO public.avatar_unlocks (user_id, avatar_id, unlock_type, coins_spent)
            --       VALUES (r_member.user_id, <ödül avatarı>, 'league', 0)
            --       ON CONFLICT (user_id, avatar_id) DO NOTHING;
            --   END IF;
            -- (avatar_unlocks.unlock_type CHECK'i canlıda 'league' içermeli.)

            UPDATE public.profiles SET league_tier = v_new_tier WHERE id = r_member.user_id;
        END LOOP;

        UPDATE public.leagues SET is_active = false WHERE id = r_league.id;
    END LOOP;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.process_weekly_leagues() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.league_period_end(timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.league_period_end(timestamptz) TO authenticated;

-- ------------------------------------------------------------
-- E) Cron: dönem sınırı Pazartesi 00:00 İstanbul = Pazar 21:00 UTC
-- ------------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'weekly_leagues_job') THEN
        PERFORM cron.unschedule('weekly_leagues_job');
    END IF;
    PERFORM cron.schedule('weekly_leagues_job', '0 21 * * 0', 'SELECT public.process_weekly_leagues()');
END $$;

COMMIT;
