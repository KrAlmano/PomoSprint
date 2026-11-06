import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_exam_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final reduceMotion in [false, true]) {
    testWidgets('catalog entrance respects reduced motion: $reduceMotion', (
      tester,
    ) async {
      final backend = FakeExamBackend();
      final service = ExamService(backend: backend);
      addTearDown(service.dispose);
      addTearDown(backend.owner.dispose);
      await service.initialize();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: Scaffold(body: ExamScreen(service: service)),
        ),
      );
      final card = find.byKey(const ValueKey('exam-card-entrance-tyt'));
      final animation = find.descendant(
        of: card,
        matching: find.byType(TweenAnimationBuilder<double>),
      );
      expect(animation, reduceMotion ? findsNothing : findsOneWidget);
      if (!reduceMotion) {
        final opacity = find.descendant(
          of: animation,
          matching: find.byType(Opacity),
        );
        expect(tester.widget<Opacity>(opacity.first).opacity, lessThan(1));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.widget<Opacity>(opacity.first).opacity, 1);
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('exam-card-tyt')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'exam progress follows real elapsed time; reduced motion: $reduceMotion',
      (tester) async {
        final backend = FakeExamBackend();
        final service = ExamService(
          backend: backend,
          createUuid: () => 'progress-test',
        );
        addTearDown(service.dispose);
        addTearDown(backend.owner.dispose);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: child!,
            ),
            home: Scaffold(body: ExamScreen(service: service)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LinearProgressIndicator), findsNothing);

        final exam = offlineExamCatalog.byId('tyt')!;
        await service.start(exam);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        double progress() => tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value!;
        expect(progress(), closeTo(0, .001));
        expect(find.text('02:45:00'), findsOneWidget);

        backend.clock = backend.clock.add(
          const Duration(minutes: 82, seconds: 30),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
        expect(progress(), closeTo(.5, .001));
        expect(find.text('01:22:30'), findsOneWidget);
        expect(backend.completions, 0);
        expect(backend.rows.values.single.pointsEarned, 0);
        expect(backend.rows.values.single.examCoinsEarned, 0);
        expect(
          backend.calls.where((call) => call.$1 == 'complete_exam_attempt'),
          isEmpty,
        );

        backend.clock = backend.clock.add(
          const Duration(minutes: 82, seconds: 29),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          progress(),
          closeTo((exam.durationSeconds - 1) / exam.durationSeconds, .001),
        );
        expect(find.text('00:00:01'), findsOneWidget);
        expect(backend.completions, 0);

        backend.clock = backend.clock.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(backend.completions, 1);
        expect(service.activeRecord, isNull);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('pending start does not invent a progress value', (tester) async {
    final backend = FakeExamBackend();
    final service = ExamService(
      backend: backend,
      createUuid: () => 'pending-progress-test',
    );
    addTearDown(backend.owner.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ExamScreen(service: service)),
      ),
    );
    await tester.pumpAndSettle();
    backend.handler = (name, params) async {
      if (name == 'start_exam_attempt') throw TimeoutException('offline');
      return backend.defaultRpc(name, params);
    };
    await service.start(offlineExamCatalog.byId('tyt')!);
    await tester.pump();
    expect(service.activeRecord?.attempt, isNull);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('exam-countdown')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });
}
