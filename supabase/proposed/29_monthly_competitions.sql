-- PROPOSED ONLY: unified monthly study/exam, segment rooms and global views.
-- Requires 27 then 28. Preserves legacy leagues/economy and existing earned awards.
\echo 'Review monthly competition README and DRYRUN before installing.'
\quit
BEGIN;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261028020000') THEN RAISE EXCEPTION 'competition_requires_exam_core'; END IF;
 IF to_regclass('public.competition_policy') IS NOT NULL THEN RAISE EXCEPTION 'competition_already_installed'; END IF;
 IF md5(pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure))<>'72023f3f4d8636363cf0231f42d4c7e1' THEN RAISE EXCEPTION 'competition_normal_precondition_changed'; END IF;
END $$;
CREATE TABLE public.competition_install_backup(signature text PRIMARY KEY,definition text NOT NULL);
ALTER TABLE public.competition_install_backup ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.competition_install_backup FROM PUBLIC,anon,authenticated,service_role;
INSERT INTO public.competition_install_backup SELECT p.oid::regprocedure::text,pg_get_functiondef(p.oid) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname IN('complete_study_session','process_weekly_leagues','get_my_league_ranking_v2','get_league_config','get_public_monthly_leaderboard','get_league_ranking','get_my_league_ranking','ensure_user_in_league');
CREATE FUNCTION public._competition_month(p_at timestamptz) RETURNS date LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $$ SELECT date_trunc('month',p_at AT TIME ZONE 'Europe/Istanbul')::date $$;
CREATE FUNCTION public._competition_month_time(p_month date) RETURNS timestamptz LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $$ SELECT p_month::timestamp AT TIME ZONE 'Europe/Istanbul' $$;
CREATE TABLE public.competition_policy(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),activates_at timestamptz NOT NULL,legacy_finalized boolean NOT NULL DEFAULT false,legacy_snapshot jsonb NOT NULL,legacy_decisions jsonb NOT NULL DEFAULT '[]'::jsonb);
INSERT INTO public.competition_policy(singleton,activates_at,legacy_snapshot) SELECT true,public._competition_month_time((public._competition_month(now())+interval '1 month')::date),jsonb_build_object('state',(SELECT jsonb_build_object('start_at',s.start_at,'initialized',s.initialized,'period_started_at',s.period_started_at) FROM public.league_competition_state s WHERE singleton),'rooms',coalesce((SELECT jsonb_agg(to_jsonb(l)) FROM public.leagues l),'[]'::jsonb),'members',coalesce((SELECT jsonb_agg(to_jsonb(m)) FROM public.league_memberships m),'[]'::jsonb),'cron',coalesce((SELECT jsonb_agg(to_jsonb(j)) FROM cron.job j WHERE jobname='weekly_leagues_job'),'[]'::jsonb));
CREATE TABLE public.competition_target_history(user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,from_month date NOT NULL,segment text NOT NULL CHECK(segment IN('lgs','yks','tus','kpss','language','university','work','other')),PRIMARY KEY(user_id,from_month));
INSERT INTO public.competition_target_history SELECT id,public._competition_month(now()),coalesce(user_segment,'other') FROM public.profiles;
CREATE TABLE public.competition_profiles(user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,kind text NOT NULL CHECK(kind IN('study','exam')),tier integer NOT NULL CHECK(tier BETWEEN 1 AND 5),PRIMARY KEY(user_id,kind));
INSERT INTO public.competition_profiles SELECT id,'study',league_tier FROM public.profiles;
CREATE TABLE public.competition_rooms(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),kind text NOT NULL CHECK(kind IN('study','exam')),period_month date NOT NULL,segment text NOT NULL,tier integer NOT NULL CHECK(tier BETWEEN 1 AND 5),created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX competition_room_lookup ON public.competition_rooms(kind,period_month,segment,tier,created_at);
CREATE TABLE public.competition_memberships(user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,kind text NOT NULL CHECK(kind IN('study','exam')),period_month date NOT NULL,room_id uuid NOT NULL REFERENCES public.competition_rooms(id),joined_at timestamptz NOT NULL,PRIMARY KEY(user_id,kind,period_month));
CREATE INDEX competition_members_by_room ON public.competition_memberships(room_id);
CREATE TABLE public.competition_events(kind text NOT NULL CHECK(kind IN('study','exam')),source_id uuid NOT NULL,user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,completed_at timestamptz NOT NULL,period_month date NOT NULL,points integer NOT NULL CHECK(points>=0),minutes integer NOT NULL CHECK(minutes>0),study_day date NOT NULL,PRIMARY KEY(kind,source_id));
CREATE INDEX competition_events_period_owner ON public.competition_events(period_month,kind,user_id);
CREATE TABLE public.competition_results(user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,kind text NOT NULL,period_month date NOT NULL,rank integer NOT NULL,from_tier integer NOT NULL,to_tier integer NOT NULL,award_id text REFERENCES public.avatars(id),snapshot jsonb NOT NULL,PRIMARY KEY(user_id,kind,period_month));
CREATE TABLE public.competition_periods(period_month date PRIMARY KEY,processed_at timestamptz NOT NULL);
CREATE TABLE public.competition_avatar_rewards(kind text NOT NULL CHECK(kind IN('study','exam')),tier integer NOT NULL CHECK(tier BETWEEN 1 AND 5),rank_position integer NOT NULL CHECK(rank_position BETWEEN 1 AND 3),avatar_id text REFERENCES public.avatars(id),PRIMARY KEY(kind,tier,rank_position));
INSERT INTO public.competition_avatar_rewards SELECT 'study',t,p,public.league_award_avatar_id(t,p) FROM generate_series(1,5)t CROSS JOIN generate_series(1,3)p;
INSERT INTO public.competition_avatar_rewards SELECT 'exam',t,p,NULL FROM generate_series(1,5)t CROSS JOIN generate_series(1,3)p;
DO $$ DECLARE n text; BEGIN FOREACH n IN ARRAY ARRAY['competition_policy','competition_target_history','competition_profiles','competition_rooms','competition_memberships','competition_events','competition_results','competition_periods','competition_avatar_rewards'] LOOP EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',n);EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC,anon,authenticated,service_role',n);END LOOP;END $$;
CREATE FUNCTION public._competition_purge_deleted_identity() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 UPDATE public.competition_policy SET legacy_snapshot=jsonb_set(jsonb_set(legacy_snapshot,'{members}',coalesce((SELECT jsonb_agg(x)FROM jsonb_array_elements(coalesce(legacy_snapshot->'members','[]'::jsonb))x WHERE x->>'user_id' IS DISTINCT FROM OLD.id::text),'[]'::jsonb)),'{final_members}',coalesce((SELECT jsonb_agg(x)FROM jsonb_array_elements(coalesce(legacy_snapshot->'final_members','[]'::jsonb))x WHERE x->>'user_id' IS DISTINCT FROM OLD.id::text),'[]'::jsonb)),legacy_decisions=coalesce((SELECT jsonb_agg(x)FROM jsonb_array_elements(legacy_decisions)x WHERE x->>'user_id' IS DISTINCT FROM OLD.id::text),'[]'::jsonb) WHERE singleton;
 RETURN OLD;
END $$;
CREATE TRIGGER competition_delete_identity BEFORE DELETE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public._competition_purge_deleted_identity();
CREATE FUNCTION public._competition_segment(p_user uuid,p_month date) RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$ SELECT coalesce((SELECT h.segment FROM public.competition_target_history h WHERE h.user_id=p_user AND h.from_month<=p_month ORDER BY h.from_month DESC LIMIT 1),(SELECT coalesce(p.user_segment,'other') FROM public.profiles p WHERE p.id=p_user),'other') $$;
CREATE FUNCTION public._competition_track_target() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_month date:=public._competition_month(clock_timestamp());
BEGIN
 IF TG_OP='UPDATE' AND NEW.user_segment IS NOT DISTINCT FROM OLD.user_segment THEN RETURN NEW; END IF;
 IF coalesce(NEW.lifetime_points,0)>0 OR NEW.active_session_ends_at>clock_timestamp() OR EXISTS(SELECT 1 FROM public.study_sessions WHERE user_id=NEW.id) OR EXISTS(SELECT 1 FROM public.exam_attempts WHERE user_id=NEW.id) THEN v_month:=(v_month+interval '1 month')::date; END IF;
 INSERT INTO public.competition_target_history(user_id,from_month,segment) VALUES(NEW.id,v_month,coalesce(NEW.user_segment,'other')) ON CONFLICT(user_id,from_month) DO UPDATE SET segment=EXCLUDED.segment;
 RETURN NEW;
END $$;
CREATE TRIGGER competition_target_change AFTER INSERT OR UPDATE OF user_segment ON public.profiles FOR EACH ROW EXECUTE FUNCTION public._competition_track_target();
CREATE FUNCTION public.get_competition_target() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_month date:=public._competition_month(now());v_pending record;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 SELECT h.* INTO v_pending FROM public.competition_target_history h WHERE h.user_id=auth.uid() AND h.from_month>v_month ORDER BY h.from_month LIMIT 1;
 RETURN jsonb_build_object('current_segment',public._competition_segment(auth.uid(),v_month),'pending_segment',v_pending.segment,'effective_at',CASE WHEN v_pending.from_month IS NOT NULL THEN public._competition_month_time(v_pending.from_month) END);
END $$;
CREATE FUNCTION public.set_competition_target(p_segment text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 IF p_segment IS NOT NULL AND p_segment NOT IN('lgs','yks','tus','kpss','language','university','work','other') THEN RAISE EXCEPTION 'competition_invalid_segment'; END IF;
 PERFORM 1 FROM public.profiles WHERE id=auth.uid() FOR UPDATE;
 UPDATE public.profiles SET user_segment=nullif(p_segment,'other') WHERE id=auth.uid();
 RETURN public.get_competition_target();
END $$;
CREATE FUNCTION public._competition_place(p_user uuid,p_kind text,p_month date,p_joined timestamptz) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_segment text;v_tier integer;v_room uuid;
BEGIN
 IF EXISTS(SELECT 1 FROM public.competition_memberships WHERE user_id=p_user AND kind=p_kind AND period_month=p_month) THEN RETURN; END IF;
 v_segment:=public._competition_segment(p_user,p_month);
 INSERT INTO public.competition_profiles(user_id,kind,tier) SELECT p_user,p_kind,CASE WHEN p_kind='study' THEN league_tier ELSE 1 END FROM public.profiles WHERE id=p_user ON CONFLICT DO NOTHING;
 SELECT tier INTO v_tier FROM public.competition_profiles WHERE user_id=p_user AND kind=p_kind;
 PERFORM pg_advisory_xact_lock(hashtextextended('competition:'||p_kind||':'||p_month||':'||v_segment||':'||v_tier,0));
 SELECT r.id INTO v_room FROM public.competition_rooms r LEFT JOIN public.competition_memberships m ON m.room_id=r.id WHERE r.kind=p_kind AND r.period_month=p_month AND r.segment=v_segment AND r.tier=v_tier GROUP BY r.id HAVING count(m.user_id)<25 ORDER BY count(m.user_id) DESC,r.created_at,r.id LIMIT 1;
 IF v_room IS NULL THEN INSERT INTO public.competition_rooms(kind,period_month,segment,tier) VALUES(p_kind,p_month,v_segment,v_tier) RETURNING id INTO v_room; END IF;
 INSERT INTO public.competition_memberships(user_id,kind,period_month,room_id,joined_at) VALUES(p_user,p_kind,p_month,v_room,p_joined) ON CONFLICT DO NOTHING;
END $$;
CREATE FUNCTION public._competition_record(p_kind text,p_source uuid,p_user uuid,p_started timestamptz,p_completed timestamptz,p_minutes integer,p_points integer) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_month date:=public._competition_month(p_completed);v_day date;
BEGIN
 PERFORM 1 FROM public.profiles WHERE id=p_user FOR UPDATE;
 SELECT ((p_started AT TIME ZONE timezone)-interval '4 hours')::date INTO v_day FROM public.profiles WHERE id=p_user;
 INSERT INTO public.competition_events(kind,source_id,user_id,completed_at,period_month,points,minutes,study_day) VALUES(p_kind,p_source,p_user,p_completed,v_month,p_points,p_minutes,v_day)
 ON CONFLICT(kind,source_id) DO UPDATE SET points=EXCLUDED.points;
 IF p_points>0 THEN PERFORM public._competition_place(p_user,p_kind,v_month,p_completed); END IF;
END $$;
CREATE FUNCTION public._competition_study_event() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$ BEGIN PERFORM public._competition_record('study',NEW.id,NEW.user_id,NEW.started_at,NEW.completed_at,NEW.duration_minutes,NEW.base_points+NEW.bonus_points);RETURN NEW;END $$;
CREATE TRIGGER competition_study_accept AFTER INSERT OR UPDATE OF base_points,bonus_points ON public.study_sessions FOR EACH ROW EXECUTE FUNCTION public._competition_study_event();
CREATE FUNCTION public._competition_exam_event() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$ BEGIN IF NEW.status='completed' THEN PERFORM public._competition_record('exam',NEW.id,NEW.user_id,NEW.started_at,NEW.ends_at,(NEW.definition->>'duration_seconds')::integer/60,NEW.points_earned);END IF;RETURN NEW;END $$;
CREATE TRIGGER competition_exam_accept AFTER UPDATE OF status ON public.exam_attempts FOR EACH ROW EXECUTE FUNCTION public._competition_exam_event();
-- Existing month records are preserved as monthly events; no profile economy update.
DO $$ DECLARE r record;BEGIN FOR r IN SELECT * FROM public.study_sessions WHERE completed_at>=public._competition_month_time(public._competition_month(now())) ORDER BY completed_at,id LOOP PERFORM public._competition_record('study',r.id,r.user_id,r.started_at,r.completed_at,r.duration_minutes,r.base_points+r.bonus_points);END LOOP; FOR r IN SELECT * FROM public.exam_attempts WHERE status='completed' LOOP PERFORM public._competition_record('exam',r.id,r.user_id,r.started_at,r.ends_at,(r.definition->>'duration_seconds')::integer/60,r.points_earned);END LOOP;END $$;
CREATE FUNCTION public._competition_room_rows(p_room uuid) RETURNS TABLE(user_id uuid,points bigint,minutes bigint,days integer,rank_position bigint,joined_at timestamptz,active_count integer,member_count integer,tier integer)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 WITH totals AS(SELECT e.user_id,sum(e.points)points,sum(e.minutes)minutes,count(DISTINCT e.study_day)::integer days FROM public.competition_events e JOIN public.competition_rooms room ON room.id=p_room AND room.kind=e.kind AND room.period_month=e.period_month GROUP BY e.user_id),base AS(SELECT m.user_id,coalesce(t.points,0)::bigint points,coalesce(t.minutes,0)::bigint minutes,coalesce(t.days,0)days,m.joined_at,r.tier FROM public.competition_memberships m JOIN public.competition_rooms r ON r.id=m.room_id LEFT JOIN totals t ON t.user_id=m.user_id WHERE m.room_id=p_room)
 SELECT b.user_id,b.points,b.minutes,b.days,row_number() OVER(ORDER BY b.points DESC,b.joined_at,b.user_id),b.joined_at,(count(*) FILTER(WHERE b.minutes>0) OVER())::integer,(count(*) OVER())::integer,b.tier FROM base b
$$;
CREATE FUNCTION public.get_monthly_league_ranking(p_kind text DEFAULT 'study',p_scope text DEFAULT 'segment') RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_uid uuid:=auth.uid();v_month date:=public._competition_month(now());v_start timestamptz:=public._competition_month_time(v_month);v_end timestamptz:=public._competition_month_time((v_month+interval '1 month')::date);v_target jsonb;v_room uuid;v_tier integer;v_rows jsonb;v_activation timestamptz;v_active integer:=0;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
 IF p_kind IS NULL OR p_scope IS NULL OR p_kind NOT IN('study','exam') OR p_scope NOT IN('segment','global') THEN RAISE EXCEPTION 'competition_invalid_scope'; END IF;
 SELECT activates_at INTO v_activation FROM public.competition_policy WHERE singleton;
 v_target:=public.get_competition_target();
 SELECT cp.tier INTO v_tier FROM public.competition_profiles cp WHERE cp.user_id=v_uid AND cp.kind=p_kind;
 v_tier:=coalesce(v_tier,CASE WHEN p_kind='study' THEN(SELECT league_tier FROM public.profiles WHERE id=v_uid)ELSE 1 END,1);
 IF p_scope='segment' THEN
  SELECT room_id INTO v_room FROM public.competition_memberships WHERE user_id=v_uid AND kind=p_kind AND period_month=v_month;
  IF v_room IS NOT NULL THEN
   SELECT max(active_count) INTO v_active FROM public._competition_room_rows(v_room);
   SELECT coalesce(jsonb_agg(jsonb_build_object('id',CASE WHEN p.id=v_uid OR(p.show_in_social_feed AND b.blocked_id IS NULL)THEN p.id END,'name',CASE WHEN p.id=v_uid OR(p.show_in_social_feed AND b.blocked_id IS NULL)THEN p.name END,'avatar_id',CASE WHEN p.id=v_uid OR(p.show_in_social_feed AND b.blocked_id IS NULL)THEN p.avatar_id END,'is_me',p.id=v_uid,'is_blocked',b.blocked_id IS NOT NULL,'points',r.points,'weekly_points',r.points,'rank',r.rank_position,'tier',r.tier,'end_date',v_end-interval '1 microsecond','has_league',true,'member_count',r.member_count,'active_member_count',r.active_count,'promotion_zone_end',CASE WHEN r.active_count>=3 THEN r.active_count/3 ELSE 0 END,'demotion_zone_start',CASE WHEN r.active_count>=10 THEN r.member_count-r.active_count/3+1 ELSE 999 END,
   'promotion_eligible',now()>=v_activation AND r.active_count>=3 AND r.rank_position<=r.active_count/3 AND r.points>0 AND r.days>=3 AND r.minutes>=300 AND r.tier<5,
   'award_eligible',now()>=v_activation AND r.active_count>=10 AND r.rank_position<=3 AND r.points>0 AND r.days>=3 AND r.minutes>=300 AND EXISTS(SELECT 1 FROM public.competition_avatar_rewards ar WHERE ar.kind=p_kind AND ar.tier=r.tier AND ar.rank_position=r.rank_position AND ar.avatar_id IS NOT NULL),
   'demotion_eligible',now()>=v_activation AND r.active_count>=10 AND r.rank_position>r.member_count-r.active_count/3 AND r.tier>1 AND r.joined_at<=v_end-interval '72 hours') ORDER BY r.rank_position),'[]'::jsonb)
   INTO v_rows FROM public._competition_room_rows(v_room)r JOIN public.profiles p ON p.id=r.user_id LEFT JOIN LATERAL(SELECT p.id AS blocked_id WHERE EXISTS(SELECT 1 FROM public.user_blocks ub WHERE(ub.blocker_id=v_uid AND ub.blocked_id=p.id)OR(ub.blocker_id=p.id AND ub.blocked_id=v_uid)))b ON true;
  END IF;
 ELSE
  WITH totals AS(SELECT e.user_id,sum(e.points)::bigint points,sum(e.minutes)::bigint minutes FROM public.competition_events e WHERE e.kind=p_kind AND e.period_month=v_month GROUP BY e.user_id),visible AS(SELECT p.id,p.name,p.avatar_id,t.points,t.minutes,row_number()OVER(ORDER BY t.points DESC,t.minutes DESC,p.id)rank_position FROM totals t JOIN public.profiles p ON p.id=t.user_id WHERE p.show_in_social_feed AND NOT EXISTS(SELECT 1 FROM public.user_blocks b WHERE(b.blocker_id=v_uid AND b.blocked_id=p.id)OR(b.blocker_id=p.id AND b.blocked_id=v_uid)))
  SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'avatar_id',avatar_id,'points',points,'weekly_points',points,'rank',rank_position,'tier',v_tier,'is_me',id=v_uid,'is_blocked',false,'has_league',true,'end_date',v_end-interval '1 microsecond','promotion_eligible',false,'award_eligible',false,'demotion_eligible',false)ORDER BY rank_position),'[]'::jsonb),count(*)::integer INTO v_rows,v_active FROM(SELECT * FROM visible ORDER BY rank_position LIMIT 100)q;
 END IF;
 IF v_rows IS NULL OR v_rows='[]'::jsonb THEN
  SELECT jsonb_build_array(jsonb_build_object('id',id,'name',name,'avatar_id',avatar_id,'points',0,'weekly_points',0,'rank',1,'tier',v_tier,'is_me',true,'is_blocked',false,'has_league',false,'member_count',0,'active_member_count',0,'end_date',v_end-interval '1 microsecond','promotion_zone_end',0,'demotion_zone_start',999,'promotion_eligible',false,'award_eligible',false,'demotion_eligible',false)) INTO v_rows FROM public.profiles WHERE id=v_uid;
 END IF;
 RETURN jsonb_build_object('schema_version',1,'server_time',clock_timestamp(),'kind',p_kind,'scope',p_scope,'segment',v_target->'current_segment','pending_segment',v_target->'pending_segment','segment_effective_at',v_target->'effective_at','tier',v_tier,'period_start',v_start,'period_end',v_end,'competition_phase',CASE WHEN now()<v_activation OR v_active<3 THEN 'preparing' ELSE 'active' END,'competition_starts_at',v_activation,'room_capacity',25,'exam_coins',coalesce((SELECT coins FROM public.exam_wallets WHERE user_id=v_uid),0),'rows',v_rows);
END $$;
CREATE FUNCTION public.get_my_exam_league_ranking(p_scope text DEFAULT 'segment') RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$ SELECT public.get_monthly_league_ranking('exam',p_scope) $$;
CREATE OR REPLACE FUNCTION public.get_my_league_ranking_v2() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT coalesce(jsonb_agg(r||jsonb_build_object('competition_phase',s->'competition_phase','competition_starts_at',s->'competition_starts_at','room_capacity',25,'league_config',public.get_league_config())),'[]'::jsonb) FROM(SELECT public.get_monthly_league_ranking('study','segment')s)q CROSS JOIN LATERAL jsonb_array_elements(s->'rows')r
$$;
CREATE OR REPLACE FUNCTION public.get_league_ranking(p_user_id uuid)
RETURNS TABLE(name text,avatar_id text,weekly_points integer,tier integer,end_date timestamptz,is_me boolean,promotion_zone_end integer,demotion_zone_start integer,member_count integer,id uuid,is_blocked boolean)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF p_user_id IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'not authorized';END IF;
 RETURN QUERY SELECT r.name,r.avatar_id,r.weekly_points,r.tier,r.end_date,r.is_me,r.promotion_zone_end,r.demotion_zone_start,r.member_count,r.id,r.is_blocked FROM jsonb_to_recordset(public.get_my_league_ranking_v2())r(name text,avatar_id text,weekly_points integer,tier integer,end_date timestamptz,is_me boolean,promotion_zone_end integer,demotion_zone_start integer,member_count integer,id uuid,is_blocked boolean);
END $$;
CREATE OR REPLACE FUNCTION public.get_my_league_ranking()
RETURNS TABLE(name text,avatar_id text,weekly_points integer,tier integer,end_date timestamptz,is_me boolean,promotion_zone_end integer,demotion_zone_start integer,member_count integer,id uuid,is_blocked boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$ SELECT * FROM public.get_league_ranking(auth.uid()) $$;
CREATE OR REPLACE FUNCTION public.get_league_config() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT jsonb_build_object('policy_version',2,'period_kind','calendar_month','period_timezone','Europe/Istanbul','reset_hour',0,'period_start',public._competition_month_time(public._competition_month(now())),'period_end',public._competition_month_time((public._competition_month(now())+interval '1 month')::date),'server_time',clock_timestamp(),'league_room_capacity',25,'league_launch_min_active_users',3,'league_promotion_min_active_members',3,'league_qualification_min_days',3,'league_qualification_min_minutes',300,'league_award_min_members',10,'league_award_min_points',1,'league_promotion_min_points',1,'competition_phase',CASE WHEN now()<activates_at THEN 'preparing' ELSE 'active' END,'competition_starts_at',activates_at) FROM public.competition_policy WHERE singleton
$$;
CREATE FUNCTION public.get_public_monthly_competition(p_limit integer DEFAULT 10) RETURNS TABLE(name text,avatar_id text,total_points bigint,total_minutes bigint,period_end timestamptz)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT public.mask_public_name(p.name),p.avatar_id,sum(e.points)::bigint,sum(e.minutes)::bigint,public._competition_month_time((public._competition_month(now())+interval '1 month')::date)
 FROM public.competition_events e JOIN public.profiles p ON p.id=e.user_id WHERE e.kind='study' AND e.period_month=public._competition_month(now()) AND p.show_in_social_feed GROUP BY p.id,p.name,p.avatar_id ORDER BY 3 DESC,4 DESC,p.id LIMIT greatest(0,least(coalesce(p_limit,10),10))
$$;
CREATE OR REPLACE FUNCTION public.get_public_monthly_leaderboard(p_limit integer DEFAULT 10) RETURNS TABLE(name text,avatar_id text,total_points integer,total_minutes integer,is_me boolean,id uuid,is_blocked boolean)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT CASE WHEN auth.uid() IS NULL THEN public.mask_public_name(p.name)WHEN b.blocked_id IS NOT NULL THEN NULL ELSE p.name END,CASE WHEN b.blocked_id IS NOT NULL THEN NULL ELSE p.avatar_id END,sum(e.points)::integer,sum(e.minutes)::integer,coalesce(p.id=auth.uid(),false),CASE WHEN auth.uid() IS NOT NULL THEN p.id END,b.blocked_id IS NOT NULL
 FROM public.competition_events e JOIN public.profiles p ON p.id=e.user_id LEFT JOIN LATERAL(SELECT p.id AS blocked_id WHERE EXISTS(SELECT 1 FROM public.user_blocks ub WHERE(ub.blocker_id=auth.uid() AND ub.blocked_id=p.id)OR(ub.blocker_id=p.id AND ub.blocked_id=auth.uid())))b ON true WHERE e.kind='study' AND e.period_month=public._competition_month(now()) AND p.show_in_social_feed GROUP BY p.id,p.name,p.avatar_id,b.blocked_id ORDER BY 3 DESC,4 DESC,p.id LIMIT CASE WHEN auth.uid() IS NULL THEN greatest(0,least(coalesce(p_limit,10),10))ELSE greatest(0,least(coalesce(p_limit,10),100))END
$$;
-- Legacy rollover remains private for the transition month only. The new
-- scheduler never interprets normal study-day 04:00 as a month boundary.
CREATE FUNCTION public._competition_finalize_legacy() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE pol public.competition_policy%ROWTYPE;st public.league_competition_state%ROWTYPE;room record;r record;v_start timestamptz;v_tier integer;v_award text;v_decisions jsonb:='[]'::jsonb;
BEGIN
 SELECT * INTO pol FROM public.competition_policy WHERE singleton FOR UPDATE;
 IF pol.legacy_finalized OR now()<pol.activates_at THEN RETURN; END IF;
 SELECT * INTO st FROM public.league_competition_state WHERE singleton;
 v_start:=coalesce(st.period_started_at,st.start_at);
 IF v_start IS NOT NULL AND v_start<pol.activates_at THEN
 FOR room IN SELECT id,tier FROM public.leagues WHERE is_active ORDER BY id LOOP
  FOR r IN WITH a AS(SELECT * FROM public._league_period_activity(v_start,pol.activates_at)),base AS(SELECT m.user_id,m.joined_at,coalesce(a.points,0)points,coalesce(a.focus_minutes,0)minutes,coalesce(a.study_days,0)days FROM public.league_memberships m LEFT JOIN a ON a.user_id=m.user_id WHERE m.league_id=room.id) SELECT *,row_number()OVER(ORDER BY points DESC,joined_at,user_id)rank_position,count(*)FILTER(WHERE minutes>0)OVER()active_count,count(*)OVER()member_count FROM base LOOP
   v_tier:=room.tier;v_award:=NULL;
   IF r.active_count>=3 AND r.rank_position<=r.active_count/3 AND r.points>0 AND r.days>=3 AND r.minutes>=300 THEN v_tier:=least(5,room.tier+1);
   ELSIF r.active_count>=10 AND r.rank_position>r.member_count-r.active_count/3 AND r.joined_at<=pol.activates_at-interval '72 hours' THEN v_tier:=greatest(1,room.tier-1);END IF;
   IF r.active_count>=10 AND r.rank_position<=3 AND r.points>0 AND r.days>=3 AND r.minutes>=300 THEN v_award:=public.league_award_avatar_id(room.tier,r.rank_position::integer);END IF;
   IF v_award IS NOT NULL THEN INSERT INTO public.avatar_unlocks(user_id,avatar_id,unlock_type,coins_spent)VALUES(r.user_id,v_award,'league_award',0)ON CONFLICT(user_id,avatar_id)DO NOTHING;END IF;
   UPDATE public.profiles SET league_tier=v_tier WHERE id=r.user_id;
   UPDATE public.competition_profiles SET tier=v_tier WHERE user_id=r.user_id AND kind='study';
   v_decisions:=v_decisions||jsonb_build_array(jsonb_build_object('user_id',r.user_id,'rank',r.rank_position,'from_tier',room.tier,'to_tier',v_tier,'award_id',v_award,'points',r.points));
  END LOOP;
 END LOOP;
 END IF;
 UPDATE public.competition_policy SET legacy_finalized=true,legacy_decisions=v_decisions,legacy_snapshot=legacy_snapshot||jsonb_build_object('finalized_at',clock_timestamp(),'final_state',jsonb_build_object('start_at',st.start_at,'initialized',st.initialized,'period_started_at',st.period_started_at),'final_members',coalesce((SELECT jsonb_agg(to_jsonb(m))FROM public.league_memberships m),'[]'::jsonb)) WHERE singleton;
END $$;
CREATE FUNCTION public._competition_repack_current() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE m record;
BEGIN
 FOR m IN SELECT cm.* FROM public.competition_memberships cm JOIN public.competition_rooms r ON r.id=cm.room_id JOIN public.competition_profiles cp ON cp.user_id=cm.user_id AND cp.kind=cm.kind WHERE cm.period_month=public._competition_month(now()) AND r.tier<>cp.tier ORDER BY cm.user_id,cm.kind LOOP
  DELETE FROM public.competition_memberships WHERE user_id=m.user_id AND kind=m.kind AND period_month=m.period_month;
  PERFORM public._competition_place(m.user_id,m.kind,m.period_month,m.joined_at);
 END LOOP;
END $$;
CREATE FUNCTION public.process_monthly_competitions() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE pol public.competition_policy%ROWTYPE;v_month date;v_end timestamptz;room record;r record;v_tier integer;v_award text;
BEGIN
 -- D-03: ordinary daily runs need no profile locks. Check immutable month
 -- boundaries and completed-period records before entering the global lock.
 SELECT * INTO pol FROM public.competition_policy WHERE singleton;
 IF NOT FOUND THEN RETURN; END IF;
 IF (pol.legacy_finalized OR now()<pol.activates_at) AND NOT EXISTS(
  SELECT 1 FROM generate_series(public._competition_month(pol.activates_at)::timestamp,
   (public._competition_month(now())-interval '1 month')::timestamp,interval '1 month') due(month)
  WHERE NOT EXISTS(SELECT 1 FROM public.competition_periods done WHERE done.period_month=due.month::date)
 ) THEN RETURN; END IF;
 -- Same lock order as normal completion: profiles first, then competition locks.
 PERFORM 1 FROM public.profiles ORDER BY id FOR UPDATE;
 PERFORM pg_advisory_xact_lock(71028003);
 -- Another worker may have finished while this one waited: recheck under lock.
 SELECT * INTO pol FROM public.competition_policy WHERE singleton;
 IF NOT FOUND THEN RETURN; END IF;
 IF (pol.legacy_finalized OR now()<pol.activates_at) AND NOT EXISTS(
  SELECT 1 FROM generate_series(public._competition_month(pol.activates_at)::timestamp,
   (public._competition_month(now())-interval '1 month')::timestamp,interval '1 month') due(month)
  WHERE NOT EXISTS(SELECT 1 FROM public.competition_periods done WHERE done.period_month=due.month::date)
 ) THEN RETURN; END IF;
 PERFORM public._competition_finalize_legacy();
 SELECT * INTO pol FROM public.competition_policy WHERE singleton;
 v_month:=public._competition_month(pol.activates_at);
 WHILE v_month<public._competition_month(now()) LOOP
 IF NOT EXISTS(SELECT 1 FROM public.competition_periods WHERE period_month=v_month) THEN
  v_end:=public._competition_month_time((v_month+interval '1 month')::date);
  FOR room IN SELECT * FROM public.competition_rooms WHERE period_month=v_month ORDER BY kind,segment,tier,id LOOP
   FOR r IN SELECT * FROM public._competition_room_rows(room.id) ORDER BY rank_position LOOP
    v_tier:=room.tier;v_award:=NULL;
    IF r.active_count>=3 AND r.rank_position<=r.active_count/3 AND r.points>0 AND r.days>=3 AND r.minutes>=300 THEN v_tier:=least(5,room.tier+1);
    ELSIF r.active_count>=10 AND r.rank_position>r.member_count-r.active_count/3 AND r.joined_at<=v_end-interval '72 hours' THEN v_tier:=greatest(1,room.tier-1); END IF;
    IF r.active_count>=10 AND r.rank_position<=3 AND r.points>0 AND r.days>=3 AND r.minutes>=300 THEN SELECT avatar_id INTO v_award FROM public.competition_avatar_rewards WHERE kind=room.kind AND tier=room.tier AND rank_position=r.rank_position; END IF;
    INSERT INTO public.competition_results(user_id,kind,period_month,rank,from_tier,to_tier,award_id,snapshot)VALUES(r.user_id,room.kind,v_month,r.rank_position,room.tier,v_tier,v_award,to_jsonb(r)) ON CONFLICT DO NOTHING;
    UPDATE public.competition_profiles SET tier=v_tier WHERE user_id=r.user_id AND kind=room.kind;
    IF room.kind='study' THEN UPDATE public.profiles SET league_tier=v_tier WHERE id=r.user_id;END IF;
    IF v_award IS NOT NULL THEN INSERT INTO public.avatar_unlocks(user_id,avatar_id,unlock_type,coins_spent)VALUES(r.user_id,v_award,'league_award',0)ON CONFLICT(user_id,avatar_id)DO NOTHING;END IF;
   END LOOP;
  END LOOP;
  INSERT INTO public.competition_periods VALUES(v_month,clock_timestamp());
 END IF;
 v_month:=(v_month+interval '1 month')::date;
 END LOOP;
 PERFORM public._competition_repack_current();
END $$;
-- Keep old cron function/signature. Before activation it delegates to its exact
-- archived body; afterwards only the monthly engine runs.
DO $$ DECLARE source text; BEGIN SELECT definition INTO source FROM public.competition_install_backup WHERE signature='process_weekly_leagues()'; IF source IS NULL THEN SELECT definition INTO source FROM public.competition_install_backup WHERE signature='public.process_weekly_leagues()';END IF; IF source IS NULL THEN RAISE EXCEPTION 'competition_legacy_source_missing'; END IF;EXECUTE replace(source,'FUNCTION public.process_weekly_leagues()','FUNCTION public._competition_legacy_weekly()');END $$;
CREATE OR REPLACE FUNCTION public.process_weekly_leagues() RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$ BEGIN IF now()<(SELECT activates_at FROM public.competition_policy WHERE singleton)THEN PERFORM public._competition_legacy_weekly();ELSE PERFORM public.process_monthly_competitions();END IF;END $$;
DO $$ DECLARE source text; BEGIN
 SELECT pg_get_functiondef('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)'::regprocedure) INTO source;
 IF position('    -- 8. LEAGUE POINTS' IN source)=0 OR position('    -- 9. INSERT STUDY SESSION' IN source)=0 THEN RAISE EXCEPTION 'competition_normal_source_changed';END IF;
 source:=replace(source,'    -- 8. LEAGUE POINTS','    IF clock_timestamp() < (SELECT activates_at FROM public.competition_policy WHERE singleton) THEN'||chr(10)||'    -- 8. LEAGUE POINTS');
 source:=replace(source,'    -- 9. INSERT STUDY SESSION','    ELSE'||chr(10)||'      v_league_points := CASE WHEN public._competition_month(v_ends_at)=public._competition_month(now()) THEN v_total_points ELSE 0 END;'||chr(10)||'      v_league_period_closed := public._competition_month(v_ends_at)<public._competition_month(now());'||chr(10)||'    END IF;'||chr(10)||'    -- 9. INSERT STUDY SESSION');
 EXECUTE source;
END $$;
DO $$ DECLARE source text;BEGIN SELECT definition INTO source FROM public.competition_install_backup WHERE signature IN('ensure_user_in_league(uuid,integer)','public.ensure_user_in_league(uuid,integer)');IF source IS NULL THEN RAISE EXCEPTION 'competition_legacy_ensure_missing';END IF;EXECUTE replace(source,'FUNCTION public.ensure_user_in_league(','FUNCTION public._competition_legacy_ensure_user_in_league(');END $$;
CREATE OR REPLACE FUNCTION public.ensure_user_in_league(p_user_id uuid,p_points integer) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$ BEGIN IF now()<(SELECT activates_at FROM public.competition_policy WHERE singleton)THEN PERFORM public._competition_legacy_ensure_user_in_league(p_user_id,p_points);END IF;END $$;
-- Daily at 00:01 Istanbul; harmless idempotent no-op outside rollover.
SELECT cron.schedule('weekly_leagues_job','1 21 * * *','SELECT public.process_weekly_leagues();');
DO $$ DECLARE r regprocedure; BEGIN FOR r IN SELECT p.oid::regprocedure FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND(p.proname LIKE '\_competition\_%' ESCAPE '\' OR p.proname IN('process_monthly_competitions','get_monthly_league_ranking','get_my_exam_league_ranking','get_public_monthly_competition','get_competition_target','set_competition_target')) LOOP EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role',r);END LOOP;END $$;
GRANT EXECUTE ON FUNCTION public.get_monthly_league_ranking(text,text),public.get_my_exam_league_ranking(text),public.get_competition_target(),public.set_competition_target(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_monthly_competition(integer) TO anon,authenticated;
INSERT INTO supabase_migrations.schema_migrations(version,name)VALUES('20261028030000','monthly_competitions');
NOTIFY pgrst,'reload schema';
COMMIT;
