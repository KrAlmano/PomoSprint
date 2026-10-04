-- ============================================================================
-- KURU ÇALIŞTIRMA: supabase/proposed/24_onboarding_profil.sql
-- (canlıda hiçbir şeyi kalıcı DEĞİŞTİRMEZ)
-- Supabase Dashboard > SQL Editor'e yapıştırıp Run'a basın. Önce öneriden
-- ÖNCEKİ tanımlarla üç sentetik "eski" profil oluşturulur (onboarding'i
-- bitmemiş ve görünürlüğü açık; bitmiş ve açık; 13 yaş altı doğum yılıyla
-- bitmiş), sonra öneri uygulanır ve senaryolar sentetik kullanıcılarla
-- (@example.invalid) çalışır. En sonda bilinçli bir hata (DRYRUN_RESULT)
-- fırlatılır ve her şey geri alınır. Her maddenin sonu 'true' olmalı.
--
-- Notlar
--  * B bölümü işlem içinde GERÇEK onboarding'i bitmemiş profillerin de
--    görünürlüğünü kapatır; işlem geri alındığı için kalıcı değildir.
--  * Gövde 24_onboarding_profil.sql ile birebir aynıdır (BEGIN/COMMIT
--    hariç); tool/local_supabase/proposed_chain_check.sh bunu denetler.
-- ============================================================================
BEGIN;

-- ---------------------------------------------------------------------------
-- Öneriden ÖNCE (zincirdeki tanımlarla): eski profiller
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE dry24 ON COMMIT DROP AS
SELECT gen_random_uuid() AS u_pending, gen_random_uuid() AS u_done, gen_random_uuid() AS u_child;
INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
SELECT x.id, 'dryrun24-' || x.tag || '-' || x.id || '@example.invalid', '{"name":"Dry Profil"}', 'authenticated', 'authenticated'
FROM dry24, LATERAL (VALUES (u_pending, 'p'), (u_done, 'd'), (u_child, 'c')) AS x(id, tag);
UPDATE public.profiles SET show_in_social_feed = true WHERE id IN (SELECT u_pending FROM dry24 UNION ALL SELECT u_done FROM dry24);
UPDATE public.profiles SET onboarding_completed_at = now() - interval '10 days', birth_year = 2000
 WHERE id = (SELECT u_done FROM dry24);
UPDATE public.profiles SET onboarding_completed_at = now() - interval '10 days',
                           birth_year = extract(year FROM now())::integer - 5
 WHERE id = (SELECT u_child FROM dry24);

-- >>> ÖNERİ GÖVDESİ (supabase/proposed/24_onboarding_profil.sql, BEGIN/COMMIT hariç, birebir) >>>

-- ---------------------------------------------------------------------------
-- 0) Ön koşul: 14 uygulanmış (ops şeması, görünürlük varsayılanı false)
-- ---------------------------------------------------------------------------
DO $pre$
BEGIN
    IF to_regnamespace('ops') IS NULL
       OR (SELECT column_default FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = 'profiles'
              AND column_name = 'show_in_social_feed') IS DISTINCT FROM 'false' THEN
        RAISE EXCEPTION 'proposed/24 ön koşulu: önce zincir uygulanmalı (14: ops şeması, show_in_social_feed varsayılanı false).';
    END IF;
    IF to_regprocedure('public.enforce_minimum_age()') IS NOT NULL THEN
        RAISE EXCEPTION 'proposed/24 ön koşulu: enforce_minimum_age zaten var (24 uygulanmış görünüyor).';
    END IF;
END
$pre$;

-- ---------------------------------------------------------------------------
-- A) 13 yaş sınırı (t2-05)
-- ---------------------------------------------------------------------------
CREATE FUNCTION public.enforce_minimum_age()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF NEW.onboarding_completed_at IS NOT NULL
       AND NEW.birth_year IS NOT NULL
       AND NEW.birth_year > extract(year FROM (now() AT TIME ZONE 'Pacific/Kiritimati'))::integer - 13 THEN
        RAISE EXCEPTION 'birth_year_under_minimum_age'
            USING ERRCODE = 'check_violation',
                  HINT = 'PomoSprint 13 yaş ve üzeri içindir (Kullanım Şartları).';
    END IF;
    RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.enforce_minimum_age() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.enforce_minimum_age() TO service_role;

CREATE TRIGGER enforce_minimum_age
    BEFORE INSERT OR UPDATE OF birth_year, onboarding_completed_at ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.enforce_minimum_age();

-- ---------------------------------------------------------------------------
-- B) Onboarding'i bitmemiş profillerde seçilmemiş görünürlük (t2-01)
-- ---------------------------------------------------------------------------
CREATE TABLE ops.proposed24_social_feed_reset (
    user_id uuid PRIMARY KEY,
    reset_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON ops.proposed24_social_feed_reset FROM PUBLIC;
COMMENT ON TABLE ops.proposed24_social_feed_reset IS
  'proposed/24: onboarding''i bitmeden show_in_social_feed = true iken false yapılan profiller (24_down geri açar).';

INSERT INTO ops.proposed24_social_feed_reset (user_id)
SELECT p.id FROM public.profiles p
 WHERE p.onboarding_completed_at IS NULL AND p.show_in_social_feed;

UPDATE public.profiles p
   SET show_in_social_feed = false
  FROM ops.proposed24_social_feed_reset r
 WHERE r.user_id = p.id;

DO $$
BEGIN
    INSERT INTO supabase_migrations.schema_migrations (version, name)
    VALUES ('20261005124000', 'onboarding_profil')
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
  v_bool boolean;
  v_int integer;
  v_year integer := extract(year FROM (now() AT TIME ZONE 'Pacific/Kiritimati'))::integer;
  u1 uuid := gen_random_uuid();
  u2 uuid := gen_random_uuid();
BEGIN
  SELECT * INTO d FROM dry24;
  INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role) VALUES
    (u1, 'dryrun24-n1-' || u1 || '@example.invalid', '{"name":"Dry Yeni"}', 'authenticated', 'authenticated'),
    (u2, 'dryrun24-n2-' || u2 || '@example.invalid', '{"name":"Dry Yeni"}', 'authenticated', 'authenticated');

  res := res || ('T01 trigger kuruldu: '
                 || EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.profiles'::regclass AND tgname = 'enforce_minimum_age')::text);

  -- ======================= t2-05: yaş sınırı =======================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u1, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_txt := '';
  BEGIN
    UPDATE public.profiles SET birth_year = v_year - 5, daily_goal_minutes = 60, show_in_social_feed = false,
                               onboarding_completed_at = now() WHERE id = u1;
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLSTATE || ' ' || SQLERRM || '|'; END;
  BEGIN
    UPDATE public.profiles SET birth_year = v_year - 12, onboarding_completed_at = now() WHERE id = u1;
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLSTATE || '|'; END;
  EXECUTE 'RESET ROLE';
  res := res || ('T02 5 ve 12 yaş doğum yılıyla onboarding reddedilir (' || v_txt || '): '
                 || (v_txt = '23514 birth_year_under_minimum_age|23514|'
                     AND (SELECT onboarding_completed_at IS NULL FROM public.profiles WHERE id = u1))::text);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', u1, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  UPDATE public.profiles SET birth_year = v_year - 5 WHERE id = u1;
  UPDATE public.profiles SET birth_year = v_year - 13, onboarding_completed_at = now() WHERE id = u1;
  EXECUTE 'RESET ROLE';
  res := res || ('T03 onboarding bitmeden yıl yazılabilir; tam 13 yaş kabul: '
                 || coalesce((SELECT birth_year = v_year - 13 AND onboarding_completed_at IS NOT NULL
                                FROM public.profiles WHERE id = u1), false)::text);

  -- Eski 13 yaş altı profil: diğer güncellemeler etkilenmez
  PERFORM set_config('request.jwt.claims', json_build_object('sub', d.u_child, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  UPDATE public.profiles SET daily_goal_minutes = 90, name = 'Dry Cocuk' WHERE id = d.u_child;
  EXECUTE 'RESET ROLE';
  res := res || ('T04 mevcut (13 yaş altı kaydedilmiş) profilin hedef/ad güncellemesi çalışır: '
                 || coalesce((SELECT daily_goal_minutes = 90 FROM public.profiles WHERE id = d.u_child), false)::text);

  -- ======================= t2-01: seçilmemiş görünürlük =======================
  res := res || ('T05 onboarding''i bitmemiş eski profil kapatıldı ve kaydedildi, bitmiş olana dokunulmadı: '
                 || coalesce(NOT (SELECT show_in_social_feed FROM public.profiles WHERE id = d.u_pending)
                             AND (SELECT show_in_social_feed FROM public.profiles WHERE id = d.u_done)
                             AND EXISTS (SELECT 1 FROM ops.proposed24_social_feed_reset WHERE user_id = d.u_pending)
                             AND NOT EXISTS (SELECT 1 FROM ops.proposed24_social_feed_reset WHERE user_id = d.u_done), false)::text);
  SELECT count(*) INTO v_int FROM public.profiles WHERE onboarding_completed_at IS NULL AND show_in_social_feed;
  res := res || ('T06 onboarding''i bitmemiş hiçbir profil görünür değil (' || v_int || '): ' || (v_int = 0)::text);

  -- Taslaktan dönen istemci: görünürlük göndermeden bitirir → kapalı kalır; açık seçim yazılır
  PERFORM set_config('request.jwt.claims', json_build_object('sub', d.u_pending, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  UPDATE public.profiles SET birth_year = 2001, daily_goal_minutes = 60, onboarding_completed_at = now() WHERE id = d.u_pending;
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u2, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  UPDATE public.profiles SET birth_year = 2001, daily_goal_minutes = 60, show_in_social_feed = true,
                             onboarding_completed_at = now() WHERE id = u2;
  EXECUTE 'RESET ROLE';
  res := res || ('T07 görünürlük gönderilmeden biten onboarding kapalı kalır, açık seçim yazılır: '
                 || coalesce(NOT (SELECT show_in_social_feed FROM public.profiles WHERE id = d.u_pending)
                             AND (SELECT show_in_social_feed FROM public.profiles WHERE id = u2), false)::text);

  res := res || ('T08 trigger fonksiyonu ve yedek tablo API rollerine kapalı: '
                 || (NOT has_function_privilege('authenticated', 'public.enforce_minimum_age()', 'EXECUTE')
                     AND NOT has_function_privilege('anon', 'public.enforce_minimum_age()', 'EXECUTE')
                     AND NOT has_table_privilege('authenticated', 'ops.proposed24_social_feed_reset', 'SELECT'))::text);
  SELECT count(*) INTO v_int FROM supabase_migrations.schema_migrations WHERE version = '20261005124000';
  res := res || ('T09 migration geçmişine yazıldı: ' || (v_int = 1)::text);

  RAISE EXCEPTION 'DRYRUN_RESULT >> %', array_to_string(res, ' || ');
END
$dry$;

ROLLBACK;
