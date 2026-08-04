/* PomoSprint landing — nav, akordiyon ve GSAP animasyonları */
(function () {
  "use strict";

  var prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---------- Mobil menü ---------- */
  var header = document.querySelector(".site-header");
  var navToggle = document.querySelector(".nav-toggle");
  if (header && navToggle) {
    navToggle.addEventListener("click", function () {
      var open = header.classList.toggle("nav-open");
      navToggle.setAttribute("aria-expanded", open ? "true" : "false");
    });
    header.querySelectorAll(".site-nav a").forEach(function (link) {
      link.addEventListener("click", function () {
        header.classList.remove("nav-open");
        navToggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  /* ---------- Footer yılı ---------- */
  var yearEl = document.getElementById("year");
  if (yearEl) yearEl.textContent = String(new Date().getFullYear());

  /* ---------- "Haber ver" formu: Supabase waitlist tablosuna kayıt ---------- */
  var notifyForm = document.getElementById("notify-form");
  if (notifyForm) {
    var SUPABASE_URL = "https://eoosnyakvxmifmexpgxa.supabase.co";
    // anon public key — istemcide görünmesi normaldir; RLS yalnızca INSERT'e izin verir
    var SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVvb3NueWFrdnhtaWZtZXhwZ3hhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxODYxNTYsImV4cCI6MjEwMDc2MjE1Nn0.W1_L04jD_cP-HuvSAOc2sb0ov5o5jsqpD6DyS7khd3Y";

    var sbClient = (window.supabase && window.supabase.createClient)
      ? window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
      : null;

    var statusEl = document.getElementById("notify-status");
    var notifyBtn = notifyForm.querySelector("button[type=submit]");
    var notifyBtnLabel = notifyBtn ? notifyBtn.textContent : "";

    var showStatus = function (msg, ok) {
      if (!statusEl) return;
      statusEl.textContent = msg;
      statusEl.classList.add("is-visible");
      statusEl.classList.toggle("is-ok", !!ok);
    };

    notifyForm.addEventListener("submit", function (e) {
      e.preventDefault();
      var input = document.getElementById("notify-email");
      var email = ((input && input.value) || "").trim().toLowerCase();
      if (!email) return;
      if (!sbClient) {
        showStatus("Bir şeyler ters gitti, tekrar dener misin?", false);
        return;
      }

      if (notifyBtn) {
        notifyBtn.disabled = true;
        notifyBtn.textContent = "Gönderiliyor…";
      }

      sbClient
        .from("waitlist")
        .insert({ email: email })
        .then(function (res) {
          if (notifyBtn) {
            notifyBtn.disabled = false;
            notifyBtn.textContent = notifyBtnLabel;
          }
          if (!res.error) {
            showStatus("Teşekkürler! Yayınlanınca sana haber vereceğiz 🚀", true);
            notifyForm.reset();
          } else if (res.error.code === "23505") {
            showStatus("Bu e-posta zaten listede ✓", true);
          } else {
            showStatus("Bir şeyler ters gitti, tekrar dener misin?", false);
          }
        });
    });
  }

  /* ---------- SSS akordiyonu (tek açık) ---------- */
  var faqItems = Array.prototype.slice.call(document.querySelectorAll(".faq-item"));
  faqItems.forEach(function (item) {
    var btn = item.querySelector(".faq-q");
    if (!btn) return;
    btn.addEventListener("click", function () {
      var wasOpen = item.classList.contains("open");
      faqItems.forEach(function (other) {
        other.classList.remove("open");
        var b = other.querySelector(".faq-q");
        if (b) b.setAttribute("aria-expanded", "false");
      });
      if (!wasOpen) {
        item.classList.add("open");
        btn.setAttribute("aria-expanded", "true");
      }
    });
  });

  /* ---------- Özellik ekran videoları (features.html) ----------
     Telefon ekranlarında uygulama kaydı, gif gibi sessiz ve sonsuz
     döngüde oynar. Videolar geldikçe aşağıdaki listeye eklenir;
     listede olmayan ekranlar yer tutucusunu göstermeye devam eder. */
  var SHOT_VIDEOS = window.SHOT_VIDEOS || {
    timer: "videos/timer.mp4",
    reports: "videos/reports.mp4",
    library: "videos/library.mp4",
    leaderboard: "videos/leaderboard.mp4",
    languages: "videos/languages.mp4"
  };

  var videoObserver = ("IntersectionObserver" in window)
    ? new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          var vid = entry.target;
          if (entry.isIntersecting) {
            var pr = vid.play();
            if (pr && pr.catch) pr.catch(function () {});
          } else {
            vid.pause();
          }
        });
      }, { threshold: 0.15 })
    : null;

  // Mobil veri dostu: video dosyası ancak ekranı yaklaşınca indirilir
  var lazyLoader = ("IntersectionObserver" in window)
    ? new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          var vid = entry.target;
          if (!vid.src) vid.src = vid.dataset.src;
          lazyLoader.unobserve(vid);
        });
      }, { rootMargin: "700px 0px" })
    : null;

  Object.keys(SHOT_VIDEOS).forEach(function (key) {
    document.querySelectorAll('.phone-screen[data-shot="' + key + '"]').forEach(function (screen) {
      var v = document.createElement("video");
      v.className = "shot-video";
      v.muted = true;
      v.loop = true;
      v.autoplay = true;
      v.playsInline = true;
      v.setAttribute("muted", "");
      v.setAttribute("playsinline", "");
      v.preload = "auto";
      v.dataset.src = SHOT_VIDEOS[key];
      v.addEventListener("loadeddata", function () {
        screen.classList.add("has-video");
        var pr = v.play();
        if (pr && pr.catch) pr.catch(function () {});
        if (videoObserver) videoObserver.observe(v);
      });
      screen.appendChild(v);
      if (lazyLoader) {
        lazyLoader.observe(v);
      } else {
        v.src = v.dataset.src;
      }
    });
  });

  /* ---------- GSAP animasyonları ---------- */
  if (prefersReduced || typeof gsap === "undefined") return;

  if (typeof ScrollTrigger !== "undefined") {
    gsap.registerPlugin(ScrollTrigger);
  }

  // Sayfa yüklenirken hero öğeleri: hafif fade-in + slide-up
  var heroEls = document.querySelectorAll("[data-hero]");
  if (heroEls.length) {
    gsap.from(heroEls, {
      y: 26,
      autoAlpha: 0,
      duration: 0.5,
      ease: "power2.out",
      stagger: 0.09,
      clearProps: "all"
    });
  }

  if (typeof ScrollTrigger === "undefined") return;

  // Scroll ile tek seferlik, abartısız reveal
  document.querySelectorAll("[data-reveal]").forEach(function (el) {
    gsap.from(el, {
      y: 32,
      autoAlpha: 0,
      duration: 0.6,
      ease: "power2.out",
      scrollTrigger: { trigger: el, start: "top 86%", once: true }
    });
  });

  // Grup reveal: kartlar hafif gecikmeli (stagger) belirir
  document.querySelectorAll("[data-reveal-group]").forEach(function (group) {
    gsap.from(group.children, {
      y: 32,
      autoAlpha: 0,
      duration: 0.6,
      ease: "power2.out",
      stagger: 0.12,
      scrollTrigger: { trigger: group, start: "top 84%", once: true }
    });
  });

  /* ---------- İmza öğesi: arka plan kum saati ----------
     Sayfanın arkasında sabit durur. Kum, ziyaretçi kaydırdıkça akar
     (aşağı = boşalır, yukarı = geri dolar); durunca akış da durur.
     Üst kum huni gibi çukurlaşır, altta konik bir tepecik yükselir. */
  var backdrop = document.getElementById("hg-backdrop");
  var hourglass = document.getElementById("hourglass");
  var stage = document.querySelector(".hourglass-stage");
  if (backdrop && hourglass) {
    if (stage) stage.classList.add("hg-js");

    var sandTop = document.getElementById("hg-sand-top");
    var sandPile = document.getElementById("hg-sand-pile");
    var timerEl = document.getElementById("hg-timer");
    var grains = Array.prototype.slice.call(hourglass.querySelectorAll(".hg-grain"));

    var TOTAL_SECONDS = 25 * 60;
    var isNarrow = window.matchMedia("(max-width: 960px)").matches;

    // Üst hazne: yüzey iner, ortadaki huni çukuru derinleşir
    function topPath(p) {
      var sy = 48 + 104 * p;                       // yüzey yüksekliği
      var dip = Math.min(10 + 30 * p, 158 - sy);   // huni çukuru
      return "M 56 " + sy +
             " Q 110 " + (sy + dip) + " 164 " + sy +
             " L 164 162 L 56 162 Z";
    }

    // Alt hazne: tepecik yükselir, yamaçlar yumuşak akar
    function pilePath(p) {
      var apex = 254 - 78 * p;
      return "M 54 258" +
             " Q " + (78 - 6 * p) + " " + (apex + 34) + " 104 " + (apex + 5) +
             " Q 110 " + apex + " 116 " + (apex + 5) +
             " Q " + (142 + 6 * p) + " " + (apex + 34) + " 166 258" +
             " L 166 262 L 54 262 Z";
    }

    function render(p) {
      sandTop.setAttribute("d", topPath(p));
      sandPile.setAttribute("d", pilePath(p));
      if (timerEl) {
        var left = Math.max(0, Math.round(TOTAL_SECONDS * (1 - p)));
        var m = Math.floor(left / 60);
        var s = left % 60;
        timerEl.textContent = (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s);
      }
      hourglass.classList.toggle("is-empty", p > 0.985);
      // Hero'dan sonra fısıltıya döner; içeriğin okunurluğunu bozmaz
      var alpha = gsap.utils.mapRange(0, 0.14, isNarrow ? 0.34 : 0.95, 0.24, Math.min(p, 0.14));
      backdrop.style.opacity = String(alpha);
    }

    render(0);

    // Taneler: akış çizgisi boyunca düşen küçük kum zerreleri
    var grainAnim = gsap.timeline({ repeat: -1, paused: true });
    grains.forEach(function (g, i) {
      grainAnim.fromTo(g,
        { attr: { cy: 164 + i * 6, cx: 110 + (i - 1) * 2 } },
        { attr: { cy: 246, cx: 110 + (i - 1) * 3.5 }, duration: 0.5, ease: "power1.in", repeat: -1 },
        i * 0.17);
    });

    // Akış durumu: yalnızca kullanıcı gerçekten kaydırırken kum dökülür
    var lastScrollAt = 0;
    var flowTicker = setInterval(function () {
      var flowing = performance.now() - lastScrollAt < 280;
      hourglass.classList.toggle("is-flowing", flowing);
      if (flowing) { grainAnim.play(); } else { grainAnim.pause(); }
    }, 120);
    void flowTicker;

    ScrollTrigger.create({
      trigger: document.body,
      start: "top top",
      end: "bottom bottom",
      scrub: 0.5,
      onUpdate: function (st) {
        lastScrollAt = performance.now();
        render(st.progress);
      }
    });

    window.addEventListener("load", function () { ScrollTrigger.refresh(); });

    // İmleç eğimi: yalnızca hassas işaretçide (masaüstü)
    if (window.matchMedia("(pointer: fine)").matches) {
      var tiltX = gsap.quickTo(hourglass, "rotation", { duration: 0.6, ease: "power2.out" });
      var shiftX = gsap.quickTo(hourglass, "x", { duration: 0.8, ease: "power2.out" });
      window.addEventListener("pointermove", function (e) {
        var ratio = e.clientX / window.innerWidth - 0.5; // -0.5 .. 0.5
        tiltX(ratio * 7);
        shiftX(ratio * 12);
      });
    }
  }

  /* ---------- Özellik satırları (features.html) ----------
     Satırlar normal akışta alt alta durur; görünüme girerken metin ve
     telefon iki yandan yumuşakça süzülür, maddeler sırayla belirir.
     Telefon ayrıca scroll'a bağlı hafif parallax ile yüzer. */
  var rows = gsap.utils.toArray(document.querySelectorAll(".feature-row"));
  var rowsNarrow = window.matchMedia("(max-width: 960px)").matches;
  rows.forEach(function (row) {
    var fromRight = row.classList.contains("reverse");
    var text = row.querySelector(".feature-row-text");
    var media = row.querySelector(".feature-row-media");
    var items = row.querySelectorAll(".feature-row-text li");

    var tl = gsap.timeline({
      scrollTrigger: { trigger: row, start: "top 80%", once: true }
    });
    // Dar ekranda tek kolon: yandan kaydırma taşma yaratır, alttan belirir
    if (text) {
      tl.from(text, rowsNarrow
        ? { y: 32, autoAlpha: 0, duration: 0.6, ease: "power2.out" }
        : { x: fromRight ? 56 : -56, autoAlpha: 0, duration: 0.7, ease: "power3.out" }, 0);
    }
    if (media) {
      tl.from(media, rowsNarrow
        ? { y: 36, autoAlpha: 0, duration: 0.65, ease: "power2.out" }
        : { x: fromRight ? -64 : 64, autoAlpha: 0, duration: 0.75, ease: "power3.out" }, 0.12);
    }
    if (items.length) {
      tl.from(items, { y: 16, autoAlpha: 0, duration: 0.4, stagger: 0.09, ease: "power2.out" }, 0.4);
    }

    var phone = row.querySelector(".phone");
    if (phone) {
      gsap.fromTo(phone, { y: 26 }, {
        y: -26,
        ease: "none",
        scrollTrigger: { trigger: row, start: "top bottom", end: "bottom top", scrub: 0.6 }
      });
    }
  });

  /* ---------- Pomodoro Nedir: zaman çizelgesi ----------
     Adımların yanındaki çizgi, kaydırdıkça yukarıdan aşağıya dolar. */
  var ptlFill = document.querySelector(".ptl-fill");
  if (ptlFill) {
    gsap.fromTo(ptlFill, { scaleY: 0 }, {
      scaleY: 1,
      ease: "none",
      transformOrigin: "top center",
      scrollTrigger: { trigger: ".ptl", start: "top 75%", end: "bottom 60%", scrub: 0.5 }
    });
  }
})();
