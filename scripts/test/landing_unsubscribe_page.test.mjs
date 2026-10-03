// landing/js/unsubscribe.js (KVKK-11): yeni bağlantılar yalnızca ?token=
// taşır; eski ?email=..&token=.. bağlantıları da çalışır ama e-posta adresi
// adres çubuğundan silinir ve isteğin URL'sine konmaz. Sayfa açılınca bir şey
// silinmez; çıkış yalnızca butonla olur.
import assert from "node:assert/strict";
import { test } from "node:test";

import { FakeElement, createPage, plain, settle } from "./helpers/fake_dom.mjs";

const TOKEN = "3f1c2a4e-1111-4222-8333-944455556666";
const UNSUB_JS = "landing/js/unsubscribe.js";

function setup(search, response = { ok: true, status: 200, data: null }) {
  const calls = [];
  const api = {
    url: "https://proj.supabase.co",
    request: (p, opts) => {
      calls.push({ path: p, opts });
      return Promise.resolve(response);
    },
    errorCode: () => "",
  };
  const els = {
    icon: new FakeElement("icon"),
    title: new FakeElement("title"),
    message: new FakeElement("message"),
    confirm: new FakeElement("confirm", { hidden: true }),
    error: new FakeElement("error"),
  };
  const page = createPage(els, { search, pathname: "/unsubscribe", api });
  page.run(UNSUB_JS);
  return { page, els, calls };
}

test("yalnızca token'lı bağlantı: sayfa açılınca istek yok, butonla token-only POST", async () => {
  const { els, calls, page } = setup(`?token=${TOKEN}`);
  assert.equal(calls.length, 0, "sayfa açılınca hiçbir şey silinmez");
  assert.equal(els.confirm.hidden, false);
  assert.match(els.message.textContent, /Bu bağlantıya ait e-⁠posta adresini/);
  assert.equal(page.replaced.length, 0, "adres çubuğunda değişecek bir şey yok");

  els.confirm.dispatch("click");
  await settle();
  assert.equal(calls.length, 1);
  assert.equal(calls[0].path, `/functions/v1/unsubscribe?token=${TOKEN}`);
  assert.deepEqual(plain(calls[0].opts.body), { token: TOKEN });
  assert.equal(els.icon.getAttribute("data-icon"), "ok");
  assert.match(els.message.textContent, /listelerimizden çıkarıldı/);
});

test("eski e-posta+token bağlantısı çalışır; e-posta URL'den silinir, yalnızca gövdede gider", async () => {
  const { els, calls, page } = setup(`?email=ayse%40example.com&token=${TOKEN}`);
  assert.deepEqual(page.replaced, [`/unsubscribe?token=${TOKEN}`]);
  assert.equal(page.window.location.search, `?token=${TOKEN}`);
  assert.match(els.message.textContent, /ayse@example\.com/);

  els.confirm.dispatch("click");
  await settle();
  assert.equal(calls.length, 1);
  assert.ok(!calls[0].path.includes("email"), "e-posta istek URL'sinde olmamalı");
  assert.ok(!calls[0].path.includes("example.com"));
  assert.deepEqual(plain(calls[0].opts.body), { token: TOKEN, email: "ayse@example.com" });
});

test("token yoksa buton gösterilmez ve istek atılmaz", async () => {
  const { els, calls } = setup("?email=ayse%40example.com");
  assert.equal(els.confirm.hidden, true);
  assert.equal(els.icon.getAttribute("data-icon"), "warn");
  els.confirm.dispatch("click");
  await settle();
  assert.equal(calls.length, 0);
});

test("sunucu 403 (e-posta token sahibiyle uyuşmuyor) dönerse geçersiz bağlantı mesajı", async () => {
  const { els } = setup(`?email=baska%40example.com&token=${TOKEN}`, { ok: false, status: 403, data: null });
  els.confirm.dispatch("click");
  await settle();
  assert.equal(els.icon.getAttribute("data-icon"), "warn");
  assert.match(els.message.textContent, /geçersiz/);
});
