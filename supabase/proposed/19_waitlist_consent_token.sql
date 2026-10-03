-- ============================================================
-- ÖNERİ 19: waitlist — ticari ileti onay kaydı ve abonelikten çıkma token'ı
--                                              ÖNCELİK: P2 (6563 / KVKK-11)
-- ============================================================
-- 3 Ekim 2026'da canlı şema okunarak yazıldı (information_schema.columns,
-- pg_constraint, pg_policies, role_table_grants; satır okunmadı):
--   public.waitlist(id uuid PK DEFAULT gen_random_uuid(),
--                   email text NOT NULL UNIQUE + CHECK biçim ve <= 254,
--                   created_at timestamptz DEFAULT now())
--   Politika "Allow public insert to waitlist": INSERT TO anon WITH CHECK (true)
--   Yetki: anon INSERT (tablo düzeyinde). anon/authenticated SELECT, UPDATE,
--   DELETE yok. Trigger yok.
--
-- SORUN
--  1. Site formu artık ayrı ve önceden işaretsiz bir ticari elektronik ileti
--     onay kutusu istiyor (landing/index.html, landing/js/main.js); kutu
--     işaretlenmeden kayıt gönderilmiyor. Ama onay yalnızca istemcide:
--     sunucuda onayın verildiği, onay metninin sürümü ve zamanı kayıtlı değil
--     (6563 ve İYS açısından ispat yükü). Doğrudan REST çağrısı da onaysız
--     satır ekleyebiliyor.
--  2. Bekleme listesindeki kişinin kişiye özel abonelikten çıkma token'ı yok:
--     lansman e-postasına tek tık çıkış bağlantısı (List-Unsubscribe) ve
--     e-posta adresi taşımayan bir çıkış sayfası bağlantısı konamıyor.
--
-- ÖNERİ: iki aşama
--  A (geriye uyumlu, hemen uygulanabilir): kolonlar + token + onay zamanı
--    trigger'ı. Canlı site yalnızca {email} gönderdiği için kayıt akışı
--    bozulmaz; yeni satırlarda marketing_consent NULL kalır.
--  B (site güncellendikten SONRA): site isteği
--    { email, marketing_consent: true, consent_text_version: "waitlist-2026-10-03" }
--    olacak şekilde landing/js/main.js'te değiştirilip deploy edildikten sonra
--    anon INSERT yalnızca onaylı satıra izin verir; anon'un yazabildiği
--    kolonlar e-posta ve onay alanlarıyla sınırlanır (token ve onay zamanı
--    sunucuda üretilir, istemci belirleyemez).
--    B'yi site güncellenmeden uygularsan bekleme listesi kaydı TAMAMEN durur.
--
-- Bu öneriden sonra ayrıca (sunucu kodu, ayrı iş):
--  * supabase/functions/unsubscribe: token marketing_subscribers'ta yoksa
--    waitlist.unsubscribe_token'da aransın ve o satır silinsin.
--  * Lansman e-postası gönderim betiği bekleme listesinde yalnızca
--    marketing_consent = true satırlara, ?token=<waitlist.unsubscribe_token>
--    bağlantısıyla göndersin. marketing_consent NULL olan eski kayıtlara
--    (onay kutusu öncesi) gönderim yapılıp yapılmayacağı hukuki karardır.
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- ADIMLAR
--  1. Canlı şemanın hâlâ yukarıdakiyle aynı olduğunu doğrula:
--       select column_name, data_type, column_default from information_schema.columns
--        where table_schema = 'public' and table_name = 'waitlist';
--       select policyname, cmd, roles, with_check from pg_policies
--        where schemaname = 'public' and tablename = 'waitlist';
--  2. SQL Editor'de önce kuru çalıştırma:
--       supabase/tests/proposed_19_waitlist_consent_token_dryrun.sql
--     Sonda DRYRUN_RESULT hatası beklenir; her satır 'true' olmalı.
--  3. A bölümünü \echo/\quit satırları olmadan
--     supabase/migrations/<zaman damgası>_waitlist_consent_token.sql olarak
--     kopyalayıp SQL Editor'de çalıştır.
--  4. Siteyi onay alanlarını gönderecek şekilde güncelle ve deploy et; sitede
--     bir deneme kaydı yapıp satırda marketing_consent = true ve consented_at
--     dolu olduğunu doğrula. Sonra B bölümünü ayrı bir migration olarak çalıştır.
--  5. Geri alma: supabase/proposed/19_waitlist_consent_token_down.sql
-- ============================================================

\echo 'supabase/proposed/19: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

-- ------------------------------------------------------------
-- A) Kolonlar, token ve onay zamanı (geriye uyumlu)
-- ------------------------------------------------------------
BEGIN;

-- gen_random_uuid() oynak varsayılan: mevcut her satıra ayrı bir token yazılır.
ALTER TABLE public.waitlist
  ADD COLUMN IF NOT EXISTS unsubscribe_token uuid NOT NULL DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS marketing_consent boolean,
  ADD COLUMN IF NOT EXISTS consent_text_version text,
  ADD COLUMN IF NOT EXISTS consented_at timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS waitlist_unsubscribe_token_key
  ON public.waitlist (unsubscribe_token);

ALTER TABLE public.waitlist
  ADD CONSTRAINT waitlist_consent_text_version_check
  CHECK (consent_text_version IS NULL OR length(consent_text_version) BETWEEN 1 AND 64);

COMMENT ON COLUMN public.waitlist.marketing_consent IS
  'Sitedeki ayrı ticari elektronik ileti onay kutusu. NULL: onay kutusundan önceki kayıt.';
COMMENT ON COLUMN public.waitlist.consent_text_version IS
  'Onay metninin sürümü (ör. waitlist-2026-10-03); metin değişince site yeni değer gönderir.';
COMMENT ON COLUMN public.waitlist.consented_at IS
  'Onay zamanı; istemci değil BEFORE INSERT trigger''ı yazar.';
COMMENT ON COLUMN public.waitlist.unsubscribe_token IS
  'Abonelikten çıkma bağlantısı için tahmin edilemez token; e-posta adresi bağlantıya konmaz.';

-- Onay zamanı sunucuda: istemcinin gönderdiği değer yok sayılır.
CREATE OR REPLACE FUNCTION public.waitlist_set_consent_time()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  new.consented_at := case when new.marketing_consent is true then now() else null end;
  return new;
end;
$function$;

REVOKE ALL ON FUNCTION public.waitlist_set_consent_time() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS waitlist_set_consent_time ON public.waitlist;
CREATE TRIGGER waitlist_set_consent_time
  BEFORE INSERT ON public.waitlist
  FOR EACH ROW EXECUTE FUNCTION public.waitlist_set_consent_time();

COMMIT;

-- ------------------------------------------------------------
-- B) Yalnızca onaylı kayıt (site onay alanlarını gönderdikten SONRA)
-- ------------------------------------------------------------
BEGIN;

-- anon yalnızca e-posta ve onay alanlarını yazabilir; token, onay zamanı ve
-- id sunucuda üretilir.
REVOKE INSERT ON public.waitlist FROM anon;
GRANT INSERT (email, marketing_consent, consent_text_version) ON public.waitlist TO anon;

ALTER POLICY "Allow public insert to waitlist" ON public.waitlist
  WITH CHECK (marketing_consent IS TRUE AND consent_text_version IS NOT NULL);

COMMIT;
