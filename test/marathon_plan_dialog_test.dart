import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/widgets/marathon_plan_dialog.dart';
import 'package:pomodoro/widgets/marathon_progress_card.dart';

const _sizes = [
  Size(320, 568),
  Size(390, 844),
  Size(568, 320),
  Size(844, 390),
  Size(820, 1180),
  Size(1180, 820),
];

Finder _key(String value) => find.byKey(ValueKey(value));

Widget _app({
  Locale locale = const Locale('tr'),
  bool dark = false,
  double scale = 1,
  int initialCount = 2,
  int initialMinutes = 25,
  Map<int, Map<int, int>>? bonuses,
  required ValueChanged<MarathonPlanChoice?> onResult,
}) => MaterialApp(
  locale: locale,
  theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          key: const ValueKey('open-plan'),
          onPressed: () async => onResult(
            await showDialog<MarathonPlanChoice>(
              context: context,
              builder: (context) => MarathonPlanDialog(
                initialTotalSessions: initialCount,
                initialDurationMinutes: initialMinutes,
                marathonBonuses: bonuses,
                onInfo: () {},
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(_key('open-plan'));
  await tester.pumpAndSettle();
}

Future<void> _tapInBody(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _expectCircularChoices(
  WidgetTester tester, {
  required int selected,
  required AppLocalizations l10n,
  String? reason,
}) {
  final centers = <Offset>[];
  for (final count in [2, 3, 4]) {
    final finder = _key('marathon-count-$count');
    final rect = tester.getRect(finder);
    expect(rect.width, closeTo(56, 0.01), reason: reason);
    expect(rect.height, closeTo(56, 0.01), reason: reason);
    final button = tester.widget<OutlinedButton>(finder);
    expect(
      button.style!.shape!.resolve({}),
      isA<CircleBorder>(),
      reason: reason,
    );
    final semantics = tester
        .widget<Semantics>(_key('marathon-count-semantics-$count'))
        .properties;
    expect(semantics.selected, count == selected, reason: reason);
    expect(semantics.label, l10n.marathonSessionCount(count), reason: reason);
    centers.add(rect.center);
  }
  expect(centers[0].dy, closeTo(centers[1].dy, 0.01), reason: reason);
  expect(centers[1].dy, closeTo(centers[2].dy, 0.01), reason: reason);
  expect(
    centers[1].dx - centers[0].dx,
    closeTo(centers[2].dx - centers[1].dx, 0.01),
    reason: reason,
  );
}

void main() {
  testWidgets('planning returns each explicit choice only after start', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    for (final total in [2, 3, 4]) {
      for (final minutes in [25, 50]) {
        MarathonPlanChoice? result;
        var resultCalls = 0;
        await tester.pumpWidget(
          _app(
            onResult: (choice) {
              result = choice;
              resultCalls++;
            },
          ),
        );
        await _open(tester);
        await _tapInBody(tester, _key('marathon-count-$total'));
        await _tapInBody(tester, _key('marathon-duration-$minutes'));
        _expectCircularChoices(tester, selected: total, l10n: l10n);
        expect(resultCalls, 0);
        final preview = tester.widget<MarathonProgressCard>(
          find.byType(MarathonProgressCard),
        );
        expect(preview.totalSessions, total);
        expect(preview.durationMinutes, minutes);
        expect(preview.completedSessions, 0);
        expect(preview.stage, MarathonCardStage.preview);
        await tester.tap(_key('marathon-start'));
        await tester.pumpAndSettle();
        expect(resultCalls, 1);
        expect(result?.totalSessions, total);
        expect(result?.durationMinutes, minutes);
        expect(find.byType(MarathonPlanDialog), findsNothing);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('close and system back return no plan after changed selection', (
    tester,
  ) async {
    MarathonPlanChoice? result;
    var resultCalls = 0;
    await tester.pumpWidget(
      _app(
        onResult: (choice) {
          result = choice;
          resultCalls++;
        },
      ),
    );
    await _open(tester);
    await _tapInBody(tester, _key('marathon-count-4'));
    await _tapInBody(tester, _key('marathon-plan-cancel'));
    expect(resultCalls, 1);
    expect(result, isNull);
    await _open(tester);
    await _tapInBody(tester, _key('marathon-duration-50'));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(resultCalls, 2);
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bonus display follows configured matrix and current choices', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    await tester.pumpWidget(
      _app(
        initialCount: 3,
        initialMinutes: 50,
        bonuses: {
          25: {3: 7},
          50: {3: 11},
        },
        onResult: (_) {},
      ),
    );
    await _open(tester);
    expect(find.text(l10n.marathonBonusHint(11)), findsOneWidget);
    await _tapInBody(tester, _key('marathon-duration-25'));
    expect(find.text(l10n.marathonBonusHint(7)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid repeated start or close cannot pop the owning page', (
    tester,
  ) async {
    for (final action in ['marathon-start', 'marathon-plan-cancel']) {
      var resultCalls = 0;
      MarathonPlanChoice? result;
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: AppTheme.lightTheme,
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const ValueKey('open-owner'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (ownerContext) => Scaffold(
                      body: Column(
                        children: [
                          const Text('Owner page'),
                          TextButton(
                            key: const ValueKey('open-plan'),
                            onPressed: () async {
                              result = await showDialog<MarathonPlanChoice>(
                                context: ownerContext,
                                builder: (_) => const MarathonPlanDialog(),
                              );
                              resultCalls++;
                            },
                            child: const Text('Open'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                child: const Text('Open owner'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(_key('open-owner'));
      await tester.pumpAndSettle();
      await _open(tester);
      final staleCallback = action == 'marathon-start'
          ? tester.widget<FilledButton>(_key(action)).onPressed!
          : tester.widget<IconButton>(_key(action)).onPressed!;
      // Deliberately no frame between invocations. A queued callback from the
      // exiting modal must not act on Navigator's now-current owning route.
      await tester.tap(_key(action));
      staleCallback();
      await tester.pumpAndSettle();
      expect(resultCalls, 1, reason: action);
      expect(find.text('Owner page'), findsOneWidget, reason: action);
      expect(find.byType(MarathonPlanDialog), findsNothing, reason: action);
      expect(result == null, action == 'marathon-plan-cancel', reason: action);
      expect(tester.takeException(), isNull, reason: action);
    }
  });

  testWidgets(
    'six viewport sizes TR EN dark light and large text keep popup controls usable',
    (tester) async {
      addTearDown(tester.view.reset);
      for (final size in _sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        for (final locale in const [Locale('tr'), Locale('en')]) {
          final l10n = await AppLocalizations.delegate.load(locale);
          for (final dark in [false, true]) {
            for (final scale in [1.0, 2.0]) {
              final label = '$size $locale dark=$dark scale=$scale';
              MarathonPlanChoice? result;
              await tester.pumpWidget(
                _app(
                  locale: locale,
                  dark: dark,
                  scale: scale,
                  initialCount: 4,
                  initialMinutes: 50,
                  onResult: (choice) => result = choice,
                ),
              );
              await _open(tester);
              expect(tester.takeException(), isNull, reason: label);
              expect(find.text(l10n.marathonChooseCount), findsOneWidget);
              expect(find.text(l10n.marathonPlanTitle), findsNothing);
              _expectCircularChoices(
                tester,
                selected: 4,
                l10n: l10n,
                reason: label,
              );
              final start = tester.getRect(_key('marathon-start'));
              final close = tester.getRect(_key('marathon-plan-cancel'));
              expect(start.top, greaterThanOrEqualTo(0), reason: label);
              expect(
                start.bottom,
                lessThanOrEqualTo(size.height),
                reason: label,
              );
              expect(start.width, greaterThanOrEqualTo(48), reason: label);
              expect(start.height, greaterThanOrEqualTo(48), reason: label);
              expect(close.height, greaterThanOrEqualTo(48), reason: label);
              await _tapInBody(tester, _key('marathon-count-2'));
              _expectCircularChoices(
                tester,
                selected: 2,
                l10n: l10n,
                reason: label,
              );
              await _tapInBody(tester, _key('marathon-duration-25'));
              await tester.tap(_key('marathon-start'));
              await tester.pumpAndSettle();
              expect(result?.totalSessions, 2, reason: label);
              expect(result?.durationMinutes, 25, reason: label);
              expect(tester.takeException(), isNull, reason: label);
            }
          }
        }
      }
    },
  );
}
