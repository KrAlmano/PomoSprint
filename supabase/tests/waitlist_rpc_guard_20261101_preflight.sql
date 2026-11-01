-- Salt okunur anlık kontrol; kayıtların kendisi veya tokenlar gösterilmez.
BEGIN READ ONLY;
SELECT
  EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101223000' AND name='waitlist_consent_guard') AS consent_guard_installed,
  EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101235501') AS rpc_marker_exists,
  EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101235502') AS cutover_marker_exists,
  to_regnamespace('waitlist_private') IS NOT NULL AS budget_schema_exists,
  to_regprocedure('public.submit_waitlist(text,boolean,text)') IS NOT NULL AS rpc_exists,
  (SELECT count(*) FROM (SELECT lower(email) FROM public.waitlist GROUP BY lower(email) HAVING count(*)>1) x) AS case_insensitive_duplicate_groups,
  has_table_privilege('anon','public.waitlist','INSERT') AS direct_table_insert,
  has_column_privilege('anon','public.waitlist','email','INSERT') AS direct_email_insert;
ROLLBACK;
