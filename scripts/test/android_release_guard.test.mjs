import assert from 'node:assert/strict';
import fs from 'node:fs';
import { test } from 'node:test';

const source = fs.readFileSync(new URL('../../android/app/build.gradle.kts', import.meta.url), 'utf8');

// Exercise the exact task-name patterns in the Gradle source, not a second
// hand-maintained matcher. The real Gradle DAG is separately checked offline.
function taskPattern(variable) {
  const literal = source.match(new RegExp(`val ${variable} = Regex\\("([^"\\n]+)"\\)`));
  assert.ok(literal, `${variable} must be an explicit full task-name regex`);
  return new RegExp(literal[1]);
}

test('real standard and flavored release bundles remain protected', () => {
  const bundle = taskPattern('releaseBundleTaskName');
  for (const name of ['bundleRelease', 'bundlePaidRelease', 'bundleDemoProdRelease']) {
    assert.equal(bundle.test(name), true, name);
  }
  for (const name of ['bundleDebug', 'bundlePaidDebug', 'bundleReleaseLocalLintAar',
    'bundlePaidReleaseLocalLintAar', 'prepareBundleRelease', 'bundleReleaseResources']) {
    assert.equal(bundle.test(name), false, name);
  }
});

test('release APK tasks are separate from bundle and internal tasks', () => {
  const apk = taskPattern('releaseApkTaskName');
  for (const name of ['assembleRelease', 'assemblePaidRelease', 'assembleDemoProdRelease']) {
    assert.equal(apk.test(name), true, name);
  }
  for (const name of ['assembleDebug', 'assemblePaidDebug', 'bundleRelease',
    'assembleReleaseAndroidTest', 'assembleReleaseUnitTest']) {
    assert.equal(apk.test(name), false, name);
  }
});

test('the guard applies the name match only to this app project', () => {
  assert.match(source, /val appTasks = allTasks\.filter \{ it\.project == project \}/);
  assert.match(source, /val buildsStoreBundle = appTasks\.any \{ releaseBundleTaskName\.matches\(it\.name\) \}/);
  assert.match(source, /val buildsReleaseApk = appTasks\.any \{ releaseApkTaskName\.matches\(it\.name\) \}/);
  assert.doesNotMatch(source, /it\.name\.contains\("(?:bundle|assemble)Release"/);
});

test('missing signing properties still reject store bundles and retain the local APK fallback', () => {
  assert.match(source, /signingConfig = if \(keystorePropertiesFile\.exists\(\)\) \{[\s\S]*?signingConfigs\.getByName\("release"\)[\s\S]*?\} else \{\s*signingConfigs\.getByName\("debug"\)/);
  assert.match(source, /if \(!keystorePropertiesFile\.exists\(\)\) \{[\s\S]*?if \(buildsStoreBundle\) \{\s*throw GradleException/);
  assert.match(source, /if \(buildsReleaseApk\) \{\s*logger\.warn/);
});
