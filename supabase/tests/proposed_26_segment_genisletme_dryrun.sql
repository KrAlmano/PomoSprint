-- ============================================================================
-- KURU ÇALIŞTIRMA: supabase/proposed/26_segment_genisletme.sql
-- (canlıda hiçbir şeyi kalıcı DEĞİŞTİRMEZ)
-- Supabase Dashboard > SQL Editor'e yapıştırıp Run'a basın. Önce öneriden
-- ÖNCE (canlı kısıtla) üç sentetik profil oluşturulur ve 'kpss'nin bugün
-- 23514 ile reddedildiği kaydedilir; sonra öneri uygulanır ve senaryolar
-- sentetik kullanıcılarla (@example.invalid) istemcinin onboarding PATCH'i
-- gibi (authenticated rolü, kendi satırı) çalışır. En sonda bilinçli bir hata
-- (DRYRUN_RESULT) fırlatılır ve her şey geri alınır. Her maddenin sonu
-- 'true' olmalı.
--
-- Notlar
--  * Bağımsızdır: canlı hâlde de, zincir + 20–25 uygulanmış hâlde de çalışır.
--  * Gövde 26_segment_genisletme.sql ile birebir aynıdır (BEGIN/COMMIT
--    hariç); tool/local_supabase/proposed_chain_check.sh bunu denetler.
-- ============================================================================
BEGIN;

-- ---------------------------------------------------------------------------
-- Öneriden ÖNCE (canlı kısıtla): sentetik profiller, 'kpss' reddi
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE dry26 ON COMMIT DROP AS
SELECT gen_random_uuid() AS u_kpss, gen_random_uuid() AS u_lang, gen_random_uuid() AS u_old,
       ''::text AS before_kpss, 0::bigint AS profiles_before;
INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
SELECT x.id, 'dryrun26-' || x.tag || '-' || x.id || '@example.invalid', '{"name":"Dry Segment"}', 'authenticated', 'authenticated'
FROM dry26, LATERAL (VALUES (u_kpss, 'k'), (u_lang, 'l'), (u_old, 'o')) AS x(id, tag);

DO $before$
DECLARE
  d record;
  v_txt text := '';
BEGIN
  SELECT * INTO d FROM dry26;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', d.u_kpss, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    UPDATE public.profiles SET user_segment = 'kpss' WHERE id = d.u_kpss;
    v_txt := 'kabul edildi';
  EXCEPTION WHEN OTHERS THEN v_txt := SQLSTATE || ' ' || SQLERRM;
  END;
  EXECUTE 'RESET ROLE';
  UPDATE dry26 SET before_kpss = v_txt, profiles_before = (SELECT count(*) FROM public.profiles);
END
$before$;

-- >>> ÖNERİ GÖVDESİ (supabase/proposed/26_segment_genisletme.sql, BEGIN/COMMIT hariç, birebir) >>>

-- ---------------------------------------------------------------------------
-- 0) Ön koşul: kısıt canlıdaki tanımıyla duruyor (26 uygulanmamış)
-- ---------------------------------------------------------------------------
DO $pre$
DECLARE
    v_def text;
BEGIN
    SELECT pg_get_constraintdef(oid) INTO v_def
      FROM pg_constraint
     WHERE conrelid = 'public.profiles'::regclass AND conname = 'profiles_user_segment_check';
    IF v_def IS DISTINCT FROM
       'CHECK ((user_segment = ANY (ARRAY[''lgs''::text, ''yks''::text, ''university''::text, ''work''::text])))' THEN
        RAISE EXCEPTION 'proposed/26 ön koşulu: profiles_user_segment_check beklenen (canlı) tanımda değil: %', coalesce(v_def, '(yok)');
    END IF;
END
$pre$;

-- ---------------------------------------------------------------------------
-- A) KPSS ve dil sınavı hedefleri (t2-04)
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles DROP CONSTRAINT profiles_user_segment_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_user_segment_check
    CHECK (user_segment = ANY (ARRAY['lgs'::text, 'yks'::text, 'kpss'::text, 'language'::text, 'university'::text, 'work'::text]));

DO $$
BEGIN
    INSERT INTO supabase_migrations.schema_migrations (version, name)
    VALUES ('20261005126000', 'segment_genisletme')
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
  d record;
  v_txt text;
  v_int integer;
  v_seg text;
  v_def text;
  v_valid boolean;
BEGIN
  SELECT * INTO d FROM dry26;

  res := res || ('T01 öneriden önce ''kpss'' CHECK ile reddediliyordu (' || d.before_kpss || '): '
                 || (d.before_kpss LIKE '23514 %profiles_user_segment_check%')::text);

  SELECT pg_get_constraintdef(oid), convalidated INTO v_def, v_valid
    FROM pg_constraint
   WHERE conrelid = 'public.profiles'::regclass AND conname = 'profiles_user_segment_check';
  res := res || ('T02 kısıt yeni tanımda ve doğrulanmış: '
                 || coalesce(v_def = 'CHECK ((user_segment = ANY (ARRAY[''lgs''::text, ''yks''::text, ''kpss''::text, ''language''::text, ''university''::text, ''work''::text])))'
                             AND v_valid, false)::text);

  -- İstemcinin onboarding PATCH'i (SupabaseService.onboardingProfileUpdate alanları)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', d.u_kpss, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  UPDATE public.profiles SET birth_year = 1995, user_segment = 'kpss', daily_goal_minutes = 120,
                             show_in_social_feed = false, onboarding_completed_at = now() WHERE id = d.u_kpss;
  EXECUTE 'RESET ROLE';
  res := res || ('T03 onboarding PATCH''i ''kpss'' ile tamamlanır: '
                 || coalesce((SELECT user_segment = 'kpss' AND onboarding_completed_at IS NOT NULL
                                FROM public.profiles WHERE id = d.u_kpss), false)::text);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', d.u_lang, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  UPDATE public.profiles SET birth_year = 2001, user_segment = 'language', daily_goal_minutes = 60,
                             show_in_social_feed = true, onboarding_completed_at = now() WHERE id = d.u_lang;
  EXECUTE 'RESET ROLE';
  res := res || ('T04 onboarding PATCH''i ''language'' ile tamamlanır: '
                 || coalesce((SELECT user_segment = 'language' AND onboarding_completed_at IS NOT NULL
                                FROM public.profiles WHERE id = d.u_lang), false)::text);

  -- Eski dört değer ve NULL aynen geçerli
  PERFORM set_config('request.jwt.claims', json_build_object('sub', d.u_old, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_int := 0;
  FOREACH v_seg IN ARRAY ARRAY['lgs', 'yks', 'university', 'work'] LOOP
    UPDATE public.profiles SET user_segment = v_seg WHERE id = d.u_old;
    v_int := v_int + 1;
  END LOOP;
  UPDATE public.profiles SET user_segment = NULL WHERE id = d.u_old;
  -- Bilinmeyen değer hâlâ reddedilir
  v_txt := '';
  FOREACH v_seg IN ARRAY ARRAY['other', 'abc', 'KPSS', ''] LOOP
    BEGIN
      UPDATE public.profiles SET user_segment = v_seg WHERE id = d.u_old;
      v_txt := v_txt || 'kabul|';
    EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLSTATE || '|';
    END;
  END LOOP;
  EXECUTE 'RESET ROLE';
  res := res || ('T05 eski dört değer ve NULL geçerli: '
                 || (v_int = 4 AND (SELECT user_segment IS NULL FROM public.profiles WHERE id = d.u_old))::text);
  res := res || ('T06 bilinmeyen değer (other, abc, KPSS, boş) hâlâ 23514 (' || v_txt || '): '
                 || (v_txt = '23514|23514|23514|23514|')::text);

  SELECT count(*) INTO v_int FROM public.profiles
   WHERE user_segment IS NOT NULL AND user_segment <> ALL (ARRAY['lgs', 'yks', 'kpss', 'language', 'university', 'work']);
  res := res || ('T07 mevcut profiller etkilenmedi (sayı aynı, kümede olmayan değer yok): '
                 || ((SELECT count(*) FROM public.profiles) = d.profiles_before AND v_int = 0)::text);

  SELECT count(*) INTO v_int FROM pg_constraint
   WHERE conrelid = 'public.profiles'::regclass AND contype = 'c'
     AND pg_get_constraintdef(oid) LIKE '%user_segment%';
  res := res || ('T08 profiles''ta tek segment kısıtı (aynı adla): ' || (v_int = 1)::text);

  SELECT count(*) INTO v_int FROM supabase_migrations.schema_migrations WHERE version = '20261005126000';
  res := res || ('T09 migration geçmişine yazıldı: ' || (v_int = 1)::text);

  RAISE EXCEPTION 'DRYRUN_RESULT >> %', array_to_string(res, ' || ');
END
$dry$;

ROLLBACK;
