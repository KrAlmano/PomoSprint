-- Migration: 20260809030000_avatars_and_economy_up.sql

BEGIN;

-- ====================================================================
-- 1. YENİ TABLO: avatars (Katalog)
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.avatars (
    id text PRIMARY KEY,
    name_tr text NOT NULL,
    name_en text NOT NULL,
    asset_key text NOT NULL,
    cost_coins integer NOT NULL DEFAULT 0,
    is_premium_only boolean NOT NULL DEFAULT false,
    is_default boolean NOT NULL DEFAULT false,
    sort_order integer NOT NULL DEFAULT 0,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.avatars ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Avatars are viewable by authenticated users" 
ON public.avatars FOR SELECT TO authenticated USING (true);
-- INSERT/UPDATE/DELETE sadece admin veya yetkililere bırakılıyor.

-- ====================================================================
-- 2. VERİ EKLEME (Mevcut Sabit Avatarlar)
-- ====================================================================
INSERT INTO public.avatars (id, name_tr, name_en, asset_key, cost_coins, is_premium_only, is_default, sort_order) VALUES
('avatar_1_gamer', 'Oyuncu Kum Saati', 'Gamer Hourglass', 'assets/avatars/avatar_1_gamer.png', 200, false, false, 1),
('avatar_2_glasses', 'Gözlüklü Kum Saati', 'Glasses Hourglass', 'assets/avatars/avatar_2_glasses.png', 0, false, true, 2),
('avatar_3_gentleman', 'Centilmen Kum Saati', 'Gentleman Hourglass', 'assets/avatars/avatar_3_gentleman.png', 0, false, true, 3),
('avatar_4_bowtie', 'Hakim Kum Saati', 'Judge Hourglass', 'assets/avatars/avatar_4_bowtie.png', 200, false, false, 4),
('avatar_5_flower', 'Çiçekli Kum Saati', 'Flower Hourglass', 'assets/avatars/avatar_5_flower.png', 0, false, true, 5),
('avatar_6_cool', 'Süslü Kum Saati', 'Glam Hourglass', 'assets/avatars/avatar_6_cool.png', 0, false, true, 6),
('avatar_7_scholar', 'Mezun Kum Saati', 'Graduate Hourglass', 'assets/avatars/avatar_7_scholar.png', 0, false, true, 7),
('avatar_8_striped', 'Sevimli Kum Saati', 'Cute Hourglass', 'assets/avatars/avatar_8_striped.png', 0, false, true, 8),
('avatar_9_viking', 'Viking Kum Saati', 'Viking Hourglass', 'assets/avatars/avatar_9_viking.png', 200, false, false, 9),
('avatar_10_dentist', 'Dişçi Kum Saati', 'Dentist Hourglass', 'assets/avatars/avatar_10_dentist.png', 200, false, false, 10),
('avatar_11_doctor', 'Doktor Kum Saati', 'Doctor Hourglass', 'assets/avatars/avatar_11_doctor.png', 0, true, false, 11),
('avatar_12_builder', 'Mimar Kum Saati', 'Architect Hourglass', 'assets/avatars/avatar_12_builder.png', 0, true, false, 12),
('avatar_13_pilot', 'Pilot Kum Saati', 'Pilot Hourglass', 'assets/avatars/avatar_13_pilot.png', 0, true, false, 13),
('avatar_14_teacher', 'Öğretmen Kum Saati', 'Teacher Hourglass', 'assets/avatars/avatar_14_teacher.png', 0, true, false, 14),
('avatar_15_athlete', 'Sporcu Kum Saati', 'Athlete Hourglass', 'assets/avatars/avatar_15_athlete.png', 0, true, false, 15),
('avatar_16_basic', 'Klasik Kum Saati', 'Classic Hourglass', 'assets/avatars/avatar_16_basic.png', 0, false, true, 16),
('tomato_basic', 'Domates', 'Tomato', 'assets/avatars/tomato_basic.png', 0, false, true, 17)
ON CONFLICT (id) DO UPDATE SET 
    name_tr = EXCLUDED.name_tr,
    name_en = EXCLUDED.name_en,
    cost_coins = EXCLUDED.cost_coins,
    is_premium_only = EXCLUDED.is_premium_only,
    is_default = EXCLUDED.is_default;

-- ====================================================================
-- 3. YENİ TABLO: avatar_unlocks
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.avatar_unlocks (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    avatar_id text NOT NULL REFERENCES public.avatars(id),
    unlock_type text NOT NULL CHECK (unlock_type IN ('coins', 'premium', 'default')),
    coins_spent integer NOT NULL DEFAULT 0,
    unlocked_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, avatar_id)
);

CREATE INDEX IF NOT EXISTS idx_avatar_unlocks_user_id ON public.avatar_unlocks(user_id);

-- RLS
ALTER TABLE public.avatar_unlocks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view their own unlocked avatars" 
ON public.avatar_unlocks FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- ====================================================================
-- 4. PROFILES TABLOSUNU GÜNCELLEME VE VERİ TAŞIMA
-- ====================================================================
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS equipped_avatar_id text REFERENCES public.avatars(id);

-- Eski 'unlocked_avatars' array verisini 'avatar_unlocks' tablosuna taşı
DO $$
DECLARE
    r record;
    u_avatar text;
    v_type text;
BEGIN
    FOR r IN SELECT id, unlocked_avatars FROM public.profiles WHERE unlocked_avatars IS NOT NULL AND array_length(unlocked_avatars, 1) > 0
    LOOP
        FOR u_avatar IN SELECT * FROM unnest(r.unlocked_avatars)
        LOOP
            IF EXISTS (SELECT 1 FROM public.avatars WHERE id = u_avatar) THEN
                -- Varsayılan açma türünü belirt
                SELECT CASE 
                    WHEN is_premium_only THEN 'premium'
                    WHEN is_default THEN 'default'
                    ELSE 'coins'
                END INTO v_type FROM public.avatars WHERE id = u_avatar;

                INSERT INTO public.avatar_unlocks (user_id, avatar_id, unlock_type, coins_spent)
                VALUES (r.id, u_avatar, v_type, 0)
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;
    END LOOP;
END
$$;

-- Mevcut seçili 'avatar_id' verisini 'equipped_avatar_id' ye kopyala
UPDATE public.profiles p
SET equipped_avatar_id = p.avatar_id
WHERE p.avatar_id IN (SELECT id FROM public.avatars);

-- Varsayılanları atamamış (veya migration öncesi) herkese is_default = true avatarları aç
INSERT INTO public.avatar_unlocks (user_id, avatar_id, unlock_type, coins_spent)
SELECT p.id, a.id, 'default', 0
FROM public.profiles p
CROSS JOIN public.avatars a
WHERE a.is_default = true
ON CONFLICT DO NOTHING;

-- Yeni kullanıcılar için bir trigger oluşturarak is_default avatarları otomatik ver
CREATE OR REPLACE FUNCTION public.give_default_avatars()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.avatar_unlocks (user_id, avatar_id, unlock_type, coins_spent)
    SELECT NEW.id, a.id, 'default', 0
    FROM public.avatars a
    WHERE a.is_default = true;

    -- Eğer kullanıcıya avatar atanmamışsa ilk default avatarı ata
    IF NEW.equipped_avatar_id IS NULL THEN
        NEW.equipped_avatar_id := 'avatar_2_glasses';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop if exists just in case
DROP TRIGGER IF EXISTS on_profile_created_give_avatars ON public.profiles;
CREATE TRIGGER on_profile_created_give_avatars
AFTER INSERT ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.give_default_avatars();

-- ====================================================================
-- 5. RPC: purchase_avatar
-- ====================================================================
CREATE OR REPLACE FUNCTION public.purchase_avatar(p_avatar_id text)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid;
    v_avatar record;
    v_is_premium boolean;
    v_user_coins integer;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Avatar var mı?
    SELECT * INTO v_avatar FROM public.avatars WHERE id = p_avatar_id AND is_active = true;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Avatar bulunamadı veya pasif durumda.';
    END IF;

    -- Kullanıcıda zaten var mı? Varsa sessizce başarılı dön (cüzdan döner)
    IF EXISTS (SELECT 1 FROM public.avatar_unlocks WHERE user_id = v_uid AND avatar_id = p_avatar_id) THEN
        SELECT coins INTO v_user_coins FROM public.profiles WHERE id = v_uid;
        RETURN v_user_coins;
    END IF;

    -- Kullanıcının bakiyesi ve premium durumunu al
    SELECT is_premium, coins INTO v_is_premium, v_user_coins FROM public.profiles WHERE id = v_uid;

    -- Premium kontrolü
    IF v_avatar.is_premium_only THEN
        IF NOT v_is_premium THEN
            RAISE EXCEPTION 'Bu avatar sadece Premium kullanıcılar içindir.';
        END IF;
        
        -- Premium avatarlar bedavadır (jeton düşme)
        INSERT INTO public.avatar_unlocks (user_id, avatar_id, unlock_type, coins_spent)
        VALUES (v_uid, p_avatar_id, 'premium', 0);
        
        RETURN v_user_coins;
    END IF;

    -- Jeton bakiyesi kontrolü
    IF v_user_coins < v_avatar.cost_coins THEN
        RAISE EXCEPTION 'Yetersiz bakiye. Bu avatar için % kum tanesi gerekiyor, senin % kum tanen var.', v_avatar.cost_coins, v_user_coins;
    END IF;

    -- Transaction (Tek blok)
    v_user_coins := v_user_coins - v_avatar.cost_coins;

    UPDATE public.profiles 
    SET coins = v_user_coins 
    WHERE id = v_uid;

    INSERT INTO public.avatar_unlocks (user_id, avatar_id, unlock_type, coins_spent)
    VALUES (v_uid, p_avatar_id, 'coins', v_avatar.cost_coins);

    RETURN v_user_coins;
END;
$$;

-- ====================================================================
-- 6. RPC: set_equipped_avatar
-- ====================================================================
CREATE OR REPLACE FUNCTION public.set_equipped_avatar(p_avatar_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid uuid;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Kullanıcı bu avatarı açmış mı?
    IF NOT EXISTS (SELECT 1 FROM public.avatar_unlocks WHERE user_id = v_uid AND avatar_id = p_avatar_id) THEN
        RAISE EXCEPTION 'Bu avatar kilitli.';
    END IF;

    UPDATE public.profiles 
    SET equipped_avatar_id = p_avatar_id, avatar_id = p_avatar_id
    WHERE id = v_uid;

    RETURN true;
END;
$$;

COMMIT;
