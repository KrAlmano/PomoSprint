-- 20261009190000_special_avatar_catalog
-- Reviewed against live read-only catalog on 9 October 2026.
-- Manifest: assets/avatars/special_catalog.json (22 rows, 500 sand grains each).
-- No schema/RPC/ACL/registration-default changes; special_ is a client category.
-- NOT APPLIED LIVE. First run matching dryrun in SQL Editor, then this file.
-- Requires the reviewed old catalog and five exact existing function bodies.
-- Rollback refuses after any of these avatars is acquired or equipped.
BEGIN;
LOCK TABLE public.avatars IN ACCESS EXCLUSIVE MODE;
DO $guard$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version = '20261009190000' AND name = 'special_avatar_catalog') THEN
    RAISE EXCEPTION 'special avatars rollback: matching package is not installed';
  END IF;
  IF EXISTS (SELECT 1 FROM public.avatar_unlocks WHERE avatar_id IN (
    'special_gold_miner',
    'special_vampire_lord',
    'special_detective',
    'special_cowboy',
    'special_steampunk_pilot',
    'special_pharaoh',
    'special_zen_master',
    'special_desert_princess',
    'special_forest_fairy',
    'special_star_wizard',
    'special_shadow_queen',
    'special_astronaut',
    'special_crystal_princess',
    'special_ronin',
    'special_potion_master',
    'special_archaeologist',
    'special_cyber_robot',
    'special_flame_spirit',
    'special_light_knight',
    'special_pirate_captain',
    'special_celestial_king',
    'special_samurai'
  )) OR EXISTS (SELECT 1 FROM public.profiles WHERE avatar_id IN (
    'special_gold_miner',
    'special_vampire_lord',
    'special_detective',
    'special_cowboy',
    'special_steampunk_pilot',
    'special_pharaoh',
    'special_zen_master',
    'special_desert_princess',
    'special_forest_fairy',
    'special_star_wizard',
    'special_shadow_queen',
    'special_astronaut',
    'special_crystal_princess',
    'special_ronin',
    'special_potion_master',
    'special_archaeologist',
    'special_cyber_robot',
    'special_flame_spirit',
    'special_light_knight',
    'special_pirate_captain',
    'special_celestial_king',
    'special_samurai'
  )) THEN
    RAISE EXCEPTION 'special avatars rollback refused: an avatar is owned or equipped; preserve user data and deactivate via a reviewed follow-up instead';
  END IF;
  IF (SELECT count(*) FROM public.avatars WHERE id IN (
    'special_gold_miner',
    'special_vampire_lord',
    'special_detective',
    'special_cowboy',
    'special_steampunk_pilot',
    'special_pharaoh',
    'special_zen_master',
    'special_desert_princess',
    'special_forest_fairy',
    'special_star_wizard',
    'special_shadow_queen',
    'special_astronaut',
    'special_crystal_princess',
    'special_ronin',
    'special_potion_master',
    'special_archaeologist',
    'special_cyber_robot',
    'special_flame_spirit',
    'special_light_knight',
    'special_pirate_captain',
    'special_celestial_king',
    'special_samurai'
  )) <> 22 OR EXISTS (
    SELECT 1 FROM public.avatars a
    JOIN (VALUES
  ('special_gold_miner', 'Altın Madencisi', 'Gold Miner', 'assets/avatars/special_gold_miner.png', 500, false, false, 300, true, false),
  ('special_vampire_lord', 'Vampir Lordu', 'Vampire Lord', 'assets/avatars/special_vampire_lord.png', 500, false, false, 301, true, false),
  ('special_detective', 'Dedektif', 'Detective', 'assets/avatars/special_detective.png', 500, false, false, 302, true, false),
  ('special_cowboy', 'Kovboy', 'Cowboy', 'assets/avatars/special_cowboy.png', 500, false, false, 303, true, false),
  ('special_steampunk_pilot', 'Buhar Pilotu', 'Steampunk Pilot', 'assets/avatars/special_steampunk_pilot.png', 500, false, false, 304, true, false),
  ('special_pharaoh', 'Firavun', 'Pharaoh', 'assets/avatars/special_pharaoh.png', 500, false, false, 305, true, false),
  ('special_zen_master', 'Zen Ustası', 'Zen Master', 'assets/avatars/special_zen_master.png', 500, false, false, 306, true, false),
  ('special_desert_princess', 'Çöl Prensesi', 'Desert Princess', 'assets/avatars/special_desert_princess.png', 500, false, false, 307, true, false),
  ('special_forest_fairy', 'Orman Perisi', 'Forest Fairy', 'assets/avatars/special_forest_fairy.png', 500, false, false, 308, true, false),
  ('special_star_wizard', 'Yıldız Büyücüsü', 'Star Wizard', 'assets/avatars/special_star_wizard.png', 500, false, false, 309, true, false),
  ('special_shadow_queen', 'Gölge Kraliçesi', 'Shadow Queen', 'assets/avatars/special_shadow_queen.png', 500, false, false, 310, true, false),
  ('special_astronaut', 'Astronot', 'Astronaut', 'assets/avatars/special_astronaut.png', 500, false, false, 311, true, false),
  ('special_crystal_princess', 'Kristal Prenses', 'Crystal Princess', 'assets/avatars/special_crystal_princess.png', 500, false, false, 312, true, false),
  ('special_ronin', 'Ronin', 'Ronin', 'assets/avatars/special_ronin.png', 500, false, false, 313, true, false),
  ('special_potion_master', 'İksir Ustası', 'Potion Master', 'assets/avatars/special_potion_master.png', 500, false, false, 314, true, false),
  ('special_archaeologist', 'Arkeolog', 'Archaeologist', 'assets/avatars/special_archaeologist.png', 500, false, false, 315, true, false),
  ('special_cyber_robot', 'Siber Robot', 'Cyber Robot', 'assets/avatars/special_cyber_robot.png', 500, false, false, 316, true, false),
  ('special_flame_spirit', 'Alev Ruhu', 'Flame Spirit', 'assets/avatars/special_flame_spirit.png', 500, false, false, 317, true, false),
  ('special_light_knight', 'Işık Şövalyesi', 'Light Knight', 'assets/avatars/special_light_knight.png', 500, false, false, 318, true, false),
  ('special_pirate_captain', 'Korsan Kaptan', 'Pirate Captain', 'assets/avatars/special_pirate_captain.png', 500, false, false, 319, true, false),
  ('special_celestial_king', 'Gökyüzü Kralı', 'Celestial King', 'assets/avatars/special_celestial_king.png', 500, false, false, 320, true, false),
  ('special_samurai', 'Samuray', 'Samurai', 'assets/avatars/special_samurai.png', 500, false, false, 321, true, false)
    ) AS e(id, name_tr, name_en, asset_key, cost_coins, is_premium_only, is_default, sort_order, is_active, is_league_award) USING (id)
    WHERE ROW(a.name_tr,a.name_en,a.asset_key,a.cost_coins,a.is_premium_only,a.is_default,a.sort_order,a.is_active,a.is_league_award)
      IS DISTINCT FROM ROW(e.name_tr,e.name_en,e.asset_key,e.cost_coins,e.is_premium_only,e.is_default,e.sort_order,e.is_active,e.is_league_award)
  ) THEN
    RAISE EXCEPTION 'special avatars rollback: catalog rows changed; review before removing';
  END IF;
END $guard$;
DELETE FROM public.avatars WHERE id IN (
    'special_gold_miner',
    'special_vampire_lord',
    'special_detective',
    'special_cowboy',
    'special_steampunk_pilot',
    'special_pharaoh',
    'special_zen_master',
    'special_desert_princess',
    'special_forest_fairy',
    'special_star_wizard',
    'special_shadow_queen',
    'special_astronaut',
    'special_crystal_princess',
    'special_ronin',
    'special_potion_master',
    'special_archaeologist',
    'special_cyber_robot',
    'special_flame_spirit',
    'special_light_knight',
    'special_pirate_captain',
    'special_celestial_king',
    'special_samurai'
);
DELETE FROM supabase_migrations.schema_migrations WHERE version = '20261009190000' AND name = 'special_avatar_catalog';
NOTIFY pgrst, 'reload schema';
COMMIT;
