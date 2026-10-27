import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_exam_backend.dart';

class _PausedRead extends ExamPersistence {
  final gate = Completer<List<ExamLocalRecord>>();
  int writes = 0;
  @override
  Future<List<ExamLocalRecord>> read(String uid) => gate.future;
  @override
  Future<bool> write(
    String uid,
    List<ExamLocalRecord> rows, {
    bool Function()? canCommit,
  }) {
    writes++;
    return super.write(uid, rows, canCommit: canCommit);
  }
}

ExamLocalRecord _record(
  FakeExamBackend backend, {
  bool completed = false,
  bool pendingResults = false,
}) {
  final exam = offlineExamCatalog.exams.first;
  final start = completed
      ? backend.clock.subtract(Duration(seconds: exam.durationSeconds))
      : backend.clock;
  return ExamLocalRecord(
    clientUuid: 'restore-record',
    definition: exam,
    createdAt: start,
    attempt: ExamAttempt(
      id: 'restore-attempt',
      clientUuid: 'restore-record',
      examId: exam.id,
      startedAt: start,
      endsAt: start.add(Duration(seconds: exam.durationSeconds)),
      durationSeconds: exam.durationSeconds,
      totalQuestions: exam.totalQuestions,
      status: completed
          ? ExamAttemptStatus.completed
          : ExamAttemptStatus.active,
      definition: exam,
    ),
    pendingAction: pendingResults ? ExamPendingAction.results : null,
    pendingResults: pendingResults ? _results() : null,
  );
}

List<ExamSubjectResult> _results() => [
  for (final subject in offlineExamCatalog.exams.first.subjects)
    ExamSubjectResult(
      subjectId: subject.id,
      correct: 0,
      wrong: 0,
      blank: subject.questionCount,
    ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'external refresh and foreground cannot publish or save an empty pre-restore snapshot',
    () async {
      final backend = FakeExamBackend();
      final storage = _PausedRead();
      final row = _record(backend);
      backend.rows[row.clientUuid] = row.attempt!;
      final service = ExamService(backend: backend, persistence: storage);
      final init = service.initialize();
      final refresh = service.refresh();
      service.setForeground(true);
      await Future<void>.delayed(Duration.zero);
      final earlyWrites = storage.writes;
      final earlyCatalog = service.catalog.available;
      storage.gate.complete([row]);
      await Future.wait([init, refresh]);
      final restoredUuid = service.activeRecord?.clientUuid;
      service.dispose();
      backend.owner.dispose();
      expect(
        earlyWrites,
        0,
        reason:
            'A crash during restore must not leave an empty journal on disk',
      );
      expect(earlyCatalog, isFalse);
      expect(restoredUuid, row.clientUuid);
    },
  );

  test(
    'a new start waits for restore and then respects its active attempt',
    () async {
      final backend = FakeExamBackend();
      final storage = _PausedRead();
      final row = _record(backend);
      backend.rows[row.clientUuid] = row.attempt!;
      final service = ExamService(backend: backend, persistence: storage);
      final init = service.initialize();
      var returned = false;
      Object? error;
      final start = service
          .start(row.definition)
          .then<void>(
            (_) {
              returned = true;
            },
            onError: (Object e) {
              returned = true;
              error = e;
            },
          );
      await Future<void>.delayed(Duration.zero);
      final earlyReturn = returned;
      storage.gate.complete([row]);
      await Future.wait([init, start]);
      final starts = backend.calls
          .where((call) => call.$1 == 'start_exam_attempt')
          .length;
      service.dispose();
      backend.owner.dispose();
      expect(earlyReturn, isFalse);
      expect(starts, 0);
      expect(error, isA<ExamFailure>());
    },
  );

  for (final action in ['sync', 'retry', 'abandon', 'results']) {
    test(
      '$action waits for the owner journal before resolving or mutating',
      () async {
        final backend = FakeExamBackend();
        final storage = _PausedRead();
        final resultAction = action != 'abandon';
        final row = _record(
          backend,
          completed: resultAction,
          pendingResults: action == 'sync' || action == 'retry',
        );
        backend.rows[row.clientUuid] = row.attempt!;
        final service = ExamService(backend: backend, persistence: storage);
        final init = service.initialize();
        var returned = false;
        Object? error;
        final operation = switch (action) {
          'sync' => service.sync(),
          'retry' => service.retry(row.clientUuid),
          'abandon' => service.abandon(row.clientUuid),
          _ => service.saveResults(row.attempt!, _results()),
        };
        final finished = operation.then<void>(
          (_) {
            returned = true;
          },
          onError: (Object e) {
            returned = true;
            error = e;
          },
        );
        await Future<void>.delayed(Duration.zero);
        final earlyReturn = returned;
        storage.gate.complete([row]);
        await Future.wait([init, finished]);
        final actual = service.attempts.single;
        service.dispose();
        backend.owner.dispose();
        expect(earlyReturn, isFalse);
        expect(error, isNull);
        if (action == 'abandon') {
          expect(actual.status, ExamAttemptStatus.abandoned);
        } else {
          expect(actual.subjectResults, hasLength(_results().length));
        }
      },
    );
  }
}
