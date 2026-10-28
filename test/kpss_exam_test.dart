import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/models/kpss_catalog.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/services/onboarding_categories.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/utils/category_names.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/details_exam_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'KPSS uses three shared130 minute sessions and nine separate field tests',
    () {
      expect(kpssExamDefinitions, hasLength(12));
      for (final id in ['bachelor', 'associate', 'secondary']) {
        final definition = offlineExamCatalog.byId('kpss_${id}_gygk')!;
        expect(definition.durationSeconds, 7800);
        expect(definition.totalQuestions, 120);
        expect(definition.subjects.map((s) => s.id), [
          'general_ability',
          'general_knowledge',
        ]);
        expect(definition.subjects.map((s) => s.questionCount), [60, 60]);
        expect(definition.fullRewardPoints, 26);
        expect(definition.fullRewardCoins, 105);
      }
      for (final definition in kpssExamDefinitions.where(
        (e) => e.id.startsWith('kpss_field_'),
      )) {
        final statistics = definition.id == 'kpss_field_statistics';
        expect(definition.durationSeconds, statistics ? 3600 : 3000);
        expect(definition.totalQuestions, 40);
        expect(definition.subjects, hasLength(1));
        expect(definition.subjects.single.questionCount, 40);
        expect(definition.fullRewardPoints, statistics ? 12 : 10);
        expect(definition.fullRewardCoins, statistics ? 50 : 40);
      }
      for (final definition in kpssExamDefinitions) {
        expect(definition.segment, 'kpss');
        expect(definition.isValid, isTrue, reason: definition.id);
        expect(definition.wrongAnswerDivisor, 4);
        expect(definition.effectiveRewardPolicyVersion, 2);
        expect(definition.effectiveModules, isEmpty);
        expect(
          ExamDefinition.fromJson(definition.toJson())?.toJson(),
          definition.toJson(),
        );
      }
    },
  );

  test(
    'KPSS net entry has official two-test totals rather than invented topic quotas',
    () {
      final definition = offlineExamCatalog.byId('kpss_bachelor_gygk')!;
      final ability = definition.subjects.first;
      const result = ExamSubjectResult(
        subjectId: 'general_ability',
        correct: 45,
        wrong: 8,
        blank: 7,
      );
      expect(result.isValidFor(ability), isTrue);
      expect(result.net(definition.wrongAnswerDivisor), 43);
      expect(
        const ExamSubjectResult(
          subjectId: 'general_ability',
          correct: 60,
          wrong: 1,
          blank: 0,
        ).isValidFor(ability),
        isFalse,
      );
      expect(definition.subjects.map((s) => s.nameTr), [
        'Genel Yetenek',
        'Genel Kültür',
      ]);
    },
  );

  test(
    'KPSS subject categories resolve in both languages without changing old selections',
    () {
      for (final definition in kpssExamDefinitions) {
        for (final subject in definition.subjects) {
          for (final key in subject.categoryKeys) {
            final english = localizedKnownCategoryName(key, turkish: false);
            expect(english, isNot(key), reason: key);
            expect(categoryMatchKey(english), categoryMatchKey(key));
          }
        }
      }
      expect(recommendedCategoryNames('kpss'), [
        'Türkçe',
        'Matematik',
        'Tarih',
        'Coğrafya',
        'Vatandaşlık',
        'Güncel Bilgiler',
      ]);
      expect(
        recommendedCategoryNames('kpss'),
        isNot(contains('Eğitim Bilimleri')),
      );
      expect(
        isRecommendedCategoryName('Eğitim Bilimleri'),
        isTrue,
        reason: 'Legacy stored draft selections must survive',
      );
      expect(isRecommendedCategoryName('Educational Sciences'), isTrue);
      expect(
        kpssExamDefinitions.any(
          (e) => e.id.contains('oabt') || e.id.contains('ags'),
        ),
        isFalse,
      );
    },
  );

  test(
    'every KPSS type refuses early completion and abandoned attempts earn nothing',
    () async {
      for (final definition in kpssExamDefinitions) {
        final backend = DetailsExamBackend();
        final service = ExamService(
          backend: backend,
          createUuid: () => 'kpss-${definition.id}',
        );
        await service.initialize();
        await service.start(definition);
        expect(service.canFinishEarly(service.activeRecord!), isFalse);
        await expectLater(
          service.finishEarly(service.activeRecord!.clientUuid),
          throwsA(isA<ExamFailure>()),
        );
        expect(backend.calls.where((c) => c.$1 == 'finish_ayt_early'), isEmpty);
        backend.clock = backend.clock.add(const Duration(seconds: 5));
        await service.abandon(service.activeRecord!.clientUuid);
        expect(service.attempts.single.status, ExamAttemptStatus.abandoned);
        expect(service.attempts.single.reportMinutes, 0);
        expect(service.attempts.single.pointsEarned, 0);
        expect(service.attempts.single.examCoinsEarned, 0);
        service.dispose();
        backend.owner.dispose();
        SharedPreferences.setMockInitialValues({});
      }
    },
  );

  for (final language in ['tr', 'en']) {
    for (final layout in [
      (size: const Size(320, 740), scale: 1.0),
      (size: const Size(320, 740), scale: 2.0),
      (size: const Size(740, 320), scale: 2.0),
    ]) {
      testWidgets(
        'KPSS explicit type choice, field cards and bounds $language ${layout.size} ${layout.scale}',
        (tester) async {
          final backend = DetailsExamBackend();
          final service = ExamService(backend: backend);
          addTearDown(service.dispose);
          addTearDown(backend.owner.dispose);
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = layout.size;
          addTearDown(tester.view.reset);
          await service.initialize();
          final l10n = await AppLocalizations.delegate.load(Locale(language));
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(layout.scale)),
                child: child!,
              ),
              home: Scaffold(body: ExamScreen(service: service)),
            ),
          );
          await tester.pumpAndSettle();
          final filter = find.byKey(const ValueKey('exam-filter-kpss'));
          await tester.ensureVisible(filter);
          await tester.tap(filter);
          await tester.pumpAndSettle();
          expect(find.text(l10n.examKpssChooseTrack), findsOneWidget);
          expect(
            find.byKey(const ValueKey('exam-card-kpss_bachelor_gygk')),
            findsNothing,
          );
          expect(find.byKey(const ValueKey('exam-card-tyt')), findsNothing);
          for (final track in KpssExamTrack.values) {
            final choice = find.byKey(
              ValueKey('exam-kpss-track-${track.name}'),
            );
            await tester.ensureVisible(choice);
            expect(tester.getSize(choice).height, greaterThanOrEqualTo(44));
            final rect = tester.getRect(choice);
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(layout.size.width));
            await tester.tap(choice);
            await tester.pumpAndSettle();
            final cards = tester
                .widgetList<Card>(find.byType(Card))
                .where(
                  (card) =>
                      card.key?.toString().contains('exam-card-kpss_') ?? false,
                );
            expect(cards, hasLength(track == KpssExamTrack.field ? 9 : 1));
            if (track == KpssExamTrack.field) {
              expect(
                find.byKey(const ValueKey('exam-card-kpss_field_statistics')),
                findsOneWidget,
              );
            } else {
              expect(
                find.byKey(ValueKey('exam-card-kpss_${track.name}_gygk')),
                findsOneWidget,
              );
            }
            expect(tester.takeException(), isNull);
          }
          final start = find.byKey(
            const ValueKey('exam-start-kpss_field_statistics'),
          );
          await tester.ensureVisible(start);
          await tester.tap(start);
          await tester.pumpAndSettle();
          expect(find.text(l10n.examRulesTitle), findsOneWidget);
          expect(
            backend.calls.where((c) => c.$1 == 'start_exam_attempt'),
            isEmpty,
          );
          await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
          await tester.pumpAndSettle();
          expect(
            backend.calls.where((c) => c.$1 == 'start_exam_attempt'),
            isEmpty,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }
}
