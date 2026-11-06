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
  testWidgets('failed normal completion retains its UUID and blocks a new timer until retry', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    const owner = 'failure-owner';
    final category = CourseCategory.initialCategories().first;
    final completed = ActiveTimerSession.start(
      clientUuid: 'completed-session',
      categoryId: category.id,
      categoryName: category.name,
      durationMinutes: 25,
      totalSeconds: 1500,
      now: DateTime.now().subtract(const Duration(minutes: 30)),
    );
    await TimerPersistence.instance.save(owner, completed);
    final calls = <ActiveTimerSession>[];
    final first = Completer<SessionSubmitResult?>();
    final second = Completer<SessionSubmitResult?>();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TimerScreen(
        categories: [category],
        sessionOwnerKey: owner,
        onOpenSettings: () {},
        onSessionCompleted: (session) {
          calls.add(session);
          return calls.length == 1 ? first.future : second.future;
        },
        lockScreenTimer: LockScreenTimer(
          platform: FakeLockScreenPlatform(),
          isEnabled: () async => true,
          categoryLabel: (name) => name,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, hasLength(1));
    expect(find.byType(SessionCompletedDialog), findsOneWidget);
    final buttonWhileSaving = tester.widget<ElevatedButton>(find.byKey(const ValueKey('timer-start-pause')));
    expect(buttonWhileSaving.onPressed, isNull);
    first.completeError(StateError('storage write failed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(find.textContaining(l10n.sessionNotSavedTitle), findsOneWidget);
    expect((await TimerPersistence.instance.load(owner))?.clientUuid, 'completed-session');
    await tester.tap(find.text(l10n.sessionCompletedOk));
    await tester.pump(const Duration(milliseconds: 300));
    final retry = find.byKey(const ValueKey('marathon-retry-save'));
    expect(retry, findsOneWidget);
    expect(find.text(l10n.timerResetBtn), findsNothing);
    tester.view.physicalSize = const Size(2400, 1200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('timer-landscape-reset')), findsNothing);
    tester.view.physicalSize = const Size(1200, 2400);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    expect(calls.map((s) => s.clientUuid), ['completed-session', 'completed-session']);
    expect(calls.last.foregroundSeconds, calls.first.foregroundSeconds);
    second.complete(const SessionSubmitSuccess(minutes: 25, totalPoints: 5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(await TimerPersistence.instance.load(owner), isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
