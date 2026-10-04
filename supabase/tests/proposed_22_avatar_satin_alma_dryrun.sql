-- ============================================================================
-- KURU ÇALIŞTIRMA: supabase/proposed/22_avatar_satin_alma.sql
-- (canlıda hiçbir şeyi kalıcı DEĞİŞTİRMEZ)
-- Supabase Dashboard > SQL Editor'e yapıştırıp Run'a basın. Öneri bir
-- transaction içinde uygulanır, senaryolar sentetik kullanıcılarla
-- (@example.invalid) ve işlem içinde eklenen sentetik avatarlarla çalışır,
-- en sonda bilinçli bir hata (DRYRUN_RESULT) fırlatılır ve her şey geri
-- alınır. Her maddenin sonu 'true' olmalı.
--
-- Notlar
--  * Eşzamanlı iki satın alma tek transaction'da sınanamaz: T01 kilidin ve
--    göreli düşümün gövdede olduğunu denetler; iki bağlantılı gerçek senaryo
--    yerelde supabase/tests/proposed_20_25_race_local.sh.
--  * Gövde 22_avatar_satin_alma.sql ile birebir aynıdır (BEGIN/COMMIT hariç);
--    tool/local_supabase/proposed_chain_check.sh bunu denetler.
-- ============================================================================
BEGIN;

-- >>> ÖNERİ GÖVDESİ (supabase/proposed/22_avatar_satin_alma.sql, BEGIN/COMMIT hariç, birebir) >>>

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

-- <<< ÖNERİ GÖVDESİ SONU <<<

-- ---------------------------------------------------------------------------
-- Senaryolar
-- ---------------------------------------------------------------------------
DO $dry$
DECLARE
  res text[] := '{}';
  v_def text := pg_get_functiondef('public.purchase_avatar(text)'::regprocedure);
  v_int integer;
  v_int2 integer;
  v_txt text;
  v_bool boolean;
  u uuid := gen_random_uuid();
  up uuid := gen_random_uuid();
BEGIN
  INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role) VALUES
    (u, 'dryrun22-a-' || u || '@example.invalid', '{"name":"Dry Avatar"}', 'authenticated', 'authenticated'),
    (up, 'dryrun22-p-' || up || '@example.invalid', '{"name":"Dry Premium"}', 'authenticated', 'authenticated');
  UPDATE public.profiles SET coins = 300 WHERE id = u;
  INSERT INTO public.avatars (id, name_tr, name_en, asset_key, cost_coins, is_premium_only, is_default, is_active, is_league_award) VALUES
    ('dryrun22_coin_a', 'Dry A', 'Dry A', 'avatar_16_basic.png', 200, false, false, true, false),
    ('dryrun22_coin_b', 'Dry B', 'Dry B', 'avatar_16_basic.png', 200, false, false, true, false),
    ('dryrun22_premium', 'Dry P', 'Dry P', 'avatar_16_basic.png', 0, true, false, true, false),
    ('dryrun22_award', 'Dry L', 'Dry L', 'avatar_16_basic.png', 0, false, false, true, true),
    ('dryrun22_new_default', 'Dry Yeni', 'Dry New', 'avatar_16_basic.png', 0, false, true, true, false),
    ('dryrun22_old_default', 'Dry Eski', 'Dry Old', 'avatar_16_basic.png', 0, false, true, false, false);

  res := res || ('T01 profil kilidi her denetimden önce, düşüm göreli ve koşullu: '
                 || (strpos(v_def, 'FOR UPDATE') > 0
                     AND strpos(v_def, 'FOR UPDATE') < strpos(v_def, 'FROM public.avatars WHERE id = p_avatar_id')
                     AND strpos(v_def, 'SET coins = coins - v_avatar.cost_coins') > 0
                     AND strpos(v_def, 'SET coins = v_user_coins') = 0)::text);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_int := public.purchase_avatar('dryrun22_coin_a');
  v_txt := NULL;
  BEGIN
    PERFORM public.purchase_avatar('dryrun22_coin_b');
  EXCEPTION WHEN OTHERS THEN v_txt := SQLERRM;
  END;
  v_int2 := public.purchase_avatar('dryrun22_coin_a');
  EXECUTE 'RESET ROLE';
  res := res || ('T02 300 kumla 200''lük alınır (100 kalır), ikincisi aynı metinle reddedilir: '
                 || coalesce(v_int = 100 AND v_txt = 'Yetersiz bakiye. Bu avatar için 200 kum tanesi gerekiyor, senin 100 kum tanen var.'
                             AND (SELECT coins FROM public.profiles WHERE id = u) = 100, false)::text);
  res := res || ('T03 sahip olunan avatar tekrar: bakiye döner, düşüm yok: '
                 || coalesce(v_int2 = 100 AND (SELECT count(*) FROM public.avatar_unlocks WHERE user_id = u AND avatar_id = 'dryrun22_coin_a') = 1, false)::text);

  EXECUTE 'SET LOCAL ROLE authenticated';
  v_txt := '';
  BEGIN PERFORM public.purchase_avatar('dryrun22_award');
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLERRM || '|'; END;
  BEGIN PERFORM public.purchase_avatar('dryrun22_premium');
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLERRM || '|'; END;
  BEGIN PERFORM public.purchase_avatar('dryrun22_yok');
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLERRM || '|'; END;
  EXECUTE 'RESET ROLE';
  res := res || ('T04 lig ödülü, premium ve olmayan avatar metinleri aynı: '
                 || (v_txt = 'Bu avatar satın alınamaz. Yalnızca lig sıralamasında ilk 3''e girerek kazanılabilir.|'
                             || 'Bu avatar sadece Premium kullanıcılar içindir.|Avatar bulunamadı veya pasif durumda.|')::text);

  UPDATE public.profiles SET is_premium = true, coins = 50 WHERE id = up;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', up, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_int := public.purchase_avatar('dryrun22_premium');
  EXECUTE 'RESET ROLE';
  res := res || ('T05 premium kullanıcı premium avatarı ücretsiz alır: '
                 || coalesce(v_int = 50 AND EXISTS (SELECT 1 FROM public.avatar_unlocks WHERE user_id = up
                                                     AND avatar_id = 'dryrun22_premium' AND unlock_type = 'premium'), false)::text);

  -- t4-F9: kullanıcı oluştuktan SONRA eklenen varsayılan avatar
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_bool := public.set_equipped_avatar('dryrun22_new_default');
  EXECUTE 'RESET ROLE';
  res := res || ('T06 sonradan eklenen varsayılan avatar kuşanılır, default kaydı yazılır: '
                 || coalesce(v_bool AND (SELECT avatar_id FROM public.profiles WHERE id = u) = 'dryrun22_new_default'
                             AND EXISTS (SELECT 1 FROM public.avatar_unlocks WHERE user_id = u
                                          AND avatar_id = 'dryrun22_new_default' AND unlock_type = 'default'), false)::text);

  EXECUTE 'SET LOCAL ROLE authenticated';
  v_txt := '';
  BEGIN PERFORM public.set_equipped_avatar('dryrun22_coin_b');
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLERRM || '|'; END;
  BEGIN PERFORM public.set_equipped_avatar('dryrun22_old_default');
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLERRM || '|'; END;
  v_bool := public.set_equipped_avatar('dryrun22_coin_a');
  EXECUTE 'RESET ROLE';
  res := res || ('T07 alınmamış ücretli ve pasif varsayılan avatar kilitli, alınmış kuşanılır: '
                 || coalesce(v_txt = 'Bu avatar kilitli.|Bu avatar kilitli.|' AND v_bool
                             AND (SELECT avatar_id FROM public.profiles WHERE id = u) = 'dryrun22_coin_a', false)::text);

  res := res || ('T08 yetkiler aynı (authenticated evet, anon hayır): '
                 || (has_function_privilege('authenticated', 'public.purchase_avatar(text)', 'EXECUTE')
                     AND NOT has_function_privilege('anon', 'public.purchase_avatar(text)', 'EXECUTE')
                     AND has_function_privilege('authenticated', 'public.set_equipped_avatar(text)', 'EXECUTE')
                     AND NOT has_function_privilege('anon', 'public.set_equipped_avatar(text)', 'EXECUTE'))::text);
  SELECT count(*) INTO v_int FROM supabase_migrations.schema_migrations WHERE version = '20261005122000';
  res := res || ('T09 migration geçmişine yazıldı: ' || (v_int = 1)::text);

  RAISE EXCEPTION 'DRYRUN_RESULT >> %', array_to_string(res, ' || ');
END
$dry$;

ROLLBACK;
