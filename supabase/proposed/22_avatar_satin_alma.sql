-- ============================================================================
-- ÖNERİ 22: AVATAR SATIN ALMA KİLİDİ VE SONRADAN EKLENEN VARSAYILAN AVATAR
--                                                           ÖNCELİK: P2
-- ============================================================================
-- Test ajanı bulguları (5 Ekim 2026, yerel kopyada yeniden üretildi:
-- supabase/tests/proposed_20_25_race_local.sh ve
-- proposed_20_25_bulgu_repro_local.sql):
--  t4-F1  (medium) purchase_avatar eşzamanlı satın almada kayıp güncelleme:
--         300 kumla 400 kumluk iki avatar alınıyor; profil satırı kilitsiz
--         okunup bakiye MUTLAK değerle yazılıyor (UPDATE ... SET coins =
--         v_user_coins). Aynı kalıp, satın alma sırasında biten seansın +20
--         kumunu da eziyor (300 + 20 - 200 = 100 kalıyor).
--  t4-F9  Kataloğa sonradan eklenen varsayılan (ücretsiz) avatarı istemci
--         'sahip' sayıyor (isOwned = isDefault || unlock), sunucu
--         set_equipped_avatar 'Bu avatar kilitli.' diyor (give_default_avatars
--         yalnızca profil oluşurken çalışıyor).
--  Bilinen: proposed/05 (11'e bağlı, uygulanmadı) aynı kilidi öneriyordu; bu
--  dosya zincirdeki gövdeden yazıldı ve 05'in yerini alır.
--
-- SIRA: zincirden (… → 13 → 14) ve 20, 21'den SONRA (onlarla çakışmaz; md5
-- ön koşulu zincirdeki gövdeleri bekler). Gövdeler zincir uygulanmış hâlden
-- (canlı gövde + 13'ün pg_temp'i) türetildi; "proposed/22" yorumlu satırlar
-- dışında aynı. Hata metinleri ve dönüş değerleri DEĞİŞMEDİ.
--
-- DEĞİŞİKLİKLER
--  purchase_avatar: profil satırı kimlik denetiminden hemen sonra FOR UPDATE
--    ile okunur (bakiye + premium); ikinci eşzamanlı çağrı bekler ve güncel
--    bakiyeyi görür. Düşüm göreli ve koşullu: UPDATE ... SET coins = coins -
--    bedel WHERE coins >= bedel RETURNING coins.
--  set_equipped_avatar: kayıt yoksa ama avatar is_default ve is_active ise
--    avatar_unlocks'a 'default' kaydı yazılır ve kuşanılır; aksi halde aynı
--    'Bu avatar kilitli.' hatası.
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- ADIMLAR (SQL Editor, kullanıcı çalıştırır)
--  1. supabase/tests/proposed_22_avatar_satin_alma_dryrun.sql → sonda
--     DRYRUN_RESULT; her madde 'true'.
--  2. Bu dosya \echo/\quit satırları silinerek (geçmişe 20261005122000
--     avatar_satin_alma).
--  3. Eşzamanlılık yerelde: supabase/tests/proposed_20_25_race_local.sh.
--  4. Geri alma: 22_avatar_satin_alma_down.sql.
-- ============================================================================

\echo 'supabase/proposed/22: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

-- ---------------------------------------------------------------------------
-- 0) Ön koşul: gövdeler zincirdeki hâlinde mi?
-- ---------------------------------------------------------------------------
DO $pre$
DECLARE
    v_expected constant jsonb := '{
        "purchase_avatar(text)": "9cdcd1330d18fd5304146e65a80b01be",
        "set_equipped_avatar(text)": "b7fc902e7f4dfcdba07b0a86cc9a582b"
    }';
    r record;
    v_bad text[] := '{}';
BEGIN
    FOR r IN SELECT key, value FROM jsonb_each_text(v_expected) LOOP
        IF to_regprocedure('public.' || r.key) IS NULL
           OR md5(pg_get_functiondef(to_regprocedure('public.' || r.key))) IS DISTINCT FROM r.value THEN
            v_bad := v_bad || r.key;
        END IF;
    END LOOP;
    IF array_length(v_bad, 1) > 0 THEN
        RAISE EXCEPTION 'proposed/22 ön koşulu: canlı tanım beklenenden farklı: % (zincirdeki 13 uygulanmış gövde bekleniyor). Dosyayı yeni gövdeye uyarlayın.',
            array_to_string(v_bad, ', ');
    END IF;
END
$pre$;

-- ---------------------------------------------------------------------------
-- 1) purchase_avatar: kilit + göreli, koşullu düşüm
-- ---------------------------------------------------------------------------
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

    -- proposed/22 (t4-F1): kullanıcı başına kilit; bakiye ve premium durumu
    -- kilit altında okunur. Eşzamanlı ikinci satın alma (ya da kum ekleyen
    -- complete_study_session) bekler ve güncel bakiyeyi görür.
    SELECT is_premium, coins INTO v_is_premium, v_user_coins
    FROM public.profiles
    WHERE id = v_uid
    FOR UPDATE;

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
        RETURN v_user_coins;
    END IF;

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

    -- proposed/22 (t4-F1): düşüm göreli ve koşullu; mutlak bakiye yazılmaz.
    UPDATE public.profiles
    SET coins = coins - v_avatar.cost_coins
    WHERE id = v_uid AND coins >= v_avatar.cost_coins
    RETURNING coins INTO v_user_coins;

    IF NOT FOUND THEN
        SELECT coins INTO v_user_coins FROM public.profiles WHERE id = v_uid;
        RAISE EXCEPTION 'Yetersiz bakiye. Bu avatar için % kum tanesi gerekiyor, senin % kum tanen var.', v_avatar.cost_coins, v_user_coins;
    END IF;

    INSERT INTO public.avatar_unlocks (user_id, avatar_id, unlock_type, coins_spent)
    VALUES (v_uid, p_avatar_id, 'coins', v_avatar.cost_coins);

    RETURN v_user_coins;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2) set_equipped_avatar: sonradan eklenen varsayılan avatar
-- ---------------------------------------------------------------------------
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
        -- proposed/22 (t4-F9): kataloğa sonradan eklenen varsayılan (ücretsiz)
        -- avatar da sahip sayılır (istemcideki isOwned ile aynı); kaydı yazılır.
        IF EXISTS (SELECT 1 FROM public.avatars a
                    WHERE a.id = p_avatar_id AND a.is_default AND a.is_active) THEN
            INSERT INTO public.avatar_unlocks (user_id, avatar_id, unlock_type, coins_spent)
            VALUES (v_uid, p_avatar_id, 'default', 0)
            ON CONFLICT (user_id, avatar_id) DO NOTHING;
        ELSE
            RAISE EXCEPTION 'Bu avatar kilitli.';
        END IF;
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
    INSERT INTO supabase_migrations.schema_migrations (version, name)
    VALUES ('20261005122000', 'avatar_satin_alma')
    ON CONFLICT (version) DO NOTHING;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişine yazılamadı: %', SQLERRM;
END $$;

COMMIT;
