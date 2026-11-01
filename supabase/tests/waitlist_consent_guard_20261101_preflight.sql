-- SALT OKUNUR ön kontrol: e-posta/token değerleri gösterilmez; değişiklik yapmaz.
-- Sonuç yalnız anlık durumdur; kurulumdaki kilitli kontrollerin yerine geçmez.
BEGIN READ ONLY;
SELECT
  coalesce((SELECT relrowsecurity FROM pg_class WHERE oid=to_regclass('public.waitlist')), false) AS rls_enabled,
  has_table_privilege('anon','public.waitlist','INSERT') AS anon_currently_has_table_insert,
  has_table_privilege('anon','public.waitlist','SELECT') AS anon_has_select,
  EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid='public.waitlist'::regclass AND a.attnum>0 AND NOT a.attisdropped AND has_column_privilege('anon','public.waitlist',a.attname,'SELECT')) AS anon_has_any_column_select,
  EXISTS (SELECT 1 FROM pg_attribute a CROSS JOIN LATERAL aclexplode(a.attacl) acl WHERE a.attrelid='public.waitlist'::regclass AND a.attnum>0 AND acl.grantee=(SELECT oid FROM pg_roles WHERE rolname='anon') AND acl.privilege_type='INSERT') AS anon_has_explicit_column_insert,
  EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='waitlist'
          AND policyname='Allow public insert to waitlist' AND cmd='INSERT' AND roles::text='{anon}' AND with_check='true') AS expected_policy,
  (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='waitlist')=1 AS single_policy,
  (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='waitlist' AND cmd IN ('INSERT','ALL'))=1 AS single_insert_policy,
  coalesce(md5(pg_get_functiondef(to_regprocedure('public.waitlist_set_consent_time()')))='67f6c03b46a30f5cef4c9404130ed6a0',false) AS expected_trigger_function,
  EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='public.waitlist'::regclass AND tgname='waitlist_set_consent_time' AND NOT tgisinternal AND tgenabled='O' AND tgtype=7 AND tgfoid=to_regprocedure('public.waitlist_set_consent_time()') AND tgnargs=0 AND tgqual IS NULL) AS expected_trigger_enabled,
  (SELECT count(*) FROM pg_trigger WHERE tgrelid='public.waitlist'::regclass AND NOT tgisinternal)=1 AS single_user_trigger,
  EXISTS (SELECT 1 FROM pg_attribute a
          JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
          JOIN pg_index i ON i.indrelid=a.attrelid AND i.indexrelid=to_regclass('public.waitlist_unsubscribe_token_key')
          WHERE a.attrelid='public.waitlist'::regclass AND a.attname='unsubscribe_token'
            AND a.attnotnull AND a.atttypid='uuid'::regtype
            AND pg_get_expr(d.adbin,d.adrelid)='gen_random_uuid()'
            AND d.adbin::text LIKE ('{FUNCEXPR :funcid '||'pg_catalog.gen_random_uuid()'::regprocedure::oid||' :%')
            AND i.indisunique AND i.indisvalid AND i.indisready
            AND i.indnkeyatts=1 AND i.indnatts=1 AND i.indkey[0]=a.attnum
            AND i.indpred IS NULL AND i.indexprs IS NULL) AS token_default_unique_safe,
  EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101223000') AS marker_already_present,
  (SELECT count(*) FROM public.waitlist) AS current_waitlist_count;
ROLLBACK;
