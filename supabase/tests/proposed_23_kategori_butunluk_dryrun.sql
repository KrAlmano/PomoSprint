-- ============================================================================
-- KURU ÇALIŞTIRMA: supabase/proposed/23_kategori_butunluk.sql
-- (canlıda hiçbir şeyi kalıcı DEĞİŞTİRMEZ)
-- Supabase Dashboard > SQL Editor'e yapıştırıp Run'a basın. Önce öneriden
-- ÖNCEKİ tanımlarla sentetik bir "eski" kullanıcı (büyük/küçük harf farklı iki
-- aktif kategori ve bozuk renkli bir kategoriyle) oluşturulur, sonra öneri
-- uygulanır ve senaryolar sentetik kullanıcılarla (@example.invalid) çalışır.
-- En sonda bilinçli bir hata (DRYRUN_RESULT) fırlatılır ve her şey geri
-- alınır. Her maddenin sonu 'true' olmalı.
--
-- Notlar
--  * Öneri categories ve profiles üzerinde trigger / fonksiyon değiştirir;
--    işlem süresince (birkaç saniye) bu tablolar kilitli kalabilir.
--  * Eşzamanlı iki kurulum tek transaction'da sınanamaz: T11 kilitlerin
--    gövdelerde olduğunu denetler; iki bağlantılı gerçek senaryo yerelde
--    supabase/tests/proposed_20_25_race_local.sh.
--  * Gövde 23_kategori_butunluk.sql ile birebir aynıdır (BEGIN/COMMIT hariç);
--    tool/local_supabase/proposed_chain_check.sh bunu denetler.
-- ============================================================================
BEGIN;

-- ---------------------------------------------------------------------------
-- Öneriden ÖNCE (zincirdeki tanımlarla): eski kullanıcı
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE dry23 ON COMMIT DROP AS SELECT gen_random_uuid() AS u_legacy;
INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
SELECT u_legacy, 'dryrun23-l-' || u_legacy || '@example.invalid', '{"name":"Dry Eski"}', 'authenticated', 'authenticated'
FROM dry23;
UPDATE public.profiles SET onboarding_completed_at = now() - interval '30 days' WHERE id = (SELECT u_legacy FROM dry23);
INSERT INTO public.categories (user_id, name, color_hex, icon_name, sort_order)
SELECT u_legacy, x.name, x.color, 'book', x.ord
FROM dry23, (VALUES ('Fizik', '#111111', 0), ('fizik', '#222222', 1), ('Eski Renk', 'kirmizi', 2)) AS x(name, color, ord);

-- >>> ÖNERİ GÖVDESİ (supabase/proposed/23_kategori_butunluk.sql, BEGIN/COMMIT hariç, birebir) >>>

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

-- <<< ÖNERİ GÖVDESİ SONU <<<

-- ---------------------------------------------------------------------------
-- Senaryolar
-- ---------------------------------------------------------------------------
CREATE FUNCTION pg_temp.d23_user(p_tag text) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v uuid := gen_random_uuid();
BEGIN
  INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
  VALUES (v, 'dryrun23-' || p_tag || '-' || v || '@example.invalid', '{"name":"Dry Kategori"}', 'authenticated', 'authenticated');
  RETURN v;
END $$;

CREATE FUNCTION pg_temp.d23_active(p uuid) RETURNS text LANGUAGE sql AS
$$ SELECT coalesce(string_agg(name, ',' ORDER BY sort_order, name), '') FROM public.categories WHERE user_id = p AND NOT is_archived $$;

DO $dry$
DECLARE
  res text[] := '{}';
  d record;
  v_res jsonb;
  v_res2 jsonb;
  v_txt text;
  v_int integer;
  v_bool boolean;
  u uuid;
  c uuid;
  v_yks constant jsonb := '[{"name":"Matematik","color_hex":"#2196F3","icon_name":"calculate"},{"name":"Fizik","color_hex":"#F44336","icon_name":"science"},
    {"name":"Kimya","color_hex":"#4CAF50","icon_name":"biotech"},{"name":"Biyoloji","color_hex":"#8BC34A","icon_name":"biotech"},
    {"name":"Türkçe","color_hex":"#FF9800","icon_name":"menu_book"},{"name":"Tarih","color_hex":"#795548","icon_name":"book"},
    {"name":"Coğrafya","color_hex":"#009688","icon_name":"language"},{"name":"Felsefe","color_hex":"#9C27B0","icon_name":"book"}]';
  v_work constant jsonb := '[{"name":"Derin Çalışma","color_hex":"#3F51B5","icon_name":"book"},{"name":"Okuma","color_hex":"#FF5722","icon_name":"menu_book"},
    {"name":"Öğrenme","color_hex":"#00BCD4","icon_name":"language"},{"name":"Proje","color_hex":"#607D8B","icon_name":"calculate"}]';
BEGIN
  SELECT * INTO d FROM dry23;

  res := res || ('T01 trigger ve anahtar: '
                 || (EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.categories'::regclass AND tgname = 'enforce_category_rules')
                     AND public.category_name_key(' MATEMATİK ') = 'matematik'
                     AND public.category_name_key('IŞIK') = public.category_name_key('ışık'))::text);

  -- ======================= t2-03: yeniden denenen onboarding =======================
  u := pg_temp.d23_user('yks');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_res := public.setup_onboarding_categories(v_yks);
  v_res2 := public.setup_onboarding_categories(v_work);
  EXECUTE 'RESET ROLE';
  v_txt := pg_temp.d23_active(u);
  res := res || ('T02 YKS 8 → work 4 (onboarding bitmemiş): aktif yalnız yeni seçim, eskiler arşivde (' || v_txt || ' / ' || v_res2::text || '): '
                 || coalesce(v_txt = 'Derin Çalışma,Okuma,Öğrenme,Proje' AND (v_res->>'created')::int = 8
                             AND (v_res2->>'created')::int = 4 AND (v_res2->>'archived')::int = 8
                             AND (SELECT count(*) FROM public.categories WHERE user_id = u AND is_archived) = 8, false)::text);

  -- Seansı olan kategori arşivlenmez; geri dönülen seçim arşivden açılır
  SELECT id INTO c FROM public.categories WHERE user_id = u AND name = 'Okuma';
  INSERT INTO public.study_sessions (user_id, category, category_id, duration_minutes, base_points, bonus_points,
                                     was_paused, is_verified, client_uuid, started_at, completed_at)
  VALUES (u, 'Okuma', c, 25, 5, 0, false, 1500, gen_random_uuid(), now() - interval '1 hour', now() - interval '35 minutes');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_res := public.setup_onboarding_categories(v_yks);
  EXECUTE 'RESET ROLE';
  v_txt := pg_temp.d23_active(u);
  res := res || ('T03 YKS''ye geri dönüş: 7 tanesi arşivden açılır, seanslı Okuma kalır, limit dolunca sayılır (' || v_res::text || '): '
                 || coalesce((v_res->>'restored')::int = 7 AND (v_res->>'created')::int = 0 AND (v_res->>'skipped_limit')::int = 1
                             AND (v_res->>'archived')::int = 3 AND v_txt LIKE 'Okuma,%'
                             AND (SELECT count(*) FROM public.categories WHERE user_id = u AND NOT is_archived) = 8
                             AND (SELECT count(*) FROM public.categories WHERE user_id = u) = 12, false)::text);

  -- TR → EN dil değişimi
  u := pg_temp.d23_user('dil');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.setup_onboarding_categories('[{"name":"Matematik","color_hex":"#2196F3","icon_name":"calculate"},{"name":"Fen Bilimleri","color_hex":"#4CAF50","icon_name":"science"},{"name":"Türkçe","color_hex":"#FF9800","icon_name":"menu_book"}]');
  PERFORM public.setup_onboarding_categories('[{"name":"Mathematics","color_hex":"#2196F3","icon_name":"calculate"},{"name":"Science","color_hex":"#4CAF50","icon_name":"science"}]');
  EXECUTE 'RESET ROLE';
  v_txt := pg_temp.d23_active(u);
  res := res || ('T04 TR kurulum sonra EN: çift kategori yok (' || v_txt || '): ' || (v_txt = 'Mathematics,Science')::text);

  -- Onboarding'i bitmiş kullanıcı (ensureServerCategories / kuyruk): arşivleme yok, limit sayılır
  u := pg_temp.d23_user('done');
  UPDATE public.profiles SET onboarding_completed_at = now() WHERE id = u;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_res := public.setup_onboarding_categories(v_work);
  v_res2 := public.setup_onboarding_categories(v_yks);
  EXECUTE 'RESET ROLE';
  res := res || ('T05 onboarding bitmiş: hiçbir şey arşivlenmez, limit 8''de durur ve sayılır (' || v_res2::text || '): '
                 || coalesce((v_res2->>'archived')::int = 0 AND (v_res2->>'created')::int = 4 AND (v_res2->>'skipped_limit')::int = 4
                             AND (SELECT count(*) FROM public.categories WHERE user_id = u AND NOT is_archived) = 8, false)::text);

  -- ======================= t2-06: doğrulama =======================
  u := pg_temp.d23_user('gecersiz');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_res := public.setup_onboarding_categories(jsonb_build_array(
      jsonb_build_object('name', '', 'color_hex', '#111111', 'icon_name', 'book'),
      jsonb_build_object('name', '   ', 'color_hex', '#111111', 'icon_name', 'book'),
      jsonb_build_object('name', repeat('Y', 300), 'color_hex', '#111111', 'icon_name', 'book'),
      jsonb_build_object('name', 'RenkBozuk', 'color_hex', 'kirmizi', 'icon_name', 'book'),
      jsonb_build_object('name', 'IkonBozuk', 'color_hex', '#111111', 'icon_name', '<script>'),
      jsonb_build_object('name', 'Siktir Ders', 'color_hex', '#111111', 'icon_name', 'book'),
      jsonb_build_object('name', '  Gecerli   Ders ', 'color_hex', '#ABCDEF'),
      jsonb_build_object('name', 'Matematik', 'color_hex', '#2196F3', 'icon_name', 'calculate'),
      jsonb_build_object('name', 'matematik', 'color_hex', '#2196F3', 'icon_name', 'calculate'),
      jsonb_build_object('name', 'Matematik ', 'color_hex', '#2196F3', 'icon_name', 'calculate')));
  EXECUTE 'RESET ROLE';
  v_txt := pg_temp.d23_active(u);
  res := res || ('T06 geçersiz öğeler atlanır, çağrı düşmez; ad temizlenir; Matematik/matematik/''Matematik '' tek (' || v_txt || ' / ' || v_res::text || '): '
                 || coalesce(v_txt = 'Gecerli Ders,Matematik' AND (v_res->>'skipped_invalid')::int = 6
                             AND (v_res->>'skipped_existing')::int = 2 AND (v_res->>'created')::int = 2, false)::text);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_txt := '';
  BEGIN PERFORM public.create_category('MATEMATİK', '#111111', 'book');
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLERRM || '|'; END;
  BEGIN PERFORM public.create_category('Renk', 'kirmizi', 'book');
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLSTATE || ' ' || SQLERRM || '|'; END;
  BEGIN PERFORM public.create_category('Ikon', '#111111', '<script>');
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLSTATE || ' ' || SQLERRM || '|'; END;
  c := public.create_category('Kimya', '#4CAF50', NULL);
  EXECUTE 'RESET ROLE';
  res := res || ('T07 create_category: harf farkı çift, bozuk renk ve ikon reddedilir; geçerli eklenir (' || v_txt || '): '
                 || coalesce(v_txt = 'Bu isimde aktif bir kategori zaten var.|23514 category_color_invalid|23514 category_icon_invalid|'
                             AND c IS NOT NULL, false)::text);

  -- Doğrudan tablo yazımı (authenticated'ın INSERT/UPDATE yetkisi var)
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_txt := '';
  BEGIN INSERT INTO public.categories (user_id, name, color_hex, icon_name) VALUES (u, 'KİMYA', '#111111', 'book');
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLSTATE || '|'; END;
  BEGIN UPDATE public.categories SET name = 'kimya ' WHERE user_id = u AND name = 'Gecerli Ders';
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLSTATE || '|'; END;
  BEGIN UPDATE public.categories SET color_hex = 'mavi' WHERE user_id = u AND name = 'Kimya';
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLSTATE || '|'; END;
  UPDATE public.categories SET is_archived = true WHERE user_id = u AND name = 'Kimya';
  INSERT INTO public.categories (user_id, name, color_hex, icon_name) VALUES (u, 'kimya', '#111111', 'book');
  v_bool := false;
  BEGIN UPDATE public.categories SET is_archived = false WHERE user_id = u AND name = 'Kimya';
  EXCEPTION WHEN unique_violation THEN v_bool := true; END;
  EXECUTE 'RESET ROLE';
  res := res || ('T08 doğrudan INSERT/UPDATE: harf farkı çift 23505, bozuk renk 23514; arşivdeki aynısı yeni ad alabilir, geri açılamaz (' || v_txt || '): '
                 || coalesce(v_txt = '23505|23505|23514|' AND v_bool, false)::text);

  -- Eski kullanıcı: mevcut çiftler ve bozuk renk dokunulmaz, arşivlenebilir
  PERFORM set_config('request.jwt.claims', json_build_object('sub', d.u_legacy, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  UPDATE public.categories SET sort_order = sort_order + 10 WHERE user_id = d.u_legacy;
  UPDATE public.categories SET is_archived = true WHERE user_id = d.u_legacy AND name = 'Eski Renk';
  v_res := public.setup_onboarding_categories('[{"name":"FİZİK","color_hex":"#111111","icon_name":"book"},{"name":"Yeni","color_hex":"#111111","icon_name":"book"}]');
  EXECUTE 'RESET ROLE';
  v_txt := pg_temp.d23_active(d.u_legacy);
  res := res || ('T09 eski çift adlar ve bozuk renk dokunulmaz; sıralanır/arşivlenir; kurulum düşmez (' || v_txt || '): '
                 || coalesce(v_txt = 'Fizik,fizik,Yeni' AND (v_res->>'skipped_existing')::int = 1
                             AND (SELECT is_archived FROM public.categories WHERE user_id = d.u_legacy AND name = 'Eski Renk'), false)::text);

  -- Limit trigger'ı (doğrudan INSERT) ve hata metinleri aynı
  u := pg_temp.d23_user('limit');
  INSERT INTO public.categories (user_id, name, color_hex, icon_name, sort_order)
  SELECT u, 'L' || g, '#111111', 'book', g FROM generate_series(1, 8) g;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_txt := '';
  BEGIN INSERT INTO public.categories (user_id, name, color_hex, icon_name) VALUES (u, 'L9', '#111111', 'book');
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLERRM || '|'; END;
  BEGIN PERFORM public.create_category('L10', '#111111', 'book');
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLERRM || '|'; END;
  EXECUTE 'RESET ROLE';
  res := res || ('T10 limit metinleri aynı (trigger ve RPC): '
                 || (v_txt = 'Ücretsiz planda en fazla 8 kategori ekleyebilirsin. Premium ile 15''e çıkar.|Ücretsiz planda en fazla 8 kategori ekleyebilirsin. Premium ile 15''e çıkar.|')::text);

  res := res || ('T11 kilitler: limit trigger''ı, create_category ve kurulum sayımdan önce profili kilitler: '
                 || (pg_get_functiondef('public.enforce_category_limit()'::regprocedure) LIKE '%WHERE id = NEW.user_id FOR UPDATE%'
                     AND pg_get_functiondef('public.create_category(text,text,text)'::regprocedure) LIKE '%WHERE id = v_uid FOR UPDATE%'
                     AND pg_get_functiondef('public.setup_onboarding_categories(jsonb)'::regprocedure) LIKE '%FOR UPDATE%'
                     AND pg_get_functiondef('public.enforce_category_rules()'::regprocedure) LIKE '%FOR UPDATE%')::text);

  res := res || ('T12 yetkiler: kurulum ve create_category yalnız authenticated; yardımcılar API rollerine kapalı: '
                 || (has_function_privilege('authenticated', 'public.setup_onboarding_categories(jsonb)', 'EXECUTE')
                     AND NOT has_function_privilege('anon', 'public.setup_onboarding_categories(jsonb)', 'EXECUTE')
                     AND has_function_privilege('authenticated', 'public.create_category(text,text,text)', 'EXECUTE')
                     AND NOT has_function_privilege('anon', 'public.create_category(text,text,text)', 'EXECUTE')
                     AND NOT has_function_privilege('authenticated', 'public.enforce_category_rules()', 'EXECUTE')
                     AND NOT has_function_privilege('authenticated', 'public.category_name_key(text)', 'EXECUTE')
                     AND NOT has_function_privilege('anon', 'public.category_name_key(text)', 'EXECUTE'))::text);
  SELECT count(*) INTO v_int FROM supabase_migrations.schema_migrations WHERE version = '20261005123000';
  res := res || ('T13 migration geçmişine yazıldı: ' || (v_int = 1)::text);

  RAISE EXCEPTION 'DRYRUN_RESULT >> %', array_to_string(res, ' || ');
END
$dry$;

ROLLBACK;
