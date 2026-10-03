import ActivityKit
import Foundation

/// Süren Pomodoro seansının Canlı Etkinliği (kilit ekranı + Dynamic Island).
///
/// Bu dosya hem Runner'da (etkinliği başlatır/günceller/bitirir) hem de
/// PomoSprintTimerWidget uzantısında (görünümü çizer) derlenir. Veri yalnızca
/// Dart'tan MethodChannel ile gelir; App Group kullanılmaz. Metinler Dart'ta
/// uygulamanın o anki dilinde hazırlanır, widget kendi çevirisini taşımaz.
@available(iOS 16.1, *)
struct PomoSprintTimerAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    /// Geri sayımın bittiği an (duraklatılmışken yalnızca bilgi).
    var endsAt: Date
    /// İlerleme aralığının başı: endsAt - toplam süre.
    var startedAt: Date
    var isPaused: Bool
    /// Duraklatılmışken gösterilen sabit kalan süre (sn).
    var remainingSeconds: Int
    var totalSeconds: Int
    var categoryName: String
    var runningLabel: String
    var pausedLabel: String
    var finishedLabel: String
    var finishedHint: String
  }

  /// Seansın client_uuid'i: aynı seansın etkinliği güncellenir, başkası bitirilir.
  var sessionId: String
}
