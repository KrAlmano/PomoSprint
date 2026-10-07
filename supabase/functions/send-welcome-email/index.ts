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
// Gerekli secret'lar:
//   RESEND_API_KEY       Gönderici alan adı (mail.pomosprint.app) Resend'de
//                        doğrulanmış olmalı.
//   MAIL_SENDER_NAME     Hizmet sağlayıcının (veri sorumlusunun) adı-soyadı ya
//   MAIL_SENDER_ADDRESS  da unvanı ve iletişim adresi; e-posta altbilgisinde
//                        yazılır (KVKK-11, KVKK-15). Kodda bilgi UYDURULMAZ:
//                        ikisinden biri yoksa e-posta GÖNDERİLMEZ (500).
// Abonelikten çıkma bağlantıları yalnızca token taşır (?token=<uuid>); e-posta
// adresi URL'ye, dolayısıyla istek günlüklerine ve tarayıcı geçmişine girmez.
// Deploy (önce secret'lar):
//   supabase secrets set MAIL_SENDER_NAME="..." MAIL_SENDER_ADDRESS="..."
//   supabase functions deploy send-welcome-email --no-verify-jwt

import { createClient } from "npm:@supabase/supabase-js@2";

const FROM_ADDRESS = "PomoSprint <noreply@mail.pomosprint.app>";
const SUPPORT_EMAIL = "destek@pomosprint.app";
const UNSUBSCRIBE_PAGE = "https://pomosprint.app/unsubscribe";
const PRIVACY_URL = "https://pomosprint.app/privacy";
const KVKK_URL = "https://pomosprint.app/kvkk";
const MAX_AGE_MS = 60 * 60 * 1000;
const SEND_TIMEOUT_MS = 10_000;

const literalEmailPattern = (value: string) =>
  `^${value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}$`;

const escapeHtml = (value: string) =>
  value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const resendKey = Deno.env.get("RESEND_API_KEY");
  if (!resendKey) {
    console.error("RESEND_API_KEY tanımlı değil");
    return json({ error: "Server misconfiguration" }, 500);
  }
  // Gönderen kimliği olmadan ticari ileti gönderilmez (satır sahiplenilmeden
  // önce kontrol edilir; welcome_sent_at boş kalır).
  const senderName = (Deno.env.get("MAIL_SENDER_NAME") ?? "").trim();
  const senderAddress = (Deno.env.get("MAIL_SENDER_ADDRESS") ?? "").trim();
  if (!senderName || !senderAddress) {
    console.error("MAIL_SENDER_NAME / MAIL_SENDER_ADDRESS tanımlı değil; e-posta gönderilmedi");
    return json({ error: "Server misconfiguration" }, 500);
  }

  let record: { id?: string; email?: string } | undefined;
  try {
    record = (await req.json())?.record;
  } catch (_) {
    return json({ error: "Invalid payload" }, 400);
  }
  if (typeof record?.id !== "string" || !record.id.trim() ||
      typeof record.email !== "string" || !record.email.trim()) {
    return json({ error: "Invalid payload" }, 400);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  // Satırı "gönderiliyor" diye işaretleyerek sahiplen; aynı satıra ikinci
  // çağrı (yeniden deneme ya da kötüye kullanım) hiçbir şey yapmaz.
  const since = new Date(Date.now() - MAX_AGE_MS).toISOString();
  const claimTime = new Date().toISOString();
  const { data: claimed, error: claimError } = await admin
    .from("marketing_subscribers")
    .update({ welcome_sent_at: claimTime })
    .eq("id", record.id)
    // E-posta eşleşmesi de atomik UPDATE içinde olmalı. Yanlış payload önce
    // sahiplenilip sonra elenirse gerçek abonenin maili kalıcı olarak atlanır.
    // PostgREST ILIKE '*' değerini '%' jokerine çevirir. İki ucu sabit,
    // regex karakterleri kaçışlı imatch ise adresi literal/case-insensitive eşler.
    .filter("email", "imatch", literalEmailPattern(record.email.trim()))
    .is("welcome_sent_at", null)
    .gte("subscribed_at", since)
    .select("id, email, unsubscribe_token")
    .maybeSingle();
  if (claimError) {
    console.error("abonelik satırı sahiplenilemedi");
    return json({ error: "Database error" }, 500);
  }
  if (!claimed) {
    return json({ skipped: true }, 200);
  }

  const email = String(claimed.email);
  // Yalnızca token: e-posta adresi bağlantıya konmaz.
  const query = `token=${encodeURIComponent(String(claimed.unsubscribe_token))}`;
  const unsubscribePage = `${UNSUBSCRIBE_PAGE}?${query}`;
  const oneClickUrl = `${String(Deno.env.get("SUPABASE_URL")).replace(/\/+$/, "")}/functions/v1/unsubscribe?${query}`;

  const releaseClaim = async () => {
    try {
      const { error } = await admin.from("marketing_subscribers")
        .update({ welcome_sent_at: null })
        .eq("id", claimed.id)
        .eq("welcome_sent_at", claimTime);
      if (!error) return true;
    } catch (_) {
      // SDK/ağ hataları da aynı açık DB hata sonucunu verir.
    }
    console.error("hoş geldin e-postası sahiplenme işareti geri alınamadı");
    return false;
  };

  const sendRequest = {
    method: "POST",
    signal: AbortSignal.timeout(SEND_TIMEOUT_MS),
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${resendKey}`,
      // Provider yanıtı kaybolsa bile aynı kayıt için yeniden gönderim tek
      // e-posta üretir. Resend anahtarı 24 saat korur; kabul penceremiz 1 saat.
      "Idempotency-Key": `welcome-subscriber/${claimed.id}`,
    },
    body: JSON.stringify({
      from: FROM_ADDRESS,
      to: [email],
      subject: "PomoSprint'e hoş geldin! ⏳",
      headers: {
        "List-Unsubscribe": `<${oneClickUrl}>`,
        "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
      },
      text:
        "PomoSprint'e hoş geldin!\n\n" +
        "Seni aramızda görmekten çok mutluyuz. Hedefin ne olursa olsun, bugün atacağın küçük bir adım yarın büyük fark yaratır. " +
        "Hiç zaman kaybetmeden ilk 25 dakikalık sprintini başlat!\n\n" +
        "Bu bültende sana yalnızca önemli güncellemeleri, yeni özellikleri ve odaklanmana yardımcı olacak ipuçlarını göndereceğiz.\n\n" +
        "Keyifli çalışmalar,\nPomoSprint Ekibi\n\n" +
        "Bu e-postayı PomoSprint kaydında bülten iznini işaretlediğin için alıyorsun.\n" +
        `Artık e-posta almak istemiyorsan: ${unsubscribePage}\n\n` +
        `Gönderen: ${senderName}, ${senderAddress}\n` +
        `İletişim: ${SUPPORT_EMAIL}\n` +
        `Gizlilik Politikası: ${PRIVACY_URL}\n` +
        `KVKK Aydınlatma Metni: ${KVKK_URL}`,
      html: `
        <div style="font-family: sans-serif; max-width: 500px; margin: 0 auto; color: #333;">
          <h2 style="color: #C2462F;">PomoSprint'e hoş geldin! ⏳</h2>
          <p>Merhaba,</p>
          <p>Seni aramızda görmekten çok mutluyuz! 🎉</p>
          <p>Hedefin ne olursa olsun, bugün atacağın küçük bir adım yarın büyük fark yaratır. Hiç zaman kaybetmeden ilk 25 dakikalık sprintini başlat!</p>
          <p>Bu bültende sana yalnızca önemli güncellemeleri, yeni özellikleri ve odaklanmana yardımcı olacak ipuçlarını göndereceğiz.</p>
          <p>Keyifli çalışmalar,<br/>PomoSprint Ekibi</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;" />
          <p style="font-size: 12px; color: #777; text-align: center;">
            Bu e-postayı PomoSprint kaydında bülten iznini işaretlediğin için alıyorsun.<br/>
            Artık e-posta almak istemiyorsan <a href="${unsubscribePage}" style="color: #C2462F; text-decoration: underline;">abonelikten çıkabilirsin</a>.
          </p>
          <p style="font-size: 12px; color: #777; text-align: center;">
            Gönderen: ${escapeHtml(senderName)}, ${escapeHtml(senderAddress)}<br/>
            İletişim: <a href="mailto:${SUPPORT_EMAIL}" style="color: #777;">${SUPPORT_EMAIL}</a> ·
            <a href="${PRIVACY_URL}" style="color: #777;">Gizlilik Politikası</a> ·
            <a href="${KVKK_URL}" style="color: #777;">KVKK Aydınlatma Metni</a>
          </p>
        </div>
      `,
    }),
  };
  let res: Response;
  try {
    res = await fetch("https://api.resend.com/emails", sendRequest);
  } catch (_) {
    console.error("Resend isteği tamamlanamadı");
    if (!await releaseClaim()) return json({ error: "Database error" }, 500);
    return json({ error: "Email provider error" }, 502);
  }

  if (!res.ok) {
    // Gönderilemediyse işareti geri al; bir sonraki denemede tekrar gidebilsin.
    if (!await releaseClaim()) return json({ error: "Database error" }, 500);
    console.error("Resend hatası:", res.status);
    return json({ error: "Email provider error" }, 502);
  }

  return json({ sent: true }, 200);
});
