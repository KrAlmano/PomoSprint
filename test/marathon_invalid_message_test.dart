import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/models/marathon_progress.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/lock_screen_timer.dart';
import 'package:pomodoro/services/session_queue.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_lock_screen_platform.dart';

void main() {
  // TimerPersistence's asynchronous lock stays in one fake-async zone while
  // both locales and all first-focus outcomes use independent owner records.
  testWidgets(
    'TR/EN invalid Marathon feedback preserves rewards without claiming a rejected focus was saved',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final store = TimerPersistence.instance;
      final category = CourseCategory.initialCategories().first;
      final now = DateTime(2026, 10, 28, 12);
      final outcomes = [
        (
          name: 'invalid-with-rewards',
          result: SessionSubmitSuccess.fromResponse({
            'total_points': 5,
            'coins_earned': 20,
            'marathon_presence_invalid': true,
            'marathon_bonus_points': 0,
          }, minutes: 25),
          accepted: true,
        ),
        (
          name: 'invalid-with-zero-rewards',
          result: SessionSubmitSuccess.fromResponse({
            'total_points': 0,
            'coins_earned': 0,
            'daily_limit_reached': true,
            'marathon_invalid': true,
            'marathon_bonus_points': 0,
          }, minutes: 25),
          accepted: true,
        ),
        (
          name: 'accepted-with-missing-receipt',
          result: const SessionSubmitSuccess(
            minutes: 25,
            totalPoints: 5,
            coinsEarned: 20,
          ),
          accepted: true,
        ),
        (
          name: 'rejected-first-focus',
          result: const SessionSubmitRejected(SessionReason.invalidData),
          accepted: false,
        ),
      ];

      for (final locale in const [Locale('tr'), Locale('en')]) {
        final l10n = await AppLocalizations.delegate.load(locale);
        // The message explains preserved regular rewards and no Marathon
        // bonus, rather than asserting that this particular attempt was saved.
        expect(
          l10n.marathonStoppedInvalid,
          contains(
            locale.languageCode == 'tr' ? 'normal puan' : 'regular point',
          ),
        );
        expect(
          l10n.marathonStoppedInvalid,
          contains(locale.languageCode == 'tr' ? 'kum' : 'sand'),
        );
        expect(
          l10n.marathonStoppedInvalid,
          contains(
            locale.languageCode == 'tr' ? 'ek Maraton puanı' : 'marathon bonus',
          ),
        );
        expect(
          l10n.marathonStoppedInvalid,
          isNot(
            contains(
              locale.languageCode == 'tr'
                  ? 'Pomodoro kaydedildi'
                  : 'Your Pomodoro was saved',
            ),
          ),
        );

        for (final outcome in outcomes) {
          SharedPreferences.setMockInitialValues({
            'notifications_enabled': false,
          });
          final owner = '${locale.languageCode}-${outcome.name}';
          final first = ActiveTimerSession.start(
            clientUuid: 'first-$owner',
            categoryId: category.id,
            categoryName: category.name,
            durationMinutes: 25,
            totalSeconds: 1500,
            now: now.subtract(const Duration(minutes: 25)),
            marathon: const MarathonProgress(
              marathonUuid: 'a92e8a1a-37c4-4c8c-af0c-112768b2b6d0',
              totalSessions: 2,
            ),
          );
          expect(first.marathon!.completedSessions, 0);
          await store.save(owner, first);
          final submitted = <String>[];
          var confirmations = 0;
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: TimerScreen(
                categories: [category],
                sessionOwnerKey: owner,
                onOpenSettings: () {},
                clock: () => now,
                lockScreenTimer: LockScreenTimer(
                  platform: FakeLockScreenPlatform(),
                  isEnabled: () async => false,
                  categoryLabel: (name) => name,
                  clock: () => now,
                ),
                onSessionCompleted: (session) async {
                  submitted.add(session.clientUuid);
                  return outcome.result;
                },
                onConfirmMarathonPresence: (_, _) async {
                  confirmations++;
                  return true;
                },
              ),
            ),
          );
          for (var frame = 0; frame < 12; frame++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(tester.takeException(), isNull, reason: owner);
          expect(submitted, [first.clientUuid], reason: owner);
          expect(await store.load(owner), isNull, reason: owner);
          expect(confirmations, 0, reason: owner);
          expect(find.byKey(const ValueKey('marathon-break')), findsNothing);
          expect(find.byKey(const ValueKey('marathon-presence')), findsNothing);
          expect(
            find.byKey(const ValueKey('marathon-active-progress')),
            findsNothing,
          );
          expect(
            find.text(
              outcome.accepted
                  ? l10n.marathonStoppedInvalid
                  : l10n.marathonStoppedRejected,
            ),
            findsWidgets,
            reason: owner,
          );
          expect(
            find.text(
              outcome.accepted
                  ? l10n.marathonStoppedRejected
                  : l10n.marathonStoppedInvalid,
            ),
            findsNothing,
            reason: owner,
          );
          expect(
            tester
                .widget<ButtonStyleButton>(
                  find.byKey(const ValueKey('timer-start-pause')),
                )
                .onPressed,
            isNotNull,
            reason: 'A stopped plan must leave normal START available: $owner',
          );
          await tester.pump(const Duration(minutes: 6));
          expect(submitted, [first.clientUuid], reason: owner);
          expect(confirmations, 0, reason: owner);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      }
    },
  );
}
