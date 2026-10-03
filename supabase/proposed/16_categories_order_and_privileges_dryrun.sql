-- ============================================================================
-- KURU ÇALIŞTIRMA: 16_categories_order_and_privileges
-- Canlıda hiçbir şeyi kalıcı DEĞİŞTİRMEZ. Supabase Dashboard > SQL Editor'e
-- yapıştırıp çalıştırın. Önce sentetik bir kullanıcıya çakışan sort_order'lı
-- kategoriler yazılır, sonra değişiklik uygulanır ve senaryolar çalışır; en
-- sonda bilinçli bir hata (DRYRUN_RESULT) fırlatılır ve her şey geri alınır.
-- Hata mesajındaki her satırın sonu 'true' olmalı.
-- ============================================================================
BEGIN;

-- Değişiklikten ÖNCE: sentetik kullanıcı (u0) ve çakışan sıralar (C bölümü testi).
CREATE TEMP TABLE dry13 ON COMMIT DROP AS SELECT gen_random_uuid() AS u0;
INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
SELECT u0, 'dryrun13a-' || u0 || '@example.invalid', '{"name":"Dry Sira"}', 'authenticated', 'authenticated' FROM dry13;
INSERT INTO public.categories (user_id, name, color_hex, icon_name, sort_order, created_at)
SELECT u0, v.name, '#EF4444', 'book', v.ord, now() - v.age
FROM dry13, (VALUES ('S-A', 0, interval '4 days'), ('S-B', 2, interval '3 days'),
                    ('S-C', 2, interval '2 days'), ('S-D', 5, interval '1 day')) AS v(name, ord, age);

-- ---------------------------------------------------------------------------
-- 16_categories_order_and_privileges (BEGIN/COMMIT ve geçmiş kaydı hariç)
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
    SELECT is_premium INTO v_is_premium FROM public.profiles WHERE id = v_uid;
    IF v_is_premium IS NULL THEN
        v_is_premium := false;
    END IF;
    IF v_is_premium THEN
        v_limit := 15;
    ELSE
        v_limit := 8;
    END IF;
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
    IF EXISTS (
        SELECT 1 FROM public.categories
        WHERE user_id = v_uid AND name = p_name AND is_archived = false
    ) THEN
        RAISE EXCEPTION 'Bu isimde aktif bir kategori zaten var.';
    END IF;
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
    SELECT is_premium INTO v_is_premium FROM public.profiles WHERE id = v_uid;
    IF v_is_premium IS NULL THEN
        v_is_premium := false;
    END IF;
    IF v_is_premium THEN
        v_limit := 15;
    ELSE
        v_limit := 8;
    END IF;
    SELECT count(*), coalesce(max(sort_order), -1) + 1 INTO v_active_count, v_next_order
    FROM public.categories
    WHERE user_id = v_uid AND is_archived = false;
    FOR v_cat IN SELECT * FROM jsonb_array_elements(p_categories)
    LOOP
        IF v_active_count >= v_limit THEN
            EXIT;
        END IF;
        IF NOT EXISTS (
            SELECT 1 FROM public.categories
            WHERE user_id = v_uid AND name = v_cat->>'name' AND is_archived = false
        ) THEN
            INSERT INTO public.categories (user_id, name, color_hex, icon_name, sort_order)
            VALUES (v_uid, v_cat->>'name', v_cat->>'color_hex', v_cat->>'icon_name', v_next_order);
            v_active_count := v_active_count + 1;
            v_next_order := v_next_order + 1;
        END IF;
    END LOOP;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_category(text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_category(text, text, text) TO authenticated;
REVOKE ALL ON FUNCTION public.setup_onboarding_categories(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.setup_onboarding_categories(jsonb) TO authenticated;

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

WITH ordered AS (
    SELECT id, row_number() OVER (PARTITION BY user_id ORDER BY sort_order, created_at, id) - 1 AS rn
    FROM public.categories
    WHERE is_archived = false
)
UPDATE public.categories c
   SET sort_order = o.rn
  FROM ordered o
 WHERE c.id = o.id AND c.sort_order IS DISTINCT FROM o.rn;

DROP POLICY IF EXISTS "Categories delete policy" ON public.categories;
REVOKE DELETE ON public.categories FROM authenticated, anon;
REVOKE UPDATE ON public.categories FROM authenticated, anon;
GRANT UPDATE (name, color_hex, icon_name, is_archived, sort_order) ON public.categories TO authenticated;

-- ---------------------------------------------------------------------------
-- Senaryolar
-- ---------------------------------------------------------------------------
DO $dry$
DECLARE
  v_u0 uuid := (SELECT dry13.u0 FROM dry13);
  u1 uuid := gen_random_uuid();
  a uuid; b uuid; c uuid; d uuid; e uuid;
  v_txt text; v_int int; v_bool boolean;
  res text[] := '{}';
BEGIN
  SELECT string_agg(name || '=' || sort_order, ',' ORDER BY sort_order) INTO v_txt
    FROM public.categories WHERE user_id = v_u0;
  res := res || ('T1 çakışan sıra görünen sırayla 0..n-1 (' || v_txt || '): '
                 || (v_txt = 'S-A=0,S-B=1,S-C=2,S-D=3')::text);

  INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
  VALUES (u1, 'dryrun13b-' || u1 || '@example.invalid', '{"name":"Dry Kat"}', 'authenticated', 'authenticated');

  PERFORM set_config('request.jwt.claims', json_build_object('sub', u1, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';

  a := public.create_category('Dry A', '#EF4444', 'book');
  b := public.create_category('Dry B', '#3B82F6', 'book');
  c := public.create_category('Dry C', '#10B981', 'book');
  d := public.create_category('Dry D', '#F59E0B', 'book');
  UPDATE public.categories SET is_archived = true WHERE id = b;          -- istemcinin arşivlemesi
  e := public.create_category('Dry E', '#8B5CF6', 'book');
  SELECT sort_order INTO v_int FROM public.categories WHERE id = e;
  res := res || ('T2 B arşivlendikten sonra yeni kategori sona (4): ' || (v_int = 4)::text);

  UPDATE public.categories SET is_archived = false WHERE id = b;         -- istemcinin arşivden çıkarması
  SELECT sort_order INTO v_int FROM public.categories WHERE id = b;
  res := res || ('T3 arşivden çıkan B sona (5): ' || (v_int = 5)::text);

  SELECT count(DISTINCT sort_order) = count(*) INTO v_bool FROM public.categories WHERE user_id = u1 AND NOT is_archived;
  res := res || ('T4 aktiflerde sort_order tekil: ' || v_bool::text);

  PERFORM public.setup_onboarding_categories('[{"name":"Dry F","color_hex":"#EC4899","icon_name":"book"}]'::jsonb);
  SELECT sort_order INTO v_int FROM public.categories WHERE user_id = u1 AND name = 'Dry F';
  res := res || ('T5 tohumlama da sona ekler (6): ' || (v_int = 6)::text);

  UPDATE public.categories SET name = 'Dry A2', color_hex = '#000000', icon_name = 'science', sort_order = 9 WHERE id = a;
  SELECT name INTO v_txt FROM public.categories WHERE id = a;
  res := res || ('T6 ad/renk/ikon/sıra güncellenir: ' || (v_txt = 'Dry A2')::text);

  BEGIN
    DELETE FROM public.categories WHERE id = c;
    GET DIAGNOSTICS v_int = ROW_COUNT;
    res := res || ('T7 kategori silinemez: ' || (v_int = 0)::text);
  EXCEPTION WHEN insufficient_privilege THEN
    res := res || 'T7 kategori silinemez: true'::text;
  END;

  BEGIN
    UPDATE public.categories SET user_id = v_u0 WHERE id = d;
    res := res || 'T8 user_id değiştirilemez: false'::text;
  EXCEPTION WHEN insufficient_privilege THEN
    res := res || 'T8 user_id değiştirilemez: true'::text;
  END;

  BEGIN
    UPDATE public.categories SET created_at = now() - interval '1 year' WHERE id = d;
    res := res || 'T9 created_at değiştirilemez: false'::text;
  EXCEPTION WHEN insufficient_privilege THEN
    res := res || 'T9 created_at değiştirilemez: true'::text;
  END;

  EXECUTE 'RESET ROLE';

  SELECT has_table_privilege('authenticated', 'public.categories', 'DELETE') INTO v_bool;
  res := res || ('T10 authenticated DELETE yetkisi yok: ' || (NOT v_bool)::text);
  SELECT count(*) INTO v_int FROM pg_policies WHERE schemaname = 'public' AND tablename = 'categories' AND cmd = 'DELETE';
  res := res || ('T11 DELETE politikası yok: ' || (v_int = 0)::text);
  SELECT has_column_privilege('authenticated', 'public.categories', 'is_archived', 'UPDATE')
     AND has_column_privilege('authenticated', 'public.categories', 'sort_order', 'UPDATE')
     AND NOT has_column_privilege('authenticated', 'public.categories', 'id', 'UPDATE') INTO v_bool;
  res := res || ('T12 kolon bazlı UPDATE: ' || v_bool::text);
  SELECT count(*) INTO v_int FROM pg_trigger
   WHERE tgrelid = 'public.categories'::regclass AND tgname = 'enforce_category_limit_on_unarchive';
  res := res || ('T13 limit trigger''ı yerinde: ' || (v_int = 1)::text);

  RAISE EXCEPTION 'DRYRUN_RESULT >> %', array_to_string(res, ' || ');
END
$dry$;
