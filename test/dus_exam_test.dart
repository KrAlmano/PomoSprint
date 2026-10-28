import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/dus_catalog.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_details.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/screens/social_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/details_exam_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'DUS official40basic80clinical questions and16 independent categories',
    () {
      final d = offlineExamCatalog.byId('dus')!;
      expect(d.durationSeconds, 9000);
      expect(d.totalQuestions, 120);
      expect(d.wrongAnswerDivisor, 4);
      expect(d.segment, 'dus');
      expect(d.subjects.map((s) => s.questionCount), [
        6,
        4,
        6,
        6,
        6,
        4,
        4,
        4,
        10,
        10,
        10,
        10,
        10,
        10,
        10,
        10,
      ]);
      expect(
        d.subjects.take(8).fold<int>(0, (n, s) => n + s.questionCount),
        40,
      );
      expect(
        d.subjects.skip(8).fold<int>(0, (n, s) => n + s.questionCount),
        80,
      );
      expect(dusCategoryNames, hasLength(16));
      expect(dusCategoryNames.toSet(), hasLength(16));
      expect(d.fullRewardPoints, 30);
      expect(d.fullRewardCoins, 120);
    },
  );
  test(
    'DUS remains ineligible for early completion despite AYT capability',
    () async {
      final b = DetailsExamBackend();
      final service = ExamService(backend: b, createUuid: () => 'dus-active');
      addTearDown(service.dispose);
      addTearDown(b.owner.dispose);
      await service.initialize();
      await service.start(service.catalog.byId('dus')!);
      expect(service.blocksOtherSessions.value, isTrue);
      expect(service.canFinishEarly(service.activeRecord!), isFalse);
      await expectLater(
        service.finishEarly('dus-active'),
        throwsA(isA<ExamFailure>()),
      );
      expect(b.calls.where((c) => c.$1 == 'finish_ayt_early'), isEmpty);
      b.clock = b.clock.add(const Duration(seconds: 5));
      await service.abandon('dus-active');
      expect(service.attempts.single.status, ExamAttemptStatus.abandoned);
      expect(service.attempts.single.reportMinutes, 0);
      expect(service.attempts.single.examCoinsEarned, 0);
    },
  );
  test(
    'all16 DUS results and metadata survive a single request without changing150min reward',
    () async {
      final b = DetailsExamBackend();
      final service = ExamService(backend: b);
      addTearDown(service.dispose);
      addTearDown(b.owner.dispose);
      final a = detailsCompletedAttempt(id: 'dus', seconds: 9000);
      b.rows[a.clientUuid] = a;
      await service.initialize();
      final results = [
        for (final s in a.definition!.subjects)
          ExamSubjectResult(
            subjectId: s.id,
            correct: s.questionCount - 1,
            wrong: 1,
            blank: 0,
          ),
      ];
      await service.saveDetails(
        a,
        patch: ExamDetailsPatch({'title': 'DUS 1', 'note': 'Review'}),
        results: results,
        expectedRevision: 0,
      );
      final saved = service.attempts.single;
      expect(saved.subjectResults, hasLength(16));
      expect(saved.subjectResults.first.net(4), 4.75);
      expect(saved.reportMinutes, 150);
      expect(StatSession.fromExamAttempt(saved)!.minutes, 150);
      expect(saved.pointsEarned, 30);
      expect(saved.examCoinsEarned, 120);
      expect(b.calls.where((c) => c.$1 == 'save_exam_details'), hasLength(1));
      expect(b.profileRefreshes, 0);
    },
  );
  for (final code in ['tr', 'en']) {
    testWidgets('four exam filters and DUS social label stay localized $code', (
      tester,
    ) async {
      final b = DetailsExamBackend();
      final service = ExamService(backend: b);
      addTearDown(service.dispose);
      addTearDown(b.owner.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 932);
      addTearDown(tester.view.reset);
      await service.initialize();
      final l10n = await AppLocalizations.delegate.load(Locale(code));
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(code),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ExamScreen(service: service)),
        ),
      );
      await tester.pumpAndSettle();
      final expected = [l10n.examFilterAll, 'YKS', 'LGS', 'TUS', 'DUS'];
      final filters = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .map((c) => (c.label as Text).data)
          .where((s) => expected.contains(s))
          .toList();
      expect(filters, expected);
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'DUS'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'DUS'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('exam-start-dus')), findsOneWidget);
      expect(find.byKey(const ValueKey('exam-start-tyt')), findsNothing);
      expect(
        SocialScreen.liveStatusText({
          'status': 'exam',
          'exam_id': 'dus',
          'user_segment': 'dus',
        }, l10n),
        l10n.socialTakingExam,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
