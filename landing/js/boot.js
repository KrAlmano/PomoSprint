/* İlk boyamadan önce çalışır: hareket tercihi izin veriyorsa hero öğeleri
   görünmez başlar, main.js giriş animasyonunu kurunca sınıfı kaldırır.
   Sayfa başlığı (h1, LCP öğesi) hiç gizlenmez. GSAP veya main.js
   yüklenemezse 1,5 sn sonra içerik yine de görünür. */
(function () {
  var root = document.documentElement;
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduce) return;
  root.classList.add("js-anim");
  setTimeout(function () { root.classList.remove("js-anim"); }, 1500);
})();
