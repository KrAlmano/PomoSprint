import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show HapticFeedback, PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import 'language_service.dart';

/// Sistem bildirim izninin durumu ([NotificationService.permissionStatus]).
enum NotificationPermissionStatus {
  /// İzin var (iOS'ta geçici "provisional" izin de sayılır).
  granted,

  /// Soruldu ama verilmedi ya da sonradan ayarlardan kapatıldı. Sistem
  /// penceresi bir daha çıkmayabilir; yol sistem ayarlarıdır.
  denied,

  /// Henüz hiç sorulmadı: açmak sistem penceresini gösterir. Bu durumda
  /// "Ayarları aç" gösterilmez (iOS'ta uygulamanın ayar sayfasında izin
  /// istenmeden Bildirimler satırı bile yoktur).
  notDetermined,

  /// Platform desteklemiyor ya da okunamadı: yalnızca tercihe bakılır.
  unknown,
}

/// Bildirim izninin platform katmanı. Varsayılanı flutter_local_notifications
/// eklentisidir; testte sahtesi [NotificationService.debugPermissionPlatform]
/// ile verilir.
abstract class NotificationPermissionPlatform {
  const NotificationPermissionPlatform();

  /// İzin şu an var mı? SORMAZ. Okunamazsa null. iOS "hiç sorulmadı" ile
  /// "reddedildi"yi ayırmaz (ikisi de false); ayrımı servis yapar.
  Future<bool?> isGranted();

  /// Sistem izin penceresini ister; izin verildiyse true. İzin daha önce
  /// reddedildiyse sistem pencere göstermeden false döndürebilir (iOS her
  /// zaman, Android 13+ iki retten sonra).
  Future<bool> request();

  /// Uygulamanın sistem bildirim ayarlarını açar; açılabildiyse true.
  Future<bool> openSettings();
}

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
  /// Başarısız deneme saklanmaz: bir sonraki çağrı yeniden dener (aksi halde
  /// tek bir açılış hatası izin isteğini süreç boyunca "verilmedi"ye
  /// düşürüyordu).
  Future<void> initialize() => _initialization ??= (debugInitializePlugin ?? _initialize)().catchError(
        (Object error, StackTrace stackTrace) {
          _initialization = null;
          Error.throwWithStackTrace(error, stackTrace);
        },
      );

  /// Testte eklenti başlatmasının yerine geçer.
  @visibleForTesting
  Future<void> Function()? debugInitializePlugin;

  /// Testte başarılı ya da başarısız başlatmayı unutturur.
  @visibleForTesting
  void debugResetInitialization() => _initialization = null;

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

  /// Tercihi kaydeder ve sonucu döndürür: true = tercih açık VE izin var.
  /// Kapatınca bekleyen (zamanlanmış) bildirim iptal edilir; kilit ekranı
  /// sayacı [preferenceRevision] ile kaldırılır. Açınca izin istenir (hiç
  /// sorulmadıysa sistem penceresi çıkar). İzin verilmezse tercih AÇIK kalır:
  /// anahtar kapalı görünür, "Ayarları aç" yolu çıkar ve kullanıcı ayarlardan
  /// izin verip dönünce anahtar kendiliğinden açılır.
  Future<bool> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    preferenceRevision.value++;
    if (!value) {
      await cancelSessionEndNotification();
      return false;
    }
    return ensurePermission(force: true);
  }

  /// Bildirim izni varsa true. Tercih kapalıysa sormaz. Kullanıcıya
  /// kendiliğinden yalnızca bir kez sorulur; [force] ile (ör. ayardan
  /// açılınca) yeniden sorulur.
  Future<bool> ensurePermission({bool force = false}) async {
    if (!await isEnabled()) return false;
    try {
      final permissions = _permissions;
      final granted = await permissions.isGranted();
      // Okunamadıysa (eklenti hazır değil, desteklenmeyen platform) sorulmaz
      // ve "soruldu" yazılmaz: aksi halde hiç görülmemiş pencere "reddedildi"
      // sayılıp kullanıcı iOS'ta Bildirimler satırı olmayan ayarlara
      // yönlendiriliyordu.
      if (granted == null) return false;
      if (granted) return true;
      final prefs = await SharedPreferences.getInstance();
      if (!force && (prefs.getBool(_permissionAskedKey) ?? false)) return false;
      final result = await permissions.request();
      await prefs.setBool(_permissionAskedKey, true);
      return result;
    } catch (e) {
      debugPrint('[NOTIF] Bildirim izni alınamadı: $e');
    }
    return false;
  }

  /// Profil anahtarının göstereceği durum: tercih açık VE sistem izni var.
  /// İzin okunamıyorsa ([NotificationPermissionStatus.unknown]) yalnızca
  /// tercihe bakılır. Hiç sorulmamış izin "yok" sayılır: anahtar kapalıdır,
  /// açmak sistem penceresini gösterir.
  static bool effectiveEnabled({required bool preference, required NotificationPermissionStatus permission}) =>
      preference &&
      (permission == NotificationPermissionStatus.granted || permission == NotificationPermissionStatus.unknown);

  /// Tercih açık ama izin reddedilmiş: kullanıcıya ayarları açan yol
  /// gösterilir. Hiç sorulmamış izin engel sayılmaz (sistem penceresi çıkar).
  static bool isBlockedBySystem({required bool preference, required NotificationPermissionStatus permission}) =>
      preference && permission == NotificationPermissionStatus.denied;

  /// Testte izin platformunun (okuma, isteme, ayarları açma) yerine geçer.
  @visibleForTesting
  NotificationPermissionPlatform? debugPermissionPlatform;

  late final NotificationPermissionPlatform _pluginPermissions = _PluginNotificationPermissions(this);

  NotificationPermissionPlatform get _permissions => debugPermissionPlatform ?? _pluginPermissions;

  /// Sistem bildirim izninin durumu. İzin İSTEMEZ. iOS'un ve Android'in
  /// "izin yok" yanıtı, iznin bu uygulamada daha önce sorulup sorulmadığına
  /// göre [NotificationPermissionStatus.denied] ya da
  /// [NotificationPermissionStatus.notDetermined] olur.
  Future<NotificationPermissionStatus> permissionStatus() async {
    try {
      final granted = await _permissions.isGranted();
      if (granted == null) return NotificationPermissionStatus.unknown;
      if (granted) return NotificationPermissionStatus.granted;
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getBool(_permissionAskedKey) ?? false)
          ? NotificationPermissionStatus.denied
          : NotificationPermissionStatus.notDetermined;
    } catch (e) {
      debugPrint('[NOTIF] Bildirim izni okunamadı: $e');
      return NotificationPermissionStatus.unknown;
    }
  }

  /// Bu uygulamanın sistem bildirim ayarlarını açar (izin bir kez
  /// reddedilince sistem penceresi bir daha çıkmaz). Açılabildiyse true.
  Future<bool> openSystemSettings() => _permissions.openSettings();

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

  /// Uygulama ön plandayken biten seans: kısa titreşim; bildirim tercihi
  /// açıksa bitiş bildiriminin sesi de çalar. iOS'ta afiş gösterilmez
  /// (yalnızca ses), Android'de bildirim birkaç saniye sonra kendiliğinden
  /// kalkar. Tercih kapalıysa yalnızca titreşim.
  Future<void> alertSessionEndInForeground() => runForegroundSessionEndAlert(
        vibrate: HapticFeedback.vibrate,
        notificationsEnabled: isEnabled,
        playSound: _playSessionEndSound,
      );

  Future<void> _playSessionEndSound() async {
    if (!await _ready()) return;
    final l10n = _l10n();
    try {
      await _plugin.cancelAllPendingNotifications();
      await _plugin.show(
        id: _sessionEndId,
        title: l10n.notifSessionDoneTitle,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            l10n.notifChannelName,
            channelDescription: l10n.notifChannelDescription,
            importance: Importance.max,
            priority: Priority.high,
            color: _brandColor,
            timeoutAfter: _foregroundAlertTimeout.inMilliseconds,
          ),
          iOS: _foregroundDarwinDetails,
          macOS: _foregroundDarwinDetails,
        ),
      );
    } catch (e) {
      debugPrint('[NOTIF] Bitiş sesi çalınamadı: $e');
    }
  }

  static const Duration _foregroundAlertTimeout = Duration(seconds: 5);
  static const DarwinNotificationDetails _foregroundDarwinDetails = DarwinNotificationDetails(
    presentAlert: false,
    presentBanner: false,
    presentList: false,
    presentBadge: false,
    presentSound: true,
  );

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

/// flutter_local_notifications 22.x üzerinden izin. iOS `checkPermissions`:
/// `isEnabled` yalnızca "authorized", `isProvisionalEnabled` "provisional";
/// "notDetermined" ve "denied" ikisi de false döner (ephemeral yalnızca App
/// Clip'te). Android: `areNotificationsEnabled` (13+'ta POST_NOTIFICATIONS
/// dahil), istek 13 altında pencere göstermeden mevcut durumu döndürür.
class _PluginNotificationPermissions extends NotificationPermissionPlatform {
  _PluginNotificationPermissions(this._service);

  final NotificationService _service;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _service._plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _service._plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  @override
  Future<bool?> isGranted() async {
    if (!await _service._ready()) return null;
    try {
      final android = _android;
      if (android != null) return await android.areNotificationsEnabled();
      final ios = _ios;
      if (ios != null) {
        final options = await ios.checkPermissions();
        if (options == null) return null;
        return options.isEnabled || options.isProvisionalEnabled;
      }
    } catch (e) {
      debugPrint('[NOTIF] Bildirim izni okunamadı: $e');
    }
    return null;
  }

  @override
  Future<bool> request() async {
    if (!await _service._ready()) return false;
    final android = _android;
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _ios;
    if (ios != null) return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    return false;
  }

  /// Eklentinin yerleşik yolu: Android'de uygulama bildirim ayarları
  /// (olmazsa uygulama bilgisi), iOS'ta uygulamanın Bildirimler sayfası
  /// (15.4+; olmazsa uygulamanın Ayarlar sayfası). iOS'ta eklenti açamazsa
  /// `app-settings:` adresi denenir.
  @override
  Future<bool> openSettings() async {
    if (await _service._ready()) {
      try {
        final android = _android;
        if (android != null) return await android.openAppNotificationSettings() ?? false;
        final ios = _ios;
        if (ios != null && (await ios.openAppNotificationSettings() ?? false)) return true;
      } catch (e) {
        debugPrint('[NOTIF] Bildirim ayarları açılamadı: $e');
      }
    }
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      return await launchUrl(Uri.parse('app-settings:'));
    } catch (e) {
      debugPrint('[NOTIF] app-settings: açılamadı: $e');
      return false;
    }
  }
}

/// [NotificationService.alertSessionEndInForeground] kuralı: titreşim her
/// zaman; ses yalnızca kullanıcının bildirim tercihi açıkken.
@visibleForTesting
Future<void> runForegroundSessionEndAlert({
  required Future<void> Function() vibrate,
  required Future<bool> Function() notificationsEnabled,
  required Future<void> Function() playSound,
}) async {
  try {
    await vibrate();
  } catch (e) {
    debugPrint('[NOTIF] Titreşim çalışmadı: $e');
  }
  if (await notificationsEnabled()) await playSound();
}
