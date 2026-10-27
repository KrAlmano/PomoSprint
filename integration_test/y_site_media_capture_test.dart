// Opt-in real UI footage for the website. The host starts simctl recordVideo
// before this test; only the two MEDIA_EVENT scene intervals are published.
// No timer speed, catalog, product layout or server dates are changed.
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/models/marathon_progress.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/widgets/hourglass_widget.dart';
import 'package:pomodoro/widgets/marathon_progress_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/e2e.dart';

const _enabled = bool.fromEnvironment('E2E_MEDIA_CAPTURE');
int _mediaPointer = 10000;

/// Send the actual pointer gesture through the binding's device path. The
/// LiveTestBinding test path paints large debugging crosshairs; the device
/// path reaches the same hit-test/gesture handling without that test overlay.
/// The native scene uses the real view's logical coordinate space.
@visibleForTesting
Future<void> mediaTapWithoutPointerOverlay(
  WidgetTester tester,
  Offset position,
) async {
  final binding = tester.binding;
  final previous = binding.shouldPropagateDevicePointerEvents;
  final pointer = ++_mediaPointer;
  final watch = Stopwatch()..start();
  var pointerDown = false;
  void send(PointerEvent event) => binding.handlePointerEventForSource(
    event,
    source: TestBindingEventSource.device,
  );
  binding.shouldPropagateDevicePointerEvents = true;
  try {
    pointerDown = true;
    send(
      PointerDownEvent(
        pointer: pointer,
        position: position,
        kind: PointerDeviceKind.touch,
        buttons: kPrimaryButton,
        timeStamp: watch.elapsed,
        viewId: tester.view.viewId,
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    send(
      PointerUpEvent(
        pointer: pointer,
        position: position,
        kind: PointerDeviceKind.touch,
        timeStamp: watch.elapsed,
        viewId: tester.view.viewId,
      ),
    );
    pointerDown = false;
  } finally {
    try {
      if (pointerDown) {
        send(
          PointerCancelEvent(
            pointer: pointer,
            position: position,
            kind: PointerDeviceKind.touch,
            viewId: tester.view.viewId,
          ),
        );
      }
    } finally {
      binding.shouldPropagateDevicePointerEvents = previous;
      watch.stop();
    }
  }
}

class _MediaEvents {
  String? _scene;

  void _emit(Map<String, Object> event) {
    debugPrint('[MEDIA_EVENT] ${jsonEncode(event)}');
  }

  Future<void> begin(WidgetTester tester, String scene) async {
    expect(_scene, isNull);
    expect({'timer', 'marathon'}, contains(scene));
    _scene = scene;
    _emit({
      'kind': 'scene_start',
      'scene': scene,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    await pumpFor(tester, const Duration(seconds: 2));
  }

  void end() {
    expect(_scene, isNotNull);
    _emit({
      'kind': 'scene_end',
      'scene': _scene!,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    _scene = null;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    expect(
      _scene,
      isNotNull,
      reason: 'Every real tap belongs to an open scene',
    );
    expect(finder, findsOneWidget);
    if (finder.hitTestable().evaluate().isEmpty) {
      await tester.ensureVisible(finder);
    }
    await pumpUntilTrue(
      tester,
      () => finder.hitTestable().evaluate().length == 1,
      reason: 'Media target is actually visible and hit-testable',
    );
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final center = tester.getCenter(finder);
    expect(size.height, greaterThan(size.width));
    expect(center.dx, inInclusiveRange(0, size.width));
    expect(center.dy, inInclusiveRange(0, size.height));
    // Timestamp immediately precedes the actual Flutter pointer dispatch.
    // These are logical screen coordinates, not a drawn/fabricated cursor.
    _emit({
      'kind': 'tap',
      'scene': _scene!,
      'at': DateTime.now().toUtc().toIso8601String(),
      'x': center.dx,
      'y': center.dy,
      'width': size.width,
      'height': size.height,
    });
    await mediaTapWithoutPointerOverlay(tester, center);
    await pumpFor(tester, const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  }
}

Future<ActiveTimerSession> _waitTimer(
  WidgetTester tester,
  String owner,
  bool Function(ActiveTimerSession) accepts,
) async {
  final until = DateTime.now().add(const Duration(seconds: 25));
  while (DateTime.now().isBefore(until)) {
    final timer = await TimerPersistence.instance.load(owner);
    if (timer != null && accepts(timer)) return timer;
    await pumpFor(tester, const Duration(milliseconds: 100));
  }
  fail('Expected real persisted timer state did not arrive');
}

Future<void> _assertReservation(String owner, ActiveTimerSession timer) async {
  final row = await E2eHost.row(
    'select active_session_ends_at from public.profiles '
    'where id=${sqlText(owner)}',
  );
  expect(row, isNotNull);
  expect(row!['active_session_ends_at'], isNotNull);
  final end = DateTime.parse(row['active_session_ends_at'] as String);
  expect(end.difference(timer.endsAt!).inSeconds.abs(), lessThanOrEqualTo(5));
}

Future<void> _assertIdleWithoutRewards(
  WidgetTester tester,
  String owner,
) async {
  final until = DateTime.now().add(const Duration(seconds: 20));
  Map<String, dynamic>? row;
  while (DateTime.now().isBefore(until)) {
    row = await E2eHost.row(
      'select active_session_ends_at,total_minutes,lifetime_points,coins '
      'from public.profiles where id=${sqlText(owner)}',
    );
    if (await TimerPersistence.instance.load(owner) == null &&
        row?['active_session_ends_at'] == null) {
      break;
    }
    await pumpFor(tester, const Duration(milliseconds: 100));
  }
  expect(await TimerPersistence.instance.load(owner), isNull);
  expect(row, isNotNull);
  expect(row!['active_session_ends_at'], isNull);
  expect(row['total_minutes'], 0);
  expect(row['lifetime_points'], 0);
  expect(row['coins'], 0);
  expect(await SupabaseService.instance.getPendingSessions(), isEmpty);
  expect(
    await E2eHost.rows(
      'select id from public.study_sessions where user_id=${sqlText(owner)}',
    ),
    isEmpty,
  );
  expect(shellStats(tester), (points: 0, coins: 0));
  expect(tester.takeException(), isNull);
}

Future<void> _cancel(
  WidgetTester tester,
  _MediaEvents events, {
  required bool marathon,
}) async {
  await events.tap(
    tester,
    marathon
        ? find.byKey(const ValueKey('marathon-stop'))
        : find.descendant(
            of: find.byType(TimerScreen),
            matching: find.text(trL10n.timerResetBtn),
          ),
  );
  final dialog = find.byType(AlertDialog);
  await pumpUntil(tester, dialog);
  expect(
    find.text(
      marathon
          ? trL10n.marathonStopConfirmTitle
          : trL10n.timerResetConfirmTitle,
    ),
    findsOneWidget,
  );
  await events.tap(
    tester,
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(
        TextButton,
        marathon
            ? trL10n.marathonStopConfirmAction
            : trL10n.timerResetConfirmAction,
      ),
    ),
  );
  await pumpUntilGone(tester, dialog);
}

void main() {
  final binding = _enabled
      ? initE2e()
      : IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  testWidgets(
    'y · two portrait website clips with real tap coordinates and no completed focus',
    (tester) async {
      expect(E2eHost.available, isTrue);
      expect(kQuickTimer, isFalse);
      expect(timerDurationSeconds(25), 1500);
      expect(timerDurationSeconds(50), 3000);
      final service = SupabaseService.instance;
      ApiAccount? account;
      final events = _MediaEvents();
      try {
        // Never replace an unfinished real-duration probe with media setup.
        final prefs = await SharedPreferences.getInstance();
        for (final key in prefs.getKeys().where(
          (key) => key.startsWith('e2e_real_duration_probe_'),
        )) {
          final marker = jsonDecode(prefs.getString(key)!) as Map;
          expect(
            marker['completion_verified'],
            isTrue,
            reason: 'Finish the real-duration probe before media capture',
          );
        }
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        await launchApp(tester);
        await waitPastSplash(tester);
        final priorOwner = service.currentUser.value?.id;
        if (priorOwner != null) {
          expect(
            await TimerPersistence.instance.load(priorOwner),
            isNull,
            reason: 'Do not replace another account’s active timer',
          );
          await service.signOutFully();
          await pumpFor(tester, const Duration(milliseconds: 300));
        }
        account = await signUpViaApi(
          e2eEmail('site-media-${DateTime.now().microsecondsSinceEpoch}'),
          'PomoSprint',
        );
        await completeOnboardingViaApi(account, showInSocialFeed: false);
        final user = await service.loginUser(account.email, kE2ePassword);
        expect(user, isNotNull);
        await service.setCurrentUser(user);
        await pumpUntil(tester, find.byType(MainNavigationShell));
        await NotificationService.instance.setEnabled(false);
        await pumpUntilGone(tester, find.byType(SnackBar));
        await _assertIdleWithoutRewards(tester, account.id);

        final primary = find.byKey(const ValueKey('timer-start-pause'));
        final hourglass = find.byType(HourglassWidget);
        await pumpUntilTrue(tester, () {
          final planner = find.byKey(const ValueKey('marathon-open-planner'));
          return planner.evaluate().length == 1 &&
              tester.widget<TextButton>(planner).onPressed != null;
        }, reason: 'Real server-enabled Marathon is ready');
        expect(primary.hitTestable(), findsOneWidget);
        expect(
          tester.view.physicalSize.height,
          greaterThan(tester.view.physicalSize.width),
        );

        await events.begin(tester, 'timer');
        await events.tap(
          tester,
          find.byKey(const ValueKey('timer-duration-50')),
        );
        expect(find.text('50:00'), findsOneWidget);
        await events.tap(
          tester,
          find.byKey(const ValueKey('timer-duration-25')),
        );
        expect(find.text('25:00'), findsOneWidget);
        final categories = find.descendant(
          of: find.byType(TimerScreen),
          matching: find.byType(FilterChip),
        );
        expect(categories.evaluate().length, greaterThanOrEqualTo(2));
        final selectedLabel =
            (tester.widget<FilterChip>(categories.at(1)).label as Text).data;
        await events.tap(tester, categories.at(1));
        expect(tester.widget<FilterChip>(categories.at(1)).selected, isTrue);
        await events.tap(tester, primary);
        final first = await _waitTimer(tester, account.id, (s) => s.isRunning);
        expect(first.totalSeconds, 1500);
        expect(first.isQuickTest, isFalse);
        expect(first.recordAccelerated, isFalse);
        expect(first.marathon, isNull);
        expect(first.categoryName, selectedLabel);
        expect(
          first.endsAt!.difference(first.startedAt),
          const Duration(minutes: 25),
        );
        expect(tester.widget<HourglassWidget>(hourglass).isRunning, isTrue);
        await _assertReservation(account.id, first);
        await pumpFor(tester, const Duration(seconds: 2));
        await events.tap(tester, primary);
        final paused = await _waitTimer(
          tester,
          account.id,
          (s) => !s.isRunning,
        );
        expect(paused.clientUuid, first.clientUuid);
        expect(paused.pauseUsedCount, 1);
        expect(tester.widget<HourglassWidget>(hourglass).isRunning, isFalse);
        // The real pause notice temporarily covers the primary button.
        // Wait as a user would; do not let ensureVisible scroll the controls
        // underneath that overlay merely to make this recording tap succeed.
        await pumpUntilGone(tester, find.byType(SnackBar));
        expect(
          primary.hitTestable(),
          findsOneWidget,
          reason: 'Resume is reachable without auto-scrolling',
        );
        await events.tap(tester, primary);
        final resumed = await _waitTimer(
          tester,
          account.id,
          (s) => s.isRunning,
        );
        expect(resumed.clientUuid, first.clientUuid);
        expect(resumed.pauseUsedCount, 1);
        expect(resumed.totalSeconds, 1500);
        expect(tester.widget<HourglassWidget>(hourglass).isRunning, isTrue);
        await pumpFor(tester, const Duration(seconds: 2));
        await _cancel(tester, events, marathon: false);
        await pumpFor(tester, const Duration(seconds: 1));
        events.end();
        await _assertIdleWithoutRewards(tester, account.id);
        await pumpUntilGone(tester, find.byType(SnackBar));

        await events.begin(tester, 'marathon');
        await events.tap(
          tester,
          find.byKey(const ValueKey('marathon-open-planner')),
        );
        final planner = find.byKey(const ValueKey('marathon-planner-dialog'));
        await pumpUntil(tester, planner);
        final preview = find.descendant(
          of: planner,
          matching: find.byType(MarathonProgressCard),
        );
        for (final count in [2, 3, 4]) {
          await events.tap(
            tester,
            find.byKey(ValueKey('marathon-count-$count')),
          );
          expect(
            tester.widget<MarathonProgressCard>(preview).totalSessions,
            count,
          );
        }
        for (final minutes in [50, 25]) {
          await events.tap(
            tester,
            find.byKey(ValueKey('marathon-duration-$minutes')),
          );
          expect(
            tester.widget<MarathonProgressCard>(preview).durationMinutes,
            minutes,
          );
        }
        await events.tap(tester, find.byKey(const ValueKey('marathon-start')));
        final marathon = await _waitTimer(
          tester,
          account.id,
          (s) => s.isRunning && s.marathon != null,
        );
        expect(marathon.totalSeconds, 1500);
        expect(marathon.isQuickTest, isFalse);
        expect(marathon.recordAccelerated, isFalse);
        expect(marathon.marathon!.phase, MarathonPhase.focus);
        expect(marathon.marathon!.totalSessions, 4);
        expect(marathon.marathon!.completedSessions, 0);
        expect(marathon.marathon!.breakSeconds, 300);
        expect(
          marathon.endsAt!.difference(marathon.startedAt),
          const Duration(minutes: 25),
        );
        await _assertReservation(account.id, marathon);
        await pumpFor(tester, const Duration(seconds: 3));
        await _cancel(tester, events, marathon: true);
        await pumpFor(tester, const Duration(seconds: 1));
        events.end();
        await _assertIdleWithoutRewards(tester, account.id);
        expect(
          await E2eHost.rows(
            'select client_uuid from public.marathon_runs '
            'where user_id=${sqlText(account.id)}',
          ),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      } finally {
        // Even a failed recording must not leave this media account focusing.
        // No real probe/other owner is touched; successful scenes cancelled via UI.
        if (account != null && service.currentUser.value?.id == account.id) {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await service.cancelStudySession();
          final pending = await TimerPersistence.instance.load(account.id);
          if (pending != null && !pending.isFinishedAt(DateTime.now())) {
            await TimerPersistence.instance.clear(
              account.id,
              onlyClientUuid: pending.clientUuid,
            );
          }
          await NotificationService.instance.cancelSessionEndNotification();
          await NotificationService.instance.cancelMarathonBreakEnd();
          await NotificationService.instance.cancelOngoingTimer();
        }
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
