// Yerel QA hesabında gerçek şifremi unuttum e-postası, rapor sayfaları ve
// bildirim (sistem izni varsa gerçek teslim) doğrulaması. Hesabı açık bırakır.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pomodoro/screens/forgot_password_screen.dart';
import 'package:pomodoro/screens/history_screen.dart';
import 'package:pomodoro/screens/monthly_tracking_screen.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/e2e.dart';

void main() {
  initE2e();
  testWidgets(
    'yerel parola e-postası, haftalık/aylık toplam ve native bildirim',
    (tester) async {
      await resetAppState(tester);
      await launchApp(tester);
      await waitPastSplash(tester);
      await tapOn(tester, find.text(trL10n.forgotPassword));
      await pumpUntil(tester, find.byType(ForgotPasswordScreen));
      await tester.enterText(find.byType(TextFormField), e2eEmail('qa1'));
      await tapOn(
        tester,
        find.widgetWithText(FilledButton, trL10n.sendPasswordResetEmail),
      );
      await pumpUntil(tester, find.byType(PasswordResetSentScreen));
      expect(find.text(trL10n.passwordResetSentTitle), findsOneWidget);
      await E2eHost.screenshot(tester, 'e2e-parola-mail-gonderildi');
      await tapOn(tester, find.text(trL10n.backToLoginBtn));
      await loginViaUi(tester, e2eEmail('qa1'));
      await pumpUntil(tester, find.byType(NavigationBar));
      expect(shellStats(tester), (points: 17, coins: 40));
      await openTab(tester, 1);
      await tapOn(tester, find.text(tr('reports_tab_history')));
      final weekly = tester.widget<HistoryScreen>(find.byType(HistoryScreen));
      expect(
        sumMinutesBetween(
          weekly.sessions,
          mondayOf(weekly.today),
          addDays(mondayOf(weekly.today), 6),
        ),
        75,
      );
      await E2eHost.screenshot(tester, 'e2e-qa1-haftalik');
      await tapOn(tester, find.text(tr('reports_tab_monthly')));
      final monthly = tester.widget<MonthlyTrackingScreen>(
        find.byType(MonthlyTrackingScreen),
      );
      expect(
        sumMinutesBetween(
          monthly.sessions,
          monthStartOf(monthly.today),
          monthEndOf(monthly.today),
        ),
        75,
      );
      await E2eHost.screenshot(tester, 'e2e-qa1-aylik');
      final permission = await NotificationService.instance.permissionStatus();
      debugPrint('[QA] Son native bildirim izni: $permission');
      if (permission == NotificationPermissionStatus.granted) {
        await NotificationService.instance.setEnabled(true);
        await NotificationService.instance.scheduleSessionEnd(
          after: const Duration(seconds: 3),
          categoryName: 'Matematik',
        );
        await pumpFor(tester, const Duration(seconds: 5));
        final active = await FlutterLocalNotificationsPlugin()
            .getActiveNotifications();
        expect(
          active.any((n) => n.id == 0),
          isTrue,
          reason: 'gerçek native bildirim teslimi',
        );
        debugPrint('[QA] Gerçek native bildirim teslimi: PASS');
        await E2eHost.screenshot(tester, 'e2e-bildirim-teslim');
      } else {
        debugPrint(
          '[QA] Bildirim teslimi DOĞRULANAMADI: sistem izni verilmedi; native kayıt denemesi de izin nedeniyle doğrulanamadı.',
        );
        await (await SharedPreferences.getInstance()).setBool(
          'notifications_enabled',
          false,
        );
      }
      await NotificationService.instance.cancelSessionEndNotification();
      await openTab(tester, 0);
      expect(tester.takeException(), isNull);
      await E2eHost.screenshot(tester, 'e2e-son-acik-qa1');
    },
  );
}
