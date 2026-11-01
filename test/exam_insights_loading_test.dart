import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/models/study_session.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_exam_backend.dart';

void _seedResults(FakeExamBackend backend) {
  final exam = offlineExamCatalog.byId('tyt')!;
  for (final (id, days, correct) in [('first', 10, 3), ('last', 1, 6)]) {
    final start = backend.clock.subtract(Duration(days: days));
    backend.rows[id] = ExamAttempt(
      id: id,
      clientUuid: id,
      examId: exam.id,
      startedAt: start,
      endsAt: start.add(Duration(seconds: exam.durationSeconds)),
      durationSeconds: exam.durationSeconds,
      totalQuestions: exam.totalQuestions,
      status: ExamAttemptStatus.completed,
      definition: exam,
      subjectResults: [
        const ExamSubjectResult(
          subjectId: 'chemistry',
          correct: 0,
          wrong: 0,
          blank: 7,
        ),
        const ExamSubjectResult(
          subjectId: 'history',
          correct: 1,
          wrong: 4,
          blank: 0,
        ),
        ExamSubjectResult(
          subjectId: 'physics',
          correct: correct,
          wrong: 0,
          blank: 7 - correct,
        ),
      ],
    );
  }
}

StudySession _study(FakeExamBackend backend, int minutes) {
  final start = backend.clock.subtract(const Duration(days: 5));
  return StudySession(
    id: 'physics-study',
    clientUuid: 'physics-study',
    userId: backend.ownerId!,
    categoryName: 'Fizik',
    minutes: minutes,
    pomodoros: minutes ~/ 25,
    startedAt: start,
    completedAt: start.add(Duration(minutes: minutes)),
  );
}

Widget _app(
  ExamService service,
  Future<List<StudySession>> Function() load, {
  String language = 'tr',
}) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: ExamScreen(service: service, loadStudySessions: load),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'failed first study history read never presents zero minutes as a verified insight',
    (tester) async {
      final backend = FakeExamBackend();
      _seedResults(backend);
      final service = ExamService(backend: backend);
      addTearDown(service.dispose);
      addTearDown(backend.owner.dispose);
      await service.initialize();
      final tr = await AppLocalizations.delegate.load(const Locale('tr'));
      await tester.pumpWidget(
        _app(
          service,
          () async => throw TimeoutException('study history offline'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('exam-tab-history')));
      await tester.pumpAndSettle();

      expect(
        find.text(tr.examInsightsChange('Fizik', 0, '3,00', '6,00')),
        findsNothing,
        reason: 'An unread history is not evidence of zero study minutes',
      );
      expect(find.text(tr.statsLoadErrorGeneric), findsOneWidget);
      expect(find.text(tr.examInsightsEmpty), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'late older study-history response cannot replace a newer insight total',
    (tester) async {
      final backend = FakeExamBackend();
      _seedResults(backend);
      final service = ExamService(backend: backend);
      addTearDown(service.dispose);
      addTearDown(backend.owner.dispose);
      await service.initialize();
      final firstRead = Completer<List<StudySession>>();
      var reads = 0;
      final tr = await AppLocalizations.delegate.load(const Locale('tr'));
      await tester.pumpWidget(
        _app(service, () {
          reads++;
          return reads == 1
              ? firstRead.future
              : Future.value([_study(backend, 100)]);
        }),
      );
      await tester.pumpAndSettle();
      expect(reads, 1);
      await tester.tap(find.byKey(const ValueKey('exam-tab-history')));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(
        find.text(tr.examInsightsChange('Fizik', 100, '3,00', '6,00')),
        findsOneWidget,
      );
      expect(
        find.text(tr.examInsightsChange('Kimya', 0, '0,00', '0,00')),
        findsNothing,
        reason: 'An unchanged zero without study adds no useful insight',
      );
      expect(
        find.text(tr.examInsightsChange('Tarih', 0, '0,00', '0,00')),
        findsOneWidget,
        reason: 'A zero net with answered questions is still meaningful',
      );

      firstRead.complete([_study(backend, 50)]);
      await tester.pumpAndSettle();
      expect(
        find.text(tr.examInsightsChange('Fizik', 100, '3,00', '6,00')),
        findsOneWidget,
        reason: 'A delayed earlier read must not overwrite the latest history',
      );
      expect(
        find.text(tr.examInsightsChange('Fizik', 50, '3,00', '6,00')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed refresh keeps cached insight with a translated warning and retry replaces it',
    (tester) async {
      final backend = FakeExamBackend();
      _seedResults(backend);
      final service = ExamService(backend: backend);
      addTearDown(service.dispose);
      addTearDown(backend.owner.dispose);
      await service.initialize();
      final tr = await AppLocalizations.delegate.load(const Locale('tr'));
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      var unavailable = false;
      var minutes = 50;
      Future<List<StudySession>> load() async {
        if (unavailable) throw TimeoutException('study refresh offline');
        return [_study(backend, minutes)];
      }

      await tester.pumpWidget(_app(service, load));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('exam-tab-history')));
      await tester.pumpAndSettle();
      expect(
        find.text(tr.examInsightsChange('Fizik', 50, '3,00', '6,00')),
        findsOneWidget,
      );

      unavailable = true;
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refresh.onRefresh();
      await tester.pumpAndSettle();
      expect(find.text(tr.statsStaleNotice), findsOneWidget);
      expect(
        find.text(tr.examInsightsChange('Fizik', 50, '3,00', '6,00')),
        findsOneWidget,
      );

      await tester.pumpWidget(_app(service, load, language: 'en'));
      await tester.pumpAndSettle();
      expect(find.text(tr.statsStaleNotice), findsNothing);
      expect(find.text(en.statsStaleNotice), findsOneWidget);
      expect(
        find.text(en.examInsightsChange('Physics', 50, '3.00', '6.00')),
        findsOneWidget,
      );

      unavailable = false;
      minutes = 75;
      final retry = find.widgetWithText(TextButton, en.examRetry);
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text(en.statsStaleNotice), findsNothing);
      expect(
        find.text(en.examInsightsChange('Physics', 75, '3.00', '6.00')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
