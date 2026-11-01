-- ÖNERİ DRYRUN: tamamı ROLLBACK olur; canlıda uygulanmadı.
BEGIN;
SET LOCAL statement_timeout = '30s';
-- ÖNERİ: 19 B'yi mevcut canlı ön koşullarıyla sınırlar; CANLIYA UYGULANMADI.
-- Canlı SQL değişikliği proje kuralındaki DRYRUN ve SQL Editor akışını izler.
-- Mevcut satırlar/tokenlar ve anon dışı yetkiler işlem boyunca korunmalıdır.
-- Sadece özet hesaplanır; e-posta veya token değeri çıktı olarak gösterilmez.
LOCK TABLE public.waitlist IN ACCESS EXCLUSIVE MODE NOWAIT;
CREATE TEMP TABLE waitlist_guard_snapshot ON COMMIT DROP AS
SELECT
  (SELECT count(*) FROM public.waitlist) AS row_count,
  (SELECT md5(coalesce(string_agg(md5(row_to_json(w)::text), '' ORDER BY w.id), '')) FROM public.waitlist w) AS row_digest,
  (SELECT coalesce(jsonb_agg(jsonb_build_array(a.grantee, a.privilege_type, a.is_grantable) ORDER BY a.grantee, a.privilege_type), '[]'::jsonb)
     FROM pg_class c CROSS JOIN LATERAL aclexplode(coalesce(c.relacl, acldefault('r',c.relowner))) a
     WHERE c.oid='public.waitlist'::regclass AND a.grantee <> (SELECT oid FROM pg_roles WHERE rolname='anon')) AS other_table_acl,
  (SELECT coalesce(jsonb_agg(jsonb_build_array(c.attname, a.grantee, a.privilege_type, a.is_grantable) ORDER BY c.attname, a.grantee, a.privilege_type), '[]'::jsonb)
     FROM pg_attribute c CROSS JOIN LATERAL aclexplode(c.attacl) a
     WHERE c.attrelid='public.waitlist'::regclass AND c.attnum > 0 AND NOT c.attisdropped
       AND a.grantee <> (SELECT oid FROM pg_roles WHERE rolname='anon')) AS other_column_acl;
SET LOCAL lock_timeout = '2s';
DO $$
BEGIN
  IF NOT coalesce((SELECT relrowsecurity FROM pg_class WHERE oid=to_regclass('public.waitlist')), false)
     OR EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101223000')
     OR NOT has_table_privilege('anon', 'public.waitlist', 'INSERT')
     OR has_table_privilege('anon', 'public.waitlist', 'SELECT')
     OR EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid='public.waitlist'::regclass
          AND a.attnum>0 AND NOT a.attisdropped AND has_column_privilege('anon','public.waitlist',a.attname,'SELECT'))
     OR (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='waitlist') <> 1
     OR NOT EXISTS (SELECT 1 FROM pg_trigger t WHERE t.tgrelid='public.waitlist'::regclass
          AND t.tgname='waitlist_set_consent_time' AND NOT t.tgisinternal AND t.tgenabled='O'
          AND t.tgtype=7 AND t.tgfoid=to_regprocedure('public.waitlist_set_consent_time()')
          AND t.tgnargs=0 AND t.tgqual IS NULL)
     OR (SELECT count(*) FROM pg_trigger WHERE tgrelid='public.waitlist'::regclass AND NOT tgisinternal) <> 1
     OR NOT EXISTS (SELECT 1 FROM pg_attribute a
          JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
          JOIN pg_index i ON i.indrelid=a.attrelid AND i.indexrelid=to_regclass('public.waitlist_unsubscribe_token_key')
          WHERE a.attrelid='public.waitlist'::regclass AND a.attname='unsubscribe_token'
            AND a.attnotnull AND a.atttypid='uuid'::regtype
            AND pg_get_expr(d.adbin,d.adrelid)='gen_random_uuid()'
            AND d.adbin::text LIKE ('{FUNCEXPR :funcid '||'pg_catalog.gen_random_uuid()'::regprocedure::oid||' :%')
            AND i.indisunique AND i.indisvalid AND i.indisready
            AND i.indnkeyatts=1 AND i.indnatts=1 AND i.indkey[0]=a.attnum
            AND i.indpred IS NULL AND i.indexprs IS NULL)
     OR EXISTS (SELECT 1 FROM pg_attribute a CROSS JOIN LATERAL aclexplode(a.attacl) acl
                WHERE a.attrelid='public.waitlist'::regclass AND a.attnum > 0
                  AND acl.grantee=(SELECT oid FROM pg_roles WHERE rolname='anon')
                  AND acl.privilege_type='INSERT')
     OR NOT EXISTS (
       SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='waitlist'
        AND policyname='Allow public insert to waitlist' AND cmd='INSERT'
        AND roles::text='{anon}' AND with_check='true'
     )
     OR (SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='waitlist' AND cmd IN ('INSERT','ALL')) <> 1
     OR to_regprocedure('public.waitlist_set_consent_time()') IS NULL
     OR md5(pg_get_functiondef(to_regprocedure('public.waitlist_set_consent_time()'))) <> '67f6c03b46a30f5cef4c9404130ed6a0'
     OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='public.waitlist'::regclass
          AND tgname='waitlist_set_consent_time' AND NOT tgisinternal AND tgenabled='O')
     OR (SELECT count(*) FROM pg_trigger WHERE tgrelid='public.waitlist'::regclass AND NOT tgisinternal) <> 1
  THEN RAISE EXCEPTION 'waitlist_guard_baseline_changed'; END IF;
END $$;

-- Sunucu değerleri (id/zaman/token) anonim istemci tarafından seçilemez.
REVOKE INSERT ON public.waitlist FROM anon;
REVOKE INSERT (id,email,created_at,unsubscribe_token,marketing_consent,consent_text_version,consented_at)
  ON public.waitlist FROM anon;
GRANT INSERT (email,marketing_consent,consent_text_version) ON public.waitlist TO anon;
ALTER POLICY "Allow public insert to waitlist" ON public.waitlist
  WITH CHECK (marketing_consent IS TRUE AND consent_text_version IS NOT NULL);

DO $$
BEGIN
  IF has_table_privilege('anon','public.waitlist','INSERT')
     OR EXISTS (SELECT 1 FROM pg_attribute a WHERE a.attrelid='public.waitlist'::regclass
          AND a.attnum>0 AND NOT a.attisdropped
          AND a.attname NOT IN ('email','marketing_consent','consent_text_version')
          AND has_column_privilege('anon','public.waitlist',a.attname,'INSERT'))
     OR has_column_privilege('anon','public.waitlist','unsubscribe_token','INSERT')
     OR has_column_privilege('anon','public.waitlist','consented_at','INSERT')
     OR has_column_privilege('anon','public.waitlist','created_at','INSERT')
     OR has_column_privilege('anon','public.waitlist','id','INSERT')
     OR NOT has_column_privilege('anon','public.waitlist','email','INSERT')
     OR NOT has_column_privilege('anon','public.waitlist','marketing_consent','INSERT')
     OR NOT has_column_privilege('anon','public.waitlist','consent_text_version','INSERT')
  THEN RAISE EXCEPTION 'waitlist_guard_postcondition_failed'; END IF;
END $$;
INSERT INTO supabase_migrations.schema_migrations(version,name)
  VALUES('20261101223000','waitlist_consent_guard');
DO $$
DECLARE s record; n bigint; d text; t jsonb; c jsonb;
BEGIN
  SELECT * INTO STRICT s FROM waitlist_guard_snapshot;
  SELECT count(*), md5(coalesce(string_agg(md5(row_to_json(w)::text), '' ORDER BY w.id), '')) INTO n,d FROM public.waitlist w;
  SELECT coalesce(jsonb_agg(jsonb_build_array(a.grantee, a.privilege_type, a.is_grantable) ORDER BY a.grantee, a.privilege_type), '[]'::jsonb) INTO t
    FROM pg_class p CROSS JOIN LATERAL aclexplode(coalesce(p.relacl, acldefault('r',p.relowner))) a
    WHERE p.oid='public.waitlist'::regclass AND a.grantee <> (SELECT oid FROM pg_roles WHERE rolname='anon');
  SELECT coalesce(jsonb_agg(jsonb_build_array(p.attname, a.grantee, a.privilege_type, a.is_grantable) ORDER BY p.attname, a.grantee, a.privilege_type), '[]'::jsonb) INTO c
    FROM pg_attribute p CROSS JOIN LATERAL aclexplode(p.attacl) a
    WHERE p.attrelid='public.waitlist'::regclass AND p.attnum > 0 AND NOT p.attisdropped
      AND a.grantee <> (SELECT oid FROM pg_roles WHERE rolname='anon');
  IF n IS DISTINCT FROM s.row_count OR d IS DISTINCT FROM s.row_digest
     OR t IS DISTINCT FROM s.other_table_acl OR c IS DISTINCT FROM s.other_column_acl
  THEN RAISE EXCEPTION 'waitlist_data_or_other_acl_changed'; END IF;
END $$;
DO $$
DECLARE
  v_email text := 'waitlist-qa-'||gen_random_uuid()||'@example.invalid';
  v_attacker text := 'waitlist-qa-'||gen_random_uuid()||'@example.invalid';
  v_count integer; v_created timestamptz; v_token uuid; v_consent boolean;
  v_error boolean;
BEGIN
  -- Mevcut canlı formunun minimum gövdesi, sunucunun oluşturduğu zaman/token.
  EXECUTE 'SET LOCAL ROLE anon';
  INSERT INTO public.waitlist(email,marketing_consent,consent_text_version)
    VALUES(v_email,true,'waitlist-2026-10-03');
  EXECUTE 'RESET ROLE';
  SELECT count(*),min(consented_at),min(unsubscribe_token::text)::uuid,bool_and(marketing_consent)
    INTO v_count,v_created,v_token,v_consent FROM public.waitlist WHERE email=v_email;
  IF v_count<>1 OR v_created IS DISTINCT FROM now() OR v_token IS NULL OR v_consent IS NOT TRUE
  THEN RAISE EXCEPTION 'legitimate_signup_failed'; END IF;

  v_error:=false;
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    INSERT INTO public.waitlist(email) VALUES(v_attacker);
  EXCEPTION WHEN insufficient_privilege THEN v_error:=true; END;
  EXECUTE 'RESET ROLE';
  IF NOT v_error THEN RAISE EXCEPTION 'missing_consent_was_accepted'; END IF;

  v_error:=false;
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    INSERT INTO public.waitlist(email,marketing_consent,consent_text_version)
      VALUES(v_attacker,false,'waitlist-2026-10-03');
  EXCEPTION WHEN insufficient_privilege THEN v_error:=true; END;
  EXECUTE 'RESET ROLE';
  IF NOT v_error THEN RAISE EXCEPTION 'false_consent_was_accepted'; END IF;

  v_error:=false;
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    INSERT INTO public.waitlist(email,marketing_consent) VALUES(v_attacker,true);
  EXCEPTION WHEN insufficient_privilege THEN v_error:=true; END;
  EXECUTE 'RESET ROLE';
  IF NOT v_error THEN RAISE EXCEPTION 'missing_version_was_accepted'; END IF;

  v_error:=false;
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    INSERT INTO public.waitlist(email,marketing_consent,consent_text_version,unsubscribe_token)
      VALUES(v_attacker,true,'waitlist-2026-10-03',gen_random_uuid());
  EXCEPTION WHEN insufficient_privilege THEN v_error:=true; END;
  EXECUTE 'RESET ROLE';
  IF NOT v_error THEN RAISE EXCEPTION 'chosen_token_was_accepted'; END IF;

  IF has_column_privilege('anon','public.waitlist','id','INSERT')
     OR has_column_privilege('anon','public.waitlist','created_at','INSERT')
     OR has_column_privilege('anon','public.waitlist','consented_at','INSERT')
     OR has_table_privilege('anon','public.waitlist','SELECT')
  THEN RAISE EXCEPTION 'server_generated_columns_or_select_were_granted'; END IF;
  IF (SELECT count(*) FROM public.waitlist WHERE email=v_attacker)<>0
  THEN RAISE EXCEPTION 'rejected_input_wrote_a_row'; END IF;
END $$;
ROLLBACK;
SELECT 'waitlist consent guard checks passed; rolled back' AS result;
