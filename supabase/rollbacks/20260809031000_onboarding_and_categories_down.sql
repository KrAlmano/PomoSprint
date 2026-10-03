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
--   profiles.user_segment, daily_goal_minutes, birth_year ve
--   onboarding_completed_at kolonlarını SİLER: tüm kullanıcılar
--   onboarding'i yeniden görür, günlük hedefler kaybolur.
--   create_category ve setup_onboarding_categories silinir; istemci
--   kategori oluşturamaz.
-- ============================================================

DROP FUNCTION IF EXISTS public.setup_onboarding_categories(jsonb);
DROP FUNCTION IF EXISTS public.create_category(text, text, text);

ALTER TABLE public.profiles DROP COLUMN IF EXISTS user_segment;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS daily_goal_minutes;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS birth_year;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS onboarding_completed_at;
