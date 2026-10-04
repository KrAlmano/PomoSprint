-- ============================================================================
-- GERİ ALMA: supabase/proposed/24_onboarding_profil.sql
-- ============================================================================
-- Zincir uygulanmış hâle döner: enforce_minimum_age trigger'ı ve fonksiyonu
-- silinir. 24'ün false yaptığı profiller, hâlâ onboarding'i bitirmemişlerse
-- yeniden true olur (bitirmişlerse onboarding'deki seçimleri korunur);
-- ops.proposed24_social_feed_reset silinir.
-- ============================================================================

\echo 'supabase/proposed/24_down: doğrudan çalıştırılmaz; \echo/\quit satırlarını silip SQL Editor''de çalıştırın.'
\quit

BEGIN;

DO $pre$
BEGIN
    IF to_regprocedure('public.enforce_minimum_age()') IS NULL THEN
        RAISE EXCEPTION 'proposed/24_down: 24 uygulanmamış görünüyor; yapılacak bir şey yok.';
    END IF;
END
$pre$;

DROP TRIGGER enforce_minimum_age ON public.profiles;
DROP FUNCTION public.enforce_minimum_age();

UPDATE public.profiles p
   SET show_in_social_feed = true
  FROM ops.proposed24_social_feed_reset r
 WHERE r.user_id = p.id
   AND p.onboarding_completed_at IS NULL
   AND NOT p.show_in_social_feed;

DROP TABLE ops.proposed24_social_feed_reset;

DO $$
BEGIN
    DELETE FROM supabase_migrations.schema_migrations WHERE version = '20261005124000';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişinden silinemedi: %', SQLERRM;
END $$;

COMMIT;
