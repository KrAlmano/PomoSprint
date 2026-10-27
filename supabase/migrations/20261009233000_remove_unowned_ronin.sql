-- 20261009233000_remove_unowned_ronin — reviewed live read-only inventory, 9 October 2026.
-- Pending manual SQL Editor application; no live application by agent.
-- Removes only the unowned/un-equipped special_ronin catalog row.
-- Proven disposable live QA accounts: ZERO. No Auth/account deletion is included.
-- Never delete a user merely because the display name contains QA/test.
-- Existing users, balances, sessions, ownership, RPCs and ACLs are untouched.
-- If ownership changes before applying, this package refuses instead of refunding
-- or altering a genuine user's profile. Review a separate plan in that situation.
BEGIN;

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

COMMIT;
