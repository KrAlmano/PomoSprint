/* Şifre sıfırlama sayfası.
   Desteklenen bağlantı biçimleri:
   1) Implicit akış (uygulamanın kullandığı): #access_token=...&type=recovery
   2) E-posta şablonu token_hash ile: ?token_hash=...&type=recovery
      Token yalnızca form gönderilince doğrulanır; böylece bağlantıyı önceden
      açan e-posta tarayıcıları tek kullanımlık token'ı tüketemez.
   3) ?code=... : eski (PKCE) sürümden gelen bağlantı; tarayıcıda takas edilemez.
   Hata durumunda URL'deki error_description gösterilmez, yalnızca error_code
   sabit metinlere eşlenir (resmi alan adında keyfi metin basılamasın). */
(function () {
  "use strict";

  var api = window.PomoSupabase;

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
  var submitLabel = submitBtn.textContent;

  var NEW_LINK = " Uygulamada “Şifremi unuttum” ile yeni bir bağlantı isteyebilirsin.";
  var MSG = {
    invalid: "Bu şifre sıfırlama bağlantısı geçersiz." + NEW_LINK,
    expired: "Bu bağlantının süresi dolmuş ya da bağlantı daha önce kullanılmış." + NEW_LINK,
    session: "Şifre sıfırlama oturumunun süresi dolmuş." + NEW_LINK,
    oldLink: "Bu bağlantı uygulamanın eski bir sürümünden geliyor ve tarayıcıda açılamıyor. Uygulamayı güncelleyip “Şifremi unuttum” ile yeni bir bağlantı iste.",
    samePassword: "Yeni şifren eski şifrenle aynı olamaz. Farklı bir şifre seç.",
    weakPassword: "Bu şifre çok zayıf. Daha uzun ve tahmin edilmesi zor bir şifre seç.",
    rateLimit: "Kısa sürede çok fazla deneme yapıldı. Birkaç dakika bekleyip tekrar dene.",
    tooShort: "Şifre en az 6 karakter olmalı.",
    tooLong: "Şifre en fazla 72 karakter olabilir.",
    mismatch: "Girdiğin şifreler eşleşmiyor.",
    network: "Bağlantı hatası. İnternet bağlantını kontrol edip tekrar dene.",
    generic: "Şifre güncellenemedi, lütfen tekrar dene."
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
    icon.textContent = "⚠️";
    title.textContent = "Bağlantı Geçersiz";
    message.textContent = text;
    form.hidden = true;
  };

  var showForm = function () {
    message.textContent = "Hesabın için yeni bir şifre gir.";
    form.hidden = false;
    pw1.focus();
  };

  var showSuccess = function () {
    icon.textContent = "✅";
    title.textContent = "Şifren Güncellendi!";
    message.textContent = "Şimdi PomoSprint uygulamasına dön ve yeni şifrenle giriş yap.";
    form.hidden = true;
  };

  var setBusy = function (busy) {
    submitBtn.disabled = busy;
    submitBtn.textContent = busy ? "Güncelleniyor…" : submitLabel;
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
      if (res.ok && res.data && res.data.access_token) {
        sessionToken = res.data.access_token;
        link.tokenHash = null;
        return sessionToken;
      }
      var code = api.errorCode(res.data);
      if (FORM_ERRORS[code] && code !== "validation_failed") throw new Error(FORM_ERRORS[code]);
      throw new LinkError(LINK_ERRORS[code] || MSG.expired);
    });
  };

  // Kurtarma oturumunu yalnızca bu tarayıcıda kapat (diğer cihazlar etkilenmez)
  var endSession = function (token) {
    api.request("/auth/v1/logout?scope=local", { token: token }).then(null, function () {});
  };

  form.addEventListener("submit", function (e) {
    e.preventDefault();
    errorEl.textContent = "";
    var p1 = pw1.value;
    var p2 = pw2.value;
    if (p1.length < 6) { errorEl.textContent = MSG.tooShort; pw1.focus(); return; }
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
