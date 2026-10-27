// pomosprint.app — statik sitenin önündeki küçük Worker.
//  * http -> https (301)
//  * www.pomosprint.app -> pomosprint.app (301, yol ve sorgu korunur)
//  * küçük sürümlü uygulama kayıtları için tek byte Range (Safari oynatma/ileri sarma)
// _headers kuralları ASSETS yanıtlarına uygulanır; Range yanıtında bu
// başlıkların tamamı korunur. Diğer varlıklar akış halinde aynen geçirilir.
const RANGE_VIDEOS = new Set([
  "/videos/timer-20261008.mp4",
  "/videos/marathon-20261008.mp4",
  "/videos/timer-demo-20261008d.mp4",
  "/videos/marathon-demo-20261008d.mp4",
]);
const MAX_RANGE_VIDEO_BYTES = 256 * 1024;

// Yalnız küçük, sürümlü kayıtlar okunur; bilinmeyen/büyük gövde tamponlanmaz.
async function readSmallVideo(body) {
  const reader = body.getReader();
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_RANGE_VIDEO_BYTES) {
        await reader.cancel();
        return null;
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes;
}

async function videoRange(request, response, env) {
  const match = /^bytes=(\d*)-(\d*)$/i.exec(request.headers.get("Range")?.trim() || "");
  // Bozuk/çoklu aralıklar 200 olarak kalır; multipart gövde üretilmez.
  if (!match || (!match[1] && !match[2])) return response;
  const first = match[1] ? Number(match[1]) : null;
  const last = match[2] ? Number(match[2]) : null;
  if ([first, last].some((n) => n !== null && !Number.isSafeInteger(n)) ||
      (first !== null && last !== null && last < first)) return response;
  const ifRange = request.headers.get("If-Range");
  // ASSETS güçlü ETag verir, Last-Modified vermez; tarih/zayıf ETag tam 200 olur.
  if (ifRange && (ifRange.startsWith("W/") || ifRange !== response.headers.get("ETag"))) return response;
  const bytes = await readSmallVideo(response.body);
  if (bytes === null) return env.ASSETS.fetch(request); // büyürse normal akışa dön
  const size = bytes.byteLength;
  const start = first === null ? Math.max(0, size - last) : first;
  const end = first === null || last === null ? size - 1 : Math.min(last, size - 1);
  const headers = new Headers(response.headers);
  headers.set("Accept-Ranges", "bytes");
  if (start >= size || end < start) {
    headers.set("Content-Range", `bytes */${size}`);
    headers.set("Content-Length", "0");
    return new Response(null, { status: 416, headers });
  }
  const part = bytes.slice(start, end + 1);
  headers.set("Content-Range", `bytes ${start}-${end}/${size}`);
  headers.set("Content-Length", String(part.byteLength));
  // TypedArray gövdesi Workers çalışma zamanında doğru Content-Length üretir.
  return new Response(part, { status: 206, headers });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const isSiteHost = url.hostname === "pomosprint.app" || url.hostname === "www.pomosprint.app";
    if (isSiteHost && (url.protocol === "http:" || url.hostname === "www.pomosprint.app")) {
      url.protocol = "https:";
      url.hostname = "pomosprint.app";
      return Response.redirect(url.toString(), 301);
    }
    const response = await env.ASSETS.fetch(request);
    if (request.method === "GET" && RANGE_VIDEOS.has(url.pathname) &&
        request.headers.has("Range") && response.status === 200 && response.body &&
        response.headers.get("Content-Type")?.split(";")[0].trim().toLowerCase() === "video/mp4" &&
        !response.headers.has("Content-Encoding")) {
      return videoRange(request, response, env);
    }
    return response;
  },
};
