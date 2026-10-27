import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_exam_backend.dart';

/// Independent regression checks for the backend/client contract audit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeExamBackend backend;
  late ExamService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend = FakeExamBackend();
    var sequence = 0;
    service = ExamService(
      backend: backend,
      createUuid: () => 'audit-${++sequence}',
    );
  });
  tearDown(() {
    service.dispose();
    backend.owner.dispose();
  });

  Future<ExamAttempt> completeFirstAttempt() async {
    await service.initialize();
    await service.start(service.catalog.exams.first);
    final active = service.activeRecord!.attempt!;
    backend.clock = active.endsAt;
    await service.complete(active.clientUuid);
    return service.attempts.single;
  }

  List<ExamSubjectResult> validResults(ExamAttempt attempt) => [
    for (final subject in attempt.definition!.subjects)
      ExamSubjectResult(
        subjectId: subject.id,
        correct: subject.questionCount,
        wrong: 0,
        blank: 0,
      ),
  ];

  test('late active history cannot resurrect a completed journal entry', () async {
    await service.initialize();
    await service.start(service.catalog.exams.first);
    final oldActive = service.activeRecord!.attempt!;
    final requested = Completer<void>();
    final delayedHistory = Completer<Object?>();
    backend.handler = (name, params) async {
      if (name == 'get_my_exam_attempts') {
        requested.complete();
        return delayedHistory.future;
      }
      return backend.defaultRpc(name, params);
    };
    final refresh = service.refresh();
    await requested.future;
    backend.clock = oldActive.endsAt;
    await service.complete(oldActive.clientUuid);
    expect(service.attempts.single.isCompleted, isTrue);
    delayedHistory.complete({
      'server_time': oldActive.startedAt.toIso8601String(),
      'attempts': [oldActive.toJson()],
    });
    await refresh;
    expect(service.attempts.single.status, ExamAttemptStatus.completed);
    expect(service.activeRecord, isNull);
    expect((await service.persistence.read('owner-1')).single.attempt!.isCompleted, isTrue);
    expect(backend.completions, 1);
  });

  test('old owner results cannot be journalled or sent by the new owner', () async {
    final oldAttempt = await completeFirstAttempt();
    backend.rows.clear();
    backend.owner.value = 'owner-2';
    await Future<void>.delayed(Duration.zero);
    expect(service.attempts, isEmpty);
    final callsBefore = backend.calls.length;
    await expectLater(
      service.saveResults(oldAttempt, validResults(oldAttempt)),
      throwsA(isA<ExamFailure>()),
    );
    expect(await service.persistence.read('owner-2'), isEmpty);
    expect(
      backend.calls.skip(callsBefore).where((call) => call.$1 == 'save_exam_results'),
      isEmpty,
    );
  });

  test('late completed history cannot erase freshly saved subject results', () async {
    final oldCompleted = await completeFirstAttempt();
    final requested = Completer<void>();
    final delayedHistory = Completer<Object?>();
    backend.handler = (name, params) async {
      if (name == 'get_my_exam_attempts') {
        requested.complete();
        return delayedHistory.future;
      }
      return backend.defaultRpc(name, params);
    };
    final refresh = service.refresh();
    await requested.future;
    final results = validResults(oldCompleted);
    await service.saveResults(oldCompleted, results);
    expect(service.attempts.single.subjectResults, hasLength(results.length));
    delayedHistory.complete({
      'server_time': oldCompleted.endsAt.toIso8601String(),
      'attempts': [oldCompleted.toJson()],
    });
    await refresh;
    expect(service.attempts.single.subjectResults, hasLength(results.length));
    expect((await service.persistence.read('owner-1')).single.attempt!.subjectResults, hasLength(results.length));
  });

  test('corrupt nested attempt preserves journal and fails closed', () async {
    await service.initialize();
    await service.start(service.catalog.exams.first);
    final record = service.records.single.toJson();
    record['attempt'] = {'id': 'incomplete'};
    final corrupt = jsonEncode([record]);
    final prefs = await SharedPreferences.getInstance();
    final key = ExamPersistence.keyFor('owner-1');
    await prefs.setString(key, corrupt);
    await expectLater(
      service.persistence.read('owner-1'),
      throwsA(isA<FormatException>()),
    );
    expect(prefs.getString(key), corrupt);
  });

  test('corrupt pending results cannot silently discard a subject', () async {
    final attempt = await completeFirstAttempt();
    final record = service.records.single.toJson();
    record['pending_action'] = 'results';
    record['pending_results'] = [
      validResults(attempt).first.toJson(),
      {'subject_id': 'corrupt', 'correct': 'not-an-integer', 'wrong': 0, 'blank': 0},
    ];
    final corrupt = jsonEncode([record]);
    final prefs = await SharedPreferences.getInstance();
    final key = ExamPersistence.keyFor('owner-1');
    await prefs.setString(key, corrupt);
    await expectLater(
      service.persistence.read('owner-1'),
      throwsA(isA<FormatException>()),
    );
    expect(prefs.getString(key), corrupt);
  });

  test('deleted owner cannot recreate its journal through a late write', () async {
    await service.initialize();
    await service.start(service.catalog.exams.first);
    final oldRows = service.records;
    await service.persistence.retireOwner('owner-1');
    expect(await service.persistence.write('owner-1', oldRows), isFalse);
    expect(await service.persistence.read('owner-1'), isEmpty);
  });
}
