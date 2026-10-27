-- HAZIRLANDI / CANLIYA UYGULANMADI. Sıra: 27 → 28 → 29.
-- SQL Editor'de çalıştırmadan önce eşlik eden DRYRUN ve README'yi okuyun.
\echo 'Öneri 27: inceleme dosyası; SQL Editor için echo/quit satırlarını kaldırın.'
\quit
BEGIN;
DO $$
DECLARE v_definition text;
BEGIN
 SELECT pg_get_constraintdef(oid) INTO v_definition FROM pg_constraint
 WHERE conrelid='public.profiles'::regclass AND conname='profiles_user_segment_check';
 IF v_definition IS DISTINCT FROM 'CHECK ((user_segment = ANY (ARRAY[''lgs''::text, ''yks''::text, ''kpss''::text, ''language''::text, ''university''::text, ''work''::text])))' THEN
  RAISE EXCEPTION 'tus_segment_precondition_changed';
 END IF;
 IF EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261028010000') THEN
  RAISE EXCEPTION 'tus_segment_already_applied';
 END IF;
END $$;
ALTER TABLE public.profiles DROP CONSTRAINT profiles_user_segment_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_user_segment_check
 CHECK(user_segment=ANY(ARRAY['lgs','yks','tus','kpss','language','university','work']::text[]));
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261028010000','tus_segment');
COMMIT;
