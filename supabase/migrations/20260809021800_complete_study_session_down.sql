BEGIN;

-- Drop the new RPC
DROP FUNCTION IF EXISTS public.complete_study_session(uuid, uuid, integer, boolean, boolean, timestamptz);

-- Drop unique constraint
DROP INDEX IF EXISTS public.study_sessions_user_client_uuid_key;

-- Drop started_at column
ALTER TABLE public.study_sessions DROP COLUMN IF EXISTS started_at;

COMMIT;
