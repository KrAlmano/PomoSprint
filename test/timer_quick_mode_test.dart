import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/models/marathon_progress.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/lock_screen_timer.dart';
import 'package:pomodoro/services/session_queue.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_lock_screen_platform.dart';

// Ürün her derlemede gerçek süreli; kısa sayaç yalnızca widget testinde
// açık parametreyle simüle edilir ve sunucuya/kuyruğa verilmez.
// (TimerPersistence tekil olduğu için dosyada tek
// testWidgets var; bkz. timer_screen_test.dart.)
void main() {
  const owner = 'u-quick';
  final category = CourseCategory.initialCategories().first;

  testWidgets('kısa sayaç 5/10 sn, test metni yok ve kayıt korumaları sürer', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    // Dikey ekran (yatayda süre çipleri gizlenir).
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    final lang = LanguageService.instance;
    final lockScreen = LockScreenTimer(
      platform: FakeLockScreenPlatform(),
      isEnabled: () async => true,
      categoryLabel: (name) => name,
    );
    final submissions = <ActiveTimerSession>[];
    final presenceCalls = <String>[];

    Future<void> mount({bool? quick}) async {
      TimerScreen screen({bool? quickTimer}) => TimerScreen(
        key: UniqueKey(),
        categories: [category],
        sessionOwnerKey: owner,
        onOpenSettings: () {},
        onSessionCompleted: (session) async {
          submissions.add(session);
          return const SessionSubmitSuccess(
            minutes: 25,
            totalPoints: 5,
            coinsEarned: 20,
          );
        },
        onTimerStateChanged: (running, name, minutes) =>
            presenceCalls.add('focus:$running'),
        onMarathonBreakChanged: (onBreak, seconds) =>
            presenceCalls.add('break:$onBreak'),
        onConfirmMarathonPresence: (previous, next) async {
          presenceCalls.add('confirm');
          return true;
        },
        lockScreenTimer: lockScreen,
        // Null deliberately exercises the actual product constructor default.
        quickTimer: quickTimer ?? false,
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen(quickTimer: quick),
        ),
      );
      // Cihazdaki kayıt (varsa) geri yüklenir; süresi dolduysa tamamlanır.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> unmount() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    Future<Map<String, dynamic>?> stored() async {
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(TimerPersistence.keyFor(owner));
      return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
    }

    ActiveTimerSession finished(String uuid, {required int totalSeconds}) =>
        ActiveTimerSession.start(
          clientUuid: uuid,
          categoryId: category.id,
          categoryName: category.name,
          durationMinutes: 25,
          totalSeconds: totalSeconds,
          now: DateTime.now().subtract(const Duration(minutes: 30)),
        );

    // 1) Normal derleme (debug dahil): gerçek süre, rozet yok.
    final defaults = TimerScreen(
      categories: [category],
      sessionOwnerKey: owner,
      onOpenSettings: () {},
      onSessionCompleted: (session) async => null,
    );
    expect(defaults.quickTimer, isFalse);
    await mount();
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text(l10n.timerQuickTestBadge), findsNothing);
    await unmount();

    // 2) Kısa sayaç 5/10 sn, görsel veya erişilebilirlikte test metni yok.
    await mount(quick: true);
    expect(find.text(l10n.timerQuickTestBadge), findsNothing);
    expect(find.bySemanticsLabel(l10n.timerQuickTestSemantics), findsNothing);
    expect(find.text('00:05'), findsOneWidget);
    await tester.tap(find.textContaining('50 '));
    await tester.pump();
    expect(find.text('00:10'), findsOneWidget);
    await tester.tap(find.textContaining('25 '));
    await tester.pump();
    expect(find.text('00:05'), findsOneWidget);

    // Başlayan seans sunucuya bildirilecek süreyi (25) korur, sayaç kısadır.
    await tester.tap(find.text(lang.translate('btn_start')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text(lang.translate('btn_pause')), findsOneWidget);
    final record = await stored();
    expect(record?['duration_minutes'], 25);
    expect(record?['total_seconds'], 5);
    expect(find.text(l10n.timerQuickTestBadge), findsNothing);
    await unmount();

    // Süresi dolmuş kısa seans kaydedilmez; test açıklaması da gösterilmez.
    await TimerPersistence.instance.save(
      owner,
      finished('quick-done', totalSeconds: 5),
    );
    await mount(quick: true);
    expect(submissions, isEmpty);
    expect(find.byType(SessionCompletedDialog), findsOneWidget);
    expect(find.text(l10n.sessionResultTestNotSaved), findsNothing);
    expect(find.text(l10n.sessionResultSaving), findsNothing);
    expect(await stored(), isNull);
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pump(const Duration(milliseconds: 300));
    await unmount();

    // 3) Normal derlemede geri yüklenen eski test seansı (eski debug
    // derlemesinin 5 sn'lik seansı) da gönderilmez; sonraki seans gerçek süreli.
    await TimerPersistence.instance.save(
      owner,
      finished('old-debug', totalSeconds: 5),
    );
    await mount(quick: false);
    expect(submissions, isEmpty);
    expect(find.text(l10n.sessionResultTestNotSaved), findsNothing);
    expect(await stored(), isNull);
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text(l10n.timerQuickTestBadge), findsNothing);
    await unmount();

    // 4) Hızlı test derlemesinde geri yüklenen GERÇEK seans yine gönderilir.
    await TimerPersistence.instance.save(
      owner,
      finished('real-done', totalSeconds: 25 * 60),
    );
    await mount(quick: true);
    expect(submissions.map((s) => s.clientUuid), ['real-done']);
    expect(find.text(l10n.sessionResultTestNotSaved), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.sessionResultPoints(5)), findsOneWidget);
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pump(const Duration(milliseconds: 300));
    await unmount();

    // Legacy accelerated markers are never restored as focus/break/presence,
    // even when the stored duration was changed to a full 25-minute session.
    final submissionCount = submissions.length;
    for (final phase in <MarathonPhase?>[null, ...MarathonPhase.values]) {
      presenceCalls.clear();
      final previous = ActiveTimerSession.start(
        clientUuid: 'legacy-${phase?.name ?? 'single'}',
        categoryId: category.id,
        categoryName: category.name,
        durationMinutes: 25,
        totalSeconds: 1500,
        recordAccelerated: true,
        now: DateTime.now().subtract(const Duration(minutes: 30)),
        marathon: phase == null
            ? null
            : MarathonProgress(
                totalSessions: 2,
                marathonUuid: 'cf091f18-1d45-4e82-9377-d55b92753c2c',
                completedSessions: phase == MarathonPhase.finished ? 2 : 1,
                phase: phase,
                breakEndsAt: DateTime.now(),
              ),
      );
      await TimerPersistence.instance.save(owner, previous);
      await mount();
      expect(await stored(), isNull, reason: '$phase legacy storage cleared');
      expect(find.text('25:00'), findsOneWidget);
      expect(submissions.length, submissionCount);
      expect(presenceCalls, isEmpty, reason: '$phase sends no presence');
      expect(find.byType(SessionCompletedDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount();
    }
    semantics.dispose();
  });
}
