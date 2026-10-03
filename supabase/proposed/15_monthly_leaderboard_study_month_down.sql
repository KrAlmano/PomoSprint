-- ============================================================
-- GERİ ALMA: 15_monthly_leaderboard_study_month
-- get_public_monthly_leaderboard'u 3 Ekim 2026 CANLI tanımına döndürür
-- (ay = completed_at, İstanbul gece yarısı). Veri değiştirmez.
-- Çalıştırmak için \echo ve \quit satırlarını silin.
-- ============================================================

\echo 'supabase/proposed/15 geri alma: doğrudan çalıştırılmaz, dosya başına bakın.'
\quit

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
    WHERE ss.completed_at >= (date_trunc('month', now() AT TIME ZONE 'Europe/Istanbul') AT TIME ZONE 'Europe/Istanbul')
      AND p.show_in_social_feed = true
    GROUP BY p.id, p.name, p.avatar_id
    ORDER BY 3 DESC, 4 DESC, p.id
    LIMIT LEAST(GREATEST(p_limit, 0), 100);
$function$;

REVOKE ALL ON FUNCTION public.get_public_monthly_leaderboard(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_monthly_leaderboard(integer) TO anon, authenticated;

DELETE FROM supabase_migrations.schema_migrations WHERE version = '20261003180000';

COMMIT;
