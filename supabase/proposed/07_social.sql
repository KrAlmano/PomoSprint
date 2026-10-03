-- ============================================================
-- ÖNERİ 07: Sosyal RPC'ler ve activity_feed RLS         ÖNCELİK: P2
-- ============================================================
-- Bulgular: BACKEND-19 (activity_feed RLS 'sosyal akışta görün' tercihini
-- atlıyor; yanıltıcı service role politikası), BACKEND-14 / SOCIAL-19
-- (get_live_friends iki satırlı modelde aynı arkadaşı iki kez döndürüyor),
-- BACKEND-22 / SOCIAL-26 (get_friends_feed SQL hatası veriyor, istemci hiç
-- çağırmıyor), BACKEND-26 / TIMER-22 (start_study_session girdileri
-- doğrulanmıyor; eski kuyruk seansı canlı seansı siliyor), SOCIAL-20
-- (arkadaş kodu normalize edilmiyor, ham hata metni).
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- ÖN KOŞUL: 20261003120000_audit_fixes (my_friend_ids()).
--
-- ADIMLAR
--  1. Canlı gövdeleri alın:
--       select p.proname, pg_get_functiondef(p.oid) from pg_proc p
--       join pg_namespace n on n.oid = p.pronamespace
--       where n.nspname = 'public' and p.proname in
--         ('get_live_friends', 'get_friends_feed', 'start_study_session',
--          'add_friend_by_code', 'respond_friend_request');
--       select polname, pg_get_expr(polqual, polrelid) from pg_policy
--       where polrelid = 'public.activity_feed'::regclass;
--  2. Canlı gövdeler repodakiyle (20260809025000) aynıysa A-D'yi yeni bir
--     migration'da uygulayın; farklıysa yalnızca açıklanan değişiklikleri
--     canlı gövdeye taşıyın.
--  3. E (add_friend_by_code) yalnızca değişiklik bloğudur; canlı gövde
--     repoda yok.
-- ============================================================

\echo 'supabase/proposed/07: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

-- ------------------------------------------------------------
-- A) activity_feed RLS (BACKEND-19)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_visible_in_social_feed(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE((SELECT show_in_social_feed FROM public.profiles WHERE id = p_user_id), false);
$$;
REVOKE ALL ON FUNCTION public.is_visible_in_social_feed(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_visible_in_social_feed(uuid) TO authenticated;

DROP POLICY IF EXISTS "Users can see their own and friends activity feed" ON public.activity_feed;
CREATE POLICY "Users can see their own and friends activity feed"
    ON public.activity_feed FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR (user_id IN (SELECT public.my_friend_ids())
            AND public.is_visible_in_social_feed(user_id))
    );

-- service_role zaten RLS'i atlar; bu politika istemciler için etkisiz ve
-- yanıltıcı.
DROP POLICY IF EXISTS "Service role full access on activity_feed" ON public.activity_feed;

-- Daha sıkı alternatif: istemci akışı yalnızca RPC ile okuyorsa doğrudan
-- SELECT'i tamamen kapatın:
-- REVOKE SELECT ON public.activity_feed FROM anon, authenticated;

-- ------------------------------------------------------------
-- B) get_live_friends: tek kaynaklı arkadaş kümesi (BACKEND-14)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_live_friends()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'name', p.name,
            'avatar_id', p.avatar_id,
            'category_name', p.active_session_category_name,
            'ends_at', p.active_session_ends_at
        ) ORDER BY p.active_session_ends_at
    ), '[]'::jsonb)
    FROM public.profiles p
    WHERE p.id IN (SELECT fid FROM public.my_friend_ids() AS fid)
      AND p.show_in_social_feed = true
      AND p.active_session_ends_at > now();
$$;
REVOKE ALL ON FUNCTION public.get_live_friends() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_live_friends() TO authenticated;

-- ------------------------------------------------------------
-- C) get_friends_feed (BACKEND-22) — ya düzeltin ya kaldırın
-- ------------------------------------------------------------
-- Ürün akışı kullanmayacaksa (SOCIAL-26): istemcideki getFriendsFeed'i,
-- bu fonksiyonu, complete_study_session'daki activity_feed yazımlarını
-- (öneri 01, DEĞİŞİKLİK 7) ve cleanup_activity_feed_job'u kaldırın.
-- Kullanılacaksa düzeltilmiş gövde (ORDER BY/LIMIT alt sorguda):
CREATE OR REPLACE FUNCTION public.get_friends_feed(p_limit integer DEFAULT 50)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE(jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC, x.id), '[]'::jsonb)
    FROM (
        SELECT a.id,
               p.id AS user_id,
               p.name,
               p.avatar_id,
               a.activity_type,
               a.payload,
               a.activity_date,
               a.created_at
        FROM public.activity_feed a
        JOIN public.profiles p ON p.id = a.user_id
        WHERE a.user_id = auth.uid()
           OR (a.user_id IN (SELECT fid FROM public.my_friend_ids() AS fid)
               AND p.show_in_social_feed = true)
        ORDER BY a.created_at DESC, a.id
        LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200)
    ) x;
$$;
REVOKE ALL ON FUNCTION public.get_friends_feed(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_friends_feed(integer) TO authenticated;

-- ------------------------------------------------------------
-- D) start_study_session: doğrulama + seans kimliği (BACKEND-26, TIMER-22)
-- ------------------------------------------------------------
-- Eski imza (p_duration_minutes, p_category_name) istemciler güncellenene
-- kadar kalır, yalnızca girdileri doğrular. Yeni istemci üç parametreli
-- sürümü çağırır: kalan dakikayı (duraklat-devam sonrası) ve seansın
-- client_uuid'ini gönderir; complete_study_session yalnızca aynı uuid'li
-- aktif seansı temizler (öneri 01, DEĞİŞİKLİK 5).
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS active_session_client_uuid uuid;

CREATE OR REPLACE FUNCTION public.start_study_session(p_duration_minutes integer, p_category_name text)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE public.profiles
    SET active_session_ends_at = now() + make_interval(mins => LEAST(GREATEST(p_duration_minutes, 1), 50)),
        active_session_category_name = left(btrim(p_category_name), 50),
        active_session_client_uuid = NULL
    WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.start_study_session(
    p_duration_minutes integer,
    p_category_name text,
    p_client_uuid uuid
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE public.profiles
    SET active_session_ends_at = now() + make_interval(mins => LEAST(GREATEST(p_duration_minutes, 1), 50)),
        active_session_category_name = left(btrim(p_category_name), 50),
        active_session_client_uuid = p_client_uuid
    WHERE id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.start_study_session(integer, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.start_study_session(integer, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_study_session(integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_study_session(integer, text, uuid) TO authenticated;

-- cancel_study_session de uuid'i temizlemeli:
CREATE OR REPLACE FUNCTION public.cancel_study_session()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE public.profiles
    SET active_session_ends_at = NULL,
        active_session_category_name = NULL,
        active_session_client_uuid = NULL
    WHERE id = auth.uid();
$$;
REVOKE ALL ON FUNCTION public.cancel_study_session() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_study_session() TO authenticated;

COMMIT;

-- ------------------------------------------------------------
-- E) add_friend_by_code / respond_friend_request (SOCIAL-20, K6) —
--    CANLI gövdeye uygulanacak değişiklikler
-- ------------------------------------------------------------
-- 1. Kodu normalize edin (WhatsApp'tan küçük harfli/boşluklu yapıştırma):
--      p_code := upper(regexp_replace(COALESCE(p_code, ''), '\s', '', 'g'));
--    ve profiles.friend_code karşılaştırmasını upper(friend_code) = p_code
--    yapın (kodlar zaten büyük harf üretiliyorsa yalnızca ilk satır yeter).
-- 2. Yanıtlara makine-okunur 'code' alanı ekleyin; istemci ARB ile
--    yerelleştirir (Türkçe 'message' geriye dönük uyumluluk için kalabilir):
--      {'success': false, 'code': 'not_found'}        kod bulunamadı
--      {'success': false, 'code': 'self_add'}         kendi kodu
--      {'success': false, 'code': 'already_friends'}  zaten arkadaş
--      {'success': false, 'code': 'already_pending'}  bekleyen istek var
--      {'success': true,  'code': 'request_sent'}
--      {'success': true,  'code': 'accepted'}         karşı taraf zaten istek göndermişse
--    respond_friend_request: 'accepted' / 'rejected' / 'not_found'.
-- 3. Kabul tek satır mı iki satır mı üretiyor, doğrulayın. Okuma tarafı
--    (my_friend_ids) iki modeli de destekler; tek modele inmek için
--    respond_friend_request yalnızca mevcut satırın status'unu
--    'accepted' yapmalı (ikinci satır eklemeden).
-- 4. Yeni istek gönderilirken karşı yönde bekleyen istek varsa ikisini
--    birden 'accepted' yapın (karşılıklı istek).
