import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'support/fake_exam_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeExamBackend backend;
  late ExamService service;
  late List<ExamAttempt> rows;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = FakeExamBackend();
    final exam = offlineExamCatalog.exams.first;
    rows = List.generate(101, (i) => ExamAttempt(
      id: '00000000-0000-0000-0000-${(101 - i).toString().padLeft(12, '0')}',
      clientUuid: 'client-$i', examId: exam.id,
      startedAt: backend.clock,
      endsAt: backend.clock.add(Duration(seconds: exam.durationSeconds)),
      completedAt: backend.clock.add(Duration(seconds: exam.durationSeconds)),
      durationSeconds: exam.durationSeconds, totalQuestions: exam.totalQuestions,
      status: ExamAttemptStatus.completed, definition: exam,
    ));
    service = ExamService(backend: backend);
    service.setForeground(false);
  });
  tearDown(() { service.dispose(); backend.owner.dispose(); });

  test('v2 reads all 101 same-timestamp attempts using the UUID cursor', () async {
    backend.handler = (name, params) async {
      if (name != 'get_my_exam_attempts_v2') return backend.defaultRpc(name, params);
      if (params['p_before_id'] == null) {
        return {'attempts': rows.take(100).map((a) => a.toJson()).toList(),
          'next_cursor': {'started_at': rows[99].startedAt.toIso8601String(), 'id': rows[99].id}};
      }
      expect(params['p_before_id'], rows[99].id);
      expect(params['p_before_started_at'], rows[99].startedAt.toIso8601String());
      return {'attempts': [rows.last.toJson()], 'next_cursor': null};
    };
    await service.initialize();
    expect(service.attempts.map((a) => a.clientUuid).toSet(), rows.map((a) => a.clientUuid).toSet());
    expect(service.historyIsStale, isFalse);
    expect(backend.calls.where((call) => call.$1 == 'get_my_exam_attempts'), isEmpty);
  });

  test('legacy timestamp boundary is marked incomplete instead of silently claiming a full report', () async {
    backend.handler = (name, params) async {
      if (name == 'get_my_exam_attempts_v2') {
        throw const PostgrestException(message: 'missing', code: 'PGRST202');
      }
      if (name == 'get_my_exam_attempts') {
        if (params['p_before'] == null) {
          return {
            'attempts': rows.take(100).map((a) => a.toJson()).toList(),
            'next_cursor': rows[99].startedAt.toIso8601String(),
          };
        }
        return {'attempts': <Object>[], 'next_cursor': null};
      }
      return backend.defaultRpc(name, params);
    };
    await service.initialize();
    expect(service.attempts, hasLength(100));
    expect(service.historyIsStale, isTrue);
    expect(service.errorCode, 'exam_history_cursor_ambiguous');
  });

  test('network failure on v2 does not downgrade to legacy', () async {
    backend.handler = (name, params) async {
      if (name == 'get_my_exam_attempts_v2') throw TimeoutException('offline');
      return backend.defaultRpc(name, params);
    };
    await service.initialize();
    expect(service.historyIsStale, isTrue);
    expect(backend.calls.where((call) => call.$1 == 'get_my_exam_attempts'), isEmpty);
  });

  test('invalid v2 cursor is an error, not a successful incomplete report', () async {
    backend.handler = (name, params) async {
      if (name == 'get_my_exam_attempts_v2') {
        return {
          'attempts': [rows.first.toJson()],
          'next_cursor': {'started_at': 'invalid', 'id': rows.first.id},
        };
      }
      return backend.defaultRpc(name, params);
    };
    await service.initialize();
    expect(service.historyIsStale, isTrue);
    expect(service.errorCode, 'invalid_response');
  });

  test('synchronous listener owner switch cannot send A start as B', () async {
    await service.initialize();
    var switched = false;
    service.addListener(() {
      if (service.busy && !switched) {
        switched = true;
        backend.owner.value = 'owner-2';
      }
    });
    await service.start(service.catalog.exams.first);
    expect(switched, isTrue);
    expect(backend.calls.where((call) => call.$1 == 'start_exam_attempt'), isEmpty);
    final oldRecords = await service.persistence.read('owner-1');
    expect(oldRecords.single.pendingAction, isNotNull);
    expect(await service.persistence.read('owner-2'), isEmpty);
  });
}
