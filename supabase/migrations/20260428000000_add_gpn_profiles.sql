-- GPN (Global Pickleball Network) profile cache.
-- One row per authenticated user. Populated exclusively by the
-- sync-gpn-profile Edge Function — the app never writes here directly.
-- Credentials are never stored; only the output of the GPN API calls.

CREATE TABLE IF NOT EXISTS public.gpn_profiles (
    -- PK is the Supabase auth user id (1:1 with auth.users)
    user_id         uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

    -- GPN identity
    gpn_username    text        NOT NULL,
    gpn_display_name text,
    gpn_avatar_url  text,
    gpn_profile_url text,
    gpn_location    text,

    -- Skill levels from /api/user/calculated-levels  (e.g. 3.50)
    singles_level   numeric(4,2),
    doubles_level   numeric(4,2),
    overall_level   numeric(4,2),

    -- DUPR rating from /api/user/stats (e.g. 4.125)
    dupr_rating     numeric(5,3),

    -- Match statistics from /api/user/stats
    total_matches   integer     NOT NULL DEFAULT 0,
    wins            integer     NOT NULL DEFAULT 0,
    losses          integer     NOT NULL DEFAULT 0,
    win_percentage  numeric(5,2),

    -- Sync metadata
    last_synced_at  timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

-- Keep updated_at current automatically
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_gpn_profiles_updated_at ON public.gpn_profiles;
CREATE TRIGGER set_gpn_profiles_updated_at
    BEFORE UPDATE ON public.gpn_profiles
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Row Level Security: each user can only see and modify their own row.
ALTER TABLE public.gpn_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "gpn_profiles_select_own"
    ON public.gpn_profiles FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "gpn_profiles_insert_own"
    ON public.gpn_profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "gpn_profiles_update_own"
    ON public.gpn_profiles FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "gpn_profiles_delete_own"
    ON public.gpn_profiles FOR DELETE
    USING (auth.uid() = user_id);

-- Mirror gpn_username back onto user_profiles for quick access without a join.
-- The Edge Function writes gpn_profiles first; this trigger keeps user_profiles in sync.
CREATE OR REPLACE FUNCTION public.sync_gpn_username_to_profile()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    UPDATE public.user_profiles
    SET    gpn_username = NEW.gpn_username
    WHERE  user_id = NEW.user_id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_gpn_username ON public.gpn_profiles;
CREATE TRIGGER sync_gpn_username
    AFTER INSERT OR UPDATE OF gpn_username ON public.gpn_profiles
    FOR EACH ROW EXECUTE FUNCTION public.sync_gpn_username_to_profile();
