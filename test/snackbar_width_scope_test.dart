import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/widgets/snackbar_width_scope.dart';

const _portrait = Size(402, 874);
const _landscape = Size(874, 402);

void main() {
  testWidgets(
    'açık AlertDialog döndürülürken bütün AnimatedTheme kareleri geçerlidir',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = _portrait;
      addTearDown(tester.view.reset);
      final navigatorKey = GlobalKey<NavigatorState>();
      var count = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: AppTheme.lightTheme,
          builder: (context, child) => SnackBarWidthScope(child: child!),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Sayaç $count'),
                    TextButton(
                      key: const ValueKey('counter'),
                      onPressed: () => setState(() => count++),
                      child: const Text('Artır'),
                    ),
                    TextButton(
                      key: const ValueKey('open-dialog'),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Maraton nedir?'),
                          content: const Text('Mola bitince Buradayım de.'),
                          actions: [
                            TextButton(
                              key: const ValueKey('close-dialog'),
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Tamam'),
                            ),
                          ],
                        ),
                      ),
                      child: const Text('Bilgi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('counter')));
      await tester.pump();
      expect(find.text('Sayaç 1'), findsOneWidget);
      final originalNavigator = navigatorKey.currentState;
      await tester.tap(find.byKey(const ValueKey('open-dialog')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      // Exercise actual animation frames; settling immediately would hide
      // the invalid midpoint when width is present but behavior is still null.
      for (final size in [_landscape, _portrait, _landscape, _portrait]) {
        tester.view.physicalSize = size;
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$size first frame');
        for (var frame = 0; frame < 16; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            tester.takeException(),
            isNull,
            reason: '$size AnimatedTheme frame $frame',
          );
        }
        expect(navigatorKey.currentState, same(originalNavigator));
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Sayaç 1'), findsOneWidget);
        final theme = Theme.of(
          tester.element(find.byKey(const ValueKey('close-dialog'))),
        ).snackBarTheme;
        expect(theme.behavior, SnackBarBehavior.floating);
        expect(
          theme.width,
          size == _landscape ? SnackBarWidthScope.wideWidth : isNull,
        );
      }
      await tester.tap(find.byKey(const ValueKey('close-dialog')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Sayaç 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('açık yüzen SnackBar döndürülünce konumu ve genişliği korunur', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _portrait;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => SnackBarWidthScope(child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('İyi çalışmalar'),
                    duration: Duration(minutes: 1),
                  ),
                ),
                child: const Text('Göster'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Göster'));
    await tester.pump(const Duration(milliseconds: 500));
    for (final size in [_portrait, _landscape, _portrait]) {
      tester.view.physicalSize = size;
      await tester.pump();
      for (var frame = 0; frame < 16; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull, reason: '$size frame $frame');
      }
      expect(find.text('İyi çalışmalar'), findsOneWidget);
      final rect = tester.getRect(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(rect.center.dx, closeTo(size.width / 2, 0.5));
      expect(rect.width, lessThanOrEqualTo(size.width));
      if (size == _landscape) {
        expect(rect.width, SnackBarWidthScope.wideWidth);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
