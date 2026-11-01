-- YALNIZ sabit, sentetik QA veritabanında çalışır; canlı testi değildir.
BEGIN;
DO $$ BEGIN
  IF current_database() <> 'pomosprint_waitlist19b_qa_20261101'
  THEN RAISE EXCEPTION 'wrong_test_database'; END IF;
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
