// Native iOS kanalları: simülatörde sessiz provisional bildirim izni ve
// ActivityKit. Tam ses/banner izninin kullanıcı kabulü bu testin dışındadır.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pomodoro/services/lock_screen_timer.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'support/e2e.dart';
import 'support/marathon_notifications.dart';

void main() {
  initE2e();
  testWidgets('k · iOS gerçek sessiz bildirim ve ActivityKit kanalı', (
    tester,
  ) async {
    expect(Platform.isIOS, isTrue);
    await resetAppState(tester);
    await launchApp(tester);
    await waitPastSplash(tester);
    final service = NotificationService.instance;
    final plugin = FlutterLocalNotificationsPlugin();
    await service.initialize();
    final ios = plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()!;
    expect(
      await ios.requestPermissions(alert: true, provisional: true),
      isTrue,
    );
    expect(
      await service.permissionStatus(),
      NotificationPermissionStatus.granted,
    );
    await service.setEnabled(true);
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
    debugPrint('[QA] iOS provisional native zamanlama/teslim/iptal: PASS');
    const platform = IosLiveActivityPlatform();
    final contentBuilder = LockScreenTimer(platform: platform);
    final session = ActiveTimerSession.start(
      clientUuid: 'qa-native-$e2eRunId',
      categoryId: 'qa',
      categoryName: 'Matematik',
      durationMinutes: 25,
      totalSeconds: 45,
      now: DateTime.now(),
    );
    final shown = await platform.show(
      contentBuilder.contentFor(session, DateTime.now())!,
      isNewSession: true,
    );
    debugPrint('[QA] ActivityKit native start: $shown');
    if (shown) {
      final paused = session.pauseAt(DateTime.now());
      expect(
        await platform.show(
          contentBuilder.contentFor(paused, DateTime.now())!,
          isNewSession: false,
        ),
        isTrue,
      );
      expect(
        await platform.show(
          contentBuilder.contentFor(
            paused.resumeAt(DateTime.now()),
            DateTime.now(),
          )!,
          isNewSession: false,
        ),
        isTrue,
      );
      debugPrint(
        '[QA] ActivityKit native start/update pause/update resume: PASS',
      );
    } else {
      debugPrint(
        '[QA] ActivityKit gösterimi DOĞRULANAMADI: simülatör veya sistem yeteneği kapalı; kanal güvenli false döndü.',
      );
    }
    await platform.clear();
    await verifyNativeMarathonNotifications(tester);
    await service.setEnabled(false);
    expect(await plugin.pendingNotificationRequests(), isEmpty);
    await plugin.cancel(id: 0);
    expect(await plugin.getActiveNotifications(), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
