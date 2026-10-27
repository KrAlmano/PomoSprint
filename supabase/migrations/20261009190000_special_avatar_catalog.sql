-- 20261009190000_special_avatar_catalog
-- Reviewed against live read-only catalog on 9 October 2026.
-- Manifest: assets/avatars/special_catalog.json (22 rows, 500 sand grains each).
-- No schema/RPC/ACL/registration-default changes; special_ is a client category.
-- NOT APPLIED LIVE. First run matching dryrun in SQL Editor, then this file.
-- Requires the reviewed old catalog and five exact existing function bodies.
-- Rollback refuses after any of these avatars is acquired or equipped.
BEGIN;

-- Catalog rows only: existing profiles, unlocks, rewards and RPCs are untouched.
LOCK TABLE public.avatars IN SHARE ROW EXCLUSIVE MODE;
DO $pre$
DECLARE
  expected constant jsonb := '{"give_default_avatars()": "bb36a4f2baa93af319c5f4e0ec3fe74f", "handle_new_user()": "ec0287158fd80a2c19bc1cdcf90a22ac", "purchase_avatar(text)": "38689aed887865e04bc6c23db8daeb32", "sanitize_profile_insert()": "41dfb7b4d7ac5fba873263b9373c3af3", "set_equipped_avatar(text)": "5a3e3e513a9fbf41619f842cdffc8a96"}'::jsonb;
  item record;
BEGIN
  IF EXISTS (SELECT 1 FROM supabase_migrations.schema_migrations WHERE version = '20261009190000') THEN
    RAISE EXCEPTION 'special avatars: package already installed; do not reapply';
  END IF;
  FOR item IN SELECT key, value FROM jsonb_each_text(expected) LOOP
    IF to_regprocedure('public.' || item.key) IS NULL OR
       md5(pg_get_functiondef(to_regprocedure('public.' || item.key))) IS DISTINCT FROM item.value THEN
      RAISE EXCEPTION 'special avatars: live function changed: %; review fresh definition', item.key;
    END IF;
  END LOOP;
  IF (SELECT md5(coalesce(jsonb_agg(to_jsonb(a) ORDER BY id), '[]'::jsonb)::text)
      FROM public.avatars a) IS DISTINCT FROM '7fe6c00afaba5f7f957540a10f3674bd' THEN
    RAISE EXCEPTION 'special avatars: existing catalog changed; review fresh catalog';
  END IF;
  IF EXISTS (SELECT 1 FROM public.avatars WHERE id IN (
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
    RAISE EXCEPTION 'special avatars: reserved ID already exists';
  END IF;
END $pre$;

INSERT INTO public.avatars (id, name_tr, name_en, asset_key, cost_coins, is_premium_only, is_default, sort_order, is_active, is_league_award) VALUES
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
  ('special_samurai', 'Samuray', 'Samurai', 'assets/avatars/special_samurai.png', 500, false, false, 321, true, false);

INSERT INTO supabase_migrations.schema_migrations (version, name)
VALUES ('20261009190000', 'special_avatar_catalog');
NOTIFY pgrst, 'reload schema';

COMMIT;
