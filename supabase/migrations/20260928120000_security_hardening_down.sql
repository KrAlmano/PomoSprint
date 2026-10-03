-- 20260928120000_security_hardening_up.sql geri alma.
-- Not: search_path atamaları geri alınmaz (zararsız ve güvenli).
-- profiles için eski geniş yetkiler bilinçli olarak geri VERİLMEZ;
-- yalnızca authenticated rolüne tablo bazlı UPDATE/INSERT geri tanınır.

BEGIN;

DROP TRIGGER IF EXISTS study_sessions_validate_timing ON public.study_sessions;
DROP FUNCTION IF EXISTS public.validate_study_session_timing();
DROP INDEX IF EXISTS public.study_sessions_user_started_at_idx;

DROP TRIGGER IF EXISTS categories_enforce_limit ON public.categories;
DROP FUNCTION IF EXISTS public.enforce_category_limit();

DROP FUNCTION IF EXISTS public.get_my_league_ranking();

DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT p.oid::regprocedure AS sig
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public' AND p.proname = 'get_league_ranking'
    LOOP
        EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', r.sig);
    END LOOP;
END;
$$;

GRANT INSERT, UPDATE ON public.profiles TO authenticated;

COMMIT;
