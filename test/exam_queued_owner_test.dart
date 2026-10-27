import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_exam_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a start queued by the old owner cannot run in the next owner account',
    () async {
      final backend = FakeExamBackend();
      final exam = offlineExamCatalog.exams.first;
      final results = [
        for (final subject in exam.subjects)
          ExamSubjectResult(
            subjectId: subject.id,
            correct: 0,
            wrong: 0,
            blank: subject.questionCount,
          ),
      ];
      final completed = ExamAttempt(
        id: 'completed-for-a',
        clientUuid: 'completed-for-a-uuid',
        examId: exam.id,
        startedAt: backend.clock.subtract(
          Duration(seconds: exam.durationSeconds),
        ),
        endsAt: backend.clock,
        completedAt: backend.clock,
        durationSeconds: exam.durationSeconds,
        totalQuestions: exam.totalQuestions,
        status: ExamAttemptStatus.completed,
        definition: exam,
      );
      SharedPreferences.setMockInitialValues({
        ExamPersistence.keyFor('owner-1'): jsonEncode([
          ExamLocalRecord(
            clientUuid: completed.clientUuid,
            definition: exam,
            createdAt: completed.startedAt,
            attempt: completed,
            pendingAction: ExamPendingAction.results,
            pendingResults: results,
          ).toJson(),
        ]),
      });
      final entered = Completer<void>();
      final release = Completer<Object?>();
      backend.handler = (name, params) async {
        if (name == 'save_exam_results') {
          entered.complete();
          return release.future;
        }
        return backend.defaultRpc(name, params);
      };
      final service = ExamService(backend: backend);
      final initA = service.initialize();
      await entered.future;
      // An automatic outbox sync can hold the lock while the catalog is
      // available. The screen's start intent must stay bound to owner A.
      Object? startError;
      final queuedStart = service.start(exam).catchError((Object error) {
        startError = error;
      });
      backend.owner.value = 'owner-2';
      await Future<void>.delayed(Duration.zero);
      final initB = service.initialize();
      release.complete({'attempt': completed.toJson()});
      await Future.wait([initA, initB, queuedStart]);
      final startCalls = backend.calls
          .where((call) => call.$1 == 'start_exam_attempt')
          .length;
      final nextOwnerRows = await service.persistence.read('owner-2');
      service.dispose();
      backend.owner.dispose();

      expect(startCalls, 0);
      expect(nextOwnerRows, isEmpty);
      expect(startError, isA<ExamFailure>());
    },
  );
}
