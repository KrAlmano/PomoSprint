// Bülten abonelikten çıkma uç noktası.
//
// Link biçimi: /functions/v1/unsubscribe?email=<e-posta>&token=<hmac>
// token = HMAC-SHA256(UNSUBSCRIBE_SECRET, lower(trim(email))) — hex.
// Token scripts/send_newsletter.js tarafından üretilir. Token doğrulanmadan
// kimse listeden çıkarılmaz; aksi halde e-posta adresini bilen herkes
// başkasını listeden çıkarabilirdi.
//
// Gerekli secret'lar: UNSUBSCRIBE_SECRET (send_newsletter.js ile aynı),
// SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY (Supabase tarafından sağlanır).
// JWT doğrulaması kapalı deploy edilmeli: `supabase functions deploy unsubscribe --no-verify-jwt`

import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://pomosprint.app",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
};

async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (req.method !== "GET") return new Response("Method not allowed", { status: 405, headers: corsHeaders });

  const secret = Deno.env.get("UNSUBSCRIBE_SECRET");
  if (!secret) return new Response("Server misconfigured", { status: 500, headers: corsHeaders });

  const url = new URL(req.url);
  const email = (url.searchParams.get("email") ?? "").trim().toLowerCase();
  const token = (url.searchParams.get("token") ?? "").trim().toLowerCase();
  if (!email || !token) return new Response("Bad request", { status: 400, headers: corsHeaders });

  const expected = await hmacHex(secret, email);
  if (!timingSafeEqual(expected, token)) {
    return new Response("Forbidden", { status: 403, headers: corsHeaders });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
  // Büyük/küçük harf duyarsız eşleşme; '_' ve '%' joker karakter olarak
  // yorumlanıp başka adresleri silmesin diye kaçışlanır.
  const pattern = email.replace(/[\\%_]/g, (c) => `\\${c}`);
  const { error } = await admin.from("marketing_subscribers").delete().ilike("email", pattern);
  if (error) return new Response("Error", { status: 500, headers: corsHeaders });

  return new Response("OK", { status: 200, headers: corsHeaders });
});
