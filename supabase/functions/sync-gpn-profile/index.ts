// supabase/functions/sync-gpn-profile/index.ts
//
// Supabase Edge Function — Deno runtime.
//
// GPN integration model (per official docs):
//   • One-time login: caller sends gpn_username + gpn_password.
//     We GET getSession → receive {userID, sessionID}.
//     userID + sessionID are stored server-side in gpn_profiles.
//   • Subsequent syncs: caller sends NO credentials. We pull the
//     stored userID via the service-role client and refresh data
//     using devKey + userID.
//
// The dev key is a Function secret — set with:
//   supabase secrets set GPN_DEV_KEY=265155-jMSTcVYLVg

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const GPN_BASE = "https://www.globalpickleball.network/component/api";

interface SyncRequest {
  gpn_username?: string;
  gpn_password?: string;
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
    headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
  });
}

function toFloat(v: unknown): number | null {
  if (v === null || v === undefined || v === "") return null;
  const n = Number(v);
  return isNaN(n) ? null : n;
}

function toInt(v: unknown): number | null {
  const n = toFloat(v);
  return n === null ? null : Math.round(n);
}

// ---------------------------------------------------------------------------
// GPN API (query-string protocol)
// ---------------------------------------------------------------------------

async function gpnFetch(params: Record<string, string>): Promise<unknown> {
  const url = new URL(GPN_BASE);
  for (const [k, v] of Object.entries(params)) url.searchParams.set(k, v);
  url.searchParams.set("format", "raw");
  const res = await fetch(url.toString(), { method: "GET" });
  const text = await res.text();
  if (!res.ok) throw new Error(`GPN ${params.apiCall} failed (${res.status}): ${text}`);
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`GPN ${params.apiCall} returned non-JSON: ${text.slice(0, 200)}`);
  }
}

async function gpnGetSession(devKey: string, username: string, password: string)
  : Promise<{ userID: string; sessionID: string }>
{
  const data = await gpnFetch({
    apiCall: "getSession",
    devKey,
    username,
    password,
  }) as Record<string, unknown>;
  const userID = String(data.userID ?? "");
  const sessionID = String(data.sessionID ?? "");
  if (!userID || !sessionID) {
    throw new Error("GPN getSession: missing userID/sessionID in response");
  }
  return { userID, sessionID };
}

async function gpnGetUserInfo(devKey: string, email: string): Promise<Record<string, unknown>> {
  return await gpnFetch({ apiCall: "getUserInfo", devKey, email }) as Record<string, unknown>;
}

async function gpnGetUserLevels(devKey: string, userID: string): Promise<Record<string, unknown>> {
  return await gpnFetch({ apiCall: "getUserLevels", devKey, userID }) as Record<string, unknown>;
}

async function gpnGetUsersStats(devKey: string, userID: string): Promise<Record<string, unknown>> {
  return await gpnFetch({
    apiCall: "getUsersStats",
    devKey,
    userID,
    leagues: "1",
    ladders: "1",
    tournaments: "1",
  }) as Record<string, unknown>;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin");

  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders(origin) });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405, origin);
  }

  // ---- 1. Verify Supabase JWT --------------------------------------------
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  // TODO: move to `supabase secrets set GPN_DEV_KEY=...` once a Function
  // secret is provisioned. Hardcoded for now per project owner request.
  const devKey = Deno.env.get("GPN_DEV_KEY") ?? "265155-jMSTcVYLVg";

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: "Server misconfiguration (Supabase env)" }, 500, origin);
  }
  if (!devKey) {
    return jsonResponse({ error: "Server misconfiguration (GPN_DEV_KEY missing)" }, 500, origin);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "Missing or invalid Authorization header" }, 401, origin);
  }
  const callerJWT = authHeader.slice(7);
  const anonKey = req.headers.get("apikey") ?? Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const supabaseClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${callerJWT}` } },
  });
  const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
  if (authError || !user) {
    return jsonResponse({ error: "Unauthorized" }, 401, origin);
  }
  const supabaseUserID = user.id;

  // ---- 2. Parse body -----------------------------------------------------
  let body: SyncRequest = {};
  try {
    body = (await req.json()) as SyncRequest;
  } catch {
    /* empty body is allowed for refresh-only syncs */
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey);

  // ---- 3. Resolve GPN userID ---------------------------------------------
  let gpnUserID: string | null = null;
  let gpnSessionID: string | null = null;
  let gpnUsername: string | null = null;

  if (body.gpn_username?.trim() && body.gpn_password?.trim()) {
    try {
      const session = await gpnGetSession(
        devKey,
        body.gpn_username.trim(),
        body.gpn_password,
      );
      gpnUserID = session.userID;
      gpnSessionID = session.sessionID;
      gpnUsername = body.gpn_username.trim();
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return jsonResponse({
        error: "GPN authentication failed. Check your username and password.",
        detail: msg,
      }, 422, origin);
    }
  } else {
    const { data: existing, error: selectErr } = await adminClient
      .from("gpn_profiles")
      .select("gpn_user_id, gpn_session_id, gpn_username")
      .eq("user_id", supabaseUserID)
      .maybeSingle();
    if (selectErr) {
      return jsonResponse({ error: "Failed to read cached GPN session" }, 500, origin);
    }
    if (!existing?.gpn_user_id) {
      return jsonResponse({
        error: "No GPN account linked. Send gpn_username and gpn_password to link.",
      }, 400, origin);
    }
    gpnUserID = existing.gpn_user_id;
    gpnSessionID = existing.gpn_session_id ?? null;
    gpnUsername = existing.gpn_username ?? null;
  }

  // ---- 4. Pull GPN data ---------------------------------------------------
  const [infoResult, levelsResult, statsResult] = await Promise.allSettled([
    gpnUsername && gpnUsername.includes("@")
      ? gpnGetUserInfo(devKey, gpnUsername)
      : Promise.resolve({} as Record<string, unknown>),
    gpnGetUserLevels(devKey, gpnUserID),
    gpnGetUsersStats(devKey, gpnUserID),
  ]);

  const info: Record<string, unknown>   = infoResult.status   === "fulfilled" ? infoResult.value   : {};
  const levels: Record<string, unknown> = levelsResult.status === "fulfilled" ? levelsResult.value : {};
  const stats: Record<string, unknown>  = statsResult.status  === "fulfilled" ? statsResult.value  : {};

  // ---- 5. Normalise -------------------------------------------------------
  const calcSingles = levels.calculatedSingles as Record<string, unknown> | undefined;
  const calcDoubles = levels.calculatedDoubles as Record<string, unknown> | undefined;
  const singlesLevel = toFloat(calcSingles?.current) ?? toFloat(levels.singlesSelfRating);
  const doublesLevel = toFloat(calcDoubles?.current) ?? toFloat(levels.doublesSelfRating);
  const overallLevel = singlesLevel !== null && doublesLevel !== null
    ? Number(((singlesLevel + doublesLevel) / 2).toFixed(2))
    : (singlesLevel ?? doublesLevel);

  const wins   = toInt(stats.wins) ?? 0;
  const losses = toInt(stats.loses) ?? 0;
  const totalMatches = wins + losses;
  const winPct = totalMatches > 0 ? Number(((wins / totalMatches) * 100).toFixed(2)) : null;

  const profileRow = {
    user_id:          supabaseUserID,
    gpn_user_id:      gpnUserID,
    gpn_session_id:   gpnSessionID,
    gpn_username:     gpnUsername ?? "",
    gpn_display_name: (info.displayName ?? info.name ?? null) as string | null,
    gpn_avatar_url:   (info.avatar ?? info.avatarUrl ?? null) as string | null,
    gpn_profile_url:  (info.profileUrl ?? null) as string | null,
    gpn_location:     (info.city ?? info.location ?? null) as string | null,
    singles_level:    singlesLevel,
    doubles_level:    doublesLevel,
    overall_level:    overallLevel,
    dupr_rating:      null as number | null,
    total_matches:    totalMatches,
    wins,
    losses,
    win_percentage:   winPct,
    last_synced_at:   new Date().toISOString(),
  };

  const { error: upsertError } = await adminClient
    .from("gpn_profiles")
    .upsert(profileRow, { onConflict: "user_id" });

  if (upsertError) {
    console.error("gpn_profiles upsert error:", upsertError);
    return jsonResponse({ error: "Failed to save GPN data" }, 500, origin);
  }

  // ---- 6. Return — never echo the sessionID -------------------------------
  return jsonResponse({
    gpn_username:     profileRow.gpn_username,
    gpn_display_name: profileRow.gpn_display_name,
    gpn_avatar_url:   profileRow.gpn_avatar_url,
    gpn_profile_url:  profileRow.gpn_profile_url,
    gpn_location:     profileRow.gpn_location,
    singles_level:    singlesLevel,
    doubles_level:    doublesLevel,
    overall_level:    overallLevel,
    dupr_rating:      null,
    total_matches:    totalMatches,
    wins,
    losses,
    win_percentage:   winPct,
  }, 200, origin);
});
