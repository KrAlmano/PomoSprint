-- ============================================================================
-- DURUM (3 Ekim 2026, ana oturum): BU DOSYA CANLIYA UYGULANMADI ve
-- migrations/ klasöründen buraya taşındı.
-- Canlıya bunun yerine 20261003150000_live_audit_fixes uygulandı (canlı
-- fonksiyon gövdeleri esas alınarak). Aşağıdaki bölümlerin durumu:
--   1) zaman normalizasyonu (synced_at, trigger)  -> GEREKSİZ: 150000 RPC'de
--      completed_at = started_at + süre yazıyor ve eski satırları düzeltti.
--   2) get_my_friends / get_incoming_friend_requests -> 150000'de VAR (farklı
--      gövde). remove_friend, cancel_friend_request,
--      get_outgoing_friend_requests -> canlıda YOK; istenirse ayrı migration.
--   4) avatar kataloğu anon okuma -> canlıda zaten açık (SELECT true).
--   5) profil insert zorlaması -> 150000'deki sanitize_profile_insert karşılıyor.
--   6) study_day_of / get_my_streak / set_my_timezone -> canlıda YOK;
--      timezone artık istemciden doğrudan güncellenebiliyor (kolon yetkisi
--      + doğrulama trigger'ı 150000'de).
--   7) category_limit / get_my_category_limit / reorder_categories -> canlıda
--      YOK; istemci yedek yola düşer.
-- Uygulamadan önce canlı tanımları okuyun ve yalnızca gereken parçaları
-- yeni bir migration'a alın (bkz. ../README.md).
-- ============================================================================

-- ============================================================
-- 20261003120000_audit_fixes
-- ============================================================
-- Bu migration canlıya UYGULANMADI. Uygulamadan önce: supabase db dump
-- ile canlı şemayı al, bu dosyayı gözden geçir, staging'de dene.
--
-- Kural: Bu dosya yalnızca EKLEYİCİ ve idempotent değişiklik içerir; hiçbir
-- mevcut fonksiyonun gövdesini değiştirmez (complete_study_session,
-- process_weekly_leagues, purchase_avatar, enforce_category_limit,
-- give_default_avatars ...). Onlar için önerilen değişiklikler
-- supabase/proposed/ altındadır. 20260928120000_security_hardening'e
-- bağımlı değildir (canlıda uygulanmamış olabilir).
--
-- 20261003150000_live_audit_fixes ile birlikte: o dosya başka bir oturumda
-- canlı fonksiyon gövdelerinden yazıldı ve bu dosyadan SONRA çalışır.
-- Çakışan nesneler uyumludur:
--   * get_my_friends / get_incoming_friend_requests aynı imza ve dönüş
--     kolonlarıyla tanımlanır; sonra çalışan dosyanın gövdesi geçerli olur.
--   * Oradaki complete_study_session completed_at'i zaten gerçek bitiş
--     yazar; buradaki trigger aynı değeri üretir ve ek olarak synced_at'i
--     doldurup küçük saat kaymasını kırpar.
--   * profiles BEFORE INSERT: 'profiles_enforce_insert_defaults' (bu dosya)
--     isim sırasıyla 'sanitize_profile_insert'ten (o dosya) önce çalışır;
--     ikisi de yalnızca is_default avatarları kabul eder.
--   * Bu dosyanın geri alması o dosyanın nesnelerine dokunmaz.
--
-- İçerik
--   1) study_sessions zaman normalizasyonu (BACKEND-01/DATA-02/STATS-V01/
--      TIMER-V02/BACKEND-10, BACKEND-08/TIMER-18)
--   2) Arkadaş RPC'leri (SOCIAL-05/DATA-16/BACKEND-14/SOCIAL-19/SOCIAL-20)
--   3) Index'ler (BACKEND-27)
--   4) Avatar kataloğu oturumsuz okunabilir (SOCIAL-V01/BACKEND-02)
--   5) Profil oluştururken e-posta ve avatar zorlaması (BACKEND-12/
--      SOCIAL-15/AUTH-21/DATA-25)
--   6) Saat dilimi, çalışma günü ve seri yardımcıları (BACKEND-09/
--      BACKEND-11/STATS-04)
--   7) Kategori limiti tek kaynak (okuma), toplu sıralama (BACKEND-28/
--      AUTH-18/DATA-26)
--
-- YAN ETKİLER (uygulamadan önce okuyun)
--   * study_sessions.completed_at artık seansın GERÇEK bitişi
--     (started_at + duration_minutes); senkron anı yeni synced_at
--     kolonunda. Mevcut satırlar da tek seferlik düzeltilir (eski değer
--     synced_at'e taşınır, geri alma betiği oradan geri yükler).
--   * complete_study_session'daki "p_started_at < son completed_at"
--     kontrolü artık gerçek bitişle karşılaştırır: kuyruktaki seanslar
--     started_at sırasıyla gönderildiğinde 2. ve sonrakiler kabul edilir.
--     Daha yeni bir seanstan SONRA gönderilen daha eski bir seans hâlâ
--     'overlap' alır; bunu 20261003150000_live_audit_fixes'teki
--     complete_study_session (ya da proposed/01) çözer.
--   * Seri, günlük 16 seans tavanı ve activity_feed özetleri started_at
--     kullanır: etkilenmez. ensure_user_in_league completed_at
--     kullanmaz: lig puanı etkilenmez. Geçmiş, rapor ve aylık takip
--     ekranları (completed_at okuyan istemciler) çevrimdışı seansları
--     doğru güne yazar. Canlıdaki get_public_monthly_leaderboard ayı
--     completed_at ile süzüyorsa, ay sınırında geç senkronlanmış birkaç
--     seans önceki aya geçer.
--   * Cihaz saati sunucudan 3-15 dk ilerideyse seans artık reddedilmez:
--     başlangıç, doğrulamayı geçecek kadar (en fazla 12 dk) geri
--     kaydırılır. Bitişi 15 dakikadan daha ilerideki seanslar (ör. debug
--     build'in 5/10 saniyelik seansları) eskisi gibi reddedilir.
--     20261003150000'deki complete_study_session bitişi now()+5 dk'dan
--     ilerideki seansı INSERT'ten önce reddettiği için, o uygulanınca
--     etkin tolerans 5 dk olur.
--     Kaydırılan seans 04:00 sınırına çok yakınsa RPC'nin hesapladığı
--     çalışma günü ile kayıttaki started_at farklı güne düşebilir (nadir).
--   * Trigger sırası: PostgreSQL aynı olaydaki BEFORE trigger'ları isim
--     sırasıyla çalıştırır. 'study_sessions_normalize_times' <
--     'study_sessions_validate_timing' olduğundan (20260928120000
--     uygulanmışsa) normalizasyon önce çalışır ve doğrulama kaydırılmış
--     başlangıcı görür. Canlıda başka
--     BEFORE INSERT trigger'ı olup olmadığını kontrol edin:
--       select tgname from pg_trigger
--       where tgrelid = 'public.study_sessions'::regclass and not tgisinternal;
--   * Yeni profillerde e-posta auth.users'tan alınır; varsayılan
--     (is_default) olmayan avatar_id varsayılan avatara (avatar_16_basic)
--     çekilir ve equipped_avatar_id aynı değere ayarlanır. Mevcut
--     profillere dokunulmaz (bkz. proposed/10_data_fixes.sql).
--   * avatars kataloğu anon rolüne açılır (yalnızca is_active satırlar).
--   * study_sessions'a yazan başka (canlıda bilinmeyen) UPDATE trigger'ı
--     varsa tek seferlik düzeltme UPDATE'i onu tetikler; kontrol edin.
-- ============================================================

BEGIN;

-- ============================================================
-- 1) study_sessions ZAMAN NORMALİZASYONU
-- ============================================================
-- complete_study_session completed_at'e now() (senkron anı) yazıyor ve
-- çakışmayı "yeni started_at < son completed_at" ile kontrol ediyordu.
-- Çevrimdışı kuyruk gönderildiğinde ilk seansın completed_at'i senkron
-- anı olduğu için sonraki tüm seanslar 'overlap' alıp kayboluyordu.
-- Fonksiyonun (canlı gövdesi farklı) yeniden yazılmasına gerek kalmadan,
-- completed_at'i ekleme anında gerçek bitişe çeken bir trigger eklenir.

ALTER TABLE public.study_sessions ADD COLUMN IF NOT EXISTS synced_at timestamptz;
-- İstemci select('*') kullanıyor; canlıda SELECT kolon bazlıysa yeni kolon
-- yetkisiz kalıp tüm sorguyu düşürmesin.
GRANT SELECT (synced_at) ON public.study_sessions TO authenticated;

CREATE OR REPLACE FUNCTION public.normalize_study_session_times()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
    v_end timestamptz;
    v_limit timestamptz := now() + interval '3 minutes';
BEGIN
    NEW.synced_at := now();

    -- started_at yoksa validate_study_session_timing reddeder.
    IF NEW.started_at IS NULL OR NEW.duration_minutes IS NULL THEN
        RETURN NEW;
    END IF;

    v_end := NEW.started_at + make_interval(mins => NEW.duration_minutes);

    -- Cihaz saati biraz ilerideyse (bitiş 3-15 dk sonra) başlangıcı
    -- doğrulamanın kabul edeceği en yakın ana kaydır. Daha büyük sapmalar
    -- (ve debug build'in kısa seansları) dokunulmadan reddedilir.
    IF v_end > v_limit AND v_end <= now() + interval '15 minutes' THEN
        NEW.started_at := NEW.started_at - (v_end - v_limit);
        v_end := v_limit;
    END IF;

    NEW.completed_at := v_end;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.normalize_study_session_times() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS study_sessions_normalize_times ON public.study_sessions;
CREATE TRIGGER study_sessions_normalize_times
    BEFORE INSERT ON public.study_sessions
    FOR EACH ROW EXECUTE FUNCTION public.normalize_study_session_times();

-- Mevcut satırlar: eski completed_at (senkron anı) synced_at'e taşınır,
-- completed_at gerçek bitişe çekilir. synced_at dolu satırlar atlanır
-- (yeniden çalıştırmada tekrar işlenmez).
UPDATE public.study_sessions
SET synced_at = completed_at,
    completed_at = CASE
        WHEN started_at IS NOT NULL AND duration_minutes IS NOT NULL
            THEN started_at + make_interval(mins => duration_minutes)
        ELSE completed_at
    END
WHERE synced_at IS NULL;

ALTER TABLE public.study_sessions ALTER COLUMN synced_at SET DEFAULT now();

-- ============================================================
-- 2) ARKADAŞ RPC'LERİ
-- ============================================================
-- İstemci başka kullanıcıların profiles satırlarını doğrudan okuyordu;
-- canlı RLS yalnızca kendi satırına izin verdiğinden gelen istekler ve
-- arkadaş listesi boş kalıyordu. Ayrıca ilişki yönü tutarsızdı (liste tek
-- yönlü, get_live_friends iki yönlü). Tek kaynak: my_friend_ids().
-- Yalnızca güvenli kolonlar döner (e-posta, doğum yılı, coin yok).

CREATE OR REPLACE FUNCTION public.my_friend_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT DISTINCT CASE WHEN f.user_id = auth.uid() THEN f.friend_id ELSE f.user_id END
    FROM public.friendships f
    WHERE f.status = 'accepted'
      AND (f.user_id = auth.uid() OR f.friend_id = auth.uid())
      AND f.user_id <> f.friend_id;
$$;

CREATE OR REPLACE FUNCTION public.get_my_friends()
RETURNS TABLE (
    id uuid,
    name text,
    avatar_id text,
    lifetime_points integer,
    total_minutes integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT p.id, p.name::text, p.avatar_id::text,
           COALESCE(p.lifetime_points, 0)::integer,
           COALESCE(p.total_minutes, 0)::integer
    FROM public.profiles p
    WHERE p.id IN (SELECT fid FROM public.my_friend_ids() AS fid)
    ORDER BY p.lifetime_points DESC NULLS LAST, p.name;
$$;

-- friendships.created_at repoda doğrulanamadığı için satır jsonb'ye
-- çevrilerek okunur: kolon yoksa NULL döner, fonksiyon yine çalışır.
CREATE OR REPLACE FUNCTION public.get_incoming_friend_requests()
RETURNS TABLE (
    id uuid,
    name text,
    avatar_id text,
    lifetime_points integer,
    total_minutes integer,
    created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT p.id, p.name::text, p.avatar_id::text,
           COALESCE(p.lifetime_points, 0)::integer,
           COALESCE(p.total_minutes, 0)::integer,
           r.created_at
    FROM (
        SELECT f.user_id AS requester_id,
               min((to_jsonb(f) ->> 'created_at')::timestamptz) AS created_at
        FROM public.friendships f
        WHERE f.friend_id = auth.uid()
          AND f.status = 'pending'
          AND f.user_id <> f.friend_id
        GROUP BY f.user_id
    ) r
    JOIN public.profiles p ON p.id = r.requester_id
    WHERE NOT EXISTS (
        SELECT 1 FROM public.my_friend_ids() AS fid WHERE fid = r.requester_id
    )
    ORDER BY r.created_at DESC NULLS LAST, p.name;
$$;

CREATE OR REPLACE FUNCTION public.get_outgoing_friend_requests()
RETURNS TABLE (
    id uuid,
    name text,
    avatar_id text,
    created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT p.id, p.name::text, p.avatar_id::text, r.created_at
    FROM (
        SELECT f.friend_id AS target_id,
               min((to_jsonb(f) ->> 'created_at')::timestamptz) AS created_at
        FROM public.friendships f
        WHERE f.user_id = auth.uid()
          AND f.status = 'pending'
          AND f.user_id <> f.friend_id
        GROUP BY f.friend_id
    ) r
    JOIN public.profiles p ON p.id = r.target_id
    WHERE NOT EXISTS (
        SELECT 1 FROM public.my_friend_ids() AS fid WHERE fid = r.target_id
    )
    ORDER BY r.created_at DESC NULLS LAST, p.name;
$$;

-- Arkadaşlığı iki yönlü siler (aradaki bekleyen istekler dahil).
CREATE OR REPLACE FUNCTION public.remove_friend(p_friend_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_count integer;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
    END IF;

    DELETE FROM public.friendships
    WHERE status IN ('accepted', 'pending')
      AND ((user_id = v_uid AND friend_id = p_friend_id)
           OR (user_id = p_friend_id AND friend_id = v_uid));
    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', v_count > 0,
        'code', CASE WHEN v_count > 0 THEN 'removed' ELSE 'not_friends' END
    );
END;
$$;

-- Kullanıcının gönderdiği, henüz yanıtlanmamış isteği geri çeker.
CREATE OR REPLACE FUNCTION public.cancel_friend_request(p_to_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_count integer;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
    END IF;

    DELETE FROM public.friendships
    WHERE user_id = v_uid AND friend_id = p_to_user_id AND status = 'pending';
    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', v_count > 0,
        'code', CASE WHEN v_count > 0 THEN 'cancelled' ELSE 'not_found' END
    );
END;
$$;

REVOKE ALL ON FUNCTION public.my_friend_ids() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_my_friends() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_incoming_friend_requests() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_outgoing_friend_requests() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.remove_friend(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cancel_friend_request(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.my_friend_ids() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_friends() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_incoming_friend_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_outgoing_friend_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_friend(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_friend_request(uuid) TO authenticated;

-- ============================================================
-- 3) INDEX'LER
-- ============================================================
-- complete_study_session her çağrıda kullanıcının son seansını
-- 'ORDER BY completed_at DESC LIMIT 1' ile arıyor.
CREATE INDEX IF NOT EXISTS study_sessions_user_completed_at_idx
    ON public.study_sessions (user_id, completed_at DESC);

-- Arkadaş sorguları iki yönden de okur. Canlıda aynı kolonla başlayan bir
-- index zaten varsa yenisi oluşturulmaz (isim farklı olabilir).
DO $$
DECLARE
    v_col text;
BEGIN
    IF to_regclass('public.friendships') IS NULL THEN
        RETURN;
    END IF;
    FOREACH v_col IN ARRAY ARRAY['user_id', 'friend_id'] LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM pg_index i
            JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = i.indkey[0]
            WHERE i.indrelid = 'public.friendships'::regclass
              AND a.attname = v_col
        ) THEN
            EXECUTE format(
                'CREATE INDEX %I ON public.friendships (%I, status)',
                'friendships_' || v_col || '_status_idx', v_col
            );
        END IF;
    END LOOP;
END $$;

-- ============================================================
-- 4) AVATAR KATALOĞU OTURUMSUZ OKUNABİLİR
-- ============================================================
-- Splash kataloğu oturum açılmadan çekiyor; politika yalnızca
-- authenticated olduğu için yeni kurulumda katalog boş kalıyor ve ana
-- kabuk çöküyordu. Katalog gizli veri değil (landing'de de yayında).
DROP POLICY IF EXISTS "Avatars are viewable by anon" ON public.avatars;
CREATE POLICY "Avatars are viewable by anon"
    ON public.avatars FOR SELECT TO anon USING (is_active);
GRANT SELECT ON public.avatars TO anon;

-- ============================================================
-- 5) PROFİL OLUŞTURMA: E-POSTA VE AVATAR ZORLAMASI
-- ============================================================
-- authenticated rolü profilini (id, email, name, avatar_id) ile kendisi
-- oluşturabiliyor: başkasının e-postasını ya da ücretli/premium/lig
-- ödülü bir avatarı yazabiliyordu. Google/Apple girişinde istemci yedeği
-- 200 coin'lik avatarı takıyordu. give_default_avatars AFTER INSERT
-- olduğundan oradaki equipped_avatar_id ataması etkisizdi.
-- INSERT yetkisi kaldırılmaz (istemcinin profil upsert'i bozulmasın);
-- değerler BEFORE INSERT trigger'ında düzeltilir.

CREATE OR REPLACE FUNCTION public.enforce_profile_insert_defaults()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_email text;
    v_avatar text;
BEGIN
    SELECT u.email INTO v_email FROM auth.users u WHERE u.id = NEW.id;
    IF v_email IS NOT NULL THEN
        NEW.email := v_email;
    END IF;

    -- Kayıtta yalnızca varsayılan (is_default) avatar seçilebilir: bunlar
    -- give_default_avatars ile hemen açılır, yani kullanıcı sahibidir.
    IF NEW.avatar_id IS NOT NULL AND EXISTS (
        SELECT 1
        FROM public.avatars a
        WHERE a.id = NEW.avatar_id AND a.is_default AND a.is_active
    ) THEN
        v_avatar := NEW.avatar_id;
    ELSE
        SELECT a.id INTO v_avatar
        FROM public.avatars a
        WHERE a.is_default AND a.is_active
        ORDER BY (a.id = 'avatar_16_basic') DESC, a.sort_order, a.id
        LIMIT 1;
    END IF;

    -- Katalog boşsa eski davranış korunur (FK hatası çıkmasın).
    IF v_avatar IS NOT NULL THEN
        NEW.avatar_id := v_avatar;
        -- equipped_avatar_id (20260809030000) canlıda kaldırılmışsa kayıt
        -- akışı bu trigger yüzünden bozulmasın.
        IF to_jsonb(NEW) ? 'equipped_avatar_id' THEN
            NEW := jsonb_populate_record(NEW, jsonb_build_object('equipped_avatar_id', v_avatar));
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_profile_insert_defaults() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS profiles_enforce_insert_defaults ON public.profiles;
CREATE TRIGGER profiles_enforce_insert_defaults
    BEFORE INSERT ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.enforce_profile_insert_defaults();

-- ============================================================
-- 6) SAAT DİLİMİ, ÇALIŞMA GÜNÜ VE SERİ
-- ============================================================
-- Sunucu kuralı: kullanıcının yerel saatiyle 04:00'ten önceki seanslar
-- önceki güne sayılır. Kural tek yerde; proposed/ altındaki yamalar da
-- bunları kullanır.

CREATE OR REPLACE FUNCTION public.study_day_of(p_ts timestamptz, p_tz text)
RETURNS date
LANGUAGE sql
STABLE
PARALLEL SAFE
SET search_path = public
AS $$
    SELECT ((p_ts AT TIME ZONE COALESCE(p_tz, 'Europe/Istanbul')) - interval '4 hours')::date;
$$;

-- Çalışma gününün başladığı an. Gün sorgularında yarı açık aralık için:
-- started_at >= study_day_start(d, tz) AND started_at < study_day_start(d + 1, tz)
CREATE OR REPLACE FUNCTION public.study_day_start(p_day date, p_tz text)
RETURNS timestamptz
LANGUAGE sql
STABLE
PARALLEL SAFE
SET search_path = public
AS $$
    SELECT (p_day + time '04:00') AT TIME ZONE COALESCE(p_tz, 'Europe/Istanbul');
$$;

-- Ekranda gösterilecek seri: son çalışma günü dün ya da bugünse
-- current_streak, değilse 0 (seri kırılmış ama henüz yeni seans yok).
CREATE OR REPLACE FUNCTION public.get_my_streak()
RETURNS TABLE (
    effective_streak integer,
    longest_streak integer,
    last_study_date date,
    study_day date
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT CASE
               WHEN p.last_study_date >= public.study_day_of(now(), p.timezone) - 1
                   THEN COALESCE(p.current_streak, 0)
               ELSE 0
           END::integer,
           COALESCE(p.longest_streak, 0)::integer,
           p.last_study_date,
           public.study_day_of(now(), p.timezone)
    FROM public.profiles p
    WHERE p.id = auth.uid();
$$;

-- profiles.timezone hiç yazılmıyordu (istemcinin UPDATE yetkisi de yok).
-- Değer pg_timezone_names'e göre doğrulanır (geçersiz bir değer
-- AT TIME ZONE'u bozar ve seansları kalıcı hataya düşürürdü). Gün
-- sınırını ve günlük tavanı oyunlamayı önlemek için 24 saatte bir
-- değişebilir; erken çağrılar sessizce mevcut değeri döndürür.
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS timezone_updated_at timestamptz;

CREATE OR REPLACE FUNCTION public.set_my_timezone(p_tz text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_tz text := btrim(p_tz);
    v_current text;
    v_updated_at timestamptz;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
    END IF;

    IF v_tz IS NULL OR v_tz = ''
       OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name = v_tz) THEN
        RAISE EXCEPTION 'invalid_timezone' USING ERRCODE = '22023';
    END IF;

    SELECT timezone, timezone_updated_at
    INTO v_current, v_updated_at
    FROM public.profiles
    WHERE id = v_uid
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0002';
    END IF;

    IF v_current = v_tz THEN
        RETURN v_current;
    END IF;

    IF v_updated_at IS NOT NULL AND v_updated_at > now() - interval '24 hours' THEN
        RETURN v_current;
    END IF;

    UPDATE public.profiles
    SET timezone = v_tz, timezone_updated_at = now()
    WHERE id = v_uid;

    RETURN v_tz;
END;
$$;

REVOKE ALL ON FUNCTION public.study_day_of(timestamptz, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.study_day_start(date, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_my_streak() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_my_timezone(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.study_day_of(timestamptz, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.study_day_start(date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_streak() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_my_timezone(text) TO authenticated;

-- ============================================================
-- 7) KATEGORİLER: TEK KAYNAKLI LİMİT, TOPLU SIRALAMA
-- ============================================================
-- 8/15 limiti create_category, setup_onboarding_categories, trigger ve
-- istemcide ayrı ayrı yazılı. category_limit() tek kaynaktır; istemci
-- limiti get_my_category_limit() ile okuyabilir. Trigger ve RPC'lerin bu
-- fonksiyona geçirilmesi ve eşzamanlı eklemede kilit (canlı gövdeler
-- repodakinden farklı) proposed/09_categories.sql içinde.

CREATE OR REPLACE FUNCTION public.category_limit(p_uid uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT CASE
               WHEN COALESCE((SELECT is_premium FROM public.profiles WHERE id = p_uid), false)
                   THEN 15
               ELSE 8
           END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_category_limit()
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT public.category_limit(auth.uid()) WHERE auth.uid() IS NOT NULL;
$$;

-- Sıralamayı tek transaction'da yazar (N ayrı UPDATE yarıda kalıp
-- karışık sıra bırakıyordu). Yalnızca kullanıcının kendi kategorileri
-- güncellenir; dönen değer güncellenen satır sayısıdır.
CREATE OR REPLACE FUNCTION public.reorder_categories(p_ids uuid[])
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid := auth.uid();
    v_count integer;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated' USING ERRCODE = '28000';
    END IF;

    UPDATE public.categories c
    SET sort_order = (t.ord - 1)::integer
    FROM unnest(p_ids) WITH ORDINALITY AS t(id, ord)
    WHERE c.id = t.id AND c.user_id = v_uid;
    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.category_limit(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_my_category_limit() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reorder_categories(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_category_limit() TO authenticated;
GRANT EXECUTE ON FUNCTION public.reorder_categories(uuid[]) TO authenticated;

COMMIT;
