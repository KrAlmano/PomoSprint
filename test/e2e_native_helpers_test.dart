import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/e2e.dart';

void main() {
  testWidgets('native tap waits for a blocking route overlay to leave', (
    tester,
  ) async {
    final blocked = ValueNotifier(true);
    final elapsed = Stopwatch();
    var keepChecking = true;
    var taps = 0;
    final oldFatal = WidgetController.hitTestWarningShouldBeFatal;
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() {
      keepChecking = false;
      elapsed.stop();
      blocked.dispose();
      WidgetController.hitTestWarningShouldBeFatal = oldFatal;
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: TextButton(
                  key: const ValueKey('native-button'),
                  onPressed: () => taps++,
                  child: const Text('Continue'),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: blocked,
                builder: (_, value, _) => value
                    ? const AbsorbPointer(
                        child: ColoredBox(color: Colors.white),
                      )
                    : const IgnorePointer(child: SizedBox.expand()),
              ),
            ],
          ),
        ),
      ),
    );
    final button = find.byKey(const ValueKey('native-button'));
    expect(button.hitTestable(), findsNothing);
    // Real elapsed time deliberately exceeds the old fixed 300 ms wait.
    // Check during pumped frames: a root-zone Timer can starve while the
    // widget test continuously pumps fake-time frames without event-loop I/O.
    void releaseAfterElapsed(Duration _) {
      if (!keepChecking) {
        return;
      }
      if (elapsed.elapsed >= const Duration(milliseconds: 650)) {
        blocked.value = false;
      } else {
        WidgetsBinding.instance.addPostFrameCallback(releaseAfterElapsed);
        WidgetsBinding.instance.scheduleFrame();
      }
    }

    elapsed.start();
    WidgetsBinding.instance.addPostFrameCallback(releaseAfterElapsed);
    WidgetsBinding.instance.scheduleFrame();
    await tapOn(tester, button, settle: Duration.zero);
    expect(blocked.value, isFalse);
    expect(taps, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
