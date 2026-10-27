// Opt-in negative REAL Marathon: 25-minute focus + 300-second break +
// 60-second unanswered presence window. No test clock or SQL-date edits.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/marathon_progress.dart';
import 'package:pomodoro/models/study_session.dart';
import 'package:pomodoro/screens/history_screen.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/widgets/stats/session_type_summary.dart';

import 'support/e2e.dart';

const _enabled = bool.fromEnvironment('E2E_REAL_MARATHON');

Future<void> _waitReal(
  WidgetTester tester,
  Future<bool> Function() condition, {
  required String phase,
  required Duration timeout,
}) async {
  final watch = Stopwatch()..start();
  var lastProgress = Duration.zero;
  while (watch.elapsed < timeout) {
    if (await condition()) {
      debugPrint(
        '[REAL_MARATHON_TIMEOUT] $phase after ${watch.elapsed.inSeconds}s',
      );
      return;
    }
    expect(tester.takeException(), isNull, reason: phase);
    if (watch.elapsed - lastProgress >= const Duration(seconds: 30)) {
      lastProgress = watch.elapsed;
      debugPrint(
        '[REAL_MARATHON_TIMEOUT] $phase elapsed=${watch.elapsed.inSeconds}s',
      );
    }
    await tester.pump(const Duration(seconds: 1));
  }
  fail('$phase did not finish within its real-time budget');
}

Future<Map<String, dynamic>> _profile(String owner) async => (await E2eHost.row(
  'select total_minutes,lifetime_points,coins from public.profiles '
  'where id=${sqlText(owner)}',
))!;

void main() {
  initE2e();
  testWidgets(
    'v · unanswered real Marathon presence ends plan and retains only first focus',
    (tester) async {
      ApiAccount? account;
      String? runId;
      final service = SupabaseService.instance;
      final entire = Stopwatch()..start();
      try {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        account = await openShellWithNewAccount(
          tester,
          'marathon-timeout-${DateTime.now().microsecondsSinceEpoch}',
          name: 'QA Maraton Süre Sonu',
        );
        final owner = account.id;
        await NotificationService.instance.setEnabled(false);
        expect(await _profile(owner), {
          'total_minutes': 0,
          'lifetime_points': 0,
          'coins': 0,
        });
        final config =
            await LocalApi.rpc('get_marathon_config', account) as Map;
        expect(config['break_seconds'], 300);
        expect(config['presence_seconds'], 60);
        await pumpUntilTrue(tester, () {
          final button = find.byKey(const ValueKey('marathon-open-planner'));
          return button.evaluate().isNotEmpty &&
              tester.widget<TextButton>(button).onPressed != null;
        }, reason: 'real Marathon planner enabled');
        await tapOn(
          tester,
          find.byKey(const ValueKey('marathon-open-planner')),
        );
        await pumpUntil(
          tester,
          find.byKey(const ValueKey('marathon-planner-dialog')),
        );
        await tapOn(tester, find.byKey(const ValueKey('marathon-count-2')));
        await tapOn(tester, find.byKey(const ValueKey('marathon-duration-25')));
        await tapOn(tester, find.byKey(const ValueKey('marathon-start')));
        await _waitReal(
          tester,
          () async {
            final current = await TimerPersistence.instance.load(owner);
            return current?.isRunning == true &&
                current?.marathon?.phase == MarathonPhase.focus;
          },
          phase: 'first focus UI start',
          timeout: const Duration(seconds: 30),
        );
        final first = (await TimerPersistence.instance.load(owner))!;
        runId = first.marathon!.marathonUuid;
        expect(first.totalSeconds, 1500);
        expect(first.durationMinutes, 25);
        expect(first.isQuickTest, isFalse);
        expect(first.recordAccelerated, isFalse);
        expect(first.marathon!.totalSessions, 2);
        expect(first.marathon!.breakSeconds, 300);
        expect(
          first.endsAt!.difference(first.startedAt),
          const Duration(minutes: 25),
        );

        await _waitReal(
          tester,
          () async {
            final current = await TimerPersistence.instance.load(owner);
            expect(current?.marathon?.stopRequested, isNot(true));
            return current?.marathon?.phase == MarathonPhase.breakTime;
          },
          phase: 'full first 1500-second focus',
          timeout: const Duration(minutes: 27),
        );
        expect(first.isFinishedAt(DateTime.now()), isTrue);
        final partialProfile = {
          'total_minutes': 25,
          'lifetime_points': 5,
          'coins': 20,
        };
        expect(await _profile(owner), partialProfile);
        final gate = (await E2eHost.row(
          'select break_started_at,break_ends_at,confirmation_deadline,confirmed_at,next_client_uuid '
          'from public.marathon_presence_gates where user_id=${sqlText(owner)} '
          'and marathon_uuid=${sqlText(runId)} and next_session_index=2',
        ))!;
        final breakStart = DateTime.parse(gate['break_started_at'] as String);
        final breakEnd = DateTime.parse(gate['break_ends_at'] as String);
        final deadline = DateTime.parse(
          gate['confirmation_deadline'] as String,
        );
        expect(breakEnd.difference(breakStart), const Duration(seconds: 300));
        expect(deadline.difference(breakEnd), const Duration(seconds: 60));
        expect(gate['confirmed_at'], isNull);
        expect(gate['next_client_uuid'], isNull);
        await E2eHost.screenshot(tester, 'e2e-marathon-timeout-break');

        await _waitReal(
          tester,
          () async {
            final current = await TimerPersistence.instance.load(owner);
            expect(current?.clientUuid, first.clientUuid);
            expect(current?.isRunning, isFalse);
            return current?.marathon?.phase == MarathonPhase.awaitingPresence;
          },
          phase: 'full 300-second break',
          timeout: const Duration(minutes: 6),
        );
        await pumpUntil(
          tester,
          find.byKey(const ValueKey('marathon-presence-confirm')),
        );
        final presence = (await TimerPersistence.instance.load(owner))!;
        expect(
          presence.marathon!.presenceRemainingAt(DateTime.now()),
          inInclusiveRange(40, 60),
        );
        await E2eHost.screenshot(tester, 'e2e-marathon-timeout-unanswered');
        // No tap: preserve and observe the original 60-second server window.
        await _waitReal(
          tester,
          () async {
            final current = await TimerPersistence.instance.load(owner);
            if (current == null) return true;
            expect(current.clientUuid, first.clientUuid);
            expect(current.isRunning, isFalse);
            expect(current.marathon!.completedSessions, 1);
            return false;
          },
          phase: 'unanswered 60-second presence window',
          timeout: const Duration(seconds: 90),
        );
        await pumpUntil(tester, find.text(trL10n.marathonPresenceExpired));
        expect(
          find.byKey(const ValueKey('marathon-presence-confirm')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('marathon-completed-dialog')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('marathon-open-planner')),
          findsOneWidget,
        );
        expect(
          entire.elapsed,
          greaterThanOrEqualTo(const Duration(minutes: 31)),
        );
        expect(await _profile(owner), partialProfile);
        await E2eHost.screenshot(tester, 'e2e-marathon-timeout-ended');
        await pumpFor(tester, const Duration(seconds: 3));
        expect(await TimerPersistence.instance.load(owner), isNull);
        final sessions = await E2eHost.rows(
          'select client_uuid::text,duration_minutes,base_points,bonus_points '
          'from public.study_sessions where user_id=${sqlText(owner)}',
        );
        expect(sessions, [
          {
            'client_uuid': first.clientUuid,
            'duration_minutes': 25,
            'base_points': 5,
            'bonus_points': 0,
          },
        ]);
        final finalGate = (await E2eHost.row(
          'select confirmed_at,next_client_uuid,clock_timestamp()>=confirmation_deadline as expired '
          'from public.marathon_presence_gates where user_id=${sqlText(owner)} '
          'and marathon_uuid=${sqlText(runId)} and next_session_index=2',
        ))!;
        expect(finalGate, {
          'confirmed_at': null,
          'next_client_uuid': null,
          'expired': true,
        });
        final run = (await E2eHost.row(
          'select target_sessions,duration_minutes,bonus_awarded '
          'from public.marathon_runs where user_id=${sqlText(owner)} and client_uuid=${sqlText(runId)}',
        ))!;
        expect(run, {
          'target_sessions': 2,
          'duration_minutes': 25,
          'bonus_awarded': 0,
        });
        // There is no fabricated server "abandoned" status for a Marathon:
        // one completed focus plus an expired, unconfirmed gate is the ledger.
        expect(await service.getPendingSessions(), isEmpty);
        await openTab(tester, 1);
        await tapOn(tester, find.text(tr('reports_tab_history')));
        await pumpUntil(tester, find.byType(HistoryScreen));
        await pumpUntilTrue(
          tester,
          () =>
              tester
                  .widget<HistoryScreen>(find.byType(HistoryScreen))
                  .sessions
                  .length ==
              1,
          reason: 'only completed first focus appears in reports',
        );
        final history = tester.widget<HistoryScreen>(
          find.byType(HistoryScreen),
        );
        expect(history.sessions.single.kind, StudySessionKind.marathon);
        expect(history.sessions.single.minutes, 25);
        expect(history.sessions.single.marathonCompletedAt, isNull);
        final summary = tester.widget<SessionTypeSummary>(
          find.byType(SessionTypeSummary),
        );
        expect(summary.counts.marathonFocusSessions, 1);
        expect(summary.counts.completedMarathons, 0);
        final league =
            await LocalApi.rpc('get_monthly_league_ranking', account, {
                  'p_kind': 'study',
                  'p_scope': 'segment',
                })
                as Map;
        final own = (league['rows'] as List).cast<Map>().singleWhere(
          (r) => r['id'] == owner,
        );
        expect(own['points'], 5);
        expect(await _profile(owner), partialProfile);
        expect(tester.takeException(), isNull);
        debugPrint(
          '[REAL_MARATHON_TIMEOUT] FINAL PASS owner=$owner run=$runId elapsed=${entire.elapsed.inSeconds}s records=1 minutes=25 points=5 coins=20 bonus=0 no-next-focus',
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        if (account != null && service.currentUser.value?.id == account.id) {
          await service.cancelStudySession();
          if (runId != null) {
            await TimerPersistence.instance.clearMarathon(
              account.id,
              marathonUuid: runId,
            );
          }
        }
        await NotificationService.instance.cancelSessionEndNotification();
        await NotificationService.instance.cancelMarathonBreakEnd();
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 40)),
  );
}
