// Kaydırma tetikleyicisi henüz çalışmamışken özellik açıklamaları okunabilir
// olmalı. GSAP'ın from başlangıç değerleri uygulanır; animasyon ilerletilmez.
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { test } from "node:test";
import { FakeElement, REPO } from "./helpers/fake_dom.mjs";

function setup({ page = "features", reduced = false, narrow = false, animations = true } = {}) {
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
  const row = node("feature-row");
  row.querySelector = (selector) => ({ ".feature-row-text": text, ".feature-row-media": media, ".phone": phone })[selector] || null;
  row.querySelectorAll = (selector) => selector === ".feature-row-text li" ? items : [];
  const content = [hero, title, heading, cta, ...cards, text, media, ...items];
  const document = {
    documentElement: root, body,
    getElementById: () => null,
    querySelector: () => null,
    querySelectorAll: (selector) => ({
      "[data-hero]": [hero], "[data-hero-title]": [title],
      "[data-reveal]": [heading, cta], "[data-reveal-group]": [group],
      ".feature-row": [row],
    })[selector] || [],
    addEventListener() {},
  };
  const window = {
    matchMedia: (query) => ({ matches: query.includes("prefers-reduced-motion") ? reduced : query === "(max-width: 720px)" && narrow }),
    addEventListener() {},
  };
  const calls = [];
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
    globals.ScrollTrigger = { refresh() {} };
    globals.gsap = {
      registerPlugin() {}, utils: { toArray: (targets) => Array.from(targets) },
      from, fromTo: (target, _before, after) => calls.push({ targets: [target], vars: after }),
      timeline: () => ({ from(targets, vars) { from(targets, vars); return this; } }),
    };
  }
  vm.runInNewContext(fs.readFileSync(path.join(REPO, "landing/js/main.js"), "utf8"), globals);
  return { root, content, hero, heading, cta, cards, text, media, items, calls };
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
    assert.ok(page.calls.some(({ vars }) => vars.x !== undefined || vars.y !== undefined), "hafif konum animasyonu korunur");
  }
});

test("Features: anker başlıkları, açıklamalar, destek kartları ve CTA sonradan yer değiştirmez", () => {
  for (const narrow of [false, true]) {
    const page = setup({ narrow });
    for (const node of [page.heading, page.cta, ...page.cards, page.text, ...page.items]) {
      assert.equal(page.calls.some(({ targets = [] }) => targets.includes(node)), false, `${node.id}: konum ve görünürlük sabit kalmalı`);
    }
    assert.ok(page.calls.some(({ targets = [] }) => targets.includes(page.media)), "medyanın hafif hareketi korunur");
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
  for (const node of [page.heading, page.cta, ...page.cards, page.text, page.media, ...page.items]) {
    assert.equal(node.style.opacity, "0", node.id);
    assert.equal(node.style.visibility, "hidden", node.id);
  }
});
