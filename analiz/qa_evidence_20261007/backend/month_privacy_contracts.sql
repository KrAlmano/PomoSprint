-- Additional release-QA assertions against an isolated local clone only.
-- Real current RPC bodies are exercised; all fixtures roll back.
\set ON_ERROR_STOP on
\pset pager off
BEGIN;
CREATE TEMP TABLE qa_results (seq serial, name text, ok boolean) ON COMMIT DROP;
CREATE FUNCTION pg_temp.qa_assert(p_name text, p_ok boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO qa_results(name, ok) VALUES(p_name, coalesce(p_ok, false));
  IF NOT coalesce(p_ok, false) THEN RAISE EXCEPTION 'QA ASSERT: %', p_name; END IF;
END $$;
CREATE FUNCTION pg_temp.qa_user(p_tag text) RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_id uuid := gen_random_uuid();
BEGIN
  INSERT INTO auth.users(id,email,email_confirmed_at,aud,role,raw_user_meta_data,raw_app_meta_data)
  VALUES(v_id,'release-extra-'||p_tag||'-'||left(v_id::text,8)||'@example.invalid',now(),
         'authenticated','authenticated',jsonb_build_object('name','QA '||p_tag),'{"provider":"email"}');
  UPDATE public.profiles SET birth_year=2000,onboarding_completed_at=now(),show_in_social_feed=true WHERE id=v_id;
  RETURN v_id;
END $$;
CREATE FUNCTION pg_temp.qa_as(p_id uuid) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',json_build_object('sub',p_id,'role','authenticated')::text,true)
$$;
CREATE TEMP TABLE qa_users(tag text PRIMARY KEY,id uuid,timezone text,month_start timestamptz) ON COMMIT DROP;
GRANT SELECT ON qa_users TO authenticated,anon;
INSERT INTO qa_users(tag,id,timezone)
VALUES ('istanbul',pg_temp.qa_user('Istanbul'),'Europe/Istanbul'),
       ('newyork',pg_temp.qa_user('NewYork'),'America/New_York'),
       ('tokyo',pg_temp.qa_user('Tokyo'),'Asia/Tokyo');
UPDATE qa_users SET month_start=(date_trunc('month',(now() AT TIME ZONE timezone)-interval '4 hours')+interval '4 hours') AT TIME ZONE timezone;
UPDATE public.profiles p SET timezone=u.timezone FROM qa_users u WHERE p.id=u.id;
-- The session starting just before 04:00 must remain in the preceding month
-- even though its completion crosses 04:00. The next session counts once.
INSERT INTO public.study_sessions(user_id,category,duration_minutes,base_points,bonus_points,was_paused,is_verified,client_uuid,started_at,completed_at)
SELECT id,'Month boundary',25,5,0,false,1500,gen_random_uuid(),month_start-interval '1 minute',month_start+interval '24 minutes' FROM qa_users;
INSERT INTO public.study_sessions(user_id,category,duration_minutes,base_points,bonus_points,was_paused,is_verified,client_uuid,started_at,completed_at)
SELECT id,'Month boundary',50,12,0,false,3000,gen_random_uuid(),month_start+interval '1 hour',month_start+interval '1 hour 50 minutes' FROM qa_users;

SELECT pg_temp.qa_as((SELECT id FROM qa_users WHERE tag='istanbul'));
SET LOCAL ROLE authenticated;
SELECT pg_temp.qa_assert('Monthly RPC uses started_at and profile-zone 04:00 in all three zones',
  (SELECT count(*)=3 AND bool_and(total_points=12 AND total_minutes=50)
     FROM public.get_public_monthly_leaderboard(100) WHERE id IN(SELECT id FROM qa_users)));
SELECT pg_temp.qa_assert('Monthly RPC exposes exactly one self row',
  (SELECT count(*) FILTER(WHERE is_me)=1 FROM public.get_public_monthly_leaderboard(100) WHERE id IN(SELECT id FROM qa_users)));
SELECT pg_temp.qa_assert('Negative requested leaderboard limit returns zero rows',
  (SELECT count(*)=0 FROM public.get_public_monthly_leaderboard(-1)));
SELECT public.block_user((SELECT id FROM qa_users WHERE tag='newyork'));
SELECT pg_temp.qa_assert('Blocked monthly row retains rank metrics but masks name and avatar',
  (SELECT is_blocked AND name IS NULL AND avatar_id IS NULL AND total_points=12 AND total_minutes=50
     FROM public.get_public_monthly_leaderboard(100) WHERE id=(SELECT id FROM qa_users WHERE tag='newyork')));
RESET ROLE;

-- An anonymous consumer may see the top aggregate rows, never user IDs.
SELECT pg_temp.qa_as(NULL);
SET LOCAL ROLE anon;
SELECT pg_temp.qa_assert('Anon monthly leaderboard caps p_limit=1000 to ten rows',
  (SELECT count(*)<=10 FROM public.get_public_monthly_leaderboard(1000)));
SELECT pg_temp.qa_assert('Anon monthly rows hide IDs and self flags',
  (SELECT bool_and(id IS NULL AND NOT is_me) FROM public.get_public_monthly_leaderboard(1000)));
RESET ROLE;

-- Privacy choice must remove the user from public aggregates immediately.
UPDATE public.profiles SET show_in_social_feed=false WHERE id=(SELECT id FROM qa_users WHERE tag='tokyo');
SELECT pg_temp.qa_as((SELECT id FROM qa_users WHERE tag='istanbul'));
SET LOCAL ROLE authenticated;
SELECT pg_temp.qa_assert('Visibility opt-out removes monthly aggregate row',
  NOT EXISTS(SELECT 1 FROM public.get_public_monthly_leaderboard(100) WHERE id=(SELECT id FROM qa_users WHERE tag='tokyo')));
SELECT pg_temp.qa_assert('Legal ledger first provider acceptance succeeds',
  (public.accept_legal_documents('2026-10-03','2026-10-03')->>'success')::boolean);
SELECT pg_temp.qa_assert('Repeated provider acceptance is unchanged',
  public.accept_legal_documents('2026-10-03','2026-10-03')->>'code'='unchanged');
RESET ROLE;
SELECT pg_temp.qa_assert('Legal acceptance ledger has exactly two terms/privacy entries',
  (SELECT count(*)=2 AND count(DISTINCT kind)=2 FROM public.consents
     WHERE user_id=(SELECT id FROM qa_users WHERE tag='istanbul') AND source='app_legal_acceptance'));

-- Delete only the confirmed synthetic owner and every related data class.
INSERT INTO public.waitlist(email) SELECT email FROM auth.users WHERE id=(SELECT id FROM qa_users WHERE tag='istanbul');
INSERT INTO public.marketing_subscribers(user_id,email) SELECT id,email FROM auth.users WHERE id=(SELECT id FROM qa_users WHERE tag='istanbul');
CREATE TEMP TABLE qa_deleted AS SELECT id,email FROM auth.users WHERE id=(SELECT id FROM qa_users WHERE tag='istanbul');
SELECT pg_temp.qa_as((SELECT id FROM qa_deleted));
SET LOCAL ROLE authenticated;
SELECT public.delete_own_account();
RESET ROLE;
SELECT pg_temp.qa_assert('Delete RPC removes owner auth and profile',
  NOT EXISTS(SELECT 1 FROM auth.users WHERE id=(SELECT id FROM qa_deleted)) AND
  NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=(SELECT id FROM qa_deleted)));
SELECT pg_temp.qa_assert('Delete RPC removes sessions and two-direction block links',
  NOT EXISTS(SELECT 1 FROM public.study_sessions WHERE user_id=(SELECT id FROM qa_deleted)) AND
  NOT EXISTS(SELECT 1 FROM public.user_blocks WHERE blocker_id=(SELECT id FROM qa_deleted) OR blocked_id=(SELECT id FROM qa_deleted)));
SELECT pg_temp.qa_assert('Delete RPC removes matching confirmed email waitlist and subscription',
  NOT EXISTS(SELECT 1 FROM public.waitlist WHERE email=(SELECT email FROM qa_deleted)) AND
  NOT EXISTS(SELECT 1 FROM public.marketing_subscribers WHERE email=(SELECT email FROM qa_deleted)));
SELECT pg_temp.qa_assert('Delete RPC unlinks retained legal ledger from owner',
  NOT EXISTS(SELECT 1 FROM public.consents WHERE user_id=(SELECT id FROM qa_deleted)));

SELECT seq,CASE WHEN ok THEN 'PASS' ELSE 'FAIL' END AS status,name FROM qa_results ORDER BY seq;
ROLLBACK;
