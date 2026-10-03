-- Fix profiles permissions and RLS
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO anon;

-- Ensure RLS is enabled
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.profiles;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON public.profiles;
DROP POLICY IF EXISTS "Enable update for users based on email" ON public.profiles;

-- Create policies for profiles
-- 1. Users can view their own profile, or maybe we want users to view all profiles for rankings
CREATE POLICY "Enable read access for all users" ON public.profiles
    FOR SELECT USING (true);

-- 2. Users can insert their own profile
CREATE POLICY "Users can insert own profile" ON public.profiles
    FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = id);

-- 3. Users can update their own profile
CREATE POLICY "Users can update own profile" ON public.profiles
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = id);

-- If someone drops the sequence or grants, make sure service_role has access
GRANT ALL PRIVILEGES ON TABLE public.profiles TO service_role;
