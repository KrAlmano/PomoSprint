// landing/js/main.js bekleme listesi formu (6563 / İYS): ticari elektronik
// ileti onayı ayrı ve önceden işaretsiz bir kutuyla alınır; kutu işaretli
// değilse waitlist'e istek gitmez. proposed/19 A onay kolonlarını ekler;
// onay ve sürüm istemciden, consented_at yalnızca sunucu trigger'ından gelir.
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { test } from "node:test";

import { FakeElement, REPO, createPage, plain, settle } from "./helpers/fake_dom.mjs";

const MAIN_JS = "landing/js/main.js";

function setup({ consentBox = true } = {}) {
  const calls = [];
  const api = {
    request: (p, opts) => {
      calls.push({ path: p, opts });
      return Promise.resolve({ ok: true, status: 201, data: null });
    },
    errorCode: () => "",
  };
  const button = new FakeElement("submit", { textContent: "Yayınlanınca haber ver" });
  const form = new FakeElement("notify-form");
  form.querySelector = (sel) => (sel === "button[type=submit]" ? button : null);
  const els = {
    "notify-form": form,
    "notify-email": new FakeElement("notify-email"),
    "notify-website": new FakeElement("notify-website"),
    "notify-status": new FakeElement("notify-status"),
    "notify-success": new FakeElement("notify-success", { hidden: true }),
  };
  if (consentBox) els["notify-consent"] = new FakeElement("notify-consent");
  const page = createPage(els, { api });
  page.run(MAIN_JS);
  return { page, els, calls, button };
}

function submit({ page, els }, email) {
  els["notify-email"].value = email;
  page.interact();
  return els["notify-form"].dispatch("submit");
}

test("onay kutusu işaretli değilse kayıt gönderilmez, kutu hatalı işaretlenir", async () => {
  const ctx = setup();
  const ev = submit(ctx, "ayse@example.com");
  assert.ok(ev.defaultPrevented);
  ctx.page.flushTimers();
  await settle();
  assert.equal(ctx.calls.length, 0, "waitlist'e istek gitmemeli");
  assert.match(ctx.els["notify-status"].textContent, /onay kutusunu işaretlemen/);
  assert.equal(ctx.els["notify-consent"].getAttribute("aria-invalid"), "true");
  assert.ok(ctx.els["notify-consent"].focused);
  assert.equal(ctx.els["notify-form"].hidden, false, "teşekkür gösterilmez");
});

test("onay verilince e-posta, onay ve metin sürümü gönderilir; zaman sunucuya bırakılır", async () => {
  const ctx = setup();
  ctx.els["notify-consent"].checked = true;
  submit(ctx, "  Ayse@Example.com ");
  ctx.page.flushTimers();
  await settle();
  assert.equal(ctx.calls.length, 1);
  assert.equal(ctx.calls[0].path, "/rest/v1/waitlist");
  assert.deepEqual(plain(ctx.calls[0].opts.body), {
    email: "ayse@example.com",
    marketing_consent: true,
    consent_text_version: "waitlist-2026-10-03",
  });
  assert.equal(ctx.calls[0].opts.prefer, "return=minimal");
  assert.equal(ctx.els["notify-form"].hidden, true);
  assert.equal(ctx.els["notify-success"].hidden, false);
});

test("onay hatası kutu işaretlenince temizlenir ve ikinci deneme gönderilir", async () => {
  const ctx = setup();
  submit(ctx, "ayse@example.com");
  assert.equal(ctx.els["notify-consent"].getAttribute("aria-invalid"), "true");
  ctx.els["notify-consent"].checked = true;
  ctx.els["notify-consent"].dispatch("change");
  assert.equal(ctx.els["notify-consent"].hasAttribute("aria-invalid"), false);
  assert.equal(ctx.els["notify-status"].textContent, "");
  submit(ctx, "ayse@example.com");
  ctx.page.flushTimers();
  await settle();
  assert.equal(ctx.calls.length, 1);
});

test("bekleme süresinde kutu kaldırılırsa istek gitmez", async () => {
  const ctx = setup();
  ctx.els["notify-consent"].checked = true;
  submit(ctx, "ayse@example.com");
  assert.ok(ctx.page.timers.length > 0, "en kısa doldurma süresi beklenmeli");
  ctx.els["notify-consent"].checked = false;
  ctx.page.flushTimers();
  await settle();
  assert.equal(ctx.calls.length, 0);
  assert.equal(ctx.button.disabled, false, "buton yeniden kullanılabilir");
  assert.match(ctx.els["notify-status"].textContent, /onay kutusunu/);
});

test("sayfada onay kutusu yoksa (eski önbellekli HTML) kayıt yapılmaz", async () => {
  const ctx = setup({ consentBox: false });
  submit(ctx, "ayse@example.com");
  ctx.page.flushTimers();
  await settle();
  assert.equal(ctx.calls.length, 0);
});

test("e-posta hataları onaydan önce gösterilir", async () => {
  const ctx = setup();
  submit(ctx, "gecersiz");
  assert.match(ctx.els["notify-status"].textContent, /Geçerli bir e-posta/);
  assert.equal(ctx.els["notify-consent"].hasAttribute("aria-invalid"), false);
});

test("index.html: onay kutusu ayrı, önceden işaretsiz ve ticari ileti onayını açıkça söylüyor", () => {
  const html = fs.readFileSync(path.join(REPO, "landing/index.html"), "utf8");
  const form = html.slice(html.indexOf('<form class="notify-form"'), html.indexOf("</form>"));
  const box = form.match(/<input[^>]*id="notify-consent"[^>]*>/);
  assert.ok(box, "onay kutusu formda olmalı");
  assert.match(box[0], /type="checkbox"/);
  assert.doesNotMatch(box[0], /\bchecked\b/, "kutu önceden işaretli olmamalı");
  const label = form.match(/<label for="notify-consent">([\s\S]*?)<\/label>/);
  assert.ok(label);
  assert.match(label[1], /ticari elektronik ileti/);
  assert.match(label[1], /geri alabilirim/);
  // E-posta alanı ve onay ayrı alanlar; e-posta alanının etiketi onay içermez
  assert.match(form, /<label class="sr-only" for="notify-email">E-posta adresin<\/label>/);
});
