-- 700 DRYRUN: önce150000/160000 kurulu,700 henüz yok. Herkontroltrue; bilinçli exception rollback.
-- BEGIN MIGRATION BODY
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
-- END MIGRATION BODY
CREATE TEMP TABLE presence_checks(seq serial,name text,ok boolean);
CREATE FUNCTION pg_temp.check_presence(p_name text,p_ok boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN INSERT INTO presence_checks(name,ok) VALUES(p_name,coalesce(p_ok,false)); END $$;
CREATE FUNCTION pg_temp.new_presence_user() RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE u uuid:=gen_random_uuid();
BEGIN
 INSERT INTO auth.users(id,email,aud,role,raw_user_meta_data) VALUES(u,'presence-'||u||'@example.invalid','authenticated','authenticated',jsonb_build_object('name','Presence QA'));
 UPDATE public.profiles SET timezone='UTC',coins=0,lifetime_points=0,total_minutes=0,show_in_social_feed=false WHERE id=u;
 INSERT INTO public.categories(user_id,name,color_hex,icon_name) VALUES(u,'Presence QA','#123456','school');
 RETURN u;
END $$;
CREATE FUNCTION pg_temp.submit_presence(u uuid,run uuid,dur integer,target integer,idx integer,client uuid,started timestamptz,paused boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE r jsonb;c uuid;
BEGIN
 SELECT id INTO c FROM public.categories WHERE user_id=u ORDER BY created_at LIMIT 1;
 PERFORM set_config('request.jwt.claims',json_build_object('sub',u,'role','authenticated')::text,true);
 SET LOCAL ROLE authenticated;
 r:=public.complete_marathon_study_session(client,c,dur,paused,dur*60,started,run,target,idx);
 RESET ROLE;
 RETURN r;
END $$;
CREATE FUNCTION pg_temp.confirm_presence(u uuid,run uuid,idx integer,client uuid) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE r jsonb;
BEGIN
 PERFORM set_config('request.jwt.claims',json_build_object('sub',u,'role','authenticated')::text,true);
 SET LOCAL ROLE authenticated;
 r:=public.confirm_marathon_presence(run,idx,client);
 RESET ROLE;
 RETURN r;
END $$;
CREATE FUNCTION pg_temp.fetch_presence(u uuid,run uuid,idx integer,client uuid) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE r jsonb;
BEGIN
 PERFORM set_config('request.jwt.claims',json_build_object('sub',u,'role','authenticated')::text,true);
 SET LOCAL ROLE authenticated;
 r:=public.start_marathon_break(run,idx,client);
 RESET ROLE;
 RETURN r;
END $$;
CREATE FUNCTION pg_temp.confirm_error(u uuid,run uuid,idx integer,client uuid,wanted text) RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN PERFORM pg_temp.confirm_presence(u,run,idx,client); RETURN false;
EXCEPTION WHEN raise_exception THEN RETURN SQLERRM=wanted; END $$;
CREATE FUNCTION pg_temp.fetch_error(u uuid,run uuid,idx integer,client uuid,wanted text) RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN PERFORM pg_temp.fetch_presence(u,run,idx,client); RETURN false;
EXCEPTION WHEN raise_exception THEN RETURN SQLERRM=wanted; END $$;
-- Owner-only historical receipts shorten no production window. They let a
-- rollback fixture exercise reward math without waiting25/50min per focus.
-- Real confirmation boundary/clock/replay tests below use actual RPC clock.
CREATE FUNCTION pg_temp.historical_receipt(u uuid,run uuid,idx integer,client uuid,t timestamptz) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
 UPDATE public.marathon_presence_gates SET break_started_at=t-interval '301 seconds',break_ends_at=t-interval '1 second',
  confirmation_deadline=t+interval '59 seconds',confirmed_at=t,next_client_uuid=client
 WHERE user_id=u AND marathon_uuid=run AND next_session_index=idx;
 IF NOT FOUND THEN RAISE EXCEPTION 'fixture gate missing'; END IF;
END $$;

DO $matrix$
DECLARE dur integer;target integer;i integer;u uuid;run uuid;client uuid;r jsonb;start_at timestamptz;normal integer;extra integer;before_points integer;
BEGIN
 FOREACH dur IN ARRAY ARRAY[25,50] LOOP
  FOREACH target IN ARRAY ARRAY[2,3,4] LOOP
   u:=pg_temp.new_presence_user();run:=gen_random_uuid();normal:=0;
   start_at:=now()-make_interval(mins=>target*(dur+6)+60);
   FOR i IN 1..target LOOP
    client:=gen_random_uuid();
    IF i>1 THEN PERFORM pg_temp.historical_receipt(u,run,i,client,start_at); END IF;
    r:=pg_temp.submit_presence(u,run,dur,target,i,client,start_at);
    normal:=normal+(r->>'total_points')::integer-(r->>'marathon_bonus_points')::integer;
    PERFORM pg_temp.check_presence('Matrix '||dur||'x'||target||' index'||i||' bonus only full confirmed plan',
     (r->>'marathon_bonus_points')::integer=CASE WHEN i=target THEN public.marathon_bonus_for(dur,target) ELSE 0 END
     AND NOT (r->>'marathon_invalid')::boolean);
    IF i<target THEN
     PERFORM pg_temp.check_presence('Matrix '||dur||'x'||target||' index'||i||' opens exactly one ticket',
      r ? 'marathon_break_ends_at' AND r ? 'marathon_confirmation_deadline'
      AND (SELECT count(*)=i FROM public.marathon_presence_gates WHERE user_id=u));
    END IF;
    start_at:=start_at+make_interval(mins=>dur+5);
   END LOOP;
   extra:=public.marathon_bonus_for(dur,target);
   PERFORM pg_temp.check_presence('Matrix '||dur||'x'||target||' profile/report/league totals agree',
    (SELECT lifetime_points=normal+extra AND coins=20*target AND total_minutes=dur*target FROM public.profiles WHERE id=u)
    AND (SELECT sum(base_points+bonus_points)=normal+extra AND count(*)=target FROM public.study_sessions WHERE user_id=u)
    AND (SELECT sum(weekly_points+carry_points)=normal+extra FROM public.league_memberships WHERE user_id=u));
   SELECT lifetime_points INTO before_points FROM public.profiles WHERE id=u;
   r:=pg_temp.submit_presence(u,run,dur,target,target,client,start_at-make_interval(mins=>dur+5));
   PERFORM pg_temp.check_presence('Matrix '||dur||'x'||target||' duplicate never reawards',
    (r->>'duplicate')::boolean AND (r->>'coins_earned')::integer=0
    AND (SELECT lifetime_points=before_points FROM public.profiles WHERE id=u)
    AND (SELECT count(*)=target FROM public.study_sessions WHERE user_id=u));
  END LOOP;
 END LOOP;
END $matrix$;

DO $clock$
DECLARE u uuid:=pg_temp.new_presence_user();other_u uuid:=pg_temp.new_presence_user();run uuid:=gen_random_uuid();
 first_client uuid:=gen_random_uuid();next_client uuid:=gen_random_uuid();r jsonb;ticket jsonb;repeat_ticket jsonb;receipt jsonb;original_confirmation timestamptz;
BEGIN
 r:=pg_temp.submit_presence(u,run,25,3,1,first_client,now()-interval '3 hours');
 ticket:=pg_temp.fetch_presence(u,run,1,first_client);
 repeat_ticket:=pg_temp.fetch_presence(u,run,1,first_client);
 PERFORM pg_temp.check_presence('Default ticket is300sec break plus60sec confirmation',
  (SELECT break_ends_at-break_started_at=interval '300 seconds' AND confirmation_deadline-break_ends_at=interval '60 seconds'
   FROM public.marathon_presence_gates WHERE user_id=u AND marathon_uuid=run));
 PERFORM pg_temp.check_presence('Fetch never resets or extends ticket',ticket=repeat_ticket
  AND (ticket->>'break_ends_at')::timestamptz=(r->>'marathon_break_ends_at')::timestamptz);
 PERFORM pg_temp.check_presence('Confirmation before break end fails',pg_temp.confirm_error(u,run,2,next_client,'marathon_presence_too_early'));
 PERFORM pg_temp.check_presence('Cannot confirm future index before previous focus',pg_temp.confirm_error(u,run,3,gen_random_uuid(),'marathon_presence_missing_previous'));
 PERFORM pg_temp.check_presence('Different account cannot fetch ticket',pg_temp.fetch_error(other_u,run,1,first_client,'marathon_presence_missing_previous'));
 PERFORM pg_temp.check_presence('Different account cannot confirm ticket',pg_temp.confirm_error(other_u,run,2,next_client,'marathon_presence_missing_previous'));
 PERFORM pg_temp.check_presence('Wrong previous UUID cannot fetch ticket',pg_temp.fetch_error(u,run,1,gen_random_uuid(),'marathon_presence_missing_previous'));
 PERFORM pg_temp.check_presence('Invalid checkin index fails',pg_temp.confirm_error(u,run,1,next_client,'marathon_presence_invalid_metadata'));
 UPDATE public.marathon_presence_gates SET break_started_at=clock_timestamp()-interval '301 seconds',
  break_ends_at=clock_timestamp()-interval '1 second',confirmation_deadline=clock_timestamp()+interval '59 seconds'
  WHERE user_id=u AND marathon_uuid=run;
 receipt:=pg_temp.confirm_presence(u,run,2,next_client);
 original_confirmation:=(receipt->>'confirmed_at')::timestamptz;
 PERFORM pg_temp.check_presence('Real server-clock confirmation returns bound receipt',
  (receipt->>'confirmed')::boolean AND receipt->>'next_client_uuid'=next_client::text
  AND original_confirmation<=clock_timestamp() AND original_confirmation>clock_timestamp()-interval '5 seconds');
 PERFORM pg_temp.check_presence('Repeated sameUUID returns original receipt',receipt=pg_temp.confirm_presence(u,run,2,next_client));
 PERFORM pg_temp.check_presence('OtherUUID cannot replace confirmed focus',pg_temp.confirm_error(u,run,2,gen_random_uuid(),'marathon_presence_conflict'));
 -- Privileged fixture moves existing receipt into past to exercise lost-response
 -- retry after deadline: receipt remains original for that ticket, never reopened.
 PERFORM pg_temp.historical_receipt(u,run,2,next_client,clock_timestamp()-interval '2 minutes');
 receipt:=pg_temp.confirm_presence(u,run,2,next_client);
 PERFORM pg_temp.check_presence('Late retry returns same historical receipt without extending deadline',
  (receipt->>'confirmation_deadline')::timestamptz<clock_timestamp()
  AND (receipt->>'confirmed_at')::timestamptz<clock_timestamp()-interval '1 minute');
END $clock$;

DO $expired$
DECLARE u uuid:=pg_temp.new_presence_user();run uuid:=gen_random_uuid();client uuid:=gen_random_uuid();r jsonb;t timestamptz;
BEGIN
 r:=pg_temp.submit_presence(u,run,25,2,1,client,now()-interval '3 hours');
 UPDATE public.marathon_presence_gates SET break_started_at=clock_timestamp()-interval '361 seconds',
  break_ends_at=clock_timestamp()-interval '61 seconds',confirmation_deadline=clock_timestamp()-interval '1 second'
  WHERE user_id=u AND marathon_uuid=run;
 PERFORM pg_temp.check_presence('Unconfirmed after deadline fails closed',pg_temp.confirm_error(u,run,2,gen_random_uuid(),'marathon_presence_expired'));
 SELECT confirmation_deadline INTO t FROM public.marathon_presence_gates WHERE user_id=u AND marathon_uuid=run;
 PERFORM pg_temp.fetch_presence(u,run,1,client);
 PERFORM pg_temp.check_presence('Expired fetch keeps original deadline',(SELECT confirmation_deadline=t AND confirmed_at IS NULL FROM public.marathon_presence_gates WHERE user_id=u AND marathon_uuid=run));
 PERFORM pg_temp.check_presence('Expired plan keeps previous completed focus',(SELECT count(*)=1 AND sum(duration_minutes)=25 FROM public.study_sessions WHERE user_id=u)
  AND (SELECT lifetime_points=5 AND coins=20 FROM public.profiles WHERE id=u));
END $expired$;

DO $invalid$
DECLARE u uuid;run uuid;first_client uuid;next_client uuid;r jsonb;t timestamptz:=now()-interval '3 hours';i integer;why text;
BEGIN
 FOREACH why IN ARRAY ARRAY['missing','wrong_uuid','late_start','early_start'] LOOP
  u:=pg_temp.new_presence_user();run:=gen_random_uuid();first_client:=gen_random_uuid();next_client:=gen_random_uuid();
  r:=pg_temp.submit_presence(u,run,25,3,1,first_client,t);
  IF why<>'missing' THEN
   PERFORM pg_temp.historical_receipt(u,run,2,CASE WHEN why='wrong_uuid' THEN gen_random_uuid() ELSE next_client END,
    CASE WHEN why='late_start' THEN t+interval '30 minutes'-interval '11 seconds'
         WHEN why='early_start' THEN t+interval '30 minutes'+interval '3 seconds' ELSE t+interval '30 minutes' END);
  END IF;
  r:=pg_temp.submit_presence(u,run,25,3,2,next_client,t+interval '30 minutes');
  PERFORM pg_temp.check_presence(why||' checkin preserves individual focus and invalidates bonus',
   (r->>'marathon_presence_invalid')::boolean AND (r->>'marathon_invalid')::boolean AND (r->>'marathon_bonus_points')::integer=0
   AND (SELECT count(*)=2 FROM public.study_sessions WHERE user_id=u)
   AND (SELECT lifetime_points=10 AND coins=40 AND total_minutes=50 FROM public.profiles WHERE id=u));
  r:=pg_temp.submit_presence(u,run,25,3,3,gen_random_uuid(),t+interval '60 minutes');
  PERFORM pg_temp.check_presence(why||' invalid plan cannot recover bonus with later focus',
   (r->>'marathon_presence_invalid')::boolean AND (r->>'marathon_completed')::boolean AND (r->>'marathon_bonus_points')::integer=0
   AND (SELECT lifetime_points=15 AND coins=60 AND total_minutes=75 FROM public.profiles WHERE id=u)
   AND (SELECT is_invalid AND bonus_awarded=0 FROM public.marathon_runs WHERE user_id=u AND client_uuid=run));
 END LOOP;
END $invalid$;

DO $limits$
DECLARE u uuid:=pg_temp.new_presence_user();run uuid:=gen_random_uuid();client uuid:=gen_random_uuid();c uuid;t timestamptz;day_start timestamptz;r jsonb;i integer;
BEGIN
 day_start:=date_trunc('day',now()-interval '4 hours')+interval '4 hours';
 IF now()-day_start<interval '8 hours' THEN t:=day_start-interval '1 day'+interval '16 hours'; ELSE t:=day_start; END IF;
 SELECT id INTO c FROM public.categories WHERE user_id=u LIMIT 1;
 FOR i IN 0..15 LOOP
  INSERT INTO public.study_sessions(user_id,category_id,category,duration_minutes,base_points,bonus_points,client_uuid,started_at,completed_at,start_verified)
  VALUES(u,c,'Presence QA',25,5,0,gen_random_uuid(),t+make_interval(mins=>i*25),t+make_interval(mins=>(i+1)*25),true);
 END LOOP;
 r:=pg_temp.submit_presence(u,run,25,2,1,gen_random_uuid(),t+interval '400 minutes');
 PERFORM pg_temp.historical_receipt(u,run,2,client,t+interval '430 minutes');
 r:=pg_temp.submit_presence(u,run,25,2,2,client,t+interval '430 minutes');
 PERFORM pg_temp.check_presence('Confirmed complete daily-capped set gives no marathon bonus',
  (r->>'daily_limit_reached')::boolean AND (r->>'marathon_bonus_points')::integer=0 AND NOT (r->>'marathon_invalid')::boolean
  AND (SELECT bonus_awarded=0 FROM public.marathon_runs WHERE user_id=u AND client_uuid=run));
 u:=pg_temp.new_presence_user();run:=gen_random_uuid();client:=gen_random_uuid();t:=now()-interval '3 hours';
 r:=pg_temp.submit_presence(u,run,50,2,1,gen_random_uuid(),t,true);
 PERFORM pg_temp.historical_receipt(u,run,2,client,t+interval '55 minutes');
 r:=pg_temp.submit_presence(u,run,50,2,2,client,t+interval '55 minutes',true);
 PERFORM pg_temp.check_presence('Confirmation preserves pause penalty plus fixed50min bonus',
  (r->>'base_points')::integer=9 AND (r->>'marathon_bonus_points')::integer=4
  AND (SELECT lifetime_points=22 AND coins=40 AND total_minutes=100 FROM public.profiles WHERE id=u));
 -- Account delete cascades all private check-in state.
 DELETE FROM auth.users WHERE id=u;
 PERFORM pg_temp.check_presence('Account delete cascades gates and plans',
  NOT EXISTS(SELECT 1 FROM public.marathon_presence_gates WHERE user_id=u)
  AND NOT EXISTS(SELECT 1 FROM public.marathon_runs WHERE user_id=u));
END $limits$;

SELECT pg_temp.check_presence('Authenticated cannot read/write owner settings or gates',
 NOT has_table_privilege('authenticated','public.marathon_presence_settings','SELECT,INSERT,UPDATE,DELETE')
 AND NOT has_table_privilege('authenticated','public.marathon_presence_gates','SELECT,INSERT,UPDATE,DELETE'));
SELECT pg_temp.check_presence('Anon cannot invoke gate RPCs',
 NOT has_function_privilege('anon','public.start_marathon_break(uuid,integer,uuid)','EXECUTE')
 AND NOT has_function_privilege('anon','public.confirm_marathon_presence(uuid,integer,uuid)','EXECUTE'));
SELECT pg_temp.check_presence('Private prepresence RPC cannot bypass gates',
 NOT has_function_privilege('authenticated','public._complete_marathon_study_session_before_presence(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)','EXECUTE')
 AND NOT has_function_privilege('anon','public._complete_marathon_study_session_before_presence(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)','EXECUTE')
 AND NOT has_function_privilege('service_role','public._complete_marathon_study_session_before_presence(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)','EXECUTE'));
SELECT pg_temp.check_presence('Config advertises mandatory300+60 and samebonusmatrix',
 public.get_marathon_config()->>'presence_required'='true' AND public.get_marathon_config()->>'presence_seconds'='60'
 AND public.get_marathon_config()->>'break_seconds'='300'
 AND public.get_marathon_config()->'bonuses'='{"25":{"2":2,"3":3,"4":5},"50":{"2":4,"3":6,"4":10}}'::jsonb);
SELECT pg_temp.check_presence('Normal complete_study_session body is untouched',
 md5(pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure))='f0f2b9bcc09ae8440a66d889b5f22fcc');
DO $dry$
DECLARE result text;
BEGIN SELECT string_agg('T'||lpad(seq::text,2,'0')||' '||name||': '||ok::text,' || ' ORDER BY seq) INTO result FROM presence_checks;
RAISE EXCEPTION 'DRYRUN_RESULT >> %',result; END $dry$;
ROLLBACK;
