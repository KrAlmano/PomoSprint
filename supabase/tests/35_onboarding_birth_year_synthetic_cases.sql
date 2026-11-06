-- Only the isolated synthetic cluster created by the companion Python harness.
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
DO $$
DECLARE n integer;
BEGIN
  BEGIN
    UPDATE public.profiles SET birth_year=NULL, onboarding_completed_at=now() WHERE id='00000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'new_null_completion_was_accepted';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM <> 'birth_year_required' THEN RAISE; END IF;
  END;
  BEGIN
    UPDATE public.profiles SET birth_year=extract(year FROM (now() AT TIME ZONE 'Pacific/Kiritimati'))::int-12, onboarding_completed_at=now() WHERE id='00000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'underage_completion_was_accepted';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM <> 'birth_year_under_minimum_age' THEN RAISE; END IF;
  END;
  UPDATE public.profiles SET birth_year=extract(year FROM (now() AT TIME ZONE 'Pacific/Kiritimati'))::int-13, onboarding_completed_at=now() WHERE id='00000000-0000-0000-0000-000000000001';
  GET DIAGNOSTICS n=ROW_COUNT;
  IF n<>1 THEN RAISE EXCEPTION 'minimum_age_completion_rejected'; END IF;
  BEGIN
    UPDATE public.profiles SET birth_year=NULL WHERE id='00000000-0000-0000-0000-000000000001';
    RAISE EXCEPTION 'completed_user_cleared_year';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM <> 'birth_year_required' THEN RAISE; END IF;
  END;
  UPDATE public.profiles SET name='Must not change' WHERE id='00000000-0000-0000-0000-000000000002';
  GET DIAGNOSTICS n=ROW_COUNT;
  IF n<>0 THEN RAISE EXCEPTION 'cross_account_update'; END IF;
END $$;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
DO $$
DECLARE n integer;
BEGIN
  UPDATE public.profiles SET name='Legacy updated' WHERE id='00000000-0000-0000-0000-000000000002';
  GET DIAGNOSTICS n=ROW_COUNT;
  IF n<>1 THEN RAISE EXCEPTION 'legacy_unrelated_update_blocked'; END IF;
  UPDATE public.profiles SET birth_year=NULL WHERE id='00000000-0000-0000-0000-000000000002';
  GET DIAGNOSTICS n=ROW_COUNT;
  IF n<>1 THEN RAISE EXCEPTION 'legacy_noop_update_blocked'; END IF;
  BEGIN
    UPDATE public.profiles SET onboarding_completed_at=now() WHERE id='00000000-0000-0000-0000-000000000002';
    RAISE EXCEPTION 'legacy_null_completion_time_changed';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM <> 'birth_year_required' THEN RAISE; END IF;
  END;
  UPDATE public.profiles SET birth_year=2000 WHERE id='00000000-0000-0000-0000-000000000002';
  GET DIAGNOSTICS n=ROW_COUNT;
  IF n<>1 THEN RAISE EXCEPTION 'legacy_year_repair_rejected'; END IF;
END $$;
RESET ROLE;
DO $$
BEGIN
  BEGIN
    INSERT INTO public.profiles(id,birth_year,onboarding_completed_at) VALUES('00000000-0000-0000-0000-000000000004',NULL,now());
    RAISE EXCEPTION 'new_insert_null_was_accepted';
  EXCEPTION WHEN check_violation THEN
    IF SQLERRM <> 'birth_year_required' THEN RAISE; END IF;
  END;
END $$;
SELECT '10 meaningful synthetic age/RLS cases passed' AS result;
