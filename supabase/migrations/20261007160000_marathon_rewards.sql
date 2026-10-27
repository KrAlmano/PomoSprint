-- HAZIRLANDI, CANLIYA UYGULANMADI. Önce DRYRUN sonra kullanıcı SQL Editor.
-- Normal RPC değiştirilmez; source7Oct canlı-eşdeğer md5 f0f2b9bcc09ae8440a66d889b5f22fcc.
-- 25dk2/3/4=2/3/5,50dk=4/6/10 sabit ekstra. Son dolduranfocusa birkez.
-- Her focus normal süre/sahiplik/çakışma/tavan doğrulaması kullanır.
-- Eski standaloneUUID retrofit edilmez; out-of-order kuyruk kabul edilir.
BEGIN;
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

COMMIT;
