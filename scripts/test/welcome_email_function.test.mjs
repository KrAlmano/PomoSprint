// supabase/functions/send-welcome-email/index.ts davranış testi (KVKK-11).
// E-postada hizmet sağlayıcı kimliği ve iletişim bilgisi olmalı, abonelikten
// çıkma bağlantıları e-posta adresini taşımamalı. Gönderen kimliği secret'ı
// yoksa e-posta gönderilmemeli. Resend ve Supabase sahtedir.
import assert from "node:assert/strict";
import { before, beforeEach, test } from "node:test";

import { loadEdgeFunction } from "./helpers/edge_harness.mjs";

const URL_ = "https://proj.supabase.co/functions/v1/send-welcome-email";
const TOKEN = "7d2b9c1e-2222-4333-8444-a55566667777";
const EMAIL = "ayse.yilmaz@example.com";
const ENV = {
  SUPABASE_URL: "https://proj.supabase.co/",
  SUPABASE_SERVICE_ROLE_KEY: "service-role-test",
  RESEND_API_KEY: "re_test_key",
  MAIL_SENDER_NAME: "Test Gönderen",
  MAIL_SENDER_ADDRESS: "Örnek Mah. Test Sok. No:1, İstanbul",
};

let fn;
let sent;
let resendStatus;

before(async () => {
  fn = await loadEdgeFunction("supabase/functions/send-welcome-email/index.ts", ENV);
  globalThis.fetch = async (url, init) => {
    sent.push({ url: String(url), init, body: JSON.parse(init.body) });
    return new Response(resendStatus === 200 ? '{"id":"email_1"}' : '{"message":"fail"}', { status: resendStatus });
  };
});

beforeEach(() => {
  Object.assign(fn.env, ENV);
  sent = [];
  resendStatus = 200;
  globalThis.__fakeDb = {
    tables: {
      marketing_subscribers: [{
        id: "s1",
        email: EMAIL,
        unsubscribe_token: TOKEN,
        subscribed_at: new Date().toISOString(),
        welcome_sent_at: null,
      }],
    },
    calls: [],
    failures: {},
  };
});

const row = () => globalThis.__fakeDb.tables.marketing_subscribers[0];
const invoke = (record = { id: "s1", email: EMAIL }) =>
  fn.handler(new Request(URL_, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ record }),
  }));

test("abonelikten çıkma bağlantıları yalnızca token taşır, e-posta adresi URL'de yok", async () => {
  const res = await invoke();
  assert.equal(res.status, 200);
  assert.equal(sent.length, 1);
  const { body } = sent[0];
  assert.deepEqual(body.to, [EMAIL]);
  assert.equal(
    body.headers["List-Unsubscribe"],
    `<https://proj.supabase.co/functions/v1/unsubscribe?token=${TOKEN}>`,
  );
  assert.equal(body.headers["List-Unsubscribe-Post"], "List-Unsubscribe=One-Click");
  const pageUrl = `https://pomosprint.app/unsubscribe?token=${TOKEN}`;
  assert.ok(body.html.includes(`href="${pageUrl}"`));
  assert.ok(body.text.includes(pageUrl));
  for (const part of [body.html, body.text, body.headers["List-Unsubscribe"]]) {
    assert.ok(!part.includes("email="), "bağlantıda email parametresi olmamalı");
    assert.ok(!part.includes(EMAIL) && !part.includes(encodeURIComponent(EMAIL)), "adres gövdede/bağlantıda geçmemeli");
  }
  assert.ok(row().welcome_sent_at, "gönderilen satır işaretlenir");
});

test("altbilgide gönderen kimliği, iletişim, gizlilik/KVKK bağlantıları ve 'neden' cümlesi var", async () => {
  await invoke();
  const { html, text } = sent[0].body;
  for (const part of [html, text]) {
    assert.ok(part.includes("Test Gönderen"));
    assert.ok(part.includes("Örnek Mah. Test Sok. No:1, İstanbul"));
    assert.ok(part.includes("destek@pomosprint.app"));
    assert.ok(part.includes("https://pomosprint.app/privacy"));
    assert.ok(part.includes("https://pomosprint.app/kvkk"));
    assert.ok(part.includes("bülten iznini işaretlediğin için alıyorsun"));
  }
});

test("gönderen kimliği HTML'de kaçışlanır", async () => {
  fn.env.MAIL_SENDER_NAME = 'A & B <script>x</script> "Ltd"';
  await invoke();
  const { html } = sent[0].body;
  assert.ok(html.includes("A &amp; B &lt;script&gt;x&lt;/script&gt; &quot;Ltd&quot;"));
  assert.ok(!html.includes("<script>"));
});

for (const missing of ["MAIL_SENDER_NAME", "MAIL_SENDER_ADDRESS"]) {
  test(`${missing} yoksa e-posta gönderilmez ve satır sahiplenilmez`, async () => {
    fn.env[missing] = "   ";
    const res = await invoke();
    assert.equal(res.status, 500);
    assert.equal(sent.length, 0);
    assert.equal(row().welcome_sent_at, null);
    assert.equal(globalThis.__fakeDb.calls.length, 0, "veritabanına dokunulmaz");
  });
}

test("Resend hata verirse 502 ve welcome_sent_at geri alınır", async () => {
  resendStatus = 500;
  const res = await invoke();
  assert.equal(res.status, 502);
  assert.equal(row().welcome_sent_at, null);
});

test("daha önce gönderilmişse ya da e-posta uyuşmuyorsa gönderim yok", async () => {
  row().welcome_sent_at = "2026-10-03T08:00:00.000Z";
  const already = await invoke();
  assert.deepEqual(await already.json(), { skipped: true });

  row().welcome_sent_at = null;
  const mismatch = await invoke({ id: "s1", email: "mallory@example.com" });
  assert.deepEqual(await mismatch.json(), { skipped: true });
  assert.equal(sent.length, 0);
});

test("bir saatten eski satıra gönderim yok", async () => {
  row().subscribed_at = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString();
  const res = await invoke();
  assert.deepEqual(await res.json(), { skipped: true });
  assert.equal(sent.length, 0);
});
