import ActivityKit
import SwiftUI
import WidgetKit

/// Marka renkleri (lib/theme.dart: AppColors.primary ve koyu temadaki darkPrimary).
enum PomoBrand {
  static let primary = Color(red: 0xB4 / 255.0, green: 0x26 / 255.0, blue: 0x1F / 255.0)
  static let primaryOnDark = Color(red: 0xFF / 255.0, green: 0x7A / 255.0, blue: 0x68 / 255.0)

  static func accent(for scheme: ColorScheme) -> Color {
    scheme == .dark ? primaryOnDark : primary
  }
}

enum TimerPhase {
  case running
  case paused
  case finished
}

extension PomoSprintTimerAttributes.ContentState {
  /// Bitiş anı geçmişse (etkinlik eskidiyse) seans tamamlanmış görünür;
  /// uygulama askıdayken de doğru son görünüm.
  func phase(isStale: Bool) -> TimerPhase {
    if isPaused { return .paused }
    if isStale || endsAt <= Date() { return .finished }
    return .running
  }

  /// Geri sayım aralığı (alt sınır üst sınırı geçemez).
  var timerRange: ClosedRange<Date> {
    min(startedAt, endsAt)...endsAt
  }

  var pausedProgress: Double {
    guard totalSeconds > 0 else { return 0 }
    return min(1, max(0, Double(remainingSeconds) / Double(totalSeconds)))
  }

  /// Sabit kalan süre, sayaç ekranındaki gibi "MM:SS".
  var pausedClock: String {
    let seconds = max(0, remainingSeconds)
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%02d:%02d", minutes, secs)
  }

  func statusText(for phase: TimerPhase) -> String {
    switch phase {
    case .running: return runningLabel
    case .paused: return pausedLabel
    case .finished: return finishedLabel
    }
  }
}

struct PomoSprintTimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PomoSprintTimerAttributes.self) { context in
      LockScreenTimerView(state: context.state, phase: context.state.phase(isStale: context.isStale))
    } dynamicIsland: { context in
      let state = context.state
      let phase = state.phase(isStale: context.isStale)
      // Dynamic Island her zaman koyu zeminlidir.
      let accent = PomoBrand.primaryOnDark
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 8) {
            PhaseBadge(phase: phase, accent: accent, size: 30)
            Text(state.categoryName)
              .font(.headline)
              .lineLimit(1)
          }
          .padding(.leading, 4)
        }
        DynamicIslandExpandedRegion(.trailing) {
          TimerClock(state: state, phase: phase)
            .font(.system(size: 26, weight: .semibold, design: .rounded))
            .foregroundStyle(phase == .running ? accent : .white)
            .frame(width: 96, alignment: .trailing)
            .padding(.trailing, 4)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 6) {
            TimerProgress(state: state, phase: phase)
              .tint(accent)
            Text(phase == .finished ? state.finishedHint : state.statusText(for: phase))
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          .padding(.horizontal, 4)
        }
      } compactLeading: {
        Image(systemName: phase.symbolName)
          .foregroundStyle(accent)
      } compactTrailing: {
        TimerClock(state: state, phase: phase)
          .font(.system(size: 14, weight: .semibold, design: .rounded))
          .foregroundStyle(accent)
          .frame(width: 46, alignment: .trailing)
      } minimal: {
        Image(systemName: phase.symbolName)
          .foregroundStyle(accent)
      }
      .keylineTint(accent)
    }
  }
}

extension TimerPhase {
  var symbolName: String {
    switch self {
    case .running: return "hourglass"
    case .paused: return "pause.fill"
    case .finished: return "checkmark"
    }
  }
}

/// Kilit ekranı (ve bildirim merkezi) görünümü. Açık/koyu temaya uyar.
struct LockScreenTimerView: View {
  let state: PomoSprintTimerAttributes.ContentState
  let phase: TimerPhase
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let accent = PomoBrand.accent(for: colorScheme)
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 12) {
        PhaseBadge(phase: phase, accent: accent, size: 40)
        VStack(alignment: .leading, spacing: 2) {
          Text(phase == .finished ? state.finishedLabel : state.categoryName)
            .font(.headline)
            .lineLimit(1)
          Text(phase == .finished ? state.finishedHint : state.statusText(for: phase))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(phase == .finished ? 2 : 1)
        }
        Spacer(minLength: 8)
        TimerClock(state: state, phase: phase)
          .font(.system(size: 34, weight: .semibold, design: .rounded))
          .foregroundStyle(phase == .running ? accent : .primary)
          .frame(width: 118, alignment: .trailing)
      }
      TimerProgress(state: state, phase: phase)
        .tint(accent)
    }
    .padding(16)
    .activitySystemActionForegroundColor(accent)
  }
}

/// Kalan süre: çalışırken sistemin yürüttüğü canlı geri sayım (uygulama
/// çalışmasa da akar), duraklatılmışken sabit süre.
struct TimerClock: View {
  let state: PomoSprintTimerAttributes.ContentState
  let phase: TimerPhase

  var body: some View {
    switch phase {
    case .running:
      Text(timerInterval: state.timerRange, countsDown: true)
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    case .paused:
      Text(state.pausedClock)
        .monospacedDigit()
    case .finished:
      Text("00:00")
        .monospacedDigit()
    }
  }
}

struct TimerProgress: View {
  let state: PomoSprintTimerAttributes.ContentState
  let phase: TimerPhase

  var body: some View {
    switch phase {
    case .running:
      ProgressView(timerInterval: state.timerRange, countsDown: true) {
        EmptyView()
      } currentValueLabel: {
        EmptyView()
      }
    case .paused:
      ProgressView(value: state.pausedProgress)
    case .finished:
      ProgressView(value: 0)
    }
  }
}

struct PhaseBadge: View {
  let phase: TimerPhase
  let accent: Color
  let size: CGFloat

  var body: some View {
    ZStack {
      Circle()
        .fill(accent.opacity(0.18))
      Image(systemName: phase.symbolName)
        .font(.system(size: size * 0.45, weight: .semibold))
        .foregroundStyle(accent)
    }
    .frame(width: size, height: size)
  }
}
