import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'e2e.dart';

/// Alarm teslimi native kuyruğa bağlıdır; emülatörde 5 sn sabit beklemek
/// zaman zaman teslimden önce sorguluyordu. Gerçek teslimi sınırlı bekle.
Future<void> waitForNativeNotification(WidgetTester tester, int id) async {
  final plugin = FlutterLocalNotificationsPlugin();
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    if ((await plugin.getActiveNotifications()).any((n) => n.id == id)) return;
    await pumpFor(tester, const Duration(milliseconds: 250));
  }
  fail('Native bildirim teslim edilmedi: $id');
}

/// NotificationManager iptali de platform yanıtından sonra işleyebilir.
/// Gerçek kaldırılmayı doğrula; 3 sn sonunda hâlâ varsa test başarısızdır.
Future<void> waitForNativeNotificationRemoved(WidgetTester tester, int id) async {
  final plugin = FlutterLocalNotificationsPlugin();
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(deadline)) {
    if (!(await plugin.getActiveNotifications()).any((n) => n.id == id)) return;
    await pumpFor(tester, const Duration(milliseconds: 100));
  }
  fail('Native bildirim iptalden sonra kaldı: $id');
}

/// Gerçek platform eklentisiyle iki alarmın ayrı kalması ve mola teslimi.
Future<void> verifyNativeMarathonNotifications(WidgetTester tester) async {
  final service = NotificationService.instance;
  final plugin = FlutterLocalNotificationsPlugin();
  await service.scheduleSessionEnd(
    after: const Duration(seconds: 60),
    categoryName: 'QA',
  );
  await service.scheduleMarathonBreakEnd(
    seconds: 60,
    nextSession: 2,
    totalSessions: 3,
  );
  expect(
    (await plugin.pendingNotificationRequests()).map((n) => n.id),
    containsAll([0, 2]),
  );
  await service.cancelSessionEndNotification();
  expect(
    (await plugin.pendingNotificationRequests()).map((n) => n.id),
    contains(2),
  );
  expect(
    (await plugin.pendingNotificationRequests()).map((n) => n.id),
    isNot(contains(0)),
  );
  await service.cancelMarathonBreakEnd();
  await service.scheduleMarathonBreakEnd(
    seconds: 3,
    nextSession: 2,
    totalSessions: 3,
  );
  await waitForNativeNotification(tester, 2);
  await service.setEnabled(false);
  expect(await plugin.pendingNotificationRequests(), isEmpty);
  await waitForNativeNotificationRemoved(tester, 2);
  expect(
    (await plugin.getActiveNotifications()).any((n) => n.id == 2),
    isFalse,
  );
}
