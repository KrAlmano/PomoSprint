-- Migration: 20260809030000_avatars_and_economy_down.sql

BEGIN;

DROP FUNCTION IF EXISTS public.set_equipped_avatar(text);
DROP FUNCTION IF EXISTS public.purchase_avatar(text);

DROP TRIGGER IF EXISTS on_profile_created_give_avatars ON public.profiles;
DROP FUNCTION IF EXISTS public.give_default_avatars();

ALTER TABLE public.profiles DROP COLUMN IF EXISTS equipped_avatar_id;

DROP TABLE IF EXISTS public.avatar_unlocks;
DROP TABLE IF EXISTS public.avatars;

COMMIT;
