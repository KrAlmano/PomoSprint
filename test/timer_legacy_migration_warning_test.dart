import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/lock_screen_timer.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'support/fake_lock_screen_platform.dart';

class _RemoveFails extends InMemorySharedPreferencesStore {
  _RemoveFails(super.data) : super.withData();
  @override
  Future<bool> remove(String key) async => key == 'flutter.${TimerPersistence.keyFor('old-email')}' ? false : super.remove(key);
}

void main() {
  testWidgets('failed legacy migration warns and blocks the timer without deleting either copy', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final category = CourseCategory.initialCategories().first;
    final session = ActiveTimerSession.start(
      clientUuid: 'old-session', categoryId: category.id, categoryName: category.name,
      durationMinutes: 25, totalSeconds: 1500, now: DateTime.now(),
    );
    final raw = jsonEncode(session.toJson());
    SharedPreferencesStorePlatform.instance = _RemoveFails({'flutter.${TimerPersistence.keyFor('old-email')}': raw});
    var starts = 0;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TimerScreen(
        categories: [category], sessionOwnerKey: 'new-uid', legacySessionOwnerKey: 'old-email',
        onOpenSettings: () {}, onSessionCompleted: (_) async => null,
        onTimerStateChanged: (running, _, _) { if (running) starts++; },
        lockScreenTimer: LockScreenTimer(platform: FakeLockScreenPlatform(), isEnabled: () async => false, categoryLabel: (name) => name),
      ),
    ));
    await tester.pump(); await tester.pump(); await tester.pump(const Duration(milliseconds: 500));
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(find.text(l10n.timerRecordCorrupt), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('timer-start-pause')));
    await tester.pump(const Duration(seconds: 5));
    expect(starts, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(TimerPersistence.keyFor('old-email')), raw);
    expect(prefs.getString(TimerPersistence.keyFor('new-uid')), isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
