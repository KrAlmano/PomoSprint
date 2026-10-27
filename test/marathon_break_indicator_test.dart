import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/widgets/marathon_break_indicator.dart';

Finder _key(String key) => find.byKey(ValueKey(key));

Widget _app({
  bool reducedMotion = false,
  bool visible = true,
  double size = 140,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: TickerMode(
        enabled: visible,
        child: MarathonBreakIndicator(size: size),
      ),
    ),
  ),
);

double _steamDrift(WidgetTester tester) => tester
    .widget<Transform>(_key('marathon-break-steam-drift'))
    .transform
    .storage[13];

double _steamOpacity(WidgetTester tester) =>
    tester.widget<Opacity>(_key('marathon-break-steam-opacity')).opacity;

void main() {
  testWidgets('cup stays still while steam moves slowly within a small range', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    final initialCup = tester.getRect(_key('marathon-break-cup'));
    final initialDrift = _steamDrift(tester);
    final initialOpacity = _steamOpacity(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(_steamDrift(tester), isNot(initialDrift));
    expect(_steamOpacity(tester), isNot(initialOpacity));
    expect(_steamDrift(tester).abs(), lessThanOrEqualTo(140 * 0.015));
    expect(_steamOpacity(tester), inInclusiveRange(0.35, 0.5));
    expect(tester.getRect(_key('marathon-break-cup')), initialCup);
    expect(
      tester.widget<Icon>(_key('marathon-break-cup')).icon,
      Icons.free_breakfast_rounded,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion is still and switching preference stops ticks', (
    tester,
  ) async {
    await tester.pumpWidget(_app(reducedMotion: true));
    final stillDrift = _steamDrift(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(_steamDrift(tester), stillDrift);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpWidget(_app(reducedMotion: true));
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    final stoppedDrift = _steamDrift(tester);
    await tester.pump(const Duration(seconds: 5));
    expect(_steamDrift(tester), stoppedDrift);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hidden TickerMode stops work and returning resumes steam', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(_app(visible: false));
    await tester.pump();
    final hiddenDrift = _steamDrift(tester);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 5));
    expect(_steamDrift(tester), hiddenDrift);
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(seconds: 1));
    expect(_steamDrift(tester), isNot(hiddenDrift));
    for (final size in [42.0, 140.0, 245.0]) {
      await tester.pumpWidget(_app(size: size));
      expect(
        tester.getSize(find.byType(MarathonBreakIndicator)),
        Size.square(size),
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
  });
}
