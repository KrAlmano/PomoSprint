-- ============================================================================
-- GERİ ALMA: supabase/proposed/23_kategori_butunluk.sql
-- ============================================================================
-- Zincir uygulanmış hâle döner: setup_onboarding_categories (16, void dönüş;
-- DROP + CREATE), create_category (16) ve enforce_category_limit (canlı)
-- pg_get_functiondef çıktısıyla BİREBİR; enforce_category_rules trigger'ı,
-- fonksiyonu ve category_name_key silinir.
-- VERİ: 23'ün onboarding sırasında arşivlediği kategoriler arşivde kalır
-- (kullanıcı Kategorilerim'den geri açabilir); oluşturulan kategoriler kalır.
-- ============================================================================

\echo 'supabase/proposed/23_down: doğrudan çalıştırılmaz; \echo/\quit satırlarını silip SQL Editor''de çalıştırın.'
\quit

BEGIN;

DO $pre$
BEGIN
    IF to_regprocedure('public.enforce_category_rules()') IS NULL THEN
        RAISE EXCEPTION 'proposed/23_down: 23 uygulanmamış görünüyor; yapılacak bir şey yok.';
    END IF;
END
$pre$;

DROP TRIGGER enforce_category_rules ON public.categories;
DROP FUNCTION public.enforce_category_rules();
DROP FUNCTION public.setup_onboarding_categories(jsonb);

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

    SELECT is_premium INTO v_is_premium FROM public.profiles WHERE id = NEW.user_id;
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

DROP FUNCTION public.category_name_key(text);

REVOKE ALL ON FUNCTION public.setup_onboarding_categories(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.setup_onboarding_categories(jsonb) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.create_category(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_category(text, text, text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.enforce_category_limit() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.enforce_category_limit() TO service_role;

DO $$
BEGIN
    DELETE FROM supabase_migrations.schema_migrations WHERE version = '20261005123000';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişinden silinemedi: %', SQLERRM;
END $$;

COMMIT;
