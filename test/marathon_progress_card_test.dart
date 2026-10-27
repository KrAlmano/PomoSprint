import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/widgets/marathon_progress_card.dart';

const _sizes = [
  Size(320, 568),
  Size(390, 844),
  Size(568, 320),
  Size(844, 390),
  Size(820, 1180),
  Size(1180, 820),
];

Widget _app({
  int total = 4,
  int completed = 0,
  int minutes = 25,
  MarathonCardStage stage = MarathonCardStage.focus,
  String status = '',
  String identity = 'plan-a',
  Locale locale = const Locale('tr'),
  bool dark = false,
  bool reducedMotion = false,
  double scale = 1,
  VoidCallback? onInfo,
}) => MaterialApp(
  locale: locale,
  theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      disableAnimations: reducedMotion,
    ),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: MarathonProgressCard(
          totalSessions: total,
          completedSessions: completed,
          durationMinutes: minutes,
          stage: stage,
          statusText: status,
          progressIdentity: identity,
          onInfo: onInfo ?? () {},
        ),
      ),
    ),
  ),
);

Finder _key(String value) => find.byKey(ValueKey(value));

double _nodeScale(WidgetTester tester, int index) => tester
    .widget<Transform>(_key('marathon-card-pop-$index'))
    .transform
    .getMaxScaleOnAxis();

void main() {
  testWidgets(
    '2/3/4 plans show the localized route and exact cumulative focus minutes',
    (tester) async {
      for (final locale in const [Locale('tr'), Locale('en')]) {
        final l10n = await AppLocalizations.delegate.load(locale);
        for (final total in [2, 3, 4]) {
          for (final minutes in [25, 50]) {
            await tester.pumpWidget(
              _app(total: total, minutes: minutes, locale: locale),
            );
            await tester.pump();
            expect(find.text(l10n.marathonTitle.toUpperCase()), findsOneWidget);
            expect(find.text(l10n.marathonSessionCount(total)), findsOneWidget);
            expect(find.text(l10n.marathonStepStart), findsOneWidget);
            expect(find.text(l10n.marathonStepGoal), findsOneWidget);
            for (var index = 1; index < total - 1; index++) {
              expect(
                find.text('${(index + 1) * minutes} ${l10n.minAbbr}'),
                findsOneWidget,
              );
            }
            expect(_key('marathon-card-step-$total'), findsOneWidget);
            expect(_key('marathon-card-step-${total + 1}'), findsNothing);
            expect(tester.takeException(), isNull);
          }
        }
      }
    },
  );

  testWidgets(
    'every completion animates once, fills its connector and settles without an idle ticker',
    (tester) async {
      for (final total in [2, 3, 4]) {
        await tester.pumpWidget(_app(total: total, identity: 'plan-$total'));
        await tester.pump();
        expect(tester.binding.transientCallbackCount, 0);
        for (var completed = 1; completed <= total; completed++) {
          final before = tester
              .widget<CustomPaint>(_key('marathon-card-connectors'))
              .painter!;
          await tester.pumpWidget(
            _app(
              total: total,
              completed: completed,
              identity: 'plan-$total',
              stage: completed == total
                  ? MarathonCardStage.finished
                  : MarathonCardStage.breakTime,
            ),
          );
          await tester.pump(const Duration(milliseconds: 250));
          expect(_key('marathon-card-check-$completed'), findsOneWidget);
          expect(_nodeScale(tester, completed), greaterThan(1));
          final during = tester
              .widget<CustomPaint>(_key('marathon-card-connectors'))
              .painter!;
          expect(during.shouldRepaint(before), isTrue);
          await tester.pump(const Duration(milliseconds: 450));
          expect(_nodeScale(tester, completed), closeTo(1, 0.00001));
          expect(tester.binding.transientCallbackCount, 0);
          if (completed < total) {
            // A stage/countdown update must not replay the session animation.
            await tester.pumpWidget(
              _app(
                total: total,
                completed: completed,
                identity: 'plan-$total',
                stage: MarathonCardStage.checkIn,
                status: 'Buradayım · 00:59',
              ),
            );
            await tester.pump(const Duration(milliseconds: 200));
            expect(_nodeScale(tester, completed), 1);
            expect(tester.binding.transientCallbackCount, 0);
          }
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'restored/different plans and reduced motion never replay or leak completion animations',
    (tester) async {
      await tester.pumpWidget(_app(completed: 2));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_nodeScale(tester, 2), 1);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(_app(completed: 3, identity: 'another-plan'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_nodeScale(tester, 3), 1);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(
        _app(completed: 4, identity: 'another-plan', reducedMotion: true),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_nodeScale(tester, 4), 1);
      expect(tester.binding.transientCallbackCount, 0);

      await tester.pumpWidget(_app(identity: 'third-plan'));
      await tester.pumpWidget(_app(completed: 1, identity: 'third-plan'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_nodeScale(tester, 1), greaterThan(1));
      await tester.pumpWidget(
        _app(completed: 1, identity: 'third-plan', reducedMotion: true),
      );
      await tester.pump();
      expect(_nodeScale(tester, 1), 1);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'phase statuses preserve completed sessions, accessible state and info hit target',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
        var infoCalls = 0;
        for (final stage in MarathonCardStage.values) {
          final completed = stage == MarathonCardStage.finished ? 4 : 1;
          await tester.pumpWidget(
            _app(
              completed: completed,
              stage: stage,
              status: 'Durum: ${stage.name}',
              identity: 'phase-${stage.name}',
              onInfo: () => infoCalls++,
            ),
          );
          await tester.pump();
          expect(find.text('Durum: ${stage.name}'), findsOneWidget);
          expect(_key('marathon-card-check-1'), findsOneWidget);
          final first = tester.getSemantics(_key('marathon-card-step-1'));
          expect(first.label, contains(l10n.marathonStepCompleted));
          final selected = tester
              .widget<Semantics>(_key('marathon-card-step-2'))
              .properties
              .selected;
          expect(
            selected,
            ![
              MarathonCardStage.finished,
              MarathonCardStage.timedOut,
              MarathonCardStage.unavailable,
            ].contains(stage),
          );
          final rect = tester.getRect(_key('marathon-card-info'));
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          await tester.tap(_key('marathon-card-info'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(infoCalls, MarathonCardStage.values.length);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'six phone/tablet sizes, TR/EN, large text and dark/light have no overflow',
    (tester) async {
      addTearDown(tester.view.reset);
      for (final size in _sizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        for (final locale in const [Locale('tr'), Locale('en')]) {
          final l10n = await AppLocalizations.delegate.load(locale);
          for (final scale in [1.0, 2.0]) {
            for (final dark in [false, true]) {
              for (final stage in [
                MarathonCardStage.unavailable,
                MarathonCardStage.checkIn,
              ]) {
                final label = '$size $locale x$scale dark=$dark $stage';
                final status = stage == MarathonCardStage.unavailable
                    ? l10n.marathonUnavailable
                    : '${l10n.marathonBreakTitle} · 00:59 · ${l10n.marathonAutomaticHint}';
                await tester.pumpWidget(
                  _app(
                    locale: locale,
                    scale: scale,
                    dark: dark,
                    stage: stage,
                    status: status,
                  ),
                );
                await tester.pump();
                expect(tester.takeException(), isNull, reason: label);
                final cardRect = tester.getRect(
                  find.byType(MarathonProgressCard),
                );
                expect(cardRect.left, greaterThanOrEqualTo(0), reason: label);
                expect(
                  cardRect.right,
                  lessThanOrEqualTo(size.width),
                  reason: label,
                );
                final estimate = MarathonProgressCard.estimatedHeight(
                  tester.element(find.byType(MarathonProgressCard)),
                  width: cardRect.width,
                  hasFooter: false,
                  statusText: status,
                );
                expect(
                  estimate,
                  greaterThanOrEqualTo(cardRect.height),
                  reason: '$label height reservation',
                );
                expect(
                  estimate - cardRect.height,
                  lessThan(9),
                  reason: '$label unnecessary height reservation',
                );
                await tester.ensureVisible(_key('marathon-card-info'));
                await tester.pump();
                expect(tester.takeException(), isNull, reason: label);
                expect(
                  tester.getRect(_key('marathon-card-info')).width,
                  greaterThanOrEqualTo(48),
                  reason: label,
                );
              }
            }
          }
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
    },
  );
}
