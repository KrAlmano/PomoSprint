// Opt-in native 2 x 25 or 2 x 50 minute Marathon. Every deadline is the unmodified
// production deadline; no fixture, clock jump, quick mode or shortened break.
// --dart-define=E2E_REAL_MARATHON=true (local Supabase / Mailpit only).
// --dart-define=E2E_MARATHON_MINUTES=25|50 (default 25; real 55/105-minute run).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/marathon_progress.dart';
import 'package:pomodoro/models/study_session.dart';
import 'package:pomodoro/screens/history_screen.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/widgets/hourglass_widget.dart';
import 'package:pomodoro/widgets/stats/session_type_summary.dart';

import 'support/e2e.dart';

const _enabled = bool.fromEnvironment('E2E_REAL_MARATHON');
const _minutesArgument = String.fromEnvironment(
  'E2E_MARATHON_MINUTES',
  defaultValue: '25',
);
const _minutes = _minutesArgument == '50' ? 50 : 25;
const _focusSeconds = _minutes * 60;
const _basePoints = _minutes == 50 ? 12 : 5;
const _bonusPoints = _minutes == 50 ? 4 : 2;
const _totalPoints = _basePoints * 2 + _bonusPoints;
const _totalMinutes = _minutes * 2;

Future<void> _untilReal(
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
        '[REAL_MARATHON] $phase complete after ${watch.elapsed.inSeconds}s',
      );
      return;
    }
    expect(tester.takeException(), isNull, reason: phase);
    if (watch.elapsed - lastProgress >= const Duration(seconds: 30)) {
      lastProgress = watch.elapsed;
      debugPrint('[REAL_MARATHON] $phase elapsed=${watch.elapsed.inSeconds}s');
    }
    // Integration binding pumps in real time. The Stopwatch is an independent
    // guard against mistaking a synthetic pump duration for elapsed wall time.
    await tester.pump(const Duration(seconds: 1));
  }
  fail('$phase did not complete within ${timeout.inMinutes} real minutes');
}

Future<void> _rotate(WidgetTester tester, DeviceOrientation orientation) async {
  await SystemChrome.setPreferredOrientations([orientation]);
  await pumpUntilTrue(tester, () {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    return orientation == DeviceOrientation.portraitUp
        ? size.height > size.width
        : size.width > size.height;
  }, reason: 'native Marathon orientation');
  await pumpFor(tester, const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull);
}

Future<Map<String, dynamic>> _profile(String owner) async => (await E2eHost.row(
  'select total_minutes,lifetime_points,coins from public.profiles '
  'where id=${sqlText(owner)}',
))!;

void main() {
  initE2e();
  testWidgets(
    's · real $_minutes + 5 + confirmation + $_minutes minute Marathon completes once',
    (tester) async {
      expect(
        const {'25', '50'}.contains(_minutesArgument),
        isTrue,
        reason: 'E2E_MARATHON_MINUTES must be exactly 25 or 50',
      );
      ApiAccount? account;
      String? runId;
      final service = SupabaseService.instance;
      final wholeRun = Stopwatch()..start();
      try {
        await _rotate(tester, DeviceOrientation.portraitUp);
        account = await openShellWithNewAccount(
          tester,
          'real-marathon-${DateTime.now().microsecondsSinceEpoch}',
          name: 'QA Gerçek Maraton',
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
        expect(config['available'], isTrue);
        expect(config['break_seconds'], 300);
        expect(config['presence_seconds'], 60);
        expect(
          (config['bonuses'] as Map)[_minutes.toString()]['2'],
          _bonusPoints,
        );
        await pumpUntilTrue(tester, () {
          final finder = find.byKey(const ValueKey('marathon-open-planner'));
          return finder.evaluate().isNotEmpty &&
              tester.widget<TextButton>(finder).onPressed != null;
        }, reason: 'server-enabled Marathon planner');
        await tapOn(
          tester,
          find.byKey(const ValueKey('marathon-open-planner')),
        );
        await pumpUntil(
          tester,
          find.byKey(const ValueKey('marathon-planner-dialog')),
        );
        await tapOn(tester, find.byKey(const ValueKey('marathon-count-2')));
        await tapOn(
          tester,
          find.byKey(const ValueKey('marathon-duration-$_minutes')),
        );
        await tapOn(tester, find.byKey(const ValueKey('marathon-start')));
        await _untilReal(
          tester,
          () async {
            final state = await TimerPersistence.instance.load(owner);
            return state?.isRunning == true &&
                state?.marathon?.phase == MarathonPhase.focus;
          },
          phase: 'first UI start',
          timeout: const Duration(seconds: 30),
        );
        final first = (await TimerPersistence.instance.load(owner))!;
        runId = first.marathon!.marathonUuid;
        expect(first.durationMinutes, _minutes);
        expect(first.totalSeconds, _focusSeconds);
        expect(first.isQuickTest, isFalse);
        expect(first.recordAccelerated, isFalse);
        expect(first.marathon!.totalSessions, 2);
        expect(first.marathon!.breakSeconds, 300);
        expect(first.marathon!.completedSessions, 0);
        expect(
          first.endsAt!.difference(first.startedAt),
          const Duration(minutes: _minutes),
        );
        await E2eHost.screenshot(tester, 'e2e-marathon-real-first-focus');
        await _rotate(tester, DeviceOrientation.landscapeLeft);
        expect(
          find.byKey(const ValueKey('timer-landscape-clock')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('timer-start-pause')), findsOneWidget);
        expect(
          tester
              .widget<HourglassWidget>(find.byType(HourglassWidget))
              .isRunning,
          isTrue,
        );
        expect(
          (await TimerPersistence.instance.load(owner))!.clientUuid,
          first.clientUuid,
        );
        await E2eHost.screenshot(tester, 'e2e-marathon-real-landscape');
        await _rotate(tester, DeviceOrientation.portraitUp);

        await _untilReal(
          tester,
          () async {
            final state = await TimerPersistence.instance.load(owner);
            expect(state?.marathon?.stopRequested, isNot(true));
            return state?.marathon?.phase == MarathonPhase.breakTime;
          },
          phase: 'first full $_focusSeconds second focus',
          timeout: const Duration(minutes: _minutes + 2),
        );
        expect(first.isFinishedAt(DateTime.now()), isTrue);
        final resting = (await TimerPersistence.instance.load(owner))!;
        expect(resting.marathon!.completedSessions, 1);
        expect(resting.isRunning, isFalse);
        final one = await E2eHost.rows(
          'select client_uuid::text,duration_minutes,base_points,bonus_points '
          'from public.study_sessions where user_id=${sqlText(owner)}',
        );
        expect(one, [
          {
            'client_uuid': first.clientUuid,
            'duration_minutes': _minutes,
            'base_points': _basePoints,
            'bonus_points': 0,
          },
        ]);
        expect(await _profile(owner), {
          'total_minutes': _minutes,
          'lifetime_points': _basePoints,
          'coins': 20,
        });
        final gate = (await E2eHost.row(
          'select break_started_at,break_ends_at,confirmation_deadline,confirmed_at '
          'from public.marathon_presence_gates where user_id=${sqlText(owner)} '
          'and marathon_uuid=${sqlText(runId)} and next_session_index=2',
        ))!;
        final breakStart = DateTime.parse(gate['break_started_at'] as String);
        final breakEnd = DateTime.parse(gate['break_ends_at'] as String);
        final presenceEnd = DateTime.parse(
          gate['confirmation_deadline'] as String,
        );
        expect(breakEnd.difference(breakStart), const Duration(seconds: 300));
        expect(presenceEnd.difference(breakEnd), const Duration(seconds: 60));
        expect(gate['confirmed_at'], isNull);
        await E2eHost.screenshot(tester, 'e2e-marathon-real-break');

        await _untilReal(
          tester,
          () async {
            final state = await TimerPersistence.instance.load(owner);
            expect(state?.marathon?.stopRequested, isNot(true));
            expect(
              state?.marathon?.phase,
              isNot(MarathonPhase.focus),
              reason: 'second focus cannot start before explicit presence',
            );
            return state?.marathon?.phase == MarathonPhase.awaitingPresence;
          },
          phase: 'full 300 second break',
          timeout: const Duration(minutes: 6),
        );
        final waiting = (await TimerPersistence.instance.load(owner))!;
        expect(
          waiting.marathon!.presenceDeadline!.difference(
            waiting.marathon!.breakEndsAt!,
          ),
          const Duration(seconds: 60),
        );
        expect(
          waiting.marathon!.presenceRemainingAt(DateTime.now()),
          inInclusiveRange(40, 60),
        );
        await pumpUntil(
          tester,
          find.byKey(const ValueKey('marathon-presence-confirm')),
        );
        // A short real delay proves the presence window stays open, without
        // deliberately exhausting it or extending the server deadline.
        await pumpFor(tester, const Duration(seconds: 2));
        await tapOn(
          tester,
          find.byKey(const ValueKey('marathon-presence-confirm')),
        );
        await _untilReal(
          tester,
          () async {
            final state = await TimerPersistence.instance.load(owner);
            return state?.marathon?.phase == MarathonPhase.focus &&
                state?.marathon?.completedSessions == 1 &&
                state?.isRunning == true;
          },
          phase: 'explicit presence authorizes second focus',
          timeout: const Duration(seconds: 30),
        );
        final second = (await TimerPersistence.instance.load(owner))!;
        expect(second.clientUuid, isNot(first.clientUuid));
        expect(second.marathon!.marathonUuid, runId);
        expect(second.categoryId, first.categoryId);
        expect(second.totalSeconds, _focusSeconds);
        expect(second.durationMinutes, _minutes);
        expect(second.isQuickTest, isFalse);
        expect(second.recordAccelerated, isFalse);
        final confirmed = (await E2eHost.row(
          'select confirmed_at,next_client_uuid::text from public.marathon_presence_gates '
          'where user_id=${sqlText(owner)} and marathon_uuid=${sqlText(runId)} and next_session_index=2',
        ))!;
        final confirmedAt = DateTime.parse(confirmed['confirmed_at'] as String);
        expect(confirmedAt.isBefore(breakEnd), isFalse);
        expect(confirmedAt.isBefore(presenceEnd), isTrue);
        expect(confirmed['next_client_uuid'], second.clientUuid);
        expect(await _profile(owner), {
          'total_minutes': _minutes,
          'lifetime_points': _basePoints,
          'coins': 20,
        });

        await _untilReal(
          tester,
          () async => find
              .byKey(const ValueKey('marathon-completed-dialog'))
              .evaluate()
              .isNotEmpty,
          phase: 'second full $_focusSeconds second focus',
          timeout: const Duration(minutes: _minutes + 2),
        );
        expect(second.isFinishedAt(DateTime.now()), isTrue);
        expect(
          wholeRun.elapsed,
          greaterThanOrEqualTo(const Duration(minutes: _totalMinutes + 5)),
        );
        expect(
          find.text(trL10n.marathonCompletedBody(2, _totalMinutes)),
          findsOneWidget,
        );
        expect(
          find.text(trL10n.marathonBonusPoints(_bonusPoints)),
          findsOneWidget,
        );
        final two = await E2eHost.rows(
          'select client_uuid::text,duration_minutes,base_points,bonus_points '
          'from public.study_sessions where user_id=${sqlText(owner)} order by started_at',
        );
        expect(two, [
          {
            'client_uuid': first.clientUuid,
            'duration_minutes': _minutes,
            'base_points': _basePoints,
            'bonus_points': 0,
          },
          {
            'client_uuid': second.clientUuid,
            'duration_minutes': _minutes,
            'base_points': _basePoints,
            'bonus_points': _bonusPoints,
          },
        ]);
        final finalProfile = {
          'total_minutes': _totalMinutes,
          'lifetime_points': _totalPoints,
          'coins': 40,
        };
        expect(await _profile(owner), finalProfile);
        expect(await TimerPersistence.instance.load(owner), isNull);
        final run = (await E2eHost.row(
          'select target_sessions,duration_minutes,bonus_awarded,is_invalid from public.marathon_runs '
          'where user_id=${sqlText(owner)} and client_uuid=${sqlText(runId)}',
        ))!;
        expect(run, {
          'target_sessions': 2,
          'duration_minutes': _minutes,
          'bonus_awarded': _bonusPoints,
          'is_invalid': false,
        });
        final duplicate =
            await LocalApi.rpc('complete_marathon_study_session', account, {
                  'p_client_uuid': second.clientUuid,
                  'p_category_id': second.categoryId,
                  'p_duration_minutes': _minutes,
                  'p_was_paused': false,
                  'p_is_verified': 0,
                  'p_started_at': second.startedAt.toUtc().toIso8601String(),
                  'p_marathon_uuid': runId,
                  'p_target_sessions': 2,
                  'p_session_index': 2,
                })
                as Map;
        expect(duplicate['duplicate'], isTrue);
        expect(await _profile(owner), finalProfile);
        expect(
          (await E2eHost.rows(
            'select client_uuid from public.study_sessions where user_id=${sqlText(owner)}',
          )),
          hasLength(2),
        );
        await E2eHost.screenshot(tester, 'e2e-marathon-real-completed');
        await tapOn(
          tester,
          find.byKey(const ValueKey('marathon-completed-close')),
        );
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
              2,
          reason: 'two real Marathon focus records in reports',
        );
        final history = tester.widget<HistoryScreen>(
          find.byType(HistoryScreen),
        );
        expect(
          history.sessions.every((s) => s.kind == StudySessionKind.marathon),
          isTrue,
        );
        expect(
          history.sessions.fold<int>(0, (total, s) => total + s.minutes),
          _totalMinutes,
        );
        final summary = tester.widget<SessionTypeSummary>(
          find.byType(SessionTypeSummary),
        );
        expect(summary.counts.marathonFocusSessions, 2);
        expect(summary.counts.completedMarathons, 1);
        expect(summary.counts.normalSessions, 0);
        expect(summary.counts.completedExams, 0);
        final league =
            await LocalApi.rpc('get_monthly_league_ranking', account, {
                  'p_kind': 'study',
                  'p_scope': 'segment',
                })
                as Map;
        final ownRank = (league['rows'] as List).cast<Map>().singleWhere(
          (r) => r['id'] == owner,
        );
        expect(ownRank['points'], _totalPoints);
        await openTab(tester, 2);
        await pumpFor(tester, const Duration(seconds: 2));
        await E2eHost.screenshot(tester, 'e2e-marathon-real-league');
        expect(tester.takeException(), isNull);
        debugPrint(
          '[REAL_MARATHON] FINAL PASS owner=$owner run=$runId elapsed=${wholeRun.elapsed.inSeconds}s records=2 minutes=$_totalMinutes points=$_totalPoints coins=40 bonus=$_bonusPoints',
        );
      } finally {
        // On a failure, stop only this test's reservation. Completed records
        // stay intact for diagnosis. No other account or simulator is touched.
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
    timeout: const Timeout(Duration(minutes: _minutes == 50 ? 125 : 70)),
  );
}
