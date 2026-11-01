// Kaydırma tetikleyicisi henüz çalışmamışken özellik açıklamaları okunabilir
// olmalı. GSAP'ın from başlangıç değerleri uygulanır; animasyon ilerletilmez.
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { test } from "node:test";
import { FakeElement, REPO } from "./helpers/fake_dom.mjs";

function setup({ page = "features", reduced = false, narrow = false, animations = true, gallery = false, rowHasPhone = true, glass = false } = {}) {
  const node = (id) => new FakeElement(id, { style: {} });
  const root = node("html");
  root.classList.add("js-anim");
  const body = node("body");
  body.setAttribute("data-page", page);
  const hero = node("hero-copy");
  const title = node("title");
  const heading = node("support-heading");
  const cta = node("cta");
  const cards = [node("offline"), node("categories"), node("language")];
  const group = node("support-grid");
  group.children = cards;
  const text = node("feature-copy");
  const media = node("feature-media");
  const items = [node("first-rule"), node("second-rule")];
  const phone = node("phone");
  const hourglass = node("hourglass");
  hourglass.querySelectorAll = () => [];
  const secondPhone = node("phone-2");
  group.querySelector = (selector) => gallery && selector === ".phone" ? phone : null;
  const row = node("feature-row");
  row.querySelector = (selector) => ({ ".feature-row-text": text, ".feature-row-media": media, ".phone": rowHasPhone ? phone : null })[selector] || null;
  row.querySelectorAll = (selector) => selector === ".feature-row-text li" ? items :
    selector === ".phone" && rowHasPhone ? [phone, secondPhone] : [];
  const content = [hero, title, heading, cta, ...cards, text, media, ...items];
  const document = {
    documentElement: root, body,
    getElementById: () => null,
    querySelector: () => null,
    querySelectorAll: (selector) => ({
      "[data-hero]": [hero], "[data-hero-title]": [title],
      "[data-reveal]": [heading, cta], "[data-reveal-group]": [group],
      ".feature-row": [row], ".hourglass": glass ? [hourglass] : [],
    })[selector] || [],
    addEventListener() {},
  };
  const motionListeners = [];
  const motion = {
    matches: reduced,
    addEventListener(type, callback) { if (type === "change") motionListeners.push(callback); },
  };
  const windowListeners = new Map();
  const window = {
    innerWidth: 1200,
    matchMedia: (query) => query.includes("prefers-reduced-motion") ? motion :
      { matches: (query === "(max-width: 720px)" && narrow) || (query === "(pointer: fine)" && glass) },
    addEventListener(type, fn) { (windowListeners.get(type) ?? windowListeners.set(type, new Set()).get(type)).add(fn); },
    removeEventListener(type, fn) { windowListeners.get(type)?.delete(fn); },
  };
  const calls = [];
  let reverts = 0;
  const from = (targets, vars) => {
    const nodes = Array.isArray(targets) ? targets : [targets];
    calls.push({ targets: nodes, vars });
    for (const target of nodes) {
      if (vars.autoAlpha === 0) {
        target.style.opacity = "0";
        target.style.visibility = "hidden";
      }
      if (Object.hasOwn(vars, "opacity")) target.style.opacity = String(vars.opacity);
      if (Object.hasOwn(vars, "visibility")) target.style.visibility = vars.visibility;
    }
  };
  const globals = { window, document };
  if (animations) {
    globals.ScrollTrigger = { refresh() {}, create() {} };
    globals.gsap = {
      registerPlugin() {}, utils: { toArray: (targets) => Array.from(targets) },
      matchMedia: () => ({ add(_query, setupAnimations) {
        let cleanup = null;
        let active = false;
        const update = () => {
          if (!motion.matches && !active) {
            active = true;
            cleanup = setupAnimations();
          } else if (motion.matches && active) {
            active = false;
            if (cleanup) cleanup();
            for (const target of [...content, phone, secondPhone]) target.style = {};
            reverts += 1;
          }
        };
        motion.addEventListener("change", update);
        update();
      } }),
      from, fromTo: (target, _before, after) => calls.push({ targets: [target], vars: after }),
      quickTo: () => () => {},
      timeline: () => ({
        from(targets, vars) { from(targets, vars); return this; },
        fromTo() { return this; }, play() {}, pause() {},
      }),
    };
  }
  vm.runInNewContext(fs.readFileSync(path.join(REPO, "landing/js/main.js"), "utf8"), globals);
  return { root, content, hero, heading, cta, cards, text, media, items, phone, secondPhone, calls,
    reverts: () => reverts,
    listeners: (type) => windowListeners.get(type)?.size || 0,
    reduced(value) { motion.matches = value; motionListeners.forEach((callback) => callback()); },
  };
}

function readable(nodes) {
  for (const node of nodes) {
    assert.notEqual(node.style.opacity, "0", node.id);
    assert.notEqual(node.style.visibility, "hidden", node.id);
  }
}

test("Features: geciken veya hiç çalışmayan kaydırma animasyonu içeriği gizlemez", () => {
  for (const narrow of [false, true]) {
    const page = setup({ narrow });
    readable(page.content);
    assert.equal(page.root.classList.contains("js-anim"), false);
    assert.equal(page.calls.some(({ targets = [] }) => targets.includes(page.media) || targets.includes(page.phone)), false, "telefonlar kaydırılırken hareket etmez");
  }
});

test("Features: anker başlıkları, açıklamalar, destek kartları ve CTA sonradan yer değiştirmez", () => {
  for (const narrow of [false, true]) {
    const page = setup({ narrow });
    for (const node of [page.heading, page.cta, ...page.cards, page.text, ...page.items]) {
      assert.equal(page.calls.some(({ targets = [] }) => targets.includes(node)), false, `${node.id}: konum ve görünürlük sabit kalmalı`);
    }
    assert.equal(page.calls.some(({ targets = [] }) => targets.includes(page.media) || targets.includes(page.phone)), false, "telefonların hizası sabit kalır");
  }
});

test("Features: GSAP yüklenemediğinde açıklamalar görünür ve açılış hata vermez", () => {
  const page = setup({ animations: false });
  readable(page.content);
  assert.equal(page.root.classList.contains("js-anim"), false);
});

test("Features: hareket azaltma tercihi okunabilir durağan içerik gösterir", () => {
  const page = setup({ reduced: true });
  readable(page.content);
  assert.equal(page.calls.length, 0);
  assert.equal(page.root.classList.contains("js-anim"), false);
});

test("Ana sayfanın kritik hero içeriği görünür kalır, alt kartların hafif animasyonu korunur", () => {
  const page = setup({ page: "home" });
  readable([page.hero]);
  assert.equal(page.calls.some(({ targets = [] }) => targets.includes(page.hero)), false);
  for (const node of [page.heading, page.cta, ...page.cards, page.text, ...page.items]) {
    assert.equal(node.style.opacity, "0", node.id);
    assert.equal(node.style.visibility, "hidden", node.id);
  }
});

test("Telefon galerileri birlikte ve yerlerinde kalır; diğer kart animasyonları korunur", () => {
  for (const narrow of [false, true]) {
    const page = setup({ page: "home", narrow, gallery: true });
    for (const node of [page.media, page.phone, page.secondPhone, ...page.cards]) {
      assert.equal(page.calls.some(({ targets = [] }) => targets.includes(node)), false, `${node.id}: telefon galerisi hareket etmemeli`);
      readable([node]);
    }
    assert.ok(page.calls.some(({ targets = [] }) => targets.includes(page.heading)), "telefonsuz öğelerin hareketi korunur");
    const decoration = setup({ page: "home", narrow, rowHasPhone: false });
    assert.ok(decoration.calls.some(({ targets = [] }) => targets.includes(decoration.media)), "telefonsuz medya canlandırılabilir");
  }
});


test("hareket tercihi açık sayfada değişince GSAP temizlenir ve erişilebilir içerik kalır", () => {
  const page = setup({ page: "home" });
  assert.equal(page.heading.style.visibility, "hidden");
  const before = page.calls.length;
  page.reduced(true);
  assert.equal(page.reverts(), 1);
  readable(page.content);
  page.reduced(true);
  assert.equal(page.reverts(), 1, "aynı tercih tekrar bildirilince temizleme yinelenmez");
  page.reduced(false);
  assert.ok(page.calls.length > before, "animasyonlar tercih kapatıldığında yeniden kurulur");
});


test("hareket tercihi değişirken kum saati dinleyicileri birikmez", () => {
  const page = setup({ page: "home", glass: true });
  assert.equal(page.listeners("load"), 1);
  assert.equal(page.listeners("pointermove"), 1);
  page.reduced(true);
  assert.equal(page.listeners("load"), 0);
  assert.equal(page.listeners("pointermove"), 0);
  page.reduced(false);
  assert.equal(page.listeners("load"), 1);
  assert.equal(page.listeners("pointermove"), 1);
  page.reduced(true);
  assert.equal(page.listeners("load"), 0);
  assert.equal(page.listeners("pointermove"), 0);
});
