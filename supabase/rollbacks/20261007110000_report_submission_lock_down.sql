-- GERİ ALMA: 20261007110000_report_submission_lock
-- 7 Ekim canlı gövdeyi birebir geri getirir; veri/RLS/yetki değişmez.
-- DİKKAT: aynı hedef ve günlük sınır için eşzamanlılık hatasını geri getirir.
BEGIN;
DO $pre$
BEGIN
    IF md5(pg_get_functiondef('public.submit_user_report(uuid,text,text,text)'::regprocedure))
       IS DISTINCT FROM 'a7ee1b72778b92b59982e5bba8b86c7a' THEN
        RAISE EXCEPTION 'report_submission_lock down ön koşulu: fonksiyon düzeltmeden sonra değişmiş; eski gövdeyle üzerine yazmayın.';
    END IF;
END
$pre$;

CREATE OR REPLACE FUNCTION public.submit_user_report(p_target_user_id uuid, p_place text, p_reason text, p_details text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_place text := lower(btrim(coalesce(p_place, '')));
    v_reason text := lower(btrim(coalesce(p_reason, '')));
    v_details text := nullif(left(btrim(coalesce(p_details, '')), 500), '');
    v_existing uuid;
    v_recent integer;
    v_name text;
    v_content text;
    v_id uuid;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;
    IF v_place NOT IN ('league', 'monthly', 'friends_ranking', 'live_feed', 'friends_list', 'friend_request', 'other') THEN
        RETURN jsonb_build_object('success', false, 'code', 'invalid_place');
    END IF;
    IF v_reason NOT IN ('offensive_name', 'offensive_content', 'harassment', 'spam', 'impersonation', 'other') THEN
        RETURN jsonb_build_object('success', false, 'code', 'invalid_reason');
    END IF;
    IF p_target_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'code', 'not_found');
    END IF;
    IF p_target_user_id = v_uid THEN
        RETURN jsonb_build_object('success', false, 'code', 'self');
    END IF;

    SELECT p.name, p.active_session_category_name INTO v_name, v_content
      FROM public.profiles p WHERE p.id = p_target_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'code', 'not_found');
    END IF;

    SELECT r.id INTO v_existing
      FROM public.user_reports r
     WHERE r.reporter_id = v_uid AND r.target_user_id = p_target_user_id
       AND r.status = 'open' AND r.created_at > now() - interval '24 hours'
     ORDER BY r.created_at DESC
     LIMIT 1;
    IF v_existing IS NOT NULL THEN
        RETURN jsonb_build_object('success', true, 'code', 'duplicate', 'duplicate', true, 'report_id', v_existing);
    END IF;

    SELECT count(*) INTO v_recent
      FROM public.user_reports r
     WHERE r.reporter_id = v_uid AND r.created_at > now() - interval '24 hours';
    IF v_recent >= 10 THEN
        RETURN jsonb_build_object('success', false, 'code', 'rate_limited');
    END IF;

    INSERT INTO public.user_reports (reporter_id, target_user_id, place, reason, details,
                                     target_name_snapshot, target_content_snapshot)
    VALUES (v_uid, p_target_user_id, v_place, v_reason, v_details,
            v_name, CASE WHEN v_place = 'live_feed' THEN v_content END)
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('success', true, 'code', 'reported', 'duplicate', false, 'report_id', v_id);
END;
$function$;

DELETE FROM supabase_migrations.schema_migrations
 WHERE version='20261007110000' AND name='report_submission_lock';
COMMIT;
