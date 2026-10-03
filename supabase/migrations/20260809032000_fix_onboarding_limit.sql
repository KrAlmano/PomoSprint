-- Update setup_onboarding_categories to not throw an exception on limit hit,
-- but rather just stop inserting. This prevents onboarding from failing 
-- for existing test users who already have categories.

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

    -- Get current active count
    SELECT count(*) INTO v_active_count 
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
                v_active_count
            );
            v_active_count := v_active_count + 1;
        END IF;
    END LOOP;

END;
$function$;
