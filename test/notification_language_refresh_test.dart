import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'changing language updates pending focus and break alerts without extending deadlines',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      SharedPreferences.setMockInitialValues({'notifications_enabled': true});
      final oldLocale = LanguageService.deviceLocale;
      LanguageService.deviceLocale = () => const Locale('tr');
      await LanguageService.instance.init();
      final calls = <MethodCall>[];
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      final service = NotificationService.instance;
      service.debugResetInitialization();
      addTearDown(() async {
        await service.cancelSessionEndNotification();
        await service.cancelMarathonBreakEnd();
        LanguageService.deviceLocale = oldLocale;
        service.debugResetInitialization();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      });

      await service.scheduleSessionEnd(
        after: const Duration(minutes: 25),
        categoryName: 'Matematik',
      );
      await service.scheduleMarathonBreakEnd(
        seconds: 300,
        nextSession: 2,
        totalSessions: 3,
      );
      final initial = calls.where((c) => c.method == 'zonedSchedule').toList();
      expect(initial, hasLength(2));
      calls.clear();
      await LanguageService.instance.setLanguage(AppLanguage.en);
      await pumpEventQueue(times: 20);
      final refreshed = calls
          .where((c) => c.method == 'zonedSchedule')
          .toList();
      final en = lookupAppLocalizations(const Locale('en'));
      final refreshedCount = refreshed.length;
      if (refreshedCount == 2) {
        for (final prior in initial) {
          final next = refreshed.singleWhere(
            (c) => c.arguments['id'] == prior.arguments['id'],
          );
          expect(
            next.arguments['scheduledDateTimeISO8601'],
            prior.arguments['scheduledDateTimeISO8601'],
          );
          expect(
            next.arguments['timeZoneName'],
            prior.arguments['timeZoneName'],
          );
        }
        expect(
          refreshed
              .singleWhere((c) => c.arguments['id'] == 0)
              .arguments['body'],
          en.notifSessionDoneBody('Mathematics'),
        );
        expect(
          refreshed
              .singleWhere((c) => c.arguments['id'] == 2)
              .arguments['body'],
          en.notifMarathonBreakDoneBody(2, 3),
        );
      }

      await service.cancelSessionEndNotification();
      await service.cancelMarathonBreakEnd();
      calls.clear();
      await LanguageService.instance.setLanguage(AppLanguage.tr);
      await pumpEventQueue(times: 20);
      expect(
        calls.where((c) => c.method == 'zonedSchedule'),
        isEmpty,
        reason: 'A language switch cannot resurrect cancelled notifications',
      );
      expect(
        refreshedCount,
        2,
        reason: 'Both already scheduled alerts must follow the new language',
      );
    },
  );
}
