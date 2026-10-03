-- Test yardımcıları. Migration zincirinden SONRA, test dosyalarından ÖNCE
-- yüklenir (bkz. run_local.sh). CANLI veritabanına UYGULAMAYIN.
--
-- Kullanım (DO blokları içinde):
--   PERFORM tests.login('<uuid>');   -- authenticated + auth.uid()
--   PERFORM tests.login(NULL);       -- anon
--   PERFORM tests.logout();          -- test sahibi (süper kullanıcı)
-- Rol ve JWT ayarları transaction sonunda (DO bloğu bitince) sıfırlanır.

CREATE SCHEMA tests;
GRANT USAGE ON SCHEMA tests TO anon, authenticated;

CREATE FUNCTION tests.logout() RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    EXECUTE 'RESET ROLE';
    PERFORM set_config('request.jwt.claim.sub', '', true);
    PERFORM set_config('request.jwt.claims', '', true);
END $$;

CREATE FUNCTION tests.login(p_uid uuid) RETURNS void LANGUAGE plpgsql AS $$
DECLARE
    v_email text;
BEGIN
    PERFORM tests.logout();
    IF p_uid IS NULL THEN
        EXECUTE 'SET LOCAL ROLE anon';
        RETURN;
    END IF;
    SELECT email INTO v_email FROM auth.users WHERE id = p_uid;
    PERFORM set_config('request.jwt.claim.sub', p_uid::text, true);
    PERFORM set_config('request.jwt.claims',
        json_build_object('sub', p_uid, 'role', 'authenticated', 'email', v_email)::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
END $$;

-- SQL'i çağıranın yetkileriyle çalıştırır. Hata yoksa NULL, varsa mesajı
-- (HINT varsa ' [hint: ...]' ekiyle) döndürür. Hata alt transaction'da
-- yakalandığı için RPC'nin o ana kadarki yazmaları geri alınır (REST
-- çağrısındaki gibi).
CREATE FUNCTION tests.error_of(p_sql text) RETURNS text LANGUAGE plpgsql AS $$
DECLARE
    v_msg text;
    v_hint text;
BEGIN
    EXECUTE p_sql;
    RETURN NULL;
EXCEPTION WHEN others THEN
    GET STACKED DIAGNOSTICS v_msg = MESSAGE_TEXT, v_hint = PG_EXCEPTION_HINT;
    RETURN v_msg || CASE WHEN COALESCE(v_hint, '') <> '' THEN ' [hint: ' || v_hint || ']' ELSE '' END;
END $$;

-- complete_study_session'ı istemcinin gönderdiği parametrelerle çağırır.
-- Exception -> {"exception": "<mesaj>"}, yumuşak red -> {"error": ...}.
CREATE FUNCTION tests.session(
    p_category_id uuid,
    p_minutes integer,
    p_started_at timestamptz,
    p_paused boolean DEFAULT false,
    p_client_uuid uuid DEFAULT gen_random_uuid()
) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
    RETURN public.complete_study_session(
        p_client_uuid, p_category_id, p_minutes, p_paused, p_minutes * 60, p_started_at
    );
EXCEPTION WHEN others THEN
    RETURN jsonb_build_object('exception', SQLERRM);
END $$;

CREATE FUNCTION tests.accepted(p_result jsonb) RETURNS boolean LANGUAGE sql IMMUTABLE AS $$
    SELECT p_result IS NOT NULL AND NOT (p_result ? 'error') AND NOT (p_result ? 'exception')
$$;

GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA tests TO anon, authenticated;
