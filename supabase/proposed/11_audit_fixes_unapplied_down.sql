-- ============================================================
-- UYARI: CANLIYA UYGULAMADAN ÖNCE OKUYUN
-- ------------------------------------------------------------
-- 20261003120000_audit_fixes.sql geri alması. Migration DEĞİLDİR;
-- supabase/migrations/ dışında tutulur. Uygulamadan önce
-- `supabase db dump` ile yedek alın ve önce staging'de deneyin.
--
-- Bu dosyaya özel riskler:
--   * study_sessions.completed_at yeniden senkron anına (synced_at)
--     döner ve synced_at kolonu SİLİNİR. Çevrimdışı kuyruktaki 2. ve
--     sonraki seanslar yeniden 'overlap' ile reddedilmeye başlar.
--   * get_my_friends / get_incoming_friend_requests silinir; istemci
--     PGRST202 alıp eski doğrudan tablo sorgusuna düşer (canlı RLS
--     yalnızca kendi satırına izin veriyorsa listeler boş görünür).
--   * avatars için anon politikası kaldırılır; anon SELECT yetkisi
--     (Supabase varsayılanı olabilir) bilinçli olarak geri alınmaz.
--   * profiles.timezone_updated_at kolonu silinir; set_my_timezone ile
--     yazılmış saat dilimleri profiles.timezone'da kalır.
--   * 20261003150000_live_audit_fixes'in nesnelerine dokunulmaz; o
--     uygulanmışsa get_my_friends / get_incoming_friend_requests onun
--     tanımıyla durur ve aşağıdaki DROP'lar onları da siler. O durumda bu
--     iki DROP satırını çıkarın. Aynı durumda en alttaki completed_at geri
--     yükleme UPDATE'ini de ÇALIŞTIRMAYIN: oradaki complete_study_session
--     çakışmayı completed_at'in gerçek bitiş olmasına dayanarak kontrol
--     eder.
-- ============================================================

BEGIN;

-- 7) Kategoriler
DROP FUNCTION IF EXISTS public.reorder_categories(uuid[]);
DROP FUNCTION IF EXISTS public.get_my_category_limit();
DROP FUNCTION IF EXISTS public.category_limit(uuid);

-- 6) Saat dilimi / çalışma günü / seri
DROP FUNCTION IF EXISTS public.set_my_timezone(text);
ALTER TABLE public.profiles DROP COLUMN IF EXISTS timezone_updated_at;
DROP FUNCTION IF EXISTS public.get_my_streak();
DROP FUNCTION IF EXISTS public.study_day_start(date, text);
DROP FUNCTION IF EXISTS public.study_day_of(timestamptz, text);

-- 5) Profil oluşturma zorlaması
DROP TRIGGER IF EXISTS profiles_enforce_insert_defaults ON public.profiles;
DROP FUNCTION IF EXISTS public.enforce_profile_insert_defaults();

-- 4) Avatar kataloğu (anon)
DROP POLICY IF EXISTS "Avatars are viewable by anon" ON public.avatars;

-- 3) Index'ler (yalnızca bu migration'ın oluşturduğu isimler)
DROP INDEX IF EXISTS public.study_sessions_user_completed_at_idx;
DROP INDEX IF EXISTS public.friendships_user_id_status_idx;
DROP INDEX IF EXISTS public.friendships_friend_id_status_idx;

-- 2) Arkadaş RPC'leri
DROP FUNCTION IF EXISTS public.cancel_friend_request(uuid);
DROP FUNCTION IF EXISTS public.remove_friend(uuid);
DROP FUNCTION IF EXISTS public.get_outgoing_friend_requests();
DROP FUNCTION IF EXISTS public.get_incoming_friend_requests();
DROP FUNCTION IF EXISTS public.get_my_friends();
DROP FUNCTION IF EXISTS public.my_friend_ids();

-- 1) study_sessions zaman normalizasyonu
DROP TRIGGER IF EXISTS study_sessions_normalize_times ON public.study_sessions;
DROP FUNCTION IF EXISTS public.normalize_study_session_times();

UPDATE public.study_sessions
SET completed_at = synced_at
WHERE synced_at IS NOT NULL;

ALTER TABLE public.study_sessions DROP COLUMN IF EXISTS synced_at;

COMMIT;
