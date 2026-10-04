-- ============================================================================
-- GERİ ALMA: supabase/proposed/26_segment_genisletme.sql
-- ============================================================================
-- 26'dan önceki hâle döner: profiles_user_segment_check yeniden yalnızca
-- 'lgs', 'yks', 'university', 'work' (ve NULL) kabul eder.
--
-- VERİ: user_segment'i 'kpss' ya da 'language' olan profiller NULL yapılır
-- (kısıt yoksa kurulamaz). Kullanıcıya etkisi yok denecek kadar az: istemci
-- NULL'u "Diğer" gibi ele alır (sayaç başlığı "DERS SEÇ" aynı kalır;
-- kategorisi hiç olmayan hesabın varsayılanları genel öneriler olur).
-- Etkilenen satır sayısı NOTICE olarak yazılır. 26_down'dan sonra yeni
-- istemcinin bu hedefleri göndermesi yine sorunsuzdur (segmentsiz biter).
-- ============================================================================

\echo 'supabase/proposed/26_down: doğrudan çalıştırılmaz; \echo/\quit satırlarını silip SQL Editor''de çalıştırın.'
\quit

BEGIN;

DO $pre$
DECLARE
    v_def text;
BEGIN
    SELECT pg_get_constraintdef(oid) INTO v_def
      FROM pg_constraint
     WHERE conrelid = 'public.profiles'::regclass AND conname = 'profiles_user_segment_check';
    IF v_def IS DISTINCT FROM
       'CHECK ((user_segment = ANY (ARRAY[''lgs''::text, ''yks''::text, ''kpss''::text, ''language''::text, ''university''::text, ''work''::text])))' THEN
        RAISE EXCEPTION 'proposed/26_down: 26 uygulanmamış görünüyor; yapılacak bir şey yok (kısıt: %).', coalesce(v_def, '(yok)');
    END IF;
END
$pre$;

DO $data$
DECLARE
    v_count integer;
BEGIN
    UPDATE public.profiles SET user_segment = NULL WHERE user_segment IN ('kpss', 'language');
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RAISE NOTICE 'proposed/26_down: % profilin kpss/language hedefi NULL yapıldı.', v_count;
END
$data$;

ALTER TABLE public.profiles DROP CONSTRAINT profiles_user_segment_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_user_segment_check
    CHECK (user_segment = ANY (ARRAY['lgs'::text, 'yks'::text, 'university'::text, 'work'::text]));

DO $$
BEGIN
    DELETE FROM supabase_migrations.schema_migrations WHERE version = '20261005126000';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişinden silinemedi: %', SQLERRM;
END $$;

COMMIT;
