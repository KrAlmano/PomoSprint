import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import 'language_service.dart';

/// Seans bitiş bildirimi. İzin açılışta İSTENMEZ; ilk BAŞLAT'ta
/// [ensurePermission] ile bağlamı olan bir anda sorulur.
class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  NotificationService._init();

  static const int _sessionEndId = 0;
  static const String _channelId = 'pomodoro_timer_channel';
  static const String _enabledKey = 'notifications_enabled';
  static const String _permissionAskedKey = 'notification_permission_asked';
  static const Color _brandColor = Color(0xFFFF5C4D);

  Future<void>? _initialization;

  /// Eklentiyi başlatır (izin istemeden). Desteklenmeyen platformda hata
  /// fırlatır; çağıran raporlar, bildirimler sessizce devre dışı kalır.
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    // Veri study_day.dart tarafından zaten yüklenmiş olabilir.
    if (!tz.timeZoneDatabase.isInitialized) tz.initializeTimeZones();
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_notification'),
        iOS: darwin,
        macOS: darwin,
      ),
    );
  }

  Future<bool> _ready() async {
    try {
      await initialize();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Kullanıcının bildirim tercihi (varsayılan açık).
  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Tercihi kaydeder. Kapatınca zamanlanmış bildirim iptal edilir, açınca
  /// izin istenir.
  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    if (value) {
      await ensurePermission(force: true);
    } else {
      await cancelSessionEndNotification();
    }
  }

  /// Bildirim izni varsa true. Tercih kapalıysa sormaz. Kullanıcıya
  /// kendiliğinden yalnızca bir kez sorulur; [force] ile (ör. ayardan
  /// açılınca) yeniden sorulur.
  Future<bool> ensurePermission({bool force = false}) async {
    if (!await _ready() || !await isEnabled()) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (android != null && (await android.areNotificationsEnabled() ?? false)) return true;
      if (ios != null && ((await ios.checkPermissions())?.isEnabled ?? false)) return true;

      final prefs = await SharedPreferences.getInstance();
      if (!force && (prefs.getBool(_permissionAskedKey) ?? false)) return false;
      await prefs.setBool(_permissionAskedKey, true);
      if (android != null) return await android.requestNotificationsPermission() ?? false;
      if (ios != null) return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } catch (e) {
      debugPrint('[NOTIF] Bildirim izni alınamadı: $e');
    }
    return false;
  }

  /// [after] süre sonra seans bitiş bildirimini zamanlar (önceki zamanlanmış
  /// bildirimin yerini alır).
  Future<void> scheduleSessionEnd({required Duration after, required String categoryName}) async {
    if (!await _ready() || !await isEnabled()) return;
    final l10n = _l10n();
    try {
      await _plugin.zonedSchedule(
        id: _sessionEndId,
        title: l10n.notifSessionDoneTitle,
        body: l10n.notifSessionDoneBody(_displayCategory(categoryName)),
        scheduledDate: tz.TZDateTime.now(tz.local).add(after),
        notificationDetails: _details(l10n),
        // exactAllowWhileIdle, Android 12+'ta SCHEDULE_EXACT_ALARM izni ister;
        // bir pomodoro bitiş hatırlatması için saniye hassasiyeti gerekmiyor.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('[NOTIF] Bildirim zamanlanamadı: $e');
    }
  }

  /// Uygulama arka plandayken biten seans için bildirimi beklemeden gösterir
  /// (inexact alarm geç tetiklenebilir).
  Future<void> showSessionEndNow({required String categoryName}) async {
    if (!await _ready() || !await isEnabled()) return;
    final l10n = _l10n();
    try {
      await _plugin.cancelAllPendingNotifications();
      await _plugin.show(
        id: _sessionEndId,
        title: l10n.notifSessionDoneTitle,
        body: l10n.notifSessionDoneBody(_displayCategory(categoryName)),
        notificationDetails: _details(l10n),
      );
    } catch (e) {
      debugPrint('[NOTIF] Bildirim gösterilemedi: $e');
    }
  }

  /// Hâlâ bekleyen zamanlanmış bildirimi iptal eder; gösterilmiş bildirime
  /// dokunmaz.
  Future<void> cancelSessionEndNotification() async {
    if (!await _ready()) return;
    try {
      await _plugin.cancelAllPendingNotifications();
    } catch (e) {
      debugPrint('[NOTIF] Bildirim iptal edilemedi: $e');
    }
  }

  // Bağlam (context) olmadan da o anki uygulama dilinde metin üretir.
  static AppLocalizations _l10n() => lookupAppLocalizations(LanguageService.instance.currentLocale);

  static String _displayCategory(String name) =>
      name.trim().isEmpty ? 'Pomodoro' : LanguageService.instance.translateCatName(name);

  static NotificationDetails _details(AppLocalizations l10n) {
    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        l10n.notifChannelName,
        channelDescription: l10n.notifChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        color: _brandColor,
      ),
      iOS: darwin,
      macOS: darwin,
    );
  }
}
