import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/lock_screen_timer.dart';
import 'package:pomodoro/services/session_queue.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_lock_screen_platform.dart';

void main() {
  testWidgets('failed normal completion survives restart in both locales', (tester) async {
    for (final locale in [const Locale('tr'), const Locale('en')]) {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final owner = 'restart-${locale.languageCode}';
      final category = CourseCategory.initialCategories().first;
      final session = ActiveTimerSession.start(
        clientUuid: 'kept-${locale.languageCode}',
        categoryId: category.id,
        categoryName: category.name,
        durationMinutes: 25,
        totalSeconds: 1500,
        now: DateTime.now().subtract(const Duration(minutes: 30)),
      );

      await TimerPersistence.instance.save(owner, session);

      final calls = <ActiveTimerSession>[];
      final first = Completer<SessionSubmitResult?>();
      final second = Completer<SessionSubmitResult?>();
      Widget app() => MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TimerScreen(
          categories: [category],
          sessionOwnerKey: owner,
          onOpenSettings: () {},
          onSessionCompleted: (entry) {
            calls.add(entry);
            return calls.length == 1 ? first.future : second.future;
          },
          lockScreenTimer: LockScreenTimer(
            platform: FakeLockScreenPlatform(),
            isEnabled: () async => true,
            categoryLabel: (name) => name,
          ),
        ),
      );

      await tester.pumpWidget(app());

      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      first.completeError(StateError('disk full'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(find.textContaining(l10n.sessionNotSavedTitle), findsOneWidget);
      expect((await TimerPersistence.instance.load(owner))?.clientUuid, session.clientUuid);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await tester.pumpWidget(app());

      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls.map((entry) => entry.clientUuid), [session.clientUuid, session.clientUuid]);
      second.complete(const SessionSubmitSuccess(minutes: 25, totalPoints: 5));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(await TimerPersistence.instance.load(owner), isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
