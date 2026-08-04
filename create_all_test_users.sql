-- ============================================================
-- PomoSprint — 7 Test Hesabını Doğrudan Supabase Auth'a Ekleme Kodu
-- Supabase Dashboard -> SQL Editor kısmına yapıştırıp RUN'a basın.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. ESKİ TEST E-POSTALARI VARSA TEMİZLE (Çakışma Önleyici)
DELETE FROM auth.users WHERE email LIKE '%@pomosprint.app';

-- 2. 7 TEST HESABINI DOĞRUDAN auth.users TABLOSUNA EKLE (E-posta Onaylı & Şifreli)
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, 
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at, 
  confirmation_token, recovery_token, email_change_token_new, email_change
) VALUES
(
  '00000000-0000-0000-0000-000000000000', 'a1111111-1111-1111-1111-111111111111',
  'authenticated', 'authenticated', 'elif.yilmaz@pomosprint.app',
  crypt('Password123!', gen_salt('bf')), NOW(),
  '{"provider":"email","providers":["email"]}', '{"name":"Elif Yılmaz","avatar_id":"avatar_7_scholar"}',
  NOW(), NOW(), '', '', '', ''
),
(
  '00000000-0000-0000-0000-000000000000', 'a2222222-2222-2222-2222-222222222222',
  'authenticated', 'authenticated', 'alexander.vance@pomosprint.app',
  crypt('Password123!', gen_salt('bf')), NOW(),
  '{"provider":"email","providers":["email"]}', '{"name":"Alexander Vance","avatar_id":"avatar_1_gamer"}',
  NOW(), NOW(), '', '', '', ''
),
(
  '00000000-0000-0000-0000-000000000000', 'a3333333-3333-3333-3333-333333333333',
  'authenticated', 'authenticated', 'zeynep.demir@pomosprint.app',
  crypt('Password123!', gen_salt('bf')), NOW(),
  '{"provider":"email","providers":["email"]}', '{"name":"Zeynep Demir","avatar_id":"avatar_11_doctor"}',
  NOW(), NOW(), '', '', '', ''
),
(
  '00000000-0000-0000-0000-000000000000', 'a4444444-4444-4444-4444-444444444444',
  'authenticated', 'authenticated', 'kenji.sato@pomosprint.app',
  crypt('Password123!', gen_salt('bf')), NOW(),
  '{"provider":"email","providers":["email"]}', '{"name":"Kenji Sato","avatar_id":"avatar_9_viking"}',
  NOW(), NOW(), '', '', '', ''
),
(
  '00000000-0000-0000-0000-000000000000', 'a5555555-5555-5555-5555-555555555555',
  'authenticated', 'authenticated', 'sarah.miller@pomosprint.app',
  crypt('Password123!', gen_salt('bf')), NOW(),
  '{"provider":"email","providers":["email"]}', '{"name":"Sarah Miller","avatar_id":"avatar_13_pilot"}',
  NOW(), NOW(), '', '', '', ''
),
(
  '00000000-0000-0000-0000-000000000000', 'a6666666-6666-6666-6666-666666666666',
  'authenticated', 'authenticated', 'mert.kaya@pomosprint.app',
  crypt('Password123!', gen_salt('bf')), NOW(),
  '{"provider":"email","providers":["email"]}', '{"name":"Mert Kaya","avatar_id":"avatar_3_gentleman"}',
  NOW(), NOW(), '', '', '', ''
),
(
  '00000000-0000-0000-0000-000000000000', 'a7777777-7777-7777-7777-777777777777',
  'authenticated', 'authenticated', 'elena.rostova@pomosprint.app',
  crypt('Password123!', gen_salt('bf')), NOW(),
  '{"provider":"email","providers":["email"]}', '{"name":"Elena Rostova","avatar_id":"avatar_15_athlete"}',
  NOW(), NOW(), '', '', '', ''
);

-- 3. PROFİLLERİ public.profiles TABLOSUNA GÜNCELLE / EKLE
INSERT INTO public.profiles (id, email, name, avatar_id, total_minutes, points, created_at)
VALUES
  ('a1111111-1111-1111-1111-111111111111', 'elif.yilmaz@pomosprint.app', 'Elif Yılmaz', 'avatar_7_scholar', 1250, 12500, NOW()),
  ('a2222222-2222-2222-2222-222222222222', 'alexander.vance@pomosprint.app', 'Alexander Vance', 'avatar_1_gamer', 980, 9800, NOW()),
  ('a3333333-3333-3333-3333-333333333333', 'zeynep.demir@pomosprint.app', 'Zeynep Demir', 'avatar_11_doctor', 840, 8400, NOW()),
  ('a4444444-4444-4444-4444-444444444444', 'kenji.sato@pomosprint.app', 'Kenji Sato', 'avatar_9_viking', 720, 7200, NOW()),
  ('a5555555-5555-5555-5555-555555555555', 'sarah.miller@pomosprint.app', 'Sarah Miller', 'avatar_13_pilot', 650, 6500, NOW()),
  ('a6666666-6666-6666-6666-666666666666', 'mert.kaya@pomosprint.app', 'Mert Kaya', 'avatar_3_gentleman', 520, 5200, NOW()),
  ('a7777777-7777-7777-7777-777777777777', 'elena.rostova@pomosprint.app', 'Elena Rostova', 'avatar_15_athlete', 410, 4100, NOW())
ON CONFLICT (id) DO UPDATE SET
  total_minutes = EXCLUDED.total_minutes, 
  points = EXCLUDED.points, 
  avatar_id = EXCLUDED.avatar_id, 
  name = EXCLUDED.name;

-- 4. SANAL KÜTÜPHANE MASALARINI DOLDUR (public.table_seats)
INSERT INTO public.table_seats (table_id, seat_index, user_id, user_email, user_name, avatar_id, subject, seated_at, is_pomodoro_started, current_timer_seconds, completed_pomodoros, updated_at)
VALUES
  ('table_1', 0, 'a1111111-1111-1111-1111-111111111111', 'elif.yilmaz@pomosprint.app', 'Elif Yılmaz', 'avatar_7_scholar', 'Matematiğe Odaklanma', NOW(), true, 840, 4, NOW()),
  ('table_1', 1, 'a2222222-2222-2222-2222-222222222222', 'alexander.vance@pomosprint.app', 'Alexander Vance', 'avatar_1_gamer', 'Flutter & Mobile Dev', NOW(), true, 1120, 3, NOW()),
  ('table_2', 0, 'a3333333-3333-3333-3333-333333333333', 'zeynep.demir@pomosprint.app', 'Zeynep Demir', 'avatar_11_doctor', 'Tıp & Anatomi', NOW(), true, 600, 5, NOW()),
  ('table_2', 1, 'a4444444-4444-4444-4444-444444444444', 'kenji.sato@pomosprint.app', 'Kenji Sato', 'avatar_9_viking', 'Python & AI Algorithms', NOW(), true, 900, 2, NOW()),
  ('table_2', 2, 'a5555555-5555-5555-5555-555555555555', 'sarah.miller@pomosprint.app', 'Sarah Miller', 'avatar_13_pilot', 'English & TOEFL Prep', NOW(), true, 1350, 1, NOW()),
  ('table_3', 0, 'a6666666-6666-6666-6666-666666666666', 'mert.kaya@pomosprint.app', 'Mert Kaya', 'avatar_3_gentleman', 'YKS Fizik & Kimya', NOW(), true, 300, 3, NOW())
ON CONFLICT (table_id, seat_index) DO UPDATE SET
  user_email = EXCLUDED.user_email, 
  user_name = EXCLUDED.user_name, 
  avatar_id = EXCLUDED.avatar_id, 
  subject = EXCLUDED.subject, 
  is_pomodoro_started = true, 
  current_timer_seconds = EXCLUDED.current_timer_seconds, 
  completed_pomodoros = EXCLUDED.completed_pomodoros, 
  updated_at = NOW();
