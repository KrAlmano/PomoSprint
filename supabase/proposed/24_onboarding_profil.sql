-- ============================================================================
-- ÖNERİ 24: ONBOARDING PROFİLİ (yaş sınırı, seçilmemiş görünürlük)
--                                                           ÖNCELİK: P1/P2
-- ============================================================================
-- Test ajanı bulguları (5 Ekim 2026, yerel kopyada yeniden üretildi:
-- supabase/tests/proposed_20_25_bulgu_repro_local.sql):
--  t2-01  (high, sunucu kısmı) Taslaktan dönen kullanıcı görünürlük sorusunu
--         yanıtlamadan onboarding'i bitirebiliyor; PATCH'te
--         show_in_social_feed yok, sunucu varsayılan TRUE bırakıyor ('Hayır'
--         diyen kişi herkese açık sıralamaya giriyor). proposed/14 yeni
--         profillerde varsayılanı FALSE yapar (zincirde doğrulandı); bu dosya
--         14'ten ÖNCE kaydolmuş ama onboarding'i HENÜZ bitirmemiş profilleri
--         de seçim yapılana kadar FALSE yapar. İstemci düzeltmesi (taslakta
--         görünürlük, restore'da görünürlük adımına dönüş, completeOnboarding'de
--         zorunlu alan) ayrı iş.
--  t2-05  13 yaş sınırı yalnızca istemcide: sunucu 5 yaşında doğum yılıyla
--         onboarding'i tamamlıyor.
--
-- SIRA: zincirden (… → 13 → 14) SONRA (14'ün ops şeması ve görünürlük
-- varsayılanı ön koşul); 20–23 ile çakışmaz.
--
-- DEĞİŞİKLİKLER
--  A. enforce_minimum_age trigger'ı (profiles, BEFORE INSERT / UPDATE OF
--     birth_year, onboarding_completed_at): onboarding_completed_at doluyken
--     birth_year > (yıl - 13) ise 'birth_year_under_minimum_age' (23514).
--     Yıl, istemcinin kuralıyla (DateTime.now().year - doğum yılı < 13) aynı;
--     sunucu en ileri saat dilimindeki yılı (UTC+14) kullanır: yılbaşında
--     istemcinin kabul ettiği bir yıl sunucuda reddedilmez. Yalnızca bu iki
--     kolon YAZILIRKEN çalışır: mevcut (13 yaş altı kaydedilmiş) profillerin
--     diğer güncellemeleri (seans, ad, hedef) etkilenmez.
--  B. Tek seferlik veri: onboarding_completed_at NULL ve show_in_social_feed
--     TRUE olan profiller FALSE yapılır (seçim yapılmamış; onboarding açıkça
--     soruyor). Etkilenen kimlikler ops.proposed24_social_feed_reset'te
--     tutulur; 24_down onları (hâlâ onboarding'i bitirmemişse) geri açar.
--     ÜRÜN ETKİSİ: yok denecek kadar az; onboarding'i bitmemiş kullanıcı
--     kabuğa (sıralama, seans) giremediği için hiçbir listede görünmüyordu.
--
-- İSTEMCİ SÖZLEŞMESİ: onboarding PATCH'inde yeni hata metni
-- 'birth_year_under_minimum_age' (SQLSTATE 23514). Bugünkü istemci 23xxx'i
-- invalidInput'a eşler (kırılmaz); yeni istemci bunu underAge olarak
-- sınıflandırmalı (yaş adımı zaten istemcide engelliyor).
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- ADIMLAR (SQL Editor, kullanıcı çalıştırır)
--  1. supabase/tests/proposed_24_onboarding_profil_dryrun.sql → sonda
--     DRYRUN_RESULT; her madde 'true'.
--  2. Bu dosya \echo/\quit satırları silinerek (geçmişe 20261005124000
--     onboarding_profil).
--  3. Doğrulama: select count(*) from ops.proposed24_social_feed_reset;
--  4. Geri alma: 24_onboarding_profil_down.sql.
-- ============================================================================

\echo 'supabase/proposed/24: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

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

COMMIT;
