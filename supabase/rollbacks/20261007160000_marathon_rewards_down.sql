-- Fonksiyon/plan takibini kaldırır; geçmiş ödül ve seans kayıtları korunur.
-- Plan takip verisi kaybolur; geri alma sonrası uygulama Maraton bonus RPC'sini kullanamaz.
BEGIN;
DROP FUNCTION public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer);
DROP FUNCTION public.get_marathon_config();
DROP FUNCTION public.marathon_bonus_for(integer,integer);
DROP TABLE public.marathon_run_sessions;
DROP TABLE public.marathon_runs;
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261007160000';
COMMIT;
