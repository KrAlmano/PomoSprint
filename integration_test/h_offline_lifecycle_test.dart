// Gerçek yerel API kesintisi; sayaç UI'si, kalıcı outbox, yeniden kurulum,
// tekrar gönderim ve hesap değiştirirken veri izolasyonu. Canlıya bağlanmaz.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/screens/login_screen.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/local_test_mode.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/widgets/shell_pending_banner.dart';
import 'package:pomodoro/widgets/stats/stats_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/e2e.dart';

void main() {
  final binding = initE2e();
  testWidgets(
    'h · çevrimdışı seans korunur, tek kez gönderilir, diğer hesap temizdir',
    (tester) async {
      expect(kQuickTimer && recordLocalQuickSessions, isTrue);
      final a = await openShellWithNewAccount(
        tester,
        'offline',
        name: 'QA Offline',
      );
      final b = await signUpViaApi(e2eEmail('isolation'), 'QA Isolation');
      await completeOnboardingViaApi(b);
      final service = SupabaseService.instance;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('league_info_shown_${a.id}', true);
      await NotificationService.instance.setEnabled(false);
      var restored = false;
      try {
        await tapOn(
          tester,
          find.text(tr('btn_start')),
          settle: const Duration(milliseconds: 100),
        );
        // Gerçek 3-2-1 bittikten sonra sunucu başlangıç çağrısına fırsat ver.
        await pumpUntilTrue(
          tester,
          () => find.text(tr('btn_pause')).evaluate().isNotEmpty,
          reason: 'sayaç çalışıyor',
        );
        await E2eHost.setLocalApiAvailable(false);
        await pumpUntil(
          tester,
          find.byType(SessionCompletedDialog),
          timeout: const Duration(seconds: 40),
        );
        await pumpUntil(
          tester,
          find.text(trL10n.sessionQueuedOffline),
          timeout: const Duration(seconds: 40),
        );
        expect(service.pendingSessionCount.value, 1);
        expect(prefs.getString('pending_sessions_uid_${a.id}'), isNotNull);
        await tapOn(
          tester,
          find.widgetWithText(ElevatedButton, trL10n.sessionCompletedOk),
        );
        await openTab(tester, 1);
        Finder report25() => find.descendant(
          of: find.byType(ReportsScreen),
          matching: find.textContaining('${StatsText.duration(25)} / '),
        );
        await pumpUntil(tester, report25());
        expect(shellStats(tester), (
          points: 0,
          coins: 0,
        ), reason: 'sunucu yanıtı olmadan puan eklenmez');
        await E2eHost.screenshot(tester, 'e2e-cevrimdisi-rapor');
        // Aynı süreçte tüm ekranları yeniden kur; cihazdaki kalıcı kayıt korunur.
        await launchApp(tester);
        await pumpUntil(
          tester,
          find.byType(MainNavigationShell),
          timeout: const Duration(seconds: 50),
        );
        expect(service.pendingSessionCount.value, 1);
        await openTab(tester, 1);
        await pumpUntil(tester, report25());
        await E2eHost.setLocalApiAvailable(true);
        restored = true;
        await pumpFor(tester, const Duration(seconds: 1));
        for (final state in [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          binding.handleAppLifecycleStateChanged(state);
        }
        await pumpUntilTrue(
          tester,
          () =>
              service.pendingSessionCount.value == 0 &&
              shellStats(tester) == (points: 5, coins: 20),
          timeout: const Duration(seconds: 60),
          reason: 'bağlantı sonrası tek seans senkronize',
        );
        await pumpUntil(tester, report25());
        expect(find.byType(ShellPendingBanner), findsNothing);
        await service.syncPendingSessions();
        await service.syncPendingSessions();
        expect(
          await E2eHost.psql(
            'select count(*) from study_sessions where user_id=${sqlText(a.id)}',
          ),
          '1',
        );
        await E2eHost.screenshot(tester, 'e2e-cevrimdisi-sonrasi-tek-kayit');
        // Çıkış yapıp B hesabına UI'dan giriş: A'nın verisi görünmez.
        await service.signOutFully();
        await pumpUntil(tester, find.byType(LoginScreen));
        await loginViaUi(tester, b.email);
        await pumpUntil(tester, find.byType(MainNavigationShell));
        expect(shellStats(tester), (points: 0, coins: 0));
        expect(service.pendingSessionCount.value, 0);
        expect(await TimerPersistence.instance.load(b.id), isNull);
        await openTab(tester, 1);
        await pumpUntil(tester, find.text(tr('no_reports_title')));
        expect(
          await E2eHost.psql(
            'select count(*) from study_sessions where user_id=${sqlText(b.id)}',
          ),
          '0',
        );
        await E2eHost.screenshot(tester, 'e2e-hesap-b-veri-izolasyonu');
        await service.signOutFully();
        await pumpUntil(tester, find.byType(LoginScreen));
        await loginViaUi(tester, a.email);
        await pumpUntil(tester, find.byType(MainNavigationShell));
        expect(shellStats(tester), (points: 5, coins: 20));
        await openTab(tester, 1);
        await pumpUntil(tester, report25());
        expect(tester.takeException(), isNull);
        debugPrint(
          '[QA] Gerçek API kesintisi → kalıcı outbox → ekran yeniden kurulumu → tekrar gönderim → hesap izolasyonu: PASS',
        );
      } finally {
        if (!restored) await E2eHost.setLocalApiAvailable(true);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      }
    },
  );
}
