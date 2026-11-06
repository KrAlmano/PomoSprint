-- REVIEW ONLY: removing v2 returns upgraded clients to an explicitly warned
-- legacy path. Inspect live dependencies, function owner/body and ACL first.
\quit
BEGIN;
DO $$
BEGIN
  IF to_regprocedure('public.get_my_exam_attempts_v2(integer,timestamptz,uuid)') IS NULL
     OR NOT (SELECT prosecdef AND proconfig=ARRAY['search_path=public, pg_temp']
               FROM pg_proc WHERE oid='public.get_my_exam_attempts_v2(integer,timestamptz,uuid)'::regprocedure)
     OR has_function_privilege('anon','public.get_my_exam_attempts_v2(integer,timestamptz,uuid)','EXECUTE')
     OR NOT has_function_privilege('authenticated','public.get_my_exam_attempts_v2(integer,timestamptz,uuid)','EXECUTE')
  THEN RAISE EXCEPTION 'exam_history_v2_rollback_baseline_changed'; END IF;
END $$;
-- No CASCADE: a later dependency causes rollback to stop instead of deleting it.
DROP FUNCTION public.get_my_exam_attempts_v2(integer,timestamptz,uuid);
COMMIT;
