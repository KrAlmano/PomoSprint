import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import fs from "node:fs";
import { test } from "node:test";

const directory = new URL("../../landing/videos/", import.meta.url);
const manifest = JSON.parse(fs.readFileSync(new URL("manifest-20261028.json", directory), "utf8"));
const hash = (bytes) => createHash("sha256").update(bytes).digest("hex");

test("yeni native video ve posterler doğrulanmış kayıt manifestiyle eşleşir", () => {
  assert.equal(manifest.schema_version, 1);
  assert.equal(manifest.speed_changed, false);
  assert.equal(manifest.editorial_overlay.includes("real native tap"), true);
  assert.match(manifest.raw_sha256, /^[a-f0-9]{64}$/);
  assert.match(manifest.event_log_sha256, /^[a-f0-9]{64}$/);
  assert.deepEqual(manifest.scenes.map((scene) => scene.scene), ["timer", "marathon"]);
  for (const scene of manifest.scenes) {
    assert.equal(scene.video, `${scene.scene}-demo-20261008d.mp4`);
    assert.equal(scene.poster, `${scene.scene}-demo-20261008d.webp`);
    const video = fs.readFileSync(new URL(scene.video, directory));
    const poster = fs.readFileSync(new URL(scene.poster, directory));
    assert.equal(hash(video), scene.video_sha256);
    assert.equal(hash(poster), scene.poster_sha256);
    assert.equal(video.length, scene.bytes);
    assert.ok(video.length < 262144);
    assert.equal(poster.toString("ascii", 0, 4), "RIFF");
    assert.equal(poster.toString("ascii", 8, 12), "WEBP");
    assert.equal(scene.width, 540);
    assert.equal(scene.height, 1170);
    assert.equal(scene.fps, 24);
    assert.equal(scene.codec, "h264");
    assert.equal(scene.pixel_format, "yuv420p");
    assert.equal(scene.audio, false);
    assert.ok(scene.duration_seconds > 10 && scene.duration_seconds < 30);
    assert.ok(scene.poster_at_seconds >= 0 && scene.poster_at_seconds < scene.duration_seconds);
    assert.ok(scene.taps.length >= 8);
    assert.ok(scene.taps.every((tap) => tap.seconds_in_scene >= 0 && tap.seconds_in_scene < scene.duration_seconds));
  }
});
