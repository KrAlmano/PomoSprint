import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/lock_screen_timer.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_lock_screen_platform.dart';

void main() {
  testWidgets('corrupt timer record survives restart and blocks replacement in both languages', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const owner = 'damaged-timer-owner';
    SharedPreferences.setMockInitialValues({TimerPersistence.keyFor(owner): '{broken'});
    var starts = 0;
    for (final locale in [const Locale('tr'), const Locale('en')]) {
      final l10n = await AppLocalizations.delegate.load(locale);
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TimerScreen(
          categories: CourseCategory.initialCategories(), sessionOwnerKey: owner,
          onOpenSettings: () {}, onSessionCompleted: (_) async => null,
          onTimerStateChanged: (running, _, _) { if (running) starts++; },
          lockScreenTimer: LockScreenTimer(platform: FakeLockScreenPlatform(), isEnabled: () async => false, categoryLabel: (name) => name),
        ),
      ));
      await tester.pump(); await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(l10n.timerRecordCorrupt), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('timer-start-pause')));
      await tester.pump(const Duration(seconds: 5));
      expect(starts, 0);
      expect((await SharedPreferences.getInstance()).getString(TimerPersistence.keyFor(owner)), '{broken');
      await tester.pumpWidget(const SizedBox.shrink()); await tester.pump();
    }
    expect(tester.takeException(), isNull);
  });
}
