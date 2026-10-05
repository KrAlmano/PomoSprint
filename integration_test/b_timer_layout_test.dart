// (b) SAYAÇ DÜZENİ, gerçek simülatör/emülatör (cihazın boyutu ve güvenli alanı):
// BAŞLAT ekranın içinde ve alt gezinmenin üstünde, 25 dk ile 50 dk aynı
// satırda, kum saati görünür, taşma (RenderFlex overflow) yok.
//
// Çalıştırma: tool/local_supabase/e2e/sim/run_sim_e2e.sh b

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/widgets/hourglass_widget.dart';

import 'support/e2e.dart';

void main() {
  initE2e();

  testWidgets('b · cihaz boyutunda BAŞLAT görünür, 25/50 tek satır, kum saati, taşma yok', (tester) async {
    await openShellWithNewAccount(tester, 'sayac');
    await pumpUntil(tester, find.byType(TimerScreen));
    await pumpUntilTrue(
      tester,
      () => find.descendant(of: find.byType(TimerScreen), matching: find.byType(FilterChip)).evaluate().length == 8,
      reason: 'sunucu kategorileri yüklendi',
    );
    await pumpFor(tester, const Duration(seconds: 1));

    final view = tester.view;
    final screen = view.physicalSize / view.devicePixelRatio;
    expect(screen.width, greaterThanOrEqualTo(320));
    expect(screen.height, greaterThan(screen.width));
    debugPrint('[E2E] Gerçek cihaz mantıksal boyutu: $screen');
    final screenRect = Offset.zero & screen;
    final safeBottom = screen.height - view.padding.bottom / view.devicePixelRatio;

    final start = find.widgetWithText(ElevatedButton, tr('btn_start'));
    expect(start, findsOneWidget);
    final startRect = tester.getRect(start);
    final navTop = tester.getRect(find.byType(NavigationBar)).top;
    expect(screenRect.contains(startRect.topLeft) && screenRect.contains(startRect.bottomRight), isTrue,
        reason: 'BAŞLAT ekran içinde: $startRect');
    expect(startRect.bottom, lessThanOrEqualTo(navTop), reason: 'BAŞLAT alt gezinmenin üstünde ($startRect, nav $navTop)');
    expect(startRect.bottom, lessThanOrEqualTo(safeBottom));
    // Kaydırma gerekmeden görünür: kaydırılabilir alan varsa başta.
    final scrollables = find.descendant(of: find.byType(TimerScreen), matching: find.byType(Scrollable));
    for (final element in scrollables.evaluate()) {
      final state = (element as StatefulElement).state as ScrollableState;
      if (state.position.axis == Axis.vertical) {
        expect(state.position.pixels, 0, reason: 'sayaç kaydırılmadan görünür');
      }
    }

    final unit = tr('minutes_unit_short');
    final r25 = tester.getRect(find.text('25 $unit'));
    final r50 = tester.getRect(find.text('50 $unit'));
    expect(r25.center.dy, closeTo(r50.center.dy, 1), reason: '25 dk ve 50 dk aynı satırda ($r25 / $r50)');
    expect(r50.left, greaterThan(r25.right), reason: '50 dk, 25 dk\'nın sağında');
    expect(screenRect.contains(r50.bottomRight), isTrue);

    final hourglass = tester.getRect(find.byType(HourglassWidget));
    expect(hourglass.width, greaterThan(120), reason: 'kum saati makul boyutta: $hourglass');
    expect(hourglass.top, greaterThanOrEqualTo(0));
    expect(hourglass.bottom, lessThan(r25.top), reason: 'kum saati kontrollerin üstünde, görünür');

    expect(tester.takeException(), isNull, reason: 'taşma ya da yerleşim hatası yok');
    await E2eHost.screenshot(tester, 'e2e-sayac');
    debugPrint('[E2E] sayaç: BAŞLAT $startRect, nav üstü $navTop, 25 $r25, 50 $r50, kum saati $hourglass');
  });
}
