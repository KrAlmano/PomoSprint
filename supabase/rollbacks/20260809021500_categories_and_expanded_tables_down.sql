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
--   categories tablosunu CASCADE ile SİLER; profiles.lifetime_points,
--   coins, longest_streak ve timezone kolonlarını SİLER. Tüm
--   kullanıcıların coin, puan ve kategori verisi kalıcı olarak kaybolur.
--   study_sessions.category_id ve puan/doğrulama kolonları da silinir;
--   güncel complete_study_session bu kolonlara yazdığı için seans
--   gönderimi tamamen durur.
-- ============================================================

BEGIN;

-- Reverse study_sessions
ALTER TABLE public.study_sessions 
    DROP COLUMN IF EXISTS category_id,
    DROP COLUMN IF EXISTS base_points,
    DROP COLUMN IF EXISTS bonus_points,
    DROP COLUMN IF EXISTS was_paused,
    DROP COLUMN IF EXISTS is_verified,
    DROP COLUMN IF EXISTS client_uuid;

-- Reverse profiles
ALTER TABLE public.profiles 
    DROP COLUMN IF EXISTS lifetime_points,
    DROP COLUMN IF EXISTS coins,
    DROP COLUMN IF EXISTS longest_streak,
    DROP COLUMN IF EXISTS timezone;

-- Reverse categories
DROP TABLE IF EXISTS public.categories CASCADE;

COMMIT;
