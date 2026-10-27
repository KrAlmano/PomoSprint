// Gerçek uygulama medyası: yalnız görünürken sessiz döngü; arka planda ve
// hareket azaltmada durur. Engellenen/bozuk video gerçek görüntüye düşer.
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { test } from "node:test";
import { FakeElement, REPO, settle } from "./helpers/fake_dom.mjs";

function mediaPage({ reduced = false, observerSupported = true, playOutcome } = {}) {
  let plays = 0;
  let pauses = 0;
  let loads = 0;
  let observer;
  let src;
  const playSettings = [];
  const rect = { top: 200, bottom: 700, left: 100, right: 350 };
  const image = new FakeElement("screenshot");
  const screen = new FakeElement("screen", { getBoundingClientRect: () => rect });
  const video = new FakeElement("video", {
    currentTime: 7.25,
    parentElement: screen,
    play() {
      plays += 1;
      playSettings.push([this.muted, this.defaultMuted, this.playsInline, this.loop]);
      return playOutcome ? playOutcome(plays) : Promise.resolve();
    },
    pause() { pauses += 1; },
  });
  video.setAttribute("data-src", "/videos/timer-demo-20261008d.mp4");
  video.setAttribute("aria-label", "Pomo kaydı");
  Object.defineProperty(video, "src", {
    get: () => src,
    set(value) { src = value; loads += 1; },
  });
  const listeners = {};
  const windowListeners = {};
  const motionListeners = [];
  const motion = {
    matches: reduced,
    addEventListener(type, callback) { if (type === "change") motionListeners.push(callback); },
  };
  const document = {
    documentElement: new FakeElement("html"),
    hidden: false,
    getElementById: () => null,
    querySelector: () => null,
    querySelectorAll: (selector) => selector === "video[data-demo-video]" ? [video] : [],
    addEventListener(type, callback) { (listeners[type] ??= []).push(callback); },
  };
  class IntersectionObserver {
    constructor(callback) { this.callback = callback; observer = this; }
    observe(target) { this.target = target; }
    unobserve(target) { this.unobserved = target; }
  }
  const window = {
    matchMedia: () => motion,
    innerHeight: 800,
    innerWidth: 1200,
    addEventListener(type, callback) { (windowListeners[type] ??= []).push(callback); },
  };
  if (observerSupported) window.IntersectionObserver = IntersectionObserver;
  vm.runInNewContext(fs.readFileSync(path.join(REPO, "landing/js/main.js"), "utf8"), {
    window, document, IntersectionObserver,
  });
  return { video, image, observer, document, rect, playSettings,
    plays: () => plays, pauses: () => pauses, loads: () => loads,
    visible(value, ratio = 1) {
      observer.callback([{ target: video, isIntersecting: value, intersectionRatio: ratio }]);
    },
    visibility(hidden) {
      document.hidden = hidden;
      (listeners.visibilitychange || []).forEach((callback) => callback());
    },
    reduced(value) {
      motion.matches = value;
      motionListeners.forEach((callback) => callback());
    },
    scroll() { (windowListeners.scroll || []).forEach((callback) => callback()); },
  };
}

test("video ancak yeterince görünürken yüklenir ve sessiz döngüde başlar", () => {
  const page = mediaPage();
  assert.equal(page.loads(), 0);
  assert.equal(page.plays(), 0);
  page.visible(true, 0.01);
  assert.equal(page.loads(), 0);
  page.visible(true);
  assert.equal(page.loads(), 1);
  assert.equal(page.plays(), 1);
  assert.deepEqual(page.playSettings, [[true, true, true, true]]);
  assert.equal(page.video.src, "/videos/timer-demo-20261008d.mp4");
});

test("ekran veya sekme dışında durur; geri dönünce aynı konumdan sürer", () => {
  const page = mediaPage();
  page.visible(true);
  const beforePause = page.pauses();
  page.visible(false);
  assert.equal(page.pauses(), beforePause + 1);
  page.visible(true);
  assert.equal(page.plays(), 2);
  page.visibility(true);
  assert.equal(page.pauses(), beforePause + 2);
  page.visible(true);
  assert.equal(page.plays(), 2);
  page.visibility(false);
  assert.equal(page.plays(), 3);
  assert.equal(page.loads(), 1);
  assert.equal(page.video.currentTime, 7.25);
});

test("başlangıçta hareket azaltma açıksa statik görüntü kalır ve MP4 yüklenmez", () => {
  const page = mediaPage({ reduced: true });
  page.visible(true);
  page.visibility(false);
  assert.equal(page.loads(), 0);
  assert.equal(page.plays(), 0);
  assert.equal(page.video.hidden, true);
  assert.equal(page.image.hidden, false);
});

test("hareket azaltma tercihi canlı değişirse kayıt durur ve yalnız görünürken geri başlar", () => {
  const page = mediaPage();
  page.visible(true);
  page.reduced(true);
  assert.equal(page.video.hidden, true);
  page.visible(false);
  page.reduced(false);
  assert.equal(page.plays(), 1);
  page.visible(true);
  assert.equal(page.plays(), 2);
  assert.equal(page.video.hidden, false);
});

test("autoplay reddi yakalanır ve tekrar tekrar oynatmadan statik görüntü bırakır", async () => {
  const page = mediaPage({ playOutcome: () => Promise.reject(new Error("NotAllowedError")) });
  page.visible(true);
  await settle();
  assert.equal(page.video.hidden, true);
  assert.equal(page.image.hidden, false);
  assert.equal(page.observer.unobserved, page.video);
  page.visible(false);
  page.visible(true);
  page.visibility(false);
  assert.equal(page.plays(), 1);
});

test("video yükleme hatası gerçek ekran görüntüsünü bırakır ve kaydı durdurur", () => {
  const page = mediaPage();
  page.visible(true);
  page.video.dispatch("error");
  assert.equal(page.video.hidden, true);
  assert.equal(page.image.hidden, false);
  assert.equal(page.observer.unobserved, page.video);
  page.visible(true);
  assert.equal(page.plays(), 1);
});

test("geç tamamlanan play isteği kullanıcı ekrandan çıkmışsa arka planda oynamaz", async () => {
  let resolve;
  const pending = new Promise((done) => { resolve = done; });
  const page = mediaPage({ playOutcome: () => pending });
  page.visible(true);
  page.visible(false);
  const pauses = page.pauses();
  resolve();
  await settle();
  assert.equal(page.pauses(), pauses + 1);
  assert.equal(page.plays(), 1);
});

test("pause nedeniyle eski play reddedilmesi geri dönen yeni oynatmayı bozmaz", async () => {
  let reject;
  const pending = new Promise((_resolve, fail) => { reject = fail; });
  const page = mediaPage({ playOutcome: (count) => count === 1 ? pending : Promise.resolve() });
  page.visible(true);
  page.visible(false);
  page.visible(true);
  reject(new Error("AbortError"));
  await settle();
  assert.equal(page.video.hidden, false);
  assert.equal(page.observer.unobserved, undefined);
  assert.equal(page.plays(), 2);
});

test("IntersectionObserver yoksa ekran konumu denetlenir; gizli video kutusu ölçümü bozmaz", () => {
  const page = mediaPage({ observerSupported: false, reduced: true });
  assert.equal(page.plays(), 0);
  page.reduced(false);
  assert.equal(page.plays(), 1);
  page.rect.top = 1200;
  page.rect.bottom = 1700;
  page.scroll();
  page.visibility(true);
  page.visibility(false);
  assert.equal(page.plays(), 1);
  page.rect.top = 200;
  page.rect.bottom = 700;
  page.scroll();
  assert.equal(page.plays(), 2);
});

test("tıklama veya klavye ile duraklatılan kayıt ekran/sekme dönüşünde otomatik başlamaz", () => {
  const page = mediaPage();
  page.visible(true);
  page.video.dispatch("click");
  assert.match(page.video.getAttribute("aria-label"), /Kaydı oynat$/);
  page.visible(false);
  page.visible(true);
  page.visibility(true);
  page.visibility(false);
  assert.equal(page.plays(), 1);
  const enter = page.video.dispatch("keydown", { key: "Enter" });
  assert.equal(enter.defaultPrevented, true);
  assert.equal(page.plays(), 2);
  assert.match(page.video.getAttribute("aria-label"), /Kaydı duraklat$/);
  const space = page.video.dispatch("keydown", { key: " " });
  assert.equal(space.defaultPrevented, true);
  page.visibility(false);
  assert.equal(page.plays(), 2);
  const unrelated = page.video.dispatch("keydown", { key: "ArrowDown" });
  assert.equal(unrelated.defaultPrevented, false);
});

test("gerçek görüntü oranı iç ekrandadır; kayıtlar sessiz döngü ve statik fallback sunar", () => {
  for (const [name, count] of [["features.html", 2], ["index.html", 1]]) {
    const html = fs.readFileSync(path.join(REPO, "landing", name), "utf8");
    const videos = [...html.matchAll(/<video\b([^>]*)>([\s\S]*?)<\/video>/g)];
    assert.equal(videos.length, count, name);
    for (const [, attrs, content] of videos) {
      for (const attr of ["autoplay", "muted", "loop", "playsinline"]) assert.match(attrs, new RegExp("\\b" + attr + "\\b"));
      assert.doesNotMatch(attrs, /\bcontrols\b/);
      assert.match(attrs, /role="button"/);
      assert.match(attrs, /tabindex="0"/);
      assert.match(attrs, /preload="none"/);
      assert.match(attrs, /data-src="\/videos\/(?:timer|marathon)-demo-20261008d\.mp4"/);
      assert.match(attrs, /poster="\/videos\/(?:timer|marathon)-demo-20261008d\.webp"/);
      assert.doesNotMatch(content, /<source\b[^>]*\bsrc=/);
      assert.match(content, /href="\/screenshots\/[a-z]+\.webp"/);
    }
    assert.doesNotMatch(html, /phone-mock|data-shot=|Oynat düğmesi|oynat düğmesi/);
  }
  const css = fs.readFileSync(path.join(REPO, "landing/css/style.css"), "utf8");
  const outer = css.match(/\.phone \{([^}]+)\}/)[1];
  const screen = css.match(/\.phone-screen \{([^}]+)\}/)[1];
  assert.doesNotMatch(outer, /aspect-ratio|height:/);
  assert.match(screen, /aspect-ratio:\s*540\s*\/\s*1170/);
  assert.match(screen, /height:\s*auto/);
  assert.match(css, /@media \(prefers-reduced-motion: reduce\)\s*\{[\s\S]*?\.shot-video \{ display: none; \}/);
  const html = fs.readFileSync(path.join(REPO, "landing/features.html"), "utf8");
  const marathon = html.match(/<article\b[^>]*\bid="maraton"[^>]*>[\s\S]*?<\/article>/)[0];
  assert.match(marathon, /<span class="eyebrow">Maraton<\/span>/);
  assert.match(marathon, /2, 3 ya da 4 Pomodoro/);
  assert.match(marathon, /5 dakikalık mola/);
  assert.match(marathon, /1 dakika içinde “Buradayım”/);
  assert.match(marathon, /onay vermezsen plan sonlanır/);
  assert.match(marathon, /internet bağlantısı gerekir/);
  assert.doesNotMatch(marathon, /önizleme|Önizleme/);
  const home = fs.readFileSync(path.join(REPO, "landing/index.html"), "utf8");
  assert.match(home, /href="\/features#maraton"/);
});
