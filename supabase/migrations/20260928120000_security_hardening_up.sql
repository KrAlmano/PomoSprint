-- Güvenlik sıkılaştırması (analiz raporu bulguları 4.1, 4.2, 4.3, 4.6, 4.9).
--
-- ÖNEMLİ: Repodaki migration'lar canlı veritabanının gerisinde (ör.
-- get_points_config, delete_own_account, get_public_alltime_leaderboard
-- repoda yok; complete_study_session canlıda farklı). Bu yüzden bu dosya
-- mevcut fonksiyon GÖVDELERİNİ yeniden yazmaz; yalnızca trigger, yetki ve
-- fonksiyon ayarı ekler. Böylece canlıdaki mantık ezilmez.
-- Uygulamadan önce bir branch/staging üzerinde deneyin.

BEGIN;

-- ============================================================
-- 1) SEANS DOĞRULAMASI (4.1)
-- ============================================================
-- complete_study_session yalnızca süre ∈ {25,50} ve başlangıcın son 24
-- saat içinde olmasını kontrol ediyordu; seansın gerçekten o kadar
-- sürdüğü doğrulanmıyordu. RPC'yi doğrudan `started_at = now()` ile art
-- arda çağırarak sınırsız puan/coin toplanabiliyordu.
--
-- Bu trigger her seans kaydında:
--   a) başlangıç + süre anının geçmiş olmasını (saat farkı için 3 dk
--      tolerans),
--   b) seansın aynı kullanıcının başka bir seansıyla zaman olarak
--      çakışmamasını
-- zorunlu kılar. RPC aynı transaction içinde çalıştığı için trigger hata
-- verdiğinde RPC'nin daha önce yaptığı profil/lig güncellemeleri de geri
-- alınır. Böylece kazanılabilecek puan gerçek geçen zamanla sınırlanır.

CREATE INDEX IF NOT EXISTS study_sessions_user_started_at_idx
    ON public.study_sessions (user_id, started_at);

CREATE OR REPLACE FUNCTION public.validate_study_session_timing()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_end timestamptz;
BEGIN
    IF NEW.started_at IS NULL THEN
        RAISE EXCEPTION 'session_missing_start: started_at zorunlu';
    END IF;

    v_end := NEW.started_at + make_interval(mins => NEW.duration_minutes);

    IF v_end > now() + interval '3 minutes' THEN
        RAISE EXCEPTION 'session_not_elapsed: seans süresi henüz dolmadı';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.study_sessions s
        WHERE s.user_id = NEW.user_id
          AND s.started_at IS NOT NULL
          AND s.started_at < v_end
          AND s.started_at + make_interval(mins => s.duration_minutes) > NEW.started_at
    ) THEN
        RAISE EXCEPTION 'session_overlap: bu zaman aralığında başka bir seans var';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS study_sessions_validate_timing ON public.study_sessions;
CREATE TRIGGER study_sessions_validate_timing
    BEFORE INSERT ON public.study_sessions
    FOR EACH ROW EXECUTE FUNCTION public.validate_study_session_timing();

-- Seanslar yalnızca SECURITY DEFINER RPC'ler üzerinden yazılır.
REVOKE INSERT, UPDATE, DELETE ON public.study_sessions FROM anon, authenticated;

-- ============================================================
-- 2) PROFILES YETKİLERİ (4.2)
-- ============================================================
-- 20260809033000 migration'ı anon rolüne tam yetki ve authenticated'a
-- kolon kısıtsız UPDATE veriyordu (kullanıcı kendi coins, is_premium,
-- league_tier, streak alanlarını değiştirebiliyordu). Yazma yetkisi
-- uygulamanın gerçekten yazdığı kolonlarla sınırlanıyor. Puan, coin,
-- seri, premium ve lig alanları yalnızca SECURITY DEFINER RPC'lerle
-- değişir. SELECT yetkisine dokunulmuyor (canlıda zaten kolon bazlı).

REVOKE ALL ON public.profiles FROM anon;

REVOKE INSERT, UPDATE, DELETE ON public.profiles FROM authenticated;
GRANT INSERT (id, email, name, avatar_id) ON public.profiles TO authenticated;
GRANT UPDATE (
    name,
    show_in_social_feed,
    user_segment,
    daily_goal_minutes,
    birth_year,
    onboarding_completed_at
) ON public.profiles TO authenticated;

-- ============================================================
-- 3) KATEGORİ LİMİTİ (4.6)
-- ============================================================
-- Limit (ücretsiz 8 / Premium 15) yalnızca create_category ve
-- setup_onboarding_categories RPC'lerinde kontrol ediliyordu; tabloya
-- doğrudan INSERT/UPDATE ile aşılabiliyordu. Trigger, aktif kategori
-- sayısını her yazma yolunda zorunlu kılar.

CREATE OR REPLACE FUNCTION public.enforce_category_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_is_premium boolean;
    v_limit integer;
    v_active integer;
BEGIN
    IF NEW.is_archived THEN
        RETURN NEW;
    END IF;
    IF TG_OP = 'UPDATE' AND OLD.is_archived = false THEN
        RETURN NEW; -- zaten aktif olan bir kategorinin düzenlenmesi
    END IF;

    SELECT COALESCE(is_premium, false) INTO v_is_premium
    FROM public.profiles WHERE id = NEW.user_id;
    v_limit := CASE WHEN v_is_premium THEN 15 ELSE 8 END;

    SELECT count(*) INTO v_active
    FROM public.categories
    WHERE user_id = NEW.user_id AND is_archived = false AND id <> NEW.id;

    IF v_active >= v_limit THEN
        IF v_is_premium THEN
            RAISE EXCEPTION 'Premium planda en fazla 15 kategori aktif olabilir.';
        ELSE
            RAISE EXCEPTION 'Ücretsiz planda en fazla 8 kategori aktif olabilir. Premium ile 15''e çıkar.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS categories_enforce_limit ON public.categories;
CREATE TRIGGER categories_enforce_limit
    BEFORE INSERT OR UPDATE OF is_archived ON public.categories
    FOR EACH ROW EXECUTE FUNCTION public.enforce_category_limit();

-- ============================================================
-- 4) LİG SIRALAMASI E-POSTA SIZINTISI (4.3)
-- ============================================================
-- get_league_ranking(p_user_id) lig üyelerinin e-postalarını döndürüyor
-- ve herhangi bir kullanıcı ID'siyle çağrılabiliyordu. Mevcut gövdeyi
-- yeniden yazmak yerine (canlı sürüm repodakinden farklı olabilir),
-- onu yalnızca oturum sahibinin kimliğiyle çağıran ve e-posta kolonunu
-- döndürmeyen bir sarmalayıcı ekleniyor; eski fonksiyon istemcilere
-- kapatılıyor. Uygulama get_my_league_ranking'i kullanır.

CREATE OR REPLACE FUNCTION public.get_my_league_ranking()
RETURNS TABLE (
    name text,
    avatar_id text,
    weekly_points integer,
    tier integer,
    end_date timestamptz,
    is_me boolean,
    promotion_zone_end integer,
    demotion_zone_start integer,
    member_count integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT r.name, r.avatar_id, r.weekly_points, r.tier, r.end_date,
           r.is_me, r.promotion_zone_end, r.demotion_zone_start, r.member_count
    FROM public.get_league_ranking(auth.uid()) AS r
    WHERE auth.uid() IS NOT NULL;
$$;

REVOKE ALL ON FUNCTION public.get_my_league_ranking() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_league_ranking() TO authenticated;

-- ============================================================
-- 5) SECURITY DEFINER FONKSİYONLARI (4.9)
-- ============================================================
-- search_path ayarlanmamış SECURITY DEFINER fonksiyonlar şema gölgeleme
-- saldırılarına açık. Gövdelere dokunmadan tümüne sabit search_path
-- atanır. Yalnızca sunucu içinden çağrılması gereken fonksiyonların
-- (lig puanı yazma, haftalık lig işlemi, e-posta döndüren eski sıralama)
-- istemci çağrı yetkisi kaldırılır.

DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT p.oid::regprocedure AS sig
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prosecdef
          AND NOT EXISTS (
              SELECT 1 FROM unnest(COALESCE(p.proconfig, '{}')) c
              WHERE c LIKE 'search_path=%'
          )
    LOOP
        EXECUTE format('ALTER FUNCTION %s SET search_path = public', r.sig);
    END LOOP;

    FOR r IN
        SELECT p.oid::regprocedure AS sig
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname IN ('ensure_user_in_league', 'process_weekly_leagues', 'get_league_ranking', 'give_default_avatars')
    LOOP
        EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', r.sig);
    END LOOP;
END;
$$;

COMMIT;
