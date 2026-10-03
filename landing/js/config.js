/* PomoSprint landing — Supabase uç noktası ve küçük fetch yardımcısı.
   URL ve anon anahtar yalnızca burada durur. Anon anahtarın istemcide
   görünmesi normaldir; yetkiyi RLS ve RPC'ler sınırlar. supabase-js
   yüklenmez: sitenin ihtiyacı birkaç düz REST çağrısından ibaret. */
(function () {
  "use strict";

  var SUPABASE_URL = "https://eoosnyakvxmifmexpgxa.supabase.co";
  var SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVvb3NueWFrdnhtaWZtZXhwZ3hhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxODYxNTYsImV4cCI6MjEwMDc2MjE1Nn0.W1_L04jD_cP-HuvSAOc2sb0ov5o5jsqpD6DyS7khd3Y";

  /* İstek atar, yanıtı { ok, status, data } olarak döndürür.
     Ağ hatası ve zaman aşımında Promise reddedilir.
     opts: method (POST), body, token (Authorization için; yoksa anon),
           prefer (PostgREST Prefer başlığı), timeout (ms) */
  function request(path, opts) {
    opts = opts || {};
    var headers = {
      apikey: SUPABASE_ANON_KEY,
      Authorization: "Bearer " + (opts.token || SUPABASE_ANON_KEY)
    };
    if (opts.body !== undefined) headers["Content-Type"] = "application/json";
    if (opts.prefer) headers.Prefer = opts.prefer;

    var ctrl = typeof AbortController === "function" ? new AbortController() : null;
    var timer = ctrl ? setTimeout(function () { ctrl.abort(); }, opts.timeout || 12000) : null;

    return fetch(SUPABASE_URL + path, {
      method: opts.method || "POST",
      headers: headers,
      body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
      signal: ctrl ? ctrl.signal : undefined,
      credentials: "omit",
      cache: "no-store"
    }).then(function (res) {
      if (timer) clearTimeout(timer);
      return res.text().then(function (txt) {
        var data = null;
        if (txt) {
          try { data = JSON.parse(txt); } catch (e) { data = null; }
        }
        return { ok: res.ok, status: res.status, data: data };
      });
    }, function (err) {
      if (timer) clearTimeout(timer);
      throw err;
    });
  }

  /* GoTrue/PostgREST hata gövdesinden makine okunur kodu çıkarır.
     Eski API: { code: 422, error_code: "same_password" }
     Yeni API: { code: "same_password" } — PostgREST: { code: "23505" } */
  function errorCode(data) {
    if (!data || typeof data !== "object") return "";
    if (typeof data.error_code === "string") return data.error_code;
    if (typeof data.code === "string") return data.code;
    if (typeof data.error === "string") return data.error;
    return "";
  }

  window.PomoSupabase = {
    url: SUPABASE_URL,
    request: request,
    errorCode: errorCode
  };
})();
