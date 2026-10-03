/* Bülten ve lansman e-postalarından çıkma sayfası.
   Sayfa açılınca otomatik işlem YAPILMAZ: e-posta güvenlik tarayıcıları
   bağlantıyı açıp JS çalıştırabildiği için çıkış yalnızca butona basınca olur.
   Önce POST denenir; uç nokta POST desteklemiyorsa (405 ya da CORS reddi)
   eski GET çağrısına düşülür. Kullanıcıdan gelen metin yalnızca textContent ile basılır. */
(function () {
  "use strict";

  var api = window.PomoSupabase;
  var params = new URLSearchParams(window.location.search);
  var email = (params.get("email") || "").trim();
  var token = (params.get("token") || "").trim();

  var icon = document.getElementById("icon");
  var title = document.getElementById("title");
  var message = document.getElementById("message");
  var confirmBtn = document.getElementById("confirm");
  var errorEl = document.getElementById("error");
  var confirmLabel = confirmBtn.textContent;

  // "<e-posta> metin" biçiminde mesaj; e-posta kalın ve güvenli basılır
  var setMessageWithEmail = function (before, after) {
    message.textContent = "";
    if (before) message.appendChild(document.createTextNode(before));
    var b = document.createElement("span");
    b.className = "auth-email";
    b.textContent = email;
    message.appendChild(b);
    message.appendChild(document.createTextNode(after));
  };

  var showFinal = function (emoji, heading) {
    icon.textContent = emoji;
    title.textContent = heading;
    confirmBtn.hidden = true;
    errorEl.textContent = "";
  };

  if (!email || !api) {
    showFinal("⚠️", "Bağlantı Eksik");
    message.textContent = "Bu bağlantı eksik ya da bozuk görünüyor. E-postadaki “Abonelikten çık” bağlantısını yeniden açmayı dene.";
    return;
  }

  setMessageWithEmail("", " adresini PomoSprint e-posta listelerinden (bülten ve lansman duyurusu) çıkarmak istiyor musun?");
  confirmBtn.hidden = false;

  var path = "/functions/v1/unsubscribe?email=" + encodeURIComponent(email) +
    "&token=" + encodeURIComponent(token);

  var legacyGet = function () {
    return fetch(api.url + path, { method: "GET", credentials: "omit", cache: "no-store" })
      .then(function (res) { return { ok: res.ok, status: res.status }; });
  };

  var unsubscribe = function () {
    return api.request(path, { body: { email: email, token: token } })
      .then(function (res) {
        return res.status === 405 ? legacyGet() : res;
      }, function (err) {
        if (err && err.name === "AbortError") throw err;
        return legacyGet();
      });
  };

  confirmBtn.addEventListener("click", function () {
    confirmBtn.disabled = true;
    confirmBtn.textContent = "İşleniyor…";
    errorEl.textContent = "";

    unsubscribe().then(function (res) {
      if (res.ok) {
        showFinal("✅", "Abonelikten Çıkıldı");
        setMessageWithEmail("", " adresi e-posta listelerimizden çıkarıldı. Fikrini değiştirirsen bize her zaman yazabilirsin.");
        return;
      }
      if (res.status === 400 || res.status === 403) {
        showFinal("⚠️", "Bağlantı Geçersiz");
        message.textContent = "Bu abonelikten çıkma bağlantısı geçersiz. E-postadaki bağlantıyı yeniden açmayı dene ya da destek@pomosprint.app adresine yaz.";
        return;
      }
      confirmBtn.disabled = false;
      confirmBtn.textContent = confirmLabel;
      errorEl.textContent = "İşlem şu an gerçekleştirilemedi. Biraz sonra tekrar dener misin?";
    }, function () {
      confirmBtn.disabled = false;
      confirmBtn.textContent = confirmLabel;
      errorEl.textContent = "Bağlantı hatası. İnternet bağlantını kontrol edip tekrar dene.";
    });
  });
})();
