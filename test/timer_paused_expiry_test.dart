import 'dart:convert';

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

// t1-04: Duraklatılmış seans açılışta 24 saat denetimini geçip sonra devam
// ettirilince bitiş başlangıçtan 24 saat sonraya kalabiliyordu; sunucu
// seansı too_old ile kalıcı reddediyordu (25 dk çalışma uyarısız kayboluyor).
// Devamdan önce (BAŞLAT ve 3-2-1 sonrası) ve ön plana dönüşte de denetlenir.
//
// TimerPersistence tekil ve kilidinin Future zinciri onu ilk kullanan testin
// fake async bölgesine bağlı kaldığı için dosyada tek testWidgets var
// (bkz. timer_screen_test.dart).
void main() {
  const owner = 'u-expiry';
  final category = CourseCategory.initialCategories().first;

  testWidgets('duraklatılmış seans 24 saati aşacaksa devam ettirilmez, uyarıyla sıfırlanır', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    final lang = LanguageService.instance;

    var now = DateTime(2026, 10, 5, 12);
    final lockPlatform = FakeLockScreenPlatform();
    final lockScreen = LockScreenTimer(
      platform: lockPlatform,
      isEnabled: () async => true,
      categoryLabel: (name) => name,
      clock: () => now,
    );
    final submitted = <ActiveTimerSession>[];

    Future<void> mount(Key key) async {
      await tester.pumpWidget(MaterialApp(
        key: key,
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TimerScreen(
          categories: [category],
          sessionOwnerKey: owner,
          onOpenSettings: () {},
          onSessionCompleted: (s) async {
            submitted.add(s);
            return null;
          },
          lockScreenTimer: lockScreen,
          clock: () => now,
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    Future<String?> stored() async {
      await tester.pump();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(TimerPersistence.keyFor(owner));
      return raw == null ? null : ActiveTimerSession.fromJson(jsonDecode(raw))?.clientUuid;
    }

    // Repro (Q12): 24 sa 04 dk önce başladı, 1 dk sonra duraklatıldı (kalan
    // 24 dk). Uygulama 1 saat önce açılmış olsun: açılış denetimi geçer.
    ActiveTimerSession pausedSession(String uuid, DateTime reference) {
      final start = reference.subtract(const Duration(hours: 24, minutes: 4));
      return ActiveTimerSession.start(
        clientUuid: uuid,
        categoryId: category.id,
        categoryName: category.name,
        durationMinutes: 25,
        totalSeconds: 25 * 60,
        now: start,
      ).pauseAt(start.add(const Duration(minutes: 1)));
    }

    // 1) BAŞLAT ile devam: 3-2-1'e gidilmeden seans sıfırlanır.
    final resumeAt = now;
    await TimerPersistence.instance.save(owner, pausedSession('paused-old', resumeAt));
    now = resumeAt.subtract(const Duration(hours: 1));
    await mount(const ValueKey('a'));
    expect(find.text(l10n.timerResetBtn), findsOneWidget, reason: 'açılışta seans geri yüklendi');
    expect(lockPlatform.calls.last, 'show:paused:paused-old:same');

    now = resumeAt.subtract(const Duration(minutes: 24));
    await tester.tap(find.text(lang.translate('btn_start')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text(l10n.pausedSessionExpired), findsOneWidget);
    expect(find.text(l10n.timerResetBtn), findsNothing, reason: 'seans sıfırlandı, sayaç boşta');
    expect(find.text(lang.translate('btn_pause')), findsNothing, reason: 'sayaç çalışmıyor');
    expect(await stored(), isNull);
    expect(lockPlatform.calls.last, 'clear');
    expect(submitted, isEmpty);
    await tester.pump(const Duration(seconds: 5));

    // 2) Uygulama açıkken (duraklatılmış) arka plana alınıp ertesi gün ön
    // plana dönülürse de denetlenir.
    final second = DateTime(2026, 10, 6, 12);
    await TimerPersistence.instance.save(owner, pausedSession('paused-bg', second));
    now = second.subtract(const Duration(hours: 1));
    await mount(const ValueKey('b'));
    expect(find.text(l10n.timerResetBtn), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    now = second.subtract(const Duration(minutes: 20));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n.pausedSessionExpired), findsOneWidget);
    expect(find.text(l10n.timerResetBtn), findsNothing);
    expect(await stored(), isNull);
    expect(lockPlatform.calls.last, 'clear');
    await tester.pump(const Duration(seconds: 5));

    // 3) Sınırın içinde kalan seans (23,5 sa sonra devam, bitiş < 24 sa)
    // normal devam eder.
    final third = DateTime(2026, 10, 7, 12);
    final start = third.subtract(const Duration(hours: 23, minutes: 30));
    await TimerPersistence.instance.save(
      owner,
      ActiveTimerSession.start(
        clientUuid: 'paused-ok',
        categoryId: category.id,
        categoryName: category.name,
        durationMinutes: 25,
        totalSeconds: 25 * 60,
        now: start,
      ).pauseAt(start.add(const Duration(minutes: 5))),
    );
    now = third;
    await mount(const ValueKey('c'));
    await tester.tap(find.text(lang.translate('btn_start')));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.text(l10n.pausedSessionExpired), findsNothing);
    expect(find.text(lang.translate('btn_pause')), findsOneWidget, reason: 'seans sürüyor');
    expect(await stored(), 'paused-ok');
    expect(lockPlatform.calls.last, 'show:running:paused-ok:same');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
