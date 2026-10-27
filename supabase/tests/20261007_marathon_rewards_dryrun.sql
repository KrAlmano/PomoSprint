-- Kullanıcı SQL Editor; her madde true olmalı. Son hata transactionı geri alır.
BEGIN;
-- BEGIN MIGRATION BODY
DO $pre$
BEGIN
  IF md5(pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure)) IS DISTINCT FROM 'f0f2b9bcc09ae8440a66d889b5f22fcc'
     OR to_regclass('public.marathon_runs') IS NOT NULL
     OR to_regprocedure('public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)') IS NOT NULL THEN
    RAISE EXCEPTION 'marathon_rewards ön koşulu değişmiş; güncel canlı tanımdan yeniden hazırlayın.';
  END IF;
END
$pre$;

CREATE TABLE public.marathon_runs (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  client_uuid uuid NOT NULL,
  target_sessions integer NOT NULL CHECK(target_sessions IN(2,3,4)),
  duration_minutes integer NOT NULL CHECK(duration_minutes IN(25,50)),
  bonus_awarded integer NOT NULL DEFAULT 0 CHECK(bonus_awarded>=0),
  is_invalid boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(user_id,client_uuid)
);
CREATE TABLE public.marathon_run_sessions (
  user_id uuid NOT NULL,
  marathon_uuid uuid NOT NULL,
  session_index integer NOT NULL CHECK(session_index BETWEEN 1 AND 4),
  client_uuid uuid NOT NULL,
  study_session_id uuid NOT NULL UNIQUE REFERENCES public.study_sessions(id) ON DELETE CASCADE,
  result_json jsonb NOT NULL,
  PRIMARY KEY(user_id,marathon_uuid,session_index),
  UNIQUE(user_id,client_uuid),
  FOREIGN KEY(user_id,marathon_uuid) REFERENCES public.marathon_runs(user_id,client_uuid) ON DELETE CASCADE
);
ALTER TABLE public.marathon_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marathon_run_sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.marathon_runs, public.marathon_run_sessions FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.marathon_runs, public.marathon_run_sessions TO service_role;

CREATE OR REPLACE FUNCTION public.marathon_bonus_for(p_duration_minutes integer,p_target_sessions integer)
RETURNS integer LANGUAGE sql IMMUTABLE STRICT SET search_path TO 'public','pg_temp'
AS $function$
  SELECT CASE WHEN p_duration_minutes IN(25,50) AND p_target_sessions IN(2,3,4)
    THEN (CASE p_target_sessions WHEN 2 THEN 2 WHEN 3 THEN 3 ELSE 5 END) * (CASE p_duration_minutes WHEN 50 THEN 2 ELSE 1 END)
    ELSE 0 END;
$function$;
REVOKE ALL ON FUNCTION public.marathon_bonus_for(integer,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.marathon_bonus_for(integer,integer) TO service_role;

CREATE OR REPLACE FUNCTION public.get_marathon_config()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
  SELECT jsonb_build_object('available',true,'break_seconds',300,'bonuses',jsonb_build_object(
    '25',jsonb_build_object('2',public.marathon_bonus_for(25,2),'3',public.marathon_bonus_for(25,3),'4',public.marathon_bonus_for(25,4)),
    '50',jsonb_build_object('2',public.marathon_bonus_for(50,2),'3',public.marathon_bonus_for(50,3),'4',public.marathon_bonus_for(50,4))));
$function$;
REVOKE ALL ON FUNCTION public.get_marathon_config() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_marathon_config() TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.complete_marathon_study_session(
  p_client_uuid uuid,p_category_id uuid,p_duration_minutes integer,
  p_was_paused boolean,p_is_verified integer,p_started_at timestamptz,
  p_marathon_uuid uuid,p_target_sessions integer,p_session_index integer
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public','pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_run public.marathon_runs%ROWTYPE;
  v_mapped public.marathon_run_sessions%ROWTYPE;
  v_result jsonb;
  v_session_id uuid;
  v_membership record;
  v_completed integer;
  v_eligible boolean;
  v_chronological boolean;
  v_extra integer := 0;
  v_league_extra integer := 0;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  IF p_client_uuid IS NULL OR p_marathon_uuid IS NULL
     OR p_target_sessions IS NULL OR p_target_sessions NOT IN(2,3,4)
     OR p_session_index IS NULL OR p_session_index<1 OR p_session_index>p_target_sessions
     OR p_duration_minutes IS NULL OR p_duration_minutes NOT IN(25,50) THEN
    RAISE EXCEPTION 'invalid_marathon_metadata';
  END IF;

  -- complete_study_session ile aynı sahip kilidi: normal/Maraton ve iki
  -- cihaz aynı ekonomik sonucu eşzamanlı iki kez yazamaz.
  PERFORM 1 FROM public.profiles WHERE id=v_uid FOR UPDATE;
  SELECT * INTO v_mapped FROM public.marathon_run_sessions
   WHERE user_id=v_uid AND client_uuid=p_client_uuid;
  IF FOUND THEN
    IF v_mapped.marathon_uuid<>p_marathon_uuid OR v_mapped.session_index<>p_session_index
       OR NOT EXISTS(SELECT 1 FROM public.marathon_runs WHERE user_id=v_uid AND client_uuid=p_marathon_uuid AND target_sessions=p_target_sessions AND duration_minutes=p_duration_minutes) THEN
      RAISE EXCEPTION 'marathon_session_reused';
    END IF;
    RETURN v_mapped.result_json || jsonb_build_object('duplicate',true,'coins_earned',0,
      'streak',(SELECT current_streak FROM public.profiles WHERE id=v_uid));
  END IF;
  -- Önceden normal bitirilmiş seans başka bir plana sonradan eklenemez.
  IF EXISTS(SELECT 1 FROM public.study_sessions WHERE user_id=v_uid AND client_uuid=p_client_uuid) THEN
    RAISE EXCEPTION 'marathon_session_reused';
  END IF;
  SELECT * INTO v_run FROM public.marathon_runs WHERE user_id=v_uid AND client_uuid=p_marathon_uuid;
  IF FOUND AND (v_run.target_sessions<>p_target_sessions OR v_run.duration_minutes<>p_duration_minutes) THEN
    RAISE EXCEPTION 'marathon_metadata_conflict';
  END IF;
  IF EXISTS(SELECT 1 FROM public.marathon_run_sessions WHERE user_id=v_uid AND marathon_uuid=p_marathon_uuid AND session_index=p_session_index) THEN
    RAISE EXCEPTION 'marathon_index_conflict';
  END IF;

  -- Normal RPC ile aynı seçim, normal UPDATE fiziksel satır sırasını
  -- değiştirmeden yakalanır. Eski mükerrer aktif üyelikte tekrar LIMIT 1
  -- okumak bonusu normal puandan farklı üyeliğe yazabilir.
  SELECT COALESCE(lm.period_started_at,l.end_date-interval '14 days') AS period_started_at,
         lm.id,l.end_date INTO v_membership
  FROM public.league_memberships lm JOIN public.leagues l ON l.id=lm.league_id
  WHERE lm.user_id=v_uid AND l.is_active=true LIMIT 1;
  v_result := public.complete_study_session(p_client_uuid,p_category_id,p_duration_minutes,p_was_paused,p_is_verified,p_started_at);
  IF v_result ? 'error' THEN RETURN v_result; END IF;
  IF COALESCE((v_result->>'duplicate')::boolean,false) THEN RAISE EXCEPTION 'marathon_session_reused'; END IF;
  SELECT id INTO STRICT v_session_id FROM public.study_sessions WHERE user_id=v_uid AND client_uuid=p_client_uuid;
  INSERT INTO public.marathon_runs(user_id,client_uuid,target_sessions,duration_minutes)
  VALUES(v_uid,p_marathon_uuid,p_target_sessions,p_duration_minutes) ON CONFLICT DO NOTHING;
  INSERT INTO public.marathon_run_sessions(user_id,marathon_uuid,session_index,client_uuid,study_session_id,result_json)
  VALUES(v_uid,p_marathon_uuid,p_session_index,p_client_uuid,v_session_id,v_result);

  SELECT count(*),bool_and(s.base_points+s.bonus_points>0) INTO v_completed,v_eligible
  FROM public.marathon_run_sessions m JOIN public.study_sessions s ON s.id=m.study_session_id
  WHERE m.user_id=v_uid AND m.marathon_uuid=p_marathon_uuid;
  v_chronological := true;
  IF v_completed=p_target_sessions THEN
    SELECT NOT EXISTS(
      SELECT 1 FROM (
        SELECT s.started_at,lag(s.completed_at) OVER(ORDER BY m.session_index) previous_end
        FROM public.marathon_run_sessions m JOIN public.study_sessions s ON s.id=m.study_session_id
        WHERE m.user_id=v_uid AND m.marathon_uuid=p_marathon_uuid
      ) q WHERE started_at IS NULL OR (previous_end IS NOT NULL AND started_at<previous_end)
    ) INTO v_chronological;
    UPDATE public.marathon_runs SET is_invalid=NOT v_chronological WHERE user_id=v_uid AND client_uuid=p_marathon_uuid;
    IF v_chronological AND v_eligible AND COALESCE(v_run.bonus_awarded,0)=0 THEN
      v_extra := public.marathon_bonus_for(p_duration_minutes,p_target_sessions);
      UPDATE public.marathon_runs SET bonus_awarded=v_extra WHERE user_id=v_uid AND client_uuid=p_marathon_uuid AND bonus_awarded=0;
      IF NOT FOUND THEN v_extra:=0; END IF;
      IF v_extra>0 THEN
        UPDATE public.profiles SET lifetime_points=lifetime_points+v_extra WHERE id=v_uid;
        -- Rapor ve normal duplicate toplamı profil ile tutarlı kalır; sabit
        -- Maraton puanı seri yüzdesiyle çarpılmaz, kum veya dakika üretmez.
        UPDATE public.study_sessions SET bonus_points=bonus_points+v_extra WHERE id=v_session_id;
        IF NOT COALESCE((v_result->>'league_period_closed')::boolean,false) THEN
          IF COALESCE((v_result->>'league_points_next_period')::boolean,false) THEN
            UPDATE public.league_memberships SET carry_points=carry_points+v_extra
            WHERE id=v_membership.id;
          ELSE
            PERFORM public.ensure_user_in_league(v_uid,v_extra);
          END IF;
          v_league_extra:=v_extra;
        END IF;
      END IF;
    END IF;
  END IF;
  v_result := v_result || jsonb_build_object(
    'bonus_points',COALESCE((v_result->>'bonus_points')::integer,0)+v_extra,
    'total_points',COALESCE((v_result->>'total_points')::integer,0)+v_extra,
    'league_points',COALESCE((v_result->>'league_points')::integer,0)+v_league_extra,
    'marathon_bonus_points',v_extra,'marathon_completed',v_completed=p_target_sessions,
    'marathon_target_sessions',p_target_sessions,'marathon_completed_sessions',v_completed,
    'marathon_invalid',NOT v_chronological);
  UPDATE public.marathon_run_sessions SET result_json=v_result WHERE user_id=v_uid AND client_uuid=p_client_uuid;
  RETURN v_result;
END;
$function$;
REVOKE ALL ON FUNCTION public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer) TO authenticated,service_role;
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261007160000','marathon_rewards') ON CONFLICT(version) DO NOTHING;
-- END MIGRATION BODY
CREATE TEMP TABLE marathon_checks(seq serial,name text,ok boolean);
CREATE FUNCTION pg_temp.marathon_check(p_name text,p_ok boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN INSERT INTO marathon_checks(name,ok) VALUES(p_name,coalesce(p_ok,false)); END $$;
CREATE FUNCTION pg_temp.new_marathon_user() RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE u uuid:=gen_random_uuid();
BEGIN
 INSERT INTO auth.users(id,email,aud,role,raw_user_meta_data) VALUES(u,'marathon-'||u||'@example.invalid','authenticated','authenticated',jsonb_build_object('name','Marathon User'));
 UPDATE public.profiles SET timezone='UTC',coins=0,lifetime_points=0,total_minutes=0,show_in_social_feed=false WHERE id=u;
 INSERT INTO public.categories(user_id,name,color_hex,icon_name) VALUES(u,'Marathon Test','#123456','school');
 RETURN u;
END $$;
CREATE FUNCTION pg_temp.submit_marathon(u uuid,run uuid,dur integer,target integer,idx integer,client uuid,started timestamptz,paused boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE r jsonb;c uuid;
BEGIN
 SELECT id INTO c FROM public.categories WHERE user_id=u ORDER BY created_at LIMIT 1;
 PERFORM set_config('request.jwt.claims',json_build_object('sub',u,'role','authenticated')::text,true);
 SET LOCAL ROLE authenticated;
 r:=public.complete_marathon_study_session(client,c,dur,paused,dur*60,started,run,target,idx);
 RESET ROLE;
 RETURN r;
END $$;
CREATE FUNCTION pg_temp.marathon_error(u uuid,run uuid,dur integer,target integer,idx integer,client uuid,started timestamptz,wanted text) RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN PERFORM pg_temp.submit_marathon(u,run,dur,target,idx,client,started); RETURN false;
EXCEPTION WHEN raise_exception THEN RETURN SQLERRM=wanted; END $$;

DO $matrix$
DECLARE dur integer;target integer;i integer;u uuid;run uuid;client uuid;r jsonb;first_start timestamptz;normal integer;extra integer;before_points integer;last_started timestamptz;
BEGIN
 FOREACH dur IN ARRAY ARRAY[25,50] LOOP
  FOREACH target IN ARRAY ARRAY[2,3,4] LOOP
   u:=pg_temp.new_marathon_user();run:=gen_random_uuid();normal:=0;
   first_start:=now()-make_interval(mins=>target*(dur+5)+60);
   FOR i IN 1..target LOOP
    client:=gen_random_uuid();last_started:=first_start+make_interval(mins=>(i-1)*(dur+5));
    r:=pg_temp.submit_marathon(u,run,dur,target,i,client,last_started);
    normal:=normal+(r->>'total_points')::integer-(r->>'marathon_bonus_points')::integer;
    PERFORM pg_temp.marathon_check('Matrix '||dur||'x'||target||' index'||i||' bonus only complete', (r->>'marathon_bonus_points')::integer=CASE WHEN i=target THEN public.marathon_bonus_for(dur,target) ELSE 0 END);
   END LOOP;
   extra:=public.marathon_bonus_for(dur,target);
   PERFORM pg_temp.marathon_check('Matrix '||dur||'x'||target||' profile/report/league agree',
    (SELECT lifetime_points=normal+extra AND coins=20*target AND total_minutes=dur*target FROM public.profiles WHERE id=u)
    AND (SELECT sum(base_points+bonus_points)=normal+extra AND count(*)=target FROM public.study_sessions WHERE user_id=u)
    AND (SELECT sum(weekly_points+carry_points)=normal+extra FROM public.league_memberships WHERE user_id=u));
   SELECT lifetime_points INTO before_points FROM public.profiles WHERE id=u;
   r:=pg_temp.submit_marathon(u,run,dur,target,target,client,last_started);
   PERFORM pg_temp.marathon_check('Matrix '||dur||'x'||target||' duplicate never reawards', (r->>'duplicate')::boolean AND (r->>'coins_earned')::integer=0 AND (SELECT lifetime_points=before_points FROM public.profiles WHERE id=u) AND (SELECT count(*)=target FROM public.study_sessions WHERE user_id=u));
  END LOOP;
 END LOOP;
END $matrix$;

DO $edge$
DECLARE u uuid:=pg_temp.new_marathon_user();run uuid:=gen_random_uuid();client uuid:=gen_random_uuid();r jsonb;t timestamptz:=now()-interval '3 hours';c uuid;normal integer:=0;
BEGIN
 r:=pg_temp.submit_marathon(u,run,25,2,1,client,t);
 PERFORM pg_temp.marathon_check('Unfinished plan never gains extra',NOT(r->>'marathon_completed')::boolean AND (r->>'marathon_bonus_points')::integer=0 AND (SELECT bonus_awarded=0 FROM public.marathon_runs WHERE user_id=u AND client_uuid=run));
 PERFORM pg_temp.marathon_check('Changed target rejects before another focus',pg_temp.marathon_error(u,run,25,3,2,gen_random_uuid(),t+interval '30 minutes','marathon_metadata_conflict'));
 PERFORM pg_temp.marathon_check('Changed duration rejects before another focus',pg_temp.marathon_error(u,run,50,2,2,gen_random_uuid(),t+interval '30 minutes','marathon_metadata_conflict'));
 PERFORM pg_temp.marathon_check('Duplicate index rejects',pg_temp.marathon_error(u,run,25,2,1,gen_random_uuid(),t+interval '30 minutes','marathon_index_conflict'));
 PERFORM pg_temp.marathon_check('Same focus cannot be in another plan',pg_temp.marathon_error(u,gen_random_uuid(),25,2,1,client,t,'marathon_session_reused'));
 PERFORM pg_temp.marathon_check('Invalid metadata rejects',pg_temp.marathon_error(u,gen_random_uuid(),25,5,1,gen_random_uuid(),t,'invalid_marathon_metadata') AND pg_temp.marathon_error(u,gen_random_uuid(),25,2,3,gen_random_uuid(),t,'invalid_marathon_metadata'));
 PERFORM pg_temp.marathon_check('Overlap normal response retains retry semantics',pg_temp.submit_marathon(u,run,25,2,2,gen_random_uuid(),t)->>'error'='overlap');
 PERFORM pg_temp.marathon_check('No extra records from rejected/overlap requests',(SELECT count(*)=1 FROM public.study_sessions WHERE user_id=u));
 -- Standalone recorded focus must never be retrospectively attached.
 SELECT id INTO c FROM public.categories WHERE user_id=u LIMIT 1;
 PERFORM set_config('request.jwt.claims',json_build_object('sub',u,'role','authenticated')::text,true);
 SET LOCAL ROLE authenticated;
 r:=public.complete_study_session(gen_random_uuid(),c,25,false,1500,t+interval '30 minutes');
 RESET ROLE;
 SELECT client_uuid INTO client FROM public.study_sessions WHERE user_id=u ORDER BY started_at DESC LIMIT 1;
 PERFORM pg_temp.marathon_check('Standalone UUID retrofit rejected',pg_temp.marathon_error(u,gen_random_uuid(),25,2,1,client,t+interval '30 minutes','marathon_session_reused'));
 -- Arrival order3,1,2 still completes genuine chronological focus sequence.
 u:=pg_temp.new_marathon_user();run:=gen_random_uuid();
 r:=pg_temp.submit_marathon(u,run,25,3,3,gen_random_uuid(),t+interval '60 minutes');
 r:=pg_temp.submit_marathon(u,run,25,3,1,gen_random_uuid(),t);
 r:=pg_temp.submit_marathon(u,run,25,3,2,gen_random_uuid(),t+interval '30 minutes');
 PERFORM pg_temp.marathon_check('Out-of-order arrival completes exactly once',(r->>'marathon_completed')::boolean AND (r->>'marathon_bonus_points')::integer=3 AND (SELECT bonus_awarded=3 FROM public.marathon_runs WHERE user_id=u));
 -- Incorrect index chronology does not discard normal study records.
 u:=pg_temp.new_marathon_user();run:=gen_random_uuid();
 r:=pg_temp.submit_marathon(u,run,25,2,2,gen_random_uuid(),t);
 r:=pg_temp.submit_marathon(u,run,25,2,1,gen_random_uuid(),t+interval '30 minutes');
 PERFORM pg_temp.marathon_check('Bad chronology preserves normal focuses but no bonus',(r->>'marathon_invalid')::boolean AND (r->>'marathon_bonus_points')::integer=0 AND (SELECT count(*)=2 FROM public.study_sessions WHERE user_id=u));
 -- Fixed extra is not multiplied by existing14-day streak bonus.
 u:=pg_temp.new_marathon_user();run:=gen_random_uuid();
 UPDATE public.profiles SET current_streak=14,longest_streak=14,last_study_date=((t AT TIME ZONE 'UTC')-interval '4 hours')::date WHERE id=u;
 r:=pg_temp.submit_marathon(u,run,50,2,1,gen_random_uuid(),t);normal:=(r->>'total_points')::integer;
 r:=pg_temp.submit_marathon(u,run,50,2,2,gen_random_uuid(),t+interval '55 minutes');
 normal:=normal+(r->>'total_points')::integer-4;
 PERFORM pg_temp.marathon_check('Streak does not multiply marathon extra',(r->>'marathon_bonus_points')::integer=4 AND (r->>'bonus_pct')::integer=30 AND (SELECT lifetime_points=normal+4 AND coins=40 AND total_minutes=100 FROM public.profiles WHERE id=u));
END $edge$;

DO $paused$
DECLARE dur integer;u uuid;run uuid;r jsonb;t timestamptz:=now()-interval '3 hours';base integer;extra integer;
BEGIN
 FOREACH dur IN ARRAY ARRAY[25,50] LOOP
  u:=pg_temp.new_marathon_user();run:=gen_random_uuid();
  base:=CASE dur WHEN 25 THEN 4 ELSE 9 END;extra:=public.marathon_bonus_for(dur,2);
  r:=pg_temp.submit_marathon(u,run,dur,2,1,gen_random_uuid(),t,true);
  r:=pg_temp.submit_marathon(u,run,dur,2,2,gen_random_uuid(),t+make_interval(mins=>dur+5),true);
  PERFORM pg_temp.marathon_check('Paused '||dur||'min focus keeps normal penalty and fixed extra',
   (r->>'base_points')::integer=base AND (r->>'marathon_bonus_points')::integer=extra
   AND (r->>'total_points')::integer=base+extra AND (r->>'bonus_pct')::integer=0);
  PERFORM pg_temp.marathon_check('Paused '||dur||'min profile/report/league/coins/minutes agree',
   (SELECT lifetime_points=base*2+extra AND coins=40 AND total_minutes=dur*2 FROM public.profiles WHERE id=u)
   AND (SELECT sum(base_points+bonus_points)=base*2+extra AND bool_and(was_paused) FROM public.study_sessions WHERE user_id=u)
   AND (SELECT sum(weekly_points+carry_points)=base*2+extra FROM public.league_memberships WHERE user_id=u));
 END LOOP;
END $paused$;

DO $league_edges$
DECLARE u uuid;run uuid;l uuid;lm uuid;second_l uuid;second_lm uuid;r jsonb;client uuid;
 t timestamptz:=now()-interval '3 hours';before_carry jsonb;
BEGIN
 -- Active room whose end date passed but period processing has not run.
 -- Both normal focuses and the extra go into one membership's carry balance.
 u:=pg_temp.new_marathon_user();run:=gen_random_uuid();l:=gen_random_uuid();lm:=gen_random_uuid();client:=gen_random_uuid();
 INSERT INTO public.leagues(id,tier,start_date,end_date,is_active)
 VALUES(l,1,now()-interval '14 days',now()-interval '4 hours',true);
 INSERT INTO public.league_memberships(id,league_id,user_id,period_started_at,weekly_points,carry_points)
 VALUES(lm,l,u,now()-interval '14 days',11,13);
 r:=pg_temp.submit_marathon(u,run,25,2,1,gen_random_uuid(),t);
 r:=pg_temp.submit_marathon(u,run,25,2,2,client,t+interval '30 minutes');
 PERFORM pg_temp.marathon_check('Ended active room sends final normal plus extra to carry',
  (r->>'league_points_next_period')::boolean AND NOT(r->>'league_period_closed')::boolean
  AND (r->>'league_points')::integer=7 AND (r->>'marathon_bonus_points')::integer=2);
 PERFORM pg_temp.marathon_check('Carry branch preserves weekly points and all economic totals',
  (SELECT weekly_points=11 AND carry_points=25 FROM public.league_memberships WHERE id=lm)
  AND (SELECT lifetime_points=12 AND coins=40 AND total_minutes=50 FROM public.profiles WHERE id=u)
  AND (SELECT sum(base_points+bonus_points)=12 FROM public.study_sessions WHERE user_id=u));
 r:=pg_temp.submit_marathon(u,run,25,2,2,client,t+interval '30 minutes');
 PERFORM pg_temp.marathon_check('Carry duplicate never reawards next-period bonus',
  (r->>'duplicate')::boolean AND (SELECT carry_points=25 AND weekly_points=11 FROM public.league_memberships WHERE id=lm));

 -- Historical focuses completed before the current membership period started.
 -- Lifetime/report bonus remains valid but must not enter this league period.
 u:=pg_temp.new_marathon_user();run:=gen_random_uuid();l:=gen_random_uuid();lm:=gen_random_uuid();client:=gen_random_uuid();
 INSERT INTO public.leagues(id,tier,start_date,end_date,is_active)
 VALUES(l,1,now()-interval '1 hour',now()+interval '13 days',true);
 INSERT INTO public.league_memberships(id,league_id,user_id,period_started_at,weekly_points,carry_points)
 VALUES(lm,l,u,now()-interval '1 hour',11,13);
 r:=pg_temp.submit_marathon(u,run,25,2,1,gen_random_uuid(),t);
 r:=pg_temp.submit_marathon(u,run,25,2,2,client,t+interval '30 minutes');
 PERFORM pg_temp.marathon_check('Closed historical period keeps extra out of current league',
  (r->>'league_period_closed')::boolean AND NOT(r->>'league_points_next_period')::boolean
  AND (r->>'league_points')::integer=0 AND (r->>'marathon_bonus_points')::integer=2
  AND (SELECT weekly_points=11 AND carry_points=13 FROM public.league_memberships WHERE id=lm));
 PERFORM pg_temp.marathon_check('Closed-period profile and study report retain earned extra',
  (SELECT lifetime_points=12 AND coins=40 AND total_minutes=50 FROM public.profiles WHERE id=u)
  AND (SELECT sum(base_points+bonus_points)=12 FROM public.study_sessions WHERE user_id=u));
 r:=pg_temp.submit_marathon(u,run,25,2,2,client,t+interval '30 minutes');
 PERFORM pg_temp.marathon_check('Closed-period duplicate changes neither lifetime nor league',
  (r->>'duplicate')::boolean AND (SELECT lifetime_points=12 FROM public.profiles WHERE id=u)
  AND (SELECT weekly_points=11 AND carry_points=13 FROM public.league_memberships WHERE id=lm));

 -- Legacy/administrative inconsistency: schema permits two active memberships.
 -- Normal RPC chooses one (LIMIT1); the wrapper must not fan the extra out.
 u:=pg_temp.new_marathon_user();run:=gen_random_uuid();l:=gen_random_uuid();lm:=gen_random_uuid();second_l:=gen_random_uuid();second_lm:=gen_random_uuid();
 INSERT INTO public.leagues(id,tier,start_date,end_date,is_active) VALUES
  (l,1,now()-interval '14 days',now()-interval '4 hours',true),
  (second_l,1,now()-interval '14 days',now()-interval '4 hours',true);
 INSERT INTO public.league_memberships(id,league_id,user_id,period_started_at,weekly_points,carry_points) VALUES
  (lm,l,u,now()-interval '14 days',0,0),
  (second_lm,second_l,u,now()-interval '14 days',0,0);
 r:=pg_temp.submit_marathon(u,run,25,2,1,gen_random_uuid(),t);
 SELECT jsonb_object_agg(id::text,carry_points) INTO before_carry FROM public.league_memberships WHERE user_id=u;
 r:=pg_temp.submit_marathon(u,run,25,2,2,gen_random_uuid(),t+interval '30 minutes');
 PERFORM pg_temp.marathon_check('Multiple active memberships cannot multiply carry bonus',
  (SELECT sum(carry_points)=12 AND sum(weekly_points)=0 FROM public.league_memberships WHERE user_id=u)
  AND (SELECT lifetime_points=12 FROM public.profiles WHERE id=u)
  AND (SELECT sum(base_points+bonus_points)=12 FROM public.study_sessions WHERE user_id=u));
 PERFORM pg_temp.marathon_check('Multiple-active carry follows the single normal membership',
  (SELECT count(*) FILTER(WHERE carry_points<>(before_carry->>id::text)::integer)=1
   AND bool_and(carry_points-(before_carry->>id::text)::integer IN(0,7)) FROM public.league_memberships WHERE user_id=u));
END $league_edges$;

DO $cap$
DECLARE u uuid:=pg_temp.new_marathon_user();run uuid:=gen_random_uuid();c uuid;t timestamptz;day_start timestamptz;r jsonb;i integer;
BEGIN
 day_start:=date_trunc('day',now()-interval '4 hours')+interval '4 hours';
 -- Use previous study day when today's elapsed time cannot hold18 valid25min intervals.
 IF now()-day_start<interval '8 hours' THEN t:=day_start-interval '1 day'+interval '16 hours'; ELSE t:=day_start; END IF;
 SELECT id INTO c FROM public.categories WHERE user_id=u LIMIT 1;
 FOR i IN 0..15 LOOP
  INSERT INTO public.study_sessions(user_id,category_id,category,duration_minutes,base_points,bonus_points,client_uuid,started_at,completed_at,start_verified)
  VALUES(u,c,'Marathon Test',25,5,0,gen_random_uuid(),t+make_interval(mins=>i*25),t+make_interval(mins=>(i+1)*25),true);
 END LOOP;
 r:=pg_temp.submit_marathon(u,run,25,2,1,gen_random_uuid(),t+interval '400 minutes');
 r:=pg_temp.submit_marathon(u,run,25,2,2,gen_random_uuid(),t+interval '430 minutes');
 PERFORM pg_temp.marathon_check('Daily cap prevents extra for completed set',(r->>'marathon_bonus_points')::integer=0 AND (r->>'daily_limit_reached')::boolean AND (SELECT bonus_awarded=0 FROM public.marathon_runs WHERE user_id=u));
END $cap$;

SELECT pg_temp.marathon_check('Protected tables have no authenticated writes/reads',NOT has_table_privilege('authenticated','public.marathon_runs','SELECT,INSERT,UPDATE,DELETE') AND NOT has_table_privilege('authenticated','public.marathon_run_sessions','SELECT,INSERT,UPDATE,DELETE'));
SELECT pg_temp.marathon_check('Anon cannot execute rewards/config',NOT has_function_privilege('anon','public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)','EXECUTE') AND NOT has_function_privilege('anon','public.get_marathon_config()','EXECUTE'));
SELECT pg_temp.marathon_check('Config uses same exact bonus matrix',public.get_marathon_config()->'bonuses'='{"25":{"2":2,"3":3,"4":5},"50":{"2":4,"3":6,"4":10}}'::jsonb AND public.get_marathon_config()->>'break_seconds'='300');
SELECT pg_temp.marathon_check('Normal RPC body untouched',md5(pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure))='f0f2b9bcc09ae8440a66d889b5f22fcc');
DO $dry$
DECLARE result text;
BEGIN SELECT string_agg('T'||lpad(seq::text,2,'0')||' '||name||': '||ok::text,' || ' ORDER BY seq) INTO result FROM marathon_checks;
RAISE EXCEPTION 'DRYRUN_RESULT >> %',result; END $dry$;
ROLLBACK;
