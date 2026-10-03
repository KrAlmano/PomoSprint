// Bülten abonelikten çıkma uç noktası.
//
// Her abonenin marketing_subscribers.unsubscribe_token kolonunda tahmin
// edilemez bir UUID'si var (20261003150000_live_audit_fixes). Linkler bu
// token'ı taşır; token olmadan kimse listeden çıkarılamaz (önceden e-posta
// adresini bilen herkes başkasını çıkarabiliyordu).
//
// Kabul edilen istekler (yalnızca POST; GET silme YAPMAZ, çünkü e-posta
// güvenlik tarayıcıları linkleri GET ile açar):
//   POST ?email=..&token=..   RFC 8058 tek tık (List-Unsubscribe-Post)
//   POST {email, token}       landing/unsubscribe.html'in "Abonelikten çık" butonu
// email isteğe bağlıdır; verilirse token'ın sahibiyle eşleşmesi gerekir.
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

  // Adresin listede olup olmadığı açığa çıkmasın: bulunamayan ya da zaten
  // çıkmış token için de aynı başarılı yanıt.
  if (!row) return new Response("OK", { status: 200, headers });
  const rowEmail = String(row.email).trim().toLowerCase();
  if (email && email !== rowEmail) {
    return new Response("Forbidden", { status: 403, headers });
  }

  const { error: deleteError } = await admin.from("marketing_subscribers").delete().eq("id", row.id);
  if (deleteError) return new Response("Error", { status: 500, headers });

  // Lansman bekleme listesi de duyuru e-postası alır; oradan da çıkar.
  const { error: waitlistError } = await admin.from("waitlist").delete().eq("email", rowEmail);
  if (waitlistError) console.warn("waitlist silme hatası:", waitlistError.message);

  return new Response("OK", { status: 200, headers });
});
