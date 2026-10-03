-- ============================================================
-- ÖNERİ 09: Kategori adı kuralları ve tek kaynaklı limit  ÖNCELİK: P3
-- ============================================================
-- Bulgular: AUTH-19 (ad uzunluğu yok, benzersizlik büyük/küçük harfe
-- duyarlı, yeniden adlandırma çakışması ham hata), BACKEND-28 / AUTH-18
-- (8/15 limiti create_category ve setup_onboarding_categories'te ayrı
-- kopya), AUTH-06 / K6 (makine-okunur hata kodu).
--
-- 20261003120000_audit_fixes zaten ekledi: category_limit(uid),
-- get_my_category_limit(), reorder_categories(uuid[]).
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- ADIMLAR
--  1. Çakışan ve taşan adları görün:
--       select user_id, lower(btrim(name)) as ad, array_agg(id order by created_at) as ids
--       from public.categories where not is_archived
--       group by 1, 2 having count(*) > 1;
--       select id, name from public.categories where char_length(btrim(name)) not between 1 and 40;
--  2. A bölümünü (veri temizliği + kısıt + index) staging'de çalıştırın.
--     İstemci 23505'i 'categoryNameExists' olarak gösteriyor olmalı (AUTH).
--  3. B bölümündeki değişiklikleri create_category ve
--     setup_onboarding_categories'in CANLI gövdelerine uygulayın:
--       select pg_get_functiondef('public.create_category(text,text,text)'::regprocedure);
--       select pg_get_functiondef('public.setup_onboarding_categories(jsonb)'::regprocedure);
--  4. C (update_category) yeni ve ek bir fonksiyondur.
-- ============================================================

\echo 'supabase/proposed/09: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

-- ------------------------------------------------------------
-- A) Veri temizliği, uzunluk kısıtı, büyük/küçük harf duyarsız benzersizlik
-- ------------------------------------------------------------
-- 1. Aynı kullanıcıda aynı (kırpılmış, küçük harf) ada sahip AKTİF
--    kayıtlardan en eskisi kalır, diğerleri arşivlenir (seanslar
--    category_id ile bağlı kalır). Kırpmadan ÖNCE yapılır; aksi halde
--    kırpma mevcut benzersiz index'e çarpabilir.
UPDATE public.categories c
SET is_archived = true
FROM (
    SELECT id,
           row_number() OVER (
               PARTITION BY user_id, lower(left(btrim(name), 40))
               ORDER BY created_at, id
           ) AS rn
    FROM public.categories
    WHERE NOT is_archived
) d
WHERE c.id = d.id AND d.rn > 1;

-- 2. Baş/son boşlukları kırp ve 40 karaktere indir.
UPDATE public.categories
SET name = left(btrim(name), 40)
WHERE name <> btrim(name) OR char_length(btrim(name)) > 40;

-- 3. Kısıt (önce NOT VALID: kilit süresi kısa kalsın).
ALTER TABLE public.categories DROP CONSTRAINT IF EXISTS categories_name_length;
ALTER TABLE public.categories
    ADD CONSTRAINT categories_name_length CHECK (char_length(btrim(name)) BETWEEN 1 AND 40) NOT VALID;
ALTER TABLE public.categories VALIDATE CONSTRAINT categories_name_length;

-- 4. Benzersizlik büyük/küçük harf ve boşluk duyarsız.
CREATE UNIQUE INDEX IF NOT EXISTS categories_user_id_lower_name_key
    ON public.categories (user_id, lower(btrim(name)))
    WHERE NOT is_archived;
DROP INDEX IF EXISTS public.categories_user_id_name_key;

COMMIT;

-- ------------------------------------------------------------
-- B) create_category / setup_onboarding_categories (CANLI gövdelere)
-- ------------------------------------------------------------
-- 1. Limit tek kaynaktan:
--      ESKİ: IF v_is_premium THEN v_limit := 15; ELSE v_limit := 8; END IF;
--      YENİ: v_limit := public.category_limit(v_uid);
-- 2. Ad normalize ve doğrulama (gövdenin başında):
--      p_name := btrim(p_name);
--      IF p_name IS NULL OR char_length(p_name) NOT BETWEEN 1 AND 40 THEN
--          RAISE EXCEPTION 'Kategori adı 1-40 karakter olmalı.' USING HINT = 'category_name_invalid';
--      END IF;
-- 3. Çakışma kontrolü büyük/küçük harf duyarsız:
--      ESKİ: WHERE user_id = v_uid AND name = p_name AND is_archived = false
--      YENİ: WHERE user_id = v_uid AND lower(btrim(name)) = lower(p_name) AND is_archived = false
--    (setup_onboarding_categories'te v_cat->>'name' için aynısı; aynı
--     JSON içinde tekrarlanan adlar da böylece atlanır.)
-- 4. enforce_category_limit (CANLI gövdeye; BACKEND-28 eşzamanlılık):
--    sayımdan önce profil satırını kilitleyin, limiti tek kaynaktan alın:
--      SELECT COALESCE(is_premium, false) INTO v_is_premium
--      FROM public.profiles WHERE id = NEW.user_id
--      FOR UPDATE;
--      v_limit := public.category_limit(NEW.user_id);
--    ve RAISE'e USING HINT = 'category_limit:' || v_limit ekleyin.
--    (20261003150000_live_audit_fixes arşivden çıkarmayı da bu trigger'a
--    bağladı; gövde değişikliği iki trigger'ı da kapsar.)
-- 5. Hata kodları HINT ile (mesaj metinleri aynı kalabilir):
--      limit      -> USING HINT = 'category_limit:' || v_limit
--      aynı ad    -> USING HINT = 'category_name_exists'
--      oturum yok -> USING ERRCODE = '28000'

-- ------------------------------------------------------------
-- C) update_category: yeniden adlandırma aynı kurallarla (AUTH-19)
-- ------------------------------------------------------------
-- İstemci şu an doğrudan UPDATE yapıyor; çakışmada ham 'duplicate key'
-- metni görünüyor. Bu RPC aynı kontrolleri yapıp HINT'li hata döndürür.
BEGIN;

CREATE OR REPLACE FUNCTION public.update_category(
    p_id uuid,
    p_name text,
    p_color_hex text,
    p_icon_name text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_name text := btrim(p_name);
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
    END IF;
    IF v_name IS NULL OR char_length(v_name) NOT BETWEEN 1 AND 40 THEN
        RAISE EXCEPTION 'Kategori adı 1-40 karakter olmalı.' USING HINT = 'category_name_invalid';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.categories
        WHERE user_id = v_uid
          AND id <> p_id
          AND NOT is_archived
          AND lower(btrim(name)) = lower(v_name)
    ) THEN
        RAISE EXCEPTION 'Bu isimde aktif bir kategori zaten var.' USING HINT = 'category_name_exists';
    END IF;

    UPDATE public.categories
    SET name = v_name,
        color_hex = COALESCE(p_color_hex, color_hex),
        icon_name = COALESCE(p_icon_name, icon_name)
    WHERE id = p_id AND user_id = v_uid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Kategori bulunamadı.' USING HINT = 'category_not_found';
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.update_category(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_category(uuid, text, text, text) TO authenticated;

COMMIT;
