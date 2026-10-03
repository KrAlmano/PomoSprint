import SwiftUI
import WidgetKit

/// PomoSprint widget uzantısı: yalnızca süren seansın Canlı Etkinliği
/// (kilit ekranı + Dynamic Island). Ana ekran widget'ı yok.
@main
struct PomoSprintTimerWidgetBundle: WidgetBundle {
  var body: some Widget {
    PomoSprintTimerLiveActivity()
  }
}
