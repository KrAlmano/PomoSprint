/* Şifre sıfırlama sayfası.
   Desteklenen bağlantı biçimleri:
   1) Implicit akış (uygulamanın kullandığı): #access_token=...&type=recovery
   2) E-posta şablonu token_hash ile: ?token_hash=...&type=recovery
      Token yalnızca form gönderilince doğrulanır; böylece bağlantıyı önceden
      açan e-posta tarayıcıları tek kullanımlık token'ı tüketemez.
   3) ?code=... : eski (PKCE) sürümden gelen bağlantı; tarayıcıda takas edilemez.
   Hata durumunda URL'deki error_description gösterilmez, yalnızca error_code
   sabit metinlere eşlenir (resmi alan adında keyfi metin basılamasın).
   Metinler Türkçe ve İngilizce; dil auth-i18n.js ile seçilir (?lang=en ya da
   tarayıcı dili). */
(function () {
  "use strict";

  var api = window.PomoSupabase;

  var TEXT = {
    tr: {
      _title: "Şifreni Sıfırla — PomoSprint",
      home: "PomoSprint ana sayfa",
      title: "Yeni Şifre Belirle",
      checking: "Bağlantın kontrol ediliyor…",
      pw1: "Yeni şifre",
      pw2: "Yeni şifre (tekrar)",
      hint: "En az 8 karakter; en az bir küçük harf, bir büyük harf ve bir rakam.",
      submit: "Şifreyi Güncelle",
      busy: "Güncelleniyor…",
      foot: "Sorun mu yaşıyorsun?",
      enterNew: "Hesabın için yeni bir şifre gir.",
      invalidTitle: "Bağlantı Geçersiz",
      successTitle: "Şifren Güncellendi!",
      successBody: "Şimdi PomoSprint uygulamasına dön ve yeni şifrenle giriş yap.",
      newLink: " Uygulamada “Şifremi unuttum” ile yeni bir bağlantı isteyebilirsin.",
      invalid: "Bu şifre sıfırlama bağlantısı geçersiz.",
      expired: "Bu bağlantının süresi dolmuş ya da bağlantı daha önce kullanılmış.",
      session: "Şifre sıfırlama oturumunun süresi dolmuş.",
      oldLink: "Bu bağlantı uygulamanın eski bir sürümünden geliyor ve tarayıcıda açılamıyor. Uygulamayı güncelleyip “Şifremi unuttum” ile yeni bir bağlantı iste.",
      samePassword: "Yeni şifren eski şifrenle aynı olamaz. Farklı bir şifre seç.",
      weakPassword: "Bu şifre çok zayıf. En az 1 küçük harf (a-z), 1 büyük harf (A-Z) ve 1 rakam (0-9) içermeli.",
      pwnedPassword: "Bu şifre daha önce bir veri sızıntısında görülmüş. Farklı bir şifre seç.",
      rateLimit: "Kısa sürede çok fazla deneme yapıldı. Birkaç dakika bekleyip tekrar dene.",
      tooShort: "Şifre en az 8 karakter olmalı.",
      tooLong: "Şifre en fazla 72 karakter olabilir.",
      mismatch: "Girdiğin şifreler eşleşmiyor.",
      network: "Bağlantı hatası. İnternet bağlantını kontrol edip tekrar dene.",
      generic: "Şifre güncellenemedi, lütfen tekrar dene."
    },
    en: {
      _title: "Reset Your Password — PomoSprint",
      home: "PomoSprint home page",
      title: "Set a New Password",
      checking: "Checking your link…",
      pw1: "New password",
      pw2: "New password (again)",
      hint: "At least 8 characters, including a lowercase letter, an uppercase letter and a number.",
      submit: "Update Password",
      busy: "Updating…",
      foot: "Having trouble?",
      enterNew: "Enter a new password for your account.",
      invalidTitle: "Invalid Link",
      successTitle: "Password Updated!",
      successBody: "Now go back to the PomoSprint app and sign in with your new password.",
      newLink: " You can request a new link in the app with “Forgot password”.",
      invalid: "This password reset link is invalid.",
      expired: "This link has expired or has already been used.",
      session: "Your password reset session has expired.",
      oldLink: "This link comes from an older version of the app and can't be opened in the browser. Update the app and request a new link with “Forgot password”.",
      samePassword: "Your new password can't be the same as your old one. Choose a different password.",
      weakPassword: "This password is too weak. It must contain at least 1 lowercase letter (a-z), 1 uppercase letter (A-Z) and 1 number (0-9).",
      pwnedPassword: "This password has appeared in a data breach. Choose a different password.",
      rateLimit: "Too many attempts in a short time. Wait a few minutes and try again.",
      tooShort: "Your password must be at least 8 characters.",
      tooLong: "Your password can be at most 72 characters.",
      mismatch: "The passwords you entered don't match.",
      network: "Connection error. Check your internet connection and try again.",
      generic: "Your password couldn't be updated. Please try again."
    }
  };
  var T = window.PomoI18n ? window.PomoI18n.use(TEXT) : TEXT.tr;

  // Tek kullanımlık bilgileri belleğe al, adres çubuğundan ve geçmişten hemen sil
  var hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ""));
  var queryParams = new URLSearchParams(window.location.search);
  var link = {
    accessToken: hashParams.get("access_token"),
    tokenHash: queryParams.get("token_hash"),
    type: hashParams.get("type") || queryParams.get("type"),
    code: queryParams.get("code"),
    error: hashParams.get("error") || queryParams.get("error"),
    errorCode: hashParams.get("error_code") || queryParams.get("error_code")
  };
  if (window.location.search || window.location.hash) {
    try { window.history.replaceState(null, "", window.location.pathname); } catch (e) { /* yoksay */ }
  }

  var icon = document.getElementById("icon");
  var title = document.getElementById("title");
  var message = document.getElementById("message");
  var form = document.getElementById("form");
  var pw1 = document.getElementById("pw1");
  var pw2 = document.getElementById("pw2");
  var submitBtn = document.getElementById("submit");
  var errorEl = document.getElementById("error");
  var submitLabel = T.submit;

  var MSG = {
    invalid: T.invalid + T.newLink,
    expired: T.expired + T.newLink,
    session: T.session + T.newLink,
    oldLink: T.oldLink,
    samePassword: T.samePassword,
    weakPassword: T.weakPassword,
    pwnedPassword: T.pwnedPassword,
    rateLimit: T.rateLimit,
    tooShort: T.tooShort,
    tooLong: T.tooLong,
    mismatch: T.mismatch,
    network: T.network,
    generic: T.generic
  };

  // weak_password yanıtındaki nedenlere göre en açıklayıcı mesaj
  // (GoTrue: { code: "weak_password", weak_password: { reasons: [...] } })
  var weakPasswordText = function (data) {
    var reasons = (data && data.weak_password && data.weak_password.reasons) || [];
    if (reasons.indexOf("pwned") !== -1) return MSG.pwnedPassword;
    if (reasons.indexOf("length") !== -1 && reasons.indexOf("characters") === -1) return MSG.tooShort;
    return MSG.weakPassword;
  };

  // Bağlantıyı tamamen geçersiz kılan kodlar (form gizlenir)
  var LINK_ERRORS = {
    otp_expired: MSG.expired,
    otp_disabled: MSG.invalid,
    access_denied: MSG.invalid,
    flow_state_expired: MSG.oldLink,
    flow_state_not_found: MSG.oldLink,
    bad_code_verifier: MSG.oldLink,
    session_not_found: MSG.session,
    session_expired: MSG.session,
    bad_jwt: MSG.session,
    no_authorization: MSG.session,
    user_not_found: MSG.invalid
  };
  // Formda kalınarak düzeltilebilen kodlar
  var FORM_ERRORS = {
    same_password: MSG.samePassword,
    weak_password: MSG.weakPassword,
    over_email_send_rate_limit: MSG.rateLimit,
    over_request_rate_limit: MSG.rateLimit,
    validation_failed: MSG.generic
  };

  var showInvalid = function (text) {
    icon.setAttribute("data-icon", "warn");
    title.textContent = T.invalidTitle;
    message.textContent = text;
    form.hidden = true;
  };

  var showForm = function () {
    message.textContent = T.enterNew;
    form.hidden = false;
    pw1.focus();
  };

  var showSuccess = function () {
    icon.setAttribute("data-icon", "ok");
    title.textContent = T.successTitle;
    message.textContent = T.successBody;
    form.hidden = true;
  };

  var setBusy = function (busy) {
    submitBtn.disabled = busy;
    submitBtn.textContent = busy ? T.busy : submitLabel;
  };

  // JWT'deki e-postayı parola yöneticileri için gizli kullanıcı adı alanına yazar
  var prefillUsername = function (jwt) {
    try {
      var part = jwt.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
      var bin = window.atob(part);
      var bytes = new Uint8Array(bin.length);
      for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
      var payload = JSON.parse(new TextDecoder().decode(bytes));
      if (payload && typeof payload.email === "string") {
        document.getElementById("username").value = payload.email;
      }
    } catch (e) { /* zorunlu değil */ }
  };

  var sessionToken = null;

  if (!api) {
    showInvalid(MSG.generic);
    return;
  }
  if (link.error || link.errorCode) {
    showInvalid(LINK_ERRORS[link.errorCode] || LINK_ERRORS[link.error] || MSG.invalid);
    return;
  }
  if (link.accessToken && link.type === "recovery") {
    sessionToken = link.accessToken;
    prefillUsername(sessionToken);
    showForm();
  } else if (link.tokenHash && link.type === "recovery") {
    showForm();
  } else if (link.code) {
    showInvalid(MSG.oldLink);
    return;
  } else {
    showInvalid(MSG.invalid);
    return;
  }

  var LinkError = function (text) { this.text = text; };

  // token_hash akışında kurtarma oturumunu yalnızca ilk gönderimde açar;
  // sonraki denemeler (ör. zayıf şifre) aynı oturumu kullanır
  var ensureSession = function () {
    if (sessionToken) return Promise.resolve(sessionToken);
    return api.request("/auth/v1/verify", {
      body: { type: "recovery", token_hash: link.tokenHash }
    }).then(function (res) {
      if (res.ok && res.data && typeof res.data.access_token === "string" && res.data.access_token.trim()) {
        sessionToken = res.data.access_token;
        link.tokenHash = null;
        return sessionToken;
      }
      var code = api.errorCode(res.data);
      if (LINK_ERRORS[code]) throw new LinkError(LINK_ERRORS[code]);
      if (code === "weak_password") throw new Error(weakPasswordText(res.data));
      if (FORM_ERRORS[code] && code !== "validation_failed") throw new Error(FORM_ERRORS[code]);
      if (res.status === 429) throw new Error(MSG.rateLimit);
      if (res.status === 401 || res.status === 403) throw new LinkError(MSG.invalid);
      // Sunucu hatası veya eksik/bozuk yanıt token'ın süresinin dolduğunu
      // göstermez. Formu ve token'ı koru; kullanıcı yeniden deneyebilsin.
      throw new Error(MSG.generic);
    });
  };

  // Kurtarma oturumunu bu tarayıcıda kapat (scope=local: bu çağrı yalnızca bu
  // oturumu kapatır). Not: şifre değişikliğinin kendisi (PUT /user) GoTrue'da
  // hesabın DİĞER oturumlarını da kapatır; uygulama bunu giriş ekranında
  // "oturumun sona erdi" diye açıklar.
  var endSession = function (token) {
    api.request("/auth/v1/logout?scope=local", { token: token }).then(null, function () {});
  };

  form.addEventListener("submit", function (e) {
    e.preventDefault();
    errorEl.textContent = "";
    var p1 = pw1.value;
    var p2 = pw2.value;
    if (p1.length < 8) { errorEl.textContent = MSG.tooShort; pw1.focus(); return; }
    if (p1.length > 72) { errorEl.textContent = MSG.tooLong; pw1.focus(); return; }
    if (p1 !== p2) { errorEl.textContent = MSG.mismatch; pw2.focus(); return; }

    setBusy(true);
    ensureSession().then(function (token) {
      return api.request("/auth/v1/user", {
        method: "PUT",
        token: token,
        body: { password: p1 }
      }).then(function (res) {
        if (res.ok) {
          endSession(token);
          showSuccess();
          return;
        }
        var code = api.errorCode(res.data);
        if (LINK_ERRORS[code] || res.status === 401 || res.status === 403) {
          throw new LinkError(LINK_ERRORS[code] || MSG.session);
        }
        if (code === "weak_password") throw new Error(weakPasswordText(res.data));
        throw new Error(FORM_ERRORS[code] || MSG.generic);
      });
    }).then(function () {
      setBusy(false);
    }, function (err) {
      setBusy(false);
      if (err instanceof LinkError) {
        showInvalid(err.text);
      } else if (err && err.name === "AbortError") {
        errorEl.textContent = MSG.network;
      } else if (err instanceof TypeError) {
        errorEl.textContent = MSG.network;
      } else {
        errorEl.textContent = (err && err.message) || MSG.generic;
      }
    });
  });
})();
