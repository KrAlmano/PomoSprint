-- ============================================================
-- ÖNERİ 03: Herkese açık sıralama RPC'leri — gizlilik  ÖNCELİK: P1 (KVKK)
-- ============================================================
-- Bulgular: LANDING-V02 (gerçek tam ad pomosprint.app'te ve anon RPC'de
-- yayında, sosyal görünürlük tercihi dikkate alınmıyor olabilir), DATA-17
-- (aylık sekme tüm zamanlar puanını gösteriyor; isimle eşleştirme), K11.
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- ADIMLAR
--  1. Canlı gövdeleri alın:
--       select pg_get_functiondef(p.oid) from pg_proc p
--       join pg_namespace n on n.oid = p.pronamespace
--       where n.nspname = 'public'
--         and p.proname in ('get_public_monthly_leaderboard', 'get_public_alltime_leaderboard');
--  2. mask_display_name() fonksiyonunu (aşağıda, ek ve güvenli) yeni bir
--     migration'a koyun.
--  3. İki RPC'nin canlı gövdesinde A ve B değişikliklerini yapın. Dönen
--     kolonlar K11 sözleşmesiyle aynı kalmalı:
--       monthly: (name, avatar_id, total_points), parametre p_limit
--       alltime: (name, avatar_id, lifetime_points, total_minutes, is_premium)
--     is_me ve id DÖNMEZ. İstemci getAllTimeRanking'de p_limit gönderiyor;
--     canlı alltime fonksiyonunda p_limit yoksa ya ekleyin
--     (p_limit integer DEFAULT 50) ya da istemciye bildirin (PGRST202).
--  4. Canlı aylık RPC gerçekten bu ayın puanını hesaplamıyorsa (DATA-17)
--     aşağıdaki REFERANS gövdeyi kullanın.
--  5. landing/privacy.html §3-4 ve terms.html §4'e 'ilk 10'a giren
--     kullanıcıların kısaltılmış adı ve avatarı pomosprint.app'te herkese
--     açık gösterilir; Profil > sosyal görünürlük ile kapatılabilir'
--     maddesi eklenmeli (LANDING paketi).
-- ============================================================

\echo 'supabase/proposed/03: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

-- 'Ahmet Yılmaz' -> 'Ahmet Y.', 'Ayşe Nur Demir' -> 'Ayşe D.', tek kelime
-- olduğu gibi (en fazla 20 karakter). Boş ad -> NULL (istemci yedek metin
-- gösterir).
CREATE OR REPLACE FUNCTION public.mask_display_name(p_name text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path = public
AS $$
    SELECT CASE
        WHEN w IS NULL THEN NULL
        WHEN cardinality(w) = 1 THEN left(w[1], 20)
        ELSE left(w[1], 20) || ' ' || upper(left(w[cardinality(w)], 1)) || '.'
    END
    FROM (SELECT regexp_split_to_array(nullif(btrim(p_name), ''), '\s+') AS w) s;
$$;
GRANT EXECUTE ON FUNCTION public.mask_display_name(text) TO anon, authenticated;

-- ------------------------------------------------------------
-- A) Sosyal görünürlüğü kapatan kullanıcı listelenmez
-- ------------------------------------------------------------
-- Her iki RPC'nin profiles'ı okuyan sorgusuna:
--     AND COALESCE(p.show_in_social_feed, true)
-- (Ayrı bir opt-in isteniyorsa profiles'a show_on_public_leaderboard
--  boolean DEFAULT false ekleyip bu koşulda onu kullanın.)
--
-- ------------------------------------------------------------
-- B) İsim maskeleme
-- ------------------------------------------------------------
--     ESKİ: p.name
--     YENİ: public.mask_display_name(p.name) AS name
-- Uygulama aynı RPC'leri kullandığı için uygulamadaki sıralama da
-- kısaltılmış adı gösterir; kullanıcının kendi satırı isimle EŞLEŞTİRİLMEZ
-- (K11), 'senin durumun' göstergesi ayrı veriyle beslenir.

-- ------------------------------------------------------------
-- REFERANS: aylık sıralama (yalnızca canlı sürüm aylık değilse)
-- ------------------------------------------------------------
-- Bu ayın (İstanbul takvimi) seans puanları toplanır. Ay, seansın
-- başladığı ana göre seçilir (completed_at artık gerçek bitiş olsa da
-- started_at index'li).
CREATE OR REPLACE FUNCTION public.get_public_monthly_leaderboard(p_limit integer DEFAULT 10)
RETURNS TABLE (
    name text,
    avatar_id text,
    total_points integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    WITH bounds AS (
        SELECT date_trunc('month', now() AT TIME ZONE 'Europe/Istanbul') AT TIME ZONE 'Europe/Istanbul' AS month_start
    ),
    totals AS (
        SELECT s.user_id, sum(COALESCE(s.base_points, 0) + COALESCE(s.bonus_points, 0))::integer AS pts
        FROM public.study_sessions s, bounds b
        WHERE s.started_at >= b.month_start
        GROUP BY s.user_id
    )
    SELECT public.mask_display_name(p.name), p.avatar_id::text, t.pts
    FROM totals t
    JOIN public.profiles p ON p.id = t.user_id
    WHERE t.pts > 0
      AND COALESCE(p.show_in_social_feed, true)
    ORDER BY t.pts DESC, p.id
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 10), 1), 100);
$$;
-- Landing oturumsuz çağırıyor: anon yetkisi bilinçli.
GRANT EXECUTE ON FUNCTION public.get_public_monthly_leaderboard(integer) TO anon, authenticated;

-- 'Senin durumun' göstergesi için (K11; listeyi ezmeden). Aynı hesap.
CREATE OR REPLACE FUNCTION public.get_my_monthly_standing()
RETURNS TABLE (
    rank integer,
    total_points integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    WITH bounds AS (
        SELECT date_trunc('month', now() AT TIME ZONE 'Europe/Istanbul') AT TIME ZONE 'Europe/Istanbul' AS month_start
    ),
    totals AS (
        SELECT s.user_id, sum(COALESCE(s.base_points, 0) + COALESCE(s.bonus_points, 0))::integer AS pts
        FROM public.study_sessions s, bounds b
        WHERE s.started_at >= b.month_start
        GROUP BY s.user_id
    ),
    ranked AS (
        SELECT t.user_id, t.pts,
               row_number() OVER (ORDER BY t.pts DESC, t.user_id)::integer AS rnk
        FROM totals t
        JOIN public.profiles p ON p.id = t.user_id
        WHERE t.pts > 0 AND COALESCE(p.show_in_social_feed, true)
    )
    SELECT r.rnk, r.pts FROM ranked r WHERE r.user_id = auth.uid();
$$;
REVOKE ALL ON FUNCTION public.get_my_monthly_standing() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_monthly_standing() TO authenticated;

COMMIT;
