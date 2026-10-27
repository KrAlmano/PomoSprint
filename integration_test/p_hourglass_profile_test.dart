// Local rendering diagnostics only. This entry point never starts app.main(),
// reads .env, initializes Supabase, or touches an account. Run on a native device:
// flutter test integration_test/p_hourglass_profile_test.dart -d <device-id>
// A debug simulator run is NOT production performance or a battery benchmark.
import 'dart:convert';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lottie/lottie.dart';
import 'package:pomodoro/widgets/hourglass_widget.dart';

Widget _app({
  required bool running,
  bool visible = true,
  bool reducedMotion = false,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
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
          remainingSeconds: 1200,
          sandColor: Colors.red,
        ),
      ),
    ),
  ),
);

AnimationController _controller(WidgetTester tester) =>
    tester.widget<LottieBuilder>(find.byType(LottieBuilder)).controller!
        as AnimationController;

double? _percentile(List<int> values, double percentile) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  final index = ((sorted.length * percentile).ceil() - 1).clamp(
    0,
    sorted.length - 1,
  );
  return sorted[index] / 1000;
}

Map<String, Object?> _summary(
  List<FrameTiming> frames,
  Duration duration,
  double refreshRate,
) {
  final build = frames.map((f) => f.buildDuration.inMicroseconds).toList();
  final raster = frames.map((f) => f.rasterDuration.inMicroseconds).toList();
  const sixtyHzBudgetUs = 1000000 / 60;
  final displayBudgetUs = refreshRate > 0 ? 1000000 / refreshRate : null;
  int overBudget(double budget) => frames
      .where(
        (f) =>
            f.buildDuration.inMicroseconds > budget ||
            f.rasterDuration.inMicroseconds > budget,
      )
      .length;
  return {
    'requested_sample_seconds': duration.inMilliseconds / 1000,
    'frame_count': frames.length,
    // Idle states correctly have no new frames, so missing percentiles are null.
    // A fabricated 0ms percentile would suggest a measurement that never ran.
    'build_ms': {
      'p50': _percentile(build, .5),
      'p90': _percentile(build, .9),
      'p99': _percentile(build, .99),
    },
    'raster_ms': {
      'p50': _percentile(raster, .5),
      'p90': _percentile(raster, .9),
      'p99': _percentile(raster, .99),
    },
    'frames_build_or_raster_over_16_67_ms': overBudget(sixtyHzBudgetUs),
    'display_refresh_hz': refreshRate,
    'display_budget_ms': displayBudgetUs == null
        ? null
        : displayBudgetUs / 1000,
    'frames_build_or_raster_over_display_budget': displayBudgetUs == null
        ? null
        : overBudget(displayBudgetUs),
  };
}

Future<Map<String, Object?>> _measure(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester, {
  required Duration duration,
  required bool running,
  bool visible = true,
  bool reducedMotion = false,
}) async {
  await tester.pumpWidget(
    _app(running: running, visible: visible, reducedMotion: reducedMotion),
  );
  // The engine batches timings. Flush the transition before the measured range;
  // collect a drain afterward without treating its extra frames as sample time.
  await Future<void>.delayed(const Duration(seconds: 2));
  final observed = <FrameTiming>[];
  void onTimings(List<FrameTiming> frames) => observed.addAll(frames);
  binding.addTimingsCallback(onTimings);
  try {
    await Future<void>.delayed(duration + const Duration(seconds: 2));
  } finally {
    binding.removeTimingsCallback(onTimings);
  }

  observed.sort(
    (a, b) => a
        .timestampInMicroseconds(FramePhase.buildStart)
        .compareTo(b.timestampInMicroseconds(FramePhase.buildStart)),
  );
  // FrameTiming's epoch is unspecified. Anchor to its first observed timestamp
  // instead of comparing it with DateTime or a possibly different trace clock.
  final first = observed.firstOrNull?.timestampInMicroseconds(
    FramePhase.buildStart,
  );
  final frames = first == null
      ? <FrameTiming>[]
      : observed
            .where(
              (f) =>
                  f.timestampInMicroseconds(FramePhase.buildStart) - first <
                  duration.inMicroseconds,
            )
            .toList();
  return {
    ..._summary(frames, duration, tester.view.display.refreshRate),
    'running_requested': running,
    'ticker_mode_enabled': visible,
    'reduced_motion': reducedMotion,
    'controller_animating': _controller(tester).isAnimating,
    'pending_frame_callbacks_at_end': binding.transientCallbackCount,
    'drain_seconds_excluded': 2,
  };
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'p · isolated real-asset hourglass rendering diagnostics',
    (tester) async {
      Lottie.cache.clear();
      await tester.pumpWidget(_app(running: true));
      final assetDeadline = DateTime.now().add(const Duration(seconds: 8));
      while (_controller(tester).duration == null &&
          DateTime.now().isBefore(assetDeadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(_controller(tester).duration, isNotNull);
      expect(_controller(tester).isAnimating, isTrue);

      final samples = <String, Object?>{};
      samples['running'] = await _measure(
        binding,
        tester,
        duration: const Duration(seconds: 26),
        running: true,
      );
      samples['paused'] = await _measure(
        binding,
        tester,
        duration: const Duration(seconds: 3),
        running: false,
      );
      expect(_controller(tester).isAnimating, isFalse);
      samples['hidden'] = await _measure(
        binding,
        tester,
        duration: const Duration(seconds: 3),
        running: true,
        visible: false,
      );
      samples['reduced_motion'] = await _measure(
        binding,
        tester,
        duration: const Duration(seconds: 3),
        running: true,
        reducedMotion: true,
      );
      expect(_controller(tester).isAnimating, isFalse);

      final report = <String, Object?>{
        'purpose': 'isolated_hourglass_diagnostic_not_release_performance',
        'build_mode': kReleaseMode
            ? 'release'
            : kProfileMode
            ? 'profile'
            : 'debug',
        'platform': defaultTargetPlatform.name,
        'asset': 'assets/sand_timer.json',
        'asset_frame_rate': 30,
        'logical_width':
            tester.view.physicalSize.width / tester.view.devicePixelRatio,
        'logical_height':
            tester.view.physicalSize.height / tester.view.devicePixelRatio,
        'limitations': [
          'Simulator/debug timings do not establish production FPS or battery use.',
          'This isolates the widget; full-screen/app overhead is not measured.',
          'FrameTiming counts engine frames, not distinct Lottie artwork frames.',
          'Idle states may have no frames and therefore null percentiles.',
        ],
        'samples': samples,
      };
      binding.reportData ??= <String, dynamic>{};
      binding.reportData!['hourglass_profile'] = report;
      debugPrint('[HOURGLASS_PROFILE] ${jsonEncode(report)}');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(
        (samples['running']! as Map<String, Object?>)['frame_count'],
        greaterThan(0),
        reason:
            'A native FrameTiming sample must exist before reporting timings.',
      );
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
