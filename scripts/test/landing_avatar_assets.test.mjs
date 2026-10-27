import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { FakeElement, REPO, createPage, settle } from './helpers/fake_dom.mjs';

const source = fs.readFileSync(path.join(REPO, 'lib/models/avatar_model.dart'), 'utf8');
const catalog = source.split('static const List<AvatarCharacter> fallbackCatalog = [')[1].split('\n  ];')[0];
const ids = [...catalog.matchAll(/AvatarCharacter\(id: '([a-z0-9_]+)'/g)].map(match => match[1]);

test('every embedded active avatar has a nonempty WebP for the public ranking', () => {
  assert.equal(ids.length, 47);
  assert.equal(new Set(ids).size, 47);
  assert.ok(!ids.includes('special_ronin'));
  assert.ok(!ids.includes('tomato_basic'));
  for (const id of ids) {
    const file = path.join(REPO, 'landing/avatars', `${id}.webp`);
    assert.ok(fs.existsSync(file), `Missing public ranking avatar: ${id}`);
    const bytes = fs.readFileSync(file);
    assert.ok(bytes.length > 32, id);
    assert.equal(bytes.toString('ascii', 0, 4), 'RIFF', id);
    assert.equal(bytes.toString('ascii', 8, 12), 'WEBP', id);
    assert.equal(bytes.readUInt32LE(4) + 8, bytes.length, id);
  }
});

function ranking(avatars) {
  const elements = Object.fromEntries(['siralama', 'lb-list', 'lb-podium', 'lb-empty']
    .map(id => [id, new FakeElement(id)]));
  const podiumImages = [];
  for (let rank = 1; rank <= 3; rank++) {
    const image = new FakeElement('image');
    const children = {
      '.lb-podium-avatar': image,
      '.lb-podium-name': new FakeElement('name'),
      '.lb-podium-points': new FakeElement('points'),
    };
    const slot = new FakeElement(`lb-podium-${rank}`);
    slot.querySelector = selector => children[selector];
    elements[slot.id] = slot;
    podiumImages.push(image);
  }
  const page = createPage(elements, { api: {
    request: () => Promise.resolve({ ok: true, data: avatars.map((avatar_id, index) => ({
      avatar_id, name: `QA ${index}`, total_points: index + 1,
    })) }),
    errorCode: () => '',
  } });
  page.run('landing/js/main.js');
  return { elements, podiumImages };
}

test('special avatar IDs render in podium and list without default substitution', async () => {
  const selected = ['special_gold_miner', 'special_zen_master', 'special_samurai', 'special_cowboy'];
  const page = ranking(selected);
  await settle();
  const images = [...page.podiumImages, page.elements['lb-list'].children[0].children
    .find(child => child.className === 'lb-avatar')];
  images.forEach((image, index) => {
    assert.equal(image.src, `/avatars/${selected[index]}.webp`);
    assert.ok(fs.existsSync(path.join(REPO, 'landing', image.src)));
  });
});

test('unsafe paths and genuinely missing images still use the safe default', async () => {
  const page = ranking(['../../private', 'special_future_unknown', null]);
  await settle();
  assert.equal(page.podiumImages[0].src, '/avatars/avatar_16_basic.webp');
  assert.equal(page.podiumImages[2].src, '/avatars/avatar_16_basic.webp');
  page.podiumImages[1].onerror();
  assert.equal(page.podiumImages[1].src, '/avatars/avatar_16_basic.webp');
  assert.equal(page.podiumImages[1].onerror, null, 'fallback must not recurse');
});
