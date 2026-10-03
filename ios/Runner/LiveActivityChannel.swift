import ActivityKit
import Flutter
import Foundation

/// Kilit ekranı sayacının iOS tarafı: Dart'taki IosLiveActivityPlatform
/// (lib/services/lock_screen_timer.dart) bu kanalı çağırır.
///
/// - `start`: artakalan etkinlikleri bitirir, yenisini başlatır.
/// - `update`: aynı seansın etkinliğini günceller (duraklat/devam); yoksa başlatır.
/// - `end`: tüm etkinlikleri hemen kaldırır.
///
/// `start`/`update` etkinlik gösterildiyse true döner; iOS 16.2 altında ya da
/// kullanıcı Canlı Etkinlikleri kapattıysa false.
enum LiveActivityChannel {
  static let name = "com.pomosprint.app/live_activity"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      handle(call, result: result)
    }
  }

  private static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 16.2, *) else {
      result(call.method == "end" ? nil : false)
      return
    }
    switch call.method {
    case "start", "update":
      guard let args = call.arguments as? [String: Any],
            let payload = LiveActivityPayload(args) else {
        result(FlutterError(code: "bad_args", message: "Invalid live activity payload", details: nil))
        return
      }
      let restart = call.method == "start"
      Task { @MainActor in
        let shown = await LiveActivityController.shared.show(payload, restart: restart)
        result(shown)
      }
    case "end":
      Task { @MainActor in
        await LiveActivityController.shared.endAll()
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// Dart'tan gelen argümanlar (LockScreenTimerContent.toLiveActivityArguments).
struct LiveActivityPayload {
  let sessionId: String
  let isPaused: Bool
  let endsAt: Date
  let startedAt: Date
  let remainingSeconds: Int
  let totalSeconds: Int
  let categoryName: String
  let runningLabel: String
  let pausedLabel: String
  let finishedLabel: String
  let finishedHint: String

  init?(_ args: [String: Any]) {
    guard let sessionId = args["sessionId"] as? String, !sessionId.isEmpty,
          let endsAtMs = (args["endsAtMs"] as? NSNumber)?.doubleValue,
          let startedAtMs = (args["startedAtMs"] as? NSNumber)?.doubleValue,
          let remaining = (args["remainingSeconds"] as? NSNumber)?.intValue,
          let total = (args["totalSeconds"] as? NSNumber)?.intValue,
          total > 0
    else { return nil }
    self.sessionId = sessionId
    isPaused = (args["isPaused"] as? Bool) ?? false
    endsAt = Date(timeIntervalSince1970: endsAtMs / 1000)
    startedAt = Date(timeIntervalSince1970: startedAtMs / 1000)
    remainingSeconds = max(0, remaining)
    totalSeconds = total
    categoryName = (args["categoryName"] as? String) ?? "Pomodoro"
    runningLabel = (args["runningLabel"] as? String) ?? ""
    pausedLabel = (args["pausedLabel"] as? String) ?? ""
    finishedLabel = (args["finishedLabel"] as? String) ?? ""
    finishedHint = (args["finishedHint"] as? String) ?? ""
  }

  @available(iOS 16.1, *)
  var contentState: PomoSprintTimerAttributes.ContentState {
    PomoSprintTimerAttributes.ContentState(
      endsAt: endsAt,
      startedAt: startedAt,
      isPaused: isPaused,
      remainingSeconds: remainingSeconds,
      totalSeconds: totalSeconds,
      categoryName: categoryName,
      runningLabel: runningLabel,
      pausedLabel: pausedLabel,
      finishedLabel: finishedLabel,
      finishedHint: finishedHint
    )
  }
}

@available(iOS 16.2, *)
@MainActor
final class LiveActivityController {
  static let shared = LiveActivityController()

  private init() {}

  func show(_ payload: LiveActivityPayload, restart: Bool) async -> Bool {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      await endAll()
      return false
    }
    // Çalışırken bitiş anında "eskir": widget "Seans tamamlandı" görünümüne
    // geçer (uygulama askıdayken de). Duraklatılmışken eskimez.
    let content = ActivityContent(
      state: payload.contentState,
      staleDate: payload.isPaused ? nil : payload.endsAt,
      relevanceScore: 100
    )
    let activities = Activity<PomoSprintTimerAttributes>.activities
    if !restart,
       let current = activities.first(where: { $0.attributes.sessionId == payload.sessionId && Self.isLive($0) }) {
      for other in activities where other.id != current.id {
        await other.end(nil, dismissalPolicy: .immediate)
      }
      await current.update(content)
      return true
    }

    // Başka seanstan (ya da önceki süreçten) artakalan etkinlikler bitirilir.
    for activity in activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
    do {
      _ = try Activity.request(
        attributes: PomoSprintTimerAttributes(sessionId: payload.sessionId),
        content: content,
        pushType: nil
      )
      return true
    } catch {
      NSLog("[LiveActivity] start failed: %@", error.localizedDescription)
      return false
    }
  }

  func endAll() async {
    for activity in Activity<PomoSprintTimerAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }

  private static func isLive(_ activity: Activity<PomoSprintTimerAttributes>) -> Bool {
    activity.activityState != .ended && activity.activityState != .dismissed
  }
}
