-- ============================================================================
-- ÖNERİ 26: SEGMENT GENİŞLETME (KPSS, dil sınavı)
--                                                           ÖNCELİK: P2
-- ============================================================================
-- Test ajanı bulgusu t2-04 (5 Ekim 2026): onboarding hedeflerinde KPSS ve
-- dil sınavları (YDS / YÖKDİL / IELTS / TOEFL) yok. İstemci (onboarding)
-- artık 'kpss' ve 'language' hedeflerini gösterip profiles.user_segment'e
-- yazıyor; canlıdaki profiles_user_segment_check yalnızca
-- 'lgs', 'yks', 'university', 'work' (ve NULL) kabul ediyor.
--
-- SIRA: bağımsız. Canlı hâlde de, zincir (12 → … → 14) ve 20–25 uygulanmış
-- hâlde de çalışır (yalnızca bu kısıta dokunur); README tablosunda 25'ten
-- sonra 13. adım. tool/local_supabase/proposed_chain_check.sh zincirin
-- sonunda sınar.
--
-- DEĞİŞİKLİK
--  profiles_user_segment_check yeniden kurulur:
--    user_segment = ANY (ARRAY['lgs','yks','kpss','language','university','work'])
--  Mevcut satırların hepsi eski kümede olduğu için doğrulama hiçbir satırı
--  reddetmez (profiles kısa süre ACCESS EXCLUSIVE kilitlenir; tek tablo
--  taraması). Yetki, RLS ve fonksiyonlar değişmez.
--
-- İSTEMCİ SÖZLEŞMESİ
--  * İstemci (SupabaseService.validUserSegments) 'kpss' ve 'language'ı
--    onboarding PATCH'inde gönderir. 26 UYGULANMADAN gelen istek 23514
--    (profiles_user_segment_check) alır; istemci bunu tanır ve aynı PATCH'i
--    user_segment = NULL ile bir kez daha yazar (onboarding tamamlanır,
--    kategoriler önceden kurulur, kullanıcı hata görmez). 26'dan sonra hedef
--    olduğu gibi saklanır. Yani 26 istemciden önce ya da sonra uygulanabilir.
--  * NULL ve eski dört değer aynen geçerli; başka değer yine 23514.
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- ADIMLAR (SQL Editor, kullanıcı çalıştırır)
--  1. supabase/tests/proposed_26_segment_genisletme_dryrun.sql → sonda
--     DRYRUN_RESULT; her madde 'true'.
--  2. Bu dosya \echo/\quit satırları silinerek (geçmişe 20261005126000
--     segment_genisletme).
--  3. Doğrulama:
--       select pg_get_constraintdef(oid) from pg_constraint
--        where conrelid = 'public.profiles'::regclass
--          and conname = 'profiles_user_segment_check';
--     → CHECK ((user_segment = ANY (ARRAY['lgs'::text, 'yks'::text,
--       'kpss'::text, 'language'::text, 'university'::text, 'work'::text])))
--  4. Geri alma: 26_segment_genisletme_down.sql (kpss/language satırları
--     NULL olur; dosya başındaki nota bakın).
-- ============================================================================

\echo 'supabase/proposed/26: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

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

COMMIT;
