// landing/js/*.js dosyalarını tarayıcı olmadan çalıştırmak için küçük sahte DOM.
// Yalnızca bekleme listesi formunun ve abonelikten çıkma sayfasının kullandığı
// API'ler var; sayfa betiği node:vm içinde, testin verdiği `window` ile çalışır.
// Ağ yok: window.PomoSupabase.request testte sahtelenir, setTimeout elle ilerletilir.
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
export const REPO = path.resolve(here, "../../..");

class FakeClassList {
  constructor() { this.set = new Set(); }
  add(...names) { names.forEach((n) => this.set.add(n)); }
  remove(...names) { names.forEach((n) => this.set.delete(n)); }
  contains(name) { return this.set.has(name); }
  toggle(name, force) {
    const on = force === undefined ? !this.set.has(name) : Boolean(force);
    if (on) this.set.add(name); else this.set.delete(name);
    return on;
  }
}

export class FakeElement {
  constructor(id, props = {}) {
    this.id = id;
    this.attributes = new Map();
    this.listeners = {};
    this.classList = new FakeClassList();
    this.children = [];
    this._text = "";
    this.hidden = false;
    this.disabled = false;
    this.value = "";
    this.checked = false;
    this.focused = false;
    Object.assign(this, props);
  }
  // Gerçek DOM'daki gibi: textContent yazmak çocukları siler, okumak birleştirir.
  get textContent() {
    return this.children.length ? this.children.map((c) => c.textContent).join("") : this._text;
  }
  set textContent(value) {
    this.children = [];
    this._text = String(value);
  }
  setAttribute(name, value) { this.attributes.set(name, String(value)); }
  getAttribute(name) { return this.attributes.has(name) ? this.attributes.get(name) : null; }
  removeAttribute(name) { this.attributes.delete(name); }
  hasAttribute(name) { return this.attributes.has(name); }
  addEventListener(type, fn) { (this.listeners[type] ??= []).push(fn); }
  dispatch(type, event = {}) {
    const ev = { type, target: this, isTrusted: true, defaultPrevented: false, preventDefault() { this.defaultPrevented = true; }, ...event };
    (this.listeners[type] || []).forEach((fn) => fn(ev));
    return ev;
  }
  appendChild(child) { this.children.push(child); return child; }
  querySelector() { return null; }
  querySelectorAll() { return []; }
  contains() { return false; }
  focus() { this.focused = true; }
  reset() {}
}

/**
 * @param {Record<string, FakeElement>} elements id → öğe
 * @param {{ search?: string, pathname?: string, api?: object }} opts
 */
export function createPage(elements, { search = "", pathname = "/", api = null } = {}) {
  const docListeners = {};
  const timers = [];
  const replaced = [];
  const location = { search, pathname, hash: "" };
  const document = {
    title: "",
    documentElement: new FakeElement("html"),
    body: new FakeElement("body"),
    getElementById: (id) => elements[id] || null,
    querySelector: () => null,
    querySelectorAll: () => [],
    createElement: (tag) => new FakeElement(tag),
    createTextNode: (text) => ({ nodeType: 3, textContent: String(text) }),
    addEventListener: (type, fn) => { (docListeners[type] ??= []).push(fn); },
  };
  const window = {
    document,
    location,
    history: {
      replaceState: (_state, _title, url) => {
        replaced.push(url);
        const u = new URL(url, "https://pomosprint.app");
        location.search = u.search;
        location.pathname = u.pathname;
      },
    },
    // Hareket azaltma açık: main.js animasyon kurmadan erken döner.
    matchMedia: () => ({ matches: true, addEventListener() {} }),
    addEventListener() {},
    PomoSupabase: api,
    scrollY: 0,
    innerWidth: 1280,
  };
  const context = vm.createContext({
    window,
    document,
    URL,
    URLSearchParams,
    Intl,
    console,
    Image: class { set src(_v) {} },
    setTimeout: (fn, ms) => { timers.push({ fn, ms }); return timers.length; },
    clearTimeout() {},
    setInterval: () => 0,
  });
  return {
    window,
    document,
    replaced,
    timers,
    run(relPath) {
      const code = fs.readFileSync(path.join(REPO, relPath), "utf8");
      vm.runInContext(code, context, { filename: relPath });
    },
    /** Belgeye gerçek bir kullanıcı etkileşimi (tuş) gönderir. */
    interact() {
      (docListeners.keydown || []).forEach((fn) => fn({ type: "keydown", isTrusted: true, key: "a" }));
    },
    /** Bekleyen zamanlayıcıları sırayla çalıştırır. */
    flushTimers() {
      while (timers.length) timers.shift().fn();
    },
  };
}

/** vm içinde üretilen nesneyi (başka realm) deepStrictEqual için düz nesneye çevirir. */
export const plain = (value) => JSON.parse(JSON.stringify(value));

/** Promise zincirlerinin (api.request().then) tamamlanmasını bekler. */
export const settle = () => new Promise((resolve) => setImmediate(resolve));
