import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/services/server_clock.dart';
import 'package:pomodoro/services/session_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

const category = '0f8fad5b-d9cb-469f-a165-70867728950e';

class _Backend implements SessionQueueBackend {
  @override
  String? signedInUserId = 'u1';
  int calls = 0;
  bool reject = false;
  @override
  Future<Object?> completeSession(PendingSession session, {
    required String expectedUserId,
    required String categoryId,
    required DateTime startedAtForServer,
  }) async {
    calls++;
    if (reject) {
      throw const PostgrestException(message: 'invalid_duration', code: 'P0001');
    }
    return {'total_points': 5};
  }
  @override
  Future<void> createDefaultCategories(String expectedUserId) async {}
  @override
  Future<List<CategoryRef>> fetchCategories(String expectedUserId) async => [];
}

class _FailOnceStore extends InMemorySharedPreferencesStore {
  _FailOnceStore(super.data) : super.withData();
  String? failKey;
  bool failAfterWrite = false;
  bool throwError = false;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key != failKey) return super.setValue(valueType, key, value);
    failKey = null;
    if (failAfterWrite) await super.setValue(valueType, key, value);
    if (throwError) throw StateError('simulated platform failure');
    return false;
  }
}

PendingSession _session(String id) => PendingSession(
  clientUuid: id,
  categoryId: category,
  categoryName: 'Matematik',
  minutes: 25,
  wasPaused: false,
  foregroundSeconds: 1500,
  startedAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
  queuedAt: DateTime.now().toUtc(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Backend backend;
  late SessionQueue queue;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = _Backend();
    queue = SessionQueue(backend: backend, clock: ServerClock());
  });

  for (final raw in ['{broken', '{}', '[null]', '']) {
    test('damaged journal $raw is never overwritten by enqueue', () async {
      final prefs = await SharedPreferences.getInstance();
      final key = SessionQueue.queueKey('u1');
      await prefs.setString(key, raw);
      await expectLater(queue.enqueue('u1', _session('new')), throwsFormatException);
      expect(prefs.getString(key), raw);
      expect(backend.calls, 0);
    });
  }

  for (final threw in [false, true]) {
    for (final written in [false, true]) {
      test('failed enqueue acknowledgement restores prior journal: throw=$threw written=$written', () async {
        await queue.enqueue('u1', _session('old'));
        final prefs = await SharedPreferences.getInstance();
        final key = SessionQueue.queueKey('u1');
        final before = prefs.getString(key);
        final store = _FailOnceStore(await SharedPreferencesStorePlatform.instance.getAll())
          ..failKey = 'flutter.$key'
          ..failAfterWrite = written
          ..throwError = threw;
        SharedPreferencesStorePlatform.instance = store;
        await expectLater(queue.enqueue('u1', _session('new')), throwsStateError);
        expect(prefs.getString(key), before);
        expect((await store.getAll())['flutter.$key'], before);
        expect((await queue.pending('u1')).map((s) => s.clientUuid), ['old']);
      });
    }
  }

  test('rejected history write fails without removing the pending session', () async {
    await queue.enqueue('u1', _session('one'));
    backend.reject = true;
    final store = _FailOnceStore(await SharedPreferencesStorePlatform.instance.getAll())
      ..failKey = 'flutter.${SessionQueue.rejectedKey('u1')}'
      ..failAfterWrite = true;
    SharedPreferencesStorePlatform.instance = store;
    final first = await queue.sync('u1');
    expect(first.stopReason, SessionReason.serverError);
    expect((await queue.pending('u1')).map((s) => s.clientUuid), ['one']);
    expect(await queue.rejectedSessions('u1'), isEmpty);
    final retry = await queue.sync('u1');
    expect(retry.rejected, 1);
    expect(await queue.pending('u1'), isEmpty);
    expect((await queue.rejectedSessions('u1')).single.clientUuid, 'one');
  });

  test('damaged rejected history cannot cause pending session loss', () async {
    await queue.enqueue('u1', _session('one'));
    final prefs = await SharedPreferences.getInstance();
    final key = SessionQueue.rejectedKey('u1');
    await prefs.setString(key, '{broken');
    backend.reject = true;
    final result = await queue.sync('u1');
    expect(result.stopReason, SessionReason.serverError);
    expect(prefs.getString(key), '{broken');
    expect((await queue.pending('u1')).map((s) => s.clientUuid), ['one']);
    expect(jsonDecode(prefs.getString(SessionQueue.queueKey('u1'))!), hasLength(1));
  });
}
