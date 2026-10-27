-- 20261007110000_report_submission_lock
-- 8 Ekim 2026 CANLIYA UYGULANDI: incelenmiş CLI Management API transaction.
-- Önce canlı DRYRUN 23/23, sonra geri alınan 23/23 ve salt okuma 9/9 geçti.
-- Güncel hash a7ee1b72778b92b59982e5bba8b86c7a; yeniden uygulamayın.
-- Kökte CLI db push/reset kullanmayın; kapsam istisnası AGENTS.md §2.4.
-- Kaynak: 7 Ekim 2026 canlı pg_get_functiondef, md5 547b73d8a9163466b19dafb4b89e9fe3.
-- İzole yerel gerçek HTTP: aynı hedefe paralel iki istek iki kayıt açıyor;
-- 9 bildirimi olan hesap iki paralel yeni hedefle 11'e çıkabiliyor.
-- Yalnız bildiriciye özgü transaction advisory kilidi eklendi. İmza, JSON,
-- neden/yer kodları, açık kayıt için 24 saat duplicate ve 10/24h sınırı aynı.
-- Mevcut veriler silinmez/düzenlenmez; RLS, tablo ve RPC yetkileri değişmez.
-- İlgili dryrun: supabase/tests/20261007_report_submission_lock_dryrun.sql
-- Yarış testi: supabase/tests/20261007_report_submission_lock_local.py
-- Geri alma: supabase/rollbacks/20261007110000_report_submission_lock_down.sql

BEGIN;

DO $pre$
BEGIN
    IF md5(pg_get_functiondef('public.submit_user_report(uuid,text,text,text)'::regprocedure))
       IS DISTINCT FROM '547b73d8a9163466b19dafb4b89e9fe3' THEN
        RAISE EXCEPTION 'report_submission_lock ön koşulu: canlı submit_user_report tanımı değişmiş; dosyayı yeni canlı gövdeye uyarlayın.';
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

    -- Aynı bildiricinin tekrar ve 24 saatlik limit denetimleri ile INSERT'i
    -- tek işlem olarak sırala. Profil satırı kilitlenmez; farklı bildiriciler
    -- ayrı advisory anahtarları kullanır. Kilit COMMIT/ROLLBACK ile bırakılır.
    PERFORM pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended('pomosprint:user_report:' || v_uid::text, 0));

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

INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES ('20261007110000', 'report_submission_lock')
ON CONFLICT (version) DO NOTHING;

COMMIT;
