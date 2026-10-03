-- 20260928120000_security_hardening migration'ı için davranış testleri.
-- Boş, yerel bir Postgres'te çalıştırın (CANLIDA DEĞİL):
--   psql -f supabase/tests/security_hardening_stub.sql
--   psql -f supabase/migrations/20260928120000_security_hardening_up.sql
--   psql -f supabase/tests/security_hardening_test.sql
-- Her testin başlığında beklenen sonuç (kabul/RED) yazılıdır.
\set VERBOSITY terse
\set ON_ERROR_STOP 0
INSERT INTO public.categories (id, user_id, name) VALUES ('aaaaaaaa-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','Mat');
SET request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
SET ROLE authenticated;
\echo '--- T1 geçerli seans (30 dk önce başlamış 25 dk) -> kabul'
SELECT public.complete_study_session(gen_random_uuid(),'aaaaaaaa-0000-0000-0000-000000000001',25, now() - interval '30 minutes');
\echo '--- T2 hile: şimdi başlamış 50 dk seans -> RED ve coin geri alınmalı'
SELECT public.complete_study_session(gen_random_uuid(),'aaaaaaaa-0000-0000-0000-000000000001',50, now());
\echo '--- T3 çakışan seans (T1 ile üst üste) -> RED'
SELECT public.complete_study_session(gen_random_uuid(),'aaaaaaaa-0000-0000-0000-000000000001',25, now() - interval '40 minutes');
\echo '--- T4 çakışmayan daha eski seans (çevrimdışı senkron) -> kabul'
SELECT public.complete_study_session(gen_random_uuid(),'aaaaaaaa-0000-0000-0000-000000000001',25, now() - interval '3 hours');
\echo '--- coins beklenen 10 (sadece T1 ve T4):'
SELECT coins FROM public.profiles WHERE id = auth.uid();
\echo '--- T5 kendi coin alanını güncelleme -> RED'
UPDATE public.profiles SET coins = 99999 WHERE id = auth.uid();
\echo '--- T6 kendi ismini güncelleme -> kabul'
UPDATE public.profiles SET name = 'Ali' WHERE id = auth.uid();
\echo '--- T7 seans tablosuna doğrudan INSERT -> RED'
INSERT INTO public.study_sessions (user_id, duration_minutes, started_at) VALUES (auth.uid(), 50, now() - interval '10 hours');
\echo '--- T8 eski sıralama fonksiyonu (e-posta döndüren) -> RED'
SELECT count(*) FROM public.get_league_ranking('22222222-2222-2222-2222-222222222222');
\echo '--- T9 yeni sıralama: e-posta kolonu yok, is_me doğru'
SELECT * FROM public.get_my_league_ranking();
\echo '--- T10 kategori limiti: 7 tane daha ekle (toplam 8) sonra 9. -> RED'
INSERT INTO public.categories (user_id, name) SELECT auth.uid(), 'K'||g FROM generate_series(2,8) g;
INSERT INTO public.categories (user_id, name) VALUES (auth.uid(), 'K9');
\echo '--- T11 arşivle + yeni ekle -> kabul; arşivi aç (9. aktif olur) -> RED'
UPDATE public.categories SET is_archived = true WHERE name = 'K8';
INSERT INTO public.categories (user_id, name) VALUES (auth.uid(), 'K9');
UPDATE public.categories SET is_archived = false WHERE name = 'K8';
\echo '--- T12 aktif kategori ismini düzenleme -> kabul'
UPDATE public.categories SET name = 'Matematik' WHERE name = 'Mat';
\echo '--- T13 profil oluşturma (ignoreDuplicates upsert = ON CONFLICT DO NOTHING) -> kabul'
INSERT INTO public.profiles (id, email, name, avatar_id) VALUES (auth.uid(), 'a@x.com', 'X', 'a') ON CONFLICT (id) DO NOTHING;
RESET ROLE;
\echo '--- T14 anon profilleri okuyamaz'
SET ROLE anon; SELECT count(*) FROM public.profiles; RESET ROLE;
\echo '--- T15 search_path atanmış mı (start_study_session):'
SELECT proconfig FROM pg_proc WHERE proname = 'start_study_session';
