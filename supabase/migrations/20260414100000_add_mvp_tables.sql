-- =============================================================
-- DinkLink MVP Migration — Add missing remote tables
-- Date: 2026-04-14
-- Adds: user_profiles, game_sessions, shot_events,
--       saved_locations, badges, user_badges
-- Keeps: comments, comment_likes, xp_events, user_progression
--        (user_progression will be removed in a future cutover migration)
-- =============================================================


-- ── user_profiles ────────────────────────────────────────────
-- Replaces user_progression (still kept for backward-compat during cutover).
-- XP, streaks, and GPN data all live here. Level/rank resolved in Swift.
CREATE TABLE IF NOT EXISTS public.user_profiles (
    user_id            uuid         PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name       text         NOT NULL DEFAULT '',
    avatar_url         text,
    total_xp           int          NOT NULL DEFAULT 0,
    xp_updated_at      timestamptz,
    current_streak     int          NOT NULL DEFAULT 0,
    longest_streak     int          NOT NULL DEFAULT 0,
    last_active_date   date,
    gpn_username       text,
    gpn_profile_url    text,
    gpn_singles_level  numeric(4,2),
    gpn_doubles_level  numeric(4,2),
    gpn_dupr_rating    numeric(4,2),
    gpn_last_synced_at timestamptz,
    created_at         timestamptz  NOT NULL DEFAULT now(),
    updated_at         timestamptz  NOT NULL DEFAULT now()
);

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Users can read/write only their own profile
CREATE POLICY "user_profiles: owner access"
    ON public.user_profiles
    FOR ALL
    USING  (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);


-- ── game_sessions ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.game_sessions (
    id                    uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id               uuid         NOT NULL REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
    mode                  text         NOT NULL,
    start_date            timestamptz  NOT NULL,
    end_date              timestamptz  NOT NULL,
    player_one_name       text         NOT NULL,
    player_two_name       text         NOT NULL DEFAULT 'Solo',
    player_one_score      int          NOT NULL DEFAULT 0,
    player_two_score      int          NOT NULL DEFAULT 0,
    average_swing_speed   float8       NOT NULL DEFAULT 0,
    max_swing_speed       float8       NOT NULL DEFAULT 0,
    sweet_spot_percentage float8       NOT NULL DEFAULT 0,
    total_hits            int          NOT NULL DEFAULT 0,
    winner_name           text         NOT NULL DEFAULT '',
    longest_streak        int          NOT NULL DEFAULT 0,
    total_valid_volleys   int          NOT NULL DEFAULT 0,
    best_rally_length     int          NOT NULL DEFAULT 0,
    is_challenge          boolean      NOT NULL DEFAULT false,
    is_pickle_cup_win     boolean      NOT NULL DEFAULT false,
    created_at            timestamptz  NOT NULL DEFAULT now()
);

ALTER TABLE public.game_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "game_sessions: owner access"
    ON public.game_sessions
    FOR ALL
    USING  (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);


-- ── shot_events ───────────────────────────────────────────────
-- Individual BLE paddle-hit events recorded per session.
CREATE TABLE IF NOT EXISTS public.shot_events (
    id             uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id     uuid         NOT NULL REFERENCES public.game_sessions(id) ON DELETE CASCADE,
    user_id        uuid         NOT NULL REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
    timestamp      timestamptz  NOT NULL,
    speed_mph      float8       NOT NULL,
    hit_sweet_spot boolean      NOT NULL,
    spin_rpm       float8       NOT NULL DEFAULT 0,
    created_at     timestamptz  NOT NULL DEFAULT now()
);

ALTER TABLE public.shot_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "shot_events: owner access"
    ON public.shot_events
    FOR ALL
    USING  (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);


-- ── saved_locations ───────────────────────────────────────────
-- User's saved courts / home location. Replaces freetext locationName.
CREATE TABLE IF NOT EXISTS public.saved_locations (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid        NOT NULL REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
    label       text        NOT NULL,
    place_name  text        NOT NULL,
    address     text,
    latitude    float8,
    longitude   float8,
    is_home     boolean     NOT NULL DEFAULT false,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- Only one home location per user
CREATE UNIQUE INDEX IF NOT EXISTS saved_locations_one_home_per_user
    ON public.saved_locations (user_id)
    WHERE is_home = true;

ALTER TABLE public.saved_locations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "saved_locations: owner access"
    ON public.saved_locations
    FOR ALL
    USING  (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);


-- ── badges ────────────────────────────────────────────────────
-- Badge catalog — app reads the full list to show locked/unlocked state.
CREATE TABLE IF NOT EXISTS public.badges (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    key         text        NOT NULL UNIQUE,
    name        text        NOT NULL,
    description text        NOT NULL,
    icon_url    text        NOT NULL DEFAULT '',
    badge_type  text        NOT NULL CHECK (badge_type IN ('achievement','milestone','tournament','level')),
    xp_reward   int         NOT NULL DEFAULT 0,
    is_hidden   boolean     NOT NULL DEFAULT false,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- All authenticated users can read the badge catalog
ALTER TABLE public.badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "badges: authenticated read"
    ON public.badges
    FOR SELECT
    USING (auth.role() = 'authenticated');


-- ── user_badges ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.user_badges (
    id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    uuid        NOT NULL REFERENCES public.user_profiles(user_id) ON DELETE CASCADE,
    badge_id   uuid        NOT NULL REFERENCES public.badges(id) ON DELETE CASCADE,
    awarded_at timestamptz NOT NULL DEFAULT now(),
    source     text,
    session_id uuid        REFERENCES public.game_sessions(id) ON DELETE SET NULL,
    UNIQUE (user_id, badge_id)
);

ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_badges: owner read"
    ON public.user_badges
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "user_badges: service insert"
    ON public.user_badges
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);
