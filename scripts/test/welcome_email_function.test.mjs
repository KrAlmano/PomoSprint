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
let resendThrow;

before(async () => {
  fn = await loadEdgeFunction("supabase/functions/send-welcome-email/index.ts", ENV);
  globalThis.fetch = async (url, init) => {
    sent.push({ url: String(url), init, body: JSON.parse(init.body) });
    if (resendThrow) throw new TypeError("Network failed");
    return new Response(resendStatus === 200 ? '{"id":"email_1"}' : '{"message":"fail"}', { status: resendStatus });
  };
});

beforeEach(() => {
  Object.assign(fn.env, ENV);
  sent = [];
  resendStatus = 200;
  resendThrow = false;
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
  assert.equal(row().welcome_sent_at, null, "yanlış adres geçerli abonenin hoş geldin mailini engellememeli");
  const correct = await invoke();
  assert.deepEqual(await correct.json(), { sent: true });
});

test("bir saatten eski satıra gönderim yok", async () => {
  row().subscribed_at = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString();
  const res = await invoke();
  assert.deepEqual(await res.json(), { skipped: true });
  assert.equal(sent.length, 0);
});

test("ağ kesintisi 502 döner, işaret geri alınır ve aynı anahtarla tekrar denenir", async () => {
  resendThrow = true;
  const failed = await invoke();
  assert.equal(failed.status, 502);
  assert.deepEqual(await failed.json(), { error: "Email provider error" });
  assert.equal(row().welcome_sent_at, null);
  assert.ok(sent[0].init.signal instanceof AbortSignal, "Resend isteğinin sınırlı bekleme süresi olmalı");
  const key = sent[0].init.headers["Idempotency-Key"];
  assert.equal(key, "welcome-subscriber/s1");
  resendThrow = false;
  const retry = await invoke();
  assert.deepEqual(await retry.json(), { sent: true });
  assert.equal(sent[1].init.headers["Idempotency-Key"], key);
  const repeated = await invoke();
  assert.deepEqual(await repeated.json(), { skipped: true });
  assert.equal(sent.length, 2, "başarılı kayda üçüncü provider isteği gitmemeli");
});

test("adres karşılaştırması büyük harfi kabul eder, LIKE jokerlerini literal eşler", async () => {
  row().email = "a_b%tag@example.com";
  const mismatch = await invoke({ id: "s1", email: "axbZZtag@example.com" });
  assert.deepEqual(await mismatch.json(), { skipped: true });
  assert.equal(row().welcome_sent_at, null);
  const match = await invoke({ id: "s1", email: "A_B%TAG@EXAMPLE.COM" });
  assert.deepEqual(await match.json(), { sent: true });
  assert.deepEqual(sent[0].body.to, ["a_b%tag@example.com"]);
});

test("PostgREST yıldız/regex jokeri gerçek abonenin e-postası yerine geçmez", async () => {
  for (const email of ["*", "*@example.com", ".*@example.com", "ayse.yilmaz@.*"]) {
    const mismatch = await invoke({ id: "s1", email });
    assert.deepEqual(await mismatch.json(), { skipped: true });
    assert.equal(row().welcome_sent_at, null);
  }
  assert.equal(sent.length, 0);
  row().email = "a*b+tag@example.com";
  const match = await invoke({ id: "s1", email: "A*B+TAG@EXAMPLE.COM" });
  assert.deepEqual(await match.json(), { sent: true });
  assert.deepEqual(sent[0].body.to, ["a*b+tag@example.com"]);
});

test("yanlış payload, yöntem ve olmayan kayıt gönderim başlatmaz", async () => {
  const malformed = await invoke({ id: { invalid: true }, email: EMAIL });
  assert.equal(malformed.status, 400);
  const method = await fn.handler(new Request(URL_, { method: "GET" }));
  assert.equal(method.status, 405);
  const missing = await invoke({ id: "absent", email: EMAIL });
  assert.deepEqual(await missing.json(), { skipped: true });
  assert.equal(sent.length, 0);
  assert.equal(row().welcome_sent_at, null);
});

test("DB sahiplenme hatasında gönderim yapılmaz", async () => {
  globalThis.__fakeDb.failures["marketing_subscribers.update"] = "DB unavailable";
  const res = await invoke();
  assert.equal(res.status, 500);
  assert.deepEqual(await res.json(), { error: "Database error" });
  assert.equal(sent.length, 0);
});

test("iki eşzamanlı webhook yalnızca bir provider gönderimi başlatır", async () => {
  const responses = await Promise.all([invoke(), invoke()]);
  const bodies = await Promise.all(responses.map((res) => res.json()));
  assert.deepEqual(bodies.filter((body) => body.sent), [{ sent: true }]);
  assert.deepEqual(bodies.filter((body) => body.skipped), [{ skipped: true }]);
  assert.equal(sent.length, 1);
});

test("provider hatasında geri alma da bozulursa DB hatası açıkça döner", async () => {
  globalThis.fetch = async (_url, init) => {
    sent.push({ init });
    globalThis.__fakeDb.failures["marketing_subscribers.update"] = "DB unavailable";
    return new Response('{"message":"fail"}', { status: 500 });
  };
  try {
    const res = await invoke();
    assert.equal(res.status, 500);
    assert.deepEqual(await res.json(), { error: "Database error" });
    assert.ok(row().welcome_sent_at, "geri alma başarısızlığı gizlenmemeli");
  } finally {
    globalThis.fetch = async (url, init) => {
      sent.push({ url: String(url), init, body: JSON.parse(init.body) });
      if (resendThrow) throw new TypeError("Network failed");
      return new Response(resendStatus === 200 ? '{"id":"email_1"}' : '{"message":"fail"}', { status: resendStatus });
    };
  }
});
