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
  testWidgets('late failure after owner change stays with the old owner', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final category = CourseCategory.initialCategories().first;
    final old = ActiveTimerSession.start(
      clientUuid: 'owner-a-session', categoryId: category.id,
      categoryName: category.name, durationMinutes: 25, totalSeconds: 1500,
      now: DateTime.now().subtract(const Duration(minutes: 30)),
    );
    await TimerPersistence.instance.save('owner-a', old);
    final gate = Completer<SessionSubmitResult?>();
    var calls = 0;
    Widget app(String owner) => MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TimerScreen(
        categories: [category], sessionOwnerKey: owner,
        onOpenSettings: () {},
        onSessionCompleted: (_) { calls++; return gate.future; },
        lockScreenTimer: LockScreenTimer(
          platform: FakeLockScreenPlatform(), isEnabled: () async => true,
          categoryLabel: (name) => name,
        ),
      ),
    );
    await tester.pumpWidget(app('owner-a'));
    await tester.pump(); await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    await tester.tap(find.text(l10n.sessionCompletedOk));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(app('owner-b'));
    await tester.pump();
    gate.completeError(StateError('storage failed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 1);
    expect(find.byKey(const ValueKey('marathon-retry-save')), findsNothing);
    expect((await TimerPersistence.instance.load('owner-a'))?.clientUuid, old.clientUuid);
    expect(await TimerPersistence.instance.load('owner-b'), isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
