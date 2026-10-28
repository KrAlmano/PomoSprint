import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const directory = path.join(repo, "landing/videos");
const hash = (bytes) => createHash("sha256").update(bytes).digest("hex");

function nativeEvidence(relative, extensions) {
  assert.equal(typeof relative, "string");
  assert.match(relative, /^analiz\/[A-Za-z0-9_./-]+$/);
  assert.equal(relative.includes(".."), false);
  assert.ok(extensions.includes(path.extname(relative)));
  const file = path.resolve(repo, relative);
  assert.ok(fs.realpathSync(file).startsWith(fs.realpathSync(path.join(repo, "analiz")) + path.sep));
  return fs.readFileSync(file);
}

test("dört native video ve poster gerçek kayıt, dokunuş ve kodlama kanıtlarıyla eşleşir", () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(directory, "manifest-20261028.json"), "utf8"));
  assert.equal(manifest.schema_version, 1);
  assert.equal(manifest.speed_changed, false);
  assert.match(manifest.editorial_overlay, /real native tap/);
  assert.deepEqual(manifest.scenes.map(scene => `${scene.scene}-${scene.locale}`).sort(),
    ["marathon-en", "marathon-tr", "timer-en", "timer-tr"]);
  for (const scene of manifest.scenes) {
    assert.equal(scene.video, `20261028/${scene.scene}-${scene.locale}.mp4`);
    assert.equal(scene.poster, `20261028/${scene.scene}-${scene.locale}.webp`);
    const video = fs.readFileSync(path.join(directory, scene.video));
    const poster = fs.readFileSync(path.join(directory, scene.poster));
    assert.equal(hash(video), scene.video_sha256);
    assert.equal(hash(poster), scene.poster_sha256);
    assert.equal(video.length, scene.bytes);
    assert.ok(video.length <= 262144);
    assert.equal(poster.toString("ascii", 0, 4), "RIFF");
    assert.equal(poster.toString("ascii", 8, 12), "WEBP");
    assert.equal(scene.width, 540);
    assert.equal(scene.height, 1170);
    assert.equal(scene.fps, 24);
    assert.equal(scene.codec, "h264");
    assert.equal(scene.pixel_format, "yuv420p");
    assert.equal(scene.audio, false);
    assert.equal(scene.speed_changed, false);
    assert.ok(scene.duration_seconds > 1 && scene.duration_seconds <= 60);
    assert.ok(scene.poster_at_seconds >= 0 && scene.poster_at_seconds < scene.duration_seconds);
    assert.equal(hash(nativeEvidence(scene.source.path, [".mp4"])), scene.source.sha256);
    const eventLog = nativeEvidence(scene.event_log.path, [".log", ".jsonl", ".txt"]);
    assert.equal(hash(eventLog), scene.event_log.sha256);
    assert.ok(eventLog.length > 0);
    assert.ok(Array.isArray(scene.taps) && scene.taps.length > 0);
    for (const tap of scene.taps) {
      assert.ok(Number.isFinite(tap.seconds_in_scene));
      assert.ok(tap.seconds_in_scene >= 0 && tap.seconds_in_scene < scene.duration_seconds);
      assert.ok(Number.isFinite(tap.video_x) && Number.isFinite(tap.video_y));
      assert.ok(tap.video_x >= 0 && tap.video_x <= 540 && tap.video_y >= 0 && tap.video_y <= 1170);
    }
  }
});
