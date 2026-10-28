// B media contract. Missing assets fail closed until the native capture is complete.
// No network, browser, subprocess, env/secrets or fixture mutation. Reads files.
// Binary checks are deliberately independent of manifest width/height claims.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const REPO = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const LANDING = path.join(REPO, 'landing');
const DATE = '20261028';
const LANGS = ['tr', 'en'];
const SCENES = ['timer', 'marathon-plan', 'exam-catalog', 'exam-running',
  'exam-history', 'exam-results', 'exam-insights', 'reports-daily',
  'reports-weekly', 'reports-monthly', 'league-category', 'league-global',
  'league-exam', 'social', 'avatar-collection'];
const VIDEO_SCENES = ['timer', 'marathon'];
const DIMENSIONS = { width: 540, height: 1170 };
const SCREEN_FILES = SCENES.flatMap(scene => LANGS.map(lang => `${scene}-${lang}.png`));
const VIDEO_FILES = VIDEO_SCENES.flatMap(scene => LANGS.flatMap(lang => [`${scene}-${lang}.mp4`, `${scene}-${lang}.webp`]));
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const read = file => fs.readFileSync(path.join(LANDING, file));
const text = file => read(file).toString('utf8');
const sorted = values => [...values].sort();
const withoutComments = source => source.replace(/<!--[\s\S]*?-->/g, '');

function walk(root, relative = '') {
  const result = [];
  for (const item of fs.readdirSync(path.join(root, relative), { withFileTypes: true })) {
    if (item.name === 'node_modules' || item.name.startsWith('.')) continue;
    const next = path.posix.join(relative, item.name);
    if (item.isDirectory()) result.push(...walk(root, next));
    else if (item.isFile()) result.push(next);
    else assert.fail(`Unsupported symlink/non-file in published assets: ${next}`);
  }
  return result;
}

function pngDimensions(bytes) {
  assert.ok(bytes.length >= 45, 'PNG has complete chunks');
  assert.deepEqual(bytes.subarray(0, 8), Buffer.from([137,80,78,71,13,10,26,10]));
  let cursor = 8;
  let dimensions;
  let imageData = false;
  let ended = false;
  while (cursor + 12 <= bytes.length) {
    const length = bytes.readUInt32BE(cursor);
    const type = bytes.toString('ascii', cursor + 4, cursor + 8);
    assert.ok(cursor + 12 + length <= bytes.length, 'PNG chunk bounds');
    if (!dimensions) {
      assert.equal(type, 'IHDR');
      assert.equal(length, 13);
      dimensions = { width: bytes.readUInt32BE(cursor + 8), height: bytes.readUInt32BE(cursor + 12) };
    }
    if (type === 'IDAT') imageData = true;
    cursor += 12 + length;
    if (type === 'IEND') { assert.equal(length, 0); ended = true; break; }
  }
  assert.ok(imageData && ended, 'PNG has IDAT and IEND');
  assert.equal(cursor, bytes.length, 'PNG has no trailing payload');
  return dimensions;
}

function webpDimensions(bytes) {
  assert.equal(bytes.toString('ascii', 0, 4), 'RIFF');
  assert.equal(bytes.toString('ascii', 8, 12), 'WEBP');
  assert.equal(bytes.readUInt32LE(4) + 8, bytes.length, 'WebP RIFF size');
  let cursor = 12;
  let dimensions;
  while (cursor + 8 <= bytes.length) {
    const type = bytes.toString('ascii', cursor, cursor + 4);
    const length = bytes.readUInt32LE(cursor + 4);
    const start = cursor + 8;
    assert.ok(start + length <= bytes.length, 'WebP chunk bounds');
    assert.notEqual(type, 'ANIM', 'Posters must be static');
    if (type === 'VP8X') {
      assert.ok(length >= 10);
      dimensions = { width: bytes.readUIntLE(start + 4, 3) + 1, height: bytes.readUIntLE(start + 7, 3) + 1 };
    } else if (type === 'VP8L' && !dimensions) {
      assert.ok(length >= 5); assert.equal(bytes[start], 0x2f);
      const bits = bytes.readUInt32LE(start + 1);
      dimensions = { width: (bits & 0x3fff) + 1, height: ((bits >>> 14) & 0x3fff) + 1 };
    } else if (type === 'VP8 ' && !dimensions) {
      assert.ok(length >= 10);
      assert.deepEqual(bytes.subarray(start + 3, start + 6), Buffer.from([0x9d,0x01,0x2a]));
      dimensions = { width: bytes.readUInt16LE(start + 6) & 0x3fff, height: bytes.readUInt16LE(start + 8) & 0x3fff };
    }
    cursor = start + length + (length % 2);
  }
  assert.equal(cursor, bytes.length);
  assert.ok(dimensions, 'WebP image dimensions present');
  return dimensions;
}

function boxes(bytes, start = 0, end = bytes.length) {
  const result = [];
  let cursor = start;
  while (cursor < end) {
    assert.ok(cursor + 8 <= end, 'MP4 box header bounds');
    let length = bytes.readUInt32BE(cursor);
    const type = bytes.toString('ascii', cursor + 4, cursor + 8);
    let header = 8;
    if (length === 1) {
      assert.ok(cursor + 16 <= end);
      const large = bytes.readBigUInt64BE(cursor + 8);
      assert.ok(large <= BigInt(Number.MAX_SAFE_INTEGER));
      length = Number(large); header = 16;
    } else if (length === 0) length = end - cursor;
    assert.ok(length >= header && cursor + length <= end, `MP4 ${type} bounds`);
    result.push({ type, start: cursor, data: cursor + header, end: cursor + length });
    cursor += length;
  }
  return result;
}

function mp4Properties(bytes) {
  const top = boxes(bytes);
  assert.ok(top.some(box => box.type === 'ftyp'));
  assert.ok(top.some(box => box.type === 'mdat'));
  const movie = top.find(box => box.type === 'moov'); assert.ok(movie);
  const children = box => boxes(bytes, box.data, box.end);
  const movieChildren = children(movie);
  const header = movieChildren.find(box => box.type === 'mvhd'); assert.ok(header);
  const version = bytes[header.data]; assert.ok(version === 0 || version === 1);
  const scale = bytes.readUInt32BE(header.data + (version === 1 ? 20 : 12));
  const duration = version === 1 ? Number(bytes.readBigUInt64BE(header.data + 24)) : bytes.readUInt32BE(header.data + 16);
  assert.ok(scale > 0 && Number.isSafeInteger(duration));
  const tracks = movieChildren.filter(box => box.type === 'trak').map(track => {
    const trackChildren = children(track);
    const tkhd = trackChildren.find(box => box.type === 'tkhd'); assert.ok(tkhd);
    const mdia = trackChildren.find(box => box.type === 'mdia'); assert.ok(mdia);
    const handler = children(mdia).find(box => box.type === 'hdlr'); assert.ok(handler);
    assert.ok(handler.data + 12 <= handler.end);
    return { kind: bytes.toString('ascii', handler.data + 8, handler.data + 12),
      width: bytes.readUInt32BE(tkhd.end - 8) / 65536,
      height: bytes.readUInt32BE(tkhd.end - 4) / 65536 };
  });
  const video = tracks.filter(track => track.kind === 'vide');
  assert.equal(video.length, 1, 'Exactly one video track');
  assert.equal(tracks.some(track => track.kind === 'soun'), false, 'Silent file, no audio track');
  return { width: video[0].width, height: video[0].height, durationSeconds: duration / scale };
}

function tags(source) {
  return [...withoutComments(source).matchAll(/<([a-z][\w-]*)\b([^<>]*)>/gi)].map(match => ({
    name: match[1].toLowerCase(), attrs: Object.fromEntries([...match[2].matchAll(/([\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/g)]
      .map(attr => [attr[1].toLowerCase(), (attr[2] ?? attr[3]).replaceAll('&amp;', '&')]))
  }));
}

function mediaReferences(source) {
  const refs = [];
  for (const element of tags(source)) for (const attribute of ['src','poster','data-src','href']) {
    const value = element.attrs[attribute]; if (!value) continue;
    const url = new URL(value, 'https://pomosprint.app/');
    if (url.origin === 'https://pomosprint.app' && /^\/(screenshots|videos)\/.+\.(png|webp|mp4)$/.test(url.pathname)) {
      refs.push({ ...element, attribute, path: url.pathname.slice(1) });
    }
  }
  return refs;
}

const allHtml = () => walk(LANDING).filter(file => file.endsWith('.html') && !file.startsWith('_partials/'));
const expectedAssetPaths = () => [
  ...SCREEN_FILES.map(file => `screenshots/${DATE}/${file}`),
  ...VIDEO_FILES.map(file => `videos/${DATE}/${file}`),
];

function safeSource(relative) {
  assert.match(relative, /^analiz\/[a-zA-Z0-9_./-]+\.(png|mp4)$/);
  assert.equal(relative.includes('..'), false);
  const resolved = path.resolve(REPO, relative);
  assert.ok(resolved.startsWith(path.join(REPO, 'analiz') + path.sep));
  assert.ok(fs.existsSync(resolved), `Raw native proof missing: ${relative}`);
  assert.ok(fs.realpathSync(resolved).startsWith(fs.realpathSync(path.join(REPO, 'analiz')) + path.sep), 'Raw source symlink escapes proof directory');
  return fs.readFileSync(resolved);
}

// Adapter contract is proposed in the companion JSON schema planning file.
// This validates real source/output hashes, not only filenames/dimensions.
test('B screenshots: 30 same-size PNG files retain native provenance', () => {
  assert.deepEqual(sorted(walk(path.join(LANDING,'screenshots',DATE)).filter(file => file.endsWith('.png'))), sorted(SCREEN_FILES));
  const manifest = JSON.parse(text(`screenshots/manifest-${DATE}.json`));
  assert.equal(manifest.schema_version, 1);
  assert.equal(manifest.date, '2026-10-28');
  assert.equal(manifest.device.name, 'PomoSprint QA iPhone 16 (18.6)');
  assert.equal(manifest.device.ios, '18.6');
  assert.equal(manifest.status_bar.time, '09:41');
  assert.equal(manifest.status_bar.battery_level, 100);
  assert.equal(manifest.status_bar.wifi_bars, 3);
  assert.equal(manifest.status_bar.cellular_bars, 4);
  assert.equal(manifest.demo_owner.display_name, 'Deniz');
  assert.match(manifest.demo_owner.id, /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/);
  assert.equal(manifest.scenes.length, 30);
  const seen = new Set();
  let commonRawDimensions;
  for (const scene of manifest.scenes) {
    assert.ok(SCENES.includes(scene.scene)); assert.ok(LANGS.includes(scene.locale));
    const file = `${scene.scene}-${scene.locale}.png`;
    assert.equal(scene.file, `${DATE}/${file}`);
    assert.equal(seen.has(file), false); seen.add(file);
    const output = read(`screenshots/${scene.file}`);
    assert.deepEqual(pngDimensions(output), DIMENSIONS);
    assert.equal(hash(output), scene.sha256);
    assert.deepEqual({ width: scene.width, height: scene.height }, DIMENSIONS);
    const raw = safeSource(scene.source.path);
    const rawDimensions = pngDimensions(raw);
    assert.deepEqual(rawDimensions, { width: scene.source.width, height: scene.source.height });
    if (!commonRawDimensions) commonRawDimensions = rawDimensions;
    assert.deepEqual(rawDimensions, commonRawDimensions, 'One consistent native device/source resolution');
    assert.equal(scene.source.locale, scene.locale);
    assert.ok(rawDimensions.width >= 540 && rawDimensions.height >= 1170);
    assert.equal(hash(raw), scene.source.sha256);
    assert.equal(scene.owner_id, manifest.demo_owner.id);
    assert.equal(scene.status_bar_time, '09:41');
  }
  assert.deepEqual(sorted(seen), sorted(SCREEN_FILES));
});

test('B timer/Marathon: four silent MP4s and four static WebP posters share dimensions', () => {
  assert.deepEqual(sorted(walk(path.join(LANDING,'videos',DATE)).filter(file => /\.(mp4|webp)$/.test(file))), sorted(VIDEO_FILES));
  const manifest = JSON.parse(text(`videos/manifest-${DATE}.json`));
  assert.equal(manifest.schema_version, 1); assert.equal(manifest.speed_changed, false);
  const screens = JSON.parse(text(`screenshots/manifest-${DATE}.json`));
  assert.equal(manifest.demo_owner.id, screens.demo_owner.id, 'Videos and screenshots use the same observer');
  assert.equal(manifest.scenes.length, 4);
  const seen = new Set();
  for (const scene of manifest.scenes) {
    assert.ok(VIDEO_SCENES.includes(scene.scene)); assert.ok(LANGS.includes(scene.locale));
    const base = `${scene.scene}-${scene.locale}`;
    assert.equal(scene.video, `${DATE}/${base}.mp4`);
    assert.equal(scene.poster, `${DATE}/${base}.webp`);
    assert.equal(seen.has(base), false); seen.add(base);
    const video = read(`videos/${scene.video}`), poster = read(`videos/${scene.poster}`);
    const properties = mp4Properties(video);
    assert.deepEqual({ width: properties.width, height: properties.height }, DIMENSIONS);
    assert.deepEqual(webpDimensions(poster), DIMENSIONS);
    assert.ok(properties.durationSeconds > 1 && properties.durationSeconds <= 60, 'Short real-time clip');
    assert.ok(video.length <= 256 * 1024, 'Keep the existing bounded256KiB Worker Range contract');
    assert.equal(hash(video), scene.video_sha256); assert.equal(hash(poster), scene.poster_sha256);
    assert.equal(scene.bytes, video.length);
    assert.ok(Math.abs(scene.duration_seconds - properties.durationSeconds) <= 0.1);
    assert.equal(scene.speed_changed, false);
    const raw = safeSource(scene.source.path); assert.equal(hash(raw), scene.source.sha256);
    assert.equal(scene.source.locale, scene.locale);
    const rawProperties = mp4Properties(raw);
    assert.deepEqual({ width: rawProperties.width, height: rawProperties.height },
      { width: scene.source.width, height: scene.source.height });
    assert.equal(scene.owner_id, manifest.demo_owner.id);
    assert.equal(scene.status_bar_time, '09:41');
  }
  assert.deepEqual(sorted(seen), sorted(VIDEO_SCENES.flatMap(scene => LANGS.map(lang => `${scene}-${lang}`))));
});

test('B published assets: no missing, stale or unused app screenshot/video files', () => {
  const expected = expectedAssetPaths();
  const actual = ['screenshots','videos'].flatMap(folder => walk(path.join(LANDING,folder))
    .filter(file => /\.(png|webp|mp4)$/.test(file)).map(file => `${folder}/${file}`));
  assert.deepEqual(sorted(actual), sorted(expected), 'Remove replaced/unused old app media; preserve raw proof under analiz');
  const used = new Set();
  for (const file of allHtml()) for (const ref of mediaReferences(text(file))) {
    assert.ok(expected.includes(ref.path), `${file}: stale or unexpected ${ref.attribute}=${ref.path}`);
    assert.ok(fs.existsSync(path.join(LANDING,ref.path)), `${file}: missing media ${ref.path}`);
    used.add(ref.path);
  }
  assert.deepEqual(sorted(used), sorted(expected), 'Every published native media file is used');
});

for (const locale of LANGS) {
  const prefix = locale === 'tr' ? '' : 'en/';
  test(`B ${locale}: native media locale and declared dimensions match page`, () => {
    for (const file of allHtml().filter(file => file.startsWith('en/') === (locale === 'en'))) {
      const html = text(file);
      for (const ref of mediaReferences(html)) {
        assert.match(ref.path, new RegExp(`-${locale}\\.(png|webp|mp4)$`), `${file}: cross-language asset`);
        if (ref.name === 'img') {
          assert.equal(ref.attrs.width, '540'); assert.equal(ref.attrs.height, '1170');
          assert.ok(ref.attrs.alt?.trim(), `${file}: meaningful localized alt text required`);
        }
      }
    }
    const features = text(`${prefix}features.html`);
    const screenshots = new Set(mediaReferences(features).filter(ref => ref.path.endsWith('.png')).map(ref => path.basename(ref.path)));
    assert.deepEqual(sorted(screenshots), sorted(SCENES.map(scene => `${scene}-${locale}.png`)));
    for (const page of ['index.html','features.html']) {
      const html = text(prefix + page);
      for (const match of html.matchAll(/<video\b([^>]*)>([\s\S]*?)<\/video>/g)) {
        const attrs = match[1];
        for (const attr of ['autoplay','muted','loop','playsinline']) assert.match(attrs,new RegExp(`\\b${attr}\\b`));
        assert.doesNotMatch(attrs,/\bcontrols\b/); assert.match(attrs,/role="button"/);
        assert.match(attrs,/tabindex="0"/); assert.match(attrs,/preload="none"/);
        assert.match(attrs,/aria-describedby="[^"]+"/);
        assert.match(match[2],new RegExp(`href="/screenshots/${DATE}/[a-z-]+-${locale}\\.png"`));
      }
    }
  });
}

test('B TR/EN home/features/FAQ have equal sections and corresponding feature topics', () => {
  for (const page of ['index.html','features.html','faq.html']) {
    const tr = withoutComments(text(page)), en = withoutComments(text(`en/${page}`));
    const count = source => [...source.matchAll(/<section\b/gi)].length;
    assert.equal(count(tr),count(en),page);
    assert.equal([...tr.matchAll(/<h1\b/gi)].length,1); assert.equal([...en.matchAll(/<h1\b/gi)].length,1);
  }
  const pairs = [['zamanlayici','timer'],['maraton','marathon'],['deneme','practice'],['denemelerim','my-exams'],
    ['icgoruler','insights'],['raporlar','reports'],['haftalik-aylik','weekly-monthly'],
    ['ligler','leagues'],['deneme-ligi','exam-league'],['arkadaslar','friends']];
  for (const [tr,en] of pairs) {
    assert.equal([...text('features.html').matchAll(new RegExp(`data-feature="${tr}"`,'g'))].length,1);
    assert.equal([...text('en/features.html').matchAll(new RegExp(`data-feature="${en}"`,'g'))].length,1);
  }
});


test('B video URLs remain inside the bounded Worker Range allowlist and common frame', () => {
  const worker = text('worker.js');
  const allowlist = worker.match(/const RANGE_VIDEOS = new Set\(\[([\s\S]*?)\]\)/)?.[1];
  assert.ok(allowlist);
  for (const scene of VIDEO_SCENES) for (const lang of LANGS) {
    assert.ok(allowlist.includes(`/videos/${DATE}/${scene}-${lang}.mp4`));
  }
  assert.match(worker, /MAX_RANGE_VIDEO_BYTES\s*=\s*256\s*\*\s*1024/);
  const screen = text('css/style.css').match(/\.phone-screen\s*\{([^}]+)\}/)?.[1];
  assert.ok(screen); assert.match(screen, /aspect-ratio:\s*540\s*\/\s*1170/);
  assert.match(screen, /height:\s*auto/);
});
