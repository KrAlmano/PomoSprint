-- ============================================================
-- UYARI: CANLIYA UYGULAMADAN ÖNCE OKUYUN
-- ------------------------------------------------------------
-- Bu dosya bir GERİ ALMA (rollback) betiğidir, migration DEĞİLDİR.
-- supabase/migrations/ dışında tutulur; aksi halde `supabase db push`
-- onu aynı sürüm numaralı ileri migration sanıp _up dosyasından ÖNCE
-- uygular. Repodaki migration'lar canlı şemanın gerisinde olduğu için
-- bu betik canlıdaki güncel fonksiyon gövdelerini ESKİ sürümlerle
-- ezebilir ve geri alınamaz şekilde VERİ SİLEBİLİR.
-- Uygulamadan önce `supabase db dump` ile yedek alın, dosyayı satır
-- satır okuyun ve önce staging/branch üzerinde deneyin.
--
-- Bu dosyaya özel riskler:
--   leagues ve league_memberships tablolarında RLS'i KAPATIR: tablo
--   yetkisi olan herkes tüm lig üyeliklerini okuyabilir.
--   get_league_ranking'i zon kolonları olmayan eski imzayla yeniden
--   oluşturur; get_my_league_ranking (20260928120000) bu kolonları
--   okuduğu için uygulamanın lig ekranı hata verir.
--   get_league_zones'u siler ve haftalık cron işini eski saate
--   ('59 23 * * 0' UTC) alır.
--   Düzeltildi: cron.unschedule artık iş yoksa hata vermez ve yeniden
--   oluşturulan get_league_ranking istemcilere KAPALI kalır (e-posta
--   sızıntısı yeniden açılmasın).
-- ============================================================

BEGIN;

-- 1) REVERT RLS
ALTER TABLE public.leagues DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Leagues select policy" ON public.leagues;

ALTER TABLE public.league_memberships DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Memberships select policy" ON public.league_memberships;
DROP FUNCTION IF EXISTS public.get_my_league_ids();

-- 2) REVERT CRON SCHEDULE
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'weekly_leagues_job') THEN
        PERFORM cron.unschedule('weekly_leagues_job');
    END IF;
    PERFORM cron.schedule('weekly_leagues_job', '59 23 * * 0', 'SELECT public.process_weekly_leagues()');
END $$;

-- 3) REVERT RPCs
DROP FUNCTION IF EXISTS public.get_league_zones(integer);

-- A. ensure_user_in_league
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
        v_end_date := (date_trunc('week', current_date) + interval '6 days') + time '23:59:59';
        
        INSERT INTO public.leagues (tier, end_date)
        VALUES (v_tier, v_end_date)
        RETURNING id INTO v_league_id;
    END IF;

    INSERT INTO public.league_memberships (league_id, user_id, weekly_points)
    VALUES (v_league_id, p_user_id, p_points);
END;
$function$;


-- B. get_league_ranking (Revert to original signature and logic)
DROP FUNCTION IF EXISTS public.get_league_ranking(uuid);
CREATE OR REPLACE FUNCTION public.get_league_ranking(p_user_id uuid)
 RETURNS TABLE(
    name text, 
    email text, 
    avatar_id text, 
    weekly_points integer, 
    tier integer, 
    end_date timestamptz, 
    is_me boolean
 )
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_league_id UUID;
    v_tier INTEGER;
    v_end_date TIMESTAMPTZ;
BEGIN
    SELECT l.id, l.tier, l.end_date
    INTO v_league_id, v_tier, v_end_date
    FROM public.league_memberships lm
    JOIN public.leagues l ON l.id = lm.league_id
    WHERE lm.user_id = p_user_id AND l.is_active = true
    LIMIT 1;

    IF v_league_id IS NULL THEN
        SELECT league_tier INTO v_tier FROM public.profiles WHERE id = p_user_id;
        v_end_date := (date_trunc('week', current_date) + interval '6 days') + time '23:59:59';
        RETURN QUERY
        SELECT 
            p.name, p.email, p.avatar_id, 0 AS points, v_tier AS tier, v_end_date AS end_date, true AS is_me
        FROM public.profiles p WHERE p.id = p_user_id;
        RETURN;
    END IF;

    RETURN QUERY
    SELECT 
        p.name,
        p.email,
        p.avatar_id,
        lm.weekly_points,
        v_tier,
        v_end_date,
        (lm.user_id = p_user_id) AS is_me
    FROM public.league_memberships lm
    JOIN public.profiles p ON p.id = lm.user_id
    WHERE lm.league_id = v_league_id
    ORDER BY lm.weekly_points DESC, lm.joined_at ASC;
END;
$function$;

-- Lig üyelerinin e-postalarını döndürdüğü için istemcilere kapalı kalmalı
-- (bkz. 20260928120000_security_hardening_up.sql bölüm 4).
REVOKE EXECUTE ON FUNCTION public.get_league_ranking(uuid) FROM PUBLIC, anon, authenticated;

-- C. process_weekly_leagues
CREATE OR REPLACE FUNCTION public.process_weekly_leagues()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    r_league RECORD;
    r_member RECORD;
    v_rank INTEGER;
    v_new_tier INTEGER;
BEGIN
    FOR r_league IN 
        SELECT id, tier FROM public.leagues WHERE is_active = true 
    LOOP
        v_rank := 1;
        FOR r_member IN 
            SELECT user_id, weekly_points 
            FROM public.league_memberships 
            WHERE league_id = r_league.id 
            ORDER BY weekly_points DESC 
        LOOP
            v_new_tier := r_league.tier;
            
            IF v_rank <= 7 AND r_league.tier < 5 THEN
                v_new_tier := r_league.tier + 1;
            ELSIF v_rank >= 24 AND r_league.tier > 1 THEN
                v_new_tier := r_league.tier - 1;
            END IF;
            
            UPDATE public.profiles SET league_tier = v_new_tier WHERE id = r_member.user_id;
            v_rank := v_rank + 1;
        END LOOP;
        
        UPDATE public.leagues SET is_active = false WHERE id = r_league.id;
    END LOOP;
END;
$function$;


COMMIT;
