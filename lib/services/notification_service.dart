import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_localizations.dart';
import 'language_service.dart';

/// Seans bitiş bildirimi ve (Android) süren seansın kilit ekranında da
/// görünen kalıcı bildirimi. İzin açılışta İSTENMEZ; ilk BAŞLAT'ta
/// [ensurePermission] ile bağlamı olan bir anda sorulur.
class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  NotificationService._init();

  static const int _sessionEndId = 0;
  static const int _ongoingTimerId = 1;
  static const String _channelId = 'pomodoro_timer_channel';
  // Ayrı kanal: varsayılan önem (sessiz/"düşük" kanal kilit ekranında
  // gizlenebilir) ama ses ve titreşim yok.
  static const String _ongoingChannelId = 'pomodoro_running_channel';
  static const String _enabledKey = 'notifications_enabled';
  static const String _permissionAskedKey = 'notification_permission_asked';
  static const Color _brandColor = Color(0xFFFF5C4D);

  Future<void>? _initialization;

  /// Bildirim tercihi her değiştiğinde artar (kilit ekranı sayacı dinler).
  final ValueNotifier<int> preferenceRevision = ValueNotifier<int>(0);

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
    preferenceRevision.value++;
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
    final scheduledDate = tz.TZDateTime.now(tz.local).add(after);
    // Android: bitiş bildirimi tam zamanında gelsin diye exact alarm
    // (Android 13+ USE_EXACT_ALARM, 12-12L SCHEDULE_EXACT_ALARM). İzin yoksa
    // (ör. kullanıcı Android 12'de kapattıysa) inexact'e düşülür; Doze'da
    // birkaç dakika gecikebilir.
    final exact = await _canScheduleExact();
    final modes = [
      if (exact) AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ];
    for (final mode in modes) {
      try {
        await _plugin.zonedSchedule(
          id: _sessionEndId,
          title: l10n.notifSessionDoneTitle,
          body: l10n.notifSessionDoneBody(displayCategoryName(categoryName)),
          scheduledDate: scheduledDate,
          notificationDetails: _details(l10n),
          androidScheduleMode: mode,
        );
        return;
      } on PlatformException catch (e) {
        // exact_alarms_not_permitted: izin bu arada geri alınmış olabilir.
        debugPrint('[NOTIF] Bildirim zamanlanamadı ($mode): ${e.code}');
      } catch (e) {
        debugPrint('[NOTIF] Bildirim zamanlanamadı: $e');
        return;
      }
    }
  }

  Future<bool> _canScheduleExact() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      return await android.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Uygulama arka plandayken biten seans için bildirimi beklemeden gösterir
  /// (alarm Doze'da ya da exact izni yoksa geç tetiklenebilir).
  Future<void> showSessionEndNow({required String categoryName}) async {
    if (!await _ready() || !await isEnabled()) return;
    final l10n = _l10n();
    try {
      await _plugin.cancelAllPendingNotifications();
      await _plugin.show(
        id: _sessionEndId,
        title: l10n.notifSessionDoneTitle,
        body: l10n.notifSessionDoneBody(displayCategoryName(categoryName)),
        notificationDetails: _details(l10n),
      );
    } catch (e) {
      debugPrint('[NOTIF] Bildirim gösterilemedi: $e');
    }
  }

  /// Android: süren seansın kalıcı (kaydırılarak kapatılamayan) bildirimi;
  /// kilit ekranında içeriğiyle görünür. [countdownTo] verilirse o ana geri
  /// sayan kronometre gösterilir. [timeout] dolunca bildirim kendiliğinden
  /// kalkar (uygulama öldürülse bile). Aynı kimlikle yeniden çağrılınca
  /// sessizce güncellenir. Android dışında hiçbir şey yapmaz.
  Future<bool> showOngoingTimer({
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
    required Duration timeout,
    DateTime? countdownTo,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android || timeout <= Duration.zero) return false;
    if (!await _ready() || !await isEnabled()) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    final countdown = countdownTo != null;
    await android.show(
      id: _ongoingTimerId,
      title: title,
      body: body,
      notificationDetails: AndroidNotificationDetails(
        _ongoingChannelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: false,
        enableVibration: false,
        channelShowBadge: false,
        onlyAlertOnce: true,
        ongoing: true,
        autoCancel: false,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.alarm,
        color: _brandColor,
        showWhen: countdown,
        when: countdownTo?.millisecondsSinceEpoch,
        usesChronometer: countdown,
        chronometerCountDown: countdown,
        timeoutAfter: timeout.inMilliseconds,
      ),
    );
    return true;
  }

  /// Süren seansın kalıcı bildirimini kaldırır (Android).
  Future<void> cancelOngoingTimer() async {
    if (defaultTargetPlatform != TargetPlatform.android || !await _ready()) return;
    await _plugin.cancel(id: _ongoingTimerId);
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

  /// Bildirimde ve kilit ekranında gösterilen kategori adı (o anki dilde).
  static String displayCategoryName(String name) =>
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
