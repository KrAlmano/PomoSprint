// Bülten hoş geldin e-postası.
//
// marketing_subscribers'a satır eklenince invoke_send_welcome_email trigger'ı
// bu fonksiyonu net.http_post ile çağırır ({ record: <yeni satır> }). Trigger
// Authorization başlığı göndermediği için fonksiyon JWT doğrulaması KAPALI
// deploy edilir (önceden açıktı ve her çağrı 401 alıyordu; hiç e-posta
// gitmedi). Kötüye kullanıma karşı istek veritabanından doğrulanır:
//   * satır gerçekten var ve e-postası payload ile aynı,
//   * son 1 saatte eklenmiş,
//   * hoş geldin e-postası daha önce gönderilmemiş (welcome_sent_at).
// Böylece dışarıdan çağıran biri rastgele adreslere e-posta gönderemez.
//
// Gerekli secret: RESEND_API_KEY. Gönderici alan adı (mail.pomosprint.app)
// Resend'de doğrulanmış olmalı.
// Deploy: `supabase functions deploy send-welcome-email --no-verify-jwt`

import { createClient } from "npm:@supabase/supabase-js@2";

const FROM_ADDRESS = "PomoSprint <noreply@mail.pomosprint.app>";
const UNSUBSCRIBE_PAGE = "https://pomosprint.app/unsubscribe";
const MAX_AGE_MS = 60 * 60 * 1000;

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const resendKey = Deno.env.get("RESEND_API_KEY");
  if (!resendKey) {
    console.error("RESEND_API_KEY tanımlı değil");
    return json({ error: "Server misconfiguration" }, 500);
  }

  let record: { id?: string; email?: string } | undefined;
  try {
    record = (await req.json())?.record;
  } catch (_) {
    return json({ error: "Invalid payload" }, 400);
  }
  if (!record?.id || !record?.email) return json({ error: "Invalid payload" }, 400);

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  // Satırı "gönderiliyor" diye işaretleyerek sahiplen; aynı satıra ikinci
  // çağrı (yeniden deneme ya da kötüye kullanım) hiçbir şey yapmaz.
  const since = new Date(Date.now() - MAX_AGE_MS).toISOString();
  const { data: claimed, error: claimError } = await admin
    .from("marketing_subscribers")
    .update({ welcome_sent_at: new Date().toISOString() })
    .eq("id", record.id)
    .is("welcome_sent_at", null)
    .gte("subscribed_at", since)
    .select("id, email, unsubscribe_token")
    .maybeSingle();
  if (claimError) {
    console.error("abonelik satırı okunamadı:", claimError.message);
    return json({ error: "Database error" }, 500);
  }
  if (!claimed || String(claimed.email).toLowerCase() !== String(record.email).toLowerCase()) {
    return json({ skipped: true }, 200);
  }

  const email = String(claimed.email);
  const query = `email=${encodeURIComponent(email)}&token=${encodeURIComponent(String(claimed.unsubscribe_token))}`;
  const unsubscribePage = `${UNSUBSCRIBE_PAGE}?${query}`;
  const oneClickUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/unsubscribe?${query}`;

  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": `Bearer ${resendKey}` },
    body: JSON.stringify({
      from: FROM_ADDRESS,
      to: [email],
      subject: "PomoSprint Bültenine Hoş Geldin! 🚀",
      headers: {
        "List-Unsubscribe": `<${oneClickUrl}>`,
        "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
      },
      text:
        "Aramıza hoş geldin!\n\n" +
        "PomoSprint'in gelişimine ortak olduğun ve yeni özelliklerden haberdar olmak istediğin için teşekkürler. " +
        "Sana yalnızca önemli güncellemeleri, yeni özellikleri ve faydalı ipuçlarını göndereceğiz.\n\n" +
        `Artık e-posta almak istemiyorsan: ${unsubscribePage}`,
      html: `
        <div style="font-family: sans-serif; max-width: 500px; margin: 0 auto; color: #333;">
          <h2 style="color: #C2462F;">Aramıza Hoş Geldin! ⏳</h2>
          <p>Merhaba,</p>
          <p>PomoSprint'in gelişimine ortak olduğun ve yeni özelliklerden haberdar olmak istediğin için teşekkürler!</p>
          <p>Sana yalnızca önemli güncellemeleri, yeni özellikleri ve faydalı ipuçlarını göndereceğiz.</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;" />
          <p style="font-size: 12px; color: #777; text-align: center;">
            Bu e-postayı PomoSprint kaydında bülten iznini işaretlediğin için alıyorsun.<br/>
            Artık e-posta almak istemiyorsan <a href="${unsubscribePage}" style="color: #C2462F; text-decoration: underline;">abonelikten çıkabilirsin</a>.
          </p>
        </div>
      `,
    }),
  });

  if (!res.ok) {
    // Gönderilemediyse işareti geri al; bir sonraki denemede tekrar gidebilsin.
    await admin.from("marketing_subscribers").update({ welcome_sent_at: null }).eq("id", claimed.id);
    const detail = await res.text();
    console.error("Resend hatası:", res.status, detail);
    return json({ error: "Email provider error" }, 502);
  }

  return json({ sent: true }, 200);
});
