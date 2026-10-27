-- Yapı kontrolü: DRYRUN_RESULT ile tüm transaction geri alınır.
-- Gerçek hesap açmaz veya mail üretmez. İşlev/yarış testleri yalnız izole yerel klonda.
BEGIN;
CREATE TEMP TABLE qa30_before AS SELECT
 (SELECT count(*) FROM public.profiles) profiles,
 (SELECT count(*) FROM public.study_sessions) studies,
 (SELECT count(*) FROM public.session_starts) starts,
 (SELECT count(*) FROM public.avatar_unlocks) unlocks,
 (SELECT coalesce(sum(coins),0) FROM public.profiles) coins;
-- >>> PROPOSED BODY
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
-- <<< PROPOSED BODY
CREATE TEMP TABLE qa30_checks(name text,passed boolean);
INSERT INTO qa30_checks VALUES
 ('T01 expected function hash',md5(pg_get_functiondef('public.register_session_start(uuid,integer)'::regprocedure))='1582a6da3c5e9ff496a8f2c16455b13e'),
 ('T02 authenticated execute',has_function_privilege('authenticated','public.register_session_start(uuid,integer)','execute')),
 ('T03 anon forbidden',NOT has_function_privilege('anon','public.register_session_start(uuid,integer)','execute')),
 ('T04 definer pinned path',EXISTS(SELECT 1 FROM pg_proc WHERE oid='public.register_session_start(uuid,integer)'::regprocedure AND prosecdef AND proconfig=ARRAY['search_path=public, pg_temp'])),
 ('T05 migration once',(SELECT count(*)=1 FROM supabase_migrations.schema_migrations WHERE version='20261028040000')),
 ('T06 profiles unchanged',(SELECT count(*) FROM public.profiles)=(SELECT profiles FROM qa30_before)),
 ('T07 studies unchanged',(SELECT count(*) FROM public.study_sessions)=(SELECT studies FROM qa30_before)),
 ('T08 starts unchanged',(SELECT count(*) FROM public.session_starts)=(SELECT starts FROM qa30_before)),
 ('T09 unlocks unchanged',(SELECT count(*) FROM public.avatar_unlocks)=(SELECT unlocks FROM qa30_before)),
 ('T10 coins unchanged',(SELECT coalesce(sum(coins),0) FROM public.profiles)=(SELECT coins FROM qa30_before));
DO $$ DECLARE result text;BEGIN SELECT string_agg(name||': '||passed::text,' || 'ORDER BY name)INTO result FROM qa30_checks;RAISE EXCEPTION 'DRYRUN_RESULT >> %',result;END $$;
ROLLBACK;
