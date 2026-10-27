import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'break and focus alarms are independent and preference disable cancels both',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      SharedPreferences.setMockInitialValues({'notifications_enabled': true});
      final calls = <MethodCall>[];
      Completer<void>? scheduleEntered;
      Completer<void>? releaseSchedule;
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'zonedSchedule' && releaseSchedule != null) {
              scheduleEntered!.complete();
              await releaseSchedule.future;
            }
            return true;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
        NotificationService.instance.debugResetInitialization();
      });
      final service = NotificationService.instance;
      await service.scheduleMarathonBreakEnd(
        seconds: 300,
        nextSession: 2,
        totalSessions: 3,
      );
      expect(
        calls.where((c) => c.method == 'zonedSchedule').single.arguments['id'],
        2,
      );
      calls.clear();
      // A late focus cleanup must not cancel the newly scheduled break.
      await service.cancelSessionEndNotification();
      expect(
        calls.where((c) => c.method == 'cancel').single.arguments['id'],
        0,
      );
      expect(
        calls.any((c) => c.method == 'cancelAllPendingNotifications'),
        isFalse,
      );
      calls.clear();
      await service.scheduleSessionEnd(
        after: const Duration(minutes: 25),
        categoryName: 'Matematik',
      );
      expect(
        calls.where((c) => c.method == 'zonedSchedule').single.arguments['id'],
        0,
      );
      await service.cancelMarathonBreakEnd();
      expect(
        calls.where((c) => c.method == 'cancel').single.arguments['id'],
        2,
      );
      calls.clear();
      await service.setEnabled(false);
      expect(
        calls.where((c) => c.method == 'cancel').map((c) => c.arguments['id']),
        containsAll([0, 2]),
      );
      calls.clear();
      await service.scheduleMarathonBreakEnd(
        seconds: 300,
        nextSession: 2,
        totalSessions: 4,
      );
      expect(calls.any((c) => c.method == 'zonedSchedule'), isFalse);

      // A foreground sound queued behind a slow native schedule must
      // observe a preference disabled while it was waiting for the lock.
      await service.setEnabled(true);
      calls.clear();
      scheduleEntered = Completer<void>();
      releaseSchedule = Completer<void>();
      final scheduling = service.scheduleSessionEnd(
        after: const Duration(minutes: 25),
        categoryName: 'QA',
      );
      await scheduleEntered.future;
      final lateAlert = service.alertSessionEndInForeground();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final disabling = service.setEnabled(false);
      await Future<void>.delayed(Duration.zero);
      expect(await service.isEnabled(), isFalse);
      releaseSchedule.complete();
      await Future.wait([scheduling, lateAlert, disabling]);
      expect(calls.any((c) => c.method == 'show'), isFalse);
    },
  );
}
