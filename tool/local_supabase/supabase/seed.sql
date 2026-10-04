-- PomoSprint yerel kopya: referans verisi (kullanıcıya ait OLMAYAN tablolar).
-- `supabase db reset` her seferinde migrations/ sonrasında bu dosyayı yükler.
--
-- 4 Ekim 2026'da canlıdan SALT OKUMA ile alındı. Canlı public şemasında
-- kullanıcıya ait olmayan tek tablo avatar kataloğu (`avatars`, 27 satır).
-- Diğer referans değerleri tablo değil, fonksiyon gövdesinde ve snapshot
-- migration'ında birebir: puan sabitleri `get_points_config()` ve
-- `complete_study_session`, lig bölgeleri `get_league_zones()`, ödül
-- avatarları `league_award_avatar_id()`. `app_config` canlıda yok
-- (proposed/13).
--
-- Kopyalanmayanlar: `leagues` (çalışma sırasında `ensure_user_in_league`
-- açar; üyesiz lig satırı anlamsız), `profiles`, `study_sessions`,
-- `categories`, `friendships`, `league_memberships`, `activity_feed`,
-- `avatar_unlocks`, `marketing_subscribers`, `waitlist` ve `auth.*`
-- (kullanıcı verisi).
--
-- Parite: canlıdaki
--   select count(*), md5(string_agg(format('%L,%L,%L,%L,%s,%s,%s,%s,%s,%L,%s', id, name_tr, name_en,
--          asset_key, cost_coins, is_premium_only, is_default, sort_order, is_active, created_at,
--          is_league_award), E'\n' order by id collate "C")) from public.avatars;
-- sonucu 27 / 2dffed668b250dbc592e8c7c31ad3754 (TimeZone=UTC).

INSERT INTO public.avatars
    (id, name_tr, name_en, asset_key, cost_coins, is_premium_only, is_default, sort_order, is_active, created_at, is_league_award)
VALUES
    ('avatar_10_dentist', 'Dişçi Kum Saati', 'Dentist Hourglass', 'assets/avatars/avatar_10_dentist.png', 200, false, false, 10, true, '2026-08-09 08:53:36.679913+00', false),
    ('avatar_11_doctor', 'Doktor Kum Saati', 'Doctor Hourglass', 'assets/avatars/avatar_11_doctor.png', 0, true, false, 11, true, '2026-08-09 08:53:36.679913+00', false),
    ('avatar_12_builder', 'Mimar Kum Saati', 'Architect Hourglass', 'assets/avatars/avatar_12_builder.png', 0, true, false, 12, true, '2026-08-09 08:53:36.679913+00', false),
    ('avatar_13_pilot', 'Pilot Kum Saati', 'Pilot Hourglass', 'assets/avatars/avatar_13_pilot.png', 0, true, false, 13, true, '2026-08-09 08:53:36.679913+00', false),
    ('avatar_14_teacher', 'Öğretmen Kum Saati', 'Teacher Hourglass', 'assets/avatars/avatar_14_teacher.png', 0, true, false, 14, true, '2026-08-09 08:53:36.679913+00', false),
    ('avatar_15_athlete', 'Sporcu Kum Saati', 'Athlete Hourglass', 'assets/avatars/avatar_15_athlete.png', 0, true, false, 15, true, '2026-08-09 08:53:36.679913+00', false),
    ('avatar_16_basic', 'Klasik Kum Saati', 'Classic Hourglass', 'assets/avatars/avatar_16_basic.png', 0, false, true, 16, true, '2026-08-09 08:53:36.679913+00', false),
    ('avatar_1_gamer', 'Oyuncu Kum Saati', 'Gamer Hourglass', 'assets/avatars/avatar_1_gamer.png', 200, false, false, 1, true, '2026-08-09 08:53:36.679913+00', false),
    ('avatar_2_glasses', 'Gözlüklü Kum Saati', 'Glasses Hourglass', 'assets/avatars/avatar_2_glasses.png', 0, false, true, 2, true, '2026-08-09 08:53:36.679913+00', false),
    ('avatar_3_gentleman', 'Centilmen Kum Saati', 'Gentleman Hourglass', 'assets/avatars/avatar_3_gentleman.png', 0, false, true, 3, true, '2026-08-09 08:53:36.679913+00', false),
    ('avatar_4_bowtie', 'Hakim Kum Saati', 'Judge Hourglass', 'assets/avatars/avatar_4_bowtie.png', 200, false, false, 4, true, '2026-08-09 08:53:36.679913+00', false),
    ('avatar_5_flower', 'Çiçekli Kum Saati', 'Flower Hourglass', 'assets/avatars/avatar_5_flower.png', 0, false, true, 5, true, '2026-08-09 08:53:36.679913+00', false),
    ('avatar_6_cool', 'Süslü Kum Saati', 'Glam Hourglass', 'assets/avatars/avatar_6_cool.png', 0, false, true, 6, true, '2026-08-09 08:53:36.679913+00', false),
    ('avatar_7_scholar', 'Mezun Kum Saati', 'Graduate Hourglass', 'assets/avatars/avatar_7_scholar.png', 0, false, true, 7, true, '2026-08-09 08:53:36.679913+00', false),
    ('avatar_8_striped', 'Sevimli Kum Saati', 'Cute Hourglass', 'assets/avatars/avatar_8_striped.png', 0, false, true, 8, true, '2026-08-09 08:53:36.679913+00', false),
    ('avatar_9_viking', 'Viking Kum Saati', 'Viking Hourglass', 'assets/avatars/avatar_9_viking.png', 200, false, false, 9, true, '2026-08-09 08:53:36.679913+00', false),
    ('league_bronze_monthly', 'Bronz Lig Şampiyonu', 'Bronze League Champion', 'assets/avatars/league_bronze_monthly.png', 0, false, false, 200, true, '2026-08-12 14:10:49.694002+00', true),
    ('league_bronze_weekly', 'Bronz Lig Madalyası', 'Bronze League Medalist', 'assets/avatars/league_bronze_weekly.png', 0, false, false, 201, true, '2026-08-12 14:10:49.694002+00', true),
    ('league_diamond_monthly', 'Elmas Lig Şampiyonu', 'Diamond League Champion', 'assets/avatars/league_diamond_monthly.png', 0, false, false, 208, true, '2026-08-12 14:10:49.694002+00', true),
    ('league_diamond_weekly', 'Elmas Lig Madalyası', 'Diamond League Medalist', 'assets/avatars/league_diamond_weekly.png', 0, false, false, 209, true, '2026-08-12 14:10:49.694002+00', true),
    ('league_gold_monthly', 'Altın Lig Şampiyonu', 'Gold League Champion', 'assets/avatars/league_gold_monthly.png', 0, false, false, 204, true, '2026-08-12 14:10:49.694002+00', true),
    ('league_gold_weekly', 'Altın Lig Madalyası', 'Gold League Medalist', 'assets/avatars/league_gold_weekly.png', 0, false, false, 205, true, '2026-08-12 14:10:49.694002+00', true),
    ('league_sapphire_monthly', 'Safir Lig Şampiyonu', 'Sapphire League Champion', 'assets/avatars/league_sapphire_monthly.png', 0, false, false, 206, true, '2026-08-12 14:10:49.694002+00', true),
    ('league_sapphire_weekly', 'Safir Lig Madalyası', 'Sapphire League Medalist', 'assets/avatars/league_sapphire_weekly.png', 0, false, false, 207, true, '2026-08-12 14:10:49.694002+00', true),
    ('league_silver_monthly', 'Gümüş Lig Şampiyonu', 'Silver League Champion', 'assets/avatars/league_silver_monthly.png', 0, false, false, 202, true, '2026-08-12 14:10:49.694002+00', true),
    ('league_silver_weekly', 'Gümüş Lig Madalyası', 'Silver League Medalist', 'assets/avatars/league_silver_weekly.png', 0, false, false, 203, true, '2026-08-12 14:10:49.694002+00', true),
    ('tomato_basic', 'Domates', 'Tomato', 'assets/avatars/tomato_basic.png', 0, false, true, 17, false, '2026-08-09 08:53:36.679913+00', false);
