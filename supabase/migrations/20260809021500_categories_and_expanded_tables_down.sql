BEGIN;

-- Reverse study_sessions
ALTER TABLE public.study_sessions 
    DROP COLUMN IF EXISTS category_id,
    DROP COLUMN IF EXISTS base_points,
    DROP COLUMN IF EXISTS bonus_points,
    DROP COLUMN IF EXISTS was_paused,
    DROP COLUMN IF EXISTS is_verified,
    DROP COLUMN IF EXISTS client_uuid;

-- Reverse profiles
ALTER TABLE public.profiles 
    DROP COLUMN IF EXISTS lifetime_points,
    DROP COLUMN IF EXISTS coins,
    DROP COLUMN IF EXISTS longest_streak,
    DROP COLUMN IF EXISTS timezone;

-- Reverse categories
DROP TABLE IF EXISTS public.categories CASCADE;

COMMIT;
