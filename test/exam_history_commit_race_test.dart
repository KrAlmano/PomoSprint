import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/utils/async_lock.dart';

import 'support/fake_exam_backend.dart';

/// Same serialized asynchronous write contract as native persistence, with a
/// controllable disk response. The gate pauses after taking the storage lock.
class _BlockedCommitPersistence extends ExamPersistence {
  final _lock = AsyncLock();
  final _disk = <String, List<ExamLocalRecord>>{};
  bool Function(List<ExamLocalRecord>)? blockOnceWhere;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<List<ExamLocalRecord>> read(String uid) =>
      _lock.synchronized(() async => List.of(_disk[uid] ?? []));

  @override
  Future<bool> write(
    String uid,
    List<ExamLocalRecord> rows, {
    bool Function()? canCommit,
  }) => _lock.synchronized(() async {
    if (canCommit?.call() == false) return false;
    if (blockOnceWhere?.call(rows) == true) {
      blockOnceWhere = null;
      entered.complete();
      await release.future;
    }
    if (canCommit?.call() == false) return false;
    _disk[uid] = List.of(rows);
    return true;
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final operation in ['abandon', 'results']) {
    test(
      'history commit cannot overwrite an in-flight $operation disk commit',
      () async {
        final backend = FakeExamBackend();
        final persistence = _BlockedCommitPersistence();
        final service = ExamService(backend: backend, persistence: persistence);
        try {
          await service.initialize();
          await service.start(service.catalog.exams.first);
          var before = service.attempts.single;
          if (operation == 'results') {
            backend.clock = before.endsAt;
            await service.complete(before.clientUuid);
            before = service.attempts.single;
          }

          final historyRequested = Completer<void>();
          final historyReply = Completer<Object?>();
          backend.handler = (name, params) async {
            if (name == 'get_my_exam_attempts') {
              historyRequested.complete();
              return historyReply.future;
            }
            return backend.defaultRpc(name, params);
          };
          final refresh = service.refresh();
          await historyRequested.future;
          persistence.blockOnceWhere = (rows) => rows.any(
            (row) =>
                row.pendingAction == null &&
                (operation == 'abandon'
                    ? row.attempt?.status == ExamAttemptStatus.abandoned
                    : row.attempt?.subjectResults.isNotEmpty == true),
          );
          final Future<void> mutation;
          if (operation == 'abandon') {
            mutation = service.abandon(before.clientUuid);
          } else {
            mutation = service.saveResults(before, [
              for (final subject in before.definition!.subjects)
                ExamSubjectResult(
                  subjectId: subject.id,
                  correct: subject.questionCount,
                  wrong: 0,
                  blank: 0,
                ),
            ]);
          }
          await persistence.entered.future.timeout(const Duration(seconds: 2));
          historyReply.complete({
            'attempts': [before.toJson()],
          });
          // Drain the reply continuation while the real mutation's storage lock
          // remains held. The old implementation queued a stale write behind it.
          for (var i = 0; i < 3; i++) {
            await Future<void>.delayed(Duration.zero);
          }
          persistence.release.complete();
          await Future.wait([mutation, refresh]);
          final record = (await persistence.read('owner-1')).single;
          expect(record.pendingAction, isNull);
          if (operation == 'abandon') {
            expect(record.attempt!.status, ExamAttemptStatus.abandoned);
            expect(service.activeRecord, isNull);
          } else {
            expect(record.attempt!.isCompleted, isTrue);
            expect(
              record.attempt!.subjectResults,
              hasLength(before.definition!.subjects.length),
            );
            expect(
              service.attempts.single.subjectResults,
              hasLength(before.definition!.subjects.length),
            );
          }
        } finally {
          if (!persistence.release.isCompleted) persistence.release.complete();
          service.dispose();
          backend.owner.dispose();
        }
      },
    );
  }
}
