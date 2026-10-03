import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/lock_screen_timer.dart';
import 'package:pomodoro/services/session_queue.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_lock_screen_platform.dart';

// UX-02 / UX-15: süre dolunca diyalog gönderimin sonucunu bekler (önce
// "kaydediliyor", sonra RPC'nin puan/kum/serisi); ön planda biten seans
// titreşimle duyurulur, arka planda bitende titreşim olmaz. Cihazdaki kayıt
// ancak gönderim bitince silinir. (TimerPersistence tekil olduğu için
// dosyada tek testWidgets var; bkz. timer_screen_test.dart.)
void main() {
  const owner = 'u-result';
  final category = CourseCategory.initialCategories().first;

  testWidgets('seans sonu: titreşim, kaydediliyor → sunucu sonucu', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));

    final platformCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call.method);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    final lockScreen = LockScreenTimer(
      platform: FakeLockScreenPlatform(),
      isEnabled: () async => true,
      categoryLabel: (name) => name,
    );
    final submissions = <ActiveTimerSession>[];
    var submission = Completer<SessionSubmitResult?>();

    ActiveTimerSession finished(String uuid) => ActiveTimerSession.start(
          clientUuid: uuid,
          categoryId: category.id,
          categoryName: category.name,
          durationMinutes: 25,
          totalSeconds: 25 * 60,
          now: DateTime.now().subtract(const Duration(minutes: 30)),
        );

    Future<void> mount() async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TimerScreen(
          categories: [category],
          sessionOwnerKey: owner,
          onOpenSettings: () {},
          onSessionCompleted: (session) {
            submissions.add(session);
            return submission.future;
          },
          lockScreenTimer: lockScreen,
        ),
      ));
      // Kayıt geri yüklenir; süresi dolduğu için hemen tamamlanır.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<String?> stored() async {
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(TimerPersistence.keyFor(owner));
    }

    // 1) Ön planda biten seans.
    await TimerPersistence.instance.save(owner, finished('done-1'));
    await mount();
    expect(submissions.map((s) => s.clientUuid), ['done-1']);
    expect(platformCalls, contains('HapticFeedback.vibrate'));
    expect(find.byType(SessionCompletedDialog), findsOneWidget);
    expect(find.text(l10n.sessionResultSaving), findsOneWidget);
    // Gönderim bitmeden cihazdaki kayıt silinmez.
    expect(await stored(), isNotNull);

    submission.complete(const SessionSubmitSuccess(
      minutes: 25,
      basePoints: 5,
      totalPoints: 5,
      coinsEarned: 20,
      streak: 2,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.sessionResultSaving), findsNothing);
    expect(find.text(l10n.sessionResultPoints(5)), findsOneWidget);
    expect(find.text(l10n.sessionResultCoins(20)), findsOneWidget);
    expect(find.text(l10n.sessionResultStreak(2)), findsOneWidget);
    expect(await stored(), isNull);

    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    // 2) Arka planda biten seans titreşim üretmez (bildirim yolu kullanılır).
    platformCalls.clear();
    submission = Completer<SessionSubmitResult?>();
    // inactive: sayaç için ön plan değil; paused'dan farklı olarak test
    // bağlamı kare üretmeye devam eder.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await TimerPersistence.instance.save(owner, finished('done-2'));
    await mount();
    expect(submissions.map((s) => s.clientUuid), ['done-1', 'done-2']);
    expect(platformCalls, isNot(contains('HapticFeedback.vibrate')));
    submission.complete(const SessionSubmitQueued(reasonCode: SessionReason.network, pendingCount: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.sessionQueuedOffline), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
