import 'package:pomodoro/services/notification_service.dart';

/// Sistem bildirim izninin sahtesi. iOS gibi davranır: "izin yok" yanıtı hiç
/// sorulmamışla reddedilmişi ayırmaz; reddedildikten sonra istek pencere
/// göstermeden false döner (izin yalnızca ayarlardan verilir).
class FakeNotificationPermissions extends NotificationPermissionPlatform {
  FakeNotificationPermissions({this.granted = false, this.systemDenied = false, this.grantOnRequest = true});

  /// Sistemdeki izin (null: okunamıyor / desteklenmeyen platform).
  bool? granted;

  /// Sistem bu uygulama için "reddedildi" kaydı tutuyor: pencere çıkmaz.
  bool systemDenied;

  /// Sistem penceresi çıkarsa kullanıcının yanıtı.
  bool grantOnRequest;

  bool openSettingsResult = true;

  /// Doluysa istek bunu fırlatır (ör. Android "izin isteği sürüyor").
  Object? requestError;
  int requests = 0;
  int dialogs = 0;
  int settingsOpened = 0;

  @override
  Future<bool?> isGranted() async => granted;

  @override
  Future<bool> request() async {
    requests++;
    final error = requestError;
    if (error != null) throw error;
    if (granted == true) return true;
    if (systemDenied) return false;
    dialogs++;
    granted = grantOnRequest;
    systemDenied = !grantOnRequest;
    return grantOnRequest;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return openSettingsResult;
  }

  /// Kullanıcı sistem ayarlarından izni açtı ya da kapattı.
  void changeInSettings({required bool allow}) {
    granted = allow;
    systemDenied = !allow;
  }
}
