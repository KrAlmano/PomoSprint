-- ADAY B GERİ ALMA: doğrudan INSERT yeniden açılır, bypass/enumerasyon geri gelir.
\echo 'ADAY: inceleme ve yerel test olmadan uygulamayın.'
\quit
BEGIN;
LOCK TABLE public.waitlist IN ACCESS EXCLUSIVE MODE NOWAIT;
DO $$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101235502' AND name='waitlist_rpc_close_legacy')
 OR has_table_privilege('anon','public.waitlist','INSERT')
 OR has_column_privilege('anon','public.waitlist','email','INSERT')
 THEN RAISE EXCEPTION 'waitlist_cutover_rollback_precondition_changed'; END IF;
END $$;
GRANT INSERT(email,marketing_consent,consent_text_version) ON public.waitlist TO anon;
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261101235502' AND name='waitlist_rpc_close_legacy';
COMMIT;
