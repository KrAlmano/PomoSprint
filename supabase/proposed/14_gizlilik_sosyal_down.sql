-- ============================================================
-- GERİ ALMA: ÖNERİ 14 (gizlilik ve sosyal güvenlik)
-- ============================================================
-- 3 Ekim 2026 canlı gövdelerine döner (pg_get_functiondef ile okundu):
-- add_friend_by_code, respond_friend_request, get_my_friends,
-- get_incoming_friend_requests, get_live_friends, mask_public_name,
-- get_league_ranking, get_my_league_ranking, get_public_monthly_leaderboard,
-- get_public_alltime_leaderboard, handle_new_user,
-- handle_newsletter_subscription, sanitize_profile_insert; activity_feed
-- politikası ve SELECT yetkisi; show_in_social_feed varsayılanı (true).
-- Aylık sıralama, 14 uygulanırken hangi gövde varsa ona döner (canlı ya da
-- proposed/15). Yerel taklitte doğrulandı: 14 + bu dosya sonrası tüm
-- fonksiyonların md5'i canlıyla aynı.
--
-- VERİ KAYBI: user_blocks, friend_request_rejections, user_reports ve
-- consents tabloları SİLİNİR (engeller, bildirimler, onay ispat kayıtları).
-- Verileri saklamak istiyorsanız en alttaki "TABLOLAR" bölümündeki DROP
-- TABLE satırlarını çalıştırmayın; tablolar kullanılmadan kalır (RLS açık,
-- istemci yetkisi yok). Öneri uygulandığı sürede saklama işiyle silinen
-- kayıtlar (onaysız hesaplar, eski bekleme listesi), silinen activity_feed
-- kayıtları ve nötr ad verilen profillerin eski adları geri gelmez.
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ (\quit). Gerekirse
-- \echo/\quit satırları olmadan SQL Editor'de çalıştırın.
-- ============================================================

\echo 'supabase/proposed/14_down: doğrudan çalıştırılmaz.'
\quit

BEGIN;

-- ------------------------------------------------------------
-- H) Saklama işi
-- ------------------------------------------------------------
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'privacy_retention_daily';

-- ------------------------------------------------------------
-- G) activity_feed
-- ------------------------------------------------------------
DROP TRIGGER activity_feed_guard ON public.activity_feed;
DROP TRIGGER activity_feed_on_visibility_off ON public.profiles;
DROP FUNCTION public.activity_feed_guard();
DROP FUNCTION public.activity_feed_on_visibility_off();
DROP POLICY "Users can see their own activity feed" ON public.activity_feed;
CREATE POLICY "Users can see their own and friends activity feed"
    ON public.activity_feed FOR SELECT TO public
    USING (
        (user_id = (SELECT auth.uid() AS uid))
        OR (user_id IN (
            SELECT CASE WHEN (f.user_id = (SELECT auth.uid() AS uid)) THEN f.friend_id ELSE f.user_id END AS user_id
              FROM public.friendships f
             WHERE (f.status = 'accepted'::text)
               AND ((f.user_id = (SELECT auth.uid() AS uid)) OR (f.friend_id = (SELECT auth.uid() AS uid)))
        ))
    );
GRANT SELECT ON public.activity_feed TO authenticated;

-- ------------------------------------------------------------
-- F) Bildirimler
-- ------------------------------------------------------------
DROP FUNCTION public.submit_user_report(uuid, text, text, text);
-- Görünüm tabloya bağlı; tablo (aşağıda) silinmeden önce kalkmalı.
DROP VIEW ops.open_user_reports;

-- ------------------------------------------------------------
-- E) Sıralamalar (canlı gövdeler)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mask_public_name(p_name text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT CASE
        WHEN p_name IS NULL OR btrim(p_name) = '' THEN NULL
        WHEN array_length(regexp_split_to_array(btrim(p_name), '\s+'), 1) = 1 THEN btrim(p_name)
        ELSE (regexp_split_to_array(btrim(p_name), '\s+'))[1] || ' '
             || upper(left((regexp_split_to_array(btrim(p_name), '\s+'))[2], 1)) || '.'
    END;
$function$;

DROP FUNCTION public.get_my_league_ranking();
DROP FUNCTION public.get_league_ranking(uuid);

CREATE FUNCTION public.get_league_ranking(p_user_id uuid)
 RETURNS TABLE(name text, avatar_id text, weekly_points integer, tier integer, end_date timestamp with time zone, is_me boolean, promotion_zone_end integer, demotion_zone_start integer, member_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_league_id UUID;
    v_tier INTEGER;
    v_end_date TIMESTAMPTZ;
    v_member_count INTEGER;
    v_promo_end INTEGER;
    v_demo_start INTEGER;
BEGIN
    -- Yalnızca kendi ligini görebilirsin (önceden herhangi bir kullanıcı id'si
    -- ile, oturumsuz bile çağrılabiliyordu).
    IF p_user_id IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'not authorized';
    END IF;

    SELECT l.id, l.tier, l.end_date
    INTO v_league_id, v_tier, v_end_date
    FROM public.league_memberships lm
    JOIN public.leagues l ON l.id = lm.league_id
    WHERE lm.user_id = p_user_id AND l.is_active = true
    LIMIT 1;

    IF v_league_id IS NULL THEN
        SELECT league_tier INTO v_tier FROM public.profiles WHERE id = p_user_id;
        -- ensure_user_in_league ile aynı 14 günlük dönem sonu
        v_end_date := ((date_trunc('week', (current_timestamp AT TIME ZONE 'Europe/Istanbul')::date::timestamp) + interval '13 days') + time '23:59:59') AT TIME ZONE 'Europe/Istanbul';
        RETURN QUERY
        SELECT
            p.name, p.avatar_id, 0, v_tier, v_end_date, true, 1, 999, 1
        FROM public.profiles p WHERE p.id = p_user_id;
        RETURN;
    END IF;

    SELECT count(*) INTO v_member_count FROM public.league_memberships WHERE league_id = v_league_id;

    SELECT z.promotion_zone_end, z.demotion_zone_start
    INTO v_promo_end, v_demo_start
    FROM public.get_league_zones(v_member_count) z;

    -- İlk 3'teki (ve puanı olan) üyeler bu ekranda lig ödülü avatarıyla
    -- görünür; profiles.avatar_id'ye dokunulmaz. Sıralama, dönem sonu
    -- işlemiyle (process_weekly_leagues) birebir aynı kuraldır.
    RETURN QUERY
    SELECT
        p.name,
        COALESCE(
            CASE WHEN ranked.weekly_points > 0
                 THEN public.league_award_avatar_id(v_tier, ranked.rnk::integer) END,
            p.avatar_id) AS avatar_id,
        ranked.weekly_points,
        v_tier,
        v_end_date,
        (ranked.user_id = p_user_id),
        v_promo_end,
        v_demo_start,
        v_member_count
    FROM (
        SELECT lm.user_id, lm.weekly_points, lm.joined_at,
               row_number() OVER (ORDER BY lm.weekly_points DESC, lm.joined_at ASC, lm.user_id) AS rnk
        FROM public.league_memberships lm
        WHERE lm.league_id = v_league_id
    ) ranked
    JOIN public.profiles p ON p.id = ranked.user_id
    ORDER BY ranked.rnk ASC;
END;
$function$;
REVOKE ALL ON FUNCTION public.get_league_ranking(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_league_ranking(uuid) TO authenticated, service_role;

CREATE FUNCTION public.get_my_league_ranking()
 RETURNS TABLE(name text, avatar_id text, weekly_points integer, tier integer, end_date timestamp with time zone, is_me boolean, promotion_zone_end integer, demotion_zone_start integer, member_count integer)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT r.name, r.avatar_id, r.weekly_points, r.tier, r.end_date,
           r.is_me, r.promotion_zone_end, r.demotion_zone_start, r.member_count
    FROM public.get_league_ranking(auth.uid()) AS r
    WHERE auth.uid() IS NOT NULL;
$function$;
REVOKE ALL ON FUNCTION public.get_my_league_ranking() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_league_ranking() TO authenticated, service_role;

-- Aylık: 14 hangi ay kuralıyla kurulduysa o gövdeye döner (canlı ya da
-- proposed/15 uygulanmış gövde; ikisi de birebir).
DO $monthly$
BEGIN
    IF position('ss.started_at >=' IN pg_get_functiondef('public.get_public_monthly_leaderboard(integer)'::regprocedure)) > 0 THEN
        DROP FUNCTION public.get_public_monthly_leaderboard(integer);
        EXECUTE $f$
CREATE FUNCTION public.get_public_monthly_leaderboard(p_limit integer DEFAULT 10)
 RETURNS TABLE(name text, avatar_id text, total_points integer, total_minutes integer, is_me boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT
        CASE WHEN auth.uid() IS NULL THEN public.mask_public_name(p.name) ELSE p.name END,
        p.avatar_id,
        SUM(ss.base_points + ss.bonus_points)::integer AS total_points,
        SUM(ss.duration_minutes)::integer AS total_minutes,
        COALESCE(p.id = auth.uid(), false) AS is_me
    FROM public.study_sessions ss
    JOIN public.profiles p ON p.id = ss.user_id
    -- Çalışma ayı: complete_study_session'ın gün kuralı (started_at, profil
    -- dilimi, 04:00). Ay, profil dilimindeki ayın 1'i 04:00'te başlar.
    WHERE ss.started_at IS NOT NULL
      AND ss.started_at >= (
            (date_trunc('month', (now() AT TIME ZONE p.timezone) - interval '4 hours') + interval '4 hours')
            AT TIME ZONE p.timezone
          )
      AND p.show_in_social_feed = true
    GROUP BY p.id, p.name, p.avatar_id
    ORDER BY 3 DESC, 4 DESC, p.id
    LIMIT LEAST(GREATEST(p_limit, 0), 100);
$function$
$f$;
    ELSE
        DROP FUNCTION public.get_public_monthly_leaderboard(integer);
        EXECUTE $f$
CREATE FUNCTION public.get_public_monthly_leaderboard(p_limit integer DEFAULT 10)
 RETURNS TABLE(name text, avatar_id text, total_points integer, total_minutes integer, is_me boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT
        CASE WHEN auth.uid() IS NULL THEN public.mask_public_name(p.name) ELSE p.name END,
        p.avatar_id,
        SUM(ss.base_points + ss.bonus_points)::integer AS total_points,
        SUM(ss.duration_minutes)::integer AS total_minutes,
        COALESCE(p.id = auth.uid(), false) AS is_me
    FROM public.study_sessions ss
    JOIN public.profiles p ON p.id = ss.user_id
    WHERE ss.completed_at >= (date_trunc('month', now() AT TIME ZONE 'Europe/Istanbul') AT TIME ZONE 'Europe/Istanbul')
      AND p.show_in_social_feed = true
    GROUP BY p.id, p.name, p.avatar_id
    ORDER BY 3 DESC, 4 DESC, p.id
    LIMIT LEAST(GREATEST(p_limit, 0), 100);
$function$
$f$;
    END IF;
END
$monthly$;
REVOKE ALL ON FUNCTION public.get_public_monthly_leaderboard(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_monthly_leaderboard(integer) TO anon, authenticated, service_role;

DROP FUNCTION public.get_public_alltime_leaderboard(integer);

CREATE FUNCTION public.get_public_alltime_leaderboard(p_limit integer DEFAULT 50)
 RETURNS TABLE(name text, avatar_id text, total_minutes integer, lifetime_points integer, is_premium boolean, is_me boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT
        CASE WHEN auth.uid() IS NULL THEN public.mask_public_name(p.name) ELSE p.name END,
        p.avatar_id,
        COALESCE(p.total_minutes, 0),
        p.lifetime_points,
        COALESCE(p.is_premium, false),
        COALESCE(p.id = auth.uid(), false) AS is_me
    FROM public.profiles p
    WHERE p.show_in_social_feed = true
    ORDER BY p.lifetime_points DESC, COALESCE(p.total_minutes, 0) DESC, p.id
    LIMIT LEAST(GREATEST(p_limit, 0), 100);
$function$;
REVOKE ALL ON FUNCTION public.get_public_alltime_leaderboard(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_alltime_leaderboard(integer) TO anon, authenticated, service_role;

-- ------------------------------------------------------------
-- D) Arkadaş RPC'leri (canlı gövdeler) ve yeni RPC'ler
-- ------------------------------------------------------------
DROP FUNCTION public.block_user(uuid);
DROP FUNCTION public.unblock_user(uuid);
DROP FUNCTION public.get_my_blocks();
DROP FUNCTION public.remove_friend(uuid);
DROP FUNCTION public.cancel_friend_request(uuid);
DROP FUNCTION public.get_outgoing_friend_requests();

CREATE OR REPLACE FUNCTION public.add_friend_by_code(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_target record;
  v_reverse_pending boolean;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select id, name, avatar_id, lifetime_points, total_minutes
    into v_target
    from public.profiles
   where friend_code = upper(trim(p_code));

  if v_target.id is null then
    return jsonb_build_object('success', false, 'message', 'Bu kod ile bir kullanıcı bulunamadı.');
  end if;

  if v_target.id = auth.uid() then
    return jsonb_build_object('success', false, 'message', 'Kendini arkadaş olarak ekleyemezsin.');
  end if;

  if exists (select 1 from public.friendships where user_id = auth.uid() and friend_id = v_target.id and status = 'accepted') then
    return jsonb_build_object('success', false, 'message', 'Bu kullanıcı zaten arkadaşın.');
  end if;

  if exists (select 1 from public.friendships where user_id = auth.uid() and friend_id = v_target.id and status = 'pending') then
    return jsonb_build_object('success', false, 'message', 'Bu kullanıcıya zaten istek gönderdin.');
  end if;

  select exists(
    select 1 from public.friendships where user_id = v_target.id and friend_id = auth.uid() and status = 'pending'
  ) into v_reverse_pending;

  if v_reverse_pending then
    update public.friendships set status = 'accepted' where user_id = v_target.id and friend_id = auth.uid();
    insert into public.friendships (user_id, friend_id, status) values (auth.uid(), v_target.id, 'accepted')
      on conflict (user_id, friend_id) do update set status = 'accepted';
    return jsonb_build_object(
      'success', true,
      'auto_accepted', true,
      'friend', jsonb_build_object('id', v_target.id, 'name', v_target.name, 'avatar_id', v_target.avatar_id, 'lifetime_points', v_target.lifetime_points, 'total_minutes', v_target.total_minutes)
    );
  end if;

  insert into public.friendships (user_id, friend_id, status) values (auth.uid(), v_target.id, 'pending')
    on conflict (user_id, friend_id) do update set status = 'pending';

  return jsonb_build_object(
    'success', true,
    'auto_accepted', false,
    'friend', jsonb_build_object('id', v_target.id, 'name', v_target.name, 'avatar_id', v_target.avatar_id)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.respond_friend_request(p_from_user_id uuid, p_accept boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1 from public.friendships
     where user_id = p_from_user_id and friend_id = auth.uid() and status = 'pending'
  ) then
    return jsonb_build_object('success', false, 'message', 'Bekleyen bir istek bulunamadı.');
  end if;

  if p_accept then
    update public.friendships set status = 'accepted'
     where user_id = p_from_user_id and friend_id = auth.uid();
    insert into public.friendships (user_id, friend_id, status) values (auth.uid(), p_from_user_id, 'accepted')
      on conflict (user_id, friend_id) do update set status = 'accepted';
  else
    delete from public.friendships where user_id = p_from_user_id and friend_id = auth.uid();
  end if;

  return jsonb_build_object('success', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_friends()
 RETURNS TABLE(id uuid, name text, avatar_id text, lifetime_points integer, total_minutes integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT p.id, p.name, p.avatar_id, p.lifetime_points, COALESCE(p.total_minutes, 0)
    FROM public.profiles p
    WHERE auth.uid() IS NOT NULL
      AND p.id <> auth.uid()
      AND p.id IN (
          SELECT CASE WHEN f.user_id = auth.uid() THEN f.friend_id ELSE f.user_id END
          FROM public.friendships f
          WHERE f.status = 'accepted' AND (f.user_id = auth.uid() OR f.friend_id = auth.uid())
      )
    ORDER BY p.lifetime_points DESC, p.name;
$function$;

CREATE OR REPLACE FUNCTION public.get_incoming_friend_requests()
 RETURNS TABLE(id uuid, name text, avatar_id text, lifetime_points integer, total_minutes integer, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT p.id, p.name, p.avatar_id, p.lifetime_points, COALESCE(p.total_minutes, 0), f.created_at
    FROM public.friendships f
    JOIN public.profiles p ON p.id = f.user_id
    WHERE auth.uid() IS NOT NULL
      AND f.friend_id = auth.uid()
      AND f.status = 'pending'
    ORDER BY f.created_at DESC;
$function$;

CREATE OR REPLACE FUNCTION public.get_live_friends()
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
            'category_name', p.active_session_category_name,
            'ends_at', p.active_session_ends_at
        ) ORDER BY p.active_session_ends_at
    ), '[]'::jsonb)
    INTO v_result
    FROM public.profiles p
    WHERE p.id <> v_uid
      AND p.id IN (
          SELECT CASE WHEN f.user_id = v_uid THEN f.friend_id ELSE f.user_id END
          FROM public.friendships f
          WHERE f.status = 'accepted' AND (f.user_id = v_uid OR f.friend_id = v_uid)
      )
      AND p.show_in_social_feed = true
      AND p.active_session_ends_at > now();

    RETURN v_result;
END;
$function$;

-- ------------------------------------------------------------
-- C) Profil adı ve görünürlük varsayılanı (canlı gövdeler)
-- ------------------------------------------------------------
ALTER TABLE public.profiles ALTER COLUMN show_in_social_feed SET DEFAULT true;

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.profiles (id, name, email, avatar_id, total_minutes, lifetime_points, friend_code)
  values (
    new.id,
    left(coalesce(nullif(btrim(new.raw_user_meta_data->>'name'), ''),
                  nullif(btrim(new.raw_user_meta_data->>'full_name'), ''),
                  split_part(new.email, '@', 1)), 50),
    new.email,
    -- Yalnızca varsayılan (ücretsiz) avatarlar kayıtta seçilebilir;
    -- önceden 200 kumluk avatar_1_gamer bedava takılıyordu.
    coalesce(
      (select a.id from public.avatars a
        where a.id = new.raw_user_meta_data->>'avatar_id' and a.is_default and a.is_active),
      'avatar_16_basic'),
    0,
    0,
    upper(substr(replace(gen_random_uuid()::text,'-',''),1,6))
  )
  on conflict (id) do update set
    email = excluded.email,
    name = coalesce(excluded.name, public.profiles.name);
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.sanitize_profile_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF current_user IN ('authenticated', 'anon') THEN
        IF NEW.avatar_id IS NULL OR NOT EXISTS (
            SELECT 1 FROM public.avatars a
            WHERE a.id = NEW.avatar_id AND a.is_default AND a.is_active
        ) THEN
            NEW.avatar_id := 'avatar_16_basic';
        END IF;
    END IF;
    RETURN NEW;
END;
$function$;

-- ------------------------------------------------------------
-- B) Onay kaydı ve bülten RPC'leri
-- ------------------------------------------------------------
DROP TRIGGER log_marketing_subscription_change ON public.marketing_subscribers;
DROP FUNCTION public.log_marketing_subscription_change();
DROP FUNCTION public.set_marketing_consent(boolean, text);
DROP FUNCTION public.get_my_marketing_consent();
DROP FUNCTION public.accept_legal_documents(text, text);

CREATE OR REPLACE FUNCTION public.handle_newsletter_subscription()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  -- Check if email_confirmed_at changed from NULL to NOT NULL
  IF (OLD.email_confirmed_at IS NULL AND NEW.email_confirmed_at IS NOT NULL) THEN
    -- Check if raw_user_meta_data contains "newsletter": true
    IF (NEW.raw_user_meta_data->>'newsletter' = 'true') THEN
      INSERT INTO public.marketing_subscribers (user_id, email)
      VALUES (NEW.id, NEW.email)
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- ------------------------------------------------------------
-- TABLOLAR (VERİ KAYBI; bkz. dosya başı)
-- ------------------------------------------------------------
DROP TABLE public.user_reports;
DROP TABLE public.user_blocks;
DROP TABLE public.friend_request_rejections;
DROP TRIGGER consents_append_only ON public.consents;
DROP FUNCTION public.consents_append_only();
DROP TABLE public.consents;

-- ------------------------------------------------------------
-- A) ops şeması (operatör görünümü ve yardımcılar)
-- ------------------------------------------------------------
DROP SCHEMA ops CASCADE;

DO $$
BEGIN
    DELETE FROM supabase_migrations.schema_migrations WHERE version = '20261003194000';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişinden silinemedi: %', SQLERRM;
END $$;

COMMIT;
