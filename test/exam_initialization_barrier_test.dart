import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_exam_backend.dart';

class _DelayedRead extends ExamPersistence {
  final pending = Completer<List<ExamLocalRecord>>();
  @override
  Future<List<ExamLocalRecord>> read(String uid) =>
      uid == 'owner-1' ? pending.future : super.read(uid);
}

ExamLocalRecord _active(DateTime now) {
  final exam = offlineExamCatalog.exams.first;
  return ExamLocalRecord(
    clientUuid: 'restored-active',
    definition: exam,
    createdAt: now,
    attempt: ExamAttempt(
      id: 'active-attempt',
      clientUuid: 'restored-active',
      examId: exam.id,
      startedAt: now,
      endsAt: now.add(Duration(seconds: exam.durationSeconds)),
      durationSeconds: exam.durationSeconds,
      totalQuestions: exam.totalQuestions,
      status: ExamAttemptStatus.active,
      definition: exam,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'concurrent initialization waits for restored journal and keeps start gate closed',
    () async {
      final backend = FakeExamBackend()..isAvailable = false;
      final persistence = _DelayedRead();
      final service = ExamService(backend: backend, persistence: persistence);
      final first = service.initialize();
      var secondReturned = false;
      final second = service.initialize().then((_) => secondReturned = true);
      await Future<void>.delayed(Duration.zero);
      final returnedBeforeRead = secondReturned;
      final blockBeforeRead = service.blocksOtherSessions.value;
      persistence.pending.complete([_active(backend.clock)]);
      await Future.wait([first, second]);
      final restored = service.activeRecord;
      final blockAfterRead = service.blocksOtherSessions.value;
      service.dispose();
      backend.owner.dispose();

      expect(
        returnedBeforeRead,
        isFalse,
        reason: 'A second start gate must await the first disk read',
      );
      expect(
        blockBeforeRead,
        isTrue,
        reason: 'Unknown restored state is not permission for a new session',
      );
      expect(restored?.clientUuid, 'restored-active');
      expect(blockAfterRead, isTrue);
    },
  );

  test(
    'an old delayed owner read cannot replace the new owner initialization',
    () async {
      final backend = FakeExamBackend()..isAvailable = false;
      final persistence = _DelayedRead();
      final service = ExamService(backend: backend, persistence: persistence);
      final old = service.initialize();
      backend.owner.value = 'owner-2';
      await service.initialize();
      expect(service.records, isEmpty);
      persistence.pending.complete([_active(backend.clock)]);
      await old;
      expect(service.records, isEmpty);
      expect(service.blocksOtherSessions.value, isFalse);
      service.dispose();
      backend.owner.dispose();
    },
  );

  test(
    'a listener can re-enter initialization without bypassing or deadlocking restore',
    () async {
      final backend = FakeExamBackend()..isAvailable = false;
      final persistence = _DelayedRead();
      final service = ExamService(backend: backend, persistence: persistence);
      Future<void>? reentered;
      service.addListener(() {
        reentered ??= service.initialize();
      });
      final first = service.initialize();
      expect(reentered, isNotNull);
      var listenerReturned = false;
      final listenerFuture = reentered!.then((_) => listenerReturned = true);
      await Future<void>.delayed(Duration.zero);
      final returnedBeforeRead = listenerReturned;
      persistence.pending.complete([]);
      await Future.wait([
        first,
        listenerFuture,
      ]).timeout(const Duration(seconds: 2));
      service.dispose();
      backend.owner.dispose();
      expect(returnedBeforeRead, isFalse);
    },
  );
}
