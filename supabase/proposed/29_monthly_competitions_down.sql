-- Reversible only before activation and before pending target choices/results.
-- Canonical study and exam attempts/rewards are never deleted here.
\echo 'Review README. After activation use a reviewed compensating migration.'
\quit
BEGIN;
DO $$ BEGIN
 IF now()>=(SELECT activates_at FROM public.competition_policy WHERE singleton)
 OR EXISTS(SELECT 1 FROM public.competition_results)
 OR EXISTS(SELECT 1 FROM public.competition_target_history WHERE from_month>public._competition_month(now()))
 THEN RAISE EXCEPTION 'competition_rollback_refused_active_or_pending_data';END IF;
END $$;
DROP TRIGGER competition_study_accept ON public.study_sessions;
DROP TRIGGER competition_exam_accept ON public.exam_attempts;
DROP TRIGGER competition_target_change ON public.profiles;
DROP TRIGGER competition_delete_identity ON public.profiles;
DO $$ DECLARE r record;j jsonb;BEGIN
 FOR r IN SELECT * FROM public.competition_install_backup LOOP EXECUTE r.definition;END LOOP;
 FOR j IN SELECT value FROM public.competition_policy p CROSS JOIN LATERAL jsonb_array_elements(p.legacy_snapshot->'cron') LOOP
  PERFORM cron.schedule(j->>'jobname',j->>'schedule',j->>'command');
 END LOOP;
END $$;
DROP FUNCTION public.get_monthly_league_ranking(text,text),public.get_my_exam_league_ranking(text),public.get_public_monthly_competition(integer),public.get_competition_target(),public.set_competition_target(text),public.process_monthly_competitions(),public._competition_finalize_legacy(),public._competition_purge_deleted_identity(),public._competition_repack_current(),public._competition_legacy_ensure_user_in_league(uuid,integer),public._competition_legacy_weekly(),public._competition_study_event(),public._competition_exam_event(),public._competition_record(text,uuid,uuid,timestamptz,timestamptz,integer,integer),public._competition_place(uuid,text,date,timestamptz),public._competition_room_rows(uuid),public._competition_track_target(),public._competition_segment(uuid,date);
DROP TABLE public.competition_results,public.competition_events,public.competition_memberships,public.competition_rooms,public.competition_profiles,public.competition_target_history,public.competition_periods,public.competition_avatar_rewards,public.competition_policy,public.competition_install_backup;
DROP FUNCTION public._competition_month_time(date),public._competition_month(timestamptz);
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261028030000' AND name='monthly_competitions';
NOTIFY pgrst,'reload schema';
COMMIT;
