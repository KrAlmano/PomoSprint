-- Maraton sosyal mola desteğini geri alır; geçici mola durumu silinir.
-- Eski istemci/yeni istemci fallback focus-only ile çalışır. Kalıcı seanslar korunur.
BEGIN;
DROP FUNCTION public.get_live_friends_with_breaks();
DROP FUNCTION public.start_study_break(timestamptz);
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
      active_session_category_name = v_name
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
    active_session_category_name = NULL
  WHERE id = auth.uid();
$function$;
ALTER TABLE public.profiles DROP COLUMN active_break_ends_at;
DELETE FROM supabase_migrations.schema_migrations WHERE version='20261007150000';
COMMIT;
