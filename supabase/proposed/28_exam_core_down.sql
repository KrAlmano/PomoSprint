-- Safe rollback: refusal preserves recorded attempts, results and their rewards.
\echo 'Review README. This rollback refuses if any attempt exists.'
\quit
BEGIN;
DO $$ BEGIN
 IF to_regclass('public.competition_policy') IS NOT NULL THEN RAISE EXCEPTION 'exam_rollback_requires_competition_down_first';END IF;
 IF EXISTS(SELECT 1 FROM public.exam_attempts) OR EXISTS(SELECT 1 FROM public.exam_wallets) THEN RAISE EXCEPTION 'exam_rollback_refused_existing_attempts';END IF;
END $$;
DROP TRIGGER exam_guard_normal_study ON public.study_sessions;
DO $$ DECLARE r record;BEGIN FOR r IN SELECT * FROM public.exam_install_backup LOOP EXECUTE r.definition;END LOOP;END $$;
DROP FUNCTION public.get_my_study_sessions_v2(timestamptz,integer,integer),public.get_exam_config(),public.start_exam_attempt(uuid,text),public.complete_exam_attempt(uuid),public.abandon_exam_attempt(uuid),public.get_my_exam_attempts(integer,timestamptz),public.save_exam_results(uuid,jsonb),public._exam_payload(uuid),public._exam_has_overlap(uuid,timestamptz,timestamptz),public._exam_guard_study_insert();
DROP TABLE public.exam_subject_results,public.exam_wallets,public.exam_attempts,public.exam_catalog,public.exam_install_backup;
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261028020000' AND name='exam_core';
NOTIFY pgrst,'reload schema';
COMMIT;
