-- SALT OKUNUR POSTFLIGHT: kayıt, e-posta, token veya hash DEĞERİ göstermez.
-- Bu dosya kurulumu yapmaz. Yalnız bağımsız inceleme sonrası çalıştırın.
BEGIN READ ONLY;
SELECT row_to_json(checks) AS checks FROM (
SELECT
  EXISTS (
    SELECT 1 FROM supabase_migrations.schema_migrations
     WHERE version='20261101223000' AND name='waitlist_consent_guard'
  ) AS expected_migration_marker,
  coalesce((SELECT relrowsecurity FROM pg_class WHERE oid=to_regclass('public.waitlist')),false) AS rls_enabled,
  NOT has_table_privilege('anon','public.waitlist','SELECT') AS anon_no_table_select,
  NOT EXISTS (
    SELECT 1 FROM pg_attribute a
     WHERE a.attrelid='public.waitlist'::regclass AND a.attnum>0 AND NOT a.attisdropped
       AND has_column_privilege('anon','public.waitlist',a.attname,'SELECT')
  ) AS anon_no_column_select,
  NOT has_table_privilege('anon','public.waitlist','INSERT') AS anon_no_table_insert,
  has_column_privilege('anon','public.waitlist','email','INSERT')
    AND has_column_privilege('anon','public.waitlist','marketing_consent','INSERT')
    AND has_column_privilege('anon','public.waitlist','consent_text_version','INSERT') AS anon_expected_column_inserts,
  NOT EXISTS (
    SELECT 1 FROM pg_attribute a
     WHERE a.attrelid='public.waitlist'::regclass AND a.attnum>0 AND NOT a.attisdropped
       AND a.attname NOT IN ('email','marketing_consent','consent_text_version')
       AND has_column_privilege('anon','public.waitlist',a.attname,'INSERT')
  ) AS anon_no_other_column_insert,
  (SELECT count(*)=1 FROM pg_policies WHERE schemaname='public' AND tablename='waitlist')
    AND EXISTS (
      SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='waitlist'
       AND policyname='Allow public insert to waitlist' AND cmd='INSERT' AND roles::text='{anon}'
       AND with_check='((marketing_consent IS TRUE) AND (consent_text_version IS NOT NULL))'
    ) AS expected_single_policy,
  (SELECT count(*)=1 FROM pg_trigger WHERE tgrelid='public.waitlist'::regclass AND NOT tgisinternal)
    AND EXISTS (
      SELECT 1 FROM pg_trigger t WHERE t.tgrelid='public.waitlist'::regclass
       AND t.tgname='waitlist_set_consent_time' AND NOT t.tgisinternal AND t.tgenabled='O'
       AND t.tgtype=7 AND t.tgfoid=to_regprocedure('public.waitlist_set_consent_time()')
       AND t.tgnargs=0 AND t.tgqual IS NULL
    ) AS expected_single_trigger,
  coalesce(md5(pg_get_functiondef(to_regprocedure('public.waitlist_set_consent_time()')))='67f6c03b46a30f5cef4c9404130ed6a0',false) AS expected_trigger_function,
  EXISTS (
    SELECT 1 FROM pg_attribute a
      JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
      JOIN pg_index i ON i.indrelid=a.attrelid AND i.indexrelid=to_regclass('public.waitlist_unsubscribe_token_key')
     WHERE a.attrelid='public.waitlist'::regclass AND a.attname='unsubscribe_token'
       AND a.attnotnull AND a.atttypid='uuid'::regtype
       AND pg_get_expr(d.adbin,d.adrelid)='gen_random_uuid()'
       AND d.adbin::text LIKE ('{FUNCEXPR :funcid '||'pg_catalog.gen_random_uuid()'::regprocedure::oid||' :%')
       AND i.indisunique AND i.indisvalid AND i.indisready
       AND i.indnkeyatts=1 AND i.indnatts=1 AND i.indkey[0]=a.attnum
       AND i.indpred IS NULL AND i.indexprs IS NULL
  ) AS expected_token_default_and_unique_index,
  (SELECT bool_and(has_table_privilege('service_role','public.waitlist',p))
     FROM unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) AS p) AS service_role_table_privileges_preserved
) AS checks;
ROLLBACK;
