import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:pomodoro/widgets/hourglass_widget.dart';

// A fresh cache and a controlled bundle reproduce a real slow asset load without
// relying on disk/network timing or changing the production widget API.
class _DelayedHourglassBundle extends CachingAssetBundle {
  final Completer<ByteData> _asset = Completer<ByteData>();
  int requests = 0;

  @override
  Future<ByteData> load(String key) {
    if (key != 'assets/sand_timer.json') return rootBundle.load(key);
    requests++;
    return _asset.future;
  }

  void release() {
    if (_asset.isCompleted) return;
    final bytes = File('assets/sand_timer.json').readAsBytesSync();
    _asset.complete(ByteData.sublistView(bytes));
  }
}

Widget _app(
  _DelayedHourglassBundle bundle, {
  bool running = false,
  bool reducedMotion = false,
  bool visible = true,
  Color color = Colors.red,
  int remainingSeconds = 100,
}) => DefaultAssetBundle(
  bundle: bundle,
  child: MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: TickerMode(
          enabled: visible,
          child: HourglassWidget(
            isRunning: running,
            size: 210,
            totalSeconds: 1500,
            remainingSeconds: remainingSeconds,
            sandColor: color,
          ),
        ),
      ),
    ),
  ),
);

AnimationController _controller(WidgetTester tester) =>
    tester.widget<LottieBuilder>(find.byType(LottieBuilder)).controller!
        as AnimationController;

Future<void> _load(WidgetTester tester, _DelayedHourglassBundle bundle) async {
  bundle.release();
  // Asset parsing only schedules microtasks; fixed pumps keep running animations
  // deterministic and avoid pumpAndSettle on an intentionally repeating timer.
  await tester.pump();
  await tester.pump();
  await tester.pump();
}

Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  expect(tester.binding.transientCallbackCount, 0);
}

void main() {
  setUp(Lottie.cache.clear);
  tearDown(Lottie.cache.clear);

  testWidgets('starting before the asset loads waits safely for its duration', (
    tester,
  ) async {
    final bundle = _DelayedHourglassBundle();
    await tester.pumpWidget(_app(bundle));
    expect(bundle.requests, 1);
    expect(_controller(tester).duration, isNull);

    await tester.pumpWidget(_app(bundle, running: true));
    final prematureStartError = tester.takeException();
    await _load(tester, bundle);
    final controller = _controller(tester);
    final loadedDuration = controller.duration;
    final runningAfterLoad = controller.isAnimating;
    await _dispose(tester);

    expect(prematureStartError, isNull);
    expect(loadedDuration, isNotNull);
    expect(runningAfterLoad, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enabling reduced motion stops an in-flight category shake', (
    tester,
  ) async {
    final bundle = _DelayedHourglassBundle();
    await tester.pumpWidget(_app(bundle));
    await _load(tester, bundle);
    await tester.pumpWidget(_app(bundle, color: Colors.blue));
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pumpWidget(
      _app(bundle, color: Colors.blue, reducedMotion: true),
    );
    await tester.pump();
    final pendingTicks = tester.binding.transientCallbackCount;
    await tester.pump(const Duration(milliseconds: 100));
    final transform = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(HourglassWidget),
            matching: find.byType(Transform),
          )
          .first,
    );
    final restingTransform = transform.transform.isIdentity();
    await _dispose(tester);

    expect(pendingTicks, 0);
    expect(restingTransform, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pause freezes the frame and resuming restarts the same asset', (
    tester,
  ) async {
    final bundle = _DelayedHourglassBundle();
    await tester.pumpWidget(_app(bundle, running: true));
    await _load(tester, bundle);
    await tester.pump(const Duration(milliseconds: 300));
    final controller = _controller(tester);
    expect(controller.isAnimating, isTrue);

    await tester.pumpWidget(_app(bundle));
    final pausedProgress = controller.value;
    await tester.pump(const Duration(seconds: 1));
    expect(controller.isAnimating, isFalse);
    expect(controller.value, pausedProgress);
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(_app(bundle, running: true));
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.isAnimating, isTrue);
    expect(controller.value, greaterThan(pausedProgress));
    expect(bundle.requests, 1);
    expect(
      tester.getSize(find.byType(HourglassWidget)),
      const Size(210, 220.5),
    );
    await _dispose(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hidden TickerMode suspends frame callbacks and resumes on return',
    (tester) async {
      final bundle = _DelayedHourglassBundle();
      await tester.pumpWidget(_app(bundle, running: true));
      await _load(tester, bundle);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(_app(bundle, running: true, visible: false));
      await tester.pump();
      final hiddenProgress = _controller(tester).value;
      await tester.pump(const Duration(seconds: 2));
      expect(_controller(tester).value, hiddenProgress);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(_app(bundle, running: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await _dispose(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a late asset respects reduced motion and resumes when allowed', (
    tester,
  ) async {
    final bundle = _DelayedHourglassBundle();
    await tester.pumpWidget(_app(bundle, running: true, reducedMotion: true));
    await _load(tester, bundle);
    expect(_controller(tester).duration, isNotNull);
    expect(_controller(tester).isAnimating, isFalse);
    expect(tester.binding.transientCallbackCount, 0);

    await tester.pumpWidget(_app(bundle, running: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_controller(tester).isAnimating, isTrue);
    await tester.pumpWidget(_app(bundle, running: true, reducedMotion: true));
    await tester.pump();
    expect(_controller(tester).isAnimating, isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    await _dispose(tester);
    expect(tester.takeException(), isNull);
  });
}
