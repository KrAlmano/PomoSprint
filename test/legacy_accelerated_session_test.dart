import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/services/server_clock.dart';
import 'package:pomodoro/services/session_queue.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _categoryId = '0f8fad5b-d9cb-469f-a165-70867728950e';
const _planId = 'cf091f18-1d45-4e82-9377-d55b92753c2c';

class _Backend implements SessionQueueBackend {
  @override
  String? signedInUserId = 'owner';

  final sent = <PendingSession>[];
  int categoryRequests = 0;
  int categoryCreations = 0;

  @override
  Future<Object?> completeSession(
    PendingSession session, {
    required String categoryId,
    required DateTime startedAtForServer,
  }) async {
    sent.add(session);
    return {'total_points': session.minutes == 25 ? 5 : 12};
  }

  @override
  Future<List<CategoryRef>> fetchCategories() async {
    categoryRequests++;
    return [(id: _categoryId, name: 'Matematik', isArchived: false)];
  }

  @override
  Future<void> createDefaultCategories() async => categoryCreations++;
}

PendingSession _entry(
  String uuid, {
  bool accelerated = true,
  bool marathon = false,
  int minutes = 25,
  String? categoryId = _categoryId,
}) => PendingSession(
  clientUuid: uuid,
  categoryId: categoryId,
  categoryName: 'Matematik',
  minutes: minutes,
  recordAccelerated: accelerated,
  marathonUuid: marathon ? _planId : null,
  marathonTargetSessions: marathon ? 2 : null,
  marathonSessionIndex: marathon ? 1 : null,
  wasPaused: false,
  foregroundSeconds: accelerated ? 5 : minutes * 60,
  startedAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
  queuedAt: DateTime.now().toUtc(),
  clockOffsetMs: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = SupabaseService.instance;

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    service.currentUser.value = null;
    service.pendingSessionCount.value = 0;
  });

  test('normal timer defaults ignore old QUICK_TIMER build defines', () {
    expect(kQuickTimer, isFalse);
    expect(timerDurationSeconds(25), 1500);
    expect(timerDurationSeconds(50), 3000);
    // Explicit widget/unit simulation remains available without recording.
    expect(timerDurationSeconds(25, quick: true), 5);
    expect(timerDurationSeconds(50, quick: true), 10);
  });

  test(
    'legacy QA flag survives disk/pause and blocks even full-duration data',
    () {
      final now = DateTime.utc(2026, 10, 9, 12);
      for (final totalSeconds in [5, 1500]) {
        final session =
            ActiveTimerSession.start(
                  clientUuid: 'legacy-$totalSeconds',
                  categoryId: _categoryId,
                  categoryName: 'Matematik',
                  durationMinutes: 25,
                  totalSeconds: totalSeconds,
                  now: now,
                  recordAccelerated: true,
                )
                .pauseAt(now.add(const Duration(seconds: 1)))
                .resumeAt(now.add(const Duration(seconds: 2)));
        final restored = ActiveTimerSession.fromJson(session.toJson())!;
        expect(restored.recordAccelerated, isTrue);
        expect(restored.isQuickTest, isTrue);
        expect(restored.totalSeconds, totalSeconds);
      }
    },
  );

  for (final signedIn in [null, 'owner', 'another-owner']) {
    test(
      'legacy offline/unmapped outbox rejects before requests ($signedIn)',
      () async {
        final legacy = _entry('legacy', categoryId: null, marathon: true);
        SharedPreferences.setMockInitialValues({
          SessionQueue.queueKey('owner'): jsonEncode([legacy.toJson()]),
        });
        final backend = _Backend()..signedInUserId = signedIn;
        final queue = SessionQueue(backend: backend, clock: ServerClock());

        final report = await queue.sync('owner');

        expect(report.rejected, 1);
        expect(report.sent, 0);
        expect(report.remaining, 0);
        expect(report.stopReason, isNull);
        expect(backend.sent, isEmpty);
        expect(backend.categoryRequests, 0);
        expect(backend.categoryCreations, 0);
        expect(
          (await queue.rejectedSessions('owner')).single.reasonCode,
          SessionReason.invalidData,
        );
        expect(await queue.takeRejectedNoticeCount('owner'), 1);
        expect((await queue.sync('owner')).rejected, 0);
        expect(await queue.takeRejectedNoticeCount('owner'), 0);
      },
    );
  }

  test(
    'mixed old QA and normal 25/50 sessions send only real entries',
    () async {
      final accelerated = [
        _entry('old-single', categoryId: null),
        _entry('old-marathon', marathon: true, minutes: 50, categoryId: null),
      ];
      SharedPreferences.setMockInitialValues({
        SessionQueue.queueKey('owner'): jsonEncode([
          for (final entry in accelerated) entry.toJson(),
          _entry('real-25', accelerated: false).toJson(),
          _entry('real-50', accelerated: false, minutes: 50).toJson(),
        ]),
      });
      final backend = _Backend();
      final accepted = <String>[];
      final queue = SessionQueue(
        backend: backend,
        clock: ServerClock(),
        onAccepted: (uid, session, result) => accepted.add(session.clientUuid),
      );

      final report = await queue.sync('owner');

      expect(report.sent, 2);
      expect(report.rejected, 2);
      expect(report.remaining, 0);
      expect(backend.sent.map((e) => e.clientUuid), ['real-25', 'real-50']);
      expect(accepted, ['real-25', 'real-50']);
      expect(backend.categoryRequests, 0);
      expect(backend.categoryCreations, 0);
      expect((await queue.rejectedSessions('owner')).map((e) => e.clientUuid), [
        'old-single',
        'old-marathon',
      ]);
    },
  );

  test(
    'new legacy submission permanently rejects without an offline retry',
    () async {
      final backend = _Backend()..signedInUserId = null;
      final queue = SessionQueue(backend: backend, clock: ServerClock());

      final result = await queue.submit('owner', _entry('obsolete'));

      expect(result, isA<SessionSubmitRejected>());
      expect(
        (result as SessionSubmitRejected).reasonCode,
        SessionReason.invalidData,
      );
      expect(await queue.pendingCount('owner'), 0);
      expect(
        (await queue.rejectedSessions('owner')).single.clientUuid,
        'obsolete',
      );
      expect(await queue.takeRejectedNoticeCount('owner'), 0);
      expect(backend.sent, isEmpty);
      expect(backend.categoryRequests, 0);
    },
  );

  test(
    'service rejects QA for signed-out, legacy-email and cached UID owners',
    () async {
      for (final user in <UserModel?>[
        null,
        UserModel(name: 'Legacy', email: 'legacy@example.com'),
        UserModel(id: 'owner', name: 'Owner', email: 'owner@example.com'),
      ]) {
        service.currentUser.value = user;
        final result = await service.submitCompletedSession(
          clientUuid: 'obsolete',
          categoryId: _categoryId,
          categoryName: 'Matematik',
          durationMinutes: 25,
          recordAccelerated: true,
          wasPaused: false,
          foregroundSeconds: 5,
          startedAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        expect(result, isA<SessionSubmitRejected>());
        expect(
          (result as SessionSubmitRejected).reasonCode,
          SessionReason.invalidData,
        );
        expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      }
    },
  );

  test(
    'offline service adopts legacy-email QA then rejects only old test data',
    () async {
      service.currentUser.value = UserModel(
        id: 'owner',
        name: 'Owner',
        email: 'owner@example.com',
      );
      SharedPreferences.setMockInitialValues({
        SessionQueue.legacyQueueKey('owner@example.com'): jsonEncode([
          _entry('old-email', marathon: true, categoryId: null).toJson(),
          _entry('real-email', accelerated: false).toJson(),
        ]),
      });

      final result = await service.syncPendingSessions();

      expect(result, (remaining: 1, retryable: false));
      expect(
        (await service.getPendingSessions()).single.clientUuid,
        'real-email',
      );
      expect(
        (await service.getRejectedSessions()).single.clientUuid,
        'old-email',
      );
      expect(
        (await service.getRejectedSessions()).single.reasonCode,
        SessionReason.invalidData,
      );
      expect(await service.takeRejectedSessionNoticeCount(), 1);
    },
  );
}
