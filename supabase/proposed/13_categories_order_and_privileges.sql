-- ============================================================
-- ÖNERİ 13: Kategori sırası ve yetkileri   ÖNCELİK: P3
-- ============================================================
-- Bulgular: CAT-07 (sort_order çakışması), CAT-10 (DELETE ve id/user_id/
-- created_at UPDATE yetkisi açık).
--
-- A) create_category ve setup_onboarding_categories yeni kategoriye AKTİF
--    SAYISINI yazıyor; bir kategori arşivlenince yeni kategori mevcut biriyle
--    aynı sort_order'ı alıyor. Yeni: aktiflerin en büyük sort_order'ı + 1
--    (her zaman sona eklenir). Gövdeler CANLI tanımdan (3 Ekim 2026); başka
--    hiçbir satır değişmedi (limit, hata metinleri, çift ad kontrolü aynı).
-- B) Arşivden çıkan kategori eski sort_order'ını koruyup başka biriyle
--    çakışıyordu: BEFORE UPDATE trigger'ı onu aktiflerin sonuna alır.
--    (Limit trigger'ı enforce_category_limit_on_unarchive aynen kalır.)
-- C) Tek seferlik: her kullanıcının AKTİF kategorileri mevcut görünen
--    sıralarıyla (sort_order, created_at, id) 0..n-1 olarak yeniden
--    numaralanır. Görünen sıra değişmez; yalnız eşitlikler çözülür. Geri
--    alınamaz ama zararsızdır (istemci de aynı üç anahtarla sıralıyor).
-- D) Yetkiler: 'Silinmez, arşivlenir' sözleşmesi. DELETE politikası ve
--    yetkisi kaldırılır; UPDATE yalnızca name, color_hex, icon_name,
--    is_archived, sort_order kolonlarına. İstemci yalnız bunları yazıyor
--    (supabase_service.dart: archive/unarchive/updateCategory/
--    updateCategoryOrders). RPC'ler SECURITY DEFINER olduğundan etkilenmez.
--
-- ADIMLAR
--  1. 13_categories_order_and_privileges_dryrun.sql'i SQL Editor'de çalıştırın
--     (sonda DRYRUN_RESULT hatası; her satır 'true').
--  2. Bu dosyanın \echo ve \quit satırlarını silip çalıştırın (ya da
--     supabase/migrations/20261003181000_categories_order_and_privileges.sql
--     olarak kopyalayın). Geri alma: 13_categories_order_and_privileges_down.sql.
--  3. Doğrulama:
--       select grantee, privilege_type from information_schema.role_table_grants
--        where table_schema='public' and table_name='categories' and grantee='authenticated';
--       select policyname from pg_policies where tablename='categories';
--  4. AGENTS.md §5.4 / §7.1 categories satırlarını güncelleyin.
-- ============================================================

\echo 'supabase/proposed/13: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

-- ------------------------------------------------------------
-- A) Yeni kategori sona eklenir
-- ------------------------------------------------------------
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

    -- Get user premium status
    SELECT is_premium INTO v_is_premium FROM public.profiles WHERE id = v_uid;
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

    -- Check for exact active name duplicate
    IF EXISTS (
        SELECT 1 FROM public.categories
        WHERE user_id = v_uid AND name = p_name AND is_archived = false
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

CREATE OR REPLACE FUNCTION public.setup_onboarding_categories(p_categories jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_is_premium boolean;
    v_active_count integer;
    v_limit integer;
    v_cat jsonb;
    v_next_order integer;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Get user premium status
    SELECT is_premium INTO v_is_premium FROM public.profiles WHERE id = v_uid;
    IF v_is_premium IS NULL THEN
        v_is_premium := false;
    END IF;

    -- Determine limit
    IF v_is_premium THEN
        v_limit := 15;
    ELSE
        v_limit := 8;
    END IF;

    -- Get current active count
    SELECT count(*), coalesce(max(sort_order), -1) + 1 INTO v_active_count, v_next_order
    FROM public.categories
    WHERE user_id = v_uid AND is_archived = false;

    -- Insert loop
    FOR v_cat IN SELECT * FROM jsonb_array_elements(p_categories)
    LOOP
        -- Stop inserting if we reached the limit (don't throw error to allow onboarding to finish)
        IF v_active_count >= v_limit THEN
            EXIT; -- exit the loop
        END IF;

        -- Ignore duplicates silently
        IF NOT EXISTS (
            SELECT 1 FROM public.categories
            WHERE user_id = v_uid AND name = v_cat->>'name' AND is_archived = false
        ) THEN
            INSERT INTO public.categories (user_id, name, color_hex, icon_name, sort_order)
            VALUES (
                v_uid,
                v_cat->>'name',
                v_cat->>'color_hex',
                v_cat->>'icon_name',
                v_next_order
            );
            v_active_count := v_active_count + 1;
            v_next_order := v_next_order + 1;
        END IF;
    END LOOP;

END;
$function$;

-- Yetkiler CREATE OR REPLACE ile korunur; canlıdaki hâl açıkça yazılır.
REVOKE ALL ON FUNCTION public.create_category(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_category(text, text, text) TO authenticated;
REVOKE ALL ON FUNCTION public.setup_onboarding_categories(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.setup_onboarding_categories(jsonb) TO authenticated;

-- ------------------------------------------------------------
-- B) Arşivden çıkan kategori sona alınır
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.place_unarchived_category_last()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    SELECT coalesce(max(sort_order), -1) + 1 INTO NEW.sort_order
    FROM public.categories
    WHERE user_id = NEW.user_id AND is_archived = false AND id <> NEW.id;
    RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.place_unarchived_category_last() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS place_unarchived_category_last ON public.categories;
CREATE TRIGGER place_unarchived_category_last
    BEFORE UPDATE OF is_archived ON public.categories
    FOR EACH ROW
    WHEN (OLD.is_archived AND NOT NEW.is_archived)
    EXECUTE FUNCTION public.place_unarchived_category_last();

-- ------------------------------------------------------------
-- C) Tek seferlik: aktif kategorilerin sort_order eşitlikleri çözülür
-- ------------------------------------------------------------
WITH ordered AS (
    SELECT id, row_number() OVER (PARTITION BY user_id ORDER BY sort_order, created_at, id) - 1 AS rn
    FROM public.categories
    WHERE is_archived = false
)
UPDATE public.categories c
   SET sort_order = o.rn
  FROM ordered o
 WHERE c.id = o.id AND c.sort_order IS DISTINCT FROM o.rn;

-- ------------------------------------------------------------
-- D) Kategoriler silinmez; yalnız izinli kolonlar güncellenir
-- ------------------------------------------------------------
DROP POLICY IF EXISTS "Categories delete policy" ON public.categories;
REVOKE DELETE ON public.categories FROM authenticated, anon;
REVOKE UPDATE ON public.categories FROM authenticated, anon;
GRANT UPDATE (name, color_hex, icon_name, is_archived, sort_order) ON public.categories TO authenticated;

DO $$
BEGIN
    INSERT INTO supabase_migrations.schema_migrations (version, name)
    VALUES ('20261003181000', 'categories_order_and_privileges')
    ON CONFLICT (version) DO NOTHING;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişine yazılamadı: %', SQLERRM;
END $$;

COMMIT;
