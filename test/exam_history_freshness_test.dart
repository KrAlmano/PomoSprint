import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_model.dart';
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
    service = ExamService(backend: backend);
  });
  tearDown(() {
    service.dispose();
    backend.owner.dispose();
  });

  void seedCompleted() {
    final exam = offlineExamCatalog.exams.first;
    backend.rows['done'] = ExamAttempt(
      id: 'done',
      clientUuid: 'done',
      examId: exam.id,
      startedAt: backend.clock.subtract(const Duration(days: 1)),
      endsAt: backend.clock.subtract(const Duration(hours: 1)),
      durationSeconds: exam.durationSeconds,
      totalQuestions: exam.totalQuestions,
      status: ExamAttemptStatus.completed,
      definition: exam,
    );
  }

  test(
    'first failed history read is stale rather than verified empty',
    () async {
      backend.handler = (name, params) async {
        if (name == 'get_my_exam_attempts') throw TimeoutException('offline');
        return backend.defaultRpc(name, params);
      };
      await service.initialize();
      expect(service.historyIsStale, isTrue);
      expect(service.attempts, isEmpty);
      backend.handler = null;
      await service.refresh();
      expect(service.historyIsStale, isFalse);
      expect(service.attempts, isEmpty);
    },
  );

  test(
    'failed refresh retains accepted cache and successful retry clears stale',
    () async {
      seedCompleted();
      await service.initialize();
      expect(service.historyIsStale, isFalse);
      backend.handler = (name, params) async {
        if (name == 'get_my_exam_attempts') throw TimeoutException('offline');
        return backend.defaultRpc(name, params);
      };
      await service.refresh();
      expect(service.historyIsStale, isTrue);
      expect(service.attempts.single.id, 'done');
      backend.handler = null;
      await service.refresh();
      expect(service.historyIsStale, isFalse);
      expect(service.attempts.single.id, 'done');
    },
  );

  test(
    'concurrent first refresh does not classify incomplete history as fresh',
    () async {
      final requested = Completer<void>();
      final gate = Completer<Object?>();
      backend.handler = (name, params) async {
        if (name == 'get_my_exam_attempts') {
          requested.complete();
          return gate.future;
        }
        return backend.defaultRpc(name, params);
      };
      final initial = service.initialize();
      await requested.future;
      var returned = false;
      final concurrent = service.refresh().then<void>((_) {
        returned = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(returned, isFalse);
      expect(service.historyIsStale, isTrue);
      gate.complete(backend.defaultRpc('get_my_exam_attempts', {}));
      await Future.wait([initial, concurrent]);
      expect(service.historyIsStale, isFalse);
    },
  );

  test(
    'concurrent report refresh waits for the new complete snapshot',
    () async {
      seedCompleted();
      await service.initialize();
      final exam = offlineExamCatalog.exams.first;
      backend.rows['new'] = ExamAttempt(
        id: 'new',
        clientUuid: 'new',
        examId: exam.id,
        startedAt: backend.clock.subtract(const Duration(hours: 3)),
        endsAt: backend.clock.subtract(const Duration(hours: 1)),
        durationSeconds: exam.durationSeconds,
        totalQuestions: exam.totalQuestions,
        status: ExamAttemptStatus.completed,
        definition: exam,
      );
      final requested = Completer<void>();
      final gate = Completer<Object?>();
      backend.handler = (name, params) async {
        if (name == 'get_my_exam_attempts') {
          if (!requested.isCompleted) requested.complete();
          return gate.future;
        }
        return backend.defaultRpc(name, params);
      };
      final refresh = service.refresh();
      await requested.future;
      var returned = false;
      final reportsRead = service.refresh().then((_) {
        returned = true;
        return service.attempts.map((e) => e.id).toSet();
      });
      await Future<void>.delayed(Duration.zero);
      expect(returned, isFalse);
      gate.complete(backend.defaultRpc('get_my_exam_attempts', {}));
      await refresh;
      expect(await reportsRead, {'done', 'new'});
      expect(service.historyIsStale, isFalse);
      expect(
        backend.calls.where((call) => call.$1 == 'get_my_exam_attempts').length,
        2, // initial + one shared refresh
      );
    },
  );

  test(
    'offline transport marks existing history stale without discarding it',
    () async {
      seedCompleted();
      await service.initialize();
      backend.isAvailable = false;
      await service.refresh();
      expect(service.historyIsStale, isTrue);
      expect(service.attempts.single.id, 'done');
      backend.isAvailable = true;
      await service.refresh();
      expect(service.historyIsStale, isFalse);
    },
  );

  test(
    'legacy missing RPC and deliberately disabled feature are not outages',
    () async {
      backend.handler = (_, _) async =>
          throw const PostgrestException(message: 'missing', code: 'PGRST202');
      await service.initialize();
      expect(service.historyIsStale, isFalse);
      backend.handler = null;
      backend.featureAvailable = false;
      await service.refresh();
      expect(service.historyIsStale, isFalse);
      expect(service.catalog.available, isFalse);
    },
  );

  test(
    'malformed catalogue is a failed read rather than a disabled feature',
    () async {
      backend.handler = (_, _) async => {
        'schema_version': 1,
        'available': true,
      };
      await service.initialize();
      expect(service.historyIsStale, isTrue);
      expect(service.catalog.available, isFalse);
      backend.handler = null;
      await service.refresh();
      expect(service.historyIsStale, isFalse);
    },
  );
}
