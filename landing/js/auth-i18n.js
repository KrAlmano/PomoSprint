/* Yardımcı sayfalar (şifre sıfırlama, e-posta onayı, abonelikten çıkma) için
   dil seçimi. Öncelik: bağlantıdaki ?lang=tr|en (e-posta şablonu ekleyebilir),
   yoksa tarayıcı dili (Türkçe dışındaki her dil İngilizce).
   use(sözlük) seçilen dilin metinlerini döndürür; data-i18n öğelerinin
   metnini, data-i18n-aria öğelerinin aria-label'ını ve sayfa başlığını yazar.
   Bu dosya, sayfanın kendi betiğinden önce yüklenmelidir (URL temizlenmeden). */
(function () {
  "use strict";

  var fromLink = function () {
    try {
      var q = new URLSearchParams(window.location.search).get("lang");
      if (!q) q = new URLSearchParams(window.location.hash.replace(/^#/, "")).get("lang");
      q = (q || "").toLowerCase();
      return q === "tr" || q === "en" ? q : "";
    } catch (e) {
      return "";
    }
  };

  var fromBrowser = function () {
    var list = navigator.languages && navigator.languages.length ? navigator.languages : [navigator.language || "tr"];
    return /^tr\b/i.test(String(list[0] || "")) ? "tr" : "en";
  };

  var lang = fromLink() || fromBrowser();

  window.PomoI18n = {
    lang: lang,
    use: function (dict) {
      var t = dict[lang] || dict.tr;
      document.documentElement.lang = lang;
      if (t._title) document.title = t._title;
      document.querySelectorAll("[data-i18n]").forEach(function (el) {
        var key = el.getAttribute("data-i18n");
        if (typeof t[key] === "string") el.textContent = t[key];
      });
      document.querySelectorAll("[data-i18n-aria]").forEach(function (el) {
        var key = el.getAttribute("data-i18n-aria");
        if (typeof t[key] === "string") el.setAttribute("aria-label", t[key]);
      });
      return t;
    }
  };
})();
