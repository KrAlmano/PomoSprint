import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/models/marathon_progress.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/lock_screen_timer.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/session_queue.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/widgets/hourglass_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'support/fake_lock_screen_platform.dart';

// Gerçek 25/50 dk seans sözleşmesini saat kaynağını ilerleterek doğrular.
// Mola, günlük rapor ve puan callback'ine hiçbir zaman gönderilmemeli.
// Singleton disk kilidi aynı fake-async bölgesinde kalması için tüm
// senaryolar tek testWidgets içinde yürütülür.
void main() {
  testWidgets(
    'Maraton zinciri, kayıt, durdurma, yeniden açılış ve arka plan güvenliği',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      final category = CourseCategory.initialCategories().first;
      var now = DateTime(2026, 10, 7, 10);
      var owner = 'marathon-widget';
      var quick = false;
      var available = true;
      var sessionActive = true;
      var textScale = 1.0;
      Map<int, Map<int, int>>? serverBonuses;
      final submitted = <ActiveTimerSession>[];
      final breakChanges = <(bool, int)>[];
      final focusChanges = <bool>[];
      Future<SessionSubmitResult?> Function(ActiveTimerSession)? submitOverride;
      Future<bool> Function(ActiveTimerSession, String)? confirmOverride;
      final confirmationUuids = <String>[];
      final receiptWindows = <String, (DateTime, DateTime)>{};
      var populateReceipt = true;
      final store = TimerPersistence.instance;

      Future<void> drain() async {
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }

      Future<void> unmount() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await drain();
      }

      Future<void> mount({Key? appKey}) async {
        final lock = LockScreenTimer(
          platform: FakeLockScreenPlatform(),
          isEnabled: () async => true,
          categoryLabel: (name) => name,
          clock: () => now,
        );
        await tester.pumpWidget(
          MaterialApp(
            key: appKey ?? UniqueKey(),
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: TimerScreen(
              categories: [category],
              sessionOwnerKey: owner,
              onOpenSettings: () {},
              onSessionCompleted: (session) async {
                submitted.add(session);
                final result =
                    await (submitOverride?.call(session) ??
                        Future.value(
                          SessionSubmitSuccess(
                            minutes: session.durationMinutes,
                            totalPoints: 5,
                            coinsEarned: 20,
                          ),
                        ));
                if (populateReceipt &&
                    result is SessionSubmitSuccess &&
                    !result.marathonInvalid &&
                    result.marathonBreakEndsAt == null &&
                    session.marathon!.sessionIndex <
                        session.marathon!.totalSessions) {
                  final window = receiptWindows.putIfAbsent(
                    session.clientUuid,
                    () {
                      final end = now.add(
                        Duration(seconds: session.marathon!.breakSeconds),
                      );
                      return (end, end.add(const Duration(minutes: 1)));
                    },
                  );
                  return SessionSubmitSuccess(
                    minutes: result.minutes,
                    basePoints: result.basePoints,
                    bonusPoints: result.bonusPoints,
                    totalPoints: result.totalPoints,
                    bonusPct: result.bonusPct,
                    coinsEarned: result.coinsEarned,
                    streak: result.streak,
                    dailyLimitReached: result.dailyLimitReached,
                    duplicate: result.duplicate,
                    marathonBonusPoints: result.marathonBonusPoints,
                    marathonBreakEndsAt: window.$1,
                    marathonConfirmationDeadline: window.$2,
                  );
                }
                return result;
              },
              onTimerStateChanged: (running, _, _) => focusChanges.add(running),
              onConfirmMarathonPresence: (previous, uuid) {
                confirmationUuids.add(uuid);
                return confirmOverride?.call(previous, uuid) ??
                    Future.value(true);
              },
              onMarathonBreakChanged: (onBreak, left) =>
                  breakChanges.add((onBreak, left)),
              lockScreenTimer: lock,
              quickTimer: quick,
              marathonAvailable: available,
              marathonBonuses: serverBonuses,
              isSessionActive: () => sessionActive,
              clock: () => now,
            ),
          ),
        );
        await drain();
      }

      Future<ActiveTimerSession?> stored() async {
        await drain();
        return store.load(owner);
      }

      Future<void> tapKey(String key) async {
        final finder = find.byKey(ValueKey(key));
        await tester.ensureVisible(finder);
        await tester.pump();
        await tester.tap(finder);
        await drain();
      }

      Future<void> countdown() async {
        for (var second = 0; second < 4; second++) {
          now = now.add(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
        }
        await drain();
      }

      Future<void> pass(Duration duration) async {
        now = now.add(duration);
        await tester.pump(const Duration(seconds: 1));
        await drain();
      }

      Future<void> confirmPresence() async {
        expect(
          (await stored())?.marathon?.phase,
          MarathonPhase.awaitingPresence,
        );
        final before = submitted.length;
        await tapKey('marathon-presence-confirm');
        expect(
          submitted.length,
          before,
          reason: 'Onay yeni çalışma kaydı üretmez',
        );
      }

      Future<void> finishBreakAndConfirm() async {
        final plan = (await stored())!.marathon!;
        now = plan.breakEndsAt!;
        await tester.pump(const Duration(seconds: 1));
        await drain();
        await confirmPresence();
      }

      Future<void> finishFocus() async {
        final active = (await stored())!;
        expect(active.marathon?.phase, MarathonPhase.focus);
        now = active.endsAt!;
        await tester.pump(const Duration(seconds: 1));
        await drain();
      }

      Future<void> plan({required int count, int minutes = 25}) async {
        expect(find.byKey(const ValueKey('marathon-count-2')), findsNothing);
        await tapKey('marathon-open-planner');
        for (final option in [2, 3, 4]) {
          expect(
            find.byKey(ValueKey('marathon-count-$option')),
            findsOneWidget,
          );
        }
        expect(find.byKey(const ValueKey('marathon-count-5')), findsNothing);
        await tapKey('marathon-count-$count');
        await tapKey('marathon-duration-$minutes');
      }

      Future<void> start({required int count, int minutes = 25}) async {
        await plan(count: count, minutes: minutes);
        await tapKey('marathon-start');
        await countdown();
        expect((await stored())?.isRunning, isTrue);
        expect(
          find.byKey(const ValueKey('marathon-started-message')),
          findsWidgets,
          reason: 'Only a durably started plan shows the welcome message',
        );
      }

      Future<void> closeSummary() async {
        expect(find.text(l10n.marathonCompletedTitle), findsOneWidget);
        await tester.tap(find.text(l10n.sessionCompletedOk).last);
        await drain();
      }

      Future<void> fresh(String name, {bool shortened = false}) async {
        await unmount();
        SharedPreferences.setMockInitialValues({});
        owner = 'marathon-$name';
        quick = shortened;
        available = true;
        sessionActive = true;
        textScale = 1;
        serverBonuses = null;
        submitted.clear();
        breakChanges.clear();
        focusChanges.clear();
        submitOverride = null;
        confirmOverride = null;
        confirmationUuids.clear();
        receiptWindows.clear();
        populateReceipt = true;
        now = now.add(const Duration(days: 1));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await mount();
      }

      Future<void> stop({bool confirm = true}) async {
        await tapKey('marathon-stop');
        expect(find.text(l10n.marathonStopConfirmTitle), findsOneWidget);
        await tester.tap(
          find
              .text(confirm ? l10n.marathonStopConfirmAction : l10n.cancel)
              .last,
        );
        await drain();
      }

      // 1) Every allowed count and duration keeps separate focus records;
      // breaks and idle time never become study sessions.
      for (final minutes in [25, 50]) {
        for (final count in [2, 3, 4]) {
          await fresh('chain-$minutes-$count');
          expect(
            find.byKey(const ValueKey('marathon-open-planner')),
            findsOneWidget,
          );
          expect(find.byKey(const ValueKey('marathon-count-2')), findsNothing);
          expect(
            find.byKey(const ValueKey('timer-start-pause')),
            findsOneWidget,
          );
          final bonus = (minutes == 25
              ? {2: 2, 3: 3, 4: 5}
              : {2: 4, 3: 6, 4: 10})[count]!;
          submitOverride = (session) async {
            final isLast = session.marathon!.sessionIndex == count;
            return SessionSubmitSuccess(
              minutes: minutes,
              totalPoints: (minutes == 25 ? 5 : 12) + (isLast ? bonus : 0),
              coinsEarned: 20,
              marathonBonusPoints: isLast ? bonus : 0,
            );
          };
          await start(count: count, minutes: minutes);
          final planUuid = (await stored())!.marathon!.marathonUuid;
          for (var index = 1; index <= count; index++) {
            final active = (await stored())!;
            expect(active.durationMinutes, minutes);
            expect(active.totalSeconds, minutes * 60);
            expect(active.marathon?.sessionIndex, index);
            expect(active.marathon?.marathonUuid, planUuid);
            expect(
              active.pauseUsedCount,
              0,
              reason: 'Each focus has its own pause credit',
            );
            await finishFocus();
            expect(submitted, hasLength(index));
            expect(submitted.last.marathon?.phase, MarathonPhase.completing);
            expect(submitted.last.marathon?.sessionIndex, index);
            expect(submitted.last.marathon?.marathonUuid, planUuid);
            if (index < count) {
              expect(
                find.byKey(const ValueKey('marathon-break')),
                findsOneWidget,
              );
              expect((await stored())?.marathon?.completedSessions, index);
              expect(breakChanges.last, (true, 300));
              expect(
                focusChanges.last,
                isFalse,
                reason: 'Social focus is stopped during break',
              );
              await finishBreakAndConfirm();
              expect(
                submitted,
                hasLength(index),
                reason: 'Mola çalışma seansı değildir',
              );
              expect((await stored())?.isRunning, isTrue);
              expect(breakChanges.last, (false, 0));
            }
          }
          expect(
            submitted.map((session) => session.clientUuid).toSet(),
            hasLength(count),
          );
          expect(
            submitted.every((session) => session.categoryId == category.id),
            isTrue,
          );
          expect(
            submitted.fold<int>(
              0,
              (sum, session) => sum + session.durationMinutes,
            ),
            count * minutes,
          );
          expect(
            await stored(),
            isNull,
            reason: 'Finished plan no longer restores as active',
          );
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('marathon-completed-dialog')),
              matching: find.text(
                l10n.marathonCompletedBody(count, count * minutes),
              ),
            ),
            findsOneWidget,
          );
          expect(
            find.text(l10n.marathonBonusPoints(bonus)),
            findsOneWidget,
            reason: 'Bonus shown comes from server result',
          );
          expect(find.text(l10n.marathonBonusPending), findsNothing);
          await closeSummary();
        }
      }

      // A planner draft belongs only to the account/environment that opened
      // it. Returning a modal choice never bypasses capability, foreground,
      // or active-auth checks, nor changes the ordinary timer implicitly.
      for (final invalidation in [
        'owner',
        'auth',
        'capability',
        'background',
      ]) {
        await fresh('planner-guard-$invalidation');
        await unmount();
        final appKey = ValueKey('planner-guard-app-$invalidation');
        await mount(appKey: appKey);
        final plannerOwner = owner;
        await plan(count: 4, minutes: 50);
        expect(await stored(), isNull);
        expect(submitted, isEmpty);
        expect(focusChanges, isEmpty);
        switch (invalidation) {
          case 'owner':
            owner = 'planner-new-owner';
            await mount(appKey: appKey);
          case 'auth':
            sessionActive = false;
          case 'capability':
            available = false;
            await mount(appKey: appKey);
          case 'background':
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
        }
        // An owner change may close the modal immediately, which also safely
        // invalidates its awaiting result. Otherwise exercise the stale result.
        if (find
            .byKey(const ValueKey('marathon-start'))
            .evaluate()
            .isNotEmpty) {
          await tapKey('marathon-start');
        }
        await countdown();
        expect(
          await stored(),
          isNull,
          reason: '$invalidation cannot start a stale draft',
        );
        expect(
          await store.load(plannerOwner),
          isNull,
          reason: '$invalidation cannot create the old owner focus',
        );
        expect(
          submitted,
          isEmpty,
          reason: '$invalidation no session submission',
        );
        expect(
          focusChanges.where((running) => running),
          isEmpty,
          reason: '$invalidation no social focus',
        );
        expect(
          find.byKey(const ValueKey('marathon-started-message')),
          findsNothing,
        );
        expect(
          tester
              .widget<HourglassWidget>(find.byType(HourglassWidget))
              .totalSeconds,
          1500,
          reason: '$invalidation invalid draft cannot change normal duration',
        );
        sessionActive = true;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await drain();
      }

      // Backing out of 3-2-1 cancels the selected marathon without leaking
      // its count into the ordinary START action that remains on the screen.
      await fresh('planner-countdown-cancel');
      await plan(count: 4, minutes: 50);
      await tapKey('marathon-start');
      expect(find.byType(TimerCountdownDialog), findsOneWidget);
      final countdownContext = tester.element(
        find.byType(TimerCountdownDialog),
      );
      expect(ModalRoute.of(countdownContext)!.isCurrent, isTrue);
      expect(await Navigator.of(countdownContext).maybePop(), isTrue);
      // Start the reverse ticker before advancing its transition duration.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await drain();
      expect(find.byType(TimerCountdownDialog), findsNothing);
      expect(await stored(), isNull);
      expect(focusChanges, isEmpty);
      expect(
        find.byKey(const ValueKey('marathon-started-message')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('marathon-active-progress')),
        findsNothing,
      );
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byKey(const ValueKey('timer-start-pause')),
            )
            .onPressed,
        isNotNull,
      );
      await tapKey('timer-start-pause');
      await countdown();
      final ordinaryAfterCancel = (await stored())!;
      expect(ordinaryAfterCancel.isRunning, isTrue);
      expect(
        ordinaryAfterCancel.marathon,
        isNull,
        reason: 'Normal START cannot retain a cancelled marathon selection',
      );
      expect(focusChanges.where((running) => running), hasLength(1));
      expect(submitted, isEmpty);
      expect(
        find.byKey(const ValueKey('marathon-started-message')),
        findsNothing,
      );

      // A dialog's close button remains mounted during its reverse animation.
      // Repeated callback delivery must not pop the timer beneath that route.
      await fresh('progress-info-close-double');
      await start(count: 3);
      final beforeDialogClose = (await stored())!;
      await tapKey('marathon-active-progress');
      expect(
        find.byKey(const ValueKey('marathon-progress-dialog')),
        findsOneWidget,
      );
      final closeProgress = tester
          .widget<TextButton>(
            find.byKey(const ValueKey('marathon-progress-close')),
          )
          .onPressed!;
      closeProgress();
      closeProgress();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await drain();
      expect(
        find.byKey(const ValueKey('marathon-progress-dialog')),
        findsNothing,
      );
      expect(find.byType(TimerScreen), findsOneWidget);
      expect((await stored())?.clientUuid, beforeDialogClose.clientUuid);
      expect((await stored())?.endsAt, beforeDialogClose.endsAt);
      expect(submitted, isEmpty);
      expect(focusChanges.where((running) => running), hasLength(1));
      expect(tester.takeException(), isNull);

      await tapKey('marathon-info');
      expect(
        find.byKey(const ValueKey('marathon-info-dialog')),
        findsOneWidget,
      );
      final closeInfo = tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, l10n.sessionResultOk),
          )
          .onPressed!;
      closeInfo();
      closeInfo();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await drain();
      expect(find.byKey(const ValueKey('marathon-info-dialog')), findsNothing);
      expect(find.byType(TimerScreen), findsOneWidget);
      expect((await stored())?.clientUuid, beforeDialogClose.clientUuid);
      expect((await stored())?.endsAt, beforeDialogClose.endsAt);
      expect(submitted, isEmpty);
      expect(focusChanges.where((running) => running), hasLength(1));
      expect(tester.takeException(), isNull);
      await stop();

      // A genuine completed focus switches the existing landscape page to
      // break; its point feedback must leave the stop action immediately usable.
      await fresh('landscape-completion-feedback');
      textScale = 2;
      await mount();
      await start(count: 2);
      final landscapeFocus = (await stored())!;
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        find.byKey(const ValueKey('timer-landscape-clock')),
        findsOneWidget,
      );
      await finishFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final landscapeBreak = (await stored())!;
      expect(landscapeBreak.marathon!.phase, MarathonPhase.breakTime);
      expect(landscapeBreak.marathon!.completedSessions, 1);
      expect(submitted.single.clientUuid, landscapeFocus.clientUuid);
      expect(landscapeBreak.clientUuid, landscapeFocus.clientUuid);
      expect(find.text(l10n.sessionResultPoints(5)), findsWidgets);
      expect(find.byKey(const ValueKey('marathon-break-cup')), findsOneWidget);
      expect(find.byType(HourglassWidget), findsNothing);
      final landscapeStop = find.byKey(const ValueKey('marathon-stop'));
      expect(
        landscapeStop.hitTestable(),
        findsOneWidget,
        reason: 'Point feedback cannot cover the landscape break stop action',
      );
      await stop(confirm: false);
      expect(
        (await stored())!.marathon!.toJson(),
        landscapeBreak.marathon!.toJson(),
      );
      expect(submitted, hasLength(1));
      expect(focusChanges.where((running) => running), hasLength(1));
      expect(tester.takeException(), isNull);
      now = landscapeBreak.marathon!.breakEndsAt!;
      await tester.pump(const Duration(seconds: 1));
      await drain();
      confirmOverride = (_, _) async => false;
      await tapKey('marathon-presence-confirm');
      await tester.pump(const Duration(milliseconds: 700));
      final refusedPresence = (await stored())!;
      expect(refusedPresence.marathon!.phase, MarathonPhase.awaitingPresence);
      expect(
        refusedPresence.marathon!.presenceDeadline,
        landscapeBreak.marathon!.presenceDeadline,
      );
      expect(refusedPresence.clientUuid, landscapeFocus.clientUuid);
      expect(confirmationUuids, hasLength(1));
      expect(find.text(l10n.marathonPresenceConnectionNeeded), findsWidgets);
      expect(find.byType(HourglassWidget), findsOneWidget);
      expect(find.byKey(const ValueKey('marathon-break-cup')), findsNothing);
      expect(
        find.byKey(const ValueKey('marathon-presence-confirm')).hitTestable(),
        findsOneWidget,
        reason:
            'Connection failure feedback cannot cover landscape presence retry',
      );
      expect(
        landscapeStop.hitTestable(),
        findsOneWidget,
        reason:
            'Connection failure feedback cannot cover landscape presence stop',
      );
      expect(submitted, hasLength(1));
      expect(focusChanges.where((running) => running), hasLength(1));
      expect(tester.takeException(), isNull);
      await unmount();
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;

      // 2) Pause belongs to one focus, and stopping the plan preserves every
      // earlier completed focus. Cancelling the stop confirmation preserves
      // the current focus as well.
      await fresh('pause-stop');
      await start(count: 3);
      final firstUuid = (await stored())!.clientUuid;
      final planUuid = (await stored())!.marathon!.marathonUuid;
      await tapKey('timer-start-pause');
      expect((await stored())?.pauseUsedCount, 1);
      await tapKey('timer-start-pause');
      await countdown();
      expect((await stored())?.clientUuid, firstUuid);
      expect((await stored())?.pauseUsedCount, 1);
      await finishFocus();
      expect(submitted.single.wasPaused, isTrue);
      await finishBreakAndConfirm();
      expect((await stored())?.pauseUsedCount, 0);
      expect((await stored())?.clientUuid, isNot(firstUuid));
      final secondUuid = (await stored())!.clientUuid;
      await stop(confirm: false);
      expect((await stored())?.clientUuid, secondUuid);
      await stop();
      expect(await stored(), isNull);
      expect(
        submitted,
        hasLength(1),
        reason: 'Partial focus and future focuses are not recorded',
      );
      expect(submitted.single.clientUuid, firstUuid);
      expect(find.text(l10n.marathonCompletedTitle), findsNothing);
      expect(breakChanges.last, (false, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await drain();
      expect(
        find.text(l10n.marathonStopped),
        findsWidgets,
        reason:
            'Stopping explains that completed Pomodoros and normal points remain',
      );
      expect(find.text('Seans ilerlemen sıfırlandı.'), findsNothing);
      expect(find.text('Your session progress has been reset.'), findsNothing);
      expect(await stored(), isNull);
      expect(submitted.single.clientUuid, firstUuid);
      await start(count: 3);
      expect(
        (await stored())?.marathon?.marathonUuid,
        isNot(planUuid),
        reason: 'A new plan has a new reward identity',
      );
      await stop();

      // 3) Safe quick mode completes a whole chain without ever sending a
      // 5/10-second focus to onSessionCompleted or the normal outbox.
      for (final minutes in [25, 50]) {
        await fresh('quick-$minutes', shortened: true);
        await start(count: 2, minutes: minutes);
        expect((await stored())?.isQuickTest, isTrue);
        expect((await stored())?.recordAccelerated, isFalse);
        await finishFocus();
        expect(submitted, isEmpty);
        expect(breakChanges.last, (true, 3));
        await finishBreakAndConfirm();
        await finishFocus();
        expect(submitted, isEmpty);
        expect(await stored(), isNull);
        expect(
          find.text(l10n.marathonBonusPoints(minutes == 25 ? 2 : 4)),
          findsNothing,
          reason: 'Quick tests cannot claim real bonus',
        );
        expect(find.text(l10n.sessionResultTestNotSaved), findsNothing);
        await closeSummary();
      }

      // 4) A break ends in an explicit one-minute confirmation. Restoring
      // midway keeps the absolute deadline; no background tick starts focus.
      await fresh('lifecycle');
      await start(count: 3);
      await finishFocus();
      expect(submitted, hasLength(1));
      final breakEnd = (await stored())!.marathon!.breakEndsAt!;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = breakEnd.add(const Duration(seconds: 20));
      await tester.pump(const Duration(seconds: 1));
      await drain();
      expect((await stored())?.marathon?.phase, MarathonPhase.awaitingPresence);
      expect(focusChanges.where((running) => running), hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await drain();
      expect((await stored())?.clientUuid, submitted.single.clientUuid);
      await unmount();
      await mount();
      expect(find.text('00:40'), findsOneWidget);
      expect(
        (await stored())?.marathon?.presenceDeadline,
        breakEnd.add(const Duration(minutes: 1)),
      );
      final resumedAt = now;
      await confirmPresence();
      final resumed = (await stored())!;
      expect(resumed.startedAt, resumedAt);
      expect(resumed.marathon?.sessionIndex, 2);
      expect(resumed.pauseUsedCount, 0);
      expect(breakChanges.last, (false, 0));
      await unmount();
      await mount();
      expect((await stored())?.clientUuid, resumed.clientUuid);
      expect((await stored())?.endsAt, resumed.endsAt);
      expect(submitted, hasLength(1));
      await finishFocus();
      await unmount();
      now = now.add(const Duration(minutes: 1));
      await mount();
      expect(submitted, hasLength(2));
      expect((await stored())?.marathon?.phase, MarathonPhase.breakTime);
      expect(breakChanges.last, (true, 240));
      await finishBreakAndConfirm();
      await finishFocus();
      await closeSummary();
      await unmount();
      await mount();
      expect(submitted, hasLength(3));
      expect(await stored(), isNull);

      // No confirmation by the deadline stops the remaining plan even in
      // background, without losing the already durable focus.
      await fresh('background-expiry');
      await start(count: 4);
      await finishFocus();
      final savedFirst = submitted.single.clientUuid;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await pass(const Duration(minutes: 6));
      expect(await stored(), isNull);
      expect(submitted.single.clientUuid, savedFirst);
      expect(confirmationUuids, isEmpty);
      expect(focusChanges.where((running) => running), hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await drain();
      expect(await stored(), isNull);
      expect(submitted, hasLength(1));

      // An overdue focus is still settled exactly once, but its already
      // expired break/check-in never fabricates a second focus.
      await fresh('overdue-focus-restore');
      receiptWindows['overdue-first-focus'] = (
        now.subtract(const Duration(hours: 2)),
        now.subtract(const Duration(hours: 2)).add(const Duration(minutes: 1)),
      );
      await unmount();
      await store.save(
        owner,
        ActiveTimerSession.start(
          clientUuid: 'overdue-first-focus',
          categoryId: category.id,
          categoryName: category.name,
          durationMinutes: 50,
          totalSeconds: 3000,
          now: now.subtract(const Duration(hours: 3)),
          marathon: const MarathonProgress(
            totalSessions: 4,
            marathonUuid: 'bbbbbbb1-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          ),
        ),
      );
      await mount();
      expect(submitted.map((session) => session.clientUuid), [
        'overdue-first-focus',
      ]);
      expect(await stored(), isNull);
      expect(confirmationUuids, isEmpty);
      expect(focusChanges.where((running) => running), isEmpty);

      // Reusing the widget for another owner must not move a saved plan or
      // leak progress into the new account. Returning restores the original.
      await fresh('owner-isolation');
      await unmount();
      const reuseKey = ValueKey('owner-reused-app');
      await mount(appKey: reuseKey);
      await start(count: 3);
      await finishFocus();
      final firstOwner = owner;
      final firstPlan = (await stored())!.marathon!.marathonUuid;
      owner = 'marathon-another-owner';
      await mount(appKey: reuseKey);
      expect(await stored(), isNull);
      expect(
        find.byKey(const ValueKey('marathon-active-progress')),
        findsNothing,
      );
      expect((await store.load(firstOwner))?.marathon?.marathonUuid, firstPlan);
      owner = firstOwner;
      await mount(appKey: reuseKey);
      expect((await stored())?.marathon?.marathonUuid, firstPlan);
      expect((await stored())?.marathon?.completedSessions, 1);
      expect(submitted, hasLength(1));
      await stop();

      // Presence must be an explicit foreground action, with durable
      // candidate identity across retries/process loss and no optimistic start.
      await fresh('presence-retry');
      await start(count: 3);
      await finishFocus();
      final alreadySaved = submitted.single.clientUuid;
      expect(
        find.byKey(const ValueKey('marathon-presence-confirm')),
        findsNothing,
      );
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('timer-start-pause')),
            )
            .onPressed,
        isNull,
      );
      await pass(const Duration(seconds: 299));
      expect(confirmationUuids, isEmpty);
      await pass(const Duration(seconds: 1));
      expect((await stored())?.marathon?.phase, MarathonPhase.awaitingPresence);
      final immutableDeadline = (await stored())!.marathon!.presenceDeadline;
      confirmOverride = (_, _) async => false;
      await confirmPresence();
      final candidate = (await stored())!.marathon!.presenceClientUuid;
      expect(candidate, isNotNull);
      expect((await stored())?.isRunning, isFalse);
      expect(confirmationUuids, [candidate]);
      await unmount();
      now = now.add(const Duration(seconds: 15));
      confirmOverride = (_, _) async => true;
      await mount();
      expect((await stored())?.marathon?.presenceDeadline, immutableDeadline);
      expect((await stored())?.marathon?.presenceClientUuid, candidate);
      await confirmPresence();
      expect((await stored())?.clientUuid, candidate);
      expect(confirmationUuids, [candidate, candidate]);
      expect(submitted.single.clientUuid, alreadySaved);
      await stop();

      await fresh('presence-double-tap-late-ack');
      await start(count: 4);
      await finishFocus();
      await pass(const Duration(minutes: 5));
      final lateAck = Completer<bool>();
      confirmOverride = (_, _) => lateAck.future;
      await confirmPresence();
      await tester.tap(find.byKey(const ValueKey('marathon-presence-confirm')));
      await drain();
      expect(confirmationUuids, hasLength(1));
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('marathon-presence-confirm')),
            )
            .onPressed,
        isNull,
      );
      await pass(const Duration(minutes: 1));
      expect(
        await stored(),
        isNull,
        reason: 'Bir dakikalık deadline RPC beklerken de işler',
      );
      lateAck.complete(true);
      await drain();
      expect(await stored(), isNull);
      expect(submitted, hasLength(1));
      expect(focusChanges.where((running) => running), hasLength(1));
      expect(
        find.byKey(const ValueKey('marathon-presence-confirm')),
        findsNothing,
      );

      await fresh('presence-boundary');
      await start(count: 2);
      await finishFocus();
      await pass(const Duration(minutes: 5));
      now = (await stored())!.marathon!.presenceDeadline!;
      await tapKey('marathon-presence-confirm');
      expect(
        confirmationUuids,
        isEmpty,
        reason: 'Sınır anında yeni UUID/RPC/odak yok',
      );
      expect(await stored(), isNull);
      expect(submitted, hasLength(1));

      await fresh('presence-background-ack');
      await start(count: 2);
      await finishFocus();
      await pass(const Duration(minutes: 5));
      final backgroundAck = Completer<bool>();
      confirmOverride = (_, _) => backgroundAck.future;
      await confirmPresence();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      backgroundAck.complete(true);
      await drain();
      expect((await stored())?.marathon?.phase, MarathonPhase.awaitingPresence);
      expect(focusChanges.where((running) => running), hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await drain();
      expect((await stored())?.marathon?.phase, MarathonPhase.awaitingPresence);
      confirmOverride = (_, _) async => true;
      await confirmPresence();
      expect(focusChanges.where((running) => running), hasLength(2));
      await stop();

      await fresh('countdown-owner-change');
      await unmount();
      const countdownReuseKey = ValueKey('countdown-owner-reused');
      await mount(appKey: countdownReuseKey);
      final countdownOwner = owner;
      await plan(count: 2);
      await tapKey('marathon-start');
      await pass(const Duration(seconds: 1));
      owner = 'countdown-other-account';
      await mount(appKey: countdownReuseKey);
      await countdown();
      expect(await stored(), isNull);
      expect(await store.load(countdownOwner), isNull);
      expect(
        focusChanges,
        isEmpty,
        reason: 'Önceki hesabın geri sayımı yeni hesabı başlatamaz',
      );
      expect(submitted, isEmpty);

      await fresh('presence-owner-ack');
      await unmount();
      const presenceReuseKey = ValueKey('presence-owner-reused');
      await mount(appKey: presenceReuseKey);
      await start(count: 2);
      await finishFocus();
      await pass(const Duration(minutes: 5));
      final originalOwner = owner;
      final ownerAck = Completer<bool>();
      confirmOverride = (_, _) => ownerAck.future;
      await confirmPresence();
      owner = 'presence-other-account';
      await mount(appKey: presenceReuseKey);
      ownerAck.complete(true);
      await drain();
      expect(await stored(), isNull);
      expect(
        (await store.load(originalOwner))?.marathon?.phase,
        MarathonPhase.awaitingPresence,
      );
      expect(focusChanges.where((running) => running), hasLength(1));
      expect(submitted, hasLength(1));

      // Server acceptance after network latency defines one immutable
      // window; queued completion keeps the original real focus-end window.
      await fresh('delayed-server-receipt');
      final delayedReceipt = Completer<SessionSubmitResult?>();
      submitOverride = (_) => delayedReceipt.future;
      await start(count: 3);
      await finishFocus();
      await pass(const Duration(seconds: 20));
      final serverEnd = now.add(const Duration(minutes: 5));
      delayedReceipt.complete(
        SessionSubmitSuccess(
          minutes: 25,
          totalPoints: 5,
          marathonBreakEndsAt: serverEnd,
          marathonConfirmationDeadline: serverEnd.add(
            const Duration(minutes: 1),
          ),
        ),
      );
      await drain();
      expect((await stored())?.marathon?.breakEndsAt, serverEnd);
      expect(
        (await stored())?.marathon?.presenceDeadline,
        serverEnd.add(const Duration(minutes: 1)),
      );
      expect(find.text('05:00'), findsOneWidget);
      await unmount();
      await mount();
      expect((await stored())?.marathon?.breakEndsAt, serverEnd);
      await stop();

      await fresh('queued-fixed-deadline');
      submitOverride = (_) async => const SessionSubmitQueued(
        reasonCode: SessionReason.offline,
        pendingCount: 1,
      );
      await start(count: 3);
      final originalEnd = (await stored())!.endsAt!;
      await finishFocus();
      final fixedDeadline = originalEnd.add(const Duration(minutes: 6));
      expect((await stored())?.marathon?.presenceDeadline, fixedDeadline);
      await unmount();
      now = fixedDeadline;
      await mount();
      expect(await stored(), isNull);
      expect(submitted, hasLength(1));
      expect(confirmationUuids, isEmpty);

      await fresh('missing-receipt');
      populateReceipt = false;
      await start(count: 3);
      await finishFocus();
      expect(
        await stored(),
        isNull,
        reason: 'Kayıt başarılı ama yetkili pencere yoksa yeni odak yok',
      );
      expect(submitted, hasLength(1));
      expect(
        find.byKey(const ValueKey('marathon-active-progress')),
        findsNothing,
        reason: 'Invalid plans cannot retain an active progress action',
      );
      // Let the welcome snackbar's outgoing transition finish before the
      // durable-stop feedback enters; this does not advance the injected clock.
      await tester.pump(const Duration(milliseconds: 600));
      await drain();
      expect(find.text(l10n.marathonStoppedInvalid), findsWidgets);
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byKey(const ValueKey('timer-start-pause')),
            )
            .onPressed,
        isNotNull,
        reason: 'Completed normal focus is kept; normal START becomes usable',
      );
      expect(confirmationUuids, isEmpty);

      await fresh('malformed-receipt');
      submitOverride = (_) async => SessionSubmitSuccess(
        minutes: 25,
        marathonBreakEndsAt: now.add(const Duration(minutes: 5)),
        marathonConfirmationDeadline: now.add(const Duration(minutes: 7)),
      );
      await start(count: 3);
      await finishFocus();
      expect(await stored(), isNull);
      expect(submitted, hasLength(1));
      expect(confirmationUuids, isEmpty);

      await fresh('server-invalid-marathon');
      submitOverride = (_) async => const SessionSubmitSuccess(
        minutes: 25,
        totalPoints: 5,
        coinsEarned: 20,
        marathonInvalid: true,
      );
      await start(count: 3);
      await finishFocus();
      expect(await stored(), isNull);
      expect(
        submitted,
        hasLength(1),
        reason: 'Bireysel odak saklı, sunucuda geçersiz plan ilerlemez',
      );
      expect(
        find.byKey(const ValueKey('marathon-active-progress')),
        findsNothing,
        reason: 'Invalid plans cannot retain an active progress action',
      );
      // Let the welcome snackbar's outgoing transition finish before the
      // durable-stop feedback enters; this does not advance the injected clock.
      await tester.pump(const Duration(milliseconds: 600));
      await drain();
      expect(find.text(l10n.marathonStoppedInvalid), findsWidgets);
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byKey(const ValueKey('timer-start-pause')),
            )
            .onPressed,
        isNotNull,
        reason: 'Completed normal focus is kept; normal START becomes usable',
      );
      await pass(const Duration(minutes: 6));
      expect(confirmationUuids, isEmpty);
      expect(submitted, hasLength(1));

      // 5) A callback with no durable outcome retains the completing record.
      // Process death retries the SAME idempotency identity, and duplicate
      // success advances only one focus.
      await fresh('retry-restore');
      submitOverride = (_) async => null;
      await start(count: 2);
      await finishFocus();
      final failed = (await stored())!;
      expect(failed.marathon?.phase, MarathonPhase.completing);
      expect(failed.marathon?.completedSessions, 0);
      expect(find.byKey(const ValueKey('marathon-retry-save')), findsOneWidget);
      expect(find.byKey(const ValueKey('marathon-break')), findsNothing);
      await unmount();
      submitOverride = (_) async =>
          const SessionSubmitSuccess(minutes: 25, duplicate: true);
      await mount();
      expect(submitted.map((session) => session.clientUuid), [
        failed.clientUuid,
        failed.clientUuid,
      ]);
      expect((await stored())?.marathon?.completedSessions, 1);
      expect((await stored())?.marathon?.phase, MarathonPhase.breakTime);
      await stop();

      // 6) An unresolved callback cannot start the break/next focus. Error
      // then UI retry with a queued durable outcome safely advances.
      await fresh('pending-retry');
      final pending = Completer<SessionSubmitResult?>();
      submitOverride = (_) => pending.future;
      await start(count: 2);
      await finishFocus();
      expect(submitted, hasLength(1));
      expect((await stored())?.marathon?.phase, MarathonPhase.completing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await pass(const Duration(minutes: 5));
      expect(
        submitted,
        hasLength(1),
        reason: 'Lifecycle events do not duplicate a pending submission',
      );
      expect(find.byKey(const ValueKey('marathon-break')), findsNothing);
      pending.completeError(StateError('temporary save failure'));
      await drain();
      expect(find.byKey(const ValueKey('marathon-retry-save')), findsOneWidget);
      submitOverride = (_) async => const SessionSubmitQueued(
        reasonCode: SessionReason.offline,
        pendingCount: 1,
      );
      await tapKey('marathon-retry-save');
      expect(submitted, hasLength(2));
      expect(submitted.first.clientUuid, submitted.last.clientUuid);
      expect((await stored())?.marathon?.completedSessions, 1);
      expect((await stored())?.marathon?.phase, MarathonPhase.awaitingPresence);
      await confirmPresence();
      expect((await stored())?.marathon?.phase, MarathonPhase.focus);
      expect(
        (await stored())?.startedAt,
        now,
        reason: 'The next focus starts at current foreground time',
      );
      await finishFocus();
      expect(submitted, hasLength(3));
      expect(find.text(l10n.marathonBonusPending), findsOneWidget);
      expect(
        find.text(l10n.marathonBonusPoints(2)),
        findsNothing,
        reason: 'Queued result must not invent an awarded bonus',
      );
      await closeSummary();

      // Stop while a focus is being saved must preserve that focus and
      // the user's stop intent, even if the screen disappears before the
      // callback returns. A late completion cannot resume the plan.
      await fresh('saving-stop-unmount');
      final stoppedPending = Completer<SessionSubmitResult?>();
      submitOverride = (_) => stoppedPending.future;
      await start(count: 3);
      await finishFocus();
      await stop();
      expect((await stored())?.marathon?.stopRequested, isTrue);
      expect((await stored())?.marathon?.phase, MarathonPhase.completing);
      await unmount();
      stoppedPending.complete(
        const SessionSubmitSuccess(
          minutes: 25,
          totalPoints: 5,
          coinsEarned: 20,
        ),
      );
      await drain();
      final afterDispose = await stored();
      expect(
        afterDispose == null ||
            (afterDispose.marathon?.stopRequested == true &&
                afterDispose.marathon?.phase == MarathonPhase.completing),
        isTrue,
        reason: 'Late completion must honor the persisted stop after dispose',
      );
      submitOverride = (_) async =>
          const SessionSubmitSuccess(minutes: 25, duplicate: true);
      await mount();
      expect(await stored(), isNull);
      expect(
        submitted.map((session) => session.clientUuid).toSet(),
        hasLength(1),
      );
      expect(
        submitted.length,
        lessThanOrEqualTo(2),
        reason: 'Only a durable stop retry may be submitted',
      );
      expect(
        find.byKey(const ValueKey('marathon-active-progress')),
        findsNothing,
      );

      // A new timer instance may restore/retry before an old callback
      // returns. The old response must not overwrite the already started
      // second focus or restart the previous break.
      await fresh('stale-instance-response');
      final oldPending = Completer<SessionSubmitResult?>();
      submitOverride = (_) => oldPending.future;
      await start(count: 3);
      await finishFocus();
      await unmount();
      submitOverride = (_) async =>
          const SessionSubmitSuccess(minutes: 25, duplicate: true);
      await mount();
      expect((await stored())?.marathon?.phase, MarathonPhase.breakTime);
      await finishBreakAndConfirm();
      final newFocus = (await stored())!;
      expect(newFocus.marathon?.sessionIndex, 2);
      oldPending.complete(
        const SessionSubmitSuccess(
          minutes: 25,
          totalPoints: 5,
          coinsEarned: 20,
        ),
      );
      await drain();
      expect(
        (await stored())?.clientUuid,
        newFocus.clientUuid,
        reason: 'Old instance must not overwrite a newer focus',
      );
      expect((await stored())?.marathon?.phase, MarathonPhase.focus);
      expect(
        submitted,
        hasLength(2),
        reason: 'Only the same first focus was attempted twice',
      );
      await stop();

      // The stop confirmation itself holds automatic break advancement.
      // Cancelling resumes one new focus at current time; confirming stops.
      for (final confirm in [false, true]) {
        await fresh('break-dialog-$confirm');
        await start(count: 3);
        await finishFocus();
        final resting = (await stored())!;
        await tapKey('marathon-stop');
        await pass(const Duration(minutes: 5));
        expect((await stored())?.clientUuid, resting.clientUuid);
        expect(
          (await stored())?.marathon?.phase,
          MarathonPhase.awaitingPresence,
        );
        expect(submitted, hasLength(1));
        final decisionAt = now;
        await tester.tap(
          find
              .text(confirm ? l10n.marathonStopConfirmAction : l10n.cancel)
              .last,
        );
        await drain();
        if (confirm) {
          expect(await stored(), isNull);
        } else {
          expect(
            (await stored())?.marathon?.phase,
            MarathonPhase.awaitingPresence,
          );
          await confirmPresence();
          expect((await stored())?.marathon?.sessionIndex, 2);
          expect((await stored())?.startedAt, decisionAt);
          await stop();
        }
        expect(submitted, hasLength(1));
      }

      // 7) A permanent rejection stops chaining without submitting future
      // focuses; already successful earlier focus records remain untouched.
      await fresh('rejected');
      await start(count: 3);
      await finishFocus();
      await finishBreakAndConfirm();
      submitOverride = (_) async =>
          const SessionSubmitRejected(SessionReason.overlap);
      await finishFocus();
      expect(submitted, hasLength(2));
      expect(await stored(), isNull);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(l10n.marathonStoppedRejected), findsWidgets);
      expect(find.text(l10n.marathonCompletedTitle), findsNothing);
      await pass(const Duration(hours: 2));
      expect(submitted, hasLength(2));

      // 8) A completed terminal record left by process death may show the
      // summary, but must never submit the final focus again.
      await fresh('terminal-restore');
      var progress = const MarathonProgress(
        totalSessions: 2,
        marathonUuid: 'aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );
      progress = progress
          .beginCompletion()
          .finishFocus(now)
          .nextFocus()
          .beginCompletion()
          .finishFocus(now);
      await unmount();
      await store.save(
        owner,
        ActiveTimerSession.start(
          clientUuid: 'terminal-focus',
          categoryId: category.id,
          categoryName: category.name,
          durationMinutes: 25,
          totalSeconds: 1500,
          now: now.subtract(const Duration(minutes: 25)),
          marathon: progress,
        ),
      );
      await mount();
      expect(submitted, isEmpty);
      expect(await stored(), isNull);
      await closeSummary();

      // 9) Server capability may disappear, but existing plans still
      // recover. Disabled capability blocks all NEW plans, including after
      // stopping a restored plan whose selection remains at three.
      await fresh('unavailable');
      await unmount();
      available = false;
      await mount();
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byKey(const ValueKey('marathon-open-planner')),
            )
            .onPressed,
        isNull,
        reason: 'Unavailable capability cannot open a new plan',
      );
      expect(find.byKey(const ValueKey('marathon-count-2')), findsNothing);
      expect(find.byKey(const ValueKey('marathon-start')), findsNothing);
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byKey(const ValueKey('timer-start-pause')),
            )
            .onPressed,
        isNotNull,
      );
      await unmount();
      available = true;
      await mount();
      serverBonuses = {
        25: {2: 11, 3: 13, 4: 17},
        50: {2: 19, 3: 23, 4: 29},
      };
      await unmount();
      await mount();
      await plan(count: 3);
      expect(
        find.text(l10n.marathonBonusHint(13)),
        findsOneWidget,
        reason: 'Chooser uses server configuration',
      );
      await tapKey('marathon-start');
      await countdown();
      final restoredUuid = (await stored())!.clientUuid;
      await unmount();
      available = false;
      await mount();
      expect((await stored())?.clientUuid, restoredUuid);
      await finishFocus();
      expect(submitted, hasLength(1));
      await finishBreakAndConfirm();
      expect((await stored())?.marathon?.sessionIndex, 2);
      await stop();
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byKey(const ValueKey('marathon-open-planner')),
            )
            .onPressed,
        isNull,
        reason: 'Stopping an old plan cannot bypass disabled new plans',
      );
      expect(find.byKey(const ValueKey('marathon-start')), findsNothing);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('timer-start-pause')),
            )
            .onPressed,
        isNotNull,
      );

      // 10) Malformed disk JSON is a safe idle state, not an app crash.
      await fresh('invalid-json');
      await unmount();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(TimerPersistence.keyFor(owner), '{broken');
      await mount();
      expect(await stored(), isNull);
      expect(submitted, isEmpty);
      expect(
        find.byKey(const ValueKey('marathon-open-planner')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await unmount();

      // 11) Native sign-out can keep the old shell mounted for seconds.
      // Ending the device session closes the live predicate immediately,
      // without clearing the resumable owner record. No new focus or
      // ID 0 alarm may appear while native sign-out is still waiting.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final notificationService = NotificationService.instance;
      notificationService.debugResetInitialization();
      const notificationChannel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final nativeCalls = <MethodCall>[];
      Completer<void>? releaseBreakCancel;
      var breakCancelEntered = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationChannel, (call) async {
            nativeCalls.add(call);
            if (call.method == 'cancel' &&
                call.arguments['id'] == 2 &&
                releaseBreakCancel != null) {
              breakCancelEntered = true;
              await releaseBreakCancel.future;
            }
            return true;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(notificationChannel, null);
        debugDefaultTargetPlatformOverride = null;
        notificationService.debugResetInitialization();
      });

      await fresh('ending-mounted-break');
      await start(count: 2);
      await finishFocus();
      final endingBreak = (await stored())!;
      expect(endingBreak.marathon?.phase, MarathonPhase.breakTime);
      nativeCalls.clear();
      sessionActive = false;
      await pass(const Duration(minutes: 6));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await drain();
      expect((await stored())?.clientUuid, endingBreak.clientUuid);
      expect((await stored())?.marathon?.phase, MarathonPhase.breakTime);
      expect(submitted, hasLength(1));
      expect(focusChanges.where((running) => running), hasLength(1));
      expect(
        nativeCalls.any(
          (call) =>
              (call.method == 'zonedSchedule' || call.method == 'show') &&
              call.arguments['id'] == 0,
        ),
        isFalse,
      );
      await unmount();
      expect(
        nativeCalls
            .where((call) => call.method == 'cancel')
            .map((call) => call.arguments['id']),
        containsAll([0, 2]),
        reason: 'Dispose clears focus and break alarms while keeping the plan',
      );
      sessionActive = true;
      await mount();
      expect(await stored(), isNull);
      expect(submitted, hasLength(1));
      expect(confirmationUuids, isEmpty);

      // The predicate is checked again after an asynchronous cancellation:
      // logout can begin after the break tick but before the next UUID exists.
      await fresh('ending-during-break-cancel');
      await start(count: 2);
      await finishFocus();
      final cancelRaceBreak = (await stored())!;
      nativeCalls.clear();
      releaseBreakCancel = Completer<void>();
      await finishBreakAndConfirm();
      expect(breakCancelEntered, isTrue);
      sessionActive = false;
      releaseBreakCancel.complete();
      releaseBreakCancel = null;
      await drain();
      expect((await stored())?.clientUuid, cancelRaceBreak.clientUuid);
      expect((await stored())?.marathon?.phase, MarathonPhase.awaitingPresence);
      expect(submitted, hasLength(1));
      expect(focusChanges.where((running) => running), hasLength(1));
      expect(
        nativeCalls.any(
          (call) =>
              (call.method == 'zonedSchedule' || call.method == 'show') &&
              call.arguments['id'] == 0,
        ),
        isFalse,
        reason: 'A post-await logout cannot recreate the cleaned focus alarm',
      );
      await unmount();

      // An expired persisted focus also waits for its owner's device
      // session to become active. Ending/remote-expired auth must not
      // submit it or recreate any alarm during the cleanup window.
      await fresh('ending-expired-restore');
      await unmount();
      final endingFocus = ActiveTimerSession.start(
        clientUuid: 'ending-focus-original',
        categoryId: category.id,
        categoryName: category.name,
        durationMinutes: 25,
        totalSeconds: 1500,
        now: now.subtract(const Duration(minutes: 26)),
        marathon: const MarathonProgress(
          totalSessions: 2,
          marathonUuid: 'eeeeeee1-eeee-4eee-8eee-eeeeeeeeeeee',
        ),
      );
      await store.save(owner, endingFocus);
      nativeCalls.clear();
      sessionActive = false;
      await mount();
      await pass(const Duration(seconds: 2));
      expect(submitted, isEmpty);
      expect(focusChanges, isEmpty);
      expect((await stored())?.clientUuid, endingFocus.clientUuid);
      expect(
        nativeCalls.any(
          (call) => call.method == 'zonedSchedule' || call.method == 'show',
        ),
        isFalse,
      );
      await unmount();
      sessionActive = true;
      await mount();
      expect(submitted.map((session) => session.clientUuid), [
        endingFocus.clientUuid,
      ]);
      expect((await stored())?.marathon?.completedSessions, 1);
      await stop();
      await unmount();

      // The disk bridge can finish long after the next focus JSON has
      // entered SharedPreferences' cache. A new owner's load must wait
      // for the same lock and see the preceding break, not that focus.
      await fresh('ending-during-focus-write');
      await start(count: 2);
      await finishFocus();
      await pass(const Duration(minutes: 5));
      final writeRaceBreak = (await stored())!;
      expect(writeRaceBreak.marathon?.phase, MarathonPhase.awaitingPresence);
      final delayedPrefs =
          _DelayedPreferencesStore(
            await SharedPreferencesStorePlatform.instance.getAll(),
          )..holdNextWrite(
            'flutter.${TimerPersistence.keyFor(owner)}',
            phase: MarathonPhase.focus,
          );
      SharedPreferencesStorePlatform.instance = delayedPrefs;
      nativeCalls.clear();
      await confirmPresence();
      expect(delayedPrefs.isWaiting, isTrue);
      final neverStarted = ActiveTimerSession.fromJson(
        jsonDecode(delayedPrefs.heldValue! as String),
      )!;
      expect(neverStarted.marathon?.phase, MarathonPhase.focus);
      expect(neverStarted.clientUuid, isNot(writeRaceBreak.clientUuid));
      sessionActive = false;
      var readCompleted = false;
      final blockedRead = store.load(owner).then((session) {
        readCompleted = true;
        return session;
      });
      await drain();
      expect(readCompleted, isFalse);
      delayedPrefs.release();
      await drain();
      final rolledBack = await blockedRead;
      expect(rolledBack?.clientUuid, writeRaceBreak.clientUuid);
      expect(rolledBack?.marathon?.phase, MarathonPhase.awaitingPresence);
      expect((await stored())?.clientUuid, writeRaceBreak.clientUuid);
      expect(submitted, hasLength(1));
      expect(focusChanges.where((running) => running), hasLength(1));
      expect(
        nativeCalls.any(
          (call) =>
              (call.method == 'zonedSchedule' || call.method == 'show') &&
              call.arguments['id'] == 0,
        ),
        isFalse,
      );
      await unmount();
      now = now.add(const Duration(hours: 1));
      sessionActive = true;
      await mount();
      expect(await stored(), isNull);
      expect(submitted, hasLength(1));

      // A healthy auth/session cannot turn a slow disk ACK into an old
      // start timestamp: rollback the unstarted focus after two seconds.
      await fresh('slow-focus-write');
      await start(count: 2);
      await finishFocus();
      await pass(const Duration(minutes: 5));
      final slowPrior = (await stored())!;
      final slowPrefs =
          _DelayedPreferencesStore(
            await SharedPreferencesStorePlatform.instance.getAll(),
          )..holdNextWrite(
            'flutter.${TimerPersistence.keyFor(owner)}',
            phase: MarathonPhase.focus,
          );
      SharedPreferencesStorePlatform.instance = slowPrefs;
      nativeCalls.clear();
      await confirmPresence();
      expect(slowPrefs.isWaiting, isTrue);
      now = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      slowPrefs.release();
      await drain();
      expect((await stored())?.clientUuid, slowPrior.clientUuid);
      expect((await stored())?.marathon?.phase, MarathonPhase.awaitingPresence);
      expect(submitted, hasLength(1));
      expect(focusChanges.where((running) => running), hasLength(1));
      expect(
        nativeCalls.any(
          (call) =>
              (call.method == 'zonedSchedule' || call.method == 'show') &&
              call.arguments['id'] == 0,
        ),
        isFalse,
      );
      await stop();

      // The first plan write has the same commit barrier. Signing out
      // before its acknowledgement cannot leave an unstarted first
      // focus that would later be submitted as a completed session.
      await fresh('ending-during-initial-write');
      final delayedFirstPrefs = _DelayedPreferencesStore(
        await SharedPreferencesStorePlatform.instance.getAll(),
      )..holdNextWrite('flutter.${TimerPersistence.keyFor(owner)}');
      SharedPreferencesStorePlatform.instance = delayedFirstPrefs;
      nativeCalls.clear();
      await plan(count: 2);
      await tapKey('marathon-start');
      await countdown();
      expect(delayedFirstPrefs.isWaiting, isTrue);
      sessionActive = false;
      await unmount();
      delayedFirstPrefs.release();
      await drain();
      expect(await stored(), isNull);
      expect(submitted, isEmpty);
      expect(focusChanges.where((running) => running), isEmpty);
      expect(
        nativeCalls.any(
          (call) =>
              (call.method == 'zonedSchedule' || call.method == 'show') &&
              call.arguments['id'] == 0,
        ),
        isFalse,
      );
      now = now.add(const Duration(hours: 1));
      sessionActive = true;
      await mount();
      expect(await stored(), isNull);
      expect(submitted, isEmpty);
      await unmount();

      // False/throwing platform acknowledgements must roll back the
      // plugin's eagerly updated cache too, both for the first plan
      // write and for a subsequent conditional focus transition.
      for (final throwAcknowledgement in [false, true]) {
        await fresh('failed-initial-write-$throwAcknowledgement');
        final failedPrefs = _DelayedPreferencesStore(
          await SharedPreferencesStorePlatform.instance.getAll(),
        );
        final preferencesKey = 'flutter.${TimerPersistence.keyFor(owner)}';
        void failWrite() {
          if (throwAcknowledgement) {
            failedPrefs.throwNextWrite(preferencesKey);
          } else {
            failedPrefs.failNextWrite(preferencesKey);
          }
        }

        failWrite();
        SharedPreferencesStorePlatform.instance = failedPrefs;
        await plan(count: 2);
        await tapKey('marathon-start');
        await countdown();
        expect(await stored(), isNull);
        expect(submitted, isEmpty);
        expect(focusChanges.where((running) => running), isEmpty);
        expect(find.text(l10n.marathonStartFailed), findsOneWidget);
        expect(
          find.byKey(const ValueKey('marathon-started-message')),
          findsNothing,
          reason: 'A failed disk acknowledgement cannot claim a started plan',
        );
        expect(tester.takeException(), isNull);
        await plan(count: 2);
        await tapKey('marathon-start');
        await countdown();
        expect((await stored())?.marathon?.phase, MarathonPhase.focus);
        await stop();
        await unmount();

        await store.save(owner, writeRaceBreak);
        failWrite();
        final failedNext = await store.compareAndUpdateMarathon(
          owner,
          clientUuid: writeRaceBreak.clientUuid,
          completedSessions: writeRaceBreak.marathon!.completedSessions,
          phases: const {MarathonPhase.awaitingPresence},
          update: (previous) => ActiveTimerSession.start(
            clientUuid: 'never-started-after-failed-ack',
            categoryId: previous.categoryId,
            categoryName: previous.categoryName,
            durationMinutes: previous.durationMinutes,
            totalSeconds: previous.totalSeconds,
            marathon: previous.marathon!.nextFocus(),
            now: now,
          ),
        );
        expect(failedNext, isNull);
        expect((await stored())?.clientUuid, writeRaceBreak.clientUuid);
        expect(
          (await stored())?.marathon?.phase,
          MarathonPhase.awaitingPresence,
        );
        await store.clear(owner);
      }
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationChannel, null);
      debugDefaultTargetPlatformOverride = null;
      notificationService.debugResetInitialization();
    },
  );
}

/// A real asynchronous preferences acknowledgement, after its native
/// value and the plugin cache have changed. The hold is consumed once
/// so an atomic rollback can restore the preceding value immediately.
class _DelayedPreferencesStore extends InMemorySharedPreferencesStore {
  _DelayedPreferencesStore(super.data) : super.withData();

  String? _heldKey;
  MarathonPhase? _heldPhase;
  String? _failedKey;
  String? _throwingKey;
  Completer<void>? _release;
  bool isWaiting = false;
  Object? heldValue;

  void holdNextWrite(String key, {MarathonPhase? phase}) {
    _heldKey = key;
    _heldPhase = phase;
    _release = Completer<void>();
  }

  void release() => _release!.complete();

  void failNextWrite(String key) => _failedKey = key;

  void throwNextWrite(String key) => _throwingKey = key;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    final saved = await super.setValue(valueType, key, value);
    if (key == _throwingKey) {
      _throwingKey = null;
      throw StateError('simulated preferences write acknowledgement failure');
    }
    if (key == _failedKey) {
      _failedKey = null;
      return false;
    }
    if (key == _heldKey &&
        (_heldPhase == null ||
            (value is String &&
                (jsonDecode(value) as Map)['marathon']?['phase'] ==
                    _heldPhase!.name))) {
      _heldKey = null;
      heldValue = value;
      isWaiting = true;
      await _release!.future;
      isWaiting = false;
    }
    return saved;
  }
}
