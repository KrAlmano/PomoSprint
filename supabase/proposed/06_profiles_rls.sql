-- ============================================================
-- ÖNERİ 06: profiles okuma politikası ve kolon yetkileri  ÖNCELİK: P2
-- ============================================================
-- Bulgular: BACKEND-05 (repoda 'Enable read access for all users' USING
-- (true) + tablo düzeyinde SELECT: repodan kurulan ortamda herkes herkesin
-- e-postasını, doğum yılını, coin'ini okur), BACKEND-12 (INSERT yetkisi),
-- STATS-14 (study_sessions SELECT politikası repoda yok).
--
-- Canlıda durum farklı olabilir: regresyon testi canlıda başka kullanıcının
-- satırının OKUNAMADIĞINI doğruluyor. Bu dosya repo ile canlıyı aynı (dar)
-- hale getirmek içindir.
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- ÖN KOŞUL: İstemci arkadaş listelerini get_my_friends /
-- get_incoming_friend_requests RPC'lerinden okuyor olmalı (DATA paketi,
-- 20261003120000_audit_fixes). Aksi halde eski istemcilerin listeleri boş
-- kalır.
--
-- ADIMLAR
--  1. Canlı durumu alın:
--       select polname, polcmd, polroles::regrole[],
--              pg_get_expr(polqual, polrelid), pg_get_expr(polwithcheck, polrelid)
--       from pg_policy where polrelid in ('public.profiles'::regclass, 'public.study_sessions'::regclass);
--       select table_name, grantee, privilege_type, column_name
--       from information_schema.column_privileges
--       where table_schema = 'public' and table_name in ('profiles', 'study_sessions')
--         and grantee in ('anon', 'authenticated')
--       order by 1, 2, 3, 4;
--  2. Canlı zaten aşağıdaki gibiyse yalnızca bu dosyayı migration olarak
--     repoya alın (baseline). Değilse önce staging'de deneyin.
--  3. Kolon listesi istemcideki SupabaseService.ownProfileColumns ile AYNI
--     olmalı; istemci yeni kolon okumaya başlarsa buraya da eklenmeli
--     (yoksa select hata verir).
-- ============================================================

\echo 'supabase/proposed/06: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

-- 1) profiles: yalnızca kendi satırı
DROP POLICY IF EXISTS "Enable read access for all users" ON public.profiles;
DROP POLICY IF EXISTS "Users can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT TO authenticated
    USING (id = auth.uid());

-- 2) profiles: kolon bazlı SELECT (ownProfileColumns + email)
REVOKE SELECT ON public.profiles FROM authenticated;
GRANT SELECT (
    id, email, name, avatar_id, total_minutes, created_at, friend_code,
    current_streak, last_study_date, is_premium, league_tier,
    lifetime_points, coins, longest_streak, timezone,
    active_session_ends_at, active_session_category_name,
    show_in_social_feed, user_segment, daily_goal_minutes, birth_year,
    onboarding_completed_at, equipped_avatar_id
) ON public.profiles TO authenticated;

-- 3) INSERT: e-posta ve avatar 20261003120000'deki BEFORE INSERT trigger'ı
--    ile zorlanıyor. İstemci profil oluştururken email göndermeyi
--    bıraktıktan sonra (DATA paketi) INSERT yetkisi daraltılabilir:
-- REVOKE INSERT ON public.profiles FROM authenticated;
-- GRANT INSERT (id, name, avatar_id) ON public.profiles TO authenticated;

-- 4) study_sessions: kendi satırları (STATS-14). Canlıda varsa adı farklı
--    olabilir; çift politika zararsızdır ama temizlenmeli.
ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own study sessions" ON public.study_sessions;
CREATE POLICY "Users can view own study sessions"
    ON public.study_sessions FOR SELECT TO authenticated
    USING (user_id = auth.uid());
REVOKE ALL ON public.study_sessions FROM anon;

COMMIT;
