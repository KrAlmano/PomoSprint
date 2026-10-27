// Gerçek Android eklentisi ve AlarmManager; sahte kanal kullanmaz.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'support/e2e.dart';
import 'support/marathon_notifications.dart';

void main() {
  initE2e();
  testWidgets('j · Android native izin, kalıcı sayaç, alarm teslim ve iptal', (
    tester,
  ) async {
    expect(
      Platform.isAndroid,
      isTrue,
      reason: 'Yalnızca Android emülatöründe çalıştır',
    );
    await resetAppState(tester);
    await launchApp(tester);
    await waitPastSplash(tester);
    await E2eHost.grantAndroidNotifications();
    final service = NotificationService.instance;
    final plugin = FlutterLocalNotificationsPlugin();
    await service.initialize();
    expect(
      await service.permissionStatus(),
      NotificationPermissionStatus.granted,
    );
    await service.setEnabled(true);
    final end = DateTime.now().add(const Duration(seconds: 20));
    expect(
      await service.showOngoingTimer(
        title: 'QA Sayaç',
        body: 'Matematik',
        channelName: 'QA Sayaç',
        channelDescription: 'Yerel QA',
        timeout: const Duration(seconds: 20),
        countdownTo: end,
      ),
      isTrue,
    );
    // NotificationManager enqueue işlemi kanal yanıtından sonra tamamlanabilir.
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(
      (await plugin.getActiveNotifications()).any((n) => n.id == 1),
      isTrue,
    );
    await service.cancelOngoingTimer();
    await waitForNativeNotificationRemoved(tester, 1);
    expect(
      (await plugin.getActiveNotifications()).any((n) => n.id == 1),
      isFalse,
    );
    await service.scheduleSessionEnd(
      after: const Duration(seconds: 60),
      categoryName: 'QA',
    );
    expect(
      (await plugin.pendingNotificationRequests()).any((n) => n.id == 0),
      isTrue,
    );
    await service.cancelSessionEndNotification();
    expect(
      (await plugin.pendingNotificationRequests()).any((n) => n.id == 0),
      isFalse,
    );
    await service.scheduleSessionEnd(
      after: const Duration(seconds: 3),
      categoryName: 'Matematik',
    );
    await waitForNativeNotification(tester, 0);
    await E2eHost.screenshot(tester, 'e2e-android-bildirim-native');
    await verifyNativeMarathonNotifications(tester);
    await service.setEnabled(false);
    expect(await service.isEnabled(), isFalse);
    expect(await plugin.pendingNotificationRequests(), isEmpty);
    await waitForNativeNotificationRemoved(tester, 1);
    expect(
      (await plugin.getActiveNotifications()).any((n) => n.id == 1),
      isFalse,
    );
    // Testin teslim kayıtlarını da açıkça temizle.
    await plugin.cancel(id: 0);
    expect(await plugin.getActiveNotifications(), isEmpty);
    expect(tester.takeException(), isNull);
    debugPrint(
      '[QA] Android native izin/ongoing/alarm zamanlama/teslim/iptal/tercih kapatma: PASS',
    );
  });
}
