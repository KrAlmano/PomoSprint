-- ADAY A: yalnız 19-B korumasından sonra; canlıya uygulanmadı.
-- 19-B ve eski form hâlâ çalışırken RPC ekler. Doğrudan INSERT bu aşamada açıktır.
\echo 'ADAY: inceleme ve yerel test olmadan uygulamayın.'
\quit
BEGIN;
SET LOCAL lock_timeout='2s';
LOCK TABLE public.waitlist IN ACCESS EXCLUSIVE MODE NOWAIT;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261101223000' AND name='waitlist_consent_guard')
     OR to_regnamespace('waitlist_private') IS NOT NULL
     OR to_regprocedure('public.submit_waitlist(text,boolean,text)') IS NOT NULL
     OR to_regclass('public.waitlist_email_lower_guard_idx') IS NOT NULL
     OR EXISTS (SELECT 1 FROM public.waitlist GROUP BY lower(email) HAVING count(*) > 1)
     OR has_table_privilege('anon','public.waitlist','INSERT')
     OR NOT has_column_privilege('anon','public.waitlist','email','INSERT')
  THEN RAISE EXCEPTION 'waitlist_rpc_baseline_changed'; END IF;
END $$;
CREATE UNIQUE INDEX waitlist_email_lower_guard_idx ON public.waitlist(lower(email));
CREATE SCHEMA waitlist_private;
REVOKE ALL ON SCHEMA waitlist_private FROM PUBLIC, anon, authenticated;
CREATE TABLE waitlist_private.budget (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  window_start timestamptz NOT NULL,
  attempts integer NOT NULL CHECK (attempts > 0 AND attempts <= 120)
);
REVOKE ALL ON ALL TABLES IN SCHEMA waitlist_private FROM PUBLIC, anon, authenticated;
CREATE FUNCTION public.submit_waitlist(p_email text, p_marketing_consent boolean, p_consent_text_version text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $$
DECLARE v_email text := lower(btrim(p_email)); v_attempts integer;
BEGIN
  -- Geçersiz gövde ve açık onayın yokluğu kayıt üretmez.
  IF p_marketing_consent IS DISTINCT FROM true OR p_consent_text_version IS NULL
     OR length(p_consent_text_version) NOT BETWEEN 1 AND 64
     OR p_consent_text_version <> btrim(p_consent_text_version)
     OR v_email IS NULL OR length(v_email)>254
     OR v_email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
  THEN RETURN jsonb_build_object('accepted',false,'reason','invalid_input'); END IF;
  -- Tek satır üzerinde atomik saatlik üst sınır: yeni kayıt + tekrar eşit sayılır.
  INSERT INTO waitlist_private.budget(singleton,window_start,attempts)
    VALUES(true,clock_timestamp(),1)
  ON CONFLICT(singleton) DO UPDATE SET
    window_start=CASE WHEN waitlist_private.budget.window_start <= clock_timestamp()-interval '1 hour'
      THEN clock_timestamp() ELSE waitlist_private.budget.window_start END,
    attempts=CASE WHEN waitlist_private.budget.window_start <= clock_timestamp()-interval '1 hour'
      THEN 1 ELSE waitlist_private.budget.attempts+1 END
  WHERE waitlist_private.budget.window_start <= clock_timestamp()-interval '1 hour'
     OR waitlist_private.budget.attempts < 120
  RETURNING attempts INTO v_attempts;
  IF v_attempts IS NULL THEN RETURN jsonb_build_object('accepted',false,'reason','rate_limited'); END IF;
  INSERT INTO public.waitlist(email,marketing_consent,consent_text_version)
    VALUES(v_email,true,p_consent_text_version) ON CONFLICT DO NOTHING;
  -- Yeni ve daha önce var olan adresler aynı sonucu alır.
  RETURN jsonb_build_object('accepted',true);
END $$;
REVOKE ALL ON FUNCTION public.submit_waitlist(text,boolean,text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_waitlist(text,boolean,text) TO anon;
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261101235501','waitlist_rpc_abuse_guard');
COMMIT;
