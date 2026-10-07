-- Current report RPC, permissions and limits; isolated clone, full rollback.
\set ON_ERROR_STOP on
\pset pager off
BEGIN;
CREATE TEMP TABLE report_results(seq serial,name text,ok boolean) ON COMMIT DROP;
CREATE FUNCTION pg_temp.report_check(p_name text,p_ok boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO report_results(name,ok) VALUES(p_name,coalesce(p_ok,false));
  IF NOT coalesce(p_ok,false) THEN RAISE EXCEPTION 'REPORT ASSERT: %',p_name; END IF;
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
SELECT seq,CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END AS status,name FROM report_results ORDER BY seq;
ROLLBACK;
