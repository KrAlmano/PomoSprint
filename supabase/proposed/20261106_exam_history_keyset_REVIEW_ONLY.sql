-- REVIEW ONLY: never run directly; application and rollout compatibility must be reviewed.
\quit
BEGIN;
DO $$
BEGIN
  IF to_regprocedure('public.get_my_exam_attempts_v2(integer,timestamptz,uuid)') IS NOT NULL THEN
    RAISE EXCEPTION 'exam_history_v2_already_exists';
  END IF;
  IF to_regprocedure('public._exam_payload(uuid)') IS NULL
     OR to_regclass('public.exam_attempts') IS NULL THEN
    RAISE EXCEPTION 'exam_history_baseline_missing';
  END IF;
END $$;

-- A timestamp plus a UUID is a total order, even when timestamps are equal.
-- The existing RPC remains unchanged for applications that do not know v2.
CREATE FUNCTION public.get_my_exam_attempts_v2(
  p_limit integer DEFAULT 100,
  p_before_started_at timestamptz DEFAULT NULL,
  p_before_id uuid DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_limit integer := greatest(1,least(coalesce(p_limit,100),1000));
  v_rows jsonb;
  v_cursor_time timestamptz;
  v_cursor_id uuid;
  v_count integer;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not authenticated'; END IF;
  IF (p_before_started_at IS NULL) <> (p_before_id IS NULL) THEN
    RAISE EXCEPTION 'exam_history_cursor_invalid';
  END IF;
  WITH page AS (
    SELECT id,started_at FROM public.exam_attempts a
     WHERE a.user_id=v_uid
       AND (p_before_started_at IS NULL OR (a.started_at,a.id)<(p_before_started_at,p_before_id))
     ORDER BY a.started_at DESC,a.id DESC LIMIT v_limit
  )
  SELECT coalesce(jsonb_agg(public._exam_payload(id) ORDER BY started_at DESC,id DESC),'[]'::jsonb),
         (array_agg(started_at ORDER BY started_at ASC,id ASC))[1],
         (array_agg(id ORDER BY started_at ASC,id ASC))[1],count(*)
    INTO v_rows,v_cursor_time,v_cursor_id,v_count FROM page;
  RETURN jsonb_build_object('server_time',clock_timestamp(),'attempts',v_rows,
    'next_cursor',CASE WHEN v_count=v_limit THEN
      jsonb_build_object('started_at',v_cursor_time,'id',v_cursor_id) ELSE NULL END);
END $$;
REVOKE ALL ON FUNCTION public.get_my_exam_attempts_v2(integer,timestamptz,uuid) FROM PUBLIC,anon,authenticated,service_role;
GRANT EXECUTE ON FUNCTION public.get_my_exam_attempts_v2(integer,timestamptz,uuid) TO authenticated;
COMMIT;
