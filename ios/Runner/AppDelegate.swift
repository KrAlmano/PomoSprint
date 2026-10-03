import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications: ön planda bildirim gösterimi ve dokunma
    // geri çağrıları için gerekli (eklenti README'si, iOS kurulumu).
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Kilit ekranı sayacı (Canlı Etkinlik) kanalı: lib/services/lock_screen_timer.dart
    LiveActivityChannel.register(with: engineBridge.applicationRegistrar.messenger())
  }
}
