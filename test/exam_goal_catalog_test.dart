import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/details_exam_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in ['tr', 'en']) {
    testWidgets('goal exams and other exams are separated: $language', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final backend = DetailsExamBackend();
      final service = ExamService(backend: backend);
      addTearDown(service.dispose);
      addTearDown(backend.owner.dispose);
      await service.initialize();
      Widget app(String? segment) => MaterialApp(
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ExamScreen(service: service, userSegment: segment),
        ),
      );
      await tester.pumpWidget(app('yks'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('exam-card-tyt')), findsOneWidget);
      expect(find.byKey(const ValueKey('exam-card-ayt')), findsOneWidget);
      expect(find.byKey(const ValueKey('exam-card-dus')), findsNothing);
      final goalTab = find.byKey(const ValueKey('exam-goal-tab'));
      final extraTab = find.byKey(const ValueKey('exam-extra-tab'));
      final l10n = AppLocalizations.of(tester.element(goalTab))!;
      expect(
        tester.getSemantics(goalTab),
        matchesSemantics(
          label: l10n.examMyGoal('YKS'),
          isButton: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(tester.getTopLeft(goalTab).dy, tester.getTopLeft(extraTab).dy);
      expect(tester.widget<ChoiceChip>(goalTab).selected, isTrue);
      expect(tester.widget<ChoiceChip>(extraTab).selected, isFalse);
      final colors = Theme.of(tester.element(goalTab)).colorScheme;
      expect(tester.widget<ChoiceChip>(goalTab).selectedColor, colors.primary);
      expect(
        tester.widget<ChoiceChip>(goalTab).labelStyle?.color,
        colors.onPrimary,
      );
      expect(
        find.descendant(of: goalTab, matching: find.byType(FittedBox)),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('exam-extra-tab')));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(goalTab).selected, isFalse);
      expect(tester.widget<ChoiceChip>(extraTab).selected, isTrue);
      expect(
        tester.getSemantics(extraTab),
        matchesSemantics(
          label: l10n.examExtraExams,
          isButton: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(find.byKey(const ValueKey('exam-card-tyt')), findsNothing);
      expect(find.byKey(const ValueKey('exam-card-dus')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('exam-goal-tab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('exam-card-tyt')), findsOneWidget);
      await tester.pumpWidget(app('dus'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('exam-card-dus')), findsOneWidget);
      expect(find.byKey(const ValueKey('exam-card-tyt')), findsNothing);
      await tester.pumpWidget(app('work'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('exam-card-tyt')), findsOneWidget);
      expect(find.byKey(const ValueKey('exam-card-dus')), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    for (final size in [const Size(320, 740), const Size(740, 320)]) {
      testWidgets('all targets fit at large text: $language $size', (
        tester,
      ) async {
        final backend = DetailsExamBackend();
        final service = ExamService(backend: backend);
        addTearDown(service.dispose);
        addTearDown(backend.owner.dispose);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        await service.initialize();
        Widget app(String segment) => MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: ExamScreen(service: service, userSegment: segment),
          ),
        );
        for (final (goal, id) in [
          ('yks', 'tyt'),
          ('lgs', 'lgs_verbal'),
          ('tus', 'tus_basic'),
          ('dus', 'dus'),
        ]) {
          await tester.pumpWidget(app(goal));
          await tester.pumpAndSettle();
          expect(find.byKey(ValueKey('exam-card-$id')), findsOneWidget);
          expect(find.byKey(const ValueKey('exam-goal-tab')), findsOneWidget);
          final extra = find.byKey(const ValueKey('exam-extra-tab'));
          final goalTab = find.byKey(const ValueKey('exam-goal-tab'));
          expect(
            tester.getTopLeft(extra).dy,
            greaterThan(tester.getTopLeft(goalTab).dy),
          );
          expect(tester.getSize(goalTab).height, greaterThanOrEqualTo(44));
          expect(tester.getSize(extra).height, greaterThanOrEqualTo(44));
          expect(
            find.descendant(of: goalTab, matching: find.byType(FittedBox)),
            findsNothing,
          );
          expect(
            find.descendant(of: extra, matching: find.byType(FittedBox)),
            findsNothing,
          );
          await tester.ensureVisible(extra);
          await tester.tap(extra);
          await tester.pumpAndSettle();
          expect(find.byKey(ValueKey('exam-card-$id')), findsNothing);
          expect(
            find.byKey(ValueKey('exam-card-${goal == 'yks' ? 'dus' : 'tyt'}')),
            findsOneWidget,
          );
          if (goal == 'yks') {
            final filter = find.byKey(const ValueKey('exam-filter-kpss'));
            await tester.ensureVisible(filter);
            await tester.tap(filter);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('exam-card-kpss_bachelor_gygk')),
              findsNothing,
            );
            final bachelor = find.byKey(
              const ValueKey('exam-kpss-track-bachelor'),
            );
            await tester.ensureVisible(bachelor);
            await tester.tap(bachelor);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('exam-card-kpss_bachelor_gygk')),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(app('kpss'));
        await tester.pumpAndSettle();
        final track = find.byKey(const ValueKey('exam-kpss-track-bachelor'));
        await tester.ensureVisible(track);
        await tester.tap(track);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('exam-card-kpss_bachelor_gygk')),
          findsOneWidget,
        );
        final extra = find.byKey(const ValueKey('exam-extra-tab'));
        await tester.ensureVisible(extra);
        await tester.tap(extra);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('exam-card-kpss_bachelor_gygk')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('exam-card-tyt')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('history keeps notes and end time in details: $language', (
      tester,
    ) async {
      final backend = DetailsExamBackend();
      final attempt = detailsCompletedAttempt(note: 'personal note');
      backend.rows[attempt.clientUuid] = attempt;
      final service = ExamService(backend: backend);
      addTearDown(service.dispose);
      addTearDown(backend.owner.dispose);
      await service.initialize();
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ExamScreen(service: service, userSegment: 'yks'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('exam-tab-history')));
      await tester.pumpAndSettle();
      expect(find.text('personal note'), findsNothing);
      final details = find.byKey(
        ValueKey('exam-history-details-${attempt.clientUuid}'),
      );
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(find.text('personal note'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
