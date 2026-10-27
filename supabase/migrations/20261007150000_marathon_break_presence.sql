-- HAZIRLANDI; CANLIYA UYGULANMADI. Kullanıcı SQL Editor'de önce DRYRUN,
-- sonra bu migration'ı çalıştırır. CLI db push/reset kullanmayın.
-- Kaynak: 7 Ekim salt-okuma ile409 katalog eşitliği doğrulanmış yerel canlı kopyası.
-- Eski get_live_friends focus-only kalır; eski uygulama molayı odak saymaz.
-- Yeni RPC additive; mola ne çalışma seansı ne ödül/rapor verisi oluşturur.
-- Mola bitişi gelecekte ve en çok5dk10sn; BLOCK/arkadaş/görünürlük aynı filtre.
-- Rollback yalnız geçici mola durumunu kaybeder; seans/puan/arkadaş verisi değişmez.

BEGIN;

DO $pre$
BEGIN
  IF md5(pg_get_functiondef('public.start_study_session(integer,text)'::regprocedure)) IS DISTINCT FROM '0a109f61759dae7ddea73b0a68919cae'
     OR md5(pg_get_functiondef('public.cancel_study_session()'::regprocedure)) IS DISTINCT FROM '7c1adf25d21513e01f70ffe792957ba2'
     OR md5(pg_get_functiondef('public.get_live_friends()'::regprocedure)) IS DISTINCT FROM 'b7edb95b65e1f04b6a298c97b250aa30'
     OR EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='active_break_ends_at')
     OR to_regprocedure('public.start_study_break(timestamptz)') IS NOT NULL
     OR to_regprocedure('public.get_live_friends_with_breaks()') IS NOT NULL THEN
    RAISE EXCEPTION 'marathon_break_presence ön koşulu değişmiş; güncel canlı tanımdan yeniden hazırlayın.';
  END IF;
END
$pre$;

ALTER TABLE public.profiles ADD COLUMN active_break_ends_at timestamptz;
COMMENT ON COLUMN public.profiles.active_break_ends_at IS 'Temporary marathon break presence. Set only by owner RPC; never study time/rewards.';
REVOKE INSERT (active_break_ends_at), UPDATE (active_break_ends_at) ON public.profiles FROM anon, authenticated;

CREATE OR REPLACE FUNCTION public.start_study_session(p_duration_minutes integer, p_category_name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_name text;
BEGIN
    IF p_duration_minutes IS NULL OR p_duration_minutes < 0 OR p_duration_minutes > 50 THEN
        RAISE EXCEPTION 'invalid duration: 0..50 minutes allowed';
    END IF;

    v_name := nullif(btrim(left(public.clean_display_text(p_category_name), 40)), '');
    IF v_name IS NOT NULL AND NOT public.display_text_is_allowed(v_name) THEN
        v_name := NULL;
    END IF;

    UPDATE public.profiles
    SET
      active_session_ends_at = now() + (p_duration_minutes * interval '1 minute'),
      active_session_category_name = v_name,
      active_break_ends_at = NULL
    WHERE id = auth.uid();
END;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_study_session()
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  UPDATE public.profiles 
  SET 
    active_session_ends_at = NULL,
    active_session_category_name = NULL,
    active_break_ends_at = NULL
  WHERE id = auth.uid();
$function$;

CREATE OR REPLACE FUNCTION public.start_study_break(p_ends_at timestamptz)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  IF p_ends_at IS NULL OR p_ends_at <= now() OR p_ends_at > now() + interval '5 minutes 10 seconds' THEN
    RAISE EXCEPTION 'invalid break end: future maximum 5 minutes 10 seconds';
  END IF;
  -- Yalnız çağıranın geçici durumu; gizli kullanıcı için iki durum da kapanır.
  UPDATE public.profiles
  SET active_session_ends_at = NULL,
      active_session_category_name = NULL,
      active_break_ends_at = CASE WHEN show_in_social_feed THEN p_ends_at ELSE NULL END
  WHERE id = v_uid;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_live_friends_with_breaks()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_result jsonb;
BEGIN
    IF v_uid IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    -- Kabul edilen arkadaşlıklar iki yönlü satırla tutuluyor; önceki
    -- OR-join her arkadaşı iki kez döndürüyordu.
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'name', p.name,
            'avatar_id', p.avatar_id,
            'category_name', CASE WHEN p.active_session_ends_at > now() THEN p.active_session_category_name END,
            'ends_at', CASE WHEN p.active_session_ends_at > now() THEN p.active_session_ends_at ELSE p.active_break_ends_at END,
            'status', CASE WHEN p.active_session_ends_at > now() THEN 'focus' ELSE 'break' END
        ) ORDER BY COALESCE(p.active_session_ends_at, p.active_break_ends_at)
    ), '[]'::jsonb)
    INTO v_result
    FROM public.profiles p
    WHERE p.id <> v_uid
      AND p.id IN (
          SELECT CASE WHEN f.user_id = v_uid THEN f.friend_id ELSE f.user_id END
          FROM public.friendships f
          WHERE f.status = 'accepted' AND (f.user_id = v_uid OR f.friend_id = v_uid)
      )
      AND NOT EXISTS (
          SELECT 1 FROM public.user_blocks b
          WHERE (b.blocker_id = v_uid AND b.blocked_id = p.id)
             OR (b.blocker_id = p.id AND b.blocked_id = v_uid)
      )
      AND p.show_in_social_feed = true
      AND (p.active_session_ends_at > now() OR p.active_break_ends_at > now());

    RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.start_study_break(timestamptz), public.get_live_friends_with_breaks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.start_study_break(timestamptz), public.get_live_friends_with_breaks() TO authenticated, service_role;
INSERT INTO supabase_migrations.schema_migrations(version,name)
VALUES ('20261007150000','marathon_break_presence') ON CONFLICT(version) DO NOTHING;

COMMIT;
