// supabase/functions/unsubscribe/index.ts davranış testi (KVKK-11).
// Yeni e-postalar yalnızca ?token=<uuid> taşır; eski ?email=..&token=..
// bağlantıları da çalışmaya devam etmeli. Supabase istemcisi sahtedir.
import assert from "node:assert/strict";
import { before, beforeEach, test } from "node:test";

import { loadEdgeFunction } from "./helpers/edge_harness.mjs";

const BASE = "https://proj.supabase.co/functions/v1/unsubscribe";
const TOKEN = "3f1c2a4e-1111-4222-8333-944455556666";
const UNKNOWN_TOKEN = "00000000-aaaa-4bbb-8ccc-dddddddddddd";

let fn;

before(async () => {
  fn = await loadEdgeFunction("supabase/functions/unsubscribe/index.ts", {
    SUPABASE_URL: "https://proj.supabase.co",
    SUPABASE_SERVICE_ROLE_KEY: "service-role-test",
  });
});

beforeEach(() => {
  globalThis.__fakeDb = {
    tables: {
      marketing_subscribers: [{ id: "s1", email: "Ayse@Example.com", unsubscribe_token: TOKEN }],
      waitlist: [
        { id: "w1", email: "ayse@example.com" },
        { id: "w2", email: "baska@example.com" },
      ],
    },
    calls: [],
    failures: {},
  };
});

const db = () => globalThis.__fakeDb;
const call = (url, init = {}) => fn.handler(new Request(url, init));
const subscriberIds = () => db().tables.marketing_subscribers.map((r) => r.id);
const waitlistIds = () => db().tables.waitlist.map((r) => r.id);
const deletes = () => db().calls.filter((c) => c.action === "delete");

test("tek tık (RFC 8058) yalnızca token ile aboneyi ve bekleme listesi kaydını siler", async () => {
  const res = await call(`${BASE}?token=${TOKEN}`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: "List-Unsubscribe=One-Click",
  });
  assert.equal(res.status, 200);
  assert.deepEqual(subscriberIds(), []);
  assert.deepEqual(waitlistIds(), ["w2"], "yalnızca abonenin adresi bekleme listesinden çıkar");
});

test("sayfa butonu: URL'de yalnızca token, gövdede token", async () => {
  const res = await call(`${BASE}?token=${TOKEN}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: TOKEN }),
  });
  assert.equal(res.status, 200);
  assert.deepEqual(subscriberIds(), []);
});

test("token yalnızca gövdede de kabul edilir", async () => {
  const res = await call(BASE, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: TOKEN }),
  });
  assert.equal(res.status, 200);
  assert.deepEqual(subscriberIds(), []);
});

test("eski e-posta+token bağlantısı çalışmaya devam eder (büyük/küçük harf duyarsız)", async () => {
  const res = await call(`${BASE}?email=${encodeURIComponent("ayse@example.com")}&token=${TOKEN}`, {
    method: "POST",
  });
  assert.equal(res.status, 200);
  assert.deepEqual(subscriberIds(), []);
});

test("sayfa eski bağlantıdan gelince e-postayı gövdede gönderir; eşleşirse siler", async () => {
  const res = await call(`${BASE}?token=${TOKEN}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: TOKEN, email: "AYSE@example.com" }),
  });
  assert.equal(res.status, 200);
  assert.deepEqual(subscriberIds(), []);
});

test("e-posta token'ın sahibiyle uyuşmazsa 403 ve hiçbir şey silinmez", async () => {
  const viaUrl = await call(`${BASE}?email=${encodeURIComponent("mallory@example.com")}&token=${TOKEN}`, {
    method: "POST",
  });
  assert.equal(viaUrl.status, 403);
  const viaBody = await call(`${BASE}?token=${TOKEN}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: TOKEN, email: "mallory@example.com" }),
  });
  assert.equal(viaBody.status, 403);
  assert.deepEqual(subscriberIds(), ["s1"]);
  assert.deepEqual(waitlistIds(), ["w1", "w2"]);
  assert.equal(deletes().length, 0);
});

test("GET hiçbir şey silmez (405): e-posta tarayıcıları bağlantıyı açabilir", async () => {
  const res = await call(`${BASE}?token=${TOKEN}`);
  assert.equal(res.status, 405);
  assert.deepEqual(subscriberIds(), ["s1"]);
  assert.equal(db().calls.length, 0);
});

test("token yoksa ya da UUID değilse 400", async () => {
  for (const url of [BASE, `${BASE}?token=abc`, `${BASE}?email=ayse%40example.com`]) {
    const res = await call(url, { method: "POST" });
    assert.equal(res.status, 400, url);
  }
  assert.deepEqual(subscriberIds(), ["s1"]);
});

test("bilinmeyen token 200 döner ama hiçbir satırı silmez (adres listede mi, belli olmaz)", async () => {
  const res = await call(`${BASE}?token=${UNKNOWN_TOKEN}`, { method: "POST" });
  assert.equal(res.status, 200);
  assert.deepEqual(subscriberIds(), ["s1"]);
  assert.deepEqual(waitlistIds(), ["w1", "w2"]);
  assert.equal(deletes().length, 0);
});

test("OPTIONS (CORS ön isteği) yalnızca site kökenine izin verir", async () => {
  const res = await call(BASE, { method: "OPTIONS", headers: { Origin: "https://evil.example" } });
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("Access-Control-Allow-Origin"), "https://pomosprint.app");
  assert.match(res.headers.get("Access-Control-Allow-Methods"), /POST/);
});
