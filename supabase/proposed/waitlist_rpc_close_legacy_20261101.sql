-- ADAY B: önce RPC ve güncel site yayınlanmış, eski istemci etkisi kabul edilmiş olmalı.
-- Eski sayfalardan doğrudan tabloya yapılan kayıtlar artık hata döndürür.
\echo 'ADAY: inceleme ve yerel test olmadan uygulamayın.'
\quit
BEGIN;
SET LOCAL lock_timeout='2s';
LOCK TABLE public.waitlist IN ACCESS EXCLUSIVE MODE NOWAIT;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101235501' AND name='waitlist_rpc_abuse_guard')
     OR to_regprocedure('public.submit_waitlist(text,boolean,text)') IS NULL
     OR has_table_privilege('anon','public.waitlist','INSERT')
     OR NOT has_column_privilege('anon','public.waitlist','email','INSERT')
     OR NOT has_column_privilege('anon','public.waitlist','marketing_consent','INSERT')
     OR NOT has_column_privilege('anon','public.waitlist','consent_text_version','INSERT')
  THEN RAISE EXCEPTION 'waitlist_rpc_cutover_precondition_changed'; END IF;
END $$;
REVOKE INSERT (email,marketing_consent,consent_text_version) ON public.waitlist FROM anon;
DO $$ BEGIN
  IF has_table_privilege('anon','public.waitlist','INSERT')
     OR EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid='public.waitlist'::regclass
          AND a.attnum > 0 AND NOT a.attisdropped
          AND has_column_privilege('anon','public.waitlist',a.attname,'INSERT'))
     OR has_table_privilege('anon','public.waitlist','SELECT')
  THEN RAISE EXCEPTION 'waitlist_rpc_direct_bypass_remains'; END IF;
END $$;
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261101235502','waitlist_rpc_close_legacy');
COMMIT;
