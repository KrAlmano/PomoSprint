-- ============================================================
-- ÖNERİ 12: Aylık sıralamada 'bu ay' = çalışma ayı   ÖNCELİK: P2
-- ============================================================
-- Bulgular: MH-1, X2 (3 Ekim 2026 analiz ekranları doğrulaması).
--
-- Sorun: get_public_monthly_leaderboard ayı completed_at ve İstanbul gece
-- yarısıyla sayıyor; Raporlar > Aylık Takip ve complete_study_session ise
-- started_at, profil dilimi ve 04:00 gün sınırıyla. 30 Eylül 23:50'de başlayıp
-- 1 Ekim 00:15'te biten seans Sıralama'da Ekim'e, Raporlar'da Eylül'e
-- yazılıyor; 1 Ekim 00:00-04:00 arasındaki seanslar da aynı şekilde.
--
-- Değişiklik: yalnızca WHERE. Seans, çalışma günü
--   ((started_at AT TIME ZONE p.timezone) - 4 saat)::date
-- içinde bulunulan çalışma ayına düşüyorsa sayılır. Alt sınır started_at
-- üzerinden yazıldı (idx_study_sessions_user_started kullanılabilir):
--   started_at >= (ayın 1'i 04:00, profil diliminde)
-- Not: Sınır her kullanıcının profil dilimindedir (complete_study_session ve
-- Raporlar ile aynı). Bugün tüm profiller Europe/Istanbul olduğundan
-- sıralama için tek bir sınır demektir.
--
-- Gövde CANLI tanımdan alındı (3 Ekim 2026, pg_get_functiondef):
--   name, avatar_id, total_points, total_minutes, is_me; oturumsuz çağrıda
--   mask_public_name; show_in_social_feed filtresi; sıralama ve LIMIT aynı.
--
-- ADIMLAR
--  1. 15_monthly_leaderboard_study_month_dryrun.sql'i SQL Editor'de çalıştırın.
--     Sonda 'DRYRUN_RESULT >> ...' hatası beklenir; her satır 'true' olmalı.
--  2. Bu dosyanın \echo ve \quit satırlarını silerek SQL Editor'de çalıştırın
--     (ya da gövdeyi supabase/migrations/20261003180000_monthly_leaderboard_study_month.sql
--     olarak kopyalayın). Geri alma: 15_monthly_leaderboard_study_month_down.sql.
--  3. Uygulandıktan SONRA istemcide lib/widgets/social/ranking_models.dart
--     nextMonthlyLeaderboardReset ayın 1'i 04:00'e (İstanbul) çekilmeli; önce
--     değiştirmeyin, geri sayım canlı sunucuyla çelişir.
--  4. AGENTS.md §5.1 get_public_monthly_leaderboard satırına "ay = çalışma ayı
--     (started_at, profil dilimi, 04:00)" notunu ekleyin.
-- ============================================================

\echo 'supabase/proposed/15: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
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
    -- Çalışma ayı: complete_study_session'ın gün kuralı (started_at, profil
    -- dilimi, 04:00). Ay, profil dilimindeki ayın 1'i 04:00'te başlar.
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

-- CREATE OR REPLACE yetkileri korur; canlıdaki hâl açıkça yeniden yazılır
-- (anon: landing sayfası, authenticated: uygulama).
REVOKE ALL ON FUNCTION public.get_public_monthly_leaderboard(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_monthly_leaderboard(integer) TO anon, authenticated;

DO $$
BEGIN
    INSERT INTO supabase_migrations.schema_migrations (version, name)
    VALUES ('20261003180000', 'monthly_leaderboard_study_month')
    ON CONFLICT (version) DO NOTHING;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişine yazılamadı: %', SQLERRM;
END $$;

COMMIT;
