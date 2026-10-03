BEGIN;

-- A) CREATE categories table
CREATE TABLE IF NOT EXISTS public.categories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name text NOT NULL,
    color_hex text NOT NULL,
    icon_name text,
    sort_order integer NOT NULL DEFAULT 0,
    is_archived boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- Note: user_id + name must be unique only among active categories
CREATE INDEX IF NOT EXISTS categories_user_id_is_archived_idx ON public.categories (user_id, is_archived);
CREATE UNIQUE INDEX IF NOT EXISTS categories_user_id_name_key ON public.categories (user_id, name) WHERE is_archived = false;

-- RLS for categories
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Categories select policy" 
ON public.categories FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Categories insert policy" 
ON public.categories FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Categories update policy" 
ON public.categories FOR UPDATE 
USING (auth.uid() = user_id);

CREATE POLICY "Categories delete policy" 
ON public.categories FOR DELETE 
USING (auth.uid() = user_id);

-- Link study_sessions to categories
ALTER TABLE public.study_sessions ADD COLUMN IF NOT EXISTS category_id uuid REFERENCES public.categories(id) ON DELETE SET NULL;

-- B) Add columns to profiles
ALTER TABLE public.profiles 
    ADD COLUMN IF NOT EXISTS lifetime_points integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS coins integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS longest_streak integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS timezone text NOT NULL DEFAULT 'Europe/Istanbul';

-- Copy existing points to lifetime_points and coins
UPDATE public.profiles SET 
    lifetime_points = COALESCE(points, 0), 
    coins = COALESCE(points, 0);

-- C) Add columns to study_sessions
-- (duration_minutes already exists as NOT NULL, skipping it)
ALTER TABLE public.study_sessions 
    ADD COLUMN IF NOT EXISTS base_points integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS bonus_points integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS was_paused boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS is_verified boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS client_uuid uuid;

-- Data Migration: Read JSONB and insert into categories
-- color in JSONB is integer ARGB (e.g., 4293870660 for #FFFF4444)
-- lpad(to_hex(...), 8, '0') will return ffff4444
INSERT INTO public.categories (id, user_id, name, color_hex, icon_name, sort_order)
SELECT 
    (cat->>'id')::uuid,
    p.id as user_id,
    cat->>'name' as name,
    '#' || UPPER(lpad(to_hex((cat->>'color')::bigint), 8, '0')) as color_hex,
    (cat->>'icon') as icon_name,
    row_number() over (partition by p.id) as sort_order
FROM public.profiles p,
     jsonb_array_elements(p.categories) as cat
WHERE p.categories IS NOT NULL
ON CONFLICT DO NOTHING;

-- Link existing study_sessions to the newly created categories based on name
UPDATE public.study_sessions ss
SET category_id = c.id
FROM public.categories c
WHERE ss.user_id = c.user_id AND ss.category = c.name;

COMMIT;
