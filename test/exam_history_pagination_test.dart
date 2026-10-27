import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:pomodoro/utils/study_day.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_exam_backend.dart';

List<ExamAttempt> _completedHistory(FakeExamBackend backend) {
  final exam = offlineExamCatalog.exams.first;
  return List.generate(201, (index) {
    final start = backend.clock.subtract(Duration(hours: (index + 1) * 3));
    final end = start.add(Duration(seconds: exam.durationSeconds));
    return ExamAttempt(
      id: 'history-$index',
      clientUuid: 'history-uuid-$index',
      examId: exam.id,
      startedAt: start,
      endsAt: end,
      completedAt: end,
      durationSeconds: exam.durationSeconds,
      totalQuestions: exam.totalQuestions,
      status: ExamAttemptStatus.completed,
      definition: exam,
    );
  });
}

/// Deliberately follows a final cursor to an empty terminal page. A short
/// page alone must not make the client ignore a server-provided next_cursor.
Object _page(List<ExamAttempt> history, String? cursor) {
  final second = history[99].startedAt.toIso8601String();
  final third = history[199].startedAt.toIso8601String();
  final empty = history[200].startedAt.toIso8601String();
  final (rows, next) = switch (cursor) {
    null => (history.sublist(0, 100), second),
    final value when value == second => (history.sublist(100, 200), third),
    final value when value == third => (history.sublist(200), empty),
    final value when value == empty => (<ExamAttempt>[], null),
    _ => throw StateError('Unexpected history cursor'),
  };
  return {
    'attempts': rows.map((attempt) => attempt.toJson()).toList(),
    'next_cursor': next,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeExamBackend backend;
  late ExamService service;
  late List<ExamAttempt> history;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setStudyTimeZone('Europe/Istanbul');
    backend = FakeExamBackend();
    history = _completedHistory(backend);
    service = ExamService(backend: backend);
    service.setForeground(false);
    backend.handler = (name, params) async => name == 'get_my_exam_attempts'
        ? _page(history, params['p_before'] as String?)
        : backend.defaultRpc(name, params);
  });

  tearDown(() {
    service.dispose();
    backend.owner.dispose();
    setStudyTimeZone('Europe/Istanbul');
  });

  test(
    '201 completed attempts traverse 100/100/1/empty pages and count once with the local journal',
    () async {
      // The same accepted attempt is already durable before the server read.
      // Pagination must not count this local/remote overlap twice.
      final existing = history.first;
      await service.persistence.write(backend.ownerId!, [
        ExamLocalRecord(
          clientUuid: existing.clientUuid,
          definition: existing.definition!,
          createdAt: existing.startedAt,
          attempt: existing,
        ),
      ]);
      await service.initialize();

      final requests = backend.calls
          .where((call) => call.$1 == 'get_my_exam_attempts')
          .map((call) => call.$2)
          .toList();
      expect(requests, hasLength(4));
      expect(requests.map((params) => params['p_limit']), everyElement(100));
      expect(requests.first.containsKey('p_before'), isFalse);
      expect(requests.skip(1).map((params) => params['p_before']), [
        history[99].startedAt.toIso8601String(),
        history[199].startedAt.toIso8601String(),
        history[200].startedAt.toIso8601String(),
      ]);
      expect(service.attempts, hasLength(201));
      expect(
        service.attempts.map((attempt) => attempt.clientUuid).toSet(),
        history.map((attempt) => attempt.clientUuid).toSet(),
      );
      expect(service.records, hasLength(201));
      expect(await service.persistence.read(backend.ownerId!), hasLength(201));
      expect(service.historyIsStale, isFalse);
      expect(service.errorCode, isNull);

      final combined = combineStudyAndExamSessions(
        study: [
          // Even an identical UUID in the normal namespace is a distinct
          // activity, while the remote/journal exam overlap is not.
          StatSession(
            day: DateTime(2026, 10, 27),
            minutes: 50,
            categoryName: 'Matematik',
            clientUuid: existing.clientUuid,
          ),
        ],
        exams: service.attempts,
        timeZone: 'Europe/Istanbul',
      );
      expect(sumMinutes(combined), 201 * 165 + 50);
      final counts = sessionTypeCounts(
        combined,
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 31),
      );
      expect(counts.completedExams, 201);
      expect(counts.normalSessions, 1);
      expect(counts.focusEquivalents, 2);
      expect(counts.completedMarathons, 0);
    },
  );

  test(
    'second-page network failure keeps the complete accepted cache and exposes stale state until retry',
    () async {
      await service.initialize();
      final before = service.attempts
          .map((attempt) => attempt.toJson())
          .toList();
      final prefs = await SharedPreferences.getInstance();
      final beforeDisk = prefs.getString(
        ExamPersistence.keyFor(backend.ownerId!),
      );
      var pages = 0;
      backend.handler = (name, params) async {
        if (name != 'get_my_exam_attempts') {
          return backend.defaultRpc(name, params);
        }
        pages++;
        if (pages == 2) throw TimeoutException('second history page offline');
        // A partial new result must never replace the previous full history.
        return {
          'attempts': [
            {
              ...history.first.toJson(),
              'id': 'new-id',
              'client_uuid': 'new-uuid',
            },
          ],
          'next_cursor': 'next-history-page',
        };
      };
      await service.refresh();

      expect(pages, 2);
      expect(service.historyIsStale, isTrue);
      expect(service.errorCode, 'connection');
      expect(service.catalog.available, isTrue);
      expect(
        service.attempts.map((attempt) => attempt.toJson()).toList(),
        before,
      );
      expect(
        prefs.getString(ExamPersistence.keyFor(backend.ownerId!)),
        beforeDisk,
      );
      expect(
        service.attempts.any((attempt) => attempt.clientUuid == 'new-uuid'),
        isFalse,
      );

      backend.handler = (name, params) async => name == 'get_my_exam_attempts'
          ? _page(history, params['p_before'] as String?)
          : backend.defaultRpc(name, params);
      await service.refresh();
      expect(service.historyIsStale, isFalse);
      expect(service.errorCode, isNull);
      expect(service.attempts, hasLength(201));
    },
  );

  test(
    'repeated next_cursor stops after two pages with a safe stale error and preserves history',
    () async {
      await service.initialize();
      final before = service.attempts
          .map((attempt) => attempt.toJson())
          .toList();
      var pages = 0;
      backend.handler = (name, params) async {
        if (name != 'get_my_exam_attempts') {
          return backend.defaultRpc(name, params);
        }
        pages++;
        // Bound the fake server too, so removing the client's cycle guard
        // creates a failed assertion instead of an unbounded test loop.
        if (pages > 3) throw StateError('unbounded repeated history cursor');
        return {
          'attempts': history
              .take(100)
              .map((attempt) => attempt.toJson())
              .toList(),
          'next_cursor': 'same-cursor',
        };
      };
      await service.refresh().timeout(const Duration(seconds: 3));

      expect(pages, 2);
      expect(service.historyIsStale, isTrue);
      expect(service.errorCode, 'invalid_response');
      expect(
        service.attempts.map((attempt) => attempt.toJson()).toList(),
        before,
      );
      expect(await service.persistence.read(backend.ownerId!), hasLength(201));
      expect(service.busy, isFalse);
    },
  );
}
