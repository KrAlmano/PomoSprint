import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/lock_screen_timer.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_lock_screen_platform.dart';

// Sayaç ekranının her durum geçişi kilit ekranı sayacına yansımalı:
// açılışta geri yükleme, duraklat, devam, ön plana dönüş, sıfırla, kapanış.
// (TimerPersistence tekil olduğu için dosyada tek testWidgets var; bkz.
// timer_screen_test.dart.)
void main() {
  const owner = 'u-lock';
  final category = CourseCategory.initialCategories().first;

  testWidgets('durum geçişleri kilit ekranına yansır', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    final platform = FakeLockScreenPlatform();
    final lockScreen = LockScreenTimer(
      platform: platform,
      isEnabled: () async => true,
      categoryLabel: (name) => name,
    );
    final running = ActiveTimerSession.start(
      clientUuid: 'run-1',
      categoryId: category.id,
      categoryName: category.name,
      durationMinutes: 25,
      totalSeconds: 25 * 60,
      now: DateTime.now().subtract(const Duration(minutes: 10)),
    );
    await TimerPersistence.instance.save(owner, running);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TimerScreen(
        categories: [category],
        sessionOwnerKey: owner,
        onOpenSettings: () {},
        onSessionCompleted: (_) async {},
        lockScreenTimer: lockScreen,
      ),
    ));
    await tester.pump();
    await tester.pump();

    // 1) Açılışta süren seans geri yüklenir ve kilit ekranında akar.
    expect(platform.calls, ['show:running:run-1:same']);
    expect(platform.shown.last.endsAt, running.endsAt);

    // 2) Duraklat: sabit kalan süre.
    final lang = LanguageService.instance;
    await tester.tap(find.text(lang.translate('btn_pause')));
    await tester.pump();
    expect(platform.calls.last, 'show:paused:run-1:same');
    expect(platform.shown.last.isPaused, isTrue);

    // 3) Devam (3-2-1 geri sayımından sonra): aynı seans yeni bitişle güncellenir.
    await tester.tap(find.text(lang.translate('btn_start')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(platform.calls.last, 'show:running:run-1:same');
    expect(platform.shown.last.isPaused, isFalse);
    final callsBeforeResume = platform.calls.length;

    // 4) Ön plana dönüş: kullanıcı bildirimi kapatmış olabilir, yeniden gönderilir.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.calls.length, callsBeforeResume + 1);
    expect(platform.calls.last, 'show:running:run-1:same');

    // 5) Sıfırla (onaylı): kilit ekranından kalkar.
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    await tester.tap(find.text(l10n.timerResetBtn));
    await tester.pump();
    await tester.tap(find.text(l10n.timerResetConfirmAction).last);
    await tester.pump();
    expect(platform.calls.last, 'clear');

    // 6) Kapanış: zaten kaldırılmış, platforma tekrar gidilmez.
    final callsBeforeUnmount = platform.calls.length;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(platform.calls.length, callsBeforeUnmount);
  });
}
