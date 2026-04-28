-- Add GPN sessionID + userID caching so we only ask the user for their
-- GPN password ONCE. Subsequent syncs just replay sessionID.
ALTER TABLE public.gpn_profiles
    ADD COLUMN IF NOT EXISTS gpn_user_id  text,
    ADD COLUMN IF NOT EXISTS gpn_session_id text;

-- gpn_session_id is a credential — never expose it via PostgREST to the
-- iOS client. RLS already restricts SELECT to the owner, but the safer
-- approach is to keep it server-side: the Edge Function reads it via the
-- service role and the iOS app never sees it.
COMMENT ON COLUMN public.gpn_profiles.gpn_session_id IS
    'GPN session token. Server-side only. Never expose to PostgREST clients.';
