-- ============================================================
-- UYARI: CANLIYA UYGULAMADAN ÖNCE OKUYUN
-- ------------------------------------------------------------
-- Bu dosya bir GERİ ALMA (rollback) betiğidir, migration DEĞİLDİR.
-- supabase/migrations/ dışında tutulur; aksi halde `supabase db push`
-- onu aynı sürüm numaralı ileri migration sanıp _up dosyasından ÖNCE
-- uygular. Repodaki migration'lar canlı şemanın gerisinde olduğu için
-- bu betik canlıdaki güncel fonksiyon gövdelerini ESKİ sürümlerle
-- ezebilir ve geri alınamaz şekilde VERİ SİLEBİLİR.
-- Uygulamadan önce `supabase db dump` ile yedek alın, dosyayı satır
-- satır okuyun ve önce staging/branch üzerinde deneyin.
--
-- Bu dosyaya özel riskler:
--   study_sessions.started_at kolonunu SİLER. Seans doğrulama trigger'ı
--   (validate_study_session_timing) ve seri/günlük tavan hesapları bu
--   kolona bağlı olduğundan sonraki tüm seans gönderimleri reddedilir.
--   DROP FUNCTION satırı boolean p_is_verified imzasını hedefler; canlıdaki
--   integer imzalı fonksiyonu etkilemez.
-- ============================================================

BEGIN;

-- Drop the new RPC
DROP FUNCTION IF EXISTS public.complete_study_session(uuid, uuid, integer, boolean, boolean, timestamptz);

-- Drop unique constraint
DROP INDEX IF EXISTS public.study_sessions_user_client_uuid_key;

-- Drop started_at column
ALTER TABLE public.study_sessions DROP COLUMN IF EXISTS started_at;

COMMIT;
