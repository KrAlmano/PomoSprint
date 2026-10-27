// Gerçek 50 dk sayaç: duraklat/devam, kalıcı kimlik, tek hak ve ödülsüz iptal.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/e2e.dart';

void main() {
  initE2e();
  testWidgets('i · duraklat/devam ve yeniden kurulum aynı seansı korur', (
    tester,
  ) async {
    final a = await openShellWithNewAccount(tester, 'pause', name: 'QA Pause');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('league_info_shown_${a.id}', true);
    await NotificationService.instance.setEnabled(false);
    await tapOn(tester, find.text('50 dk'));
    await tapOn(
      tester,
      find.text(tr('btn_start')),
      settle: const Duration(milliseconds: 100),
    );
    await pumpUntil(tester, find.text(tr('btn_pause')));
    await tapOn(
      tester,
      find.text(tr('btn_pause')),
      settle: const Duration(milliseconds: 100),
    );
    final paused = (await TimerPersistence.instance.load(a.id))!;
    expect(paused.wasPaused, isTrue);
    expect(paused.pauseUsedCount, 1);
    expect(paused.recordAccelerated, isFalse);
    expect(paused.durationMinutes, 50);
    expect(paused.totalSeconds, 3000);
    expect(paused.isRunning, isFalse);
    await pumpFor(tester, const Duration(seconds: 2));
    expect(
      (await TimerPersistence.instance.load(a.id))!.pausedRemainingSeconds,
      paused.pausedRemainingSeconds,
    );
    await launchApp(tester);
    await pumpUntil(tester, find.byType(MainNavigationShell));
    await pumpUntil(tester, find.text(trL10n.pauseCreditUsed));
    final restored = (await TimerPersistence.instance.load(a.id))!;
    expect(restored.clientUuid, paused.clientUuid);
    expect(restored.startedAt, paused.startedAt);
    expect(restored.pausedRemainingSeconds, paused.pausedRemainingSeconds);
    await E2eHost.screenshot(tester, 'e2e-duraklat-geri-yukle');
    await tapOn(
      tester,
      find.text(tr('btn_start')),
      settle: const Duration(milliseconds: 100),
    );
    await pumpUntil(tester, find.text(tr('btn_pause')));
    await tapOn(
      tester,
      find.text(tr('btn_pause')),
      settle: const Duration(milliseconds: 100),
    );
    await pumpUntil(tester, find.byType(AlertDialog));
    expect(find.text(tr('pause_limit_title')), findsOneWidget);
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    // 50 dakika beklemeden normal seansı iptal et; ödül üretmemeli.
    await tapOn(tester, find.text(trL10n.timerResetBtn));
    await pumpUntil(tester, find.text(trL10n.timerResetConfirmTitle));
    await tapOn(tester, find.text(trL10n.timerResetConfirmAction).last);
    await pumpUntilGone(tester, find.byType(AlertDialog));
    expect(shellStats(tester), (points: 0, coins: 0));
    final rows = await E2eHost.rows(
      'select client_uuid::text from study_sessions where user_id=${sqlText(a.id)}',
    );
    expect(rows, isEmpty);
    expect(await TimerPersistence.instance.load(a.id), isNull);
    expect(tester.takeException(), isNull);
    debugPrint(
      '[QA] Duraklatma hakkı, aynı client_uuid/started_at, kalıcı devam, gerçek 50 dk süre ve ödülsüz iptal: PASS',
    );
  });
}
