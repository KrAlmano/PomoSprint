/* PomoSprint landing — nav, akordiyon, bekleme listesi, canlı sıralama ve GSAP animasyonları */
(function () {
  "use strict";

  var root = document.documentElement;
  var prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var api = window.PomoSupabase || null;

  // boot.js'in gizlediği hero'yu görünür yap (animasyon yoksa ya da kurulduysa)
  var revealHero = function () { root.classList.remove("js-anim"); };

  /* ---------- Mobil menü ----------
     Açıkken sayfa kaydırması kilitlenir ve arkada karartma görünür (CSS:
     html.nav-lock). Menü dışına dokunmak, Escape ya da geniş ekrana geçmek
     menüyü kapatır. */
  var header = document.querySelector(".site-header");
  var navToggle = document.querySelector(".nav-toggle");
  if (header && navToggle) {
    var setNav = function (open) {
      header.classList.toggle("nav-open", open);
      root.classList.toggle("nav-lock", open);
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
    document.addEventListener("click", function (e) {
      if (header.classList.contains("nav-open") && !header.contains(e.target)) setNav(false);
    });
    var navMq = window.matchMedia("(max-width: 760px)");
    var onNavMq = function () { if (!navMq.matches) setNav(false); };
    if (navMq.addEventListener) navMq.addEventListener("change", onNavMq);
    else if (navMq.addListener) navMq.addListener(onNavMq);
  }

  /* ---------- Yasal sayfalar: içindekiler geniş ekranda açık başlar ---------- */
  var toc = document.querySelector("details.toc");
  if (toc && window.matchMedia("(min-width: 761px)").matches) toc.open = true;

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
     Bot koruması: gizli tuzak alanı, sayfada gerçek bir etkileşim (tuş ya da
     dokunma) olmadan gönderimin reddi ve en kısa doldurma süresi. Süre
     dolmadan gönderilirse kullanıcıya tekrar sorulmaz; kalan süre beklenip
     kendiliğinden gönderilir. Aynı adres ikinci kez gönderilse de aynı
     teşekkür gösterilir; form bir adresin listede olup olmadığını ele vermez.
     Ticari elektronik ileti onayı (6563 sayılı Kanun) ayrı ve önceden
     işaretsiz bir kutuyla alınır: kutu işaretlenmeden (ya da sayfada yoksa)
     kayıt gönderilmez. waitlist tablosunda onay kolonu olmadığı için istekte
     yalnızca e-posta gider; onay kaydı için bkz. supabase/proposed/19. */
  var notifyForm = document.getElementById("notify-form");
  var notifyInput = document.getElementById("notify-email");
  if (notifyForm && notifyInput) {
    var statusEl = document.getElementById("notify-status");
    var successEl = document.getElementById("notify-success");
    var notifyBtn = notifyForm.querySelector("button[type=submit]");
    var notifyBtnLabel = notifyBtn ? notifyBtn.textContent : "";
    var honeypot = document.getElementById("notify-website");
    var consentBox = document.getElementById("notify-consent");
    var formReadyAt = Date.now();
    var MIN_FILL_MS = 2500;
    var sending = false;
    var hadInteraction = false;
    var markInteraction = function (e) { if (e.isTrusted) hadInteraction = true; };
    document.addEventListener("keydown", markInteraction, true);
    document.addEventListener("pointerdown", markInteraction, true);

    var MSG_EMPTY = "E-posta adresini yazar mısın?";
    var MSG_INVALID = "Geçerli bir e-posta adresi girer misin?";
    var MSG_FAILED = "Bir şeyler ters gitti, tekrar dener misin?";
    var MSG_CONSENT = "Sana haber verebilmemiz için onay kutusunu işaretlemen gerekiyor.";
    var EMAIL_RE = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;

    var hideStatus = function () {
      if (!statusEl) return;
      statusEl.textContent = "";
      statusEl.classList.remove("is-visible");
    };
    var showStatus = function (msg) {
      if (!statusEl) return;
      statusEl.textContent = msg;
      statusEl.classList.add("is-visible");
    };
    var clearInvalid = function () {
      notifyInput.removeAttribute("aria-invalid");
      notifyInput.removeAttribute("aria-describedby");
    };
    var showError = function (msg) {
      showStatus(msg);
      notifyInput.setAttribute("aria-invalid", "true");
      notifyInput.setAttribute("aria-describedby", "notify-status");
      notifyInput.focus();
    };
    var clearConsentInvalid = function () {
      if (!consentBox) return;
      consentBox.removeAttribute("aria-invalid");
      consentBox.removeAttribute("aria-describedby");
    };
    var showConsentError = function () {
      showStatus(MSG_CONSENT);
      if (!consentBox) return;
      consentBox.setAttribute("aria-invalid", "true");
      consentBox.setAttribute("aria-describedby", "notify-status");
      consentBox.focus();
    };
    var setBusy = function (busy) {
      sending = busy;
      if (!notifyBtn) return;
      notifyBtn.disabled = busy;
      notifyBtn.textContent = busy ? "Gönderiliyor…" : notifyBtnLabel;
    };
    // Başarıda form yerine onay kartı görünür; odak karta taşınır ki ekran okuyucu okusun
    var showSuccess = function () {
      setBusy(false);
      hideStatus();
      notifyForm.reset();
      notifyForm.hidden = true;
      if (successEl) {
        successEl.hidden = false;
        successEl.focus();
      }
    };

    notifyInput.addEventListener("input", function () {
      if (notifyInput.hasAttribute("aria-invalid")) {
        clearInvalid();
        hideStatus();
      }
    });
    if (consentBox) {
      consentBox.addEventListener("change", function () {
        if (consentBox.checked && consentBox.hasAttribute("aria-invalid")) {
          clearConsentInvalid();
          hideStatus();
        }
      });
    }

    var sendEmail = function (email) {
      // Bekleme süresinde kutu kaldırıldıysa yine gönderme
      if (!consentBox || !consentBox.checked) {
        setBusy(false);
        showConsentError();
        return;
      }
      if (!api) {
        setBusy(false);
        showStatus(MSG_FAILED);
        return;
      }
      api.request("/rest/v1/waitlist", {
        body: { email: email },
        prefer: "return=minimal"
      }).then(function (res) {
        var code = api.errorCode(res.data);
        if (res.ok || res.status === 409 || code === "23505") {
          showSuccess();
        } else if (code === "23514" || code === "22001") {
          setBusy(false);
          showError(MSG_INVALID);
        } else {
          setBusy(false);
          showStatus(MSG_FAILED);
        }
      }, function () {
        setBusy(false);
        showStatus(MSG_FAILED);
      });
    };

    notifyForm.addEventListener("submit", function (e) {
      e.preventDefault();
      if (sending) return;
      var email = (notifyInput.value || "").trim().toLowerCase();
      if (!email) {
        showError(MSG_EMPTY);
        return;
      }
      if (!EMAIL_RE.test(email) || email.length > 254) {
        showError(MSG_INVALID);
        return;
      }
      clearInvalid();
      // Onay kutusu işaretli değilse kayıt yok
      if (!consentBox || !consentBox.checked) {
        showConsentError();
        return;
      }
      clearConsentInvalid();
      hideStatus();
      // Tuzak alanı dolduysa ya da sayfada hiç gerçek etkileşim yoksa bot:
      // kayıt göndermeden teşekkür et
      if ((honeypot && honeypot.value) || !hadInteraction) {
        showSuccess();
        return;
      }
      setBusy(true);
      var wait = MIN_FILL_MS - (Date.now() - formReadyAt);
      if (wait > 0) {
        setTimeout(function () { sendEmail(email); }, wait);
      } else {
        sendEmail(email);
      }
    });
  }

  /* ---------- Canlı aylık sıralama (ana sayfa) ----------
     Herkese açık, oturum gerektirmeyen get_public_monthly_leaderboard RPC'si.
     Dönen alanlar: name, avatar_id, total_points (e-posta/id dönmez).
     Bölüm gizli başlar: lansman öncesi boş ya da çok kısa bir liste "kimse
     kullanmıyor" izlenimi vermesin diye en az 3 kişi varsa gösterilir;
     hata durumunda da gizli kalır. */
  var lbSection = document.getElementById("siralama");
  var lbList = document.getElementById("lb-list");
  var lbPodium = document.getElementById("lb-podium");
  var LB_MIN_ROWS = 3;

  var hideLeaderboard = function () {
    if (lbSection) lbSection.hidden = true;
  };
  var revealLeaderboard = function () {
    if (!lbSection || !lbSection.hidden) return;
    lbSection.hidden = false;
    // Sayfa uzadı: kaydırma tetikleyicilerinin konumlarını yeniden hesapla
    if (window.ScrollTrigger) window.ScrollTrigger.refresh();
  };
  var formatPoints = function (value) {
    var n = Number(value) || 0;
    try {
      return n.toLocaleString("tr-TR") + " puan";
    } catch (e) {
      return n + " puan";
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
    slot.querySelector(".lb-podium-points").textContent = formatPoints(row.total_points);
  };

  var renderLeaderboard = function (rows) {
    if (!Array.isArray(rows) || rows.length < LB_MIN_ROWS) {
      hideLeaderboard();
      return;
    }
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
      pts.textContent = formatPoints(row.total_points);
      li.appendChild(pts);

      lbList.appendChild(li);
    });
    revealLeaderboard();
  };

  var loadLeaderboard = function () {
    if (!lbList) return;
    if (!api) {
      hideLeaderboard();
      return;
    }
    api.request("/rest/v1/rpc/get_public_monthly_leaderboard", {
      body: { p_limit: 10 },
      timeout: 10000
    }).then(function (res) {
      if (!res.ok) {
        hideLeaderboard();
        return;
      }
      renderLeaderboard(res.data);
    }, function () {
      hideLeaderboard();
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
     döngüde oynar. Listede olmayan ekranlar yer tutucusunu (ya da örnek
     görünümü) gösterir. Her videonun ilk karesi poster olarak hemen görünür;
     böylece video yüklenmese de (iOS Düşük Güç Modu, autoplay engeli) ekran
     boş kalmaz. Hareket azaltma tercihinde video hiç indirilmez, yalnızca
     poster görünür.
     Eski arayüzü gösteren leaderboard.mp4 ve reports.mp4 güncel kayıt
     gelene kadar listeden çıkarıldı (yer tutucu görünür). */
  var SHOT_VIDEOS = {
    timer: { src: "/videos/timer.mp4", poster: "/videos/timer.webp" },
    languages: { src: "/videos/languages.mp4", poster: "/videos/languages.webp" }
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
  var lazyLoader = (!prefersReduced && "IntersectionObserver" in window)
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
    var shot = SHOT_VIDEOS[key];
    document.querySelectorAll('.phone-screen[data-shot="' + key + '"]').forEach(function (screen) {
      var markReady = function () { screen.classList.add("has-video"); };
      var v = document.createElement("video");
      v.className = "shot-video";
      v.muted = true;
      v.playsInline = true;
      v.setAttribute("muted", "");
      v.setAttribute("playsinline", "");
      v.setAttribute("aria-hidden", "true");
      v.preload = prefersReduced ? "none" : "auto";

      // Poster yüklenince yer tutucu hemen kalkar
      if (shot.poster) {
        var probe = new Image();
        probe.onload = markReady;
        probe.src = shot.poster;
        v.poster = shot.poster;
      }
      screen.appendChild(v);
      if (prefersReduced) return;

      v.loop = true;
      v.autoplay = true;
      v.dataset.src = shot.src;
      v.addEventListener("loadeddata", function () {
        markReady();
        var pr = v.play();
        if (pr && pr.catch) pr.catch(function () {});
        if (videoObserver) videoObserver.observe(v);
      });
      if (lazyLoader) {
        lazyLoader.observe(v);
      } else {
        v.src = shot.src;
      }
    });
  });

  /* ---------- Arka plan kum saati: GSAP'sız yedek ----------
     Hareket azaltma tercihinde ya da GSAP yüklenemediğinde kum akmaz;
     arka plan kopyası yalnızca hero geride kalınca (geçişsiz) soluk belirir. */
  var backdrop = document.getElementById("hg-backdrop");
  var heroSection = document.querySelector(".hero");
  var staticBackdrop = function () {
    if (!backdrop || !heroSection) return;
    var update = function () {
      root.classList.toggle("hg-past-hero", window.scrollY > heroSection.offsetHeight * 0.6);
    };
    update();
    window.addEventListener("scroll", update, { passive: true });
  };

  /* ---------- GSAP animasyonları ---------- */
  if (prefersReduced || typeof gsap === "undefined") {
    revealHero();
    staticBackdrop();
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
  // Sayfa başlığı (LCP öğesi) hiç gizlenmez; yalnızca hafifçe yukarı kayar
  var heroTitles = document.querySelectorAll("[data-hero-title]");
  if (heroTitles.length) {
    gsap.from(heroTitles, { y: 16, duration: 0.5, ease: "power2.out", clearProps: "transform" });
  }
  // gsap.from başlangıç durumunu hemen uyguladığı için sınıf artık kaldırılabilir
  revealHero();

  if (typeof ScrollTrigger === "undefined") {
    staticBackdrop();
    return;
  }

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

  /* ---------- İmza öğesi: kum saati ----------
     Hero'daki kum saati ile sabit arka plan kopyası aynı anda çizilir. Kum,
     ziyaretçi kaydırdıkça akar (aşağı = boşalır, yukarı = geri dolar); durunca
     akış da durur. Üst kum huni gibi çukurlaşır, altta konik bir tepecik
     yükselir. Arka plan kopyası hero görünürken gizlidir, hero geride
     kalırken soluk olarak belirir; böylece hero'daki rozetler her genişlikte
     kendi kum saatine bağlı kalır. */
  var glasses = Array.prototype.slice.call(document.querySelectorAll(".hourglass"));
  if (glasses.length) {
    var sandTops = Array.prototype.slice.call(document.querySelectorAll(".hg-sand-top"));
    var sandPiles = Array.prototype.slice.call(document.querySelectorAll(".hg-sand-pile"));
    var timerEl = document.getElementById("hg-timer");

    var TOTAL_SECONDS = 25 * 60;
    // Dar ekranda arka plan kopyası içeriğin arkasına düşer: daha da soluk kalır
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
      var tp = topPath(p);
      var pp = pilePath(p);
      sandTops.forEach(function (el) { el.setAttribute("d", tp); });
      sandPiles.forEach(function (el) { el.setAttribute("d", pp); });
      if (timerEl) {
        var left = Math.max(0, Math.round(TOTAL_SECONDS * (1 - p)));
        var m = Math.floor(left / 60);
        var s = left % 60;
        timerEl.textContent = (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s);
      }
      var empty = p > 0.985;
      glasses.forEach(function (g) { g.classList.toggle("is-empty", empty); });
    };

    render(0);

    // Arka plan kopyası: hero'nun alt kenarı ekranın üst kısmına yaklaşırken belirir
    if (backdrop) {
      var endAlpha = isNarrow ? 0.14 : 0.24;
      if (heroSection) {
        gsap.fromTo(backdrop, { opacity: 0 }, {
          opacity: endAlpha,
          ease: "none",
          scrollTrigger: { trigger: heroSection, start: "bottom 70%", end: "bottom 10%", scrub: 0.4 }
        });
      } else {
        backdrop.style.opacity = String(endAlpha);
      }
    }

    // Taneler: akış çizgisi boyunca düşen küçük kum zerreleri (her kum saatinde)
    var grainAnim = gsap.timeline({ repeat: -1, paused: true });
    glasses.forEach(function (glass) {
      Array.prototype.slice.call(glass.querySelectorAll(".hg-grain")).forEach(function (g, i) {
        grainAnim.fromTo(g,
          { attr: { cy: 164 + i * 6, cx: 110 + (i - 1) * 2 } },
          { attr: { cy: 246, cx: 110 + (i - 1) * 3.5 }, duration: 0.5, ease: "power1.in", repeat: -1 },
          i * 0.17);
      });
    });

    // Akış yalnızca kullanıcı gerçekten kaydırırken sürer; kaydırma durunca
    // 280 ms sonra durur (sürekli çalışan bir zamanlayıcı gerekmez)
    var stopFlowTimer = null;
    var setFlowing = function (on) {
      glasses.forEach(function (g) { g.classList.toggle("is-flowing", on); });
    };
    var stopFlow = function () {
      stopFlowTimer = null;
      setFlowing(false);
      grainAnim.pause();
    };
    var markFlowing = function () {
      if (!stopFlowTimer) {
        setFlowing(true);
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
      var tilts = glasses.map(function (g) {
        return {
          rot: gsap.quickTo(g, "rotation", { duration: 0.6, ease: "power2.out" }),
          x: gsap.quickTo(g, "x", { duration: 0.8, ease: "power2.out" })
        };
      });
      window.addEventListener("pointermove", function (e) {
        var ratio = e.clientX / window.innerWidth - 0.5; // -0.5 .. 0.5
        tilts.forEach(function (t) {
          t.rot(ratio * 7);
          t.x(ratio * 12);
        });
      });
    }
  }

  /* ---------- Özellik satırları (features.html) ----------
     Satırlar normal akışta alt alta durur; görünüme girerken metin ve
     telefon iki yandan yumuşakça süzülür, maddeler sırayla belirir.
     Telefon ayrıca scroll'a bağlı hafif parallax ile yüzer. */
  var rows = gsap.utils.toArray(document.querySelectorAll(".feature-row"));
  var rowsNarrow = window.matchMedia("(max-width: 720px)").matches;
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
