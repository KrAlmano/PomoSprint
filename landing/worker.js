// pomosprint.app — statik sitenin önündeki küçük Worker.
//  * http -> https (301)
//  * www.pomosprint.app -> pomosprint.app (301, yol ve sorgu korunur)
// Diğer her istek statik varlıklara gider; _headers kuralları yalnızca
// env.ASSETS.fetch() yanıtlarına uygulanır (Worker'ın ürettiği yönlendirme
// yanıtlarına değil).
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const isSiteHost = url.hostname === "pomosprint.app" || url.hostname === "www.pomosprint.app";
    if (isSiteHost && (url.protocol === "http:" || url.hostname === "www.pomosprint.app")) {
      url.protocol = "https:";
      url.hostname = "pomosprint.app";
      return Response.redirect(url.toString(), 301);
    }
    return env.ASSETS.fetch(request);
  },
};
