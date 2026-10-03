/* PomoSprint landing — nav, akordiyon, bekleme listesi, canlı sıralama ve GSAP animasyonları */
(function () {
  "use strict";

  var root = document.documentElement;
  var prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var api = window.PomoSupabase || null;

  // boot.js'in gizlediği hero'yu görünür yap (animasyon yoksa ya da kurulduysa)
  var revealHero = function () { root.classList.remove("js-anim"); };

  /* ---------- Mobil menü ---------- */
  var header = document.querySelector(".site-header");
  var navToggle = document.querySelector(".nav-toggle");
  if (header && navToggle) {
    var setNav = function (open) {
      header.classList.toggle("nav-open", open);
      navToggle.setAttribute("aria-expanded", open ? "true" : "false");
    };
    navToggle.addEventListener("click", function () {
      setNav(!header.classList.contains("nav-open"));
    });
    header.querySelectorAll(".site-nav a").forEach(function (link) {
      link.addEventListener("click", function () { setNav(false); });
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && header.classList.contains("nav-open")) {
        setNav(false);
        navToggle.focus();
      }
    });
  }

  /* ---------- Footer yılı ---------- */
  var yearEl = document.getElementById("year");
  if (yearEl) yearEl.textContent = String(new Date().getFullYear());

  // Sunucudan gelen avatar_id yalnızca güvenli karakterlerle yola eklenir
  var avatarSrc = function (id) {
    var safe = typeof id === "string" && /^[a-z0-9_]{1,64}$/.test(id) ? id : "avatar_16_basic";
    return "/avatars/" + safe + ".webp";
  };
  var setAvatar = function (img, id) {
    img.onerror = function () { img.onerror = null; img.src = "/avatars/avatar_16_basic.webp"; };
    img.src = avatarSrc(id);
  };

  /* ---------- "Haber ver" formu: waitlist tablosuna kayıt ----------
     Bot koruması: gizli tuzak alanı ve çok hızlı gönderim kontrolü.
     Aynı adres ikinci kez gönderilse de aynı teşekkür mesajı gösterilir;
     böylece form bir adresin listede olup olmadığını ele vermez. */
  var notifyForm = document.getElementById("notify-form");
  if (notifyForm) {
    var statusEl = document.getElementById("notify-status");
    var notifyBtn = notifyForm.querySelector("button[type=submit]");
    var notifyBtnLabel = notifyBtn ? notifyBtn.textContent : "";
    var honeypot = document.getElementById("notify-website");
    var formReadyAt = Date.now();
    var MIN_FILL_MS = 2500;

    var showStatus = function (msg, ok) {
      if (!statusEl) return;
      statusEl.textContent = msg;
      statusEl.classList.add("is-visible");
      statusEl.classList.toggle("is-ok", !!ok);
    };
    var setBusy = function (busy) {
      if (!notifyBtn) return;
      notifyBtn.disabled = busy;
      notifyBtn.textContent = busy ? "Gönderiliyor…" : notifyBtnLabel;
    };
    var MSG_THANKS = "Teşekkürler! Yayınlanınca sana haber vereceğiz 🚀";
    var MSG_INVALID = "Geçerli bir e-posta adresi girer misin?";
    var MSG_FAILED = "Bir şeyler ters gitti, tekrar dener misin?";

    var EMAIL_RE = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;

    notifyForm.addEventListener("submit", function (e) {
      e.preventDefault();
      var input = document.getElementById("notify-email");
      var email = ((input && input.value) || "").trim().toLowerCase();
      if (!email) return;
      if (!EMAIL_RE.test(email) || email.length > 254) {
        showStatus(MSG_INVALID, false);
        if (input) input.focus();
        return;
      }
      // Tuzak alanı dolduysa bot: kayıt göndermeden teşekkür et
      if (honeypot && honeypot.value) {
        showStatus(MSG_THANKS, true);
        notifyForm.reset();
        return;
      }
      if (Date.now() - formReadyAt < MIN_FILL_MS) {
        formReadyAt = Date.now();
        showStatus("Bir saniye… bir kez daha dener misin?", false);
        return;
      }
      if (!api) {
        showStatus(MSG_FAILED, false);
        return;
      }

      setBusy(true);
      api.request("/rest/v1/waitlist", {
        body: { email: email },
        prefer: "return=minimal"
      }).then(function (res) {
        setBusy(false);
        var code = api.errorCode(res.data);
        if (res.ok || res.status === 409 || code === "23505") {
          showStatus(MSG_THANKS, true);
          notifyForm.reset();
        } else if (code === "23514" || code === "22001") {
          showStatus(MSG_INVALID, false);
        } else {
          showStatus(MSG_FAILED, false);
        }
      }, function () {
        setBusy(false);
        showStatus(MSG_FAILED, false);
      });
    });
  }

  /* ---------- Canlı aylık sıralama (ana sayfa) ----------
     Herkese açık, oturum gerektirmeyen get_public_monthly_leaderboard RPC'si.
     Dönen alanlar: name, avatar_id, total_points (e-posta/id dönmez). */
  var lbList = document.getElementById("lb-list");
  var lbEmpty = document.getElementById("lb-empty");
  var lbPodium = document.getElementById("lb-podium");

  var showLeaderboardMessage = function (msg) {
    lbList.innerHTML = "";
    lbList.hidden = true;
    if (lbPodium) lbPodium.hidden = true;
    if (lbEmpty) {
      if (msg) lbEmpty.textContent = msg;
      lbEmpty.hidden = false;
    }
  };

  var fillPodiumSlot = function (rank, row) {
    var slot = document.getElementById("lb-podium-" + rank);
    if (!slot) return;
    if (!row) {
      slot.hidden = true;
      return;
    }
    slot.hidden = false;
    setAvatar(slot.querySelector(".lb-podium-avatar"), row.avatar_id);
    slot.querySelector(".lb-podium-name").textContent = row.name || "PomoSprint kullanıcısı";
    slot.querySelector(".lb-podium-points").textContent = (Number(row.total_points) || 0) + " puan";
  };

  var renderLeaderboard = function (rows) {
    if (!Array.isArray(rows) || !rows.length) {
      showLeaderboardMessage(null);
      return;
    }
    if (lbEmpty) lbEmpty.hidden = true;
    lbList.innerHTML = "";

    if (lbPodium) {
      lbPodium.hidden = false;
      fillPodiumSlot(1, rows[0]);
      fillPodiumSlot(2, rows[1]);
      fillPodiumSlot(3, rows[2]);
    }

    var rest = rows.slice(3);
    lbList.hidden = !rest.length;
    rest.forEach(function (row, i) {
      var li = document.createElement("li");
      li.className = "lb-item";

      var rank = document.createElement("span");
      rank.className = "lb-rank";
      rank.textContent = String(i + 4);
      li.appendChild(rank);

      var img = document.createElement("img");
      img.className = "lb-avatar";
      img.alt = "";
      img.loading = "lazy";
      img.width = 40;
      img.height = 40;
      setAvatar(img, row.avatar_id);
      li.appendChild(img);

      var name = document.createElement("span");
      name.className = "lb-name";
      name.textContent = row.name || "PomoSprint kullanıcısı";
      li.appendChild(name);

      var pts = document.createElement("span");
      pts.className = "lb-points";
      pts.textContent = (Number(row.total_points) || 0) + " puan";
      li.appendChild(pts);

      lbList.appendChild(li);
    });
  };

  var LB_ERROR = "Sıralama şu an yüklenemedi, sayfayı yenilemeyi dener misin?";
  var loadLeaderboard = function () {
    if (!lbList) return;
    if (!api) {
      showLeaderboardMessage(LB_ERROR);
      return;
    }
    api.request("/rest/v1/rpc/get_public_monthly_leaderboard", {
      body: { p_limit: 10 },
      timeout: 10000
    }).then(function (res) {
      if (!res.ok) {
        showLeaderboardMessage(LB_ERROR);
        return;
      }
      renderLeaderboard(res.data);
    }, function () {
      showLeaderboardMessage(LB_ERROR);
    });
  };
  loadLeaderboard();

  /* ---------- Aylık sıfırlanma sayacı ----------
     Ay sınırı Türkiye saatine (Europe/Istanbul) göre hesaplanır; ziyaretçinin
     saat dilimi farklı olsa da herkes aynı anı görür. Sayaç sıfırlandığında
     bir sonraki ay hedeflenir ve sıralama yeniden çekilir. */
  var lbCountdownTime = document.getElementById("lb-countdown-time");
  if (lbCountdownTime) {
    var TZ = "Europe/Istanbul";
    var tzFormatter = null;
    try {
      tzFormatter = new Intl.DateTimeFormat("en-US", {
        timeZone: TZ, hourCycle: "h23",
        year: "numeric", month: "numeric", day: "numeric",
        hour: "numeric", minute: "numeric", second: "numeric"
      });
    } catch (e) {
      tzFormatter = null;
    }

    // Verilen anın İstanbul'daki takvim parçaları (Intl yoksa sabit UTC+3)
    var istanbulParts = function (ms) {
      if (tzFormatter) {
        var p = {};
        tzFormatter.formatToParts(new Date(ms)).forEach(function (x) { p[x.type] = Number(x.value); });
        return p;
      }
      var d = new Date(ms + 3 * 3600 * 1000);
      return {
        year: d.getUTCFullYear(), month: d.getUTCMonth() + 1, day: d.getUTCDate(),
        hour: d.getUTCHours(), minute: d.getUTCMinutes(), second: d.getUTCSeconds()
      };
    };
    var istanbulOffsetMs = function (ms) {
      var p = istanbulParts(ms);
      var asUtc = Date.UTC(p.year, p.month - 1, p.day, p.hour % 24, p.minute, p.second);
      return asUtc - Math.floor(ms / 1000) * 1000;
    };
    var nextMonthlyReset = function () {
      var now = Date.now();
      var p = istanbulParts(now);
      var localMidnightAsUtc = Date.UTC(p.year, p.month, 1, 0, 0, 0); // bir sonraki ayın 1'i
      return localMidnightAsUtc - istanbulOffsetMs(localMidnightAsUtc);
    };

    var formatRemaining = function (diffMs) {
      var totalSeconds = Math.floor(diffMs / 1000);
      var days = Math.floor(totalSeconds / 86400);
      var hours = Math.floor((totalSeconds % 86400) / 3600);
      var minutes = Math.floor((totalSeconds % 3600) / 60);
      var seconds = totalSeconds % 60;
      if (days > 0) return days + " gün " + hours + " saat " + minutes + " dk";
      return hours + " saat " + minutes + " dk " + seconds + " sn";
    };

    var target = nextMonthlyReset();
    var tickCountdown = function () {
      var diff = target - Date.now();
      if (diff <= 0) {
        lbCountdownTime.textContent = "Sıfırlanıyor…";
        target = nextMonthlyReset();
        if (target - Date.now() > 0) setTimeout(loadLeaderboard, 5000);
        return;
      }
      lbCountdownTime.textContent = formatRemaining(diff);
    };
    tickCountdown();
    setInterval(tickCountdown, 1000);
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
     döngüde oynar. Listede olmayan ekranlar yer tutucusunu gösterir.
     Hareket azaltma tercihinde video oynatılmaz, yalnızca ilk karesi görünür. */
  var SHOT_VIDEOS = {
    timer: "/videos/timer.mp4",
    reports: "/videos/reports.mp4",
    leaderboard: "/videos/leaderboard.mp4",
    languages: "/videos/languages.mp4"
  };

  var videoObserver = (!prefersReduced && "IntersectionObserver" in window)
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
      v.playsInline = true;
      v.setAttribute("muted", "");
      v.setAttribute("playsinline", "");
      v.setAttribute("aria-hidden", "true");
      if (prefersReduced) {
        v.preload = "metadata";
      } else {
        v.loop = true;
        v.autoplay = true;
        v.preload = "auto";
      }
      v.dataset.src = SHOT_VIDEOS[key];
      v.addEventListener("loadeddata", function () {
        screen.classList.add("has-video");
        if (prefersReduced) return;
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
  if (prefersReduced || typeof gsap === "undefined") {
    revealHero();
    return;
  }

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
  // gsap.from başlangıç durumunu hemen uyguladığı için sınıf artık kaldırılabilir
  revealHero();

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
    // Dar ekranda kum saati hero metninin arkasına düşer: okunurluk için soluk başlar
    var isNarrow = window.matchMedia("(max-width: 960px)").matches;

    // Üst hazne: yüzey iner, ortadaki huni çukuru derinleşir
    var topPath = function (p) {
      var sy = 48 + 104 * p;                       // yüzey yüksekliği
      var dip = Math.min(10 + 30 * p, 158 - sy);   // huni çukuru
      return "M 56 " + sy +
             " Q 110 " + (sy + dip) + " 164 " + sy +
             " L 164 162 L 56 162 Z";
    };

    // Alt hazne: tepecik yükselir, yamaçlar yumuşak akar
    var pilePath = function (p) {
      var apex = 254 - 78 * p;
      return "M 54 258" +
             " Q " + (78 - 6 * p) + " " + (apex + 34) + " 104 " + (apex + 5) +
             " Q 110 " + apex + " 116 " + (apex + 5) +
             " Q " + (142 + 6 * p) + " " + (apex + 34) + " 166 258" +
             " L 166 262 L 54 262 Z";
    };

    var render = function (p) {
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
      var startAlpha = isNarrow ? 0.16 : 0.95;
      var endAlpha = isNarrow ? 0.14 : 0.24;
      var alpha = gsap.utils.mapRange(0, 0.14, startAlpha, endAlpha, Math.min(p, 0.14));
      backdrop.style.opacity = String(alpha);
    };

    render(0);

    // Taneler: akış çizgisi boyunca düşen küçük kum zerreleri
    var grainAnim = gsap.timeline({ repeat: -1, paused: true });
    grains.forEach(function (g, i) {
      grainAnim.fromTo(g,
        { attr: { cy: 164 + i * 6, cx: 110 + (i - 1) * 2 } },
        { attr: { cy: 246, cx: 110 + (i - 1) * 3.5 }, duration: 0.5, ease: "power1.in", repeat: -1 },
        i * 0.17);
    });

    // Akış yalnızca kullanıcı gerçekten kaydırırken sürer; kaydırma durunca
    // 280 ms sonra durur (sürekli çalışan bir zamanlayıcı gerekmez)
    var stopFlowTimer = null;
    var stopFlow = function () {
      stopFlowTimer = null;
      hourglass.classList.remove("is-flowing");
      grainAnim.pause();
    };
    var markFlowing = function () {
      if (!stopFlowTimer) {
        hourglass.classList.add("is-flowing");
        grainAnim.play();
      } else {
        clearTimeout(stopFlowTimer);
      }
      stopFlowTimer = setTimeout(stopFlow, 280);
    };

    ScrollTrigger.create({
      trigger: document.body,
      start: "top top",
      end: "bottom bottom",
      scrub: 0.5,
      onUpdate: function (st) {
        markFlowing();
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
