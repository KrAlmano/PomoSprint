-- ============================================================
-- GERİ ALMA: ÖNERİ 19 (waitlist onay kaydı ve token)
-- ============================================================
-- 3 Ekim 2026 canlı durumuna döner: politika WITH CHECK (true), anon'a
-- tablo düzeyinde INSERT, ek kolon/trigger yok.
-- DİKKAT: kolonlar silinince onay kayıtları (marketing_consent,
-- consent_text_version, consented_at) ve token'lar KALICI olarak kaybolur.
-- Gerekirse önce dışa aktar:
--   select id, email, marketing_consent, consent_text_version, consented_at
--     from public.waitlist where marketing_consent is not null;
-- Site onay alanlarını gönderiyorsa, geri almadan ÖNCE siteyi yalnızca
-- {email} gönderen sürüme döndür (yoksa PostgREST bilinmeyen kolon hatası verir).
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ (\quit). Gerekirse
-- \echo/\quit satırları olmadan SQL Editor'de çalıştırın.
-- ============================================================

\echo 'supabase/proposed/19_down: doğrudan çalıştırılmaz.'
\quit

BEGIN;

ALTER POLICY "Allow public insert to waitlist" ON public.waitlist WITH CHECK (true);

REVOKE INSERT (email, marketing_consent, consent_text_version) ON public.waitlist FROM anon;
GRANT INSERT ON public.waitlist TO anon;

DROP TRIGGER IF EXISTS waitlist_set_consent_time ON public.waitlist;
DROP FUNCTION IF EXISTS public.waitlist_set_consent_time();

DROP INDEX IF EXISTS public.waitlist_unsubscribe_token_key;

ALTER TABLE public.waitlist
  DROP CONSTRAINT IF EXISTS waitlist_consent_text_version_check,
  DROP COLUMN IF EXISTS consented_at,
  DROP COLUMN IF EXISTS consent_text_version,
  DROP COLUMN IF EXISTS marketing_consent,
  DROP COLUMN IF EXISTS unsubscribe_token;

COMMIT;
