-- 1. ADD COLUMNS TO PROFILES
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS user_segment text CHECK (user_segment IN ('lgs', 'yks', 'university', 'work'));
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS daily_goal_minutes integer;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS birth_year integer;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS onboarding_completed_at timestamp with time zone;

-- 2. GRANT SELECT and UPDATE
GRANT SELECT (user_segment, daily_goal_minutes, birth_year, onboarding_completed_at) ON public.profiles TO authenticated;
GRANT UPDATE (user_segment, daily_goal_minutes, birth_year, onboarding_completed_at) ON public.profiles TO authenticated;

-- 3. MIGRATE EXISTING USERS
-- "MEVCUT KULLANICILAR: categories tablosunda kaydı olanlara gösterme, onboarding_completed_at'lerini now() yap"
UPDATE public.profiles 
SET onboarding_completed_at = now() 
WHERE id IN (
  SELECT DISTINCT user_id FROM public.categories
) AND onboarding_completed_at IS NULL;

-- 4. CREATE RPC: create_category
CREATE OR REPLACE FUNCTION public.create_category(p_name text, p_color_hex text, p_icon_name text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_is_premium boolean;
    v_active_count integer;
    v_limit integer;
    v_new_id uuid;
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
    SELECT count(*) INTO v_active_count 
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

    -- Insert
    INSERT INTO public.categories (user_id, name, color_hex, icon_name, sort_order)
    VALUES (v_uid, p_name, p_color_hex, p_icon_name, v_active_count)
    RETURNING id INTO v_new_id;

    RETURN v_new_id;
END;
$function$;

-- 5. CREATE RPC: setup_onboarding_categories
-- Takes a JSON array of objects: [{name, color_hex, icon_name}]
CREATE OR REPLACE FUNCTION public.setup_onboarding_categories(p_categories jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_is_premium boolean;
    v_active_count integer;
    v_limit integer;
    v_cat jsonb;
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

    -- Check current active count (should be 0 for new onboarding, but just in case)
    -- Get current active count for sorting
    SELECT count(*) INTO v_active_count 
    FROM public.categories 
    WHERE user_id = v_uid AND is_archived = false;

    -- Insert loop
    FOR v_cat IN SELECT * FROM jsonb_array_elements(p_categories)
    LOOP
        -- Ignore duplicates silently during onboarding setup
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
                v_active_count
            );
            v_active_count := v_active_count + 1;
        END IF;
    END LOOP;

    -- Validate limit AFTER insertions
    IF v_active_count > v_limit THEN
        IF v_is_premium THEN
            RAISE EXCEPTION 'Premium planda en fazla 15 kategori seçebilirsin.';
        ELSE
            RAISE EXCEPTION 'Ücretsiz planda en fazla 8 kategori seçebilirsin.';
        END IF;
    END IF;

END;
$function$;
