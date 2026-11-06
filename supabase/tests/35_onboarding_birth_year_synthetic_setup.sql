CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE ROLE service_role;
CREATE SCHEMA auth;
CREATE SCHEMA supabase_migrations;
CREATE TABLE supabase_migrations.schema_migrations(version text PRIMARY KEY, name text);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $$;
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;
CREATE TABLE public.profiles(id uuid PRIMARY KEY, birth_year integer, onboarding_completed_at timestamptz, name text NOT NULL DEFAULT 'Example', CHECK (birth_year IS NULL OR birth_year BETWEEN 1900 AND 2100));
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY owner_select ON public.profiles FOR SELECT TO authenticated USING (id=auth.uid());
CREATE POLICY owner_update ON public.profiles FOR UPDATE TO authenticated USING (id=auth.uid()) WITH CHECK (id=auth.uid());
GRANT SELECT(id,birth_year,onboarding_completed_at,name) ON public.profiles TO authenticated;
GRANT UPDATE(birth_year,onboarding_completed_at,name) ON public.profiles TO authenticated;
CREATE OR REPLACE FUNCTION public.enforce_minimum_age()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF NEW.onboarding_completed_at IS NOT NULL
       AND NEW.birth_year IS NOT NULL
       AND NEW.birth_year > extract(year FROM (now() AT TIME ZONE 'Pacific/Kiritimati'))::integer - 13 THEN
        RAISE EXCEPTION 'birth_year_under_minimum_age'
            USING ERRCODE = 'check_violation',
                  HINT = 'PomoSprint 13 yaş ve üzeri içindir (Kullanım Şartları).';
    END IF;
    RETURN NEW;
END;
$function$

;
REVOKE ALL ON FUNCTION public.enforce_minimum_age() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.enforce_minimum_age() TO service_role;
CREATE TRIGGER enforce_minimum_age BEFORE INSERT OR UPDATE OF birth_year, onboarding_completed_at ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.enforce_minimum_age();
INSERT INTO public.profiles(id,birth_year,onboarding_completed_at,name) VALUES
 ('00000000-0000-0000-0000-000000000001',NULL,NULL,'New'),
 ('00000000-0000-0000-0000-000000000002',NULL,now() - interval '1 day','Legacy'),
 ('00000000-0000-0000-0000-000000000003',2000,now() - interval '1 day','Other');
