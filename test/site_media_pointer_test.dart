import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/y_site_media_capture_test.dart' as media;

void main() {
  for (final initiallyPropagate in [false, true]) {
    testWidgets(
      'media tap uses device events and restores flag=$initiallyPropagate',
      (tester) async {
        final binding = tester.binding;
        final previous = binding.shouldPropagateDevicePointerEvents;
        binding.shouldPropagateDevicePointerEvents = initiallyPropagate;
        addTearDown(
          () => binding.shouldPropagateDevicePointerEvents = previous,
        );
        var taps = 0;
        final sources = <TestBindingEventSource>[];
        final positions = <Offset>[];
        final pointerIds = <int>{};
        void record(PointerEvent event) {
          if (event is PointerDownEvent || event is PointerUpEvent) {
            sources.add(binding.pointerEventSource);
            positions.add(event.position);
            pointerIds.add(event.pointer);
            expect(binding.shouldPropagateDevicePointerEvents, isTrue);
          }
        }

        binding.pointerRouter.addGlobalRoute(record);
        addTearDown(() => binding.pointerRouter.removeGlobalRoute(record));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('Actual action'),
                ),
              ),
            ),
          ),
        );
        final center = tester.getCenter(find.text('Actual action'));
        await media.mediaTapWithoutPointerOverlay(tester, center);
        await tester.pump();
        expect(taps, 1);
        expect(sources, [
          TestBindingEventSource.device,
          TestBindingEventSource.device,
        ]);
        expect(positions, [center, center]);
        expect(pointerIds, hasLength(1));
        expect(binding.shouldPropagateDevicePointerEvents, initiallyPropagate);
        expect(tester.takeException(), isNull);
        // Flutter verifies its default flag before addTearDown callbacks run.
        binding.shouldPropagateDevicePointerEvents = previous;
      },
    );
  }

  testWidgets('media tap restores propagation after widget callback error', (
    tester,
  ) async {
    final binding = tester.binding;
    final previous = binding.shouldPropagateDevicePointerEvents;
    binding.shouldPropagateDevicePointerEvents = false;
    addTearDown(() => binding.shouldPropagateDevicePointerEvents = previous);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => throw StateError('expected callback failure'),
              child: const Text('Failing action'),
            ),
          ),
        ),
      ),
    );
    await media.mediaTapWithoutPointerOverlay(
      tester,
      tester.getCenter(find.text('Failing action')),
    );
    expect(tester.takeException(), isA<StateError>());
    expect(binding.shouldPropagateDevicePointerEvents, isFalse);
  });
}
