/* E-posta onayı dönüş sayfası.
   Supabase /verify sonucu:
     Implicit akış -> #access_token=...&type=signup
     PKCE (eski sürümler) -> ?code=...  (yönlendirme yalnızca onay başarılıysa olur)
     Hata -> #error=...&error_code=...  (ya da aynı alanlar query'de)
   Parametresiz açılışta "onaylandı" denmez. URL'deki token hemen silinir ve
   bu tarayıcıda açılan oturum kapatılır; giriş uygulamada yapılır. */
(function () {
  "use strict";

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

  var show = function (emoji, heading, text) {
    icon.textContent = emoji;
    title.textContent = heading;
    message.textContent = text;
    homeLink.hidden = true;
  };

  if (error || errorCode) {
    show("⚠️", "Onay Bağlantısı Geçersiz", errorCode === "otp_expired"
      ? "Bu onay bağlantısının süresi dolmuş ya da bağlantı daha önce kullanılmış. Uygulamada giriş yapmayı dene; e-postan henüz onaylanmadıysa yeni bir onay e-postası isteyebilirsin."
      : "Bu onay bağlantısı geçersiz. Uygulamada giriş yapmayı dene; e-postan henüz onaylanmadıysa yeni bir onay e-postası isteyebilirsin.");
    return;
  }

  if (accessToken || code) {
    show("✅", "E-postan Onaylandı!",
      "Harika, PomoSprint hesabın artık aktif. Uygulamaya dön ve e-posta adresin ile şifrenle giriş yap.");
    // Onay bağlantısının tarayıcıda açtığı oturuma ihtiyaç yok: yalnızca bu oturumu kapat
    if (accessToken && window.PomoSupabase) {
      window.PomoSupabase.request("/auth/v1/logout?scope=local", { token: accessToken })
        .then(null, function () {});
    }
  }
})();
