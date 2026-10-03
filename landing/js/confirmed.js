/* E-posta onayı dönüş sayfası.
   Supabase /verify sonucu:
     Implicit akış -> #access_token=...&type=signup
     PKCE (eski sürümler) -> ?code=...  (yönlendirme yalnızca onay başarılıysa olur)
     Hata -> #error=...&error_code=...  (ya da aynı alanlar query'de)
   Parametresiz açılışta "onaylandı" denmez. URL'deki token hemen silinir ve
   bu tarayıcıda açılan oturum kapatılır; giriş uygulamada yapılır.
   Metinler Türkçe ve İngilizce; dil auth-i18n.js ile seçilir. Satır sonunda
   "e-" / "posta" diye bölünmesin diye tireden sonra U+2060 (kelime birleştirici) var. */
(function () {
  "use strict";

  var TEXT = {
    tr: {
      _title: "E-posta Onayı — PomoSprint",
      home: "PomoSprint ana sayfa",
      title: "E-posta Onayı",
      intro: "Bu sayfa, PomoSprint'ten gelen onay e-\u2060postasındaki bağlantıyla açılır. Hesabını onaylamak için e-\u2060postandaki bağlantıya dokun.",
      home_link: "Ana sayfaya git",
      foot: "Sorun mu yaşıyorsun?",
      invalidTitle: "Onay Bağlantısı Geçersiz",
      expired: "Bu onay bağlantısının süresi dolmuş ya da bağlantı daha önce kullanılmış. Uygulamada giriş yapmayı dene; e-\u2060postan henüz onaylanmadıysa yeni bir onay e-\u2060postası isteyebilirsin.",
      invalid: "Bu onay bağlantısı geçersiz. Uygulamada giriş yapmayı dene; e-\u2060postan henüz onaylanmadıysa yeni bir onay e-\u2060postası isteyebilirsin.",
      okTitle: "E-postan Onaylandı!",
      okBody: "Harika, PomoSprint hesabın artık aktif. Uygulamaya dön ve e-\u2060posta adresin ile şifrenle giriş yap."
    },
    en: {
      _title: "Email Confirmation — PomoSprint",
      home: "PomoSprint home page",
      title: "Email Confirmation",
      intro: "This page opens from the link in the confirmation email sent by PomoSprint. To confirm your account, tap the link in that email.",
      home_link: "Go to the home page",
      foot: "Having trouble?",
      invalidTitle: "Invalid Confirmation Link",
      expired: "This confirmation link has expired or has already been used. Try signing in in the app; if your email isn't confirmed yet, you can request a new confirmation email.",
      invalid: "This confirmation link is invalid. Try signing in in the app; if your email isn't confirmed yet, you can request a new confirmation email.",
      okTitle: "Email Confirmed!",
      okBody: "Great, your PomoSprint account is now active. Go back to the app and sign in with your email address and password."
    }
  };
  var T = window.PomoI18n ? window.PomoI18n.use(TEXT) : TEXT.tr;

  var hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ""));
  var queryParams = new URLSearchParams(window.location.search);
  var accessToken = hashParams.get("access_token");
  var code = queryParams.get("code");
  var error = hashParams.get("error") || queryParams.get("error");
  var errorCode = hashParams.get("error_code") || queryParams.get("error_code");
  if (window.location.search || window.location.hash) {
    try { window.history.replaceState(null, "", window.location.pathname); } catch (e) { /* yoksay */ }
  }

  var icon = document.getElementById("icon");
  var title = document.getElementById("title");
  var message = document.getElementById("message");
  var homeLink = document.getElementById("home-link");

  var show = function (state, heading, text) {
    icon.setAttribute("data-icon", state);
    title.textContent = heading;
    message.textContent = text;
    homeLink.hidden = true;
  };

  if (error || errorCode) {
    show("warn", T.invalidTitle, errorCode === "otp_expired" ? T.expired : T.invalid);
    return;
  }

  if (accessToken || code) {
    show("ok", T.okTitle, T.okBody);
    // Onay bağlantısının tarayıcıda açtığı oturuma ihtiyaç yok: yalnızca bu oturumu kapat
    if (accessToken && window.PomoSupabase) {
      window.PomoSupabase.request("/auth/v1/logout?scope=local", { token: accessToken })
        .then(null, function () {});
    }
  }
})();
