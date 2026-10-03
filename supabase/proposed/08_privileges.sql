-- ============================================================
-- ÖNERİ 08: Fonksiyon yetkileri ve search_path          ÖNCELİK: P3
-- ============================================================
-- Bulgu: BACKEND-25. complete_study_session, purchase_avatar,
-- create_category, start_study_session, get_live_friends gibi SECURITY
-- DEFINER RPC'ler anon rolüne açık (şu an gövdelerdeki auth.uid() NULL
-- kontrolü sayesinde zararsız). Gelecekte kontrolü unutulmuş bir RPC anon
-- key'e sahip herkese açılır. Ayrıca 20260928120000'deki toplu
-- 'search_path = public' ataması, extensions şemasındaki fonksiyonları
-- (gen_random_bytes, digest, uuid_generate_v4, crypt) şema adı olmadan
-- kullanan fonksiyonları kırabilir.
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- ADIMLAR
--  1. Önce durumu görün:
--       select p.oid::regprocedure, p.prosecdef,
--              has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec,
--              has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec,
--              p.proconfig
--       from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--       where n.nspname = 'public' order by 1;
--  2. ANON_ALLOWED listesini doğrulayın: landing'in oturumsuz çağırdığı
--     fonksiyonlar (şu an yalnızca get_public_monthly_leaderboard;
--     alltime da landing'de kullanılıyorsa ekleyin). Uygulamanın giriş
--     öncesi (splash/kayıt) çağırdığı başka RPC varsa ekleyin.
--  3. Staging'de uygulayın, Supabase Security Advisor'ı çalıştırın,
--     scripts/security_regression_test.js ile doğrulayın.
-- ============================================================

\echo 'supabase/proposed/08: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

-- 1) Bundan sonra oluşturulan fonksiyonlar varsayılan olarak anon'a kapalı.
--    Supabase'te varsayılan yetkiler oluşturan role göre tutulur.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon;

-- 2) Mevcut fonksiyonlar: anon ve PUBLIC'ten EXECUTE kaldır. authenticated
--    bugün çağırabiliyorsa (PUBLIC üzerinden de olsa) açık grant ile korunur;
--    bilinçli olarak kapatılmış fonksiyonlara (ensure_user_in_league,
--    process_weekly_leagues, get_league_ranking, category_limit, trigger
--    fonksiyonları) yeni yetki VERİLMEZ. Eklenti fonksiyonları atlanır.
DO $$
DECLARE
    r record;
    c_anon_allowed constant text[] := ARRAY['get_public_monthly_leaderboard', 'get_public_alltime_leaderboard'];
BEGIN
    FOR r IN
        SELECT p.oid, p.oid::regprocedure AS sig, p.proname
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prokind = 'f'
          AND NOT EXISTS (
              SELECT 1 FROM pg_depend d
              WHERE d.classid = 'pg_proc'::regclass AND d.objid = p.oid AND d.deptype = 'e'
          )
    LOOP
        IF r.proname = ANY (c_anon_allowed) THEN
            CONTINUE;
        END IF;
        IF has_function_privilege('authenticated', r.oid, 'EXECUTE') THEN
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', r.sig);
        END IF;
        IF has_function_privilege('service_role', r.oid, 'EXECUTE') THEN
            EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', r.sig);
        END IF;
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon', r.sig);
    END LOOP;
END $$;

-- 3) extensions şemasındaki fonksiyonları şema adı olmadan kullanan
--    fonksiyonların search_path'ine extensions eklenir (Supabase'te
--    pgcrypto / uuid-ossp extensions şemasında).
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT p.oid::regprocedure AS sig
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prokind = 'f'
          AND p.prosrc ~ '(^|[^.a-z_])(gen_random_bytes|digest|hmac|crypt|gen_salt|uuid_generate_v[1-5])\s*\('
    LOOP
        EXECUTE format('ALTER FUNCTION %s SET search_path = public, extensions', r.sig);
    END LOOP;
END $$;

COMMIT;
