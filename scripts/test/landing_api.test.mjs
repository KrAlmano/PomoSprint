import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { test } from "node:test";
import { REPO, plain, settle } from "./helpers/fake_dom.mjs";

function setup(fetch) {
  const timers = new Map();
  let timerId = 0;
  const window = {};
  const context = vm.createContext({
    window, fetch, AbortController,
    setTimeout: (callback) => { timers.set(++timerId, callback); return timerId; },
    clearTimeout: (id) => timers.delete(id),
  });
  vm.runInContext(fs.readFileSync(path.join(REPO, "landing/js/config.js"), "utf8"), context);
  return { api: window.PomoSupabase, timers };
}

test("landing API: response gövdesi beklenirken timeout etkin kalır", async () => {
  const { api, timers } = setup((_url, options) => Promise.resolve({
    ok: true, status: 200,
    text: () => new Promise((_resolve, reject) => options.signal.addEventListener("abort", () => reject(Object.assign(new Error("timed out"), { name: "AbortError" })), { once: true })),
  }));
  const pending = api.request("/qa");
  await settle();
  assert.equal(timers.size, 1, "headers geldi diye gövde timeout'u kaldırılmamalı");
  for (const callback of timers.values()) callback();
  await assert.rejects(pending, { name: "AbortError" });
  assert.equal(timers.size, 0);
});

test("landing API: başarılı JSON/boş/metin yanıtları timeout'u temizler", async () => {
  for (const [body, expected] of [['{"success":true}', { success: true }], ["", null], ["not JSON", null]]) {
    const { api, timers } = setup(() => Promise.resolve({ ok: true, status: 200, text: () => Promise.resolve(body) }));
    const result = await api.request("/qa");
    assert.deepEqual(plain(result), { ok: true, status: 200, data: expected });
    assert.equal(timers.size, 0);
  }
});

test("landing API: POST metadatası body'de, token yalnızca Authorization'da", async () => {
  let call;
  const { api } = setup((url, options) => {
    call = { url, options };
    return Promise.resolve({ ok: true, status: 201, text: () => Promise.resolve("") });
  });
  await api.request("/qa", { body: { email: "qa@example.invalid" }, token: "qa-private-token", prefer: "return=minimal" });
  assert.doesNotMatch(call.url, /qa-private-token|qa@example/);
  assert.equal(call.options.headers.Authorization, "Bearer qa-private-token");
  assert.equal(call.options.body, '{"email":"qa@example.invalid"}');
  assert.equal(call.options.credentials, "omit");
  assert.equal(call.options.cache, "no-store");
});

test("landing API: fetch ya da body hatasında timeout temizlenir ve hata üst katmana gider", async () => {
  for (const fetch of [
    () => Promise.reject(new Error("network unavailable")),
    () => Promise.resolve({ text: () => Promise.reject(new Error("body interrupted")) }),
  ]) {
    const { api, timers } = setup(fetch);
    await assert.rejects(api.request("/qa"));
    assert.equal(timers.size, 0);
  }
});
