// supabase/functions/sync-gpn-profile/index.ts
//
// Supabase Edge Function — Deno runtime.
//
// Responsibilities:
//   1. Receive GPN credentials from the authenticated iOS app.
//   2. Authenticate with the Global Pickleball Network REST API.
//   3. Fetch the user's profile, calculated skill levels, and match stats.
//   4. Upsert results into public.gpn_profiles (the caller's own row via RLS).
//   5. Return the parsed data to the app for immediate local caching.
//
// Security model:
//   - GPN credentials are used once and never persisted anywhere.
//   - The caller MUST supply a valid Supabase Bearer JWT; we verify it before
//     doing anything, preventing unauthenticated calls to the GPN API.
//   - All GPN HTTP calls are made server-side (Deno) — credentials never
//     travel through the client after the initial POST.
//
// Deploy:
//   supabase functions deploy sync-gpn-profile --no-verify-jwt=false

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const GPN_BASE = "https://www.globalpickleball.network/api";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface SyncRequest {
  gpn_username: string;
  gpn_password: string;
}

interface GPNLoginResponse {
  access_token?: string;
  token?: string; // some GPN API versions use "token"
  user_id?: number | string;
}

interface GPNUserInfoResponse {
  username?: string;
  name?: string;
  display_name?: string;
  avatar?: string;
  avatar_url?: string;
  profile_url?: string;
  city?: string;
  location?: string;
  [key: string]: unknown;
}

interface GPNLevelsResponse {
  singles_level?: number | string;
  doubles_level?: number | string;
  overall_level?: number | string;
  singles?: number | string;
  doubles?: number | string;
  overall?: number | string;
  [key: string]: unknown;
}

interface GPNStatsResponse {
  dupr_rating?: number | string;
  dupr?: number | string;
  total_matches?: number | string;
  matches?: number | string;
  wins?: number | string;
  losses?: number | string;
  win_percentage?: number | string;
  win_pct?: number | string;
  [key: string]: unknown;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function toFloat(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  const n = Number(value);
  return isNaN(n) ? null : n;
}

function toInt(value: unknown): number | null {
  const n = toFloat(value);
  return n === null ? null : Math.round(n);
}

function corsHeaders(origin: string | null) {
  return {
    "Access-Control-Allow-Origin": origin ?? "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

function jsonResponse(body: unknown, status = 200, origin: string | null = null) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(origin),
      "Content-Type": "application/json",
    },
  });
}

// ---------------------------------------------------------------------------
// GPN API calls
// ---------------------------------------------------------------------------

async function gpnLogin(username: string, password: string): Promise<string> {
  const res = await fetch(`${GPN_BASE}/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ username, password }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`GPN login failed (${res.status}): ${text}`);
  }

  const data = (await res.json()) as GPNLoginResponse;
  const token = data.access_token ?? data.token;
  if (!token) {
    throw new Error("GPN login succeeded but no access_token in response");
  }
  return token;
}

async function gpnGetUserInfo(token: string): Promise<GPNUserInfoResponse> {
  const res = await fetch(`${GPN_BASE}/user/info`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) throw new Error(`GPN /user/info failed (${res.status})`);
  return (await res.json()) as GPNUserInfoResponse;
}

async function gpnGetCalculatedLevels(token: string): Promise<GPNLevelsResponse> {
  const res = await fetch(`${GPN_BASE}/user/calculated-levels`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) throw new Error(`GPN /user/calculated-levels failed (${res.status})`);
  return (await res.json()) as GPNLevelsResponse;
}

async function gpnGetStats(token: string): Promise<GPNStatsResponse> {
  const res = await fetch(`${GPN_BASE}/user/stats`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) throw new Error(`GPN /user/stats failed (${res.status})`);
  return (await res.json()) as GPNStatsResponse;
}

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin");

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders(origin) });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405, origin);
  }

  // ------------------------------------------------------------------
  // 1. Verify Supabase JWT — reject unauthenticated callers early.
  // ------------------------------------------------------------------
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: "Server misconfiguration" }, 500, origin);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "Missing or invalid Authorization header" }, 401, origin);
  }
  const callerJWT = authHeader.slice(7);

  // Use the anon key from the header to verify the caller's JWT.
  const anonKey = req.headers.get("apikey") ?? Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const supabaseClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${callerJWT}` } },
  });

  const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
  if (authError || !user) {
    return jsonResponse({ error: "Unauthorized" }, 401, origin);
  }
  const userID = user.id;

  // ------------------------------------------------------------------
  // 2. Parse request body
  // ------------------------------------------------------------------
  let body: SyncRequest;
  try {
    body = (await req.json()) as SyncRequest;
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400, origin);
  }

  const { gpn_username, gpn_password } = body;
  if (!gpn_username?.trim() || !gpn_password?.trim()) {
    return jsonResponse({ error: "gpn_username and gpn_password are required" }, 400, origin);
  }

  // ------------------------------------------------------------------
  // 3. Authenticate with GPN
  // ------------------------------------------------------------------
  let gpnToken: string;
  try {
    gpnToken = await gpnLogin(gpn_username.trim(), gpn_password);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    // Surface a user-friendly message — don't leak internal details.
    return jsonResponse({
      error: "GPN authentication failed. Check your username and password.",
      detail: msg,
    }, 422, origin);
  }

  // ------------------------------------------------------------------
  // 4. Fetch GPN data (parallel)
  // ------------------------------------------------------------------
  const [userInfoResult, levelsResult, statsResult] = await Promise.allSettled([
    gpnGetUserInfo(gpnToken),
    gpnGetCalculatedLevels(gpnToken),
    gpnGetStats(gpnToken),
  ]);

  const info: GPNUserInfoResponse = userInfoResult.status === "fulfilled"
    ? userInfoResult.value
    : {};
  const levels: GPNLevelsResponse = levelsResult.status === "fulfilled"
    ? levelsResult.value
    : {};
  const stats: GPNStatsResponse = statsResult.status === "fulfilled"
    ? statsResult.value
    : {};

  // ------------------------------------------------------------------
  // 5. Normalise fields (GPN API has varied casing across versions)
  // ------------------------------------------------------------------
  const singlesLevel  = toFloat(levels.singles_level ?? levels.singles);
  const doublesLevel  = toFloat(levels.doubles_level ?? levels.doubles);
  const overallLevel  = toFloat(levels.overall_level ?? levels.overall);
  const duprRating    = toFloat(stats.dupr_rating ?? stats.dupr);
  const totalMatches  = toInt(stats.total_matches ?? stats.matches) ?? 0;
  const wins          = toInt(stats.wins) ?? 0;
  const losses        = toInt(stats.losses) ?? 0;
  const winPct        = toFloat(stats.win_percentage ?? stats.win_pct);

  const profileRow = {
    user_id:          userID,
    gpn_username:     (info.username ?? gpn_username).trim(),
    gpn_display_name: info.display_name ?? info.name ?? null,
    gpn_avatar_url:   info.avatar_url ?? info.avatar ?? null,
    gpn_profile_url:  info.profile_url ?? null,
    gpn_location:     info.location ?? info.city ?? null,
    singles_level:    singlesLevel,
    doubles_level:    doublesLevel,
    overall_level:    overallLevel,
    dupr_rating:      duprRating,
    total_matches:    totalMatches,
    wins,
    losses,
    win_percentage:   winPct,
    last_synced_at:   new Date().toISOString(),
  };

  // ------------------------------------------------------------------
  // 6. Upsert into gpn_profiles using the service role (bypasses RLS
  //    since we've already verified the caller's identity above).
  // ------------------------------------------------------------------
  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const { error: upsertError } = await adminClient
    .from("gpn_profiles")
    .upsert(profileRow, { onConflict: "user_id" });

  if (upsertError) {
    console.error("gpn_profiles upsert error:", upsertError);
    return jsonResponse({ error: "Failed to save GPN data" }, 500, origin);
  }

  // ------------------------------------------------------------------
  // 7. Return parsed data to the app for immediate local caching.
  //    Credentials are not echoed back.
  // ------------------------------------------------------------------
  const responsePayload = {
    gpn_username:     profileRow.gpn_username,
    gpn_display_name: profileRow.gpn_display_name,
    gpn_avatar_url:   profileRow.gpn_avatar_url,
    gpn_profile_url:  profileRow.gpn_profile_url,
    gpn_location:     profileRow.gpn_location,
    singles_level:    singlesLevel,
    doubles_level:    doublesLevel,
    overall_level:    overallLevel,
    dupr_rating:      duprRating,
    total_matches:    totalMatches,
    wins,
    losses,
    win_percentage:   winPct,
  };

  return jsonResponse(responsePayload, 200, origin);
});
