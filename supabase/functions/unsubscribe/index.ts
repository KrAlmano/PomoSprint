// Bülten abonelikten çıkma uç noktası.
//
// Her abonenin marketing_subscribers.unsubscribe_token veya
// waitlist.unsubscribe_token kolonunda tahmin edilemez bir UUID'si var
// (live_audit_fixes ve proposed/19 A). Linkler bu
// token'ı taşır; token olmadan kimse listeden çıkarılamaz (önceden e-posta
// adresini bilen herkes başkasını çıkarabiliyordu).
//
// Kabul edilen istekler (yalnızca POST; GET silme YAPMAZ, çünkü e-posta
// güvenlik tarayıcıları linkleri GET ile açar):
//   POST ?token=..            RFC 8058 tek tık (List-Unsubscribe-Post); 3 Ekim
//                             sonrası e-postalar yalnızca token taşır
//   POST ?email=..&token=..   eski e-postalardaki tek tık bağlantısı
//   POST ?token=.. {token, email?}  landing/unsubscribe.html'in butonu
// email isteğe bağlıdır; verilirse token'ın sahibiyle eşleşmesi gerekir.
// Davranış scripts/test/unsubscribe_function.test.mjs ile sınanır.
//
// JWT doğrulaması KAPALI deploy edilir (e-posta istemcisi Authorization
// başlığı göndermez): `supabase functions deploy unsubscribe --no-verify-jwt`

import { createClient } from "npm:@supabase/supabase-js@2";

const ALLOWED_ORIGINS = new Set([
  "https://pomosprint.app",
  "https://www.pomosprint.app",
]);

const UUID_TOKEN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin") ?? "";
  return {
    "Access-Control-Allow-Origin": ALLOWED_ORIGINS.has(origin) ? origin : "https://pomosprint.app",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type",
    "Vary": "Origin",
  };
}

// E-posta ve token'ı önce URL'den, yoksa POST gövdesinden okur.
async function readParams(req: Request): Promise<{ email: string; token: string }> {
  const url = new URL(req.url);
  let email = url.searchParams.get("email") ?? "";
  let token = url.searchParams.get("token") ?? "";

  if (!email || !token) {
    const type = req.headers.get("content-type") ?? "";
    try {
      if (type.includes("application/json")) {
        const body = await req.json();
        email = email || String(body?.email ?? "");
        token = token || String(body?.token ?? "");
      } else if (type.includes("application/x-www-form-urlencoded") || type.includes("multipart/form-data")) {
        const form = await req.formData();
        email = email || String(form.get("email") ?? "");
        token = token || String(form.get("token") ?? "");
      }
    } catch (_) {
      // Bozuk gövde: aşağıdaki token kontrolü 400 döndürür.
    }
  }
  return { email: email.trim().toLowerCase(), token: token.trim().toLowerCase() };
}

Deno.serve(async (req) => {
  const headers = corsHeaders(req);
  if (req.method === "OPTIONS") return new Response(null, { headers });
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405, headers });
  }

  const { email, token } = await readParams(req);
  if (!UUID_TOKEN.test(token) || email.length > 254) {
    return new Response("Bad request", { status: 400, headers });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  const { data: row, error: readError } = await admin
    .from("marketing_subscribers")
    .select("id, email")
    .eq("unsubscribe_token", token)
    .maybeSingle();
  if (readError) return new Response("Error", { status: 500, headers });

  let tokenRow = row;
  let tokenTable = "marketing_subscribers";
  if (!tokenRow) {
    const { data: waitlistRow, error: waitlistReadError } = await admin
      .from("waitlist")
      .select("id, email")
      .eq("unsubscribe_token", token)
      .maybeSingle();
    if (waitlistReadError) return new Response("Error", { status: 500, headers });
    tokenRow = waitlistRow;
    tokenTable = "waitlist";
  }

  // Adresin listede olup olmadığı açığa çıkmasın: bulunamayan ya da zaten
  // çıkmış token için de aynı başarılı yanıt.
  if (!tokenRow) return new Response("OK", { status: 200, headers });
  const rowEmail = String(tokenRow.email).trim().toLowerCase();
  if (email && email !== rowEmail) {
    return new Response("Forbidden", { status: 403, headers });
  }

  // Önce diğer listeyi sil. Ağ/DB hatasında token'ın sahibi yerinde kalır:
  // kullanıcı aynı bağlantıyla yeniden deneyebilir. Sabitlenmiş literal
  // regex, PostgREST ILIKE'ın * joker takma adını da devre dışı bırakır.
  const otherTable = tokenTable === "waitlist" ? "marketing_subscribers" : "waitlist";
  const literalEmail = "^" + rowEmail.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$";
  const { error: otherDeleteError } = await admin.from(otherTable).delete().filter("email", "imatch", literalEmail);
  if (otherDeleteError) return new Response("Error", { status: 500, headers });

  // waitlist UNIQUE(email) büyük/küçük harfe duyarlıdır. Aynı adresin
  // farklı yazımlarını da çıkar; retry token'ını taşıyan satır en son gider.
  const { error: siblingDeleteError } = await admin.from(tokenTable).delete()
    .filter("email", "imatch", literalEmail).neq("id", tokenRow.id);
  if (siblingDeleteError) return new Response("Error", { status: 500, headers });

  const { error: tokenDeleteError } = await admin.from(tokenTable).delete().eq("id", tokenRow.id);
  if (tokenDeleteError) return new Response("Error", { status: 500, headers });

  return new Response("OK", { status: 200, headers });
});
