-- Canlı SQL Editor: tüm sonuçlar true. Son DRYRUN_RESULT hatası bütün fixture ve migration'ı geri alır.
-- Canlı insan seansları varken profil kilitleri nedeniyle kısa bakım penceresinde çalıştırın.
BEGIN;
-- BEGIN MIGRATION BODY
-- 8 Ekim 2026: 25 kişilik odalar, hazırlık ve sunucuda doğrulanan rekabet.
-- Canlı gövdeler: analiz/qa_evidence_20261008/league_launch/baseline.json.
-- Tek atomik işlem. Önce eşlik eden DRYRUN ve rollback rehberini okuyun.
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

-- END MIGRATION BODY
-- BEGIN SCENARIOS
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

-- END SCENARIOS
DO $done$
DECLARE v_result jsonb;BEGIN
 SELECT jsonb_agg(jsonb_build_object('name',name,'ok',ok) ORDER BY seq) INTO v_result FROM league_policy_results;
 RAISE EXCEPTION 'DRYRUN_RESULT: %',v_result;
END $done$;
ROLLBACK;
