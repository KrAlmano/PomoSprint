// Native regression for a test-helper scroll, not a product layout change.
// The real 50-minute session is paused/resumed and cancelled without saving.
// Use a separate local E2eHost/device; never attach to the overnight actors.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/widgets/hourglass_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/e2e.dart';

void main() {
  final binding = initE2e();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  testWidgets(
    't · visible timer taps preserve category viewport through real pause/resume',
    (tester) async {
      expect(kQuickTimer, isFalse);
      expect(timerDurationSeconds(25), 1500);
      expect(timerDurationSeconds(50), 3000);
      expect(E2eHost.available, isTrue);
      final service = SupabaseService.instance;
      final observations = <Map<String, Object?>>[];
      ApiAccount? account;
      String? cancelledUuid;
      double? initialOffset;

      final primary = find.byKey(const ValueKey('timer-start-pause'));
      final categories = find.descendant(
        of: find.byType(TimerScreen),
        matching: find.byType(FilterChip),
      );

      Future<void> observe(String phase) async {
        await tester.pump();
        expect(primary, findsOneWidget);
        expect(primary.hitTestable(), findsOneWidget, reason: phase);
        expect(categories, findsWidgets);
        final selected = categories
            .evaluate()
            .where((element) => (element.widget as FilterChip).selected)
            .toList();
        expect(selected, hasLength(1), reason: '$phase selected category');
        final chip = find.byElementPredicate(
          (element) => identical(element, selected.single),
        );
        expect(chip.hitTestable(), findsOneWidget, reason: phase);
        final position = Scrollable.of(tester.element(primary)).position;
        expect(
          position.axisDirection,
          anyOf(AxisDirection.up, AxisDirection.down),
        );
        initialOffset ??= position.pixels;
        expect(initialOffset, closeTo(0, .01));
        expect(
          position.pixels,
          closeTo(initialOffset!, .01),
          reason: '$phase already visible action must not scroll controls',
        );
        final viewport = tester.getRect(
          find.ancestor(of: primary, matching: find.byType(Scrollable)).first,
        );
        final chipRect = tester.getRect(chip);
        expect(
          chipRect.top,
          greaterThanOrEqualTo(viewport.top - .01),
          reason: '$phase entire category chip is inside the controls viewport',
        );
        expect(chipRect.bottom, lessThanOrEqualTo(viewport.bottom + .01));
        final active = await TimerPersistence.instance.load(account!.id);
        observations.add({
          'phase': phase,
          'at_utc': DateTime.now().toUtc().toIso8601String(),
          'owner_uid': account.id,
          'scroll_offset': position.pixels,
          'max_scroll_extent': position.maxScrollExtent,
          'viewport_top': viewport.top,
          'viewport_bottom': viewport.bottom,
          'category_top': chipRect.top,
          'category_bottom': chipRect.bottom,
          'category_hit_testable': true,
          'primary_hit_testable': true,
          'active_uuid': active?.clientUuid,
          'active_seconds': active?.remainingSecondsAt(DateTime.now()),
          'pause_used_count': active?.pauseUsedCount,
          'is_running': active?.isRunning,
        });
        await E2eHost.screenshot(tester, 'e2e-t-visible-tap-$phase');
        expect(tester.takeException(), isNull, reason: phase);
      }

      Future<ActiveTimerSession> running() async {
        ActiveTimerSession? current;
        final end = DateTime.now().add(const Duration(seconds: 20));
        while (DateTime.now().isBefore(end)) {
          current = await TimerPersistence.instance.load(account!.id);
          final hourglass = find.byType(HourglassWidget);
          if (current?.isRunning == true &&
              hourglass.evaluate().length == 1 &&
              tester.widget<HourglassWidget>(hourglass).isRunning) {
            expect(current!.totalSeconds, 3000);
            expect(current.durationMinutes, 50);
            expect(current.recordAccelerated, isFalse);
            expect(current.isQuickTest, isFalse);
            expect(current.marathon, isNull);
            return current;
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        fail('Real 50-minute focus did not start.');
      }

      try {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        account = await openShellWithNewAccount(
          tester,
          'visible-tap-${DateTime.now().microsecondsSinceEpoch}',
          name: 'QA Görünür Sayaç',
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('league_info_shown_${account.id}', true);
        await NotificationService.instance.setEnabled(false);
        expect(service.currentUser.value?.id, account.id);
        expect(shellStats(tester), (points: 0, coins: 0));
        final nativeSize =
            tester.view.physicalSize / tester.view.devicePixelRatio;
        expect(nativeSize.height, greaterThan(nativeSize.width));
        await tapOn(tester, find.byKey(const ValueKey('timer-duration-50')));
        await observe('idle');
        await tapOn(tester, primary);
        final started = await running();
        cancelledUuid = started.clientUuid;
        expect(started.wasPaused, isFalse);
        await observe('focus');

        await tapOn(tester, primary);
        final paused = (await TimerPersistence.instance.load(account.id))!;
        expect(paused.clientUuid, started.clientUuid);
        expect(paused.startedAt, started.startedAt);
        expect(paused.isRunning, isFalse);
        expect(paused.pauseUsedCount, 1);
        final pauseWaitStart = DateTime.now();
        await pumpFor(tester, const Duration(seconds: 3));
        expect(
          DateTime.now().difference(pauseWaitStart),
          greaterThanOrEqualTo(const Duration(seconds: 3)),
        );
        await pumpUntilGone(tester, find.byType(SnackBar));
        expect(
          (await TimerPersistence.instance.load(
            account.id,
          ))!.pausedRemainingSeconds,
          paused.pausedRemainingSeconds,
        );
        expect(find.text(trL10n.pauseCreditUsed), findsOneWidget);
        await observe('paused');

        await tapOn(tester, primary);
        final resumed = await running();
        expect(resumed.clientUuid, started.clientUuid);
        expect(resumed.startedAt, started.startedAt);
        expect(resumed.pauseUsedCount, 1);
        expect(resumed.wasPaused, isTrue);
        expect(resumed.endsAt!.isAfter(started.endsAt!), isTrue);
        await observe('resumed');
        await tapOn(tester, primary);
        await pumpUntil(tester, find.text(tr('pause_limit_title')));
        final rejectedPause = (await TimerPersistence.instance.load(
          account.id,
        ))!;
        expect(rejectedPause.isRunning, isTrue);
        expect(rejectedPause.clientUuid, started.clientUuid);
        expect(rejectedPause.endsAt, resumed.endsAt);
        expect(rejectedPause.pauseUsedCount, 1);
        await tapOn(tester, find.text(tr('continue_btn')));
        await pumpUntilGone(tester, find.byType(AlertDialog));
        await observe('second-pause-rejected');

        await tapOn(tester, find.text(trL10n.timerResetBtn));
        await pumpUntil(tester, find.text(trL10n.timerResetConfirmTitle));
        await tapOn(tester, find.text(trL10n.timerResetConfirmAction).last);
        await pumpUntilGone(tester, find.byType(AlertDialog));
        expect(await TimerPersistence.instance.load(account.id), isNull);
        expect(await service.getPendingSessions(), isEmpty);
        expect(await service.fetchStudySessions(), isEmpty);
        expect(shellStats(tester), (points: 0, coins: 0));
        expect(
          await E2eHost.rows(
            'select client_uuid::text from study_sessions '
            'where user_id=${sqlText(account.id)}',
          ),
          isEmpty,
        );
        expect(
          await E2eHost.rows(
            'select client_uuid::text from study_sessions '
            'where client_uuid=${sqlText(cancelledUuid)}',
          ),
          isEmpty,
        );
        final profile = await E2eHost.row(
          'select total_minutes,lifetime_points,coins from profiles '
          'where id=${sqlText(account.id)}',
        );
        expect(profile, {'total_minutes': 0, 'lifetime_points': 0, 'coins': 0});
        debugPrint(
          '[QA] visible-tap ${jsonEncode({'owner_uid': account.id, 'cancelled_client_uuid': cancelledUuid, 'completed_sessions': 0, 'points': 0, 'coins': 0, 'pending_count': service.pendingSessionCount.value})}',
        );
        for (final observation in observations) {
          debugPrint('[QA] visible-tap-phase ${jsonEncode(observation)}');
        }
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        if (account != null) {
          await service.cancelStudySession();
          final unfinished = await TimerPersistence.instance.load(account.id);
          if (unfinished != null && !unfinished.isFinishedAt(DateTime.now())) {
            await TimerPersistence.instance.clear(
              account.id,
              onlyClientUuid: unfinished.clientUuid,
            );
          }
        }
        await NotificationService.instance.cancelSessionEndNotification();
        await NotificationService.instance.cancelOngoingTimer();
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
