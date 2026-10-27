import assert from "node:assert/strict";
import { test } from "node:test";
import { FakeElement, createPage } from "./helpers/fake_dom.mjs";

// Runs the production event handlers without a browser or network. It proves
// state/ARIA changes, not Safari layout, keyboard routing or native <details>.
function navigation() {
  const page = createPage({});
  const header = new FakeElement("header");
  const toggle = new FakeElement("toggle");
  const link = new FakeElement("link");
  const outside = new FakeElement("outside");
  const listeners = {};
  let viewportChanged;
  const viewport = { matches: true, addEventListener: (_, handler) => { viewportChanged = handler; } };
  page.window.matchMedia = query => query === "(max-width: 760px)"
    ? viewport : { matches: true, addEventListener() {} };
  page.document.querySelector = selector => ({ ".site-header": header, ".nav-toggle": toggle })[selector] || null;
  page.document.addEventListener = (type, handler) => { (listeners[type] ??= []).push(handler); };
  header.querySelectorAll = selector => selector === ".site-nav a" ? [link] : [];
  header.contains = target => [header, toggle, link].includes(target);
  page.run("landing/js/main.js");
  return {
    ...page, header, toggle, link, outside,
    event: (type, event) => (listeners[type] || []).forEach(handler => handler(event)),
    widen() { viewport.matches = false; viewportChanged(); },
  };
}

test("mobile navigation keeps ARIA, scroll lock and dismissal paths synchronized", () => {
  const page = navigation();
  function state(open) {
    assert.equal(page.header.classList.contains("nav-open"), open);
    assert.equal(page.document.documentElement.classList.contains("nav-lock"), open);
    assert.equal(page.toggle.getAttribute("aria-expanded"), String(open));
  }
  page.toggle.dispatch("click"); state(true);
  page.event("click", { target: page.header }); state(true);
  page.event("keydown", { key: "Escape" }); state(false);
  assert.equal(page.toggle.focused, true);
  page.toggle.dispatch("click"); page.link.dispatch("click"); state(false);
  page.toggle.dispatch("click"); page.event("click", { target: page.outside }); state(false);
  page.toggle.dispatch("click"); page.widen(); state(false);
  page.toggle.dispatch("click"); page.toggle.dispatch("click"); state(false);
});

test("FAQ buttons open one answer, close the previous answer and expose matching ARIA state", () => {
  const page = createPage({});
  const rows = Array.from({ length: 3 }, (_, i) => {
    const item = new FakeElement(`item-${i}`);
    const button = new FakeElement(`button-${i}`);
    button.setAttribute("aria-expanded", "false");
    item.querySelector = selector => selector === ".faq-q" ? button : null;
    return { item, button };
  });
  page.document.querySelectorAll = selector => selector === ".faq-item" ? rows.map(row => row.item) : [];
  page.run("landing/js/main.js");
  const state = expected => rows.forEach(({ item, button }, i) => {
    assert.equal(item.classList.contains("open"), expected === i);
    assert.equal(button.getAttribute("aria-expanded"), String(expected === i));
  });
  rows[0].button.dispatch("click"); state(0);
  rows[1].button.dispatch("click"); state(1);
  rows[1].button.dispatch("click"); state(null);
});
