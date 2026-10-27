-- CANLIYA UYGULANMADI. TUS kullanan profil varsa kayıpsız geri alma mümkün
-- olmadığından bu betik reddeder; kullanıcı hedefini sessizce NULL yapmaz.
\echo 'Öneri 27 down: önce README.'
\quit
BEGIN;
DO $$ BEGIN
 IF to_regclass('public.exam_attempts') IS NOT NULL THEN RAISE EXCEPTION 'tus_rollback_requires_exam_down_first'; END IF;
 IF EXISTS(SELECT 1 FROM public.profiles WHERE user_segment='tus') THEN
  RAISE EXCEPTION 'tus_segment_in_use';
 END IF;
END $$;
ALTER TABLE public.profiles DROP CONSTRAINT profiles_user_segment_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_user_segment_check
 CHECK(user_segment=ANY(ARRAY['lgs','yks','kpss','language','university','work']::text[]));
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261028010000' AND name='tus_segment';
COMMIT;
