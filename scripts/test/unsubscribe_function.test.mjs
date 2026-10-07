// supabase/functions/unsubscribe/index.ts davranış testi (KVKK-11).
// Yeni e-postalar yalnızca ?token=<uuid> taşır; eski ?email=..&token=..
// bağlantıları da çalışmaya devam etmeli. Supabase istemcisi sahtedir.
import assert from "node:assert/strict";
import { before, beforeEach, test } from "node:test";

import { loadEdgeFunction } from "./helpers/edge_harness.mjs";

const BASE = "https://proj.supabase.co/functions/v1/unsubscribe";
const TOKEN = "3f1c2a4e-1111-4222-8333-944455556666";
const WAITLIST_TOKEN = "7a1c2a4e-1111-4222-8333-944455556666";
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
        { id: "w1", email: "ayse@example.com", unsubscribe_token: WAITLIST_TOKEN },
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

test("waitlist-only token bekleme listesini gerçekten siler; başka adres korunur", async () => {
  db().tables.marketing_subscribers = [];
  const res = await call(`${BASE}?token=${WAITLIST_TOKEN}`, { method: "POST" });
  assert.equal(res.status, 200);
  assert.deepEqual(waitlistIds(), ["w2"]);
  const again = await call(`${BASE}?token=${WAITLIST_TOKEN}`, { method: "POST" });
  assert.equal(again.status, 200, "tekrarlanan link aynı başarılı yanıtı verir");
});

test("waitlist token aynı adresin bülten aboneliğini de case farkına rağmen siler", async () => {
  const res = await call(`${BASE}?token=${WAITLIST_TOKEN}`, { method: "POST" });
  assert.equal(res.status, 200);
  assert.deepEqual(subscriberIds(), []);
  assert.deepEqual(waitlistIds(), ["w2"]);
});

test("waitlist token eski bağlantıda başka e-postayla gelirse hiçbir satır silinmez", async () => {
  const res = await call(`${BASE}?token=${WAITLIST_TOKEN}&email=mallory%40example.com`, { method: "POST" });
  assert.equal(res.status, 403);
  assert.deepEqual(subscriberIds(), ["s1"]);
  assert.deepEqual(waitlistIds(), ["w1", "w2"]);
  assert.equal(deletes().length, 0);
});

test("bülten token: waitlist silme hatasında yanlış başarı yok, token korunur ve retry tamamlanır", async () => {
  db().failures["waitlist.delete"] = "database unavailable";
  const failed = await call(`${BASE}?token=${TOKEN}`, { method: "POST" });
  assert.equal(failed.status, 500);
  assert.deepEqual(subscriberIds(), ["s1"], "retry için token'ın sahibi kalmalı");
  assert.deepEqual(waitlistIds(), ["w1", "w2"]);
  delete db().failures["waitlist.delete"];
  const retry = await call(`${BASE}?token=${TOKEN}`, { method: "POST" });
  assert.equal(retry.status, 200);
  assert.deepEqual(subscriberIds(), []);
  assert.deepEqual(waitlistIds(), ["w2"]);
});

test("waitlist token: bülten silme hatasında token korunur ve retry iki listeyi temizler", async () => {
  db().failures["marketing_subscribers.delete"] = "database unavailable";
  const failed = await call(`${BASE}?token=${WAITLIST_TOKEN}`, { method: "POST" });
  assert.equal(failed.status, 500);
  assert.deepEqual(waitlistIds(), ["w1", "w2"], "retry için token'ın sahibi kalmalı");
  assert.deepEqual(subscriberIds(), ["s1"]);
  delete db().failures["marketing_subscribers.delete"];
  const retry = await call(`${BASE}?token=${WAITLIST_TOKEN}`, { method: "POST" });
  assert.equal(retry.status, 200);
  assert.deepEqual(subscriberIds(), []);
  assert.deepEqual(waitlistIds(), ["w2"]);
});

test("token sahibinin son silme adımı başarısızsa kısmi işlem aynı linkle tamamlanır", async () => {
  db().failures["marketing_subscribers.delete"] = (query) =>
    query.filters.some(([op, col]) => op === "eq" && col === "id") && "database unavailable";
  const failed = await call(`${BASE}?token=${TOKEN}`, { method: "POST" });
  assert.equal(failed.status, 500);
  assert.deepEqual(waitlistIds(), ["w2"]);
  assert.deepEqual(subscriberIds(), ["s1"]);
  delete db().failures["marketing_subscribers.delete"];
  const retry = await call(`${BASE}?token=${TOKEN}`, { method: "POST" });
  assert.equal(retry.status, 200);
  assert.deepEqual(subscriberIds(), []);
});

test("e-postadaki % ve _ karakterleri başka adresleri eşleyen joker olamaz", async () => {
  db().tables.marketing_subscribers[0].email = "qa_%@example.com";
  db().tables.waitlist = [
    { id: "matching", email: "QA_%@Example.com" },
    { id: "unrelated", email: "qa_other@example.com" },
  ];
  const res = await call(`${BASE}?token=${TOKEN}`, { method: "POST" });
  assert.equal(res.status, 200);
  assert.deepEqual(waitlistIds(), ["unrelated"]);
});

test("token lookup DB hataları 500 döner; bilinmeyen token gibi yanlış başarı verilmez", async () => {
  for (const table of ["marketing_subscribers", "waitlist"]) {
    db().failures[`${table}.select`] = "database unavailable";
    const failed = await call(`${BASE}?token=${UNKNOWN_TOKEN}`, { method: "POST" });
    assert.equal(failed.status, 500);
    assert.equal(deletes().length, 0);
    delete db().failures[`${table}.select`];
  }
});

test("waitlist token aynı adresin case-variant kayıtlarının tümünü çıkarır", async () => {
  db().tables.waitlist.push({ id: "w3", email: "AYSE@Example.com", unsubscribe_token: UNKNOWN_TOKEN });
  const res = await call(`${BASE}?token=${WAITLIST_TOKEN}`, { method: "POST" });
  assert.equal(res.status, 200);
  assert.deepEqual(subscriberIds(), []);
  assert.deepEqual(waitlistIds(), ["w2"], "diğer token'lı case-variant satır da silinir");
  assert.deepEqual(deletes().at(-1).filters, [["eq", "id", "w1"]], "yeniden deneme token'ı en son silinir");
  const repeated = await call(`${BASE}?token=${UNKNOWN_TOKEN}`, { method: "POST" });
  assert.equal(repeated.status, 200);
  assert.deepEqual(waitlistIds(), ["w2"]);
});

test("case-variant temizliği başarısızsa token korunur ve aynı bağlantıyla tamamlanır", async () => {
  db().tables.waitlist.push({ id: "w3", email: "AYSE@Example.com", unsubscribe_token: UNKNOWN_TOKEN });
  db().failures["waitlist.delete"] = (query) =>
    query.filters.some(([op]) => op === "neq") && "database unavailable";
  const failed = await call(`${BASE}?token=${WAITLIST_TOKEN}`, { method: "POST" });
  assert.equal(failed.status, 500);
  assert.deepEqual(subscriberIds(), [], "ilk listede tamamlanan işlem tekrarlanabilir");
  assert.deepEqual(waitlistIds(), ["w1", "w2", "w3"]);
  delete db().failures["waitlist.delete"];
  const retry = await call(`${BASE}?token=${WAITLIST_TOKEN}`, { method: "POST" });
  assert.equal(retry.status, 200);
  assert.deepEqual(waitlistIds(), ["w2"]);
});

test("case-variant kayıt silindikten sonra token sahibi silinemese bile aynı link çalışır", async () => {
  db().tables.waitlist.push({ id: "w3", email: "AYSE@Example.com", unsubscribe_token: UNKNOWN_TOKEN });
  db().failures["waitlist.delete"] = (query) =>
    query.filters.some(([op, col]) => op === "eq" && col === "id") && "database unavailable";
  const failed = await call(`${BASE}?token=${WAITLIST_TOKEN}`, { method: "POST" });
  assert.equal(failed.status, 500);
  assert.deepEqual(waitlistIds(), ["w1", "w2"], "yalnız case-variant silindi; token sahibi kaldı");
  delete db().failures["waitlist.delete"];
  const retry = await call(`${BASE}?token=${WAITLIST_TOKEN}`, { method: "POST" });
  assert.equal(retry.status, 200);
  assert.deepEqual(waitlistIds(), ["w2"]);
});

test("PostgREST * aliası iki token yolunda da başka adresleri silmez", async () => {
  for (const token of [TOKEN, WAITLIST_TOKEN]) {
    db().tables.marketing_subscribers = [
      { id: "s1", email: "qa*@example.com", unsubscribe_token: TOKEN },
      { id: "s2", email: "qa_other@example.com", unsubscribe_token: UNKNOWN_TOKEN },
    ];
    db().tables.waitlist = [
      { id: "w1", email: "QA*@Example.com", unsubscribe_token: WAITLIST_TOKEN },
      { id: "w2", email: "qa_other@example.com" },
      { id: "w3", email: "qa*@example.com" },
    ];
    const res = await call(`${BASE}?token=${token}`, { method: "POST" });
    assert.equal(res.status, 200);
    assert.deepEqual(subscriberIds(), ["s2"]);
    assert.deepEqual(waitlistIds(), ["w2"]);
  }
});

test("literal regex %/_ ve bütün regex metakarakterlerini tam adres olarak eşler", async () => {
  db().tables.marketing_subscribers[0].email = "qa_%.*+?^${}()|[x]\\@example.com";
  db().tables.waitlist = [
    { id: "matching", email: "QA_%.*+?^${}()|[X]\\@Example.com" },
    { id: "unrelated", email: "qa_other@example.com" },
    { id: "unrelated-prefix", email: "prefixqa_%.*+?^${}()|[x]\\@example.com" },
  ];
  const res = await call(`${BASE}?token=${TOKEN}`, { method: "POST" });
  assert.equal(res.status, 200);
  assert.deepEqual(waitlistIds(), ["unrelated", "unrelated-prefix"]);
});

test("mail güvenlik tarayıcısının GET/OPTIONS istekleri case-variant kayıtları değiştirmez", async () => {
  db().tables.waitlist.push({ id: "w3", email: "AYSE@Example.com", unsubscribe_token: UNKNOWN_TOKEN });
  const original = structuredClone(db().tables);
  const url = `${BASE}?token=${WAITLIST_TOKEN}&email=ayse%40example.com`;
  assert.equal((await call(url, { method: "GET" })).status, 405);
  assert.equal((await call(url, { method: "OPTIONS" })).status, 200);
  assert.deepEqual(db().tables, original);
  assert.equal(db().calls.length, 0);
});
