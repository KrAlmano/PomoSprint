-- Kullanıcı SQL Editor; tüm kontroller true olmalı. Son hata transactionı geri alır.
BEGIN;
-- BEGIN MIGRATION BODY
DO $pre$
BEGIN
  IF md5(pg_get_functiondef('public.start_study_session(integer,text)'::regprocedure)) IS DISTINCT FROM '0a109f61759dae7ddea73b0a68919cae'
     OR md5(pg_get_functiondef('public.cancel_study_session()'::regprocedure)) IS DISTINCT FROM '7c1adf25d21513e01f70ffe792957ba2'
     OR md5(pg_get_functiondef('public.get_live_friends()'::regprocedure)) IS DISTINCT FROM 'b7edb95b65e1f04b6a298c97b250aa30'
     OR EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='active_break_ends_at')
     OR to_regprocedure('public.start_study_break(timestamptz)') IS NOT NULL
     OR to_regprocedure('public.get_live_friends_with_breaks()') IS NOT NULL THEN
    RAISE EXCEPTION 'marathon_break_presence ön koşulu değişmiş; güncel canlı tanımdan yeniden hazırlayın.';
  END IF;
END
$pre$;

ALTER TABLE public.profiles ADD COLUMN active_break_ends_at timestamptz;
COMMENT ON COLUMN public.profiles.active_break_ends_at IS 'Temporary marathon break presence. Set only by owner RPC; never study time/rewards.';
REVOKE INSERT (active_break_ends_at), UPDATE (active_break_ends_at) ON public.profiles FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.start_study_session(p_duration_minutes integer, p_category_name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_name text;
BEGIN
    IF p_duration_minutes IS NULL OR p_duration_minutes < 0 OR p_duration_minutes > 50 THEN
        RAISE EXCEPTION 'invalid duration: 0..50 minutes allowed';
    END IF;

    v_name := nullif(btrim(left(public.clean_display_text(p_category_name), 40)), '');
    IF v_name IS NOT NULL AND NOT public.display_text_is_allowed(v_name) THEN
        v_name := NULL;
    END IF;

    UPDATE public.profiles
    SET
      active_session_ends_at = now() + (p_duration_minutes * interval '1 minute'),
      active_session_category_name = v_name,
      active_break_ends_at = NULL
    WHERE id = auth.uid();
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_study_session()
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  UPDATE public.profiles 
  SET 
    active_session_ends_at = NULL,
    active_session_category_name = NULL,
    active_break_ends_at = NULL
  WHERE id = auth.uid();
$function$;

CREATE OR REPLACE FUNCTION public.start_study_break(p_ends_at timestamptz)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  IF p_ends_at IS NULL OR p_ends_at <= now() OR p_ends_at > now() + interval '5 minutes 10 seconds' THEN
    RAISE EXCEPTION 'invalid break end: future maximum 5 minutes 10 seconds';
  END IF;
  -- Yalnız çağıranın geçici durumu; gizli kullanıcı için iki durum da kapanır.
  UPDATE public.profiles
  SET active_session_ends_at = NULL,
      active_session_category_name = NULL,
      active_break_ends_at = CASE WHEN show_in_social_feed THEN p_ends_at ELSE NULL END
  WHERE id = v_uid;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_live_friends_with_breaks()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_result jsonb;
BEGIN
    IF v_uid IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    -- Kabul edilen arkadaşlıklar iki yönlü satırla tutuluyor; önceki
    -- OR-join her arkadaşı iki kez döndürüyordu.
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'name', p.name,
            'avatar_id', p.avatar_id,
            'category_name', CASE WHEN p.active_session_ends_at > now() THEN p.active_session_category_name END,
            'ends_at', CASE WHEN p.active_session_ends_at > now() THEN p.active_session_ends_at ELSE p.active_break_ends_at END,
            'status', CASE WHEN p.active_session_ends_at > now() THEN 'focus' ELSE 'break' END
        ) ORDER BY COALESCE(p.active_session_ends_at, p.active_break_ends_at)
    ), '[]'::jsonb)
    INTO v_result
    FROM public.profiles p
    WHERE p.id <> v_uid
      AND p.id IN (
          SELECT CASE WHEN f.user_id = v_uid THEN f.friend_id ELSE f.user_id END
          FROM public.friendships f
          WHERE f.status = 'accepted' AND (f.user_id = v_uid OR f.friend_id = v_uid)
      )
      AND NOT EXISTS (
          SELECT 1 FROM public.user_blocks b
          WHERE (b.blocker_id = v_uid AND b.blocked_id = p.id)
             OR (b.blocker_id = p.id AND b.blocked_id = v_uid)
      )
      AND p.show_in_social_feed = true
      AND (p.active_session_ends_at > now() OR p.active_break_ends_at > now());

    RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.start_study_break(timestamptz), public.get_live_friends_with_breaks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_study_break(timestamptz), public.get_live_friends_with_breaks() TO authenticated, service_role;
INSERT INTO supabase_migrations.schema_migrations(version,name)
VALUES ('20261007150000','marathon_break_presence') ON CONFLICT(version) DO NOTHING;
-- END MIGRATION BODY

CREATE TEMP TABLE break_checks(seq serial,name text,ok boolean);
CREATE FUNCTION pg_temp.break_check(p_name text,p_ok boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN INSERT INTO break_checks(name,ok) VALUES(p_name,coalesce(p_ok,false)); END $$;
CREATE FUNCTION pg_temp.break_reject(p_end timestamptz) RETURNS boolean LANGUAGE plpgsql AS $$
BEGIN PERFORM public.start_study_break(p_end); RETURN false;
EXCEPTION WHEN raise_exception THEN RETURN SQLERRM LIKE 'invalid break end:%'; END $$;
CREATE TEMP TABLE break_users(tag text primary key,id uuid);
INSERT INTO break_users SELECT tag,gen_random_uuid() FROM unnest(ARRAY['observer','focus','break','hidden','blocked']) tag;
GRANT SELECT ON break_users TO authenticated;
INSERT INTO auth.users(id,email,aud,role,raw_user_meta_data)
SELECT id,'break-'||tag||'-'||left(id::text,8)||'@example.invalid','authenticated','authenticated',jsonb_build_object('name','Break '||tag) FROM break_users;
INSERT INTO public.friendships(user_id,friend_id,status)
SELECT o.id,p.id,'accepted' FROM break_users o CROSS JOIN break_users p WHERE o.tag='observer' AND p.tag<>'observer';
INSERT INTO public.friendships(user_id,friend_id,status)
SELECT p.id,o.id,'accepted' FROM break_users o CROSS JOIN break_users p WHERE o.tag='observer' AND p.tag<>'observer';
UPDATE public.profiles SET show_in_social_feed=true WHERE id IN(SELECT id FROM break_users);
UPDATE public.profiles SET active_session_ends_at=now()+interval '25 minutes',active_session_category_name='Fizik' WHERE id=(SELECT id FROM break_users WHERE tag='focus');
UPDATE public.profiles SET show_in_social_feed=false WHERE id=(SELECT id FROM break_users WHERE tag='hidden');
INSERT INTO public.user_blocks(blocker_id,blocked_id) SELECT o.id,b.id FROM break_users o CROSS JOIN break_users b WHERE o.tag='observer' AND b.tag='blocked';
SELECT set_config('request.jwt.claims',json_build_object('sub',(SELECT id FROM break_users WHERE tag='break'),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
SELECT public.start_study_break(now()+interval '5 minutes');
SELECT pg_temp.break_check('NULL end rejected',pg_temp.break_reject(NULL));
SELECT pg_temp.break_check('Past end rejected',pg_temp.break_reject(now()-interval '1 second'));
SELECT pg_temp.break_check('Exact now rejected',pg_temp.break_reject(now()));
SELECT pg_temp.break_check('Over max end rejected',pg_temp.break_reject(now()+interval '5 minutes 11 seconds'));
RESET ROLE;
SELECT pg_temp.break_check('Owner break set and focus fields cleared',(SELECT active_break_ends_at=now()+interval '5 minutes' AND active_session_ends_at IS NULL AND active_session_category_name IS NULL FROM public.profiles WHERE id=(SELECT id FROM break_users WHERE tag='break')));
SELECT pg_temp.break_check('Other owner focus preserved',(SELECT active_session_ends_at=now()+interval '25 minutes' FROM public.profiles WHERE id=(SELECT id FROM break_users WHERE tag='focus')));
UPDATE public.profiles SET active_break_ends_at=now()+interval '5 minutes' WHERE id IN(SELECT id FROM break_users WHERE tag IN('hidden','blocked'));
SELECT set_config('request.jwt.claims',json_build_object('sub',(SELECT id FROM break_users WHERE tag='observer'),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
SELECT pg_temp.break_check('Old RPC remains focus-only',jsonb_array_length(public.get_live_friends())=1 AND public.get_live_friends()->0->>'id'=(SELECT id::text FROM break_users WHERE tag='focus'));
SELECT pg_temp.break_check('New RPC returns one focus and one break without duplicates',jsonb_array_length(public.get_live_friends_with_breaks())=2 AND (SELECT count(*)=1 FROM jsonb_array_elements(public.get_live_friends_with_breaks()) r WHERE r->>'status'='break') AND (SELECT count(*)=1 FROM jsonb_array_elements(public.get_live_friends_with_breaks()) r WHERE r->>'status'='focus'));
SELECT pg_temp.break_check('Break response has no category and exact end',(SELECT r->>'category_name' IS NULL AND (r->>'ends_at')::timestamptz=now()+interval '5 minutes' FROM jsonb_array_elements(public.get_live_friends_with_breaks()) r WHERE r->>'status'='break'));
SELECT pg_temp.break_check('Hidden and blocked peers are excluded',NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.get_live_friends_with_breaks()) r WHERE r->>'id' IN(SELECT id::text FROM break_users WHERE tag IN('hidden','blocked'))));
SELECT pg_temp.break_check('Caller never sees own row',NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.get_live_friends_with_breaks()) r WHERE r->>'id'=(SELECT id::text FROM break_users WHERE tag='observer')));
RESET ROLE;
DELETE FROM public.user_blocks WHERE blocker_id=(SELECT id FROM break_users WHERE tag='observer');
INSERT INTO public.user_blocks(blocker_id,blocked_id) SELECT b.id,o.id FROM break_users o CROSS JOIN break_users b WHERE o.tag='observer' AND b.tag='blocked';
SET LOCAL ROLE authenticated;
SELECT pg_temp.break_check('Reverse block also excludes peer',NOT EXISTS(SELECT 1 FROM jsonb_array_elements(public.get_live_friends_with_breaks()) r WHERE r->>'id'=(SELECT id::text FROM break_users WHERE tag='blocked')));
RESET ROLE;
UPDATE public.profiles SET active_break_ends_at=now()-interval '1 second' WHERE id=(SELECT id FROM break_users WHERE tag='break');
SET LOCAL ROLE authenticated;
SELECT pg_temp.break_check('Expired break not returned',jsonb_array_length(public.get_live_friends_with_breaks())=1);
RESET ROLE;
SELECT set_config('request.jwt.claims',json_build_object('sub',(SELECT id FROM break_users WHERE tag='break'),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
SELECT public.start_study_break(now()+interval '5 minutes');
SELECT public.start_study_session(25,'Fizik');
RESET ROLE;
SELECT pg_temp.break_check('Next focus clears break',(SELECT active_break_ends_at IS NULL AND active_session_ends_at>now() FROM public.profiles WHERE id=(SELECT id FROM break_users WHERE tag='break')));
SET LOCAL ROLE authenticated;
SELECT public.start_study_break(now()+interval '5 minutes');
SELECT public.cancel_study_session();
RESET ROLE;
SELECT pg_temp.break_check('Cancel clears both states',(SELECT active_break_ends_at IS NULL AND active_session_ends_at IS NULL FROM public.profiles WHERE id=(SELECT id FROM break_users WHERE tag='break')));
SELECT set_config('request.jwt.claims',json_build_object('sub',(SELECT id FROM break_users WHERE tag='hidden'),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
SELECT public.start_study_break(now()+interval '5 minutes');
RESET ROLE;
SELECT pg_temp.break_check('Hidden owner cannot publish break',(SELECT active_break_ends_at IS NULL FROM public.profiles WHERE id=(SELECT id FROM break_users WHERE tag='hidden')));
SELECT pg_temp.break_check('Mola grants no direct profile write',NOT has_column_privilege('authenticated','public.profiles','active_break_ends_at','UPDATE') AND NOT has_column_privilege('anon','public.profiles','active_break_ends_at','UPDATE'));
SELECT pg_temp.break_check('Anon cannot execute new RPCs',NOT has_function_privilege('anon','public.start_study_break(timestamptz)','EXECUTE') AND NOT has_function_privilege('anon','public.get_live_friends_with_breaks()','EXECUTE'));
SELECT pg_temp.break_check('Authenticated can execute new RPCs',has_function_privilege('authenticated','public.start_study_break(timestamptz)','EXECUTE') AND has_function_privilege('authenticated','public.get_live_friends_with_breaks()','EXECUTE'));
SELECT pg_temp.break_check('Both RPCs security definer with safe search path',(SELECT bool_and(prosecdef AND proconfig=ARRAY['search_path=public, pg_temp']) FROM pg_proc WHERE oid IN('public.start_study_break(timestamptz)'::regprocedure,'public.get_live_friends_with_breaks()'::regprocedure)));
SELECT pg_temp.break_check('Old get_live_friends body unchanged',md5(pg_get_functiondef('public.get_live_friends()'::regprocedure))='b7edb95b65e1f04b6a298c97b250aa30');
SELECT pg_temp.break_check('No study records or rewards',(SELECT count(*)=0 FROM public.study_sessions WHERE user_id IN(SELECT id FROM break_users)) AND (SELECT bool_and(lifetime_points=0 AND total_minutes=0) FROM public.profiles WHERE id IN(SELECT id FROM break_users)));
SELECT pg_temp.break_check('Version recorded',EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261007150000'));
DO $dry$
DECLARE result text;
BEGIN SELECT string_agg('T'||lpad(seq::text,2,'0')||' '||name||': '||ok::text,' || ' ORDER BY seq) INTO result FROM break_checks;
RAISE EXCEPTION 'DRYRUN_RESULT >> %',result; END $dry$;
ROLLBACK;
