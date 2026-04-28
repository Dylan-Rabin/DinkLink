# DinkLink Database Reference
**Version:** Option A + MVP (13 tables) — April 13, 2026
**Backend:** Supabase (PostgreSQL) + SwiftData (on-device)
**App:** iOS pickleball paddle tracking app

---

## Quick Reference

| Question | Answer |
|---|---|
| Auth system | Supabase Auth (email/password) |
| User identity | `auth.users.id` (UUID) |
| On-device store | SwiftData (4 models) |
| Remote store | Supabase REST API (9 custom tables) |
| Offline writes | Queued in `SyncQueueItem`, drained when online |
| XP/level logic | `total_xp` on `user_profiles`; tier thresholds in Swift code |
| Streak tracking | `current_streak`, `longest_streak`, `last_active_date` on `user_profiles` |
| GPN integration | Supabase Edge Function `sync-gpn-profile` via real GPN OAuth API |
| Supabase URL | `https://nrygqwhhzizplpgnxvzk.supabase.co` |
| REST base | `https://nrygqwhhzizplpgnxvzk.supabase.co/rest/v1` |

---

## Architecture Overview

```
iOS App
  │
  ├── SwiftData (always — never bypassed)
  │     PlayerProfile, StoredGameSession, SavedLocation, SyncQueueItem
  │
  └── SyncService (when online)
        │
        └── Supabase REST API
              user_profiles, game_sessions, shot_events, saved_locations,
              badges, user_badges, xp_events, comments, comment_likes
```

**Write rule:** Every write hits SwiftData first. The UI never waits for network.
**Read rule:** App reads from SwiftData. Remote data is pulled down on launch and merged in.
**Offline rule:** Any failed remote write is stored in `SyncQueueItem` and replayed when connectivity returns.

---

## Tables

### LOCAL (SwiftData — on-device)

---

#### `PlayerProfile`
The single on-device user profile. One record per device.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK, unique |
| `name` | String | Display name |
| `locationName` | String | Legacy freetext location. Replaced by `SavedLocation.isHome` in Phase 3 |
| `dominantArmRawValue` | String | `Right` \| `Left` \| `Ambidextrous` |
| `skillLevelRawValue` | String | `Beginner` \| `Intermediate` \| `Advanced` \| `Tournament` |
| `syncedPaddleName` | String | Last BLE-connected paddle name |
| `completedOnboarding` | Bool | True once onboarding complete |
| `supabaseProfileSynced` | Bool | True once pushed to Supabase |
| `gpnUsername` | String? | GPN handle, mirrors `user_profiles.gpn_username`. Used with GPN OAuth API |
| `homeLocationLabel` | String? | Cache of home `SavedLocation.label` |
| `currentStreak` | Int | **NEW (MVP).** Consecutive daily-play streak. Incremented when `lastActiveDate` was yesterday |
| `longestStreak` | Int | **NEW (MVP).** All-time best consecutive streak |
| `lastActiveDate` | Date? | **NEW (MVP).** Last calendar day a session was completed. Used for streak calculation |

**Relationships:**
- Syncs to → `user_profiles` (remote, 1:1)
- Has many → `SavedLocation` (local)
- Has many → `StoredGameSession` (local, by user context)

---

#### `StoredGameSession`
One record per completed game session. Source of truth for all session history.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK — same value used as `game_sessions.id` in Supabase |
| `modeRawValue` | String | `Dink Sinks` \| `Volley Wallies` \| `The Real Deal` \| `Pickle Cup` |
| `startDate` | Date | UTC |
| `endDate` | Date | UTC — used for sort order |
| `playerOneName` | String | |
| `playerTwoName` | String | `"Solo"` if single-player |
| `playerOneScore` | Int | |
| `playerTwoScore` | Int | |
| `averageSwingSpeed` | Double | MPH |
| `maxSwingSpeed` | Double | MPH — used for personal best tracking |
| `sweetSpotPercentage` | Double | 0–100 |
| `totalHits` | Int | |
| `winnerName` | String | |
| `longestStreak` | Int | Dink Sinks mode |
| `totalValidVolleys` | Int | Volley Wallies mode (≥15 MPH) |
| `bestRallyLength` | Int | The Real Deal mode |
| `remoteID` | UUID? | Set once confirmed in Supabase |
| `isDirty` | Bool | `true` = pending sync |
| `isChallenge` | Bool | **NEW (MVP).** `true` = challenge match. If user wins, awards +100 XP |
| `isPickleCupWin` | Bool | **NEW (MVP).** `true` = user won the full Pickle Cup sequence |

**Relationships:**
- Syncs to → `game_sessions` (remote)
- Referenced by → `user_badges.session_id` (optional, when a badge is triggered by this session)

---

#### `SavedLocation`
Named locations for a user (home court, favorite venue, etc.).
Replaces the single `PlayerProfile.locationName` string.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `label` | String | e.g. `"Home"`, `"Rec Center"` |
| `placeName` | String | Venue/area name |
| `address` | String? | Full street address |
| `latitude` | Double? | For map/weather features |
| `longitude` | Double? | |
| `isHome` | Bool | At most one per user. Used by weather service |
| `supabaseID` | UUID? | Set once confirmed in `saved_locations` |
| `isDirty` | Bool | `true` = pending sync |
| `createdAt` | Date | |

**Relationships:**
- Syncs to → `saved_locations` (remote)
- `isHome = true` row replaces `PlayerProfile.locationName`

---

#### `SyncQueueItem`
Offline write queue. When there is no network connection, all
Supabase-bound writes are serialised here. Drained oldest-first
when connectivity is restored.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID | PK |
| `operation` | String | See **SyncOperation enum** below |
| `tableName` | String | Target Supabase table (e.g. `"game_sessions"`) |
| `payload` | Data | JSON-encoded request body |
| `createdAt` | Date | Queue order is ascending by this field |
| `retryCount` | Int | Abandoned after 5 retries |

**SyncOperation values:**
| Value | Action |
|---|---|
| `upsert_profile` | POST to `user_profiles` with `Prefer: resolution=merge-duplicates` |
| `save_session` | POST to `game_sessions` |
| `upsert_location` | POST to `saved_locations` with merge-duplicates |
| `award_badge` | POST to `user_badges` |
| `xp_events` | POST rows to `xp_events`, then PATCH `user_profiles.total_xp` |

---

### REMOTE (Supabase / PostgreSQL)

All tables use Row Level Security (RLS). Users may only read and write
their own rows unless otherwise noted.

---

#### `auth.users` *(Supabase-managed — do not modify directly)*
Standard Supabase auth table.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK — this is the universal user identifier across all tables |
| `email` | text | Unique |

**Every custom table that is user-owned has `user_id uuid FK → auth.users(id)`.**

---

#### `user_profiles`
1:1 extension of `auth.users`. Stores display data, XP, and GPN integration fields.

> **Option A note:** `total_xp` and `xp_updated_at` are stored here.
> The separate `user_progression` table no longer exists.
> Level/rank is resolved in Swift using `ProgressionService.levelThresholds`.
>
> **MVP note:** `current_streak`, `longest_streak`, `last_active_date` added for the
> 5-day streak XP bonus (+75 XP). GPN integration uses the real OAuth API
> (`globalpickleball.network/developers`) — not HTML scraping.

| Column | Type | Notes |
|---|---|---|
| `user_id` | uuid | PK + FK → `auth.users.id` |
| `display_name` | text | Default `''` |
| `avatar_url` | text | nullable |
| `total_xp` | int | Default `0`. Upserted after every session |
| `xp_updated_at` | timestamptz | nullable. Timestamp of last XP change |
| `gpn_username` | text | nullable. User's GPN handle |
| `gpn_profile_url` | text | nullable. Cached GPN profile URL |
| `gpn_singles_level` | numeric(4,2) | nullable. e.g. `3.50`. Set by Edge Function |
| `gpn_doubles_level` | numeric(4,2) | nullable |
| `gpn_dupr_rating` | numeric(4,2) | nullable. DUPR rating via GPN |
| `gpn_last_synced_at` | timestamptz | nullable. Last successful GPN OAuth sync |
| `current_streak` | int | **NEW (MVP).** Default `0`. Consecutive daily-play streak |
| `longest_streak` | int | **NEW (MVP).** Default `0`. All-time best streak |
| `last_active_date` | date | **NEW (MVP).** nullable. Last calendar day with a completed session |
| `created_at` | timestamptz | Auto |
| `updated_at` | timestamptz | Auto. Update via trigger |

**How levels work:**
```
total_xp >= 0    → Bronze (Bronze Paddle)
total_xp >= 500  → Silver (Silver Spin)
total_xp >= 1400 → Gold (Gold Rally)
total_xp >= 3800 → Diamond (Diamond Dink)
```
4 ranks — no Platinum. Resolved entirely in `ProgressionService.swift`.

**Upsert pattern used by app:**
```
POST /rest/v1/user_profiles
Prefer: resolution=merge-duplicates
```

---

#### `game_sessions`
Remote replica of `StoredGameSession`. Enables multi-device access and cloud backup.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK — same UUID as `StoredGameSession.id` |
| `user_id` | uuid | FK → `user_profiles.user_id` |
| `mode` | text | `Dink Sinks` \| `Volley Wallies` \| `The Real Deal` \| `Pickle Cup` |
| `start_date` | timestamptz | |
| `end_date` | timestamptz | Sort order |
| `player_one_name` | text | |
| `player_two_name` | text | `"Solo"` if single-player |
| `player_one_score` | int | |
| `player_two_score` | int | |
| `average_swing_speed` | float8 | MPH |
| `max_swing_speed` | float8 | MPH |
| `sweet_spot_percentage` | float8 | 0–100 |
| `total_hits` | int | |
| `winner_name` | text | |
| `longest_streak` | int | |
| `total_valid_volleys` | int | |
| `best_rally_length` | int | |
| `is_challenge` | bool | **NEW (MVP).** Default `false`. Challenge match flag. Winner earns +100 XP |
| `is_pickle_cup_win` | bool | **NEW (MVP).** Default `false`. `true` = user won full Pickle Cup |
| `created_at` | timestamptz | Auto |

**Fetch pattern:**
```
GET /rest/v1/game_sessions
  ?user_id=eq.{uid}
  &order=end_date.desc
```

---

#### `shot_events`
**NEW (Phase 2 / MVP).** Remote record of individual shot events per session.
Per MVP spec section 6, `ShotEvent` includes `gameId` and `sessionId` as persistent fields.
Enables future biomechanics analysis and shot-level replays.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK, auto-generated |
| `session_id` | uuid | FK → `game_sessions.id` — cascade deletes |
| `user_id` | uuid | FK → `user_profiles.user_id` |
| `timestamp` | timestamptz | Exact UTC time of paddle hit event from BLE |
| `speed_mph` | float8 | Swing speed from BLE `estimatedSwingSpeed` (MPH) |
| `hit_sweet_spot` | bool | `true` if paddle BLE event flagged `sweetSpotHit` |
| `spin_rpm` | float8 | Default `0`. Spin rate if available from paddle firmware |
| `created_at` | timestamptz | Auto |

**Fetch pattern:**
```
GET /rest/v1/shot_events
  ?session_id=eq.{sessionId}
  &order=timestamp.asc
```

---

#### `saved_locations`
Remote replica of `SavedLocation`. Partial unique index enforces one home per user.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `user_id` | uuid | FK → `user_profiles.user_id` |
| `label` | text | Default `'Home'` |
| `place_name` | text | |
| `address` | text | nullable |
| `latitude` | float8 | nullable |
| `longitude` | float8 | nullable |
| `is_home` | bool | Default `false`. **UNIQUE per user via partial index** |
| `created_at` | timestamptz | Auto |

**Constraint:**
```sql
CREATE UNIQUE INDEX saved_locations_one_home_per_user
  ON saved_locations (user_id)
  WHERE is_home = true;
```

---

#### `badges`
Catalog of all available badges. Public read. Admin-only write.
The app fetches this list to render locked/unlocked states without
any badge definitions hardcoded in Swift.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `key` | text | **UNIQUE**. Machine code, e.g. `"first_session"`, `"100_hits"`, `"gold_tier"` |
| `name` | text | Display name |
| `description` | text | How to earn it |
| `icon_url` | text | Badge image |
| `badge_type` | text | `achievement` \| `milestone` \| `tournament` \| `level` |
| `xp_reward` | int | Bonus XP when earned. Default `0` |
| `is_hidden` | bool | `true` = secret badge, hidden until earned |
| `created_at` | timestamptz | Auto |

**badge_type meanings:**
| Type | Trigger |
|---|---|
| `achievement` | Stat milestone (e.g. 100 total hits, 75% sweet spot) |
| `milestone` | Participation (e.g. 10 sessions played, 30 days active) |
| `tournament` | Imported from GPN tournament results |
| `level` | Crossing a tier threshold (Bronze, Silver, etc.) |

**Fetch pattern (cached 24h):**
```
GET /rest/v1/badges
  ?select=id,key,name,description,icon_url,badge_type,xp_reward,is_hidden
  &order=badge_type.asc,name.asc
```

---

#### `user_badges`
Junction table: which badges each user has earned.
`UNIQUE(user_id, badge_id)` prevents duplicate awards.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `user_id` | uuid | FK → `user_profiles.user_id` |
| `badge_id` | uuid | FK → `badges.id` |
| `awarded_at` | timestamptz | Auto |
| `source` | text | nullable. Readable reason, e.g. `"First session completed"` |
| `session_id` | uuid | nullable. FK → `game_sessions.id` — which session triggered it |

**Constraint:** `UNIQUE (user_id, badge_id)`

**Insert pattern:**
```
POST /rest/v1/user_badges
  (bearer token required — RLS)
```

---

#### `xp_events`
Immutable append-only log of every XP award. One row per
`XPBreakdownItem` per session. Used for auditing.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK, auto-generated |
| `user_id` | uuid | FK → `auth.users.id` |
| `source` | text | **MVP XP values:** `"Complete session"` +50 · `"10+ clean hits"` +20 · `"Personal best"` +40 · `"Played with a friend"` +30 · `"5-day streak"` +75 · `"Challenge win"` +100 |
| `xp` | int | Amount awarded |
| `metadata` | jsonb | nullable. Arbitrary context: `sync_type`, `session_count`, `previous_remote_xp` |
| `created_at` | timestamptz | Auto. **Events must be applied in ASC order** |

> When draining offline queue, always process `xp_events` rows in
> `created_at ASC` order before updating `user_profiles.total_xp`.

---

#### `comments`
Public comments on game sessions or other feed items.
`item_id` is a soft/generic UUID reference (not a strict FK),
allowing multiple commentable entity types.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `item_id` | uuid | Soft ref to commented item (e.g. `game_sessions.id`) |
| `user_id` | uuid | FK → `auth.users.id` |
| `author_name` | text | Display name at time of posting |
| `body` | text | Comment content |
| `created_at` | timestamptz | Default `now()`. Ordered DESC for display |

**Fetch pattern:**
```
GET /rest/v1/comments
  ?select=id,item_id,user_id,author_name,body,created_at
  &item_id=eq.{itemID}
  &order=created_at.desc
```

---

#### `comment_likes`
Tracks which users liked which comments.
Unlike = `DELETE` by `(comment_id, user_id)`.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `comment_id` | uuid | FK → `comments.id` |
| `user_id` | uuid | FK → `auth.users.id` |

---

## Entity Relationship Map

```
auth.users (id)
  │
  └─1:1──► user_profiles (user_id PK+FK)
                │  total_xp ──► resolved to rank in Swift
                │               Bronze Paddle / Silver Spin / Gold Rally / Diamond Dink
                │  current_streak ──► 5-day streak XP (+75) trigger
                │
                ├─1:M──► saved_locations (user_id)
                │         └─ is_home=true row → used by HomeViewModel.loadTodayWeather()
                │
                ├─1:M──► user_badges (user_id)
                │         └─M:1──► badges (badge_id)
                │                    session_id ──► game_sessions.id (optional)
                │
                └─1:M──► game_sessions (user_id)
                            └─1:M──► shot_events (session_id)

auth.users (id) [also direct FK for audit/social tables]
  ├─1:M──► xp_events (user_id)
  ├─1:M──► comments (user_id)
  └─1:M──► comment_likes (user_id)
              └─M:1──► comments (comment_id)
```

---

## GPN Integration

Global Pickleball Network (`globalpickleball.network`) has a real developer REST API
at `globalpickleball.network/developers`. Requires developer registration.

**Available endpoints (via GPN Developer API):**
- `POST /api/login` — Authenticate, returns `access_token` + `refresh_token`
- `GET /api/user/info` — Fetch user profile data
- `GET /api/user/calculated-levels` — Retrieve singles/doubles skill levels (e.g. `3.50`)
- `GET /api/user/stats` — Fetch match statistics including DUPR rating

**How it works:**
1. User enters their GPN username and password in the app → credentials never stored client-side
2. App calls Supabase Edge Function: `POST /functions/v1/sync-gpn-profile`
3. Edge Function (Deno runtime) authenticates with GPN OAuth API using user credentials
4. Fetches and parses `calculated-levels` and `stats` responses
5. Writes `gpn_singles_level`, `gpn_doubles_level`, `gpn_dupr_rating`, `gpn_last_synced_at` to `user_profiles`
6. Access/refresh tokens stored server-side in Supabase Vault — never returned to client
7. App reads and displays cached values; never hits GPN directly

**Offline behaviour:** Show cached values with "Last updated X days ago".
Sync button disabled when `NetworkMonitor.isConnected = false`.
Consider showing a warning if `gpn_last_synced_at` is > 7 days old.

**DUPR:** GPN is a DUPR preferred partner. DUPR ratings appear on GPN
profiles and are captured in `gpn_dupr_rating`.

---

## Row Level Security Summary

| Table | Read | Write |
|---|---|---|
| `user_profiles` | Own row only | Own row only |
| `game_sessions` | Own rows only | Own rows only |
| `shot_events` | Own rows only | Own rows only |
| `saved_locations` | Own rows only | Own rows only |
| `user_badges` | Own rows only | Own rows only |
| `badges` | **Public** (all users) | Admin only |
| `xp_events` | Own rows only | Own rows only |
| `comments` | Own rows only | Own rows only |
| `comment_likes` | Own rows only | Own rows only |

All writes require a valid `Bearer {access_token}` JWT.
The `apikey` header uses the publishable anon key (safe for client use).

---

## Offline-First Sync Rules

| Data type | Conflict resolution |
|---|---|
| Game sessions | Local write wins — append only, no conflicts |
| Profile / XP | Remote `total_xp` wins if remote > local |
| Saved locations | Local write wins — append only |
| Badges | Union — add any remote badges not in local set |
| XP events | Must be replayed in `created_at ASC` order |

---

## Common Query Patterns

**Get user's full profile + XP:**
```
GET /rest/v1/user_profiles
  ?user_id=eq.{uid}
  &select=*
```

**Get recent sessions:**
```
GET /rest/v1/game_sessions
  ?user_id=eq.{uid}
  &order=end_date.desc
  &limit=20
```

**Get earned badges with catalog detail:**
```
GET /rest/v1/user_badges
  ?user_id=eq.{uid}
  &select=awarded_at,source,session_id,badges(key,name,icon_url,badge_type)
```

**Upsert XP after session:**
```
POST /rest/v1/user_profiles
Prefer: resolution=merge-duplicates
Body: { "user_id": "...", "total_xp": 450, "xp_updated_at": "2026-04-13T..." }
```

**Get shots for a session:**
```
GET /rest/v1/shot_events
  ?session_id=eq.{sessionId}
  &order=timestamp.asc
```

**Award a badge:**
```
POST /rest/v1/user_badges
Body: { "user_id": "...", "badge_id": "...", "source": "First session completed", "session_id": "..." }
```

---

## Files in This Folder

| File | Purpose |
|---|---|
| `DinkLink-DataModel-ERD.txt` | Full ERD in text format |
| `DinkLink-DataModel.xlsx` | Excel workbook — one sheet per table |
| `DinkLink-Cutover-Plan.txt` | Phased migration plan (6 phases) |
| `DATABASE_README.txt` | This file — agent and developer reference |
| `generate_datamodel_excel.py` | Python script to regenerate the Excel file |
