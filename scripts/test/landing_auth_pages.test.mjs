// Gerçek yardımcı sayfa betikleri; istekler sahte API'ye gider, mail/hesap yok.
import assert from "node:assert/strict";
import { test } from "node:test";
import { FakeElement, createPage, plain, settle } from "./helpers/fake_dom.mjs";

function setupReset({ search = "", hash = "", language = "tr", respond } = {}) {
  const calls = [];
  const api = {
    request(path, opts) {
      calls.push({ path, opts });
      return respond ? respond(path, opts) : Promise.resolve({ ok: true, status: 200, data: {} });
    },
    errorCode: (data) => data?.error_code || data?.code || "",
  };
  const els = Object.fromEntries(["icon", "title", "message", "form", "pw1", "pw2", "submit", "error", "username"].map((id) => [id, new FakeElement(id)]));
  els.form.hidden = true;
  const page = createPage(els, { search, hash, language, pathname: "/reset-password", api });
  page.run("landing/js/auth-i18n.js");
  page.run("landing/js/reset-password.js");
  return { page, els, calls };
}

async function submit(ctx, p1 = "TestPassword1", p2 = p1) {
  ctx.els.pw1.value = p1;
  ctx.els.pw2.value = p2;
  ctx.els.form.dispatch("submit");
  await settle();
}

test("reset: eksik ve eski PKCE bağlantıları geçersiz, istek yapılmaz", () => {
  for (const search of ["", "?code=old-code"]) {
    const { els, calls } = setupReset({ search });
    assert.equal(els.form.hidden, true);
    assert.match(els.title.textContent, /Geçersiz/);
    assert.equal(calls.length, 0);
  }
});

test("reset: token_hash açılışta tüketilmez; hassas parametreler URL'den silinir", () => {
  const { page, els, calls } = setupReset({ search: "?token_hash=single-use&type=recovery&lang=en" });
  assert.equal(calls.length, 0);
  assert.equal(els.form.hidden, false);
  assert.deepEqual(page.replaced, ["/reset-password"]);
  assert.equal(page.window.location.search, "");
  assert.match(els.message.textContent, /Enter a new password/);
});

test("reset: kısa, uzun veya farklı şifreler token doğrulaması başlatmaz", async () => {
  for (const [p1, p2, message] of [["abc", "abc", /en az 8/], ["a".repeat(73), "a".repeat(73), /en fazla 72/], ["Abc12345", "Abc12346", /eşleşmiyor/]]) {
    const ctx = setupReset({ search: "?token_hash=single-use&type=recovery" });
    await submit(ctx, p1, p2);
    assert.equal(ctx.calls.length, 0);
    assert.match(ctx.els.error.textContent, message);
    assert.equal(ctx.els.form.hidden, false);
  }
});

test("reset: yedi karakter reddedilir, sekiz karakter güncel Auth alt sınırını geçer", async () => {
  const ctx = setupReset({ hash: "#access_token=qa-recovery-token&type=recovery" });
  await submit(ctx, "Abc1234");
  assert.equal(ctx.calls.length, 0);
  assert.match(ctx.els.error.textContent, /en az 8/);
  await submit(ctx, "Abc12345");
  assert.equal(ctx.calls[0].path, "/auth/v1/user");
  assert.equal(ctx.els.form.hidden, true);
});

test("reset: implicit recovery şifreyi günceller, yalnızca kurtarma oturumunu kapatır", async () => {
  const ctx = setupReset({ hash: "#access_token=qa-recovery-token&type=recovery" });
  assert.equal(ctx.page.window.location.hash, "");
  await submit(ctx);
  assert.deepEqual(ctx.calls.map((x) => x.path), ["/auth/v1/user", "/auth/v1/logout?scope=local"]);
  assert.equal(ctx.calls[0].opts.method, "PUT");
  assert.equal(ctx.calls[0].opts.token, "qa-recovery-token");
  assert.deepEqual(plain(ctx.calls[0].opts.body), { password: "TestPassword1" });
  assert.match(ctx.els.title.textContent, /Güncellendi/);
  assert.equal(ctx.els.form.hidden, true);
});

test("reset: zayıf şifreden sonraki denemede tek kullanımlık token tekrar doğrulanmaz", async () => {
  let updates = 0;
  const ctx = setupReset({ search: "?token_hash=single-use&type=recovery", respond(path) {
    if (path === "/auth/v1/verify") return Promise.resolve({ ok: true, status: 200, data: { access_token: "qa-recovery-token" } });
    if (path === "/auth/v1/user" && ++updates === 1) return Promise.resolve({ ok: false, status: 422, data: { code: "weak_password", weak_password: { reasons: ["pwned"] } } });
    return Promise.resolve({ ok: true, status: 200, data: {} });
  }});
  await submit(ctx);
  assert.match(ctx.els.error.textContent, /veri sızıntısında/);
  assert.equal(ctx.els.form.hidden, false);
  assert.equal(ctx.els.submit.disabled, false);
  await submit(ctx, "DifferentPassword2");
  assert.equal(ctx.calls.filter((x) => x.path === "/auth/v1/verify").length, 1);
  assert.equal(ctx.calls.filter((x) => x.path === "/auth/v1/user").length, 2);
  assert.equal(ctx.els.form.hidden, true);
});

test("reset: süresi dolmuş token formu kapatır; sunucu hata açıklaması basılmaz", async () => {
  const ctx = setupReset({ search: "?token_hash=expired&type=recovery", respond: () => Promise.resolve({ ok: false, status: 403, data: { code: "otp_expired", error_description: "UNTRUSTED SERVER TEXT" } }) });
  await submit(ctx);
  assert.equal(ctx.els.form.hidden, true);
  assert.match(ctx.els.message.textContent, /süresi dolmuş/);
  assert.doesNotMatch(ctx.els.message.textContent, /UNTRUSTED/);
});

async function verifyRetry(firstResponse, expectedMessage) {
  let verifies = 0;
  const ctx = setupReset({ search: "?token_hash=single-use&type=recovery", respond(path) {
    if (path === "/auth/v1/verify") {
      if (++verifies === 1) return Promise.resolve(firstResponse);
      return Promise.resolve({ ok: true, status: 200, data: { access_token: "qa-recovery-token" } });
    }
    return Promise.resolve({ ok: true, status: 200, data: {} });
  }});
  await submit(ctx);
  assert.equal(ctx.els.form.hidden, false, "geçici doğrulama hatası formu kapatmamalı");
  assert.equal(ctx.els.submit.disabled, false);
  assert.match(ctx.els.error.textContent, expectedMessage);
  assert.equal(ctx.calls.length, 1, "başarısız doğrulamada şifre güncellemesi yapılmamalı");
  await submit(ctx);
  const attempts = ctx.calls.filter((x) => x.path === "/auth/v1/verify");
  assert.equal(attempts.length, 2);
  for (const attempt of attempts) assert.deepEqual(plain(attempt.opts.body), { type: "recovery", token_hash: "single-use" });
  assert.equal(ctx.calls.filter((x) => x.path === "/auth/v1/user").length, 1);
  assert.match(ctx.els.title.textContent, /Güncellendi/);
  assert.equal(ctx.els.form.hidden, true);
}

test("reset: doğrulamada 5xx formu ve token'ı korur, yeniden deneme tamamlanır", async () => {
  for (const response of [
    { ok: false, status: 500, data: { code: "unexpected_failure", message: "UNTRUSTED SERVER TEXT" } },
    { ok: false, status: 503, data: null },
  ]) await verifyRetry(response, /Şifre güncellenemedi/);
});

test("reset: doğrulamada kodsuz ya da bilinmeyen 429 yeniden denenebilir hız sınırı gösterir", async () => {
  for (const data of [null, { code: "unknown_rate_limit" }]) {
    await verifyRetry({ ok: false, status: 429, data }, /çok fazla deneme/);
  }
});

test("reset: doğrulamada eksik veya bozuk başarılı yanıt bağlantıyı süresi dolmuş saymaz", async () => {
  for (const data of [null, {}, { access_token: {} }, { access_token: "   " }]) {
    await verifyRetry({ ok: true, status: 200, data }, /Şifre güncellenemedi/);
  }
});

test("reset: doğrulamadaki kalıcı bağlantı ve yetki hataları formu kapatır", async () => {
  for (const response of [
    { ok: false, status: 403, data: { code: "otp_expired" } },
    { ok: false, status: 401, data: null },
    { ok: false, status: 403, data: { code: "unexpected_authorization_error" } },
  ]) {
    const ctx = setupReset({ search: "?token_hash=single-use&type=recovery", respond: () => Promise.resolve(response) });
    await submit(ctx);
    assert.equal(ctx.els.form.hidden, true);
    assert.match(ctx.els.title.textContent, /Geçersiz/);
    assert.equal(ctx.calls.length, 1);
  }
});

test("reset: ağ kesintisi formu korur ve yeniden denemeye izin verir", async () => {
  const ctx = setupReset({ hash: "#access_token=qa-recovery-token&type=recovery", respond: () => Promise.reject(Object.assign(new Error("aborted"), { name: "AbortError" })) });
  await submit(ctx);
  assert.equal(ctx.els.form.hidden, false);
  assert.equal(ctx.els.submit.disabled, false);
  assert.match(ctx.els.error.textContent, /Bağlantı hatası/);
});

function setupConfirmed({ search = "", hash = "", language = "tr" } = {}) {
  const calls = [];
  const els = Object.fromEntries(["icon", "title", "message", "home-link"].map((id) => [id, new FakeElement(id)]));
  const api = { request: (path, opts) => { calls.push({ path, opts }); return Promise.resolve({ ok: true }); } };
  const page = createPage(els, { search, hash, language, pathname: "/confirmed", api });
  page.run("landing/js/auth-i18n.js");
  page.run("landing/js/confirmed.js");
  return { page, els, calls };
}

test("confirmed: parametresiz açılışta başarılı onay iddiası ve logout yok", () => {
  const { els, calls } = setupConfirmed();
  assert.equal(els.icon.getAttribute("data-icon"), null);
  assert.equal(els["home-link"].hidden, false);
  assert.equal(calls.length, 0);
});

test("confirmed: onay dönüşü URL'yi temizler ve yalnızca tarayıcıdaki oturumu kapatır", async () => {
  const { page, els, calls } = setupConfirmed({ hash: "#access_token=qa-confirmation-token&type=signup", language: "en-US" });
  await settle();
  assert.equal(page.window.location.hash, "");
  assert.equal(els.icon.getAttribute("data-icon"), "ok");
  assert.equal(els.title.textContent, "Email Confirmed!");
  assert.equal(calls.length, 1);
  assert.equal(calls[0].path, "/auth/v1/logout?scope=local");
});

test("confirmed: URL'deki keyfi hata metni yerine sabit geçersiz bağlantı mesajı", () => {
  const { els, calls } = setupConfirmed({ search: "?error=access_denied&error_code=otp_expired&error_description=UNTRUSTED" });
  assert.equal(els.icon.getAttribute("data-icon"), "warn");
  assert.match(els.message.textContent, /süresi dolmuş/);
  assert.doesNotMatch(els.message.textContent, /UNTRUSTED/);
  assert.equal(calls.length, 0);
});

test("auth dil seçimi: bağlantı tercihi tarayıcı dilinden önce gelir", () => {
  const ctx = setupReset({ search: "?lang=tr&token_hash=single-use&type=recovery", language: "en-US" });
  assert.equal(ctx.page.document.documentElement.lang, "tr");
  assert.match(ctx.els.message.textContent, /yeni bir şifre/);
});
