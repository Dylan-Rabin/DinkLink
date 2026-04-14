-- Add home_city and paddle_name to user_profiles so returning users
-- can restore their profile on a new device without re-entering details.

ALTER TABLE public.user_profiles
    ADD COLUMN IF NOT EXISTS home_city   text NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS paddle_name text NOT NULL DEFAULT '';
