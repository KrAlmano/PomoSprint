import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/models/marathon_progress.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/lock_screen_timer.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_lock_screen_platform.dart';

void main() {
  testWidgets(
    'late normal and Marathon authorization cannot run in background or leave reservations',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      SharedPreferences.setMockInitialValues({'notifications_enabled': false});
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final category = CourseCategory.initialCategories().first;
      final now = DateTime.utc(2026, 10, 28, 0);
      final failures = <String>[];
      var started = 0, aborted = 0;
      final authorize = Completer<bool>();
      var authorizeCalls = 0;
      Future<void> pump() async {
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }

      Future<void> mount({
        required String owner,
        Future<bool> Function(String, int)? onAuthorize,
        Future<bool> Function(ActiveTimerSession, String)? onConfirm,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(owner),
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TimerScreen(
              categories: [category],
              sessionOwnerKey: owner,
              onOpenSettings: () {},
              onSessionCompleted: (_) async => null,
              clock: () => now,
              lockScreenTimer: LockScreenTimer(
                platform: FakeLockScreenPlatform(),
                isEnabled: () async => false,
                categoryLabel: (s) => s,
              ),
              authorizeStart: onAuthorize,
              onConfirmMarathonPresence: onConfirm,
              onStartAborted: () => aborted++,
              onTimerStateChanged: (running, _, _) {
                if (running) started++;
              },
            ),
          ),
        );
        await pump();
      }

      await mount(
        owner: 'audit-normal',
        onAuthorize: (_, _) {
          authorizeCalls++;
          return authorize.future;
        },
      );
      await tester.tap(
        find.text(LanguageService.instance.translate('btn_start')),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await pump();
      expect(authorizeCalls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      authorize.complete(true);
      await pump();
      if (started != 0) {
        failures.add('normal authorization ACK started a timer while inactive');
      }
      if (aborted == 0) {
        failures.add(
          'normal inactive authorization did not release its reservation',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await pump();
      await TimerPersistence.instance.clear('audit-normal');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      started = 0;
      aborted = 0;

      final previous = ActiveTimerSession.start(
        clientUuid: 'completed-focus',
        categoryId: category.id,
        categoryName: category.name,
        durationMinutes: 25,
        totalSeconds: 1500,
        now: now.subtract(const Duration(minutes: 31)),
        marathon: MarathonProgress(
          totalSessions: 2,
          marathonUuid: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          completedSessions: 1,
          phase: MarathonPhase.awaitingPresence,
          breakEndsAt: now.subtract(const Duration(seconds: 5)),
        ),
      );
      await TimerPersistence.instance.save('audit-marathon', previous);
      final confirmed = Completer<bool>();
      var confirmCalls = 0;
      await mount(
        owner: 'audit-marathon',
        onConfirm: (_, _) {
          confirmCalls++;
          return confirmed.future;
        },
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('marathon-presence-confirm')),
      );
      await tester.tap(find.byKey(const ValueKey('marathon-presence-confirm')));
      await pump();
      expect(confirmCalls, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      confirmed.complete(true);
      await pump();
      if (started != 0) {
        failures.add('Marathon authorization ACK started a timer while paused');
      }
      if (aborted == 0) {
        failures.add(
          'Marathon paused authorization did not release its reservation',
        );
      }
      final retained = await TimerPersistence.instance.load('audit-marathon');
      expect(
        retained?.clientUuid,
        'completed-focus',
        reason: 'previous completed focus remains the break carrier',
      );
      expect(retained?.marathon?.phase, MarathonPhase.awaitingPresence);
      await tester.pumpWidget(const SizedBox.shrink());
      await pump();
      expect(failures, isEmpty, reason: failures.join('; '));
    },
  );
}
