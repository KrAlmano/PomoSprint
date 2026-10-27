-- 20261009233000_remove_unowned_ronin — reviewed live read-only inventory, 9 October 2026.
-- Pending manual SQL Editor application; no live application by agent.
-- Removes only the unowned/un-equipped special_ronin catalog row.
-- Proven disposable live QA accounts: ZERO. No Auth/account deletion is included.
-- Never delete a user merely because the display name contains QA/test.
-- Existing users, balances, sessions, ownership, RPCs and ACLs are untouched.
-- If ownership changes before applying, this package refuses instead of refunding
-- or altering a genuine user's profile. Review a separate plan in that situation.
-- This catalog-only down is reversible. It does not restore deleted accounts,
-- because the forward package intentionally does not delete any accounts.
BEGIN;
LOCK TABLE public.avatars IN ACCESS EXCLUSIVE MODE;
DO $guard$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261009233000' AND name='remove_unowned_ronin') THEN
    RAISE EXCEPTION 'Ronin rollback: matching package is not installed';
  END IF;
  IF EXISTS(SELECT 1 FROM public.avatars WHERE id='special_ronin') THEN
    RAISE EXCEPTION 'Ronin rollback: ID already exists; review before restoring';
  END IF;
  IF (SELECT md5(coalesce(jsonb_agg(to_jsonb(a) ORDER BY id),'[]'::jsonb)::text) FROM public.avatars a) IS DISTINCT FROM '9ad12fc8edb016c69eb45a24f4ac1e11' THEN
    RAISE EXCEPTION 'Ronin rollback: catalog changed; review before restoring';
  END IF;
END $guard$;
INSERT INTO public.avatars SELECT * FROM jsonb_populate_record(NULL::public.avatars,'{"asset_key": "assets/avatars/special_ronin.png", "cost_coins": 500, "created_at": "2026-10-09T19:25:05.402775+00:00", "id": "special_ronin", "is_active": true, "is_default": false, "is_league_award": false, "is_premium_only": false, "name_en": "Ronin", "name_tr": "Ronin", "sort_order": 313}'::jsonb);
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261009233000' AND name='remove_unowned_ronin';
NOTIFY pgrst,'reload schema';
COMMIT;
