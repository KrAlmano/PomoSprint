DROP FUNCTION IF EXISTS public.setup_onboarding_categories(jsonb);
DROP FUNCTION IF EXISTS public.create_category(text, text, text);

ALTER TABLE public.profiles DROP COLUMN IF EXISTS user_segment;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS daily_goal_minutes;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS birth_year;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS onboarding_completed_at;
