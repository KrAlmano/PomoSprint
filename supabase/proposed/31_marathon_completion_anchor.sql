-- PROPOSED ONLY: unpaused Marathon anchor; paused legacy AFK limitation remains.
-- No normal completion/award formula change. Existing gates are not rewritten.
\echo 'Öneri31: README ve DRYRUN incelenmeden çalıştırmayın.'
\quit
BEGIN;
DO $$ BEGIN
 IF to_regclass('public.marathon_presence_gates') IS NULL THEN RAISE EXCEPTION 'marathon_anchor_requires_presence'; END IF;
 IF EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261028050000') THEN RAISE EXCEPTION 'marathon_anchor_already_applied'; END IF;
 IF md5(pg_get_functiondef('public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)'::regprocedure))<>'177a238a9aa8a4ffd3738b2865120568' THEN RAISE EXCEPTION 'marathon_anchor_precondition_changed'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.complete_marathon_study_session(p_client_uuid uuid, p_category_id uuid, p_duration_minutes integer, p_was_paused boolean, p_is_verified integer, p_started_at timestamp with time zone, p_marathon_uuid uuid, p_target_sessions integer, p_session_index integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
 v_uid uuid:=auth.uid();v_run public.marathon_runs%ROWTYPE;v_mapped public.marathon_run_sessions%ROWTYPE;
 v_gate public.marathon_presence_gates%ROWTYPE;v_result jsonb;v_invalid boolean:=false;
 v_count integer;v_session_id uuid;v_now timestamptz;v_break integer;v_presence integer;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 IF p_client_uuid IS NULL OR p_marathon_uuid IS NULL OR p_target_sessions IS NULL OR p_target_sessions NOT IN(2,3,4)
  OR p_session_index IS NULL OR p_session_index<1 OR p_session_index>p_target_sessions
  OR p_duration_minutes IS NULL OR p_duration_minutes NOT IN(25,50) THEN RAISE EXCEPTION 'invalid_marathon_metadata'; END IF;
 PERFORM 1 FROM public.profiles WHERE id=v_uid FOR UPDATE;
 SELECT * INTO v_mapped FROM public.marathon_run_sessions WHERE user_id=v_uid AND client_uuid=p_client_uuid;
 IF FOUND THEN
  IF v_mapped.marathon_uuid<>p_marathon_uuid OR v_mapped.session_index<>p_session_index
   OR NOT EXISTS(SELECT 1 FROM public.marathon_runs WHERE user_id=v_uid AND client_uuid=p_marathon_uuid
    AND target_sessions=p_target_sessions AND duration_minutes=p_duration_minutes) THEN RAISE EXCEPTION 'marathon_session_reused'; END IF;
  RETURN v_mapped.result_json||jsonb_build_object('duplicate',true,'coins_earned',0,
   'streak',(SELECT current_streak FROM public.profiles WHERE id=v_uid));
 END IF;
 IF EXISTS(SELECT 1 FROM public.study_sessions WHERE user_id=v_uid AND client_uuid=p_client_uuid) THEN RAISE EXCEPTION 'marathon_session_reused'; END IF;
 SELECT * INTO v_run FROM public.marathon_runs WHERE user_id=v_uid AND client_uuid=p_marathon_uuid;
 IF FOUND AND (v_run.target_sessions<>p_target_sessions OR v_run.duration_minutes<>p_duration_minutes) THEN RAISE EXCEPTION 'marathon_metadata_conflict'; END IF;
 IF EXISTS(SELECT 1 FROM public.marathon_run_sessions WHERE user_id=v_uid AND marathon_uuid=p_marathon_uuid AND session_index=p_session_index) THEN
  RAISE EXCEPTION 'marathon_index_conflict'; END IF;
 v_invalid:=COALESCE(v_run.is_invalid,false);
 IF p_session_index>1 THEN
  SELECT * INTO v_gate FROM public.marathon_presence_gates WHERE user_id=v_uid AND marathon_uuid=p_marathon_uuid AND next_session_index=p_session_index;
  v_invalid:=v_invalid OR NOT FOUND OR v_gate.confirmed_at IS NULL OR v_gate.next_client_uuid IS DISTINCT FROM p_client_uuid
   OR p_started_at IS NULL OR p_started_at<v_gate.confirmed_at-interval '2 seconds' OR p_started_at>v_gate.confirmed_at+interval '10 seconds'
   OR (SELECT count(*) FROM public.marathon_run_sessions WHERE user_id=v_uid AND marathon_uuid=p_marathon_uuid AND session_index<p_session_index)<>p_session_index-1;
 END IF;
 IF NOT v_invalid THEN
  v_result:=public._complete_marathon_study_session_before_presence(p_client_uuid,p_category_id,p_duration_minutes,p_was_paused,p_is_verified,p_started_at,p_marathon_uuid,p_target_sessions,p_session_index);
 ELSE
  -- Completed individual study is never thrown away for a missing check-in.
  -- Normal duration/category/clock/overlap/daily-cap controls remain in force.
  v_result:=public.complete_study_session(p_client_uuid,p_category_id,p_duration_minutes,p_was_paused,p_is_verified,p_started_at);
  IF v_result ? 'error' THEN RETURN v_result; END IF;
  SELECT id INTO STRICT v_session_id FROM public.study_sessions WHERE user_id=v_uid AND client_uuid=p_client_uuid;
  INSERT INTO public.marathon_runs(user_id,client_uuid,target_sessions,duration_minutes,is_invalid)
   VALUES(v_uid,p_marathon_uuid,p_target_sessions,p_duration_minutes,true) ON CONFLICT(user_id,client_uuid) DO UPDATE SET is_invalid=true;
  INSERT INTO public.marathon_run_sessions(user_id,marathon_uuid,session_index,client_uuid,study_session_id,result_json)
   VALUES(v_uid,p_marathon_uuid,p_session_index,p_client_uuid,v_session_id,v_result);
  SELECT count(*) INTO v_count FROM public.marathon_run_sessions WHERE user_id=v_uid AND marathon_uuid=p_marathon_uuid;
  v_result:=v_result||jsonb_build_object('marathon_bonus_points',0,'marathon_completed',v_count=p_target_sessions,
   'marathon_target_sessions',p_target_sessions,'marathon_completed_sessions',v_count,'marathon_invalid',true,'marathon_presence_invalid',true);
 END IF;
 IF v_result ? 'error' THEN RETURN v_result; END IF;
 IF NOT COALESCE((v_result->>'marathon_invalid')::boolean,false) AND p_session_index<p_target_sessions THEN
  SELECT break_seconds,presence_seconds INTO STRICT v_break,v_presence FROM public.marathon_presence_settings WHERE singleton;
  -- proposed/31: Unpaused focus uses the accepted row's end, never receipt
  -- time. A late upload cannot mint a fresh 300+60-second AFK window.
  -- Paused focus remains on the legacy receipt-time contract: this 9-argument
  -- RPC has no server-owned pause ledger. Do not invalidate legitimate pauses
  -- or claim full paused-AFK enforcement; see 31 README's explicit limitation.
  IF p_was_paused THEN
   v_now:=clock_timestamp();
  ELSE
   SELECT completed_at INTO STRICT v_now FROM public.study_sessions
    WHERE user_id=v_uid AND client_uuid=p_client_uuid;
  END IF;
  IF NOT COALESCE(p_was_paused,false)
     AND clock_timestamp()>=v_now+make_interval(secs=>v_break+v_presence) THEN
   -- Normal completion and its rewards have already been accepted. Do not
   -- raise/roll them back. Only this incomplete Marathon loses bonus eligibility.
   UPDATE public.marathon_runs SET is_invalid=true
    WHERE user_id=v_uid AND client_uuid=p_marathon_uuid;
   v_result:=v_result||jsonb_build_object('marathon_invalid',true,
    'marathon_presence_invalid',true,'marathon_bonus_points',0);
  ELSE
   INSERT INTO public.marathon_presence_gates(user_id,marathon_uuid,next_session_index,previous_client_uuid,break_started_at,break_ends_at,confirmation_deadline)
    VALUES(v_uid,p_marathon_uuid,p_session_index+1,p_client_uuid,v_now,v_now+make_interval(secs=>v_break),v_now+make_interval(secs=>v_break+v_presence))
    ON CONFLICT(user_id,marathon_uuid,next_session_index) DO NOTHING;
   SELECT * INTO STRICT v_gate FROM public.marathon_presence_gates WHERE user_id=v_uid AND marathon_uuid=p_marathon_uuid AND next_session_index=p_session_index+1;
   v_result:=v_result||jsonb_build_object('marathon_break_ends_at',v_gate.break_ends_at,'marathon_confirmation_deadline',v_gate.confirmation_deadline);
  END IF;
 END IF;
 UPDATE public.marathon_run_sessions SET result_json=v_result WHERE user_id=v_uid AND client_uuid=p_client_uuid;
 RETURN v_result;
END;
$function$;
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261028050000','marathon_completion_anchor');
COMMIT;
