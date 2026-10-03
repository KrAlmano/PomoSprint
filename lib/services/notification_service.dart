import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  NotificationService._init();

  
  Future<bool> requestPermission() async {
    bool granted = false;
    final androidImplementation = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      granted = await androidImplementation.requestNotificationsPermission() ?? false;
    }
    final iosImplementation = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      granted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      ) ?? false;
    }
    return granted;
  }

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      macOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );
  }

  Future<void> scheduleTimerCompletionNotification(int seconds, String categoryName) async {
    await flutterLocalNotificationsPlugin.cancelAll();

    final scheduledDate = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'pomodoro_timer_channel',
      'Pomodoro Timer',
      channelDescription: 'Notifications for completed Pomodoro sessions',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: 0,
      title: 'Pomodoro Tamamlandı!',
      body: '$categoryName çalışmanız bitti. Puanlarınızı almak için uygulamaya dönün!',
      scheduledDate: scheduledDate,
      notificationDetails: platformDetails,
      // exactAllowWhileIdle, Android 12+'ta SCHEDULE_EXACT_ALARM izni ister;
      // bu izin manifest'te tanımlı değildi ve Android'de her seans
      // bitiminde "exact_alarms_not_permitted" hatasıyla sessizce
      // başarısız oluyordu (bildirim hiç planlanmıyordu). Bir pomodoro
      // bitiş hatırlatması için saniye hassasiyeti gerekmiyor.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
