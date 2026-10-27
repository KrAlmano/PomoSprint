-- Removes check-in gate only; completed individual seans/points remain.
-- Run BEFORE 160000_down, then 150000_down. Do not rollback active plans.
BEGIN;
DROP FUNCTION public.start_marathon_break(uuid,integer,uuid);
DROP FUNCTION public.confirm_marathon_presence(uuid,integer,uuid);
DROP FUNCTION public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer);
ALTER FUNCTION public._complete_marathon_study_session_before_presence(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)
 RENAME TO complete_marathon_study_session;
REVOKE ALL ON FUNCTION public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer) TO authenticated,service_role;
CREATE OR REPLACE FUNCTION public.get_marathon_config()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
  SELECT jsonb_build_object('available',true,'break_seconds',300,'bonuses',jsonb_build_object(
    '25',jsonb_build_object('2',public.marathon_bonus_for(25,2),'3',public.marathon_bonus_for(25,3),'4',public.marathon_bonus_for(25,4)),
    '50',jsonb_build_object('2',public.marathon_bonus_for(50,2),'3',public.marathon_bonus_for(50,3),'4',public.marathon_bonus_for(50,4))));
$function$;
DROP TABLE public.marathon_presence_gates;
DROP TABLE public.marathon_presence_settings;
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261007170000';
COMMIT;
