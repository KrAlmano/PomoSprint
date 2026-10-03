/* Bülten ve lansman e-postalarından çıkma sayfası.
   Bağlantı: ?token=<uuid> (yeni e-postalar; adres URL'de taşınmaz) ya da
   eski e-postalardaki ?email=..&token=.. Eski biçimde e-posta okunur, sonra
   adres çubuğundan ve tarayıcı geçmişinden kaldırılır; istekte URL'ye değil
   POST gövdesine konur (sunucu token'ın sahibiyle eşleştirir, uyuşmazsa 403).
   Sayfa açılınca otomatik işlem YAPILMAZ: e-posta güvenlik tarayıcıları
   bağlantıyı açıp JS çalıştırabildiği için çıkış yalnızca butona basınca olur.
   Uç nokta yalnızca POST kabul eder (canlı unsubscribe v9, 3 Ekim'de okundu).
   Kullanıcıdan gelen metin yalnızca textContent ile basılır.
   Metinler Türkçe ve İngilizce; dil auth-i18n.js ile seçilir. */
(function () {
  "use strict";

  var TEXT = {
    tr: {
      _title: "Abonelikten Çık — PomoSprint",
      home: "PomoSprint ana sayfa",
      title: "Abonelikten Çık",
      checking: "Bağlantı kontrol ediliyor…",
      confirm: "Abonelikten çık",
      foot: "Sorun mu yaşıyorsun?",
      busy: "İşleniyor…",
      missingTitle: "Bağlantı Eksik",
      missing: "Bu bağlantı eksik ya da bozuk görünüyor. E-\u2060postadaki “Abonelikten çık” bağlantısını yeniden açmayı dene.",
      askBefore: "",
      askAfter: " adresini PomoSprint e-\u2060posta listelerinden (bülten ve lansman duyurusu) çıkarmak istiyor musun?",
      askNoEmail: "Bu bağlantıya ait e-\u2060posta adresini PomoSprint e-\u2060posta listelerinden (bülten ve lansman duyurusu) çıkarmak istiyor musun?",
      doneTitle: "Abonelikten Çıkıldı",
      doneBefore: "",
      doneAfter: " adresi e-\u2060posta listelerimizden çıkarıldı. Fikrini değiştirirsen bize her zaman yazabilirsin.",
      doneNoEmail: "Bu bağlantıya ait e-\u2060posta adresi listelerimizden çıkarıldı. Fikrini değiştirirsen bize her zaman yazabilirsin.",
      invalidTitle: "Bağlantı Geçersiz",
      invalid: "Bu abonelikten çıkma bağlantısı geçersiz. E-\u2060postadaki bağlantıyı yeniden açmayı dene ya da destek@pomosprint.app adresine yaz.",
      failed: "İşlem şu an gerçekleştirilemedi. Biraz sonra tekrar dener misin?",
      network: "Bağlantı hatası. İnternet bağlantını kontrol edip tekrar dene."
    },
    en: {
      _title: "Unsubscribe — PomoSprint",
      home: "PomoSprint home page",
      title: "Unsubscribe",
      checking: "Checking the link…",
      confirm: "Unsubscribe",
      foot: "Having trouble?",
      busy: "Processing…",
      missingTitle: "Incomplete Link",
      missing: "This link looks incomplete or broken. Try opening the “Unsubscribe” link in the email again.",
      askBefore: "Do you want to remove ",
      askAfter: " from PomoSprint email lists (newsletter and launch announcement)?",
      askNoEmail: "Do you want to remove the email address this link belongs to from PomoSprint email lists (newsletter and launch announcement)?",
      doneTitle: "You're Unsubscribed",
      doneBefore: "",
      doneAfter: " has been removed from our email lists. If you change your mind, you can always write to us.",
      doneNoEmail: "The email address this link belongs to has been removed from our email lists. If you change your mind, you can always write to us.",
      invalidTitle: "Invalid Link",
      invalid: "This unsubscribe link is invalid. Try opening the link in the email again or write to destek@pomosprint.app.",
      failed: "We couldn't complete this right now. Could you try again a bit later?",
      network: "Connection error. Check your internet connection and try again."
    }
  };
  var T = window.PomoI18n ? window.PomoI18n.use(TEXT) : TEXT.tr;

  var api = window.PomoSupabase;
  var params = new URLSearchParams(window.location.search);
  var email = (params.get("email") || "").trim();
  var token = (params.get("token") || "").trim();

  // Eski bağlantıdaki e-posta adres çubuğunda ve geçmişte kalmasın
  if (params.has("email") && window.history && typeof window.history.replaceState === "function") {
    params.delete("email");
    var rest = params.toString();
    try {
      window.history.replaceState(null, "", window.location.pathname + (rest ? "?" + rest : "") + window.location.hash);
    } catch (e) { /* adres değişmezse de sayfa çalışır */ }
  }

  var icon = document.getElementById("icon");
  var title = document.getElementById("title");
  var message = document.getElementById("message");
  var confirmBtn = document.getElementById("confirm");
  var errorEl = document.getElementById("error");
  var confirmLabel = T.confirm;

  // "<e-posta> metin" biçiminde mesaj; e-posta kalın ve güvenli basılır.
  // Yeni (yalnızca token'lı) bağlantıda adres bilinmez: genel metin.
  var setMessageWithEmail = function (before, after, noEmail) {
    if (!email) {
      message.textContent = noEmail;
      return;
    }
    message.textContent = "";
    if (before) message.appendChild(document.createTextNode(before));
    var b = document.createElement("span");
    b.className = "auth-email";
    b.textContent = email;
    message.appendChild(b);
    message.appendChild(document.createTextNode(after));
  };

  var showFinal = function (state, heading) {
    icon.setAttribute("data-icon", state);
    title.textContent = heading;
    confirmBtn.hidden = true;
    errorEl.textContent = "";
  };

  if (!token || !api) {
    showFinal("warn", T.missingTitle);
    message.textContent = T.missing;
    return;
  }

  setMessageWithEmail(T.askBefore, T.askAfter, T.askNoEmail);
  confirmBtn.hidden = false;

  // Adres URL'ye (dolayısıyla sunucu istek günlüğüne) yazılmaz; eski
  // bağlantıdan geldiyse yalnızca gövdede, eşleşme kontrolü için gider.
  var path = "/functions/v1/unsubscribe?token=" + encodeURIComponent(token);
  var body = email ? { token: token, email: email } : { token: token };

  var unsubscribe = function () {
    return api.request(path, { body: body });
  };

  confirmBtn.addEventListener("click", function () {
    confirmBtn.disabled = true;
    confirmBtn.textContent = T.busy;
    errorEl.textContent = "";

    unsubscribe().then(function (res) {
      if (res.ok) {
        showFinal("ok", T.doneTitle);
        setMessageWithEmail(T.doneBefore, T.doneAfter, T.doneNoEmail);
        return;
      }
      if (res.status === 400 || res.status === 403) {
        showFinal("warn", T.invalidTitle);
        message.textContent = T.invalid;
        return;
      }
      confirmBtn.disabled = false;
      confirmBtn.textContent = confirmLabel;
      errorEl.textContent = T.failed;
    }, function () {
      confirmBtn.disabled = false;
      confirmBtn.textContent = confirmLabel;
      errorEl.textContent = T.network;
    });
  });
})();
