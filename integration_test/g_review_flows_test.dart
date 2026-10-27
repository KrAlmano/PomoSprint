// Kendi yeni yerel hesabında şifremi unuttum e-postası, rapor sayfaları ve
// bildirim (sistem izni varsa gerçek teslim) doğrulaması. Hesabı açık bırakır.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pomodoro/screens/forgot_password_screen.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/screens/login_screen.dart';
import 'package:pomodoro/screens/history_screen.dart';
import 'package:pomodoro/screens/monthly_tracking_screen.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'support/e2e.dart';

void main() {
  initE2e();
  testWidgets('yerel parola e-postası, haftalık/aylık toplam ve native bildirim', (
    tester,
  ) async {
    // Başka bir senaryonun eski hesabına/seanslarına bağlı değildir.
    final account = await signUpViaApi(e2eEmail('review'), 'QA Review');
    await completeOnboardingViaApi(account);
    final category = (await categoriesViaApi(account)).first;
    await LocalApi.rpc('complete_study_session', account, {
      'p_client_uuid': const Uuid().v4(),
      'p_category_id': category['id'],
      'p_duration_minutes': 25,
      'p_was_paused': false,
      'p_is_verified': 1500,
      'p_started_at': DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 26))
          .toIso8601String(),
    });
    // Normal geçmiş seans fixture'ı; 25 dk boyunca canlı bekleme kanıtı değildir.
    // Dönem sınırlarında hafta/ay beklentisini sunucu SQL'i belirler.
    Future<int> serverMinutes(DateTime first, DateTime last) async {
      final row = await E2eHost.row(
        'select coalesce(sum(s.duration_minutes),0)::int as minutes '
        'from public.study_sessions s join public.profiles p on p.id=s.user_id '
        'where s.user_id=${sqlText(account.id)} and '
        "((s.started_at at time zone coalesce(nullif(p.timezone,''),'Europe/Istanbul')) "
        "- interval '4 hours')::date between "
        '${sqlText(first.toIso8601String().substring(0, 10))}::date and '
        '${sqlText(last.toIso8601String().substring(0, 10))}::date',
      );
      return row!['minutes'] as int;
    }

    await resetAppState(tester);
    await launchApp(tester);
    await waitPastSplash(tester);
    await tapOn(tester, find.text(trL10n.forgotPassword));
    await pumpUntil(tester, find.byType(ForgotPasswordScreen));
    await tester.enterText(find.byType(TextFormField), account.email);
    await tapOn(
      tester,
      find.widgetWithText(FilledButton, trL10n.sendPasswordResetEmail),
    );
    await pumpUntil(tester, find.byType(PasswordResetSentScreen));
    expect(find.text(trL10n.passwordResetSentTitle), findsOneWidget);
    await E2eHost.screenshot(tester, 'e2e-parola-mail-gonderildi');
    await tapOn(tester, find.text(trL10n.backToLoginBtn));
    await loginViaUi(tester, account.email);
    await pumpUntil(tester, find.byType(NavigationBar));
    expect(shellStats(tester), (points: 5, coins: 20));
    await openTab(tester, 1);
    await tapOn(tester, find.text(tr('reports_tab_history')));
    final weekly = tester.widget<HistoryScreen>(find.byType(HistoryScreen));
    expect(
      sumMinutesBetween(
        weekly.sessions,
        mondayOf(weekly.today),
        addDays(mondayOf(weekly.today), 6),
      ),
      await serverMinutes(
        mondayOf(weekly.today),
        addDays(mondayOf(weekly.today), 6),
      ),
    );
    await E2eHost.screenshot(tester, 'e2e-review-haftalik');
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
      await serverMinutes(
        monthStartOf(monthly.today),
        monthEndOf(monthly.today),
      ),
    );
    await E2eHost.screenshot(tester, 'e2e-review-aylik');
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
    await E2eHost.screenshot(tester, 'e2e-son-acik-review');
  });

  testWidgets('g2 · Mailpit recovery, old password rejected, new native login', (
    tester,
  ) async {
    await resetAppState(tester);
    final account = await signUpViaApi(e2eEmail('recovery'), 'QA Recovery');
    await completeOnboardingViaApi(account);
    await launchApp(tester);
    await waitPastSplash(tester);
    await tapOn(tester, find.text(trL10n.forgotPassword));
    await pumpUntil(tester, find.byType(ForgotPasswordScreen));
    await tester.enterText(find.byType(TextFormField), account.email);
    await tapOn(
      tester,
      find.widgetWithText(FilledButton, trL10n.sendPasswordResetEmail),
    );
    await pumpUntil(tester, find.byType(PasswordResetSentScreen));
    const newPassword = 'Recovered-Sim2026';
    await E2eHost.recoverLocalPassword(account.email, newPassword);
    await tapOn(tester, find.text(trL10n.backToLoginBtn));
    await loginViaUi(tester, account.email);
    await pumpUntil(tester, find.text(trL10n.authErrInvalidCredentials));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(MainNavigationShell), findsNothing);
    await loginViaUi(tester, account.email, password: newPassword);
    await pumpUntil(tester, find.byType(MainNavigationShell));
    expect(SupabaseService.instance.currentUser.value?.id, account.id);
    expect(tester.takeException(), isNull);
    await E2eHost.screenshot(tester, 'e2e-password-recovery-native-login');
    debugPrint(
      '[QA] Mailpit recovery + local Auth update + old/new native login PASS; web form UI not exercised',
    );
  });
}
