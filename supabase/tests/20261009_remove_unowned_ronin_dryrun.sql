-- 20261009233000_remove_unowned_ronin — reviewed live read-only inventory, 9 October 2026.
-- Pending manual SQL Editor application; no live application by agent.
-- Removes only the unowned/un-equipped special_ronin catalog row.
-- Proven disposable live QA accounts: ZERO. No Auth/account deletion is included.
-- Never delete a user merely because the display name contains QA/test.
-- Existing users, balances, sessions, ownership, RPCs and ACLs are untouched.
-- If ownership changes before applying, this package refuses instead of refunding
-- or altering a genuine user's profile. Review a separate plan in that situation.
-- Deliberate DRYRUN_RESULT exception at the end rolls everything back.
-- No user fixtures, purchases, emails or Auth mutations.
BEGIN;
CREATE TEMP TABLE ronin_cleanup_before ON COMMIT DROP AS SELECT
 (SELECT jsonb_agg(to_jsonb(a) ORDER BY id) FROM public.avatars a WHERE id<>'special_ronin') AS keep_catalog,
 (SELECT md5(coalesce(jsonb_agg(to_jsonb(u) ORDER BY id),'[]'::jsonb)::text) FROM auth.users u) AS auth_md5,
 (SELECT md5(coalesce(jsonb_agg(to_jsonb(p) ORDER BY id),'[]'::jsonb)::text) FROM public.profiles p) AS profiles_md5,
 (SELECT md5(coalesce(jsonb_agg(to_jsonb(s) ORDER BY id),'[]'::jsonb)::text) FROM public.study_sessions s) AS sessions_md5,
 (SELECT md5(coalesce(jsonb_agg(to_jsonb(a) ORDER BY user_id,avatar_id),'[]'::jsonb)::text) FROM public.avatar_unlocks a) AS unlocks_md5,
 (SELECT md5(coalesce(jsonb_agg(to_jsonb(c) ORDER BY id),'[]'::jsonb)::text) FROM public.categories c) AS categories_md5,
 (SELECT jsonb_agg(jsonb_build_object('signature',p.oid::regprocedure::text,'body',md5(pg_get_functiondef(p.oid)),'acl',p.proacl::text) ORDER BY p.oid::regprocedure::text) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f') AS functions;
-- >>> PACKAGE BODY >>>

-- The catalog lock excludes purchases while ownership guards and deletion run.
LOCK TABLE public.avatars IN ACCESS EXCLUSIVE MODE;
DO $pre$
DECLARE
  expected constant jsonb := '{"give_default_avatars()": "bb36a4f2baa93af319c5f4e0ec3fe74f", "handle_new_user()": "ec0287158fd80a2c19bc1cdcf90a22ac", "purchase_avatar(text)": "38689aed887865e04bc6c23db8daeb32", "sanitize_profile_insert()": "41dfb7b4d7ac5fba873263b9373c3af3", "set_equipped_avatar(text)": "5a3e3e513a9fbf41619f842cdffc8a96"}'::jsonb;
  item record;
BEGIN
  IF EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261009233000') THEN
    RAISE EXCEPTION 'Ronin cleanup: package already installed; do not reapply';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261009190000' AND name='special_avatar_catalog') THEN
    RAISE EXCEPTION 'Ronin cleanup: predecessor special catalog package is missing';
  END IF;
  FOR item IN SELECT key,value FROM jsonb_each_text(expected) LOOP
    IF to_regprocedure('public.'||item.key) IS NULL OR md5(pg_get_functiondef(to_regprocedure('public.'||item.key))) IS DISTINCT FROM item.value THEN
      RAISE EXCEPTION 'Ronin cleanup: current function changed: %; review fresh definition',item.key;
    END IF;
  END LOOP;
  IF (SELECT md5(coalesce(jsonb_agg(to_jsonb(a) ORDER BY id),'[]'::jsonb)::text) FROM public.avatars a) IS DISTINCT FROM '5e80e532aa71a325edd1d76e96183fb5' THEN
    RAISE EXCEPTION 'Ronin cleanup: current catalog changed; review fresh catalog';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.avatars WHERE id='special_ronin') THEN
    RAISE EXCEPTION 'Ronin cleanup: expected catalog row missing';
  END IF;
  IF EXISTS(SELECT 1 FROM public.avatar_unlocks WHERE avatar_id='special_ronin')
     OR EXISTS(SELECT 1 FROM public.profiles WHERE avatar_id='special_ronin') THEN
    RAISE EXCEPTION 'Ronin cleanup refused: avatar is owned or equipped; preserve users and balances';
  END IF;
END $pre$;

DELETE FROM public.avatars WHERE id='special_ronin';
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261009233000','remove_unowned_ronin');
NOTIFY pgrst,'reload schema';

-- <<< PACKAGE BODY <<<
DO $dry$
DECLARE res text[]:='{}'; old ronin_cleanup_before%ROWTYPE;
BEGIN
 SELECT * INTO STRICT old FROM ronin_cleanup_before;
 res:=res||('T01 exactly Ronin is removed: '||((SELECT count(*) FROM public.avatars)=48 AND NOT EXISTS(SELECT 1 FROM public.avatars WHERE id='special_ronin'))::text);
 res:=res||('T02 remaining special avatars are21 and all500/safe: '||((SELECT count(*) FROM public.avatars WHERE id LIKE 'special\_%' ESCAPE '\' AND cost_coins=500 AND is_active AND NOT is_default AND NOT is_premium_only AND NOT is_league_award)=21)::text);
 res:=res||('T03 all other catalog rows unchanged: '||((SELECT jsonb_agg(to_jsonb(a) ORDER BY id) FROM public.avatars a)=old.keep_catalog)::text);
 res:=res||('T04 seven active free signup choices unchanged: '||((SELECT count(*) FROM public.avatars WHERE is_default AND is_active AND cost_coins=0)=7)::text);
 res:=res||('T05 Auth accounts unchanged: '||((SELECT md5(coalesce(jsonb_agg(to_jsonb(u) ORDER BY id),'[]'::jsonb)::text) FROM auth.users u)=old.auth_md5)::text);
 res:=res||('T06 profiles/balances/avatars unchanged: '||((SELECT md5(coalesce(jsonb_agg(to_jsonb(p) ORDER BY id),'[]'::jsonb)::text) FROM public.profiles p)=old.profiles_md5)::text);
 res:=res||('T07 sessions unchanged: '||((SELECT md5(coalesce(jsonb_agg(to_jsonb(s) ORDER BY id),'[]'::jsonb)::text) FROM public.study_sessions s)=old.sessions_md5)::text);
 res:=res||('T08 owned avatars unchanged: '||((SELECT md5(coalesce(jsonb_agg(to_jsonb(a) ORDER BY user_id,avatar_id),'[]'::jsonb)::text) FROM public.avatar_unlocks a)=old.unlocks_md5)::text);
 res:=res||('T09 categories unchanged: '||((SELECT md5(coalesce(jsonb_agg(to_jsonb(c) ORDER BY id),'[]'::jsonb)::text) FROM public.categories c)=old.categories_md5)::text);
 res:=res||('T10 public RPC bodies and ACLs unchanged: '||((SELECT jsonb_agg(jsonb_build_object('signature',p.oid::regprocedure::text,'body',md5(pg_get_functiondef(p.oid)),'acl',p.proacl::text) ORDER BY p.oid::regprocedure::text) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.prokind='f')=old.functions)::text);
 res:=res||('T11 exact expected remaining catalog checksum: '||((SELECT md5(coalesce(jsonb_agg(to_jsonb(a) ORDER BY id),'[]'::jsonb)::text) FROM public.avatars a)='9ad12fc8edb016c69eb45a24f4ac1e11')::text);
 res:=res||('T12 cleanup history is recorded once: '||((SELECT count(*) FROM supabase_migrations.schema_migrations WHERE version='20261009233000' AND name='remove_unowned_ronin')=1)::text);
 RAISE EXCEPTION 'DRYRUN_RESULT >> %',array_to_string(res,' || ');
END $dry$;
ROLLBACK;
