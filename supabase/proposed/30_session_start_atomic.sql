-- HAZIRLANDI / CANLIYA UYGULANMADI. 13'ün register_session_start RPC'si gerekir.
-- 27/28/29'dan bağımsız ek güvenlik düzeltmesi; onların tablolarını değiştirmez.
\echo 'Öneri 30: README/DRYRUN incelemeden çalıştırmayın; SQL Editor için echo/quit satırlarını çıkarın.'
\quit
BEGIN;
DO $$ BEGIN
 IF to_regclass('public.session_starts') IS NULL THEN RAISE EXCEPTION 'session_start_atomic_requires_session_starts'; END IF;
 IF EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261028040000') THEN RAISE EXCEPTION 'session_start_atomic_already_applied'; END IF;
 IF md5(pg_get_functiondef('public.register_session_start(uuid,integer)'::regprocedure))<>'9500c7c45503a3e5031e52c879b1dba2' THEN RAISE EXCEPTION 'session_start_atomic_precondition_changed'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.register_session_start(p_client_uuid uuid, p_duration_minutes integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_started timestamptz;
    v_recent integer;
    v_duration integer;
    v_created boolean;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;
    IF p_client_uuid IS NULL THEN
        RAISE EXCEPTION 'invalid client_uuid';
    END IF;
    IF p_duration_minutes IS NULL OR p_duration_minutes NOT IN (25, 50) THEN
        RAISE EXCEPTION 'invalid duration: only 25 or 50 allowed';
    END IF;

    -- proposed/30: aynı kullanıcıda kota ve UUID denetimi tek sırada yapılır.
    -- Kilit sırası normal tamamlama/avatar satın alma ile aynıdır: profil önce.
    PERFORM 1 FROM public.profiles WHERE id = v_uid FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'not authenticated: profile_not_found';
    END IF;

    -- Var olan kayıt değişmez: başlangıç sonradan kaydırılamaz.
    SELECT s.server_started_at, s.duration_minutes INTO v_started, v_duration
      FROM public.session_starts s
     WHERE s.user_id = v_uid AND s.client_uuid = p_client_uuid;
    IF FOUND THEN
        IF v_duration <> p_duration_minutes THEN
            RAISE EXCEPTION 'invalid duration: session_start_metadata_conflict';
        END IF;
        RETURN jsonb_build_object('client_uuid', p_client_uuid, 'server_started_at', v_started,
                                  'server_now', now(), 'created', false);
    END IF;

    -- Tamamlanmamış / terk edilmiş eski başlangıçlar (seans 24 saatten
    -- eskiyse zaten kabul edilmez).
    DELETE FROM public.session_starts
     WHERE user_id = v_uid AND server_started_at < now() - interval '48 hours';

    SELECT count(*) INTO v_recent
      FROM public.session_starts
     WHERE user_id = v_uid AND server_started_at > now() - interval '24 hours';
    IF v_recent >= 100 THEN
        RAISE EXCEPTION 'too_many_session_starts';
    END IF;

    INSERT INTO public.session_starts (user_id, client_uuid, duration_minutes, server_started_at)
    VALUES (v_uid, p_client_uuid, p_duration_minutes, now())
    ON CONFLICT (user_id, client_uuid) DO NOTHING
    RETURNING server_started_at INTO v_started;

    v_created := v_started IS NOT NULL;
    IF v_started IS NULL THEN
        SELECT s.server_started_at INTO v_started
          FROM public.session_starts s
         WHERE s.user_id = v_uid AND s.client_uuid = p_client_uuid;
    END IF;

    RETURN jsonb_build_object('client_uuid', p_client_uuid, 'server_started_at', v_started,
                              'server_now', now(), 'created', v_created);
END;
$function$;
INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES('20261028040000','session_start_atomic');
COMMIT;
