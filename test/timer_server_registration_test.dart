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
  final category = CourseCategory.initialCategories().first;
  final now = DateTime.utc(2026, 11, 1, 10);
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({'notifications_enabled': false});
    LanguageService.instance.setLanguage(AppLanguage.tr);
  });

  Future<void> mount(
    WidgetTester tester,
    String owner, {
    required Future<bool> Function(String, int) register,
    Future<bool> Function(ActiveTimerSession, String)? confirm,
    void Function(bool, String, int)? onState,
    VoidCallback? onAbort,
    bool Function(String)? isPresenceValid,
  }) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
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
          authorizeStart: (_, _) async => true,
          registerNewFocus: register,
          onConfirmMarathonPresence: confirm,
          marathonPresenceStillValid: isPresenceValid,
          onTimerStateChanged: onState,
          onStartAborted: onAbort,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> countdown(WidgetTester tester) async {
    await tester.tap(
      find.text(LanguageService.instance.translate('btn_start')),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump();
    await tester.pump();
  }

  testWidgets('başlangıç kaydı normal, çevrimdışı ve Maraton akışları', (tester) async {
  for (final minutes in [25, 50]) {
      final owner = 'registration-normal-$minutes';
      final requested = <(String, int)>[];
      final gate = Completer<bool>();
      var running = 0;
      await mount(
        tester,
        owner,
        register: (uuid, duration) {
          requested.add((uuid, duration));
          return gate.future;
        },
        onState: (active, _, _) {
          if (active) running++;
        },
      );
      if (minutes == 50) {
        await tester.tap(find.byKey(const ValueKey('timer-duration-50')));
        await tester.pump();
      }
      await countdown(tester);
      expect(requested, hasLength(1));
      expect(requested.single.$2, minutes);
      expect(running, 0);
      expect(await TimerPersistence.instance.load(owner), isNull);
      gate.complete(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(running, 1);
      final saved = await TimerPersistence.instance.load(owner);
      expect(saved?.clientUuid, requested.single.$1);
      expect(saved?.durationMinutes, minutes);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
  }

  {
      const owner = 'registration-offline';
      final requested = <String>[];
      await mount(
        tester,
        owner,
        register: (uuid, duration) async {
          requested.add(uuid);
          return false;
        },
      );
      await countdown(tester);
      expect(requested, hasLength(1));
      expect(find.text(l10n.sessionStartUnverified), findsOneWidget);
      final offlineUuid = (await TimerPersistence.instance.load(owner))?.clientUuid;
      expect(offlineUuid, isNotNull);
      // The timed-out request may later be accepted: its UUID must not match
      // the locally running offline session.
      expect(offlineUuid, isNot(requested.single));
      await tester.tap(
        find.text(LanguageService.instance.translate('btn_pause')),
      );
      await tester.pump();
      await countdown(tester);
      expect(requested, hasLength(1));
      expect(
        (await TimerPersistence.instance.load(owner))?.clientUuid,
        offlineUuid,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
  }

  {
    const owner = 'registration-inactive';
    final gate = Completer<bool>();
    var running = 0, aborted = 0;
    await mount(
      tester,
      owner,
      register: (_, _) => gate.future,
      onState: (active, _, _) {
        if (active) running++;
      },
      onAbort: () => aborted++,
    );
    await countdown(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    gate.complete(true);
    await tester.pump();
    await tester.pump();
    expect(running, 0);
    expect(aborted, greaterThan(0));
    expect(await TimerPersistence.instance.load(owner), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  {
      const owner = 'registration-marathon';
      final previous = ActiveTimerSession.start(
        clientUuid: 'previous-focus',
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
      await TimerPersistence.instance.save(owner, previous);
      String? confirmedUuid;
      final registrations = <(String, int)>[];
      Future<bool> confirm(ActiveTimerSession _, String uuid) async {
        confirmedUuid = uuid;
        return true;
      }
      Future<bool> register(String uuid, int duration) async {
        registrations.add((uuid, duration));
        return registrations.length > 1;
      }
      await mount(tester, owner, confirm: confirm, register: register);
      await tester.ensureVisible(
        find.byKey(const ValueKey('marathon-presence-confirm')),
      );
      await tester.tap(find.byKey(const ValueKey('marathon-presence-confirm')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(registrations, hasLength(1));
      expect(registrations.single.$1, confirmedUuid);
      expect(registrations.single.$2, 25);
      var stored = await TimerPersistence.instance.load(owner);
      expect(stored?.clientUuid, previous.clientUuid);
      expect(stored?.marathon?.presenceClientUuid, confirmedUuid);
      expect(stored?.marathon?.completedSessions, 1);
      expect(find.text(l10n.marathonPresenceConnectionNeeded), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await mount(tester, owner, confirm: confirm, register: register);
      await tester.ensureVisible(find.byKey(const ValueKey('marathon-presence-confirm')));
      await tester.tap(find.byKey(const ValueKey('marathon-presence-confirm')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(registrations, hasLength(2));
      expect(registrations[1], registrations[0]);
      stored = await TimerPersistence.instance.load(owner);
      expect(stored?.clientUuid, confirmedUuid);
      expect(stored?.marathon?.completedSessions, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
  }
  {
    const owner = 'registration-marathon-expired';
    final previous = ActiveTimerSession.start(
      clientUuid: 'previous-expired-focus',
      categoryId: category.id,
      categoryName: category.name,
      durationMinutes: 25,
      totalSeconds: 1500,
      now: now.subtract(const Duration(minutes: 31)),
      marathon: MarathonProgress(
        totalSessions: 2,
        marathonUuid: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        completedSessions: 1,
        phase: MarathonPhase.awaitingPresence,
        breakEndsAt: now.subtract(const Duration(seconds: 5)),
      ),
    );
    await TimerPersistence.instance.save(owner, previous);
    var valid = true;
    var running = 0;
    await mount(
      tester, owner,
      confirm: (_, _) async => true,
      isPresenceValid: (_) => valid,
      onState: (active, _, _) { if (active) running++; },
      register: (_, _) async { valid = false; return true; },
    );
    await tester.ensureVisible(find.byKey(const ValueKey('marathon-presence-confirm')));
    await tester.tap(find.byKey(const ValueKey('marathon-presence-confirm')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(running, 0);
    expect(await TimerPersistence.instance.load(owner), isNull);
    expect(find.text(l10n.marathonPresenceExpired), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }
  });
}
