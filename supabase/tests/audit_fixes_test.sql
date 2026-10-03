-- 20261003120000_audit_fixes davranış testleri (gerçek migration zinciri
-- üzerinde, ASSERT ile). Yerel, tek kullanımlık bir Postgres'te çalıştırın
-- (CANLIDA DEĞİL): supabase/tests/run_local.sh

\set ON_ERROR_STOP 1
\set VERBOSITY terse

-- U1 çevrimdışı kuyruk/saat dilimi/kategori, U2 saat kayması,
-- U3-U5 arkadaşlık, U6-U7 profil oluşturma (profil satırı yok).
INSERT INTO auth.users (id, email, email_confirmed_at) VALUES
    ('c1000000-0000-0000-0000-000000000001', 'u1@x.com', now()),
    ('c1000000-0000-0000-0000-000000000002', 'u2@x.com', now()),
    ('c1000000-0000-0000-0000-000000000003', 'u3@x.com', now()),
    ('c1000000-0000-0000-0000-000000000004', 'u4@x.com', now()),
    ('c1000000-0000-0000-0000-000000000005', 'u5@x.com', now()),
    ('c1000000-0000-0000-0000-000000000006', 'u6@x.com', now()),
    ('c1000000-0000-0000-0000-000000000007', 'u7@x.com', now());
INSERT INTO public.profiles (id, email, name, friend_code) VALUES
    ('c1000000-0000-0000-0000-000000000001', 'u1@x.com', 'U1', 'UUUUU1'),
    ('c1000000-0000-0000-0000-000000000002', 'u2@x.com', 'U2', 'UUUUU2'),
    ('c1000000-0000-0000-0000-000000000003', 'u3@x.com', 'U3', 'UUUUU3'),
    ('c1000000-0000-0000-0000-000000000004', 'u4@x.com', 'U4', 'UUUUU4'),
    ('c1000000-0000-0000-0000-000000000005', 'u5@x.com', 'U5', 'UUUUU5');
INSERT INTO public.categories (id, user_id, name, color_hex) VALUES
    ('c2000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'Fizik', '#FF0000'),
    ('c2000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000002', 'Kimya', '#00FF00');

\echo '--- A1 çevrimdışı kuyruk: completed_at gerçek bitiş, 2. seans kabul (BACKEND-01)'
DO $$
DECLARE
    v_cat uuid := 'c2000000-0000-0000-0000-000000000001';
    r jsonb;
    v_row record;
BEGIN
    PERFORM tests.login('c1000000-0000-0000-0000-000000000001');

    r := tests.session(v_cat, 25, now() - interval '180 minutes', false, 'd1000000-0000-0000-0000-000000000001');
    ASSERT tests.accepted(r), 'A1.1 1. çevrimdışı seans kabul edilmeli: ' || r::text;

    -- 1. seansın bittiği anda başlayan 2. seans: eskiden completed_at =
    -- senkron anı olduğu için 'overlap' alıp kayboluyordu.
    r := tests.session(v_cat, 25, now() - interval '155 minutes', false, 'd1000000-0000-0000-0000-000000000002');
    ASSERT tests.accepted(r), 'A1.2 2. çevrimdışı seans kabul edilmeli: ' || r::text;

    r := tests.session(v_cat, 50, now() - interval '120 minutes', false, 'd1000000-0000-0000-0000-000000000003');
    ASSERT tests.accepted(r), 'A1.3 3. çevrimdışı (50 dk) seans kabul edilmeli: ' || r::text;

    -- Aynı client_uuid yeniden gönderilirse çift kayıt olmaz.
    r := tests.session(v_cat, 25, now() - interval '180 minutes', false, 'd1000000-0000-0000-0000-000000000001');
    ASSERT (r ->> 'duplicate')::boolean, 'A1.4 aynı client_uuid duplicate dönmeli: ' || r::text;

    -- Gerçekten çakışan seans yine reddedilir.
    r := tests.session(v_cat, 25, now() - interval '100 minutes');
    ASSERT NOT tests.accepted(r), 'A1.5 3. seansla çakışan seans reddedilmeli: ' || r::text;

    PERFORM tests.logout();

    SELECT * INTO v_row FROM public.study_sessions WHERE client_uuid = 'd1000000-0000-0000-0000-000000000001';
    ASSERT v_row.completed_at = v_row.started_at + interval '25 minutes',
        'A1.6 completed_at = started_at + süre olmalı: ' || v_row.completed_at::text;
    ASSERT v_row.synced_at IS NOT NULL AND v_row.synced_at > v_row.completed_at,
        'A1.7 synced_at senkron anını tutmalı';

    SELECT * INTO v_row FROM public.study_sessions WHERE client_uuid = 'd1000000-0000-0000-0000-000000000003';
    ASSERT v_row.completed_at = v_row.started_at + interval '50 minutes', 'A1.8 50 dk seansın bitişi doğru olmalı';

    ASSERT (SELECT count(*) FROM public.study_sessions WHERE user_id = 'c1000000-0000-0000-0000-000000000001') = 3,
        'A1.9 tabloda tam 3 seans olmalı';
END $$;

\echo '--- A2 saat kayması: 3-15 dk ileri kabul, debug kısa seans red (BACKEND-08)'
DO $$
DECLARE
    v_cat uuid := 'c2000000-0000-0000-0000-000000000002';
    r jsonb;
    v_row record;
BEGIN
    PERFORM tests.login('c1000000-0000-0000-0000-000000000002');

    -- Debug build: 25 dk seans 5 saniyede biter. Sunucu reddetmeli (KASITLI).
    r := tests.session(v_cat, 25, now() - interval '5 seconds');
    ASSERT r ->> 'exception' LIKE 'session_not_elapsed%', 'A2.1 debug kısa seans reddedilmeli: ' || r::text;

    -- Bitişi 20 dk sonra: tolerans dışı, reddedilir.
    r := tests.session(v_cat, 25, now() - interval '5 minutes');
    ASSERT r ->> 'exception' LIKE 'session_not_elapsed%', 'A2.2 bitişi 20 dk sonraki seans reddedilmeli: ' || r::text;

    -- Bitişi 10 dk sonra (cihaz saati ~10 dk ileri): kabul, geri kaydırılır.
    r := tests.session(v_cat, 25, now() - interval '15 minutes', false, 'd2000000-0000-0000-0000-000000000001');
    ASSERT tests.accepted(r), 'A2.3 birkaç dakika ileri saatli seans kabul edilmeli: ' || r::text;

    PERFORM tests.logout();
    SELECT * INTO v_row FROM public.study_sessions WHERE client_uuid = 'd2000000-0000-0000-0000-000000000001';
    ASSERT v_row.completed_at = now() + interval '3 minutes',
        'A2.4 bitiş doğrulamanın kabul ettiği en yakın ana (now()+3 dk) çekilmeli: ' || v_row.completed_at::text;
    ASSERT v_row.started_at = now() - interval '22 minutes',
        'A2.5 başlangıç 7 dk geri kaydırılmalı: ' || v_row.started_at::text;
END $$;

\echo '--- A3 arkadaş RPC''leri (SOCIAL-05 / BACKEND-14 / SOCIAL-20)'
-- U3 <-> U4 kabul edilmiş, iki satırlı model; U5 -> U3 bekleyen istek.
INSERT INTO public.friendships (user_id, friend_id, status) VALUES
    ('c1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000004', 'accepted'),
    ('c1000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000003', 'accepted'),
    ('c1000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000003', 'pending');
-- U1 -> U2 kabul edilmiş, tek satırlı model.
INSERT INTO public.friendships (user_id, friend_id, status) VALUES
    ('c1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000002', 'accepted');

DO $$
DECLARE
    u1 uuid := 'c1000000-0000-0000-0000-000000000001';
    u2 uuid := 'c1000000-0000-0000-0000-000000000002';
    u3 uuid := 'c1000000-0000-0000-0000-000000000003';
    u4 uuid := 'c1000000-0000-0000-0000-000000000004';
    u5 uuid := 'c1000000-0000-0000-0000-000000000005';
    v_count integer;
    v_created timestamptz;
    r jsonb;
BEGIN
    PERFORM tests.login(u3);
    SELECT count(*) INTO v_count FROM public.get_my_friends() WHERE id = u4;
    ASSERT v_count = 1, 'A3.1 iki satırlı modelde arkadaş tam bir kez dönmeli, dönen: ' || v_count;
    SELECT count(*), max(created_at) INTO v_count, v_created FROM public.get_incoming_friend_requests() WHERE id = u5;
    ASSERT v_count = 1 AND v_created IS NOT NULL, 'A3.2 U3, U5''in bekleyen isteğini created_at ile görmeli';
    ASSERT tests.error_of($q$SELECT email FROM public.get_incoming_friend_requests()$q$) IS NOT NULL,
        'A3.3 istek satırları e-posta içermemeli';
    ASSERT tests.error_of($q$SELECT email FROM public.get_my_friends()$q$) IS NOT NULL,
        'A3.4 arkadaş satırları e-posta içermemeli';

    PERFORM tests.login(u5);
    SELECT count(*) INTO v_count FROM public.get_outgoing_friend_requests() WHERE id = u3;
    ASSERT v_count = 1, 'A3.5 U5 gönderdiği isteği görmeli';
    SELECT count(*) INTO v_count FROM public.get_incoming_friend_requests();
    ASSERT v_count = 0, 'A3.6 isteği gönderen taraf onu gelen istek olarak görmemeli';

    -- Tek satırlı modelde iki taraf da birbirini görür.
    PERFORM tests.login(u1);
    SELECT count(*) INTO v_count FROM public.get_my_friends() WHERE id = u2;
    ASSERT v_count = 1, 'A3.7 isteği gönderen taraf arkadaşını görmeli';
    PERFORM tests.login(u2);
    SELECT count(*) INTO v_count FROM public.get_my_friends() WHERE id = u1;
    ASSERT v_count = 1, 'A3.8 isteği kabul eden taraf da arkadaşını görmeli (iki yönlü)';

    PERFORM tests.login(NULL);
    ASSERT tests.error_of($q$SELECT * FROM public.get_my_friends()$q$) IS NOT NULL,
        'A3.9 anon get_my_friends çağıramamalı';
    ASSERT tests.error_of($q$SELECT * FROM public.get_incoming_friend_requests()$q$) IS NOT NULL,
        'A3.10 anon get_incoming_friend_requests çağıramamalı';

    PERFORM tests.login(u5);
    r := public.cancel_friend_request(u3);
    ASSERT (r ->> 'success')::boolean, 'A3.11 U5 isteğini geri çekebilmeli: ' || r::text;
    PERFORM tests.login(u3);
    SELECT count(*) INTO v_count FROM public.get_incoming_friend_requests();
    ASSERT v_count = 0, 'A3.12 geri çekilen istek listeden düşmeli';

    r := public.remove_friend(u4);
    ASSERT (r ->> 'success')::boolean, 'A3.13 U3 arkadaşlığı silebilmeli: ' || r::text;
    PERFORM tests.login(u4);
    SELECT count(*) INTO v_count FROM public.get_my_friends() WHERE id = u3;
    ASSERT v_count = 0, 'A3.14 silinen arkadaşlık iki taraftan da düşmeli';

    PERFORM tests.logout();
    SELECT count(*) INTO v_count FROM public.friendships
    WHERE (user_id = u3 AND friend_id = u4) OR (user_id = u4 AND friend_id = u3);
    ASSERT v_count = 0, 'A3.15 iki yöndeki satır da silinmeli';
END $$;

\echo '--- A4 avatar kataloğu anon okunabilir (SOCIAL-V01)'
DO $$
DECLARE
    v_count integer;
BEGIN
    PERFORM tests.login(NULL);
    SELECT count(*) INTO v_count FROM public.avatars;
    ASSERT v_count > 0, 'A4.1 anon avatar kataloğunu okuyabilmeli';
    SELECT count(*) INTO v_count FROM public.avatars WHERE NOT is_active;
    ASSERT v_count = 0, 'A4.2 anon pasif avatarları görmemeli';
END $$;

\echo '--- A5 profil oluşturma: e-posta ve avatar zorlaması (BACKEND-12 / SOCIAL-15)'
DO $$
DECLARE
    v_row record;
BEGIN
    -- Ücretli avatar + başkasının e-postası ile kendi profilini oluşturma.
    PERFORM tests.login('c1000000-0000-0000-0000-000000000006');
    INSERT INTO public.profiles (id, email, name, avatar_id)
    VALUES (auth.uid(), 'ceo@baskasi.com', 'U6', 'avatar_1_gamer');

    -- Ücretsiz (varsayılan) avatar seçimi korunur.
    PERFORM tests.login('c1000000-0000-0000-0000-000000000007');
    INSERT INTO public.profiles (id, email, name, avatar_id)
    VALUES (auth.uid(), 'u7@x.com', 'U7', 'avatar_2_glasses');

    PERFORM tests.logout();
    SELECT email, avatar_id, equipped_avatar_id INTO v_row
    FROM public.profiles WHERE id = 'c1000000-0000-0000-0000-000000000006';
    ASSERT v_row.email = 'u6@x.com', 'A5.1 e-posta auth.users''tan gelmeli: ' || v_row.email;
    ASSERT v_row.avatar_id = 'avatar_16_basic', 'A5.2 ücretli avatar varsayılana çekilmeli: ' || v_row.avatar_id;
    ASSERT v_row.equipped_avatar_id = 'avatar_16_basic', 'A5.3 equipped_avatar_id ayarlanmalı';

    SELECT email, avatar_id, equipped_avatar_id INTO v_row
    FROM public.profiles WHERE id = 'c1000000-0000-0000-0000-000000000007';
    ASSERT v_row.avatar_id = 'avatar_2_glasses' AND v_row.equipped_avatar_id = 'avatar_2_glasses',
        'A5.4 ücretsiz avatar seçimi korunmalı';
    ASSERT EXISTS (
        SELECT 1 FROM public.avatar_unlocks
        WHERE user_id = 'c1000000-0000-0000-0000-000000000007' AND avatar_id = 'avatar_2_glasses'
    ), 'A5.5 varsayılan avatarlar give_default_avatars ile açılmış olmalı';
END $$;

\echo '--- A6 çalışma günü, seri ve saat dilimi (BACKEND-09 / BACKEND-11)'
DO $$
DECLARE
    v_tz text;
    v_err text;
    v_streak record;
BEGIN
    ASSERT public.study_day_of('2026-10-03 00:30:00+03', 'Europe/Istanbul') = date '2026-10-02',
        'A6.1 04:00 öncesi önceki güne sayılmalı';
    ASSERT public.study_day_of('2026-10-03 04:30:00+03', 'Europe/Istanbul') = date '2026-10-03',
        'A6.2 04:00 sonrası aynı gün';
    ASSERT public.study_day_start(date '2026-10-03', 'Europe/Istanbul') = timestamptz '2026-10-03 04:00:00+03',
        'A6.3 çalışma günü yerel 04:00''te başlamalı';

    PERFORM tests.login('c1000000-0000-0000-0000-000000000001');

    SELECT * INTO v_streak FROM public.get_my_streak();
    ASSERT v_streak.effective_streak >= 1, 'A6.4 bugün seans yapan kullanıcının serisi en az 1 olmalı';

    v_err := tests.error_of($q$SELECT public.set_my_timezone('Mars/Phobos')$q$);
    ASSERT v_err LIKE 'invalid_timezone%', 'A6.5 geçersiz saat dilimi reddedilmeli: ' || COALESCE(v_err, 'hata yok');

    v_tz := public.set_my_timezone('Europe/Berlin');
    ASSERT v_tz = 'Europe/Berlin', 'A6.6 geçerli saat dilimi kaydedilmeli: ' || v_tz;
    v_tz := public.set_my_timezone('Asia/Tokyo');
    ASSERT v_tz = 'Europe/Berlin', 'A6.7 24 saat dolmadan ikinci değişiklik uygulanmamalı: ' || v_tz;

    PERFORM tests.logout();
    ASSERT (SELECT timezone FROM public.profiles WHERE id = 'c1000000-0000-0000-0000-000000000001') = 'Europe/Berlin',
        'A6.8 profiles.timezone güncellenmiş olmalı';
END $$;

\echo '--- A7 kategori limiti tek kaynak ve toplu sıralama (BACKEND-28 / DATA-26)'
DO $$
DECLARE
    v_err text;
    v_ids uuid[];
    v_count integer;
    v_foreign uuid := 'c2000000-0000-0000-0000-000000000002';
BEGIN
    PERFORM tests.login('c1000000-0000-0000-0000-000000000001');

    ASSERT public.get_my_category_limit() = 8, 'A7.1 ücretsiz kullanıcının limiti 8 olmalı';

    v_err := tests.error_of($q$INSERT INTO public.categories (user_id, name, color_hex)
                               SELECT auth.uid(), 'Ders' || g, '#000000' FROM generate_series(2, 8) g$q$);
    ASSERT v_err IS NULL, 'A7.2 8 kategoriye kadar ekleme kabul edilmeli: ' || COALESCE(v_err, '');
    v_err := tests.error_of($q$INSERT INTO public.categories (user_id, name, color_hex) VALUES (auth.uid(), 'Fazla', '#000000')$q$);
    ASSERT v_err IS NOT NULL, 'A7.3 9. aktif kategori reddedilmeli';

    SELECT array_agg(id ORDER BY sort_order DESC, name DESC) INTO v_ids
    FROM public.categories WHERE user_id = auth.uid();
    v_count := public.reorder_categories(v_ids || v_foreign);
    ASSERT v_count = 8, 'A7.4 yalnızca kullanıcının kendi 8 kategorisi güncellenmeli, güncellenen: ' || v_count;
    ASSERT (SELECT sort_order FROM public.categories WHERE id = v_ids[1]) = 0, 'A7.5 ilk sıradaki sort_order 0 olmalı';
    ASSERT (SELECT sort_order FROM public.categories WHERE id = v_ids[8]) = 7, 'A7.6 son sıradaki sort_order 7 olmalı';

    PERFORM tests.logout();
    ASSERT (SELECT sort_order FROM public.categories WHERE id = v_foreign) = 0,
        'A7.7 başka kullanıcının kategorisi değişmemeli';
END $$;

\echo 'audit_fixes_test: tüm testler geçti'
