-- ============================================================================
-- GERİ ALMA: supabase/proposed/22_avatar_satin_alma.sql
-- ============================================================================
-- purchase_avatar ve set_equipped_avatar zincirdeki hâle (canlı gövde +
-- 13'ün pg_temp'i; pg_get_functiondef çıktısıyla BİREBİR) döner. Veri
-- değişmez: 22'nin set_equipped_avatar'ı ile yazılmış 'default' avatar_unlocks
-- kayıtları kalır (zararsız; give_default_avatars'ın yazacağı kayıtla aynı).
-- ============================================================================

\echo 'supabase/proposed/22_down: doğrudan çalıştırılmaz; \echo/\quit satırlarını silip SQL Editor''de çalıştırın.'
\quit

BEGIN;

DO $pre$
BEGIN
    IF pg_get_functiondef('public.purchase_avatar(text)'::regprocedure) NOT LIKE '%proposed/22%' THEN
        RAISE EXCEPTION 'proposed/22_down: 22 uygulanmamış görünüyor; yapılacak bir şey yok.';
    END IF;
END
$pre$;

CREATE OR REPLACE FUNCTION public.purchase_avatar(p_avatar_id text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid;
    v_avatar record;
    v_is_premium boolean;
    v_user_coins integer;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Avatar var mı?
    SELECT * INTO v_avatar FROM public.avatars WHERE id = p_avatar_id AND is_active = true;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Avatar bulunamadı veya pasif durumda.';
    END IF;

    -- Lig ödülü avatarları hiçbir şekilde (jetonla, premium ile) satın alınamaz;
    -- sadece process_weekly_leagues() bir kullanıcıyı o dönemin 1./2./3.sü
    -- ilan ettiğinde otomatik olarak açılır.
    IF v_avatar.is_league_award THEN
        RAISE EXCEPTION 'Bu avatar satın alınamaz. Yalnızca lig sıralamasında ilk 3''e girerek kazanılabilir.';
    END IF;

    -- Kullanıcıda zaten var mı? Varsa sessizce başarılı dön (cüzdan döner)
    IF EXISTS (SELECT 1 FROM public.avatar_unlocks WHERE user_id = v_uid AND avatar_id = p_avatar_id) THEN
        SELECT coins INTO v_user_coins FROM public.profiles WHERE id = v_uid;
        RETURN v_user_coins;
    END IF;

    -- Kullanıcının bakiyesi ve premium durumunu al
    SELECT is_premium, coins INTO v_is_premium, v_user_coins FROM public.profiles WHERE id = v_uid;

    -- Premium kontrolü
    IF v_avatar.is_premium_only THEN
        IF NOT v_is_premium THEN
            RAISE EXCEPTION 'Bu avatar sadece Premium kullanıcılar içindir.';
        END IF;

        -- Premium avatarlar bedavadır (jeton düşme)
        INSERT INTO public.avatar_unlocks (user_id, avatar_id, unlock_type, coins_spent)
        VALUES (v_uid, p_avatar_id, 'premium', 0);

        RETURN v_user_coins;
    END IF;

    -- Jeton bakiyesi kontrolü
    IF v_user_coins < v_avatar.cost_coins THEN
        RAISE EXCEPTION 'Yetersiz bakiye. Bu avatar için % kum tanesi gerekiyor, senin % kum tanen var.', v_avatar.cost_coins, v_user_coins;
    END IF;

    -- Transaction (Tek blok)
    v_user_coins := v_user_coins - v_avatar.cost_coins;

    UPDATE public.profiles 
    SET coins = v_user_coins 
    WHERE id = v_uid;

    INSERT INTO public.avatar_unlocks (user_id, avatar_id, unlock_type, coins_spent)
    VALUES (v_uid, p_avatar_id, 'coins', v_avatar.cost_coins);

    RETURN v_user_coins;
END;
$function$;

CREATE OR REPLACE FUNCTION public.set_equipped_avatar(p_avatar_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Kullanıcı bu avatarı açmış mı?
    IF NOT EXISTS (SELECT 1 FROM public.avatar_unlocks WHERE user_id = v_uid AND avatar_id = p_avatar_id) THEN
        RAISE EXCEPTION 'Bu avatar kilitli.';
    END IF;

    UPDATE public.profiles 
    SET avatar_id = p_avatar_id
    WHERE id = v_uid;

    RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.purchase_avatar(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.purchase_avatar(text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.set_equipped_avatar(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_equipped_avatar(text) TO authenticated, service_role;

DO $$
BEGIN
    DELETE FROM supabase_migrations.schema_migrations WHERE version = '20261005122000';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişinden silinemedi: %', SQLERRM;
END $$;

COMMIT;
