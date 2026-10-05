// Kısa gerçek sayaç: duraklat/devam, kalıcı kimlik ve tek duraklatma hakkı.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/screens/timer_screen.dart';
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
    expect(paused.recordAccelerated, isTrue);
    expect(paused.totalSeconds, 10);
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
    await pumpUntil(
      tester,
      find.byType(SessionCompletedDialog),
      timeout: const Duration(seconds: 25),
    );
    await pumpUntil(tester, find.text(trL10n.sessionResultPoints(9)));
    await tapOn(
      tester,
      find.widgetWithText(ElevatedButton, trL10n.sessionCompletedOk),
    );
    expect(shellStats(tester), (points: 9, coins: 20));
    final rows = await E2eHost.rows(
      'select client_uuid::text, duration_minutes, was_paused, base_points from study_sessions where user_id=${sqlText(a.id)}',
    );
    expect(rows.length, 1);
    expect(rows.single['client_uuid'], paused.clientUuid);
    expect(rows.single['duration_minutes'], 50);
    expect(rows.single['was_paused'], isTrue);
    expect(rows.single['base_points'], 9);
    expect(await TimerPersistence.instance.load(a.id), isNull);
    expect(tester.takeException(), isNull);
    debugPrint(
      '[QA] Duraklatma hakkı, aynı client_uuid/started_at, kalıcı devam, 50 dk ve duraklatma puanı: PASS',
    );
  });
}
