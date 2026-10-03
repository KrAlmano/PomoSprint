-- 20260928120000_security_hardening davranış testleri (gerçek migration
-- zinciri üzerinde, ASSERT ile). Yerel, tek kullanımlık bir Postgres'te
-- çalıştırın (CANLIDA DEĞİL): supabase/tests/run_local.sh
-- Herhangi bir ASSERT başarısız olursa psql ON_ERROR_STOP ile durur ve
-- sıfırdan farklı çıkış kodu döner.

\set ON_ERROR_STOP 1
\set VERBOSITY terse

-- Kullanıcılar: A = 1111..., B = 2222...
INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    ('11111111-1111-1111-1111-111111111111', 'a@x.com', now()),
    ('22222222-2222-2222-2222-222222222222', 'b@x.com', now());
INSERT INTO public.profiles (id, email, name, friend_code) VALUES
    ('11111111-1111-1111-1111-111111111111', 'a@x.com', 'A', 'AAAAAA'),
    ('22222222-2222-2222-2222-222222222222', 'b@x.com', 'B', 'BBBBBB');
INSERT INTO public.categories (id, user_id, name, color_hex) VALUES
    ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'Mat', '#FF0000');

\echo '--- T1-T4 seans doğrulaması'
DO $$
DECLARE
    v_cat uuid := 'aaaaaaaa-0000-0000-0000-000000000001';
    r jsonb;
    v_coins_before integer;
    v_coins_after integer;
BEGIN
    SELECT coins INTO v_coins_before FROM public.profiles WHERE id = '11111111-1111-1111-1111-111111111111';

    PERFORM tests.login('11111111-1111-1111-1111-111111111111');

    r := tests.session(v_cat, 25, now() - interval '30 minutes');
    ASSERT tests.accepted(r), 'T1 geçerli seans (30 dk önce başlamış 25 dk) kabul edilmeli: ' || r::text;
    ASSERT (r ->> 'base_points')::int = 5, 'T1 25 dk seans 5 taban puan vermeli: ' || r::text;

    r := tests.session(v_cat, 50, now());
    ASSERT NOT tests.accepted(r), 'T2 şimdi başlamış 50 dk seans reddedilmeli: ' || r::text;

    r := tests.session(v_cat, 25, now() - interval '40 minutes');
    ASSERT NOT tests.accepted(r), 'T3 T1 ile çakışan seans reddedilmeli: ' || r::text;

    r := tests.session(v_cat, 25, now() - interval '20 hours');
    -- Daha yeni bir seanstan SONRA gönderilen eski seans: repodaki RPC
    -- 'overlap' döndürür. proposed/01_complete_study_session.sql
    -- uygulanınca kabul edilir; bu yüzden yalnızca bilgi olarak yazılır.
    RAISE NOTICE 'T4 (bilgi) sıra dışı eski seans sonucu: %', r::text;

    PERFORM tests.logout();
    SELECT coins INTO v_coins_after FROM public.profiles WHERE id = '11111111-1111-1111-1111-111111111111';
    ASSERT v_coins_after - v_coins_before = 5
        + CASE WHEN tests.accepted(r) THEN 5 ELSE 0 END,
        format('Reddedilen seansların coin''i geri alınmalı (önce %s, sonra %s)', v_coins_before, v_coins_after);
END $$;

\echo '--- T5-T7 profil ve seans tablosu yetkileri'
DO $$
DECLARE
    v_err text;
BEGIN
    PERFORM tests.login('11111111-1111-1111-1111-111111111111');

    v_err := tests.error_of($q$UPDATE public.profiles SET coins = 99999 WHERE id = auth.uid()$q$);
    ASSERT v_err IS NOT NULL, 'T5 kullanıcı kendi coin alanını güncelleyememeli';

    v_err := tests.error_of($q$UPDATE public.profiles SET name = 'Ali' WHERE id = auth.uid()$q$);
    ASSERT v_err IS NULL, 'T6 kullanıcı kendi ismini güncelleyebilmeli: ' || COALESCE(v_err, '');

    v_err := tests.error_of($q$INSERT INTO public.study_sessions (user_id, duration_minutes, started_at)
                               VALUES (auth.uid(), 50, now() - interval '10 hours')$q$);
    ASSERT v_err IS NOT NULL, 'T7 seans tablosuna doğrudan INSERT reddedilmeli';

    v_err := tests.error_of($q$INSERT INTO public.profiles (id, email, name, avatar_id)
                               VALUES (auth.uid(), 'a@x.com', 'X', 'avatar_16_basic') ON CONFLICT (id) DO NOTHING$q$);
    ASSERT v_err IS NULL, 'T13 profil upsert (ON CONFLICT DO NOTHING) çalışmalı: ' || COALESCE(v_err, '');

    PERFORM tests.logout();
    ASSERT (SELECT name FROM public.profiles WHERE id = '11111111-1111-1111-1111-111111111111') = 'Ali',
        'T6 isim güncellenmiş olmalı';
END $$;

\echo '--- T8-T9 lig sıralaması'
DO $$
DECLARE
    v_err text;
    v_me integer;
BEGIN
    PERFORM tests.login('11111111-1111-1111-1111-111111111111');

    v_err := tests.error_of($q$SELECT count(*) FROM public.get_league_ranking('22222222-2222-2222-2222-222222222222')$q$);
    ASSERT v_err IS NOT NULL, 'T8 e-posta döndüren eski get_league_ranking istemciye kapalı olmalı';

    v_err := tests.error_of($q$SELECT email FROM public.get_my_league_ranking()$q$);
    ASSERT v_err IS NOT NULL, 'T9 get_my_league_ranking e-posta kolonu döndürmemeli';

    SELECT count(*) INTO v_me FROM public.get_my_league_ranking() WHERE is_me;
    ASSERT v_me = 1, 'T9 get_my_league_ranking kendi satırını tam bir kez is_me ile döndürmeli';
END $$;

\echo '--- T10-T12 kategori limiti'
DO $$
DECLARE
    v_err text;
BEGIN
    PERFORM tests.login('11111111-1111-1111-1111-111111111111');

    v_err := tests.error_of($q$INSERT INTO public.categories (user_id, name, color_hex)
                               SELECT auth.uid(), 'K' || g, '#000000' FROM generate_series(2, 8) g$q$);
    ASSERT v_err IS NULL, 'T10 toplam 8 aktif kategoriye kadar ekleme kabul edilmeli: ' || COALESCE(v_err, '');

    v_err := tests.error_of($q$INSERT INTO public.categories (user_id, name, color_hex) VALUES (auth.uid(), 'K9', '#000000')$q$);
    ASSERT v_err IS NOT NULL, 'T10 9. aktif kategori reddedilmeli';

    v_err := tests.error_of($q$UPDATE public.categories SET is_archived = true WHERE name = 'K8' AND user_id = auth.uid()$q$);
    ASSERT v_err IS NULL, 'T11 arşivleme kabul edilmeli: ' || COALESCE(v_err, '');
    v_err := tests.error_of($q$INSERT INTO public.categories (user_id, name, color_hex) VALUES (auth.uid(), 'K9', '#000000')$q$);
    ASSERT v_err IS NULL, 'T11 arşivden sonra yeni kategori kabul edilmeli: ' || COALESCE(v_err, '');
    v_err := tests.error_of($q$UPDATE public.categories SET is_archived = false WHERE name = 'K8' AND user_id = auth.uid()$q$);
    ASSERT v_err IS NOT NULL, 'T11 arşivi açmak 9. aktif kategori olacağı için reddedilmeli';

    v_err := tests.error_of($q$UPDATE public.categories SET name = 'Matematik' WHERE name = 'Mat' AND user_id = auth.uid()$q$);
    ASSERT v_err IS NULL, 'T12 aktif kategori ismini düzenleme kabul edilmeli: ' || COALESCE(v_err, '');
END $$;

\echo '--- T14 anon profilleri okuyamaz'
DO $$
BEGIN
    PERFORM tests.login(NULL);
    ASSERT tests.error_of($q$SELECT count(*) FROM public.profiles$q$) IS NOT NULL,
        'T14 anon profiles tablosunu okuyamamalı';
END $$;

\echo '--- T15 SECURITY DEFINER fonksiyonlarında search_path sabit'
DO $$
DECLARE
    v_missing text;
BEGIN
    SELECT string_agg(p.oid::regprocedure::text, ', ') INTO v_missing
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prosecdef
      AND NOT EXISTS (
          SELECT 1 FROM unnest(COALESCE(p.proconfig, '{}')) c WHERE c LIKE 'search_path=%'
      );
    ASSERT v_missing IS NULL, 'T15 search_path atanmamış SECURITY DEFINER fonksiyonlar: ' || COALESCE(v_missing, '');
END $$;

\echo 'security_hardening_test: tüm testler geçti'
