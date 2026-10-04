-- ============================================================================
-- ÖNERİ 23: KATEGORİ BÜTÜNLÜĞÜ (onboarding uzlaştırma, ad/renk/ikon,
-- eşzamanlılık)                                              ÖNCELİK: P2
-- ============================================================================
-- Test ajanı bulguları (5 Ekim 2026, yerel kopyada yeniden üretildi:
-- supabase/tests/proposed_20_25_bulgu_repro_local.sql ve
-- proposed_20_25_race_local.sh):
--  t2-03  (medium) Yeniden denenen onboarding kategorileri uzlaştırmıyor:
--         önceki denemenin kategorileri kalıyor, yeni seçim limitte sessizce
--         düşüyor (YKS 8 → work 4: aktif hâlâ YKS 8); dil değişince TR + EN
--         çift kategori (Matematik + Mathematics).
--  t2-06  Ad/renk/ikon sunucuda doğrulanmıyor ('kirmizi', '<script>');
--         'Matematik', 'matematik', 'Matematik ' ayrı kategori. Zincirden
--         SONRA (13'ün ad trigger'ı) durum daha kötü: setup_onboarding_
--         categories yükte tek bir boş / büyük-küçük harf farklı ad varsa
--         TAMAMEN düşüyor (23514 / 23505) ve onboarding bitemiyor.
--  t2-07  Eşzamanlı iki kategori kurulumu / iki create_category ücretsiz
--         limiti aşıyor (8 yerine 16 / 9).
--
-- SIRA: zincirden (… → 16 → 19 → 13 → 14) SONRA; 20–22 ile çakışmaz. Gövdeler
-- zincir uygulanmış hâlden türetildi: setup_onboarding_categories ve
-- create_category = proposed/16 gövdeleri, enforce_category_limit = canlı
-- gövde. 13'ün yardımcıları (clean_display_text, display_text_is_allowed) ve
-- ad trigger'ı (enforce_category_name) kullanılır. İlk adım md5'leri denetler.
--
-- DEĞİŞİKLİKLER
--  A. category_name_key(ad): büyük/küçük harf ve Türkçe İ/I/ı duyarsız
--     karşılaştırma anahtarı (lower(translate(btrim(ad), 'İIı', 'iii'))).
--  B. enforce_category_rules trigger'ı (BEFORE INSERT / UPDATE OF name,
--     color_hex, icon_name, is_archived; 13'ün ad trigger'ından SONRA çalışır):
--     - kullanıcının profil satırını kilitler (t2-07: limit ve tekillik
--       denetimleri kullanıcı başına sıralı);
--     - renk yazılırken '#RRGGBB' değilse 'category_color_invalid' (23514);
--     - ikon yazılırken NULL ya da [a-z0-9_]{1,40} değilse
--       'category_icon_invalid' (23514);
--     - aktif olacak kategorinin adı (anahtarla) başka bir AKTİF kategoriyle
--       aynıysa 'Bu isimde aktif bir kategori zaten var.' (23505; istemci
--       service_errors bu metni ve 23505'i zaten tanıyor).
--     Yalnızca yazılan alan denetlenir: mevcut bozuk renkli / eski çift adlı
--     satırlar arşivlenebilir, sıralanabilir; DOKUNULMAZ (veri göçü yok).
--  C. enforce_category_limit: sayımdan önce profil kilidi (t2-07).
--  D. create_category: başta profil kilidi; çift ad denetimi anahtarla.
--     Hata metinleri aynı.
--  E. setup_onboarding_categories (dönüş tipi void → jsonb; DROP + CREATE,
--     yetkiler yeniden yazılır):
--     - başta profil kilidi (t2-07);
--     - her öğe temizlenir (clean_display_text) ve doğrulanır (ad 1..40 ve
--       izinli, renk, ikon); geçersiz öğe ATLANIR (eskiden 13'ten sonra
--       tüm çağrı düşüyordu), yükteki anahtar tekrarı atlanır;
--     - onboarding_completed_at NULL iken (yeniden denenen onboarding):
--       yükte olmayan ve SEANSI OLMAYAN aktif kategoriler arşivlenir; yükteki
--       bir ad daha önce böyle arşivlenmişse yenisi açılmaz, arşivden çıkar;
--       (TR ↔ EN dil değişiminde eski dildeki seansız kategoriler arşive
--       gider, yeni dildekiler açılır: çift yok);
--     - limit dolunca sessizce durmaz, atlananları sayar;
--     - dönüş: {created, restored, skipped_existing, skipped_limit,
--       skipped_invalid, archived}. Bugünkü istemci dönüşü okumuyor (void
--       bekliyordu; supabase-dart yanıtı yok sayar), kırılmaz.
--     Onboarding'i bitmiş kullanıcıda (ensureServerCategories, kuyruk) hiçbir
--     kategori arşivlenmez.
--   ÜRÜN ETKİSİ: onboarding'i yarım kalmış eski kullanıcı onboarding'i yeniden
--   yaparken seçmediği ve hiç seans girmediği kategoriler arşive gider
--   (silinmez; Kategorilerim'den geri açılır).
--
-- İSTEMCİ SÖZLEŞMESİ: setup_onboarding_categories yanıtı jsonb (yukarıda);
-- yeni istemci skipped_limit > 0 ise uyarabilir. create_category / doğrudan
-- yazımda yeni hata metinleri: category_color_invalid, category_icon_invalid
-- (23514; bugün invalidInput'a düşer).
--
-- ÖNCE (salt okuma, isteğe bağlı): canlıda büyük/küçük harf farkıyla çift
-- aktif kategori ve bozuk renk/ikon var mı? (Varsa dokunulmaz; bilgi için.)
--   select user_id, lower(translate(btrim(name), 'İIı', 'iii')) k, count(*)
--     from public.categories where not is_archived group by 1, 2 having count(*) > 1;
--   select count(*) filter (where color_hex !~ '^#[0-9A-Fa-f]{6}$'),
--          count(*) filter (where icon_name !~ '^[a-z0-9_]{1,40}$') from public.categories;
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- ADIMLAR (SQL Editor, kullanıcı çalıştırır)
--  1. supabase/tests/proposed_23_kategori_butunluk_dryrun.sql → sonda
--     DRYRUN_RESULT; her madde 'true'.
--  2. Bu dosya \echo/\quit satırları silinerek (geçmişe 20261005123000
--     kategori_butunluk).
--  3. Eşzamanlılık yerelde: supabase/tests/proposed_20_25_race_local.sh.
--  4. Geri alma: 23_kategori_butunluk_down.sql.
-- ============================================================================

\echo 'supabase/proposed/23: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

-- ---------------------------------------------------------------------------
-- 0) Ön koşul: zincir uygulanmış, gövdeler beklenen hâlde
-- ---------------------------------------------------------------------------
DO $pre$
DECLARE
    v_expected constant jsonb := '{
        "setup_onboarding_categories(jsonb)": "ae43cbc3a5cf164ea7e2d0ba74c7b7a9",
        "create_category(text,text,text)": "a18e2ad9af94c786a4e7d97f9b252d50",
        "enforce_category_limit()": "15eec60b4e8bbb9b6d7b4542028af9d4"
    }';
    r record;
    v_bad text[] := '{}';
BEGIN
    IF to_regprocedure('public.clean_display_text(text)') IS NULL
       OR to_regprocedure('public.display_text_is_allowed(text)') IS NULL
       OR to_regprocedure('public.place_unarchived_category_last()') IS NULL
       OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.categories'::regclass
                       AND tgname = 'enforce_category_name') THEN
        RAISE EXCEPTION 'proposed/23 ön koşulu: önce zincir uygulanmalı (16 ve 13: place_unarchived_category_last, enforce_category_name).';
    END IF;
    FOR r IN SELECT key, value FROM jsonb_each_text(v_expected) LOOP
        IF to_regprocedure('public.' || r.key) IS NULL
           OR md5(pg_get_functiondef(to_regprocedure('public.' || r.key))) IS DISTINCT FROM r.value THEN
            v_bad := v_bad || r.key;
        END IF;
    END LOOP;
    IF array_length(v_bad, 1) > 0 THEN
        RAISE EXCEPTION 'proposed/23 ön koşulu: canlı tanım beklenenden farklı: %. Dosyayı yeni gövdeye uyarlayın.',
            array_to_string(v_bad, ', ');
    END IF;
END
$pre$;

-- ---------------------------------------------------------------------------
-- A) Ad anahtarı
-- ---------------------------------------------------------------------------
CREATE FUNCTION public.category_name_key(p_name text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT lower(translate(btrim(p_name), 'İIı', 'iii'))
$function$;

-- ---------------------------------------------------------------------------
-- B) enforce_category_rules
-- ---------------------------------------------------------------------------
CREATE FUNCTION public.enforce_category_rules()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    -- t2-07: kullanıcı başına sıralama; limit ve tekillik kilit altında.
    PERFORM 1 FROM public.profiles WHERE id = NEW.user_id FOR UPDATE;

    IF TG_OP = 'INSERT' OR NEW.color_hex IS DISTINCT FROM OLD.color_hex THEN
        IF NEW.color_hex IS NULL OR NEW.color_hex !~ '^#[0-9A-Fa-f]{6}$' THEN
            RAISE EXCEPTION 'category_color_invalid'
                USING ERRCODE = 'check_violation',
                      HINT = 'Renk #RRGGBB biçiminde olmalı.';
        END IF;
    END IF;

    IF TG_OP = 'INSERT' OR NEW.icon_name IS DISTINCT FROM OLD.icon_name THEN
        IF NEW.icon_name IS NOT NULL AND NEW.icon_name !~ '^[a-z0-9_]{1,40}$' THEN
            RAISE EXCEPTION 'category_icon_invalid'
                USING ERRCODE = 'check_violation',
                      HINT = 'İkon adı küçük harf, rakam ve alt çizgiden oluşmalı (en çok 40).';
        END IF;
    END IF;

    IF NOT NEW.is_archived
       AND (TG_OP = 'INSERT' OR NEW.name IS DISTINCT FROM OLD.name OR OLD.is_archived) THEN
        IF EXISTS (SELECT 1 FROM public.categories c
                    WHERE c.user_id = NEW.user_id AND NOT c.is_archived AND c.id <> NEW.id
                      AND public.category_name_key(c.name) = public.category_name_key(NEW.name)) THEN
            RAISE EXCEPTION 'Bu isimde aktif bir kategori zaten var.'
                USING ERRCODE = 'unique_violation';
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;

CREATE TRIGGER enforce_category_rules
    BEFORE INSERT OR UPDATE OF name, color_hex, icon_name, is_archived ON public.categories
    FOR EACH ROW EXECUTE FUNCTION public.enforce_category_rules();

-- ---------------------------------------------------------------------------
-- C) enforce_category_limit: sayımdan önce kilit (canlı gövde + kilit)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_category_limit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_is_premium boolean;
    v_active_count integer;
    v_limit integer;
BEGIN
    IF NEW.is_archived THEN
        RETURN NEW;
    END IF;

    -- proposed/23 (t2-07): eşzamanlı eklemeler kullanıcı başına sıralı;
    -- sayım öteki işlemin eklediğini görür.
    SELECT is_premium INTO v_is_premium FROM public.profiles WHERE id = NEW.user_id FOR UPDATE;
    v_is_premium := COALESCE(v_is_premium, false);
    v_limit := CASE WHEN v_is_premium THEN 15 ELSE 8 END;

    SELECT count(*) INTO v_active_count
    FROM public.categories
    WHERE user_id = NEW.user_id AND is_archived = false;

    IF v_active_count >= v_limit THEN
        IF v_is_premium THEN
            RAISE EXCEPTION 'Premium planda en fazla 15 kategori ekleyebilirsin.';
        ELSE
            RAISE EXCEPTION 'Ücretsiz planda en fazla 8 kategori ekleyebilirsin. Premium ile 15''e çıkar.';
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------------------
-- D) create_category (proposed/16 gövdesi + kilit + anahtarla çift ad)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_category(p_name text, p_color_hex text, p_icon_name text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_is_premium boolean;
    v_active_count integer;
    v_limit integer;
    v_new_id uuid;
    v_next_order integer;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Get user premium status (proposed/23 t2-07: kilit altında)
    SELECT is_premium INTO v_is_premium FROM public.profiles WHERE id = v_uid FOR UPDATE;
    IF v_is_premium IS NULL THEN
        v_is_premium := false;
    END IF;

    -- Determine limit
    IF v_is_premium THEN
        v_limit := 15;
    ELSE
        v_limit := 8;
    END IF;

    -- Check current active count
    SELECT count(*), coalesce(max(sort_order), -1) + 1 INTO v_active_count, v_next_order
    FROM public.categories
    WHERE user_id = v_uid AND is_archived = false;

    IF v_active_count >= v_limit THEN
        IF v_is_premium THEN
            RAISE EXCEPTION 'Premium planda en fazla 15 kategori ekleyebilirsin.';
        ELSE
            RAISE EXCEPTION 'Ücretsiz planda en fazla 8 kategori ekleyebilirsin. Premium ile 15''e çıkar.';
        END IF;
    END IF;

    -- Check for active name duplicate (proposed/23 t2-06: büyük/küçük harf ve boşluk duyarsız)
    IF EXISTS (
        SELECT 1 FROM public.categories
        WHERE user_id = v_uid AND is_archived = false
          AND public.category_name_key(name) = public.category_name_key(public.clean_display_text(p_name))
    ) THEN
        RAISE EXCEPTION 'Bu isimde aktif bir kategori zaten var.';
    END IF;

    -- Insert (aktiflerin sonuna)
    INSERT INTO public.categories (user_id, name, color_hex, icon_name, sort_order)
    VALUES (v_uid, p_name, p_color_hex, p_icon_name, v_next_order)
    RETURNING id INTO v_new_id;

    RETURN v_new_id;
END;
$function$;

-- ---------------------------------------------------------------------------
-- E) setup_onboarding_categories: doğrula, uzlaştır, say (void → jsonb)
-- ---------------------------------------------------------------------------
DROP FUNCTION public.setup_onboarding_categories(jsonb);

CREATE FUNCTION public.setup_onboarding_categories(p_categories jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_is_premium boolean;
    v_onboarding_done boolean;
    v_active_count integer;
    v_limit integer;
    v_next_order integer;
    v_cat jsonb;
    v_item jsonb;
    v_items jsonb := '[]'::jsonb;
    v_keys text[] := '{}';
    v_name text;
    v_key text;
    v_color text;
    v_icon text;
    v_restore_id uuid;
    v_created integer := 0;
    v_restored integer := 0;
    v_skipped_existing integer := 0;
    v_skipped_limit integer := 0;
    v_skipped_invalid integer := 0;
    v_archived integer := 0;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- t2-07: kullanıcı başına kilit; sayım, arşivleme ve ekleme sıralı.
    SELECT is_premium, onboarding_completed_at IS NOT NULL
      INTO v_is_premium, v_onboarding_done
      FROM public.profiles
     WHERE id = v_uid
       FOR UPDATE;
    v_is_premium := COALESCE(v_is_premium, false);
    v_onboarding_done := COALESCE(v_onboarding_done, false);
    v_limit := CASE WHEN v_is_premium THEN 15 ELSE 8 END;

    -- 1. Yükü temizle, doğrula, tekilleştir (sıra korunur). Geçersiz öğe
    --    tüm çağrıyı düşürmez, atlanır (t2-06).
    FOR v_cat IN
        SELECT * FROM jsonb_array_elements(
            CASE WHEN jsonb_typeof(p_categories) = 'array' THEN p_categories ELSE '[]'::jsonb END)
    LOOP
        v_name := public.clean_display_text(v_cat->>'name');
        v_color := btrim(v_cat->>'color_hex');
        v_icon := nullif(btrim(v_cat->>'icon_name'), '');
        IF v_name IS NULL OR char_length(v_name) < 1 OR char_length(v_name) > 40
           OR NOT public.display_text_is_allowed(v_name)
           OR v_color IS NULL OR v_color !~ '^#[0-9A-Fa-f]{6}$'
           OR (v_icon IS NOT NULL AND v_icon !~ '^[a-z0-9_]{1,40}$') THEN
            v_skipped_invalid := v_skipped_invalid + 1;
            CONTINUE;
        END IF;
        v_key := public.category_name_key(v_name);
        IF v_key = ANY (v_keys) THEN
            v_skipped_existing := v_skipped_existing + 1;
            CONTINUE;
        END IF;
        v_keys := v_keys || v_key;
        v_items := v_items || jsonb_build_object('name', v_name, 'color_hex', v_color,
                                                 'icon_name', v_icon, 'key', v_key);
    END LOOP;

    -- 2. Onboarding bitmeden yeniden kurulum (t2-03): yükte olmayan ve seansı
    --    olmayan aktif kategoriler arşivlenir (silinmez).
    IF NOT v_onboarding_done AND array_length(v_keys, 1) > 0 THEN
        WITH stale AS (
            UPDATE public.categories c
               SET is_archived = true
             WHERE c.user_id = v_uid
               AND NOT c.is_archived
               AND NOT (public.category_name_key(c.name) = ANY (v_keys))
               AND NOT EXISTS (SELECT 1 FROM public.study_sessions s
                                WHERE s.user_id = v_uid AND s.category_id = c.id)
            RETURNING 1
        )
        SELECT count(*) INTO v_archived FROM stale;
    END IF;

    SELECT count(*), coalesce(max(sort_order), -1) + 1 INTO v_active_count, v_next_order
    FROM public.categories
    WHERE user_id = v_uid AND is_archived = false;

    -- 3. Ekle: aynı adlı aktif kategori varsa atla; limit dolduysa say;
    --    onboarding sırasında arşivlenmiş aynı adlı kategori varsa geri aç.
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_items)
    LOOP
        IF EXISTS (SELECT 1 FROM public.categories c
                    WHERE c.user_id = v_uid AND NOT c.is_archived
                      AND public.category_name_key(c.name) = v_item->>'key') THEN
            v_skipped_existing := v_skipped_existing + 1;
            CONTINUE;
        END IF;

        IF v_active_count >= v_limit THEN
            v_skipped_limit := v_skipped_limit + 1;
            CONTINUE;
        END IF;

        v_restore_id := NULL;
        IF NOT v_onboarding_done THEN
            SELECT c.id INTO v_restore_id
              FROM public.categories c
             WHERE c.user_id = v_uid AND c.is_archived
               AND public.category_name_key(c.name) = v_item->>'key'
             ORDER BY c.created_at DESC, c.id
             LIMIT 1;
        END IF;

        IF v_restore_id IS NOT NULL THEN
            -- place_unarchived_category_last (16) sona alır.
            UPDATE public.categories SET is_archived = false WHERE id = v_restore_id;
            SELECT greatest(v_next_order, c.sort_order + 1) INTO v_next_order
              FROM public.categories c WHERE c.id = v_restore_id;
            v_restored := v_restored + 1;
        ELSE
            INSERT INTO public.categories (user_id, name, color_hex, icon_name, sort_order)
            VALUES (v_uid, v_item->>'name', v_item->>'color_hex', v_item->>'icon_name', v_next_order);
            v_next_order := v_next_order + 1;
            v_created := v_created + 1;
        END IF;
        v_active_count := v_active_count + 1;
    END LOOP;

    RETURN jsonb_build_object(
        'created', v_created,
        'restored', v_restored,
        'skipped_existing', v_skipped_existing,
        'skipped_limit', v_skipped_limit,
        'skipped_invalid', v_skipped_invalid,
        'archived', v_archived
    );
END;
$function$;

-- ---------------------------------------------------------------------------
-- F) Yetkiler. DROP + CREATE ve yeni fonksiyonlar varsayılan yetkileri
-- (pg_default_acl: anon, authenticated) alır; zincirdeki hâle göre yazılır.
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.setup_onboarding_categories(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.setup_onboarding_categories(jsonb) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.create_category(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_category(text, text, text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.enforce_category_limit() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.enforce_category_limit() TO service_role;
REVOKE ALL ON FUNCTION public.enforce_category_rules() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.enforce_category_rules() TO service_role;
REVOKE ALL ON FUNCTION public.category_name_key(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.category_name_key(text) TO service_role;

DO $$
BEGIN
    INSERT INTO supabase_migrations.schema_migrations (version, name)
    VALUES ('20261005123000', 'kategori_butunluk')
    ON CONFLICT (version) DO NOTHING;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişine yazılamadı: %', SQLERRM;
END $$;

COMMIT;
