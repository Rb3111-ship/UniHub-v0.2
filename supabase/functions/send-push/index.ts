// Sends pending UniHub notifications as push messages through Firebase Cloud Messaging.
//
// Called only by the database (trigger + retry job) with the shared secret from Vault.
// It takes no input: it claims whatever is pending, sends it and records the result,
// so calling it twice is harmless.
//
// Needs one secret set in the Supabase dashboard (Edge Functions > Secrets):
//   FCM_SERVICE_ACCOUNT = the full JSON of a Firebase service account key.
import { createClient } from "npm:@supabase/supabase-js@2.49.4";

type Row = { id: number; user_id: string; kind: string; event_id: string | null; event_title: string | null; starts_at: string | null };
type Target = { user_id: string; token: string; platform: string; locale: string };

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});

// ---- message texts (same wording as the in-app inbox) ------------------------------
function hoursUntil(startsAt: string | null): number | null {
  if (!startsAt) return null;
  return Math.round((Date.parse(startsAt) - Date.now()) / 3_600_000);
}

function text(row: Row, locale: string): { title: string; body: string } {
  const t = row.event_title ?? "";
  const h = hoursUntil(row.starts_at);
  const de = locale === "de";
  switch (row.kind) {
    case "event_cancelled":
      return de ? { title: "Event abgesagt", body: `${t} wurde abgesagt.` }
                : { title: "Event cancelled", body: `${t} has been cancelled.` };
    case "event_changed":
      return de ? { title: "Event geändert", body: `${t}: Zeit oder Ort hat sich geändert.` }
                : { title: "Event updated", body: `${t}: the time or place has changed.` };
    case "waitlist_promoted":
      return de ? { title: "Du hast einen Platz!", body: `Du bist jetzt für ${t} angemeldet. Dein Ticket ist bereit.` }
                : { title: "You got a spot!", body: `You're now registered for ${t}. Your ticket is ready.` };
    case "reminder":
      if (h !== null && h >= 2) {
        return de ? { title: "Erinnerung", body: `${t} beginnt in ${h} Stunden.` }
                  : { title: "Reminder", body: `${t} starts in ${h} hours.` };
      }
      return de ? { title: "Erinnerung", body: `${t} beginnt bald.` }
                : { title: "Reminder", body: `${t} starts soon.` };
    case "request_approved":
      return de ? { title: "Bewerbung angenommen", body: "Du kannst jetzt Events auf UniHub veröffentlichen." }
                : { title: "Application approved", body: "You can now publish events on UniHub." };
    case "request_rejected":
      return de ? { title: "Bewerbung nicht angenommen", body: "Details findest du in deinem Profil." }
                : { title: "Application not approved", body: "See your profile for details." };
    case "event_removed":
      return de ? { title: "Event entfernt", body: `${t} wurde nach einer Meldung entfernt.` }
                : { title: "Event removed", body: `${t} was removed after a report.` };
    default:
      return { title: "UniHub", body: t };
  }
}

// ---- Google OAuth token for FCM (service account JWT, RS256) -----------------------
type ServiceAccount = { project_id: string; client_email: string; private_key: string };
let cachedToken: { value: string; expires: number } | null = null;

function b64url(data: ArrayBuffer | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : new Uint8Array(data);
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function accessToken(sa: ServiceAccount): Promise<string> {
  if (cachedToken && cachedToken.expires > Date.now() + 60_000) return cachedToken.value;
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const pem = sa.private_key.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`));
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${b64url(sig)}`,
    }),
  });
  if (!res.ok) throw new Error(`google token ${res.status}`);
  const json = await res.json();
  cachedToken = { value: json.access_token, expires: Date.now() + json.expires_in * 1000 };
  return cachedToken.value;
}

// ---- sending -------------------------------------------------------------------------
type Outcome = "sent" | "bad_token" | "retry";

async function send(sa: ServiceAccount, target: Target, row: Row): Promise<Outcome> {
  const { title, body } = text(row, target.locale);
  const data: Record<string, string> = { kind: row.kind, notification_id: String(row.id) };
  if (row.event_id) data.event_id = row.event_id;
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${await accessToken(sa)}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      message: {
        token: target.token,
        notification: { title, body },
        data,
        android: { priority: "high", notification: { tag: `unihub-${row.id}` } },
      },
    }),
  });
  if (res.ok) return "sent";
  const err = await res.text();
  // The app was uninstalled or the token is no longer valid.
  if (res.status === 404 || (res.status === 400 && err.includes("registration token"))) return "bad_token";
  console.error("fcm", res.status, err.slice(0, 300));
  return "retry";
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });
  const secret = req.headers.get("x-push-secret") ?? "";
  const { data: ok } = await db.rpc("push_secret_ok", { p_secret: secret });
  if (ok !== true) return new Response("forbidden", { status: 403 });

  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) return new Response("push not configured", { status: 503 });
  const sa = JSON.parse(raw) as ServiceAccount;

  const summary = { sent: 0, skipped: 0, retry: 0, removed_devices: 0 };
  for (let round = 0; round < 5; round++) {
    const { data: rows, error } = await db.rpc("claim_push_batch", { p_limit: 200 });
    if (error) return new Response(`claim failed: ${error.message}`, { status: 500 });
    if (!rows || rows.length === 0) break;

    const users = [...new Set((rows as Row[]).map((r) => r.user_id))];
    const { data: targets, error: tErr } = await db.rpc("push_targets", { p_users: users });
    if (tErr) return new Response(`targets failed: ${tErr.message}`, { status: 500 });
    const byUser = new Map<string, Target[]>();
    for (const t of (targets ?? []) as Target[]) byUser.set(t.user_id, [...(byUser.get(t.user_id) ?? []), t]);

    const sent: number[] = [], skipped: number[] = [], retry: number[] = [], badTokens: string[] = [];
    for (const row of rows as Row[]) {
      const devices = byUser.get(row.user_id) ?? [];
      if (devices.length === 0) { skipped.push(row.id); continue; } // inbox only
      const results = await Promise.all(devices.map((d) => send(sa, d, row).catch((): Outcome => "retry")));
      results.forEach((r, i) => { if (r === "bad_token") badTokens.push(devices[i].token); });
      if (results.includes("sent")) sent.push(row.id);
      else if (results.includes("retry")) retry.push(row.id);
      else skipped.push(row.id); // every device was gone
    }
    if (sent.length) await db.rpc("finish_push", { p_ids: sent, p_state: "sent" });
    if (skipped.length) await db.rpc("finish_push", { p_ids: skipped, p_state: "skipped" });
    // Failed ones stay "sending"; the retry job picks them up again after 5 minutes.
    if (badTokens.length) await db.rpc("forget_push_tokens", { p_tokens: badTokens });
    summary.sent += sent.length; summary.skipped += skipped.length; summary.retry += retry.length;
    summary.removed_devices += badTokens.length;
    if (rows.length < 200) break;
  }
  return Response.json(summary);
});
