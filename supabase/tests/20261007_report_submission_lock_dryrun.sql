-- Kullanıcı SQL Editor'de çalıştırır; tüm değişiklikler bilinçli son hata ile geri alınır.
-- Her DRYRUN_RESULT maddesi true olmalı. Eşzamanlı HTTP iki bağlantılı yerel
-- testte sınanır; tek transaction DRYRUN o yarışın yerini tutmaz.
-- Sentetik kullanıcılar @example.invalid ve marketing onayı olmadan eklenir.
BEGIN;
-- BEGIN MIGRATION BODY
DO $pre$
BEGIN
    IF md5(pg_get_functiondef('public.submit_user_report(uuid,text,text,text)'::regprocedure))
       IS DISTINCT FROM '547b73d8a9163466b19dafb4b89e9fe3' THEN
        RAISE EXCEPTION 'report_submission_lock ön koşulu: canlı submit_user_report tanımı değişmiş; dosyayı yeni canlı gövdeye uyarlayın.';
    END IF;
END
$pre$;

CREATE OR REPLACE FUNCTION public.submit_user_report(p_target_user_id uuid, p_place text, p_reason text, p_details text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_place text := lower(btrim(coalesce(p_place, '')));
    v_reason text := lower(btrim(coalesce(p_reason, '')));
    v_details text := nullif(left(btrim(coalesce(p_details, '')), 500), '');
    v_existing uuid;
    v_recent integer;
    v_name text;
    v_content text;
    v_id uuid;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;
    IF v_place NOT IN ('league', 'monthly', 'friends_ranking', 'live_feed', 'friends_list', 'friend_request', 'other') THEN
        RETURN jsonb_build_object('success', false, 'code', 'invalid_place');
    END IF;
    IF v_reason NOT IN ('offensive_name', 'offensive_content', 'harassment', 'spam', 'impersonation', 'other') THEN
        RETURN jsonb_build_object('success', false, 'code', 'invalid_reason');
    END IF;
    IF p_target_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'code', 'not_found');
    END IF;
    IF p_target_user_id = v_uid THEN
        RETURN jsonb_build_object('success', false, 'code', 'self');
    END IF;

    SELECT p.name, p.active_session_category_name INTO v_name, v_content
      FROM public.profiles p WHERE p.id = p_target_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'code', 'not_found');
    END IF;

    -- Aynı bildiricinin tekrar ve 24 saatlik limit denetimleri ile INSERT'i
    -- tek işlem olarak sırala. Profil satırı kilitlenmez; farklı bildiriciler
    -- ayrı advisory anahtarları kullanır. Kilit COMMIT/ROLLBACK ile bırakılır.
    PERFORM pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended('pomosprint:user_report:' || v_uid::text, 0));

    SELECT r.id INTO v_existing
      FROM public.user_reports r
     WHERE r.reporter_id = v_uid AND r.target_user_id = p_target_user_id
       AND r.status = 'open' AND r.created_at > now() - interval '24 hours'
     ORDER BY r.created_at DESC
     LIMIT 1;
    IF v_existing IS NOT NULL THEN
        RETURN jsonb_build_object('success', true, 'code', 'duplicate', 'duplicate', true, 'report_id', v_existing);
    END IF;

    SELECT count(*) INTO v_recent
      FROM public.user_reports r
     WHERE r.reporter_id = v_uid AND r.created_at > now() - interval '24 hours';
    IF v_recent >= 10 THEN
        RETURN jsonb_build_object('success', false, 'code', 'rate_limited');
    END IF;

    INSERT INTO public.user_reports (reporter_id, target_user_id, place, reason, details,
                                     target_name_snapshot, target_content_snapshot)
    VALUES (v_uid, p_target_user_id, v_place, v_reason, v_details,
            v_name, CASE WHEN v_place = 'live_feed' THEN v_content END)
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('success', true, 'code', 'reported', 'duplicate', false, 'report_id', v_id);
END;
$function$;

INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES ('20261007110000', 'report_submission_lock')
ON CONFLICT (version) DO NOTHING;
-- END MIGRATION BODY

-- Current report RPC, permissions and limits; isolated clone, full rollback.
CREATE TEMP TABLE report_results(seq serial,name text,ok boolean) ON COMMIT DROP;
CREATE FUNCTION pg_temp.report_check(p_name text,p_ok boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO report_results(name,ok) VALUES(p_name,coalesce(p_ok,false));
END $$;
CREATE FUNCTION pg_temp.report_user(p_tag text) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v uuid:=gen_random_uuid();
BEGIN
  INSERT INTO auth.users(id,email,aud,role,raw_user_meta_data)
  VALUES(v,'report-'||p_tag||'-'||left(v::text,8)||'@example.invalid','authenticated','authenticated',jsonb_build_object('name','Report '||p_tag));
  RETURN v;
END $$;
CREATE TEMP TABLE report_users(tag text PRIMARY KEY,id uuid) ON COMMIT DROP;
GRANT SELECT ON report_users TO authenticated;
INSERT INTO report_users VALUES('reporter',pg_temp.report_user('Reporter')),('target',pg_temp.report_user('Target'));
SELECT set_config('request.jwt.claims',json_build_object('sub',(SELECT id FROM report_users WHERE tag='reporter'),'role','authenticated')::text,true);
SET LOCAL ROLE authenticated;
CREATE TEMP TABLE report_response AS SELECT public.submit_user_report((SELECT id FROM report_users WHERE tag='target'),' friends_list ',' HARASSMENT ',repeat('x',700)) r;
SELECT pg_temp.report_check('Valid report returns reported and UUID',
  (SELECT (r->>'success')::boolean AND r->>'code'='reported' AND NOT(r->>'duplicate')::boolean AND (r->>'report_id')::uuid IS NOT NULL FROM report_response));
SELECT pg_temp.report_check('Duplicate report returns same ID and success without extra row',
  (SELECT r->>'report_id'=public.submit_user_report((SELECT id FROM report_users WHERE tag='target'),'other','spam')->>'report_id' FROM report_response));
SELECT pg_temp.report_check('Self report rejected with self code',
  public.submit_user_report((SELECT id FROM report_users WHERE tag='reporter'),'other','spam')->>'code'='self');
SELECT pg_temp.report_check('Missing target rejected with not_found code',
  public.submit_user_report(gen_random_uuid(),'other','spam')->>'code'='not_found');
SELECT pg_temp.report_check('Null target rejected with not_found code',
  public.submit_user_report(NULL,'other','spam')->>'code'='not_found');
SELECT pg_temp.report_check('Invalid place rejected before report write',
  public.submit_user_report((SELECT id FROM report_users WHERE tag='target'),'invalid','spam')->>'code'='invalid_place');
SELECT pg_temp.report_check('Invalid reason rejected before report write',
  public.submit_user_report((SELECT id FROM report_users WHERE tag='target'),'other','invalid')->>'code'='invalid_reason');
RESET ROLE;
SELECT pg_temp.report_check('Report stored exactly once with normalized fields and 500 char limit',
  (SELECT count(*)=1 AND bool_and(place='friends_list' AND reason='harassment' AND length(details)=500 AND target_name_snapshot='Report Target' AND target_content_snapshot IS NULL)
   FROM public.user_reports WHERE reporter_id=(SELECT id FROM report_users WHERE tag='reporter')));
SELECT pg_temp.report_check('Authenticated role cannot read report table',
  NOT has_table_privilege('authenticated','public.user_reports','SELECT'));
SELECT pg_temp.report_check('Anon role cannot read report table or execute report RPC',
  NOT has_table_privilege('anon','public.user_reports','SELECT') AND NOT has_function_privilege('anon','public.submit_user_report(uuid,text,text,text)','EXECUTE'));

-- Each target is unique so duplicate handling cannot mask the limit.
DO $$
DECLARE i integer;v_target uuid;v_result jsonb;v_reporter uuid:=(SELECT id FROM report_users WHERE tag='reporter');
BEGIN
  FOR i IN 2..11 LOOP
    v_target:=pg_temp.report_user('Target'||i);
    SET LOCAL ROLE authenticated;
    v_result:=public.submit_user_report(v_target,'other','spam','Rate-limit fixture');
    RESET ROLE;
    IF i<=10 THEN
      PERFORM pg_temp.report_check('Report '||i||' accepted below cap',v_result->>'code'='reported');
    ELSE
      PERFORM pg_temp.report_check('Eleventh report rejected with rate_limited code',v_result->>'code'='rate_limited' AND NOT(v_result->>'success')::boolean);
    END IF;
  END LOOP;
  PERFORM pg_temp.report_check('Only ten report rows persist below the 24h cap',
    (SELECT count(*)=10 FROM public.user_reports WHERE reporter_id=v_reporter));
END $$;
SELECT pg_temp.report_check('Function owner/security/volatility/search_path/ACL preserved',
  (SELECT prosecdef AND provolatile='v' AND pg_get_userbyid(proowner)='postgres'
     AND proconfig=ARRAY['search_path=public, pg_temp']
     AND proacl::text='{postgres=X/postgres,authenticated=X/postgres,service_role=X/postgres}'
   FROM pg_proc WHERE oid='public.submit_user_report(uuid,text,text,text)'::regprocedure));
SELECT pg_temp.report_check('Migration version recorded',
  (SELECT count(*)=1 FROM supabase_migrations.schema_migrations WHERE version='20261007110000' AND name='report_submission_lock'));
DO $dry$
DECLARE v_result text;
BEGIN
    SELECT string_agg('T'||lpad(seq::text,2,'0')||' '||name||': '||ok::text,' || ' ORDER BY seq)
      INTO v_result FROM report_results;
    RAISE EXCEPTION 'DRYRUN_RESULT >> %', v_result;
END
$dry$;

ROLLBACK;
