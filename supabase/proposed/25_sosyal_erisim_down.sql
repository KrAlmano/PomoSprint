-- ============================================================================
-- GERİ ALMA: supabase/proposed/25_sosyal_erisim.sql
-- ============================================================================
-- Zincir uygulanmış hâle döner: authenticated'a leagues ve league_memberships
-- SELECT yetkisi geri verilir; rotate_friend_code ve friend_code_rotations
-- silinir. VERİ: yenilenmiş arkadaş kodları yeni değerlerinde kalır.
-- ============================================================================

\echo 'supabase/proposed/25_down: doğrudan çalıştırılmaz; \echo/\quit satırlarını silip SQL Editor''de çalıştırın.'
\quit

BEGIN;

DO $pre$
BEGIN
    IF to_regprocedure('public.rotate_friend_code()') IS NULL THEN
        RAISE EXCEPTION 'proposed/25_down: 25 uygulanmamış görünüyor; yapılacak bir şey yok.';
    END IF;
END
$pre$;

DROP FUNCTION public.rotate_friend_code();
DROP TABLE public.friend_code_rotations;

GRANT SELECT ON public.leagues TO authenticated;
GRANT SELECT ON public.league_memberships TO authenticated;

DO $$
BEGIN
    DELETE FROM supabase_migrations.schema_migrations WHERE version = '20261005125000';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişinden silinemedi: %', SQLERRM;
END $$;

COMMIT;
