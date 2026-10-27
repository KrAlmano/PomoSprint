-- BEGIN veya COMMIT içermez. Yalnız dış transaction + ROLLBACK içinde çalıştır.
CREATE TEMP TABLE league_policy_results(seq serial,name text,ok boolean) ON COMMIT DROP;
CREATE FUNCTION pg_temp.lp_check(p_name text,p_ok boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$ BEGIN
 INSERT INTO league_policy_results(name,ok) VALUES(p_name,coalesce(p_ok,false));
 IF NOT coalesce(p_ok,false) THEN RAISE EXCEPTION 'league policy assertion failed: %',p_name;END IF;
END $$;
CREATE FUNCTION pg_temp.lp_user(p_tag text,p_tier integer DEFAULT 1) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v uuid:=gen_random_uuid();BEGIN
 INSERT INTO auth.users(id,email,aud,role,raw_user_meta_data,created_at)
 VALUES(v,'league-policy-'||p_tag||'-'||left(v::text,8)||'@example.invalid','authenticated','authenticated',
  jsonb_build_object('name','League policy '||p_tag),now());
 UPDATE public.profiles SET league_tier=p_tier,timezone='Europe/Istanbul' WHERE id=v;
 RETURN v;END $$;
CREATE FUNCTION pg_temp.lp_as(p_uid uuid) RETURNS void LANGUAGE sql AS $$
 SELECT set_config('request.jwt.claims',json_build_object('sub',p_uid,'role','authenticated')::text,true)
$$;
CREATE FUNCTION pg_temp.lp_study(p_uid uuid,p_at timestamptz,p_minutes integer DEFAULT 50,p_points integer DEFAULT 12)
RETURNS void LANGUAGE sql AS $$
 INSERT INTO public.study_sessions(user_id,category,duration_minutes,base_points,bonus_points,started_at,completed_at,client_uuid)
 VALUES(p_uid,'SQL isolated fixture',p_minutes,p_points,0,p_at-make_interval(mins=>p_minutes),p_at,gen_random_uuid())
$$;
SELECT pg_temp.lp_check('capacity25',public.get_league_config()->>'league_room_capacity'='25');
SELECT pg_temp.lp_check('initialthreshold25',public.get_league_config()->>'league_launch_min_active_users'='25');
SELECT pg_temp.lp_check('preparationnoinstantcompetition',public.get_league_config()->>'competition_phase' IN('preparing','scheduled'));
SELECT pg_temp.lp_check('zone0noautomaticpromotion',(SELECT promotion_zone_end=0 AND demotion_zone_start=999 FROM public.get_league_zones(0)));
SELECT pg_temp.lp_check('zone2noautomaticpromotion',(SELECT promotion_zone_end=0 AND demotion_zone_start=999 FROM public.get_league_zones(2)));
SELECT pg_temp.lp_check('zone3onepromotion',(SELECT promotion_zone_end=1 AND demotion_zone_start=999 FROM public.get_league_zones(3)));
SELECT pg_temp.lp_check('zone10threepromotion',(SELECT promotion_zone_end=3 AND demotion_zone_start=8 FROM public.get_league_zones(10)));
SELECT pg_temp.lp_check('zone25eightpromotion',(SELECT promotion_zone_end=8 AND demotion_zone_start=18 FROM public.get_league_zones(25)));
SELECT pg_temp.lp_check('zone30tenpromotion',(SELECT promotion_zone_end=10 AND demotion_zone_start=21 FROM public.get_league_zones(30)));
SELECT pg_temp.lp_check('privatestateRLS',(SELECT relrowsecurity FROM pg_class WHERE oid='public.league_competition_state'::regclass));
SELECT pg_temp.lp_check('privateStateNoAPIread',NOT has_table_privilege('anon','public.league_competition_state','SELECT')
 AND NOT has_table_privilege('authenticated','public.league_competition_state','SELECT')
 AND NOT has_table_privilege('service_role','public.league_competition_state','SELECT'));
SELECT pg_temp.lp_check('privateFunctionsNoAPIexecution',NOT EXISTS(
 SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public'
 AND p.proname LIKE '\_league\_%' ESCAPE '\' AND
 (has_function_privilege('anon',p.oid,'EXECUTE') OR has_function_privilege('authenticated',p.oid,'EXECUTE') OR has_function_privilege('service_role',p.oid,'EXECUTE'))));
SELECT pg_temp.lp_check('rankingV2authOnly',NOT has_function_privilege('anon','public.get_my_league_ranking_v2()','EXECUTE')
 AND has_function_privilege('authenticated','public.get_my_league_ranking_v2()','EXECUTE'));
SELECT pg_temp.lp_check('normalCompletionExpectedPeriodGuardFingerprint',md5(pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure))='72023f3f4d8636363cf0231f42d4c7e1');
SELECT pg_temp.lp_check('marathonCompletionFingerprintUnchanged',md5(pg_get_functiondef('public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)'::regprocedure))='177a238a9aa8a4ffd3738b2865120568');
SELECT pg_temp.lp_check('readonlyConfigNoSecrets',NOT(public.get_league_config() ?| ARRAY['rollback_snapshot','applied_at','friend_code_attempts_per_hour']));
SET LOCAL TimeZone='America/New_York';
SELECT pg_temp.lp_check('periodCalendarIndependentDST',public._league_grid_start(timestamptz '2026-11-10 12:00Z')=timestamptz '2026-11-09 00:00 Europe/Istanbul');
SET LOCAL TimeZone='Europe/Istanbul';

-- Bütün aşağıdaki yerleşim/sıralama fixture'ları transaction içinde izole.
-- Özgün oda üyelikleri/verileri silinmez, oda görünürlüğü ROLLBACK ile döner.
UPDATE public.leagues SET is_active=false;
DO $placement$
DECLARE u uuid;u2 uuid;l1 uuid;l2 uuid;v_end timestamptz;v_score integer;v_bounds timestamptz;
BEGIN
 v_end:=public._league_grid_start(now())+interval '336 hours'-interval '1 microsecond';
 INSERT INTO public.leagues(tier,start_date,end_date) VALUES(1,now()-interval '10 days',v_end) RETURNING id INTO l1;
 INSERT INTO public.leagues(tier,start_date,end_date) VALUES(1,now()-interval '5 days',v_end) RETURNING id INTO l2;
 u:=pg_temp.lp_user('existing');u2:=pg_temp.lp_user('new');
 INSERT INTO public.league_memberships(league_id,user_id,weekly_points,carry_points,period_started_at)
 VALUES(l2,u,20,7,now()-interval '12 days');
 PERFORM pg_temp.lp_as(u2);
 PERFORM public.ensure_user_in_league(u2,0);
 PERFORM pg_temp.lp_check('nozeroPointPlacement',NOT EXISTS(SELECT 1 FROM public.league_memberships WHERE user_id=u2));
 PERFORM public.ensure_user_in_league(u2,5);
 PERFORM pg_temp.lp_check('existingDensestRoomUsed',(SELECT league_id=l2 FROM public.league_memberships WHERE user_id=u2));
 PERFORM pg_temp.lp_as(u);
 PERFORM pg_temp.lp_check('preparationShowsWeeklyAndCarry',(public.get_my_league_ranking_v2()->0->>'weekly_points')::integer=27);
 PERFORM pg_temp.lp_check('preparationEligibilityFalse',NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.get_my_league_ranking_v2()) r
  WHERE (r->>'promotion_eligible')::boolean OR (r->>'award_eligible')::boolean OR (r->>'demotion_eligible')::boolean));
 SELECT period_started_at INTO v_bounds FROM public.league_memberships WHERE user_id=u;
 PERFORM public.process_weekly_leagues();
 PERFORM pg_temp.lp_check('preparationCronKeepsTier',(SELECT league_tier=1 FROM public.profiles WHERE id=u));
 PERFORM pg_temp.lp_check('preparationCronFoldsCarry',(SELECT weekly_points=27 AND carry_points=0 FROM public.league_memberships WHERE user_id=u));
 PERFORM pg_temp.lp_check('preparationRepackKeepsCutoff',(SELECT period_started_at=v_bounds FROM public.league_memberships WHERE user_id=u));
 PERFORM pg_temp.lp_check('preparationReusesNonemptyRoom',EXISTS(SELECT 1 FROM public.leagues WHERE id=l2 AND is_active));
 PERFORM pg_temp.lp_check('nestedSafeConfigIncluded',(public.get_my_league_ranking_v2()->0->'league_config'->>'policy_version')='1');
END $placement$;

-- Tam 25 farklı kullanıcı, puan sıfır olsa da gerçek tamamlanan süre ile sayılır.
DO $threshold$
DECLARE i integer;u uuid;v_start timestamptz;v_existing integer;
BEGIN
 UPDATE public.league_competition_state SET start_at=NULL,initialized=false,period_started_at=NULL WHERE singleton;
 SELECT count(DISTINCT user_id)::integer INTO v_existing FROM public.study_sessions
  WHERE completed_at>=now()-interval '336 hours' AND completed_at<=now() AND duration_minutes IN(25,50);
 UPDATE public.app_config SET value=to_jsonb(v_existing+25) WHERE key='league_launch_min_active_users';
 FOR i IN 1..24 LOOP
  u:=pg_temp.lp_user('threshold-'||i);PERFORM pg_temp.lp_study(u,now()-interval '1 hour',25,0);
 END LOOP;
 PERFORM pg_temp.lp_check('24ActiveUsersRemainPreparing',(SELECT start_at IS NULL FROM public.league_competition_state WHERE singleton));
 -- Tek kişinin ikinci/üçüncü seansı farklı kullanıcı gibi sayılmaz.
 PERFORM pg_temp.lp_study(u,now()-interval '30 minutes',25,0);
 PERFORM pg_temp.lp_check('repeatUserDoesNotMeetThreshold',(SELECT start_at IS NULL FROM public.league_competition_state WHERE singleton));
 u:=pg_temp.lp_user('threshold-25');PERFORM pg_temp.lp_study(u,now(),25,0);
 SELECT start_at INTO v_start FROM public.league_competition_state WHERE singleton;
 PERFORM pg_temp.lp_check('25DistinctIncludingZeroPointSchedules',v_start IS NOT NULL);
 PERFORM pg_temp.lp_check('launchNextFullGridNotImmediate',v_start=greatest(timestamptz '2026-10-12 00:00 Europe/Istanbul',public._league_grid_start(now())+interval '336 hours'));
 PERFORM pg_temp.lp_check('scheduledPhaseReadable',public.get_league_config()->>'competition_phase'='scheduled');
 PERFORM pg_temp.lp_check('launchIsNotRepeated',(SELECT start_at=v_start FROM public.league_competition_state WHERE singleton));
 UPDATE public.app_config SET value='25' WHERE key='league_launch_min_active_users';
END $threshold$;

UPDATE public.leagues SET is_active=false;
DO $rollover$
DECLARE room uuid;u uuid;i integer;j integer;v_start timestamptz;v_current timestamptz;top_user uuid;late_user uuid;v_before jsonb;v_after jsonb;
BEGIN
 v_current:=public._league_grid_start(now());v_start:=v_current-interval '336 hours';
 UPDATE public.league_competition_state SET start_at=v_start,initialized=true,period_started_at=v_start WHERE singleton;
 INSERT INTO public.leagues(tier,start_date,end_date) VALUES(2,v_start,v_current-interval '1 microsecond') RETURNING id INTO room;
 FOR i IN 1..10 LOOP
  u:=pg_temp.lp_user('competing-'||i,2);
  INSERT INTO public.league_memberships(league_id,user_id,weekly_points,joined_at,period_started_at)
  VALUES(room,u,999,v_start,v_start-interval '1 microsecond');
  FOR j IN 1..6 LOOP PERFORM pg_temp.lp_study(u,v_start+make_interval(hours=>j*24+12),50,20-i);END LOOP;
  IF i=1 THEN top_user:=u;END IF;
  IF i=10 THEN
   late_user:=u;UPDATE public.league_memberships SET joined_at=v_current-interval '24 hours' WHERE user_id=u;
  END IF;
 END LOOP;
 -- Gün/ dakika yeterli; puanlar her üyede seanslardan gelir, stale999 değil.
 PERFORM public.process_weekly_leagues();
 PERFORM pg_temp.lp_check('qualifiedTop3Promoted',(SELECT count(*)=3 FROM public.profiles WHERE name LIKE 'League policy competing-%' AND league_tier=3));
 PERFORM pg_temp.lp_check('bottom3MinusProtectedLateUserDemoted',(SELECT count(*)=2 FROM public.profiles WHERE name LIKE 'League policy competing-%' AND league_tier=1));
 PERFORM pg_temp.lp_check('lateJoiningUserNotDemoted',(SELECT league_tier=2 FROM public.profiles WHERE id=late_user));
 PERFORM pg_temp.lp_check('championAwardFromFinishedTier',EXISTS(SELECT 1 FROM public.avatar_unlocks WHERE user_id=top_user AND avatar_id=public.league_award_avatar_id(2,1) AND unlock_type='league_award'));
 PERFORM pg_temp.lp_check('exactThreeLeagueAwards',(SELECT count(*)=3 FROM public.avatar_unlocks a JOIN public.profiles p ON p.id=a.user_id
  WHERE p.name LIKE 'League policy competing-%' AND a.unlock_type='league_award'));
 PERFORM pg_temp.lp_check('scoreResetCurrentPeriodOnly',(SELECT bool_and(m.weekly_points=0 AND m.carry_points=0)
  FROM public.league_memberships m JOIN public.leagues l ON l.id=m.league_id AND l.is_active));
 PERFORM pg_temp.lp_check('correctNewCutoff',(SELECT bool_and(m.period_started_at=v_current-interval '1 microsecond')
  FROM public.league_memberships m JOIN public.leagues l ON l.id=m.league_id AND l.is_active));
 PERFORM pg_temp.lp_check('allRoomsAligned14Days',(SELECT bool_and(end_date=v_current+interval '336 hours'-interval '1 microsecond') FROM public.leagues WHERE is_active));
 SELECT jsonb_agg(jsonb_build_object('user',m.user_id,'room',m.league_id,'points',m.weekly_points,'tier',p.league_tier) ORDER BY m.user_id)
 INTO v_before FROM public.league_memberships m JOIN public.leagues l ON l.id=m.league_id AND l.is_active JOIN public.profiles p ON p.id=m.user_id;
 PERFORM public.process_weekly_leagues();
 SELECT jsonb_agg(jsonb_build_object('user',m.user_id,'room',m.league_id,'points',m.weekly_points,'tier',p.league_tier) ORDER BY m.user_id)
 INTO v_after FROM public.league_memberships m JOIN public.leagues l ON l.id=m.league_id AND l.is_active JOIN public.profiles p ON p.id=m.user_id;
 PERFORM pg_temp.lp_check('repeatedCronIdempotentNoMidperiodShuffle',v_before=v_after);
 PERFORM pg_temp.lp_check('maxCapacity25AfterMoves',(SELECT max(n)<=25 FROM (SELECT count(*) n FROM public.league_memberships m JOIN public.leagues l ON l.id=m.league_id AND l.is_active GROUP BY l.id) q));
END $rollover$;

-- Snapshot toplamından önceki dönem puanları çıkar, ancak ilk dakika/current
-- dönem seansları ve Maraton bonusu tam bir kere görünür.
UPDATE public.leagues SET is_active=false;
DO $launch$
DECLARE u uuid;room uuid;v_start timestamptz;v_row jsonb;v_lifetime integer;
BEGIN
 v_start:=public._league_grid_start(now());
 UPDATE public.league_competition_state SET start_at=v_start,initialized=false,period_started_at=NULL WHERE singleton;
 u:=pg_temp.lp_user('firstlaunch',5);
 INSERT INTO public.leagues(tier,end_date) VALUES(5,now()+interval '24 hours') RETURNING id INTO room;
 INSERT INTO public.league_memberships(league_id,user_id,weekly_points,carry_points) VALUES(room,u,444,33);
 PERFORM pg_temp.lp_study(u,v_start-interval '1 microsecond',50,500);
 PERFORM pg_temp.lp_study(u,v_start,25,5);
 PERFORM pg_temp.lp_study(u,now()-interval '1 hour',50,22);
 SELECT lifetime_points INTO v_lifetime FROM public.profiles WHERE id=u;
 PERFORM pg_temp.lp_as(u);v_row:=public.get_my_league_ranking_v2()->0;
 PERFORM pg_temp.lp_check('virtualLaunchNoOldPointsBeforeCron',(v_row->>'weekly_points')::integer=27);
 PERFORM public.process_weekly_leagues();
 PERFORM pg_temp.lp_check('launchKeepsActualCurrent27Points',(SELECT weekly_points=27 AND carry_points=0 FROM public.league_memberships WHERE user_id=u));
 PERFORM pg_temp.lp_check('firstLaunchDoesNotAwardOrMove',(SELECT league_tier=5 FROM public.profiles WHERE id=u)
  AND NOT EXISTS(SELECT 1 FROM public.avatar_unlocks WHERE user_id=u AND unlock_type='league_award'));
 PERFORM pg_temp.lp_check('lifetimeUnaffectedByLaunch',(SELECT lifetime_points=v_lifetime FROM public.profiles WHERE id=u));
END $launch$;

-- Yerel/geri alınan DRYRUN için takvim helper'ı tek işlemde sabit bir geçmiş
-- sınıra çekilir; gerçek server now(), süre/overlap/ödül kontrolleri korunur.
-- Böylece 14 gün beklemeden gerçek normal RPC'nin 24 saat sınırı sınanır.
UPDATE public.leagues SET is_active=false;
DO $firstdelayed$
DECLARE v_grid_definition text;v_boundary timestamptz:=now()-interval '1 hour';u uuid;u2 uuid;c uuid;c2 uuid;
 v_uuid uuid:=gen_random_uuid();v_result jsonb;v_exact jsonb;v_next jsonb;
BEGIN
 SELECT pg_get_functiondef('public._league_grid_start(timestamptz)'::regprocedure) INTO v_grid_definition;
 EXECUTE format('CREATE OR REPLACE FUNCTION public._league_grid_start(p_at timestamptz) RETURNS timestamptz LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS %L',
  'SELECT '||quote_literal(v_boundary::text)||'::timestamptz');
 UPDATE public.league_competition_state SET start_at=v_boundary,initialized=true,period_started_at=v_boundary WHERE singleton;
 u:=pg_temp.lp_user('first-delayed');u2:=pg_temp.lp_user('first-exact');
 INSERT INTO public.categories(user_id,name,color_hex) VALUES(u,'Delayed fixture','#FF0000') RETURNING id INTO c;
 INSERT INTO public.categories(user_id,name,color_hex) VALUES(u2,'Exact fixture','#FF0000') RETURNING id INTO c2;
 PERFORM pg_temp.lp_as(u);
 v_result:=public.complete_study_session(v_uuid,c,25,false,0,v_boundary-interval '26 minutes');
 PERFORM pg_temp.lp_check('firstEverDelayedPreviousPeriodResponseClosedZero',
  (v_result->>'league_points')::integer=0 AND (v_result->>'league_period_closed')::boolean AND (v_result->>'total_points')::integer=5);
 PERFORM pg_temp.lp_check('firstEverDelayedPlacedWithZeroLeaguePoints',
  EXISTS(SELECT 1 FROM public.league_memberships m JOIN public.leagues l ON l.id=m.league_id AND l.is_active
   WHERE m.user_id=u AND m.weekly_points=0 AND m.carry_points=0));
 PERFORM pg_temp.lp_check('firstEverDelayedLifetimeHistoryKept',
  (SELECT lifetime_points=5 AND total_minutes=25 AND coins=20 FROM public.profiles WHERE id=u)
  AND (SELECT count(*)=1 FROM public.study_sessions WHERE user_id=u));
 PERFORM pg_temp.lp_check('firstEverDelayedV2HasZeroCurrentPeriodPoints',
  (public.get_my_league_ranking_v2()->0->>'weekly_points')::integer=0);
 v_next:=public.complete_study_session(gen_random_uuid(),c,25,false,0,v_boundary+interval '5 minutes');
 PERFORM pg_temp.lp_check('currentAfterDelayedHasOnlyCurrentLeaguePoints',
  (v_next->>'league_points')::integer=5 AND NOT(v_next->>'league_period_closed')::boolean
  AND (SELECT weekly_points=5 AND carry_points=0 FROM public.league_memberships WHERE user_id=u));
 v_result:=public.complete_study_session(v_uuid,c,25,false,0,v_boundary-interval '26 minutes');
 PERFORM pg_temp.lp_check('delayedDuplicateDoesNotContaminateCurrentPoints',
  (v_result->>'duplicate')::boolean AND (v_result->>'coins_earned')::integer=0
  AND (SELECT weekly_points=5 FROM public.league_memberships WHERE user_id=u)
  AND (SELECT lifetime_points=10 AND total_minutes=50 AND coins=40 FROM public.profiles WHERE id=u));
 PERFORM pg_temp.lp_as(u2);
 v_exact:=public.complete_study_session(gen_random_uuid(),c2,25,false,0,v_boundary-interval '25 minutes');
 PERFORM pg_temp.lp_check('firstEverExactBoundaryCredited',
  (v_exact->>'league_points')::integer=5 AND NOT(v_exact->>'league_period_closed')::boolean
  AND (SELECT weekly_points=5 FROM public.league_memberships WHERE user_id=u2));
 PERFORM pg_temp.lp_check('exactBoundaryV2ConsistentWithNormalRPC',
  EXISTS(SELECT 1 FROM jsonb_array_elements(public.get_my_league_ranking_v2()) r WHERE (r->>'is_me')::boolean AND (r->>'weekly_points')::integer=5));
 EXECUTE v_grid_definition;
 PERFORM pg_temp.lp_check('testCalendarGatewayRestored',
  pg_get_functiondef('public._league_grid_start(timestamptz)'::regprocedure)=v_grid_definition);
END $firstdelayed$;
SELECT seq,name,ok FROM league_policy_results ORDER BY seq;
SELECT jsonb_build_object('checks',count(*),'passed',count(*) FILTER(WHERE ok),'failed',count(*) FILTER(WHERE NOT ok)) AS league_policy_summary FROM league_policy_results;
