-- ADAY A GERİ ALMA: yalnız B geri alındıktan ve site eskiye döndürüldükten sonra.
-- Sınırlayıcının tek satır sayacı silinir; bekleme listesi kayıtları silinmez.
\echo 'ADAY: inceleme ve yerel test olmadan uygulamayın.'
\quit
BEGIN;
LOCK TABLE public.waitlist IN ACCESS EXCLUSIVE MODE NOWAIT;
DO $$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101235501' AND name='waitlist_rpc_abuse_guard')
 OR EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101235502')
 THEN RAISE EXCEPTION 'waitlist_rpc_rollback_precondition_changed'; END IF;
END $$;
DROP FUNCTION public.submit_waitlist(text,boolean,text);
DROP TABLE waitlist_private.budget;
DROP SCHEMA waitlist_private;
DROP INDEX public.waitlist_email_lower_guard_idx;
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261101235501' AND name='waitlist_rpc_abuse_guard';
COMMIT;
