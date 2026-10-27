-- HAZIRLANDI; CANLIYA UYGULANMADI. 150000 -> 160000 -> bu paket.
-- Normal complete_study_session gövdesi/ekonomisi korunur. Canlıda kullanıcı
-- SQL Editor'de önce DRYRUN, sonra migration çalıştırır; CLI push kullanmayın.
-- Server-owned 300sn mola +60sn Buradayım penceresi. Auth istemcisi tarih,
-- pencere veya onay tablosu yazamaz; onay bir sonraki UUID'ye bir kez bağlanır.
BEGIN;
DO $pre$
BEGIN
 IF md5(pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure)) IS DISTINCT FROM 'f0f2b9bcc09ae8440a66d889b5f22fcc'
 OR md5(pg_get_functiondef('public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)'::regprocedure)) IS DISTINCT FROM '6925319a991d7435135efd92551fcc44'
 OR md5(pg_get_functiondef('public.get_marathon_config()'::regprocedure)) IS DISTINCT FROM 'd0e6843ba297e7c9474a3f1481144260'
 OR to_regclass('public.marathon_presence_gates') IS NOT NULL
 OR to_regclass('public.marathon_presence_settings') IS NOT NULL THEN
  RAISE EXCEPTION 'marathon_presence_confirmation ön koşulu değişmiş; güncel tanımdan yeniden hazırlayın.';
 END IF;
END $pre$;

CREATE TABLE public.marathon_presence_settings (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 break_seconds integer NOT NULL DEFAULT 300 CHECK(break_seconds BETWEEN 1 AND 300),
 presence_seconds integer NOT NULL DEFAULT 60 CHECK(presence_seconds BETWEEN 1 AND 60)
);
INSERT INTO public.marathon_presence_settings DEFAULT VALUES;
COMMENT ON TABLE public.marathon_presence_settings IS 'Owner-only duration config. Production defaults 300/60; shorter values exclusively local Docker QA helper.';
CREATE TABLE public.marathon_presence_gates (
 user_id uuid NOT NULL,
 marathon_uuid uuid NOT NULL,
 next_session_index integer NOT NULL CHECK(next_session_index BETWEEN 2 AND 4),
 previous_client_uuid uuid NOT NULL,
 break_started_at timestamptz NOT NULL,
 break_ends_at timestamptz NOT NULL,
 confirmation_deadline timestamptz NOT NULL,
 confirmed_at timestamptz,
 next_client_uuid uuid,
 PRIMARY KEY(user_id,marathon_uuid,next_session_index),
 UNIQUE(user_id,next_client_uuid),
 FOREIGN KEY(user_id,marathon_uuid) REFERENCES public.marathon_runs(user_id,client_uuid) ON DELETE CASCADE,
 CHECK(break_started_at<break_ends_at AND break_ends_at<confirmation_deadline),
 CHECK((confirmed_at IS NULL)=(next_client_uuid IS NULL)),
 CHECK(confirmed_at IS NULL OR (confirmed_at>=break_ends_at AND confirmed_at<confirmation_deadline))
);
ALTER TABLE public.marathon_presence_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marathon_presence_gates ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.marathon_presence_settings,public.marathon_presence_gates FROM PUBLIC,anon,authenticated,service_role;

-- Preserve the tested reward implementation privately; clients cannot bypass
-- the gate by invoking it. The normal RPC remains separately unchanged.
ALTER FUNCTION public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)
 RENAME TO _complete_marathon_study_session_before_presence;
REVOKE ALL ON FUNCTION public._complete_marathon_study_session_before_presence(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION public.get_marathon_config()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
 SELECT jsonb_build_object('available',true,'break_seconds',300,
  'presence_required',true,'presence_seconds',60,'presence_start_grace_seconds',10,
  'bonuses',jsonb_build_object(
   '25',jsonb_build_object('2',public.marathon_bonus_for(25,2),'3',public.marathon_bonus_for(25,3),'4',public.marathon_bonus_for(25,4)),
   '50',jsonb_build_object('2',public.marathon_bonus_for(50,2),'3',public.marathon_bonus_for(50,3),'4',public.marathon_bonus_for(50,4))))
 FROM public.marathon_presence_settings s WHERE singleton;
$function$;

CREATE FUNCTION public.start_marathon_break(p_marathon_uuid uuid,p_completed_session_index integer,p_previous_client_uuid uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_uid uuid:=auth.uid();v_gate public.marathon_presence_gates%ROWTYPE;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 IF p_marathon_uuid IS NULL OR p_previous_client_uuid IS NULL OR p_completed_session_index IS NULL
  OR p_completed_session_index NOT BETWEEN 1 AND 3 THEN RAISE EXCEPTION 'marathon_presence_invalid_metadata'; END IF;
 SELECT * INTO v_gate FROM public.marathon_presence_gates
 WHERE user_id=v_uid AND marathon_uuid=p_marathon_uuid AND next_session_index=p_completed_session_index+1
  AND previous_client_uuid=p_previous_client_uuid;
 IF NOT FOUND THEN RAISE EXCEPTION 'marathon_presence_missing_previous'; END IF;
 -- Fetch only. A delayed, repeated or replayed read never opens a new window.
 RETURN jsonb_build_object('break_ends_at',v_gate.break_ends_at,'confirmation_deadline',v_gate.confirmation_deadline,
  'confirmed',v_gate.confirmed_at IS NOT NULL,'confirmed_at',v_gate.confirmed_at,'next_client_uuid',v_gate.next_client_uuid);
END;
$function$;

CREATE FUNCTION public.confirm_marathon_presence(p_marathon_uuid uuid,p_next_session_index integer,p_next_client_uuid uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE v_uid uuid:=auth.uid();v_gate public.marathon_presence_gates%ROWTYPE;v_now timestamptz;v_run public.marathon_runs%ROWTYPE;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 IF p_marathon_uuid IS NULL OR p_next_client_uuid IS NULL OR p_next_session_index IS NULL
  OR p_next_session_index NOT BETWEEN 2 AND 4 THEN RAISE EXCEPTION 'marathon_presence_invalid_metadata'; END IF;
 PERFORM 1 FROM public.profiles WHERE id=v_uid FOR UPDATE;
 SELECT * INTO v_run FROM public.marathon_runs WHERE user_id=v_uid AND client_uuid=p_marathon_uuid;
 IF NOT FOUND OR v_run.is_invalid OR p_next_session_index>v_run.target_sessions THEN
  RAISE EXCEPTION 'marathon_presence_missing_previous';
 END IF;
 IF (SELECT count(*) FROM public.marathon_run_sessions WHERE user_id=v_uid AND marathon_uuid=p_marathon_uuid
  AND session_index<p_next_session_index)<>p_next_session_index-1 THEN RAISE EXCEPTION 'marathon_presence_missing_previous'; END IF;
 SELECT * INTO v_gate FROM public.marathon_presence_gates
  WHERE user_id=v_uid AND marathon_uuid=p_marathon_uuid AND next_session_index=p_next_session_index FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'marathon_presence_missing_previous'; END IF;
 IF v_gate.confirmed_at IS NOT NULL THEN
  IF v_gate.next_client_uuid<>p_next_client_uuid THEN RAISE EXCEPTION 'marathon_presence_conflict'; END IF;
  -- Lost response retry returns the original receipt; no date/UUID changes.
  RETURN jsonb_build_object('confirmed',true,'confirmed_at',v_gate.confirmed_at,'next_client_uuid',v_gate.next_client_uuid,
   'break_ends_at',v_gate.break_ends_at,'confirmation_deadline',v_gate.confirmation_deadline);
 END IF;
 v_now:=clock_timestamp();
 IF v_now<v_gate.break_ends_at THEN RAISE EXCEPTION 'marathon_presence_too_early'; END IF;
 IF v_now>=v_gate.confirmation_deadline THEN RAISE EXCEPTION 'marathon_presence_expired'; END IF;
 IF EXISTS(SELECT 1 FROM public.study_sessions WHERE user_id=v_uid AND client_uuid=p_next_client_uuid)
  OR EXISTS(SELECT 1 FROM public.marathon_presence_gates WHERE user_id=v_uid AND next_client_uuid=p_next_client_uuid)
  THEN RAISE EXCEPTION 'marathon_presence_conflict'; END IF;
 UPDATE public.marathon_presence_gates SET confirmed_at=v_now,next_client_uuid=p_next_client_uuid
  WHERE user_id=v_uid AND marathon_uuid=p_marathon_uuid AND next_session_index=p_next_session_index;
 RETURN jsonb_build_object('confirmed',true,'confirmed_at',v_now,'next_client_uuid',p_next_client_uuid,
  'break_ends_at',v_gate.break_ends_at,'confirmation_deadline',v_gate.confirmation_deadline);
END;
$function$;

CREATE FUNCTION public.complete_marathon_study_session(
 p_client_uuid uuid,p_category_id uuid,p_duration_minutes integer,
 p_was_paused boolean,p_is_verified integer,p_started_at timestamptz,
 p_marathon_uuid uuid,p_target_sessions integer,p_session_index integer
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
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
  v_now:=clock_timestamp();
  INSERT INTO public.marathon_presence_gates(user_id,marathon_uuid,next_session_index,previous_client_uuid,break_started_at,break_ends_at,confirmation_deadline)
   VALUES(v_uid,p_marathon_uuid,p_session_index+1,p_client_uuid,v_now,v_now+make_interval(secs=>v_break),v_now+make_interval(secs=>v_break+v_presence))
   ON CONFLICT(user_id,marathon_uuid,next_session_index) DO NOTHING;
  SELECT * INTO STRICT v_gate FROM public.marathon_presence_gates WHERE user_id=v_uid AND marathon_uuid=p_marathon_uuid AND next_session_index=p_session_index+1;
  v_result:=v_result||jsonb_build_object('marathon_break_ends_at',v_gate.break_ends_at,'marathon_confirmation_deadline',v_gate.confirmation_deadline);
 END IF;
 UPDATE public.marathon_run_sessions SET result_json=v_result WHERE user_id=v_uid AND client_uuid=p_client_uuid;
 RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.start_marathon_break(uuid,integer,uuid),public.confirm_marathon_presence(uuid,integer,uuid),
 public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.start_marathon_break(uuid,integer,uuid),public.confirm_marathon_presence(uuid,integer,uuid),
 public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer) TO authenticated,service_role;
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261007170000','marathon_presence_confirmation') ON CONFLICT(version) DO NOTHING;
COMMIT;
