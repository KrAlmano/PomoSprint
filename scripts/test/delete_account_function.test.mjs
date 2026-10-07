// Gerçek Edge kaynak kodu; Supabase Auth/DB ve Apple HTTP tamamen sahtedir.
// Silme testleri gerçek kullanıcıya, Apple'a veya başka bir ağa bağlanmaz.
import assert from "node:assert/strict";
import { registerHooks } from "node:module";
import { before, beforeEach, test } from "node:test";
import { createClient as createQueryClient } from "./helpers/fake_supabase.mjs";

const BASE = "https://proj.supabase.co/functions/v1/delete-account";
const JWT = "authenticated-test-token";
const USER_ID = "caller-id";
const EMAIL = "ayse@example.com";
const ENV = {
  SUPABASE_URL: "https://proj.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "service-role-test",
};
const APPLE_ENV = {
  APPLE_TEAM_ID: "TESTTEAM",
  APPLE_KEY_ID: "TESTKEY",
  APPLE_CLIENT_ID: "com.pomosprint.test",
};

let handler;
let env;
let privateKey;
let publicKey;
let appleCalls;
let appleReplies;

before(async () => {
  // Aynı query sahtesine yalnızca bu test dosyasında Auth API'si eklenir;
  // diğer Edge testlerinin global/SDK davranışı değiştirilmez.
  const fakeUrl = "data:text/javascript," + encodeURIComponent(
    "export function createClient(...args) { return globalThis.__deleteAccountClient(...args); }",
  );
  registerHooks({
    resolve(specifier, context, nextResolve) {
      if (specifier === "npm:@supabase/supabase-js@2") return { url: fakeUrl, shortCircuit: true };
      return nextResolve(specifier, context);
    },
  });
  globalThis.__deleteAccountClient = (url, key) => {
    const queryClient = createQueryClient(url, key);
    return {
      ...queryClient,
      from(table) {
        const query = queryClient.from(table);
        const execute = query.exec.bind(query);
        query.exec = async (single) => {
          const result = await execute(single);
          // PostgREST'in varsayılan SELECT sınırı; geniş LIKE adayları
          // gerçek hedefi bu sınırın dışına itebilir. DELETE sınırlandırılmaz.
          if (query.action === "select" && !single && Array.isArray(result.data)) result.data = result.data.slice(0, 1000);
          return result;
        };
        return query;
      },
      auth: {
        async getUser(jwt) {
          const state = db();
          state.calls.push({ action: "getUser", jwt });
          if (jwt !== JWT || state.failures["auth.getUser"]) return { data: { user: null }, error: { message: "not authenticated" } };
          return { data: { user: state.user }, error: null };
        },
        admin: {
          async deleteUser(id) {
            const state = db();
            state.calls.push({ action: "deleteUser", id });
            if (state.failures["auth.deleteUser"]) return { error: { message: "delete unavailable" } };
            state.deleted.push(id);
            state.tables.marketing_subscribers = state.tables.marketing_subscribers.filter((row) => row.user_id !== id);
            return { error: null };
          },
        },
      },
    };
  };
  globalThis.Deno = {
    env: { get: (key) => env[key] },
    serve: (fn) => { handler = fn; },
  };
  await import("../../supabase/functions/delete-account/index.ts");
  assert.equal(typeof handler, "function");

  // Kullan-at test anahtarı: JWT imzası gerçek WebCrypto ile doğrulanır.
  const keys = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
  publicKey = keys.publicKey;
  const exported = await crypto.subtle.exportKey("pkcs8", keys.privateKey);
  privateKey = `-----BEGIN PRIVATE KEY-----\n${Buffer.from(exported).toString("base64")}\n-----END PRIVATE KEY-----`;
  globalThis.fetch = async (url, init) => {
    const endpoint = String(url);
    assert.ok(["https://appleid.apple.com/auth/token", "https://appleid.apple.com/auth/revoke"].includes(endpoint), "beklenmeyen ağ isteği yasak");
    const call = { url: endpoint, init, body: new URLSearchParams(init.body) };
    appleCalls.push(call);
    const reply = appleReplies.shift();
    assert.ok(reply, "her HTTP yanıtı testte açıkça sağlanmalı");
    if (reply.throw) throw new TypeError("mock network failure");
    return new Response(JSON.stringify(reply.body ?? {}), { status: reply.status ?? 200 });
  };
});

beforeEach(() => {
  env = { ...ENV };
  appleCalls = [];
  appleReplies = [];
  globalThis.__fakeDb = {
    user: { id: USER_ID, email: EMAIL, email_confirmed_at: "2026-10-07T08:00:00Z", app_metadata: { provider: "email", providers: ["email"] }, identities: [] },
    tables: {
      waitlist: [{ id: "w1", email: EMAIL }, { id: "w2", email: "Ayse@Example.com" }, { id: "other-w", email: "other@example.com" }],
      marketing_subscribers: [
        { id: "s1", email: ` ${EMAIL.toUpperCase()} `, user_id: null },
        { id: "own-s", email: EMAIL, user_id: USER_ID },
        { id: "foreign-s", email: EMAIL, user_id: "different-owner" },
        { id: "other-s", email: "other@example.com", user_id: null },
      ],
    },
    calls: [],
    failures: {},
    deleted: [],
  };
});

const db = () => globalThis.__fakeDb;
const ids = (table) => db().tables[table].map((row) => row.id);
const deleteCalls = () => db().calls.filter((call) => call.action === "deleteUser");
const invoke = (body = {}, { authorization = `Bearer ${JWT}`, method = "POST", rawBody } = {}) => {
  const headers = { "Content-Type": "application/json" };
  if (authorization !== null) headers.Authorization = authorization;
  return handler(new Request(BASE, { method, headers, ...(method === "POST" ? { body: rawBody ?? JSON.stringify(body) } : {}) }));
};
const appleUser = (metadata = { providers: ["apple"] }, identities = []) => {
  db().user.app_metadata = metadata;
  db().user.identities = identities;
};
const configureApple = () => Object.assign(env, APPLE_ENV, { APPLE_PRIVATE_KEY: privateKey });

test("Authorization yok/boş ya da JWT geçersizse hiçbir kayıt silinmez", async () => {
  for (const authorization of [null, "", "Bearer ", "Bearer invalid", "Basic invalid"]) {
    const response = await invoke({}, { authorization });
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), { error: "not_authenticated" });
  }
  assert.deepEqual(db().deleted, []);
  assert.ok(!db().calls.some((call) => call.action === "delete"));
});

test("Auth hata verir veya kullanıcı yoksa gövdedeki kimlikle silme yapılamaz", async () => {
  db().failures["auth.getUser"] = true;
  assert.equal((await invoke({ user_id: "victim" })).status, 401);
  delete db().failures["auth.getUser"];
  db().user = null;
  assert.equal((await invoke({ user_id: "victim" })).status, 401);
  assert.deepEqual(deleteCalls(), []);
});

test("GET 405; Auth ve DB çağrılmaz, yanıtlar no-store'dur", async () => {
  const response = await invoke({}, { method: "GET" });
  assert.equal(response.status, 405);
  assert.deepEqual(await response.json(), { error: "method_not_allowed" });
  assert.equal(response.headers.get("Cache-Control"), "no-store");
  assert.equal(db().calls.length, 0);
});

test("bozuk JSON, nesne olmayan gövde ve yanlış türde Apple kodu 400; silme başlamaz", async () => {
  for (const rawBody of ["{", "null", "[]", '"string"', "123", '{"apple_authorization_code":123}', '{"apple_authorization_code":null}']) {
    const response = await invoke({}, { rawBody });
    assert.equal(response.status, 400, rawBody);
    assert.deepEqual(await response.json(), { error: "invalid_payload" });
  }
  assert.deepEqual(deleteCalls(), []);
  assert.ok(!db().calls.some((call) => call.action === "delete"));
});

test("gövdesiz POST geçerli; non-Apple hesapta provider isteği yok", async () => {
  const response = await invoke({}, { rawBody: "" });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { deleted: true, apple: { status: "not_applicable" } });
  assert.deepEqual(db().deleted, [USER_ID]);
  assert.deepEqual(appleCalls, []);
});

test("yalnızca JWT kullanıcısı silinir; gövdedeki id/email hedef değiştiremez", async () => {
  const response = await invoke({ id: "victim-id", user_id: "victim-id", email: "other@example.com", apple_authorization_code: "unused" });
  assert.equal(response.status, 200);
  assert.deepEqual(db().deleted, [USER_ID]);
  assert.deepEqual(ids("waitlist"), ["other-w"]);
  assert.deepEqual(ids("marketing_subscribers"), ["foreign-s", "other-s"]);
  assert.deepEqual(appleCalls, []);
  assert.deepEqual(db().calls.map((call) => call.action), ["getUser", "delete", "delete", "deleteUser"]);
});

test("doğrulanmamış e-posta başka abonelik/waitlist kaydı silmez", async () => {
  db().user.email_confirmed_at = null;
  const response = await invoke();
  assert.equal(response.status, 200);
  assert.deepEqual(ids("waitlist"), ["w1", "w2", "other-w"]);
  assert.deepEqual(ids("marketing_subscribers"), ["s1", "foreign-s", "other-s"]);
  assert.deepEqual(db().calls.map((call) => call.action), ["getUser", "deleteUser"]);
});

test("email yoksa doğrulama alanı dolu olsa bile email temizliği yok", async () => {
  db().user.email = undefined;
  assert.equal((await invoke()).status, 200);
  assert.deepEqual(ids("waitlist"), ["w1", "w2", "other-w"]);
});

test("e-posta *, %, _, regex metakarakteri ve case farkı başka adresi eşlemez", async () => {
  const email = "qa*_%+.tag[1](x)|$^?\\@example.com";
  db().user.email = ` ${email.toUpperCase()} `;
  db().tables.waitlist = [
    { id: "target-w", email: email.toUpperCase() },
    { id: "unrelated-w", email: "qa_other@example.com" },
  ];
  db().tables.marketing_subscribers = [
    { id: "target-s", email: ` ${email} `, user_id: null },
    { id: "foreign-s", email, user_id: "different-owner" },
    { id: "unrelated-s", email: "qa_other@example.com", user_id: null },
  ];
  assert.equal((await invoke()).status, 200);
  assert.deepEqual(ids("waitlist"), ["unrelated-w"]);
  assert.deepEqual(ids("marketing_subscribers"), ["foreign-s", "unrelated-s"]);
  assert.ok(db().calls.filter((call) => call.action === "delete").every((call) => call.filters.some((filter) => filter[0] === "imatch")));
});

test("1000 satırdan sonraki exact eşleşme doğrudan DELETE ile atlanmaz", async () => {
  db().user.email = "qa_%@example.com";
  db().tables.waitlist = [
    ...Array.from({ length: 1100 }, (_, i) => ({ id: `unrelated-${i}`, email: `qa_${i}@example.com` })),
    { id: "matching", email: "QA_%@Example.com" },
  ];
  assert.equal((await invoke()).status, 200);
  assert.equal(db().tables.waitlist.length, 1100);
  assert.ok(!ids("waitlist").includes("matching"));
});

for (const table of ["waitlist", "marketing_subscribers"]) {
  test(`${table} temizleme hatası Auth'u korur; aynı JWT ile retry tamamlanır`, async () => {
    db().failures[`${table}.delete`] = "DB unavailable";
    const response = await invoke();
    assert.equal(response.status, 500);
    assert.deepEqual(await response.json(), { error: "delete_failed", apple: { status: "not_applicable" } });
    assert.deepEqual(db().deleted, []);
    assert.deepEqual(deleteCalls(), []);
    delete db().failures[`${table}.delete`];
    const retry = await invoke();
    assert.equal(retry.status, 200);
    assert.deepEqual(ids("waitlist"), ["other-w"]);
    assert.deepEqual(ids("marketing_subscribers"), ["foreign-s", "other-s"]);
    assert.deepEqual(db().deleted, [USER_ID]);
  });
}

test("email DELETE ağ hatasında Auth silinmez ve 500 döner", async () => {
  db().failures["waitlist.delete"] = () => { throw new TypeError("mock network failure"); };
  const response = await invoke();
  assert.equal(response.status, 500);
  assert.deepEqual(db().deleted, []);
  assert.deepEqual(deleteCalls(), []);
});

test("admin deleteUser hatası deleted:true göstermez; retry tamamlar", async () => {
  db().failures["auth.deleteUser"] = true;
  const response = await invoke();
  assert.equal(response.status, 500);
  assert.deepEqual(await response.json(), { error: "delete_failed", apple: { status: "not_applicable" } });
  assert.deepEqual(db().deleted, []);
  delete db().failures["auth.deleteUser"];
  assert.equal((await invoke()).status, 200);
  assert.deepEqual(db().deleted, [USER_ID]);
});

for (const [label, metadata, identities] of [
  ["providers", { providers: ["email", "apple"] }, []],
  ["provider", { provider: "apple" }, []],
  ["identities", {}, [{ provider: "apple" }]],
]) {
  test(`Apple ${label} kimliği kod yoksa açıklanarak atlanır; hesap yine silinir`, async () => {
    appleUser(metadata, identities);
    const response = await invoke();
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { deleted: true, apple: { status: "skipped", reason: "no_authorization_code" } });
    assert.deepEqual(db().deleted, [USER_ID]);
    assert.deepEqual(appleCalls, []);
  });
}

test("Apple kodu var ama config eksikse not_configured; ağ isteği olmadan siler", async () => {
  appleUser();
  const response = await invoke({ apple_authorization_code: "fresh-code" });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { deleted: true, apple: { status: "skipped", reason: "not_configured" } });
  assert.deepEqual(appleCalls, []);
});

test("Apple refresh token iptali önce tamamlanır; ES256 client_secret ve endpoint gövdeleri doğru", async () => {
  appleUser();
  configureApple();
  // Secret'ta literal \n bulunan PEM de desteklenmeli.
  env.APPLE_PRIVATE_KEY = privateKey.replace(/\n/g, "\\n");
  appleReplies.push({ body: { refresh_token: "refresh-token", access_token: "access-token" } }, { body: {} });
  const response = await invoke({ apple_authorization_code: " fresh-code " });
  assert.deepEqual(await response.json(), { deleted: true, apple: { status: "revoked" } });
  assert.equal(appleCalls.length, 2);
  const [exchange, revoke] = appleCalls;
  assert.equal(exchange.body.get("code"), "fresh-code");
  assert.equal(exchange.body.get("grant_type"), "authorization_code");
  assert.equal(revoke.body.get("token"), "refresh-token");
  assert.equal(revoke.body.get("token_type_hint"), "refresh_token");
  assert.equal(exchange.body.get("client_id"), APPLE_ENV.APPLE_CLIENT_ID);
  assert.equal(exchange.body.get("client_secret"), revoke.body.get("client_secret"));
  const secret = exchange.body.get("client_secret");
  const [head, payload, signature] = secret.split(".");
  assert.deepEqual(JSON.parse(Buffer.from(head, "base64url")), { alg: "ES256", kid: "TESTKEY", typ: "JWT" });
  const claims = JSON.parse(Buffer.from(payload, "base64url"));
  assert.equal(claims.iss, "TESTTEAM");
  assert.equal(claims.sub, APPLE_ENV.APPLE_CLIENT_ID);
  assert.equal(claims.aud, "https://appleid.apple.com");
  assert.equal(claims.exp - claims.iat, 300);
  assert.ok(await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, publicKey, Buffer.from(signature, "base64url"), new TextEncoder().encode(`${head}.${payload}`)));
  for (const call of appleCalls) {
    assert.equal(call.init.method, "POST");
    assert.equal(call.init.headers["Content-Type"], "application/x-www-form-urlencoded");
    assert.ok(call.init.signal instanceof AbortSignal);
  }
  assert.deepEqual(db().deleted, [USER_ID]);
});

test("Apple refresh token yoksa access token doğru hint ile iptal edilir", async () => {
  appleUser();
  configureApple();
  appleReplies.push({ body: { access_token: "access-token" } }, { body: {} });
  const response = await invoke({ apple_authorization_code: "fresh-code" });
  assert.deepEqual(await response.json(), { deleted: true, apple: { status: "revoked" } });
  assert.equal(appleCalls[1].body.get("token"), "access-token");
  assert.equal(appleCalls[1].body.get("token_type_hint"), "access_token");
});

for (const [reason, replies] of [
  ["token_exchange_failed", [{ status: 400, body: { error: "invalid_grant" } }]],
  ["no_token", [{ body: {} }]],
  ["revoke_failed", [{ body: { refresh_token: "refresh-token" } }, { status: 500 }]],
  ["apple_error", [{ throw: true }]],
]) {
  test(`Apple ${reason} sonucu kaybolmaz; kullanıcı hesabı yine silinir`, async () => {
    appleUser();
    configureApple();
    appleReplies.push(...replies);
    const response = await invoke({ apple_authorization_code: "fresh-code" });
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { deleted: true, apple: { status: "skipped", reason } });
    assert.deepEqual(db().deleted, [USER_ID]);
  });
}

test("Apple revoked durumu cleanup hatasının 500 yanıtında korunur", async () => {
  appleUser();
  configureApple();
  appleReplies.push({ body: { refresh_token: "refresh-token" } }, { body: {} });
  db().failures["waitlist.delete"] = "DB unavailable";
  const response = await invoke({ apple_authorization_code: "fresh-code" });
  assert.equal(response.status, 500);
  assert.deepEqual(await response.json(), { error: "delete_failed", apple: { status: "revoked" } });
  assert.deepEqual(db().deleted, []);
});
