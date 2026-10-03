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
--   avatars ve avatar_unlocks tablolarını SİLER: satın alınmış tüm
--   avatarlar ve coin harcama kayıtları kalıcı olarak kaybolur.
--   profiles.equipped_avatar_id kolonu ve purchase_avatar /
--   set_equipped_avatar fonksiyonları silinir.
-- ============================================================

-- Migration: 20260809030000_avatars_and_economy_down.sql

BEGIN;

DROP FUNCTION IF EXISTS public.set_equipped_avatar(text);
DROP FUNCTION IF EXISTS public.purchase_avatar(text);

DROP TRIGGER IF EXISTS on_profile_created_give_avatars ON public.profiles;
DROP FUNCTION IF EXISTS public.give_default_avatars();

ALTER TABLE public.profiles DROP COLUMN IF EXISTS equipped_avatar_id;

DROP TABLE IF EXISTS public.avatar_unlocks;
DROP TABLE IF EXISTS public.avatars;

COMMIT;
