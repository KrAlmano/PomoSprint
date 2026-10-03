-- ============================================================
-- ÖNERİ 04: cleanup_unconfirmed_duplicate_identity     ÖNCELİK: P1 (güvenlik)
-- ============================================================
-- Bulgu: AUTH-V03. Google/Apple girişinden sonra istemci bu RPC'yi
-- p_email ile çağırıyor. Fonksiyon repoda yok. Parametreye güveniyorsa
-- oturum açmış herhangi biri başkasının henüz onaylanmamış e-posta
-- kaydını silebilir (kayıt engelleme).
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- ADIMLAR
--  1. Canlı gövdeyi alın:
--       select pg_get_functiondef(p.oid), pg_get_function_result(p.oid)
--       from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--       where n.nspname = 'public' and p.proname = 'cleanup_unconfirmed_duplicate_identity';
--  2. Canlı gövde e-postayı auth.jwt() / auth.users'tan alıp
--     parametreyle karşılaştırıyorsa değişiklik gerekmez; repoya alın.
--     Değilse aşağıdaki gövdeyi kullanın:
--       * RETURNS tipini canlıdakiyle AYNI yapın (CREATE OR REPLACE dönüş
--         tipini değiştiremez; farklıysa hata verir, sessizce bozulmaz).
--       * Canlı gövde silmeyi başka bir yolla yapıyorsa (ör. profili de
--         ayrıca siliyorsa) o adımları koruyun.
--       * Supabase'te postgres rolünün auth.users üzerinde DELETE yetkisi
--         olduğunu doğrulayın (canlı gövde zaten siliyorsa vardır).
--  3. scripts/security_regression_test.js: 'A, B'nin e-postasıyla temizlik
--     çağıramaz' (hata beklenir) ve 'A kendi e-postasıyla çağırabilir'
--     (hata yok) senaryoları bu gövdeyle geçer.
-- ============================================================

\echo 'supabase/proposed/04: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

CREATE OR REPLACE FUNCTION public.cleanup_unconfirmed_duplicate_identity(p_email text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_email text := lower(btrim(auth.jwt() ->> 'email'));
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
    END IF;

    -- E-posta parametreden DEĞİL oturumdaki kimlikten gelir. Çağıranın
    -- kendi kaydı onaylı olmalı (ör. Google/Apple girişi).
    IF v_email IS NULL OR v_email = '' OR NOT EXISTS (
        SELECT 1 FROM auth.users u
        WHERE u.id = v_uid
          AND lower(btrim(u.email)) = v_email
          AND u.email_confirmed_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'email_not_confirmed' USING ERRCODE = '42501';
    END IF;

    -- Parametre geriye dönük uyumluluk için kabul edilir ama yalnızca
    -- doğrulama amaçlı: başka bir adres gönderilirse reddedilir.
    IF p_email IS NOT NULL AND lower(btrim(p_email)) <> v_email THEN
        RAISE EXCEPTION 'email_mismatch' USING ERRCODE = '42501';
    END IF;

    DELETE FROM auth.users u
    WHERE lower(btrim(u.email)) = v_email
      AND u.id <> v_uid
      AND u.email_confirmed_at IS NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.cleanup_unconfirmed_duplicate_identity(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cleanup_unconfirmed_duplicate_identity(text) TO authenticated;

COMMIT;
