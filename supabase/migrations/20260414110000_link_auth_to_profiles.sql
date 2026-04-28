-- =============================================================
-- DinkLink: Link auth.users → user_profiles
-- Date: 2026-04-14
-- 
-- 1. Creates handle_new_user() trigger function that auto-inserts
--    a user_profiles stub row whenever a new auth.users row is added.
-- 2. Backfills the 3 existing auth users who signed up before
--    user_profiles existed.
-- =============================================================

-- ── 1. Trigger function ──────────────────────────────────────
-- Runs as SECURITY DEFINER (postgres role) so it can write to
-- public.user_profiles even before the user has an active session.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.user_profiles (
        user_id,
        display_name,
        total_xp,
        current_streak,
        longest_streak,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
        0,
        0,
        0,
        now(),
        now()
    )
    ON CONFLICT (user_id) DO NOTHING;  -- idempotent: safe to run multiple times
    RETURN NEW;
END;
$$;

-- ── 2. Attach trigger to auth.users ──────────────────────────
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ── 3. Backfill existing auth users ──────────────────────────
-- Inserts a user_profiles row for any auth.users row that doesn't
-- already have one. Uses the same defaults as the trigger.
INSERT INTO public.user_profiles (
    user_id,
    display_name,
    total_xp,
    current_streak,
    longest_streak,
    created_at,
    updated_at
)
SELECT
    au.id,
    COALESCE(au.raw_user_meta_data->>'display_name', split_part(au.email, '@', 1)),
    0,
    0,
    0,
    COALESCE(au.created_at, now()),
    now()
FROM auth.users au
WHERE NOT EXISTS (
    SELECT 1 FROM public.user_profiles up WHERE up.user_id = au.id
);
