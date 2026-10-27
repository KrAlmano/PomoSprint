-- CANLIYA UYGULANMADI. Kayıt/puan/kum silmez; eski kota yarışını geri getirir.
\echo 'Öneri 30 down: yalnız bilinçli geri alma; önce README.'
\quit
BEGIN;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='20261028040000' AND name='session_start_atomic') THEN RAISE EXCEPTION 'session_start_atomic_not_installed'; END IF;
 IF md5(pg_get_functiondef('public.register_session_start(uuid,integer)'::regprocedure))<>'1582a6da3c5e9ff496a8f2c16455b13e' THEN RAISE EXCEPTION 'session_start_atomic_down_precondition_changed'; END IF;
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

    -- Var olan kayıt değişmez: başlangıç sonradan kaydırılamaz.
    SELECT s.server_started_at INTO v_started
      FROM public.session_starts s
     WHERE s.user_id = v_uid AND s.client_uuid = p_client_uuid;
    IF FOUND THEN
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

    IF v_started IS NULL THEN
        SELECT s.server_started_at INTO v_started
          FROM public.session_starts s
         WHERE s.user_id = v_uid AND s.client_uuid = p_client_uuid;
    END IF;

    RETURN jsonb_build_object('client_uuid', p_client_uuid, 'server_started_at', v_started,
                              'server_now', now(), 'created', true);
END;
$function$;
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261028040000' AND name='session_start_atomic';
COMMIT;
