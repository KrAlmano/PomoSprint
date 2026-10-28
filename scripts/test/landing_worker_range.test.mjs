// Gerçek MP4 dosyaları + Range'ı yok sayan ASSETS: Safari byte probe/seek regresyonu.
import assert from "node:assert/strict";
import fs from "node:fs";
import { test } from "node:test";
import worker from "../../landing/worker.js";

const paths = ["/videos/20261028/timer-tr.mp4", "/videos/20261028/timer-en.mp4", "/videos/20261028/marathon-tr.mp4", "/videos/20261028/marathon-en.mp4"];
const videos = new Map(paths.map((name) => [name, new Uint8Array(fs.readFileSync(new URL(`../../landing${name}`, import.meta.url)))]));
const assetHeaders = {
  "Content-Type": "video/mp4",
  "Cache-Control": "public, max-age=86400",
  "ETag": '"current-video"',
  "Content-Security-Policy": "default-src 'self'; media-src 'self'; object-src 'none'",
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Strict-Transport-Security": "max-age=31536000; includeSubDomains; preload",
  "Referrer-Policy": "strict-origin-when-cross-origin",
};

function assets({ status = 200, headers = assetHeaders, body } = {}) {
  const calls = [];
  return { calls, ASSETS: { async fetch(request) {
    calls.push(request);
    const bytes = body ?? videos.get(new URL(request.url).pathname) ?? new Uint8Array([9, 8, 7]);
    return new Response(request.method === "HEAD" || status === 304 ? null : bytes, { status, headers });
  } } };
}
function request(path = paths[0], headers = {}, method = "GET") {
  return new Request(`https://pomosprint.app${path}`, { method, headers });
}
async function checkRange(path, range, start, end) {
  const env = assets();
  const result = await worker.fetch(request(path, { Range: range }), env);
  const bytes = videos.get(new URL(`https://pomosprint.app${path}`).pathname);
  assert.equal(result.status, 206);
  assert.equal(result.headers.get("Accept-Ranges"), "bytes");
  assert.equal(result.headers.get("Content-Range"), `bytes ${start}-${end}/${bytes.byteLength}`);
  assert.equal(result.headers.get("Content-Length"), String(end - start + 1));
  assert.deepEqual(new Uint8Array(await result.arrayBuffer()), bytes.slice(start, end + 1));
  for (const [key, value] of Object.entries(assetHeaders)) assert.equal(result.headers.get(key), value, key);
  assert.equal(env.calls.length, 1);
  assert.equal(new URL(env.calls[0].url).search, new URL(`https://pomosprint.app${path}`).search);
}

for (const path of paths) {
  test(`${path}: Safari ilk iki byte sorgusu, ileri/geri sarma ve son byte aralıkları`, async () => {
    const size = videos.get(path).byteLength;
    await checkRange(path, "bytes=0-1", 0, 1);
    await checkRange(path, "bytes=65536-66559", 65536, 66559);
    await checkRange(path, "bytes=-1024", size - 1024, size - 1);
    await checkRange(path, `bytes=${size - 32}-`, size - 32, size - 1);
    await checkRange(path, `bytes=${size - 16}-${size + 1000}`, size - 16, size - 1);
  });
}

test("güncel native video cache sürümü Range yanıtını ve byte konumunu değiştirmez", async () => {
  for (const path of paths) {
    await checkRange(`${path}?v=20261028b`, "bytes=0-1", 0, 1);
    await checkRange(`${path}?v=20261028b`, "bytes=512-1023", 512, 1023);
  }
});

test("videolar 256 KiB Range sınırının altında; tam GET aynı byte'ları döndürür", async () => {
  for (const path of paths) {
    assert.ok(videos.get(path).byteLength < 256 * 1024);
    const result = await worker.fetch(request(path), assets());
    assert.equal(result.status, 200);
    assert.deepEqual(new Uint8Array(await result.arrayBuffer()), videos.get(path));
    assert.equal(result.headers.get("Content-Range"), null);
  }
});

test("dosya dışı ve sıfır uzunluklu suffix aralık 416 verir, güvenlik başlıkları kalır", async () => {
  for (const range of ["bytes=999999-", "bytes=-0"]) {
    const result = await worker.fetch(request(paths[0], { Range: range }), assets());
    assert.equal(result.status, 416);
    assert.equal(result.headers.get("Content-Range"), `bytes */${videos.get(paths[0]).byteLength}`);
    assert.equal((await result.arrayBuffer()).byteLength, 0);
    assert.equal(result.headers.get("X-Content-Type-Options"), "nosniff");
    assert.equal(result.headers.get("Content-Security-Policy"), assetHeaders["Content-Security-Policy"]);
  }
});

test("bozuk, çoklu, ters ve taşan Range tam 200 olarak kalır", async () => {
  for (const range of ["bytes=", "bytes=-", "items=0-1", "bytes=2-1", "bytes=0-1,10-11", "bytes=9007199254740992-"]) {
    const result = await worker.fetch(request(paths[0], { Range: range }), assets());
    assert.equal(result.status, 200, range);
    assert.deepEqual(new Uint8Array(await result.arrayBuffer()), videos.get(paths[0]), range);
  }
});

test("If-Range güçlü güncel ETag ile 206, değişmiş/zayıf/tarih doğrulayıcısıyla tam 200", async () => {
  for (const tag of ['"current-video"', '"old-video"', 'W/"current-video"', "Wed, 07 Oct 2026 12:00:00 GMT"]) {
    const result = await worker.fetch(request(paths[0], { Range: "bytes=0-1", "If-Range": tag }), assets());
    assert.equal(result.status, tag === '"current-video"' ? 206 : 200, tag);
    assert.equal((await result.arrayBuffer()).byteLength, tag === '"current-video"' ? 2 : videos.get(paths[0]).byteLength);
  }
});

test("HEAD, 304 ve 404 Range tarafından yeniden yazılmaz", async () => {
  const head = await worker.fetch(request(paths[0], { Range: "bytes=0-1" }, "HEAD"), assets());
  assert.equal(head.status, 200);
  assert.equal((await head.arrayBuffer()).byteLength, 0);
  for (const status of [304, 404]) {
    const result = await worker.fetch(request(paths[0], { Range: "bytes=0-1", "If-None-Match": '"current-video"' }), assets({ status }));
    assert.equal(result.status, status);
    assert.equal(result.headers.get("Content-Range"), null);
  }
});

test("yalnız izin verilen sürümlü MP4 yolları: yardımcı sayfa, private ve başka video yolları değişmez", async () => {
  for (const path of ["/reset-password", "/worker.js", "/videos/other.mp4"]) {
    const env = assets({ headers: { "Content-Type": "text/html", "Cache-Control": "no-store" } });
    const result = await worker.fetch(request(path, { Range: "bytes=0-1" }), env);
    assert.equal(result.status, 200);
    assert.equal(result.headers.get("Cache-Control"), "no-store");
    assert.equal(result.headers.get("Content-Range"), null);
    assert.deepEqual(new Uint8Array(await result.arrayBuffer()), new Uint8Array([9, 8, 7]));
  }
});

test("sıkıştırılmış ya da yanlış MIME olan temsil kesilmez", async () => {
  for (const headers of [{ ...assetHeaders, "Content-Encoding": "gzip" }, { ...assetHeaders, "Content-Type": "text/html" }]) {
    const result = await worker.fetch(request(paths[0], { Range: "bytes=0-1" }), assets({ headers }));
    assert.equal(result.status, 200);
    assert.deepEqual(new Uint8Array(await result.arrayBuffer()), videos.get(paths[0]));
  }
});

test("256 KiB üstünde okuma iptal edilir, dosya normal akışla yeniden alınır", async () => {
  let canceled = false;
  let calls = 0;
  const big = new Uint8Array(300 * 1024);
  const env = { ASSETS: { async fetch() {
    calls += 1;
    if (calls > 1) return new Response(big, { headers: assetHeaders });
    return new Response(new ReadableStream({
      start(controller) { controller.enqueue(big); },
      cancel() { canceled = true; },
    }), { headers: assetHeaders });
  } } };
  const result = await worker.fetch(request(paths[0], { Range: "bytes=0-1" }), env);
  assert.equal(canceled, true);
  assert.equal(calls, 2);
  assert.equal(result.status, 200);
  assert.equal((await result.arrayBuffer()).byteLength, big.byteLength);
});

test("www/HTTP yönlendirmeleri sorguyu korur; ASSETS'e çağrı yapılmaz", async () => {
  for (const url of ["http://pomosprint.app/features?lang=en&via=qa", "https://www.pomosprint.app/features?lang=en&via=qa"]) {
    const env = assets();
    const result = await worker.fetch(new Request(url), env);
    assert.equal(result.status, 301);
    assert.equal(result.headers.get("Location"), "https://pomosprint.app/features?lang=en&via=qa");
    assert.equal(env.calls.length, 0);
  }
});

test("eşzamanlı video aralıkları birbirinin byte/sayacını paylaşmaz", async () => {
  await Promise.all(paths.flatMap((path) => [checkRange(path, "bytes=0-1", 0, 1), checkRange(path, "bytes=100-199", 100, 199)]));
});
