import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _FailingStore extends InMemorySharedPreferencesStore {
  _FailingStore() : super.withData({});
  String? failSet;
  String? failRemove;
  bool throws = false;
  bool removeFirst = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == failSet) {
      failSet = null;
      if (throws) throw StateError('disk full');
      return false;
    }
    return super.setValue(type, key, value);
  }
  @override
  Future<bool> remove(String key) async {
    if (key == failRemove) {
      failRemove = null;
      if (removeFirst) await super.remove(key);
      if (throws) throw StateError('disk full');
      return false;
    }
    return super.remove(key);
  }
}

void main() {
  test('legacy migration failures retain the source and never expose a duplicate completion', () async {
    final backend = _FailingStore();
    SharedPreferencesStorePlatform.instance = backend;
    final prefs = await SharedPreferences.getInstance();
    final store = TimerPersistence.instance;
    for (final failure in ['write-false', 'write-throw', 'remove-false', 'remove-throw', 'remove-after-write']) {
      final owner = 'uid-$failure';
      final legacy = 'mail-$failure';
      final legacyKey = TimerPersistence.keyFor(legacy);
      final session = ActiveTimerSession.start(
        clientUuid: 'uuid-$failure', categoryId: 'cat', categoryName: 'Math',
        durationMinutes: 25, totalSeconds: 1500, now: DateTime(2026, 11, 1),
      );
      final raw = jsonEncode(session.toJson());
      await prefs.setString(legacyKey, raw);
      backend.throws = failure.endsWith('throw');
      backend.removeFirst = failure == 'remove-after-write';
      if (failure.startsWith('write')) {
        backend.failSet = 'flutter.${TimerPersistence.keyFor(owner)}';
      } else {
        backend.failRemove = 'flutter.$legacyKey';
      }
      expect(await store.load(owner, legacyOwnerKey: legacy), isNull, reason: failure);
      expect(await store.hasInvalidRecord(owner, legacyOwnerKey: legacy), isTrue);
      expect(prefs.getString(legacyKey), raw);
      expect(await store.load(owner), isNull);
      expect(await store.saveChecked(owner, session), isFalse);
      await store.clear(owner, onlyClientUuid: session.clientUuid);
      expect(prefs.getString(legacyKey), raw);
      final restored = await store.load(owner, legacyOwnerKey: legacy);
      expect(restored?.clientUuid, session.clientUuid);
      expect(prefs.getString(legacyKey), isNull);
      await store.clear(owner, onlyClientUuid: session.clientUuid);
      expect(await store.load(owner, legacyOwnerKey: legacy), isNull);
    }
  });

  test('different current and legacy records are preserved for manual recovery', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = TimerPersistence.instance;
    ActiveTimerSession session(String id) => ActiveTimerSession.start(
      clientUuid: id, categoryId: 'c', categoryName: 'Math',
      durationMinutes: 25, totalSeconds: 1500, now: DateTime(2026, 11, 1),
    );
    final currentRaw = jsonEncode(session('current').toJson());
    final legacyRaw = jsonEncode(session('legacy').toJson());
    await prefs.setString(TimerPersistence.keyFor('conflict-owner'), currentRaw);
    await prefs.setString(TimerPersistence.keyFor('conflict-email'), legacyRaw);
    expect(await store.load('conflict-owner', legacyOwnerKey: 'conflict-email'), isNull);
    expect(await store.hasInvalidRecord('conflict-owner', legacyOwnerKey: 'conflict-email'), isTrue);
    expect(prefs.getString(TimerPersistence.keyFor('conflict-owner')), currentRaw);
    expect(prefs.getString(TimerPersistence.keyFor('conflict-email')), legacyRaw);
  });
}
