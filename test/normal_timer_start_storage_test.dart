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
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'support/fake_lock_screen_platform.dart';

class _Prefs extends InMemorySharedPreferencesStore {
  _Prefs(super.data) : super.withData();
  String? keyToFail;
  bool throwFailure = false;
  bool writeFirst = false;
  String? keyToHold;
  Completer<void>? held;
  Completer<void>? release;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == keyToFail) {
      keyToFail = null;
      if (writeFirst) await super.setValue(type, key, value);
      if (throwFailure) throw StateError('simulated disk full');
      return false;
    }
    final result = await super.setValue(type, key, value);
    if (key == keyToHold) {
      keyToHold = null;
      held!.complete();
      await release!.future;
    }
    return result;
  }
}

void main() {
  testWidgets('normal start and resume require durable storage before running', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'notifications_enabled': false});
    final category = CourseCategory.initialCategories().first;
    final prefs = _Prefs(await SharedPreferencesStorePlatform.instance.getAll());
    SharedPreferencesStorePlatform.instance = prefs;
    var started = 0, aborted = 0, submitted = 0;
    var now = DateTime.now();
    Future<void> drain() async {
      await tester.pump(); await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
    Future<void> countdown() async {
      for (var i = 0; i < 4; i++) {
        now = now.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      await drain();
    }
    Widget app(String owner, Locale locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TimerScreen(
        categories: [category], sessionOwnerKey: owner,
        clock: () => now, onOpenSettings: () {},
        onSessionCompleted: (_) async { submitted++; return null; },
        authorizeStart: (_, _) async => true,
        registerNewFocus: (_, _) async => true,
        onStartAborted: () => aborted++,
        onTimerStateChanged: (running, _, _) { if (running) started++; },
        lockScreenTimer: LockScreenTimer(
          platform: FakeLockScreenPlatform(), isEnabled: () async => false,
          categoryLabel: (name) => name,
        ),
      ),
    );
    Future<void> startTimer() async {
      final button = find.byKey(const ValueKey('timer-start-pause'));
      await tester.ensureVisible(button); await tester.pump();
      await tester.tap(button); await tester.pump();
      await countdown();
    }
    for (final locale in [const Locale('tr'), const Locale('en')]) {
      final owner = 'start-${locale.languageCode}';
      await LanguageService.instance.setLanguage(locale.languageCode == 'tr' ? AppLanguage.tr : AppLanguage.en);
      await tester.pumpWidget(app(owner, locale)); await drain();
      final l10n = await AppLocalizations.delegate.load(locale);
      for (final throws in [false, true]) {
        prefs.keyToFail = 'flutter.${TimerPersistence.keyFor(owner)}';
        prefs.throwFailure = throws;
        prefs.writeFirst = throws;
        final previousAbort = aborted;
        await startTimer();
        expect(started, 0, reason: 'failed native storage must not start the timer');
        expect(submitted, 0);
        expect(aborted, greaterThan(previousAbort));
        expect(await TimerPersistence.instance.load(owner), isNull);
        expect(find.text(l10n.timerStartStorageError), findsOneWidget);
      }
      await startTimer();
      expect(started, 1);
      expect((await TimerPersistence.instance.load(owner))?.isRunning, isTrue);
      for (final throws in [false, true]) {
        prefs.keyToFail = 'flutter.${TimerPersistence.keyFor(owner)}';
        prefs.throwFailure = throws;
        prefs.writeFirst = throws;
        final button = find.byKey(const ValueKey('timer-start-pause'));
        await tester.ensureVisible(button); await tester.pump();
        await tester.tap(button); await drain();
        await tester.pump(const Duration(milliseconds: 500));
        final retained = await TimerPersistence.instance.load(owner);
        expect(retained?.isRunning, isTrue);
        expect(retained?.pauseUsedCount, 0);
        expect(find.text(l10n.timerPauseStorageError), findsOneWidget);
      }
      final pause = find.byKey(const ValueKey('timer-start-pause'));
      await tester.ensureVisible(pause); await tester.pump();
      await tester.tap(pause); await drain();
      final stopped = await TimerPersistence.instance.load(owner);
      expect(stopped?.isRunning, isFalse);
      expect(stopped?.pauseUsedCount, 1);
      await tester.pumpWidget(const SizedBox.shrink()); await drain();
      await TimerPersistence.instance.clear(owner);
      started = 0;
    }

    const owner = 'resume-owner';
    final paused = ActiveTimerSession.start(
      clientUuid: 'existing-pause', categoryId: category.id, categoryName: category.name,
      durationMinutes: 25, totalSeconds: 1500, now: now.subtract(const Duration(minutes: 2)),
    ).pauseAt(now);
    await TimerPersistence.instance.save(owner, paused);
    await LanguageService.instance.setLanguage(AppLanguage.tr);
    await tester.pumpWidget(app(owner, const Locale('tr'))); await drain();
    prefs.keyToFail = 'flutter.${TimerPersistence.keyFor(owner)}';
    prefs.throwFailure = false;
    prefs.writeFirst = false;
    await startTimer();
    expect(started, 0);
    final retained = await TimerPersistence.instance.load(owner);
    expect(retained?.clientUuid, paused.clientUuid);
    expect(retained?.isRunning, isFalse);
    expect(retained?.pausedRemainingSeconds, paused.pausedRemainingSeconds);
    await tester.pumpWidget(const SizedBox.shrink()); await drain();
    await TimerPersistence.instance.clear(owner);

    const marathonOwner = 'marathon-pause-owner';
    final marathon = ActiveTimerSession.start(
      clientUuid: 'marathon-focus', categoryId: category.id,
      categoryName: category.name, durationMinutes: 25, totalSeconds: 1500,
      now: now,
      marathon: const MarathonProgress(
        totalSessions: 2,
        marathonUuid: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      ),
    );
    await TimerPersistence.instance.save(marathonOwner, marathon);
    await tester.pumpWidget(app(marathonOwner, const Locale('tr'))); await drain();
    prefs.keyToFail = 'flutter.${TimerPersistence.keyFor(marathonOwner)}';
    prefs.throwFailure = true;
    prefs.writeFirst = true;
    final marathonPause = find.byKey(const ValueKey('timer-start-pause'));
    await tester.ensureVisible(marathonPause); await tester.pump();
    await tester.tap(marathonPause); await drain();
    await tester.pump(const Duration(milliseconds: 500));
    final marathonRetained = await TimerPersistence.instance.load(marathonOwner);
    expect(marathonRetained?.isRunning, isTrue);
    expect(marathonRetained?.pauseUsedCount, 0);
    expect(marathonRetained?.marathon?.marathonUuid, marathon.marathon?.marathonUuid);
    final l10nTr = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(find.text(l10nTr.timerPauseStorageError), findsOneWidget);
    await tester.tap(marathonPause); await drain();
    final marathonStopped = await TimerPersistence.instance.load(marathonOwner);
    expect(marathonStopped?.isRunning, isFalse);
    expect(marathonStopped?.pauseUsedCount, 1);
    expect(marathonStopped?.marathon?.completedSessions, 0);
    // A failed resume must leave the durable marathon paused.
    prefs.keyToFail = 'flutter.${TimerPersistence.keyFor(marathonOwner)}';
    prefs.throwFailure = true;
    prefs.writeFirst = true;
    await startTimer();
    final failedResume = await TimerPersistence.instance.load(marathonOwner);
    expect(failedResume?.isRunning, isFalse);
    expect(failedResume?.clientUuid, marathon.clientUuid);
    expect(find.text(l10nTr.timerStartStorageError), findsOneWidget);
    prefs.keyToHold = 'flutter.${TimerPersistence.keyFor(marathonOwner)}';
    prefs.held = Completer<void>(); prefs.release = Completer<void>();
    await startTimer();
    await prefs.held!.future;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    prefs.release!.complete();
    await drain();
    expect((await TimerPersistence.instance.load(marathonOwner))?.isRunning, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await drain();
    await startTimer();
    expect((await TimerPersistence.instance.load(marathonOwner))?.isRunning, isTrue);
    await tester.pumpWidget(const SizedBox.shrink()); await drain();
    await TimerPersistence.instance.clear(marathonOwner);
    started = 0;

    // An account switch during the native disk write prevents A's timer from
    // starting in B and rolls back the just-written A draft.
    const oldOwner = 'late-a';
    await tester.pumpWidget(app(oldOwner, const Locale('tr'))); await drain();
    prefs.keyToHold = 'flutter.${TimerPersistence.keyFor(oldOwner)}';
    prefs.held = Completer<void>(); prefs.release = Completer<void>();
    final button = find.byKey(const ValueKey('timer-start-pause'));
    await tester.ensureVisible(button); await tester.pump();
    await tester.tap(button); await tester.pump();
    await countdown();
    await prefs.held!.future;
    await tester.pumpWidget(app('late-b', const Locale('tr'))); await drain();
    prefs.release!.complete(); await drain();
    expect(started, 0);
    expect(await TimerPersistence.instance.load(oldOwner), isNull);
    expect(await TimerPersistence.instance.load('late-b'), isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink()); await drain();
  });
}
