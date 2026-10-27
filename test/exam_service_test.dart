import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_exam_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeExamBackend backend;
  late ExamService service;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = FakeExamBackend();
    var id = 0;
    service = ExamService(backend: backend, createUuid: () => 'uuid-${++id}');
  });
  tearDown(() {
    service.dispose();
    backend.owner.dispose();
  });

  test('old server hides start and leaves normal state alone', () async {
    backend.handler = (_, _) async =>
        throw const PostgrestException(message: 'missing', code: 'PGRST202');
    await service.initialize();
    expect(service.catalog.available, isFalse);
    expect(service.blocksOtherSessions.value, isFalse);
    await expectLater(
      service.start(offlineExamCatalog.exams.first),
      throwsA(isA<ExamFailure>()),
    );
    expect(backend.calls.where((c) => c.$1 == 'start_exam_attempt'), isEmpty);
  });
  test(
    'server start is durable and no client duration or reward is sent',
    () async {
      await service.initialize();
      await service.start(service.catalog.exams.first);
      expect(service.blocksOtherSessions.value, isTrue);
      final params = backend.calls
          .firstWhere((c) => c.$1 == 'start_exam_attempt')
          .$2;
      expect(params.keys, unorderedEquals(['p_client_uuid', 'p_exam_id']));
      final disk = await service.persistence.read('owner-1');
      expect(
        disk.single.attempt!.endsAt.difference(backend.clock),
        const Duration(minutes: 165),
      );
      expect(disk.single.pendingAction, isNull);
      await expectLater(
        service.start(service.catalog.exams.last),
        throwsA(isA<ExamFailure>()),
      );
    },
  );
  test(
    'lost start reply retries same UUID and creates one server attempt',
    () async {
      await service.initialize();
      var failed = false;
      backend.handler = (name, params) async {
        final response = backend.defaultRpc(name, params);
        if (name == 'start_exam_attempt' && !failed) {
          failed = true;
          throw TimeoutException('lost reply');
        }
        return response;
      };
      await service.start(service.catalog.exams.first);
      expect(service.activeRecord!.pendingAction, ExamPendingAction.start);
      await service.retry(service.activeRecord!.clientUuid);
      expect(backend.rows, hasLength(1));
      expect(
        backend.calls
            .where((c) => c.$1 == 'start_exam_attempt')
            .map((c) => c.$2['p_client_uuid'])
            .toSet(),
        hasLength(1),
      );
      expect(service.activeRecord!.attempt, isNotNull);
    },
  );
  test('offline finish is journalled and cold start replays once', () async {
    await service.initialize();
    await service.start(service.catalog.exams.first);
    final uuid = service.activeRecord!.clientUuid;
    backend.clock = backend.clock.add(const Duration(minutes: 165));
    backend.isAvailable = false;
    await service.complete(uuid);
    expect(service.records.single.pendingAction, ExamPendingAction.complete);
    expect(service.blocksOtherSessions.value, isFalse);
    service.dispose();
    service = ExamService(backend: backend);
    await service.initialize();
    expect(service.records.single.pendingAction, ExamPendingAction.complete);
    backend.isAvailable = true;
    await service.refresh();
    await service.sync();
    expect(backend.completions, 1);
    expect(service.attempts.single.status, ExamAttemptStatus.completed);
    expect(service.records.single.pendingAction, isNull);
  });
  test(
    'abandon stays visible, earns no reward and clears the active block',
    () async {
      await service.initialize();
      await service.start(service.catalog.exams.first);
      await service.abandon(service.activeRecord!.clientUuid);
      final a = service.attempts.single;
      expect(a.status, ExamAttemptStatus.abandoned);
      expect(a.pointsEarned, 0);
      expect(a.examCoinsEarned, 0);
      expect(service.blocksOtherSessions.value, isFalse);
      expect(await service.persistence.read('owner-1'), hasLength(1));
    },
  );
  test('late start reply never enters the next owner account', () async {
    await service.initialize();
    final gate = Completer<Object?>();
    backend.handler = (name, params) async => name == 'start_exam_attempt'
        ? gate.future
        : backend.defaultRpc(name, params);
    final pending = service.start(service.catalog.exams.first);
    await Future<void>.delayed(Duration.zero);
    final params = backend.calls
        .firstWhere((c) => c.$1 == 'start_exam_attempt')
        .$2;
    final oldResponse = backend.defaultRpc('start_exam_attempt', params);
    backend.owner.value = null;
    backend.rows.clear();
    backend.owner.value = 'owner-2';
    await Future<void>.delayed(Duration.zero);
    gate.complete(oldResponse);
    await pending;
    expect(service.records, isEmpty);
    expect(service.attempts, isEmpty);
    expect(
      (await service.persistence.read('owner-1')).single.pendingAction,
      ExamPendingAction.start,
    );
    expect(await service.persistence.read('owner-2'), isEmpty);
  });
  test(
    'invalid journal is retained and cannot be overwritten by starting',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ExamPersistence.keyFor('owner-1'), '{bad');
      await service.initialize();
      expect(service.errorCode, 'journal_invalid');
      expect(service.blocksOtherSessions.value, isTrue);
      await expectLater(
        service.start(service.catalog.exams.first),
        throwsA(isA<ExamFailure>()),
      );
      expect(prefs.getString(ExamPersistence.keyFor('owner-1')), '{bad');
    },
  );
  test(
    'net updates queue offline and never call completion or send points',
    () async {
      await service.initialize();
      await service.start(service.catalog.exams.first);
      backend.clock = backend.clock.add(const Duration(minutes: 165));
      await service.complete(service.activeRecord!.clientUuid);
      final attempt = service.attempts.single;
      final results = attempt.definition!.subjects
          .map(
            (s) => ExamSubjectResult(
              subjectId: s.id,
              correct: s.questionCount,
              wrong: 0,
              blank: 0,
            ),
          )
          .toList();
      backend.isAvailable = false;
      await service.saveResults(attempt, results);
      final disk = await service.persistence.read('owner-1');
      expect(disk.single.pendingAction, ExamPendingAction.results);
      backend.isAvailable = true;
      await service.sync();
      expect(backend.completions, 1);
      expect(service.attempts.single.subjectResults, hasLength(results.length));
      final sent = backend.calls
          .lastWhere((c) => c.$1 == 'save_exam_results')
          .$2;
      expect(sent.keys, unorderedEquals(['p_attempt_id', 'p_subject_results']));
      expect(jsonEncode(sent), isNot(contains('points')));
    },
  );
}
