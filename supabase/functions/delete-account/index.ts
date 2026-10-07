// Uygulama içi hesap silme (App Store 5.1.1(v), Google Play).
//
// Sign in with Apple ile bağlı hesapta önce Apple token'ı iptal edilir
// (Apple: "Apps that support Sign in with Apple should use the Sign in with
// Apple REST API to revoke user tokens"), sonra kullanıcı silinir.
//
// İstek (yalnızca POST, JWT ZORUNLU; verify_jwt AÇIK deploy edilir):
//   Authorization: Bearer <kullanıcının access token'ı>
//   { "apple_authorization_code"?: string }   // iOS'ta silmeden hemen önce
//                                             // getAppleIDCredential ile alınan taze kod
// Yanıt 200:
//   { "deleted": true,
//     "apple": { "status": "revoked" | "skipped" | "not_applicable",
//                "reason"?: "no_authorization_code" | "not_configured" |
//                           "token_exchange_failed" | "no_token" |
//                           "revoke_failed" | "apple_error" } }
// Hata: 400 invalid_payload, 401 not_authenticated, 405,
// 500 delete_failed (+ apple). Bu fonksiyon
// 404 DÖNDÜRMEZ: istemci 404'ü "fonksiyon deploy edilmemiş", 5xx'i
// "çalışamadı" sayıp delete_own_account RPC'sine düşer.
//
// Secret'lar (Apple iptali için; yoksa iptal atlanır ve yanıtta söylenir):
//   APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_CLIENT_ID (com.pomosprint.app),
//   APPLE_PRIVATE_KEY (Sign in with Apple yetkili .p8 anahtarının PEM metni)
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY Edge runtime'da hazır gelir.
//
// Silme sırası supabase/proposed/12_delete_own_account.sql ile aynı:
//   1. Yalnızca e-postası DOĞRULANMIŞ hesapta, e-postaya bağlı ve yabancı
//      anahtarı olmayan kayıtlar: waitlist ve user_id'si boş
//      marketing_subscribers satırları.
//   2. auth.users (admin.deleteUser): profiles, study_sessions, categories,
//      friendships, league_memberships, activity_feed, avatar_unlocks,
//      marketing_subscribers(user_id), auth.identities/sessions cascade.

import { createClient, type SupabaseClient, type User } from "npm:@supabase/supabase-js@2";

const APPLE_AUDIENCE = "https://appleid.apple.com";
const APPLE_TOKEN_URL = "https://appleid.apple.com/auth/token";
const APPLE_REVOKE_URL = "https://appleid.apple.com/auth/revoke";
const APPLE_TIMEOUT_MS = 10_000;

type AppleStatus = "revoked" | "skipped" | "not_applicable";
type AppleResult = { status: AppleStatus; reason?: string };
type AppleConfig = { teamId: string; keyId: string; clientId: string; privateKey: string };

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function appleConfig(): AppleConfig | null {
  const teamId = Deno.env.get("APPLE_TEAM_ID")?.trim() ?? "";
  const keyId = Deno.env.get("APPLE_KEY_ID")?.trim() ?? "";
  const clientId = Deno.env.get("APPLE_CLIENT_ID")?.trim() ?? "";
  const privateKey = Deno.env.get("APPLE_PRIVATE_KEY") ?? "";
  if (!teamId || !keyId || !clientId || !privateKey.trim()) return null;
  return { teamId, keyId, clientId, privateKey };
}

function base64url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// .p8 PEM metni (secret'ta satır sonları "\n" olarak kaçışlı da olabilir) → PKCS#8 DER.
function pemToPkcs8(pem: string): ArrayBuffer {
  const body = pem
    .replace(/\\n/g, "\n")
    .replace(/-----BEGIN [A-Z ]+-----/, "")
    .replace(/-----END [A-Z ]+-----/, "")
    .replace(/\s+/g, "");
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

// Apple client_secret: ES256 imzalı kısa ömürlü JWT (en çok 6 ay; burada 5 dk).
async function appleClientSecret(cfg: AppleConfig): Promise<string> {
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToPkcs8(cfg.privateKey),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "ES256", kid: cfg.keyId, typ: "JWT" };
  const payload = { iss: cfg.teamId, iat: now, exp: now + 300, aud: APPLE_AUDIENCE, sub: cfg.clientId };
  const signingInput = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`;
  // WebCrypto ECDSA imzası JWS'nin istediği ham r||s (64 bayt) biçimindedir.
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64url(new Uint8Array(signature))}`;
}

async function applePost(url: string, params: Record<string, string>): Promise<Response> {
  return await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(params),
    signal: AbortSignal.timeout(APPLE_TIMEOUT_MS),
  });
}

// authorizationCode → refresh_token (/auth/token), sonra /auth/revoke.
async function revokeAppleTokens(code: string, cfg: AppleConfig): Promise<AppleResult> {
  const clientSecret = await appleClientSecret(cfg);
  const tokenRes = await applePost(APPLE_TOKEN_URL, {
    client_id: cfg.clientId,
    client_secret: clientSecret,
    code,
    grant_type: "authorization_code",
  });
  if (!tokenRes.ok) {
    // Kod ve token günlüğe yazılmaz; yalnızca Apple'ın hata kodu.
    const err = await tokenRes.json().catch(() => ({}));
    console.warn("apple token exchange failed:", tokenRes.status, (err as { error?: string })?.error ?? "");
    return { status: "skipped", reason: "token_exchange_failed" };
  }
  const tokens = await tokenRes.json() as { refresh_token?: string; access_token?: string };
  const token = tokens.refresh_token ?? tokens.access_token;
  if (!token) return { status: "skipped", reason: "no_token" };

  const revokeRes = await applePost(APPLE_REVOKE_URL, {
    client_id: cfg.clientId,
    client_secret: clientSecret,
    token,
    token_type_hint: tokens.refresh_token ? "refresh_token" : "access_token",
  });
  if (!revokeRes.ok) {
    console.warn("apple revoke failed:", revokeRes.status);
    return { status: "skipped", reason: "revoke_failed" };
  }
  return { status: "revoked" };
}

function hasAppleIdentity(user: User): boolean {
  const providers = user.app_metadata?.providers;
  if (Array.isArray(providers) && providers.includes("apple")) return true;
  if (user.app_metadata?.provider === "apple") return true;
  return user.identities?.some((i) => i.provider === "apple") ?? false;
}

// E-postaya bağlı, yabancı anahtarı olmayan kayıtlar (proposed/12 ile aynı
// kural: lower(btrim(email)) eşleşmesi). PostgREST ILIKE'da '*' da jokerdir;
// literal ve baştan/sondan sabitlenmiş regex doğrudan DELETE'te kullanılır.
// Adayları SELECT ile almak PostgREST satır sınırında eşleşmeyi atlayabilirdi.
async function deleteEmailLinkedRows(admin: SupabaseClient, email: string): Promise<boolean> {
  const literal = email.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const pattern = `^ *${literal} *$`;
  for (const table of ["waitlist", "marketing_subscribers"]) {
    try {
      let query = admin.from(table).delete().filter("email", "imatch", pattern);
      if (table === "marketing_subscribers") query = query.is("user_id", null);
      const { error } = await query;
      if (!error) continue;
      console.warn(`${table} silinemedi:`, error.message);
    } catch (_) {
      console.warn(`${table} silme isteği tamamlanamadı`);
    }
    // Auth satırı korunur: kullanıcı veya istemcinin SQL yedeği yeniden
    // deneyebilir. Kısmi temizliği tamamlanmış silme diye göstermeyiz.
    return false;
  }
  return true;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!jwt) return json({ error: "not_authenticated" }, 401);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  // Kullanıcı yalnızca çağıranın JWT'sinden alınır; gövdedeki hiçbir kimliğe güvenilmez.
  const { data: userData, error: userError } = await admin.auth.getUser(jwt);
  const user = userData?.user;
  if (userError || !user) return json({ error: "not_authenticated" }, 401);

  let body: Record<string, unknown> = {};
  try {
    const rawBody = await req.text();
    if (rawBody.trim()) body = JSON.parse(rawBody);
  } catch (_) {
    return json({ error: "invalid_payload" }, 400);
  }
  // Gövdesiz POST geçerli; bozuk JSON veya yanlış türde Apple kodu hesabı
  // silmeye başlamamalı. Gövdedeki kullanıcı kimlikleri yine kullanılmaz.
  if (!body || typeof body !== "object" || Array.isArray(body)) return json({ error: "invalid_payload" }, 400);
  const rawCode = body?.apple_authorization_code;
  if (rawCode !== undefined && typeof rawCode !== "string") return json({ error: "invalid_payload" }, 400);
  const code = typeof rawCode === "string" ? rawCode.trim() : "";

  let apple: AppleResult = { status: "not_applicable" };
  if (hasAppleIdentity(user)) {
    const cfg = appleConfig();
    if (!code) {
      apple = { status: "skipped", reason: "no_authorization_code" };
    } else if (!cfg) {
      apple = { status: "skipped", reason: "not_configured" };
    } else {
      try {
        apple = await revokeAppleTokens(code, cfg);
      } catch (e) {
        console.warn("apple revoke error:", e instanceof Error ? e.name : "unknown");
        apple = { status: "skipped", reason: "apple_error" };
      }
    }
  }

  const email = user.email_confirmed_at && user.email ? user.email.trim().toLowerCase() : "";
  if (email && !await deleteEmailLinkedRows(admin, email)) return json({ error: "delete_failed", apple }, 500);

  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) {
    console.error("deleteUser failed:", deleteError.message);
    return json({ error: "delete_failed", apple }, 500);
  }

  return json({ deleted: true, apple });
});
