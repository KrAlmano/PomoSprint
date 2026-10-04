-- t2 — Onboarding/kategori sunucu bulgularının kendini geri alan SQL reprosu.
--   psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -X -f tool/local_supabase/e2e/t2_onboarding_categories/t2_server_repro.sql
-- Her şey tek transaction'da; sonda ROLLBACK. Geçici kullanıcı auth.users'a
-- eklenir (handle_new_user profili açar). Her satır "bulgu | beklenen | gerçek".
\set ON_ERROR_STOP 1
\pset format unaligned
\pset tuples_only on
BEGIN;

INSERT INTO auth.users (id, instance_id, aud, role, email, raw_user_meta_data, email_confirmed_at)
VALUES ('00000000-0000-4000-a000-0000000072aa'::uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        't2-sqlrepro@pomosprint.local',
        '{"name":"T2 SQL","avatar_id":"avatar_16_basic","newsletter":false}', now());
SELECT 'A handle_new_user profil | 1 satır, onboarding alanları NULL, show_in_social_feed=t | '
       || count(*) || ' satır, segment=' || coalesce(max(user_segment), 'NULL')
       || ', show=' || bool_and(show_in_social_feed)::text || ', tz=' || max(timezone)
FROM public.profiles WHERE id = '00000000-0000-4000-a000-0000000072aa'::uuid;

SELECT set_config('request.jwt.claims', json_build_object('sub','00000000-0000-4000-a000-0000000072aa','role','authenticated')::text, true) IS NOT NULL;
SET LOCAL ROLE authenticated;

-- D1: ilk deneme YKS (8), profil PATCH'i yapılamadı; ikinci deneme work seçimi.
SELECT public.setup_onboarding_categories('[{"name":"Matematik","color_hex":"#EF4444","icon_name":"book"},{"name":"Fizik","color_hex":"#3B82F6","icon_name":"book"},{"name":"Kimya","color_hex":"#10B981","icon_name":"book"},{"name":"Biyoloji","color_hex":"#F59E0B","icon_name":"book"},{"name":"Türkçe","color_hex":"#8B5CF6","icon_name":"book"},{"name":"Tarih","color_hex":"#EC4899","icon_name":"book"},{"name":"Coğrafya","color_hex":"#14B8A6","icon_name":"book"},{"name":"Felsefe","color_hex":"#F97316","icon_name":"book"}]'::jsonb);
SELECT public.setup_onboarding_categories('[{"name":"Derin Çalışma","color_hex":"#EF4444","icon_name":"book"},{"name":"Okuma","color_hex":"#3B82F6","icon_name":"book"}]'::jsonb);
UPDATE public.profiles SET user_segment='work', birth_year=1995, daily_goal_minutes=60, onboarding_completed_at=now()
WHERE id = auth.uid();
SELECT 'D1 ikinci denemedeki seçim | Derin Çalışma, Okuma kurulmalı ya da hata dönmeli | aktif: '
       || string_agg(name, ', ' ORDER BY sort_order) FROM public.categories WHERE user_id = auth.uid() AND NOT is_archived;

-- D2: dil değişimi (TR yarım kurulum + EN tekrar) — temiz kullanıcıda: önce arşivle.
UPDATE public.categories SET is_archived = true WHERE user_id = auth.uid();
SELECT public.setup_onboarding_categories('[{"name":"Matematik","color_hex":"#EF4444","icon_name":"book"},{"name":"Fen Bilimleri","color_hex":"#3B82F6","icon_name":"book"}]'::jsonb);
SELECT public.setup_onboarding_categories('[{"name":"Mathematics","color_hex":"#EF4444","icon_name":"book"},{"name":"Science","color_hex":"#3B82F6","icon_name":"book"}]'::jsonb);
SELECT 'D2 TR+EN tekrar | 2 kategori | ' || count(*) || ': ' || string_agg(name, ', ' ORDER BY sort_order)
FROM public.categories WHERE user_id = auth.uid() AND NOT is_archived;

-- F: ad/renk doğrulaması ve büyük/küçük harf.
UPDATE public.categories SET is_archived = true WHERE user_id = auth.uid();
SELECT public.setup_onboarding_categories('[{"name":"","color_hex":"x","icon_name":"?"},{"name":"matematik","color_hex":"#EF4444","icon_name":"book"},{"name":"Matematik","color_hex":"#EF4444","icon_name":"book"}]'::jsonb);
SELECT 'F doğrulama | boş ad ve "x" renk reddedilmeli; matematik/Matematik tek | '
       || string_agg(quote_literal(name) || '/' || color_hex, ', ' ORDER BY sort_order)
FROM public.categories WHERE user_id = auth.uid() AND NOT is_archived;

-- G: yaş sınırı yalnızca istemcide.
UPDATE public.profiles SET birth_year = extract(year from now())::int - 5, onboarding_completed_at = now() WHERE id = auth.uid();
SELECT 'G 13 yaş altı | reddedilmeli | birth_year=' || birth_year || ' kabul edildi' FROM public.profiles WHERE id = auth.uid();

-- G2: show_in_social_feed gönderilmeyen onboarding PATCH'i → varsayılan TRUE kalır.
SELECT 'G2 görünürlük yanıtsız | açık seçim olmadan TRUE olmamalı | show_in_social_feed=' || show_in_social_feed
FROM public.profiles WHERE id = auth.uid();

ROLLBACK;
