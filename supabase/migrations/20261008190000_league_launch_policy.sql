-- 8 Ekim 2026: 25 kişilik odalar, hazırlık ve sunucuda doğrulanan rekabet.
-- Canlı gövdeler: analiz/qa_evidence_20261008/league_launch/baseline.json.
-- Tek atomik işlem. Önce eşlik eden DRYRUN ve rollback rehberini okuyun.
BEGIN;
DO $pre$
DECLARE r record;
BEGIN
 FOR r IN SELECT * FROM (VALUES
  ('public.ensure_user_in_league(uuid,integer)','8fd1f1a6fa0af892c73a8f37456ee29d'),
  ('public.process_weekly_leagues()','094ff2f6076341f33cf6cbabad297cae'),
  ('public.get_league_ranking(uuid)','b49f8d84ac55437f1d45ea7dcab362ea'),
  ('public.get_league_zones(integer)','a6f397d1030391e2913e87ed681f2009'),
  ('public.get_my_league_ranking()','a6e5ec04783800080c36b03704c4e320'),
  ('public.league_membership_period_start()','622780658a08efaf2484342395bd7743'),
  ('public.league_period_rollover()','a42801cb6e19c6d77d3f401c8950e1ca'),
  ('public.app_config_int(text)','832edcc3fca0de4871dc456775e63e34'),
  ('public.league_award_avatar_id(integer,integer)','f6ed7f1c88a233f1a08bc67713b886e6'),
  ('public.complete_study_session(uuid,uuid,integer,boolean,integer,timestamptz)','f0f2b9bcc09ae8440a66d889b5f22fcc'),
  ('public.complete_marathon_study_session(uuid,uuid,integer,boolean,integer,timestamptz,uuid,integer,integer)','177a238a9aa8a4ffd3738b2865120568')
 ) f(signature, expected) LOOP
  IF md5(pg_get_functiondef(r.signature::regprocedure)) IS DISTINCT FROM r.expected THEN
   RAISE EXCEPTION 'league_launch_policy ön koşulu: % güncel canlı gövdesi değişti.',r.signature;
  END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM public.league_memberships m JOIN public.leagues l ON l.id=m.league_id AND l.is_active
           GROUP BY m.user_id HAVING count(*)>1) THEN
  RAISE EXCEPTION 'league_launch_policy: mükerrer aktif üyelik önce incelenmeli.';
 END IF;
END $pre$;

CREATE TABLE public.league_competition_state (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
 start_at timestamptz,
 initialized boolean NOT NULL DEFAULT false,
 period_started_at timestamptz,
 applied_at timestamptz NOT NULL DEFAULT now(),
 rollback_snapshot jsonb NOT NULL,
 CHECK((initialized AND start_at IS NOT NULL AND period_started_at IS NOT NULL) OR NOT initialized)
);
ALTER TABLE public.league_competition_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.league_competition_state FROM PUBLIC,anon,authenticated,service_role;
INSERT INTO public.league_competition_state(singleton,rollback_snapshot)
SELECT true,jsonb_build_object(
 'config',COALESCE((SELECT jsonb_agg(to_jsonb(c)) FROM public.app_config c WHERE c.key IN
  ('league_room_capacity','league_launch_min_active_users','league_promotion_min_active_members',
   'league_qualification_min_days','league_qualification_min_minutes','league_award_min_members',
   'league_award_min_points','league_promotion_min_points')),'[]'::jsonb),
 'leagues',COALESCE((SELECT jsonb_agg(to_jsonb(l)) FROM public.leagues l),'[]'::jsonb),
 'memberships',COALESCE((SELECT jsonb_agg(to_jsonb(m)) FROM public.league_memberships m),'[]'::jsonb));

INSERT INTO public.app_config(key,value,is_public,description) VALUES
 ('league_room_capacity','25',true,'Lig odası üst sınırı; başlangıç 25, güvenli aralık 3–30.'),
 ('league_launch_min_active_users','25',true,'Son 14 günde seans tamamlayan farklı kullanıcı sayısı; sonraki tam döneme başlangıç.'),
 ('league_promotion_min_active_members','3',true,'Terfi için odadaki en az aktif rakip sayısı.'),
 ('league_qualification_min_days','3',true,'Terfi/avatar için dönem içinde en az farklı çalışma günü (kullanıcı saat dilimi, 04:00).'),
 ('league_qualification_min_minutes','300',true,'Terfi/avatar için dönem içinde en az tamamlanmış odak dakikası.'),
 ('league_award_min_members','10',true,'Avatar ödülü için odadaki en az aktif rakip sayısı.'),
 ('league_award_min_points','1',true,'Avatar ödülü için en az dönem puanı.'),
 ('league_promotion_min_points','1',true,'Terfi için en az dönem puanı.')
ON CONFLICT(key) DO UPDATE SET value=EXCLUDED.value,is_public=EXCLUDED.is_public,
 description=EXCLUDED.description,updated_at=now();

CREATE FUNCTION public._league_policy_int(p_key text,p_default integer,p_min integer,p_max integer)
RETURNS integer LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT greatest(p_min,least(p_max,coalesce(public.app_config_int(p_key),p_default)))
$$;
CREATE FUNCTION public._league_grid_start(p_at timestamptz)
RETURNS timestamptz LANGUAGE sql IMMUTABLE SET search_path=public,pg_temp AS $$
 SELECT timestamptz '2026-10-12 00:00:00 Europe/Istanbul'
   + floor(extract(epoch FROM (p_at-timestamptz '2026-10-12 00:00:00 Europe/Istanbul'))/1209600)
     * interval '336 hours'
$$;

-- Seans INSERT'inden sonra yalnız başlangıç durumu değişir; başka profil veya
-- üyelik kilitlenmez. Profil→durum sırası cron ile de aynıdır.
CREATE FUNCTION public._league_refresh_start()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_start timestamptz;v_needed integer;
BEGIN
 SELECT start_at INTO v_start FROM public.league_competition_state WHERE singleton;
 IF v_start IS NOT NULL THEN RETURN; END IF;
 SELECT start_at INTO v_start FROM public.league_competition_state WHERE singleton FOR UPDATE;
 IF v_start IS NOT NULL THEN RETURN; END IF;
 v_needed:=public._league_policy_int('league_launch_min_active_users',25,3,1000000);
 IF (SELECT count(*) FROM (SELECT s.user_id FROM public.study_sessions s
    WHERE s.completed_at>=now()-interval '336 hours' AND s.completed_at<=now()
      AND s.duration_minutes IN(25,50) GROUP BY s.user_id LIMIT v_needed) q)>=v_needed THEN
  v_start:=greatest(timestamptz '2026-10-12 00:00:00 Europe/Istanbul',
                   public._league_grid_start(now())+interval '336 hours');
  UPDATE public.league_competition_state SET start_at=v_start WHERE singleton;
 END IF;
END $$;
CREATE FUNCTION public._league_after_completed_session()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN PERFORM public._league_refresh_start();RETURN NULL;END $$;
CREATE TRIGGER league_schedule_after_completed_session AFTER INSERT ON public.study_sessions
 FOR EACH ROW EXECUTE FUNCTION public._league_after_completed_session();

-- Tek kabul edilmiş seans tablosu gerçek dakika/gün ve puanın kaynağıdır.
-- Maraton bonusu son seansın bonus_points kolonunda zaten vardır; ikinci kez eklenmez.
-- Günlük ödül sınırı yüzünden sıfır puanlı gerçek seans da aktiflik/dakika sayılır.
CREATE FUNCTION public._league_period_activity(p_start timestamptz,p_end timestamptz)
RETURNS TABLE(user_id uuid,focus_minutes bigint,study_days integer,points bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT s.user_id,sum(s.duration_minutes)::bigint,
  count(DISTINCT ((coalesce(s.started_at,s.completed_at-make_interval(mins=>s.duration_minutes))
   AT TIME ZONE p.timezone)-interval '4 hours')::date)::integer,
  sum(s.base_points+s.bonus_points)::bigint
 FROM public.study_sessions s JOIN public.profiles p ON p.id=s.user_id
 WHERE s.completed_at>=p_start AND s.completed_at<p_end AND s.completed_at<=now()
   AND s.duration_minutes IN(25,50)
 GROUP BY s.user_id
$$;

CREATE FUNCTION public.get_league_config()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT jsonb_build_object('policy_version',1,'server_time',now(),
  'league_room_capacity',public._league_policy_int('league_room_capacity',25,3,30),
  'league_launch_min_active_users',public._league_policy_int('league_launch_min_active_users',25,3,1000000),
  'league_promotion_min_active_members',public._league_policy_int('league_promotion_min_active_members',3,3,30),
  'league_qualification_min_days',public._league_policy_int('league_qualification_min_days',3,1,14),
  'league_qualification_min_minutes',public._league_policy_int('league_qualification_min_minutes',300,1,20160),
  'league_award_min_members',public._league_policy_int('league_award_min_members',10,3,30),
  'league_award_min_points',public._league_policy_int('league_award_min_points',1,1,2147483647),
  'league_promotion_min_points',public._league_policy_int('league_promotion_min_points',1,1,2147483647),
  'competition_phase',CASE WHEN s.start_at IS NULL THEN 'preparing' WHEN now()<s.start_at THEN 'scheduled' ELSE 'active' END,
  'competition_starts_at',s.start_at)
 FROM public.league_competition_state s WHERE singleton
$$;

CREATE OR REPLACE FUNCTION public.get_league_zones(p_member_count integer)
RETURNS TABLE(promotion_zone_end integer,demotion_zone_start integer)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT CASE WHEN coalesce(p_member_count,0)>=public._league_policy_int('league_promotion_min_active_members',3,3,30)
             THEN greatest(p_member_count,0)/3 ELSE 0 END,
        CASE WHEN coalesce(p_member_count,0)>=10 THEN p_member_count-p_member_count/3+1 ELSE 999 END
$$;

-- Tek resmi dönem başlangıcı: hazırlıkta puanlar korunur. Resmi dönemlerde
-- hesap sunucu seanslarından yapılır; gecikmiş cron eski puanı yeni döneme taşımaz.
CREATE FUNCTION public._league_ranking_rows(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_league uuid;v_tier integer;v_end timestamptz;v_start timestamptz;v_next timestamptz;
 v_phase text;v_competition_start timestamptz;v_count integer;v_active integer;v_promo integer;v_demo integer;v_result jsonb;
BEGIN
 IF p_user_id IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'not authorized'; END IF;
 SELECT s.start_at INTO v_competition_start FROM public.league_competition_state s WHERE singleton;
 v_phase:=CASE WHEN v_competition_start IS NULL THEN 'preparing' WHEN now()<v_competition_start THEN 'scheduled' ELSE 'active' END;
 v_start:=CASE WHEN v_phase='active' THEN public._league_grid_start(now()) ELSE NULL END;
 v_next:=CASE WHEN v_start IS NOT NULL THEN v_start+interval '336 hours'
              ELSE coalesce(v_competition_start,public._league_grid_start(now())+interval '336 hours') END;
 SELECT l.id,l.tier,l.end_date INTO v_league,v_tier,v_end
 FROM public.league_memberships m JOIN public.leagues l ON l.id=m.league_id AND l.is_active
 WHERE m.user_id=p_user_id LIMIT 1;
 IF v_league IS NULL THEN
  SELECT p.league_tier INTO v_tier FROM public.profiles p WHERE p.id=p_user_id;
  RETURN coalesce((SELECT jsonb_agg(jsonb_build_object('name',p.name,'avatar_id',p.avatar_id,
   'weekly_points',0,'tier',v_tier,'end_date',v_next-interval '1 microsecond','is_me',true,
   'promotion_zone_end',0,'demotion_zone_start',999,'member_count',0,'id',p.id,'is_blocked',false,
   'has_league',false,'active_member_count',0,'competition_phase',v_phase,'competition_starts_at',v_competition_start,
   'room_capacity',public._league_policy_int('league_room_capacity',25,3,30),
   'league_config',public.get_league_config(),
   'promotion_eligible',false,'award_eligible',false,'demotion_eligible',false))
   FROM public.profiles p WHERE p.id=p_user_id),'[]'::jsonb);
 END IF;
 SELECT count(*)::integer INTO v_count FROM public.league_memberships WHERE league_id=v_league;
 SELECT count(*)::integer INTO v_active FROM public.league_memberships m
 JOIN public._league_period_activity(coalesce(v_start,now()-interval '336 hours'),coalesce(v_next,now()+interval '1 microsecond')) a ON a.user_id=m.user_id
 WHERE m.league_id=v_league;
 SELECT z.promotion_zone_end,z.demotion_zone_start INTO v_promo,v_demo FROM public.get_league_zones(v_active) z;
 IF v_phase<>'active' THEN v_promo:=0;v_demo:=999;END IF;
 -- Düşme sınırı tüm üyelerin ham sırasındadır; kontenjan aktif rakiplerden gelir.
 IF v_active>=10 AND v_phase='active' THEN v_demo:=v_count-v_active/3+1;END IF;
 WITH activity AS MATERIALIZED (SELECT * FROM public._league_period_activity(coalesce(v_start,now()-interval '336 hours'),v_next)),
 ranked AS (SELECT m.*,p.name,p.avatar_id,p.league_tier,
  CASE WHEN v_phase='active' THEN coalesce(a.points,0)::integer ELSE m.weekly_points+m.carry_points END AS score,
  coalesce(a.study_days,0)>=public._league_policy_int('league_qualification_min_days',3,1,14)
   AND coalesce(a.focus_minutes,0)>=public._league_policy_int('league_qualification_min_minutes',300,1,20160) AS qualified
  FROM public.league_memberships m JOIN public.profiles p ON p.id=m.user_id
  LEFT JOIN activity a ON a.user_id=m.user_id WHERE m.league_id=v_league),
 positioned AS (SELECT r.*,row_number() OVER(ORDER BY score DESC,joined_at,user_id)::integer AS position FROM ranked r),
 eligibility AS (SELECT r.*,
  v_phase='active' AND v_tier<5 AND r.position<=v_promo AND r.qualified
   AND r.score>=public._league_policy_int('league_promotion_min_points',1,1,2147483647) AS promo,
  v_phase='active' AND v_active>=public._league_policy_int('league_award_min_members',10,3,30)
   AND r.position<=3 AND r.qualified AND r.score>=public._league_policy_int('league_award_min_points',1,1,2147483647) AS award,
  v_phase='active' AND v_tier>1 AND r.position>=v_demo AND r.joined_at<=v_next-interval '72 hours' AS demo
  FROM positioned r)
 SELECT jsonb_agg(jsonb_build_object('name',CASE WHEN b.blocked_id IS NULL THEN r.name END,
  'avatar_id',CASE WHEN b.blocked_id IS NULL THEN coalesce(CASE WHEN r.award THEN public.league_award_avatar_id(v_tier,r.position) END,r.avatar_id) END,
  'weekly_points',r.score,'tier',v_tier,'end_date',CASE WHEN v_phase='active' THEN v_next-interval '1 microsecond' ELSE greatest(v_end,v_next-interval '1 microsecond') END,
  'is_me',r.user_id=p_user_id,'promotion_zone_end',v_promo,'demotion_zone_start',v_demo,
  'member_count',v_count,'id',r.user_id,'is_blocked',b.blocked_id IS NOT NULL,'has_league',true,
  'active_member_count',v_active,'competition_phase',v_phase,'competition_starts_at',v_competition_start,
  'room_capacity',public._league_policy_int('league_room_capacity',25,3,30),
  'league_config',public.get_league_config(),
  'promotion_eligible',r.promo,'award_eligible',r.award,'demotion_eligible',r.demo) ORDER BY r.position)
 INTO v_result FROM eligibility r LEFT JOIN public.user_blocks b ON b.blocker_id=p_user_id AND b.blocked_id=r.user_id;
 RETURN coalesce(v_result,'[]'::jsonb);
END $$;

CREATE FUNCTION public.get_my_league_ranking_v2()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT CASE WHEN auth.uid() IS NULL THEN '[]'::jsonb ELSE public._league_ranking_rows(auth.uid()) END
$$;
CREATE OR REPLACE FUNCTION public.get_league_ranking(p_user_id uuid)
RETURNS TABLE(name text,avatar_id text,weekly_points integer,tier integer,end_date timestamptz,is_me boolean,
 promotion_zone_end integer,demotion_zone_start integer,member_count integer,id uuid,is_blocked boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT r.name,r.avatar_id,r.weekly_points,r.tier,r.end_date,r.is_me,r.promotion_zone_end,r.demotion_zone_start,r.member_count,r.id,r.is_blocked
 FROM jsonb_to_recordset(public._league_ranking_rows(p_user_id)) AS r(name text,avatar_id text,weekly_points integer,tier integer,
  end_date timestamptz,is_me boolean,promotion_zone_end integer,demotion_zone_start integer,member_count integer,id uuid,is_blocked boolean)
$$;

CREATE FUNCTION public._league_place_member(p_user_id uuid,p_points integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_tier integer;v_league uuid;v_membership uuid;v_start timestamptz;v_launch timestamptz;v_end timestamptz;v_capacity integer;
BEGIN
 IF p_user_id IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'not authorized';END IF;
 IF p_points IS NULL OR p_points<0 THEN RETURN;END IF;
 SELECT m.id,m.league_id INTO v_membership,v_league FROM public.league_memberships m
 JOIN public.leagues l ON l.id=m.league_id AND l.is_active WHERE m.user_id=p_user_id LIMIT 1;
 IF FOUND THEN UPDATE public.league_memberships SET weekly_points=weekly_points+p_points WHERE id=v_membership;RETURN;END IF;
 SELECT coalesce(league_tier,1) INTO v_tier FROM public.profiles WHERE id=p_user_id;
 IF v_tier IS NULL THEN RAISE EXCEPTION 'profile not found';END IF;
 PERFORM pg_advisory_xact_lock(hashtext('pomosprint_league_room'),v_tier);
 SELECT start_at INTO v_launch FROM public.league_competition_state WHERE singleton;
 v_start:=CASE WHEN v_launch IS NOT NULL AND now()>=v_launch THEN public._league_grid_start(now()) END;
 v_end:=coalesce(v_start+interval '336 hours',v_launch,public._league_grid_start(now())+interval '336 hours')-interval '1 microsecond';
 v_capacity:=public._league_policy_int('league_room_capacity',25,3,30);
 SELECT l.id INTO v_league FROM public.leagues l LEFT JOIN public.league_memberships m ON m.league_id=l.id
 WHERE l.is_active AND l.tier=v_tier
  AND (l.end_date=v_end OR NOT(SELECT initialized FROM public.league_competition_state WHERE singleton))
 GROUP BY l.id HAVING count(m.id)<v_capacity
 ORDER BY count(m.id) DESC,l.start_date,l.id LIMIT 1;
 IF v_league IS NULL THEN
  INSERT INTO public.leagues(tier,end_date) VALUES(v_tier,v_end) RETURNING id INTO v_league;
 END IF;
 INSERT INTO public.league_memberships(league_id,user_id,weekly_points,period_started_at)
 VALUES(v_league,p_user_id,p_points,CASE WHEN v_start IS NOT NULL THEN v_start-interval '1 microsecond' ELSE NULL END);
END $$;

CREATE OR REPLACE FUNCTION public.ensure_user_in_league(p_user_id uuid,p_points integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF p_user_id IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'not authorized';END IF;
 IF p_points IS NULL OR p_points<=0 THEN RETURN;END IF;
 PERFORM public._league_place_member(p_user_id,p_points);
END $$;

CREATE OR REPLACE FUNCTION public.complete_study_session(p_client_uuid uuid, p_category_id uuid, p_duration_minutes integer, p_was_paused boolean, p_is_verified integer, p_started_at timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid;
    v_base_points integer;
    v_bonus_points integer := 0;
    v_total_points integer;
    v_coins_earned integer := 20;
    v_current_streak integer;
    v_longest_streak integer;
    v_last_study_date date;
    v_user_tz text;
    v_study_day date;
    v_bonus_pct integer := 0;
    v_session_id uuid;
    v_daily_sessions integer;
    v_daily_limit_reached boolean := false;
    v_daily_minutes integer;
    v_top_category text;
    v_existing RECORD;
    v_ends_at timestamptz;
    v_is_late_session boolean := false;
    v_show_in_social_feed boolean;
    -- proposed/13
    v_started_at timestamptz;
    v_server_started_at timestamptz;
    v_start_verified boolean := false;
    v_unverified_cap integer;
    v_unverified_sessions integer;
    v_unverified_limit_reached boolean := false;
    v_period_start timestamptz;
    v_league_period_closed boolean := false;
    v_league_points integer := 0;
    -- proposed/21
    v_bonus_streak integer;
    v_membership_id uuid;
    v_league_end timestamptz;
    v_league_points_next_period boolean := false;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

    -- proposed/21 (t1-01): kullanıcı başına kilit EN BAŞTA. Aynı hesabın iki
    -- cihazdan eşzamanlı gönderdiği seanslar sırayla işlenir; tekrar
    -- (client_uuid) ve çakışma denetimleri öteki işlemin kaydını görür. Aynı
    -- client_uuid yarışı 23505 yerine duplicate:true döner.
    PERFORM 1 FROM public.profiles WHERE id = v_uid FOR UPDATE;

    -- 1. IDEMPOTENCY CHECK (client_uuid)
    SELECT * INTO v_existing FROM public.study_sessions
    WHERE client_uuid = p_client_uuid AND user_id = v_uid LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'base_points', v_existing.base_points,
            'bonus_points', v_existing.bonus_points,
            'total_points', v_existing.base_points + v_existing.bonus_points,
            'coins_earned', 0,
            'streak', (SELECT current_streak FROM public.profiles WHERE id = v_uid),
            'bonus_pct', 0,
            'duplicate', true,
            'daily_limit_reached', false
        );
    END IF;

    -- 2. VALIDATION
    IF p_duration_minutes NOT IN (25, 50) THEN
        RAISE EXCEPTION 'invalid duration: only 25 or 50 allowed';
    END IF;

    -- 2a. proposed/13 (UX-01): sunucu başlangıç kaydı. Aynı client_uuid ve
    -- süreyle kayıt var VE süre sunucu saatine göre dolmuşsa (60 sn pay)
    -- seans doğrulanmıştır; başlangıç sunucudan alınır (completed_at now()'u
    -- geçmesin diye en geç now() - süre). Aksi halde istemcinin
    -- p_started_at'i bugünkü kurallarla değerlendirilir.
    SELECT s.server_started_at INTO v_server_started_at
      FROM public.session_starts s
     WHERE s.user_id = v_uid
       AND s.client_uuid = p_client_uuid
       AND s.duration_minutes = p_duration_minutes;

    IF v_server_started_at IS NOT NULL
       AND now() >= v_server_started_at + make_interval(mins => p_duration_minutes) - interval '60 seconds' THEN
        v_start_verified := true;
        v_started_at := least(v_server_started_at, now() - make_interval(mins => p_duration_minutes));
    ELSE
        v_started_at := p_started_at;
    END IF;

    IF v_started_at IS NULL OR v_started_at > now() THEN
        RAISE EXCEPTION 'started_at cannot be in the future';
    END IF;

    IF v_started_at < now() - interval '24 hours' THEN
        RAISE EXCEPTION 'started_at is older than 24 hours';
    END IF;

    v_ends_at := v_started_at + make_interval(mins => p_duration_minutes);

    -- Seans gerçekten bitmiş olmalı (küçük saat sapması toleransı: 5 dk).
    IF v_ends_at > now() + interval '5 minutes' THEN
        RAISE EXCEPTION 'session_not_finished';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.categories
        WHERE id = p_category_id AND user_id = v_uid
    ) THEN
        RAISE EXCEPTION 'category does not belong to this user';
    END IF;

    -- 3. ÇAKIŞMA: gerçek zaman aralığıyla (completed_at = gerçek bitiş)
    IF EXISTS (
        SELECT 1 FROM public.study_sessions s
        WHERE s.user_id = v_uid
          AND s.started_at IS NOT NULL
          AND s.started_at < v_ends_at
          AND s.completed_at > v_started_at
    ) THEN
        RETURN jsonb_build_object('error', 'overlap');
    END IF;

    -- 4. BASE POINTS & STREAK
    IF p_duration_minutes = 25 THEN
        v_base_points := 5;
    ELSE
        v_base_points := 12;
    END IF;

    IF p_was_paused THEN
        v_base_points := v_base_points - ceil(v_base_points * 0.20);
    END IF;

    SELECT COALESCE(current_streak, 0), longest_streak, last_study_date,
           COALESCE(timezone, 'Europe/Istanbul'), show_in_social_feed
    INTO v_current_streak, v_longest_streak, v_last_study_date, v_user_tz, v_show_in_social_feed
    FROM public.profiles
    WHERE id = v_uid
    FOR UPDATE;

    v_study_day := ((v_started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date;

    IF v_last_study_date IS NOT NULL AND v_study_day < v_last_study_date THEN
        -- Çevrimdışı kuyruktan geç gelen eski seans: seriyi ve son
        -- çalışma gününü geri almaz.
        v_is_late_session := true;
    ELSIF v_last_study_date IS NULL THEN
        v_current_streak := 1;
    ELSIF v_last_study_date = v_study_day THEN
        NULL;
    ELSIF v_last_study_date = v_study_day - 1 THEN
        v_current_streak := v_current_streak + 1;
    ELSE
        v_current_streak := 1;
    END IF;

    IF v_current_streak > COALESCE(v_longest_streak, 0) THEN
        v_longest_streak := v_current_streak;
    END IF;

    -- 5. DAILY CEILING CHECK (16 seans) — lig puanı + lifetime_points + kum
    SELECT count(*) INTO v_daily_sessions
    FROM public.study_sessions
    WHERE user_id = v_uid
      AND ((started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date = v_study_day;

    IF v_daily_sessions >= 16 THEN
        v_daily_limit_reached := true;
    END IF;

    -- 5b. proposed/13 (UX-01): doğrulanmamış seans tavanı. null = kapalı.
    IF NOT v_start_verified THEN
        v_unverified_cap := public.app_config_int('unverified_session_daily_cap');
        IF v_unverified_cap IS NOT NULL THEN
            SELECT count(*) INTO v_unverified_sessions
            FROM public.study_sessions
            WHERE user_id = v_uid
              AND start_verified IS FALSE
              AND ((started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date = v_study_day;

            IF v_unverified_sessions >= greatest(v_unverified_cap, 0) THEN
                v_unverified_limit_reached := true;
            END IF;
        END IF;
    END IF;

    -- 6. STREAK BONUS
    -- proposed/21 (t1-05): geç gelen (önceki güne ait) seans kendi gününün
    -- serisiyle ödüllendirilir: bugünkü seri o günden bu yana kesintisizse
    -- seri - gün farkı, değilse 1 (bonus yok). Seri ve last_study_date
    -- değişmez (13'teki gibi); yanıttaki 'streak' bugünkü seridir.
    IF v_is_late_session THEN
        v_bonus_streak := greatest(1, v_current_streak - (v_last_study_date - v_study_day));
    ELSE
        v_bonus_streak := v_current_streak;
    END IF;

    IF v_bonus_streak >= 14 THEN
        v_bonus_pct := 30;
    ELSIF v_bonus_streak >= 7 THEN
        v_bonus_pct := 20;
    ELSIF v_bonus_streak >= 3 THEN
        v_bonus_pct := 10;
    ELSE
        v_bonus_pct := 0;
    END IF;

    v_bonus_points := ceil(v_base_points::numeric * v_bonus_pct / 100.0);
    v_total_points := v_base_points + v_bonus_points;

    IF v_daily_limit_reached OR v_unverified_limit_reached THEN
        v_base_points := 0;
        v_bonus_points := 0;
        v_total_points := 0;
        v_coins_earned := 0;
    END IF;

    -- 7. UPDATE PROFILES
    UPDATE public.profiles
    SET total_minutes = COALESCE(total_minutes, 0) + p_duration_minutes,
        lifetime_points = lifetime_points + v_total_points,
        coins = coins + v_coins_earned,
        current_streak = v_current_streak,
        longest_streak = v_longest_streak,
        last_study_date = CASE WHEN v_is_late_session THEN last_study_date ELSE v_study_day END
    WHERE id = v_uid;

    -- 8. LEAGUE POINTS — proposed/13: kapanmış döneme ait seans lig puanı almaz.
    IF NOT v_daily_limit_reached AND NOT v_unverified_limit_reached THEN
        SELECT COALESCE(lm.period_started_at, l.end_date - interval '14 days'), lm.id, l.end_date
          INTO v_period_start, v_membership_id, v_league_end
          FROM public.league_memberships lm
          JOIN public.leagues l ON l.id = lm.league_id
         WHERE lm.user_id = v_uid AND l.is_active = true
         LIMIT 1;

        -- league_launch_policy: ilk puanlı seans önceki resmi dönemde bitmiş
        -- olabilir. Lifetime ödülü geçerlidir, yeni dönem lig puanı değildir.
        -- Üyeliği sıfır lig puanıyla aç; günlük tavan sıfır-puanlı seansları
        -- bu bloğa hiç girmez ve ilk üyelik oluşturmaz.
        IF v_membership_id IS NULL
           AND EXISTS(SELECT 1 FROM public.league_competition_state st
                      WHERE st.singleton AND st.start_at <= now()) THEN
            v_period_start := public._league_grid_start(now()) - interval '1 microsecond';
            IF v_ends_at <= v_period_start THEN
                PERFORM public._league_place_member(v_uid, 0);
            END IF;
        END IF;

        IF v_period_start IS NOT NULL AND v_ends_at <= v_period_start THEN
            v_league_period_closed := true;
        ELSIF v_membership_id IS NOT NULL AND v_ends_at > v_league_end THEN
            -- proposed/21 (t4-F5): oda bitti ama dönem sonu henüz işlenmedi
            -- (Pazar 23:59:59 TR ile cron arası ya da kaçan cron) ve seans
            -- bitişten SONRA bitti: puan sıradaki döneme (carry_points, 20).
            UPDATE public.league_memberships
               SET carry_points = carry_points + v_total_points
             WHERE id = v_membership_id;
            v_league_points := v_total_points;
            v_league_points_next_period := true;
        ELSE
            PERFORM public.ensure_user_in_league(v_uid, v_total_points);
            v_league_points := v_total_points;
        END IF;
    END IF;

    -- 9. INSERT STUDY SESSION (completed_at = gerçek bitiş)
    INSERT INTO public.study_sessions (
        user_id, category, category_id, duration_minutes,
        base_points, bonus_points, was_paused, is_verified,
        client_uuid, started_at, completed_at, start_verified
    ) VALUES (
        v_uid,
        (SELECT name FROM public.categories WHERE id = p_category_id),
        p_category_id, p_duration_minutes,
        v_base_points, v_bonus_points, p_was_paused, p_is_verified,
        p_client_uuid, v_started_at, v_ends_at, v_start_verified
    )
    RETURNING id INTO v_session_id;

    -- proposed/13: kullanılan başlangıç kaydı artık gereksiz.
    DELETE FROM public.session_starts
     WHERE user_id = v_uid AND client_uuid = p_client_uuid;

    -- 10. ACTIVITY FEED
    IF v_show_in_social_feed THEN
        SELECT SUM(duration_minutes), COUNT(*) INTO v_daily_minutes, v_daily_sessions
        FROM public.study_sessions
        WHERE user_id = v_uid AND ((started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date = v_study_day;

        SELECT category INTO v_top_category
        FROM public.study_sessions
        WHERE user_id = v_uid AND ((started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date = v_study_day
        GROUP BY category
        ORDER BY SUM(duration_minutes) DESC
        LIMIT 1;

        INSERT INTO public.activity_feed (user_id, activity_type, activity_date, payload)
        VALUES (
            v_uid,
            'daily_summary',
            v_study_day,
            jsonb_build_object(
                'total_minutes', COALESCE(v_daily_minutes, 0),
                'session_count', COALESCE(v_daily_sessions, 0),
                'top_category', v_top_category
            )
        )
        ON CONFLICT (user_id, activity_type, activity_date)
        DO UPDATE SET
            payload = EXCLUDED.payload,
            updated_at = now();

        IF NOT v_is_late_session
           AND v_current_streak IN (7, 14, 30, 60, 100)
           AND v_last_study_date IS DISTINCT FROM v_study_day THEN
            INSERT INTO public.activity_feed (user_id, activity_type, activity_date, payload)
            VALUES (v_uid, 'streak_milestone', v_study_day, jsonb_build_object('streak', v_current_streak))
            ON CONFLICT (user_id, activity_type, activity_date) DO NOTHING;
        END IF;

        IF COALESCE(v_daily_minutes, 0) >= 240 THEN
            INSERT INTO public.activity_feed (user_id, activity_type, activity_date, payload)
            VALUES (v_uid, 'daily_4h_milestone', v_study_day, jsonb_build_object('total_minutes', v_daily_minutes))
            ON CONFLICT (user_id, activity_type, activity_date) DO NOTHING;
        END IF;
    END IF;

    -- 11. RETURN RESULT
    RETURN jsonb_build_object(
        'base_points', v_base_points,
        'bonus_points', v_bonus_points,
        'total_points', v_total_points,
        'coins_earned', v_coins_earned,
        'streak', v_current_streak,
        'bonus_pct', v_bonus_pct,
        'duplicate', false,
        'daily_limit_reached', v_daily_limit_reached,
        'start_verified', v_start_verified,
        'unverified_limit_reached', v_unverified_limit_reached,
        'league_points', v_league_points,
        'league_period_closed', v_league_period_closed,
        'league_points_next_period', v_league_points_next_period
    );
END;
$function$;

-- Çağıran tüm profilleri, ardından tüm kademe kilitlerini tutar. İlk odalarda
-- boşluk varken yeni oda açılmaz. Mevcut oda UUID'leri mümkün olduğunca korunur.
CREATE FUNCTION public._league_repack(p_start timestamptz,p_end timestamptz,p_reset boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_tier integer;v_capacity integer;v_rooms uuid[];v_target uuid;v_index integer;v_total integer;v_member record;v_boundaries jsonb;
BEGIN
 v_capacity:=public._league_policy_int('league_room_capacity',25,3,30);
 IF p_start IS NULL THEN
  SELECT jsonb_agg(jsonb_build_object('id',m.id,'period_started_at',m.period_started_at)) INTO v_boundaries
  FROM public.league_memberships m JOIN public.leagues l ON l.id=m.league_id AND l.is_active;
 END IF;
 FOR v_tier IN 1..5 LOOP
  SELECT array_agg(id ORDER BY members DESC,start_date,id) INTO v_rooms FROM
   (SELECT l.id,l.start_date,count(m.id) AS members FROM public.leagues l
    LEFT JOIN public.league_memberships m ON m.league_id=l.id WHERE l.is_active AND l.tier=v_tier GROUP BY l.id) q;
  v_index:=0;
  FOR v_member IN SELECT m.*,l.start_date AS room_started FROM public.league_memberships m
    JOIN public.leagues l ON l.id=m.league_id AND l.is_active
    WHERE l.tier=v_tier ORDER BY l.start_date,l.id,m.joined_at,m.user_id LOOP
   v_index:=v_index+1;v_total:=((v_index-1)/v_capacity)+1;
   IF v_rooms IS NULL OR cardinality(v_rooms)<v_total THEN
    INSERT INTO public.leagues(tier,end_date) VALUES(v_tier,p_end) RETURNING id INTO v_target;
    v_rooms:=array_append(coalesce(v_rooms,'{}'::uuid[]),v_target);
   ELSE v_target:=v_rooms[v_total];END IF;
   IF v_member.league_id IS DISTINCT FROM v_target THEN
    UPDATE public.league_memberships SET league_id=v_target WHERE id=v_member.id;
   END IF;
   -- Oda değişiminin eski trigger'ı sınırı yazar; doğru sınırı açıkça geri koy.
   UPDATE public.league_memberships SET period_started_at=CASE WHEN p_start IS NULL THEN v_member.period_started_at ELSE p_start-interval '1 microsecond' END
    WHERE id=v_member.id;
  END LOOP;
  v_total:=greatest(1,(v_index+v_capacity-1)/v_capacity);
  IF v_rooms IS NOT NULL THEN
   UPDATE public.leagues SET is_active=false WHERE id=ANY(v_rooms) AND NOT(id=ANY(v_rooms[1:v_total]));
   UPDATE public.leagues SET end_date=p_end WHERE id=ANY(v_rooms[1:v_total]);
  END IF;
 END LOOP;
 IF p_reset THEN
  WITH score AS (SELECT m.id,coalesce(a.points,0)::integer AS points FROM public.league_memberships m
   JOIN public.leagues l ON l.id=m.league_id AND l.is_active
   LEFT JOIN public._league_period_activity(p_start,p_end+interval '1 microsecond') a ON a.user_id=m.user_id)
  UPDATE public.league_memberships m SET weekly_points=s.points,carry_points=0,period_started_at=p_start-interval '1 microsecond'
   FROM score s WHERE s.id=m.id;
 ELSE
  -- league_period_rollover yalnız end_date değişiminden de tetiklenebilir;
  -- hazırlıkta bu çağrının başındaki mevcut sınırları koru.
  UPDATE public.league_memberships m SET period_started_at=b.period_started_at
  FROM jsonb_to_recordset(coalesce(v_boundaries,'[]'::jsonb)) b(id uuid,period_started_at timestamptz)
  WHERE m.id=b.id;
 END IF;
END $$;

CREATE OR REPLACE FUNCTION public.process_weekly_leagues()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE v_state public.league_competition_state%ROWTYPE;v_cursor timestamptz;v_end timestamptz;
 v_league record;v_member record;v_active integer;v_count integer;v_promo integer;v_demo integer;v_target integer;v_avatar text;v_first_launch boolean:=false;
BEGIN
 -- complete_study_session önce kendi profilini kilitler; cron aynı sırayı
 -- kullanır ve hiçbir kademe kilidini profil beklerken tutmaz.
 PERFORM 1 FROM public.profiles ORDER BY id FOR UPDATE;
 PERFORM pg_advisory_xact_lock(hashtext('pomosprint_league_room'),t) FROM generate_series(1,5) t;
 PERFORM public._league_refresh_start();
 SELECT * INTO STRICT v_state FROM public.league_competition_state WHERE singleton FOR UPDATE;
 IF v_state.start_at IS NULL OR now()<v_state.start_at THEN
  UPDATE public.league_memberships m SET weekly_points=m.weekly_points+m.carry_points,carry_points=0
  FROM public.leagues l WHERE l.id=m.league_id AND l.is_active;
  PERFORM public._league_repack(NULL,
   coalesce(v_state.start_at,public._league_grid_start(now())+interval '336 hours')-interval '1 microsecond',false);
  RETURN;
 END IF;
 v_cursor:=coalesce(v_state.period_started_at,v_state.start_at);
 -- İlk geçişte eski hazırlık puanlarından ödül verilmez. Sonrasında cron
 -- gecikirse tamamlanan her gerçek dönemin kapalı snapshot'ı bir kez işlenir.
 IF NOT v_state.initialized THEN
  UPDATE public.league_competition_state SET initialized=true,period_started_at=v_cursor WHERE singleton;
  v_first_launch:=true;
 END IF;
 WHILE v_cursor+interval '336 hours'<=now() LOOP
  v_end:=v_cursor+interval '336 hours';
  -- Tüm oda kararlarını TAŞIMADAN önce kalıcı olmayan tek snapshot'ta al.
  DROP TABLE IF EXISTS pg_temp.league_launch_decisions;
  CREATE TEMP TABLE league_launch_decisions(user_id uuid PRIMARY KEY,tier integer,award text,original_tier integer) ON COMMIT DROP;
  FOR v_league IN SELECT id,tier FROM public.leagues WHERE is_active ORDER BY tier,start_date,id LOOP
   SELECT count(*)::integer,count(a.user_id)::integer INTO v_count,v_active
   FROM public.league_memberships m LEFT JOIN public._league_period_activity(v_cursor,v_end) a ON a.user_id=m.user_id
   WHERE m.league_id=v_league.id;
   SELECT z.promotion_zone_end,z.demotion_zone_start INTO v_promo,v_demo FROM public.get_league_zones(v_active) z;
   IF v_active>=10 THEN v_demo:=v_count-v_active/3+1;END IF;
   FOR v_member IN SELECT m.user_id,m.joined_at,coalesce(a.points,0)::integer AS score,
    coalesce(a.focus_minutes,0) AS minutes,coalesce(a.study_days,0) AS days,
    row_number() OVER(ORDER BY coalesce(a.points,0) DESC,m.joined_at,m.user_id)::integer AS position
    FROM public.league_memberships m LEFT JOIN public._league_period_activity(v_cursor,v_end) a ON a.user_id=m.user_id
    WHERE m.league_id=v_league.id LOOP
    v_target:=v_league.tier;v_avatar:=NULL;
    IF v_member.position<=v_promo AND v_league.tier<5
     AND v_member.score>=public._league_policy_int('league_promotion_min_points',1,1,2147483647)
     AND v_member.days>=public._league_policy_int('league_qualification_min_days',3,1,14)
     AND v_member.minutes>=public._league_policy_int('league_qualification_min_minutes',300,1,20160) THEN
      v_target:=v_league.tier+1;
    ELSIF v_active>=10 AND v_member.position>=v_demo AND v_league.tier>1 AND v_member.joined_at<=v_end-interval '72 hours' THEN
      v_target:=v_league.tier-1;
    END IF;
    IF v_active>=public._league_policy_int('league_award_min_members',10,3,30) AND v_member.position<=3
     AND v_member.score>=public._league_policy_int('league_award_min_points',1,1,2147483647)
     AND v_member.days>=public._league_policy_int('league_qualification_min_days',3,1,14)
     AND v_member.minutes>=public._league_policy_int('league_qualification_min_minutes',300,1,20160) THEN
      v_avatar:=public.league_award_avatar_id(v_league.tier,v_member.position);
    END IF;
    INSERT INTO league_launch_decisions VALUES(v_member.user_id,v_target,v_avatar,v_league.tier);
   END LOOP;
  END LOOP;
  FOR v_member IN SELECT d.*,m.id AS membership,m.league_id,p.league_tier AS old_tier FROM league_launch_decisions d
   JOIN public.profiles p ON p.id=d.user_id JOIN public.league_memberships m ON m.user_id=d.user_id
   JOIN public.leagues l ON l.id=m.league_id AND l.is_active ORDER BY d.user_id LOOP
   IF v_member.award IS NOT NULL THEN
    INSERT INTO public.avatar_unlocks(user_id,avatar_id,unlock_type,coins_spent)
    VALUES(v_member.user_id,v_member.award,'league_award',0) ON CONFLICT(user_id,avatar_id) DO NOTHING;
   END IF;
   IF v_member.tier<>v_member.old_tier THEN
    UPDATE public.profiles SET league_tier=v_member.tier WHERE id=v_member.user_id;
    -- Oda değişimi karar snapshot'ından sonra. Mevcut hedef odanın kapasitesi
    -- repack'te sınırlandırılır; işlem boyunca diğer yerleşimler kilitlidir.
    SELECT id INTO v_league FROM public.leagues WHERE is_active AND tier=v_member.tier ORDER BY start_date,id LIMIT 1;
    IF NOT FOUND THEN
     INSERT INTO public.leagues(tier,end_date) VALUES(v_member.tier,v_end+interval '336 hours'-interval '1 microsecond') RETURNING id INTO v_league;
    END IF;
    UPDATE public.league_memberships SET league_id=v_league.id,joined_at=v_end,period_started_at=v_end-interval '1 microsecond' WHERE id=v_member.membership;
    IF v_member.tier>v_member.old_tier THEN
     INSERT INTO public.activity_feed(user_id,activity_type,activity_date,payload)
     VALUES(v_member.user_id,'league_promotion',(v_end AT TIME ZONE 'Europe/Istanbul')::date,
      jsonb_build_object('league_id',v_league.id,'tier',v_member.tier)) ON CONFLICT(user_id,activity_type,activity_date) DO NOTHING;
    END IF;
   END IF;
  END LOOP;
  v_cursor:=v_end;
  UPDATE public.league_competition_state SET period_started_at=v_cursor WHERE singleton;
  PERFORM public._league_repack(v_cursor,v_cursor+interval '336 hours'-interval '1 microsecond',true);
  UPDATE public.activity_feed f SET payload=jsonb_set(f.payload,'{league_id}',to_jsonb(m.league_id))
  FROM pg_temp.league_launch_decisions d,public.league_memberships m,public.leagues l
  WHERE f.user_id=d.user_id AND d.tier>d.original_tier AND m.user_id=d.user_id AND l.id=m.league_id AND l.is_active
   AND f.activity_type='league_promotion' AND f.activity_date=(v_cursor AT TIME ZONE 'Europe/Istanbul')::date;
  v_first_launch:=false;
 END LOOP;
 -- Cron dönemi zamanında/geç açsa da mevcut döneme ait normal/Maraton puanı
 -- seans tablosundan eksiksiz geri alınır. Tekrarlanan cron sonuç değiştirmez.
 IF v_first_launch THEN
  PERFORM public._league_repack(v_cursor,v_cursor+interval '336 hours'-interval '1 microsecond',true);
 END IF;
END $$;

DO $private$
DECLARE r record;
BEGIN
 FOR r IN SELECT p.oid::regprocedure AS signature FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.proname IN('_league_policy_int','_league_grid_start','_league_refresh_start',
   '_league_after_completed_session','_league_period_activity','_league_ranking_rows','_league_repack','_league_place_member') LOOP
  EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC,anon,authenticated,service_role',r.signature);
 END LOOP;
END $private$;
REVOKE ALL ON FUNCTION public.get_league_config() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_league_config() TO anon,authenticated,service_role;
REVOKE ALL ON FUNCTION public.get_my_league_ranking_v2() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_league_ranking_v2() TO authenticated,service_role;

-- Her mevcut kullanıcı kendi kademesinde kalır; 25 üstü odalar aynı kademe
-- içinde bölünür, boşlukları olan odalar birleştirilir, puanlar korunur.
DO $layout$
BEGIN
 PERFORM 1 FROM public.profiles ORDER BY id FOR UPDATE;
 PERFORM pg_advisory_xact_lock(hashtext('pomosprint_league_room'),t) FROM generate_series(1,5) t;
 PERFORM public._league_refresh_start();
 PERFORM public._league_repack(NULL,
  coalesce((SELECT start_at FROM public.league_competition_state WHERE singleton),public._league_grid_start(now())+interval '336 hours')-interval '1 microsecond',false);
END $layout$;
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261008190000','league_launch_policy') ON CONFLICT(version) DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
