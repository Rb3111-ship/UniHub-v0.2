// Removes a user for an admin, including the files they uploaded.
//
// 1. Calls the database function admin_delete_user AS THE CALLING ADMIN, so every
//    permission rule lives in SQL (who may remove whom, admins must be demoted first...).
// 2. Only if that succeeded: deletes the person's storage folders (profile photo,
//    event pictures, organizer documents). The database cannot delete stored files.
// 3. Sweeps folders of people who no longer exist (e.g. a removal whose file
//    clean-up failed earlier), so nothing is left behind for long.
//
// Body: { "user_id": "<uuid>", "block": true|false }
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

const URL = Deno.env.get("SUPABASE_URL")!;
const admin = createClient(URL, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
const BUCKETS = ["avatars", "event-images", "organizer-docs"];
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

/** Every file directly inside "<folder>/" of a bucket (folders here are flat). */
async function filesIn(bucket: string, folder: string): Promise<string[]> {
  const names: string[] = [];
  for (let offset = 0; ; offset += 1000) {
    const { data, error } = await admin.storage.from(bucket).list(folder, { limit: 1000, offset });
    if (error) throw error;
    for (const f of data ?? []) if (f.id) names.push(`${folder}/${f.name}`);
    if (!data || data.length < 1000) return names;
  }
}

async function removeFolder(bucket: string, folder: string): Promise<number> {
  const paths = await filesIn(bucket, folder);
  for (let i = 0; i < paths.length; i += 500) {
    const { error } = await admin.storage.from(bucket).remove(paths.slice(i, i + 500));
    if (error) throw error;
  }
  return paths.length;
}

/** Deletes top-level folders named after a user id that has no profile any more. */
async function sweepOrphans(): Promise<number> {
  let removed = 0;
  for (const bucket of BUCKETS) {
    const { data, error } = await admin.storage.from(bucket).list("", { limit: 1000 });
    if (error) throw error;
    const folders = (data ?? []).filter((f) => !f.id && UUID.test(f.name)).map((f) => f.name);
    if (folders.length === 0) continue;
    const { data: alive, error: e2 } = await admin.from("profiles").select("id").in("id", folders);
    if (e2) throw e2; // never guess: without the profile list, delete nothing
    const keep = new Set((alive ?? []).map((p) => p.id as string));
    for (const folder of folders) if (!keep.has(folder)) removed += await removeFolder(bucket, folder);
  }
  return removed;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  if (req.method !== "POST") return reply(405, { error: "method_not_allowed" });

  const auth = req.headers.get("Authorization") ?? "";
  const apikey = req.headers.get("apikey") ?? Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!auth.startsWith("Bearer ") || !apikey) return reply(401, { error: "not_authenticated" });

  let userId: string, block: boolean;
  try {
    const body = await req.json();
    userId = String(body.user_id ?? "").toLowerCase();
    block = body.block === true;
  } catch {
    return reply(400, { error: "bad_request" });
  }
  if (!UUID.test(userId)) return reply(400, { error: "bad_request" });

  // Step 1: as the caller. The SQL function decides whether this is allowed.
  const asCaller = createClient(URL, apikey, {
    auth: { persistSession: false },
    global: { headers: { Authorization: auth } },
  });
  const { data: events, error } = await asCaller.rpc("admin_delete_user", { p_user: userId, p_block: block });
  if (error) {
    const known = ["not_authorized", "not_found", "cannot_remove_self", "demote_first"].find((k) => error.message.includes(k));
    return reply(known === "not_found" ? 404 : 403, { error: known ?? "refused" });
  }

  // Step 2 + 3: the account is gone now; remove its files and any older leftovers.
  let files = 0;
  let filesOk = true;
  try {
    for (const bucket of BUCKETS) files += await removeFolder(bucket, userId);
    files += await sweepOrphans();
  } catch (e) {
    filesOk = false; // the next removal's sweep tries again
    console.error("file clean-up failed", e);
  }
  return reply(200, { events, files, files_ok: filesOk });
});
