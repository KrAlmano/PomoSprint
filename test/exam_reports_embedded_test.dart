import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/details_exam_backend.dart';
import 'support/fake_supabase_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in ['tr', 'en']) {
    testWidgets('reports contain editable exam history ($language)', (
      tester,
    ) async {
      final backend = DetailsExamBackend();
      final attempt = detailsCompletedAttempt(
        title: 'Example AYT',
        results: const [
          ExamSubjectResult(
            subjectId: 'mathematics',
            correct: 30,
            wrong: 4,
            blank: 6,
          ),
        ],
      );
      backend.rows[attempt.clientUuid] = attempt;
      final exams = ExamService(backend: backend);
      final reports = FakeSupabaseService();
      addTearDown(exams.dispose);
      addTearDown(backend.owner.dispose);
      await exams.initialize();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ReportsScreen(
              categories: const [],
              service: reports,
              examService: exams,
              loadExamAttempts: () async => exams.attempts,
              loadExamStudySessions: () async => [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(Locale(language));
      final tab = find.text(l10n.reportsTabExamsShort);
      await tester.ensureVisible(tab);
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('exam-reports-inside-reports')),
        findsOneWidget,
      );
      expect(find.byType(ReportsScreen), findsOneWidget);
      expect(
        find.byKey(ValueKey('exam-history-card-${attempt.clientUuid}')),
        findsOneWidget,
      );
      expect(find.text('Example AYT'), findsOneWidget);
      expect(
        find.text('${l10n.examNet}: ${language == 'tr' ? '29,00' : '29.00'}'),
        findsOneWidget,
      );
      final edit = find.text(l10n.examDetailsEdit);
      await tester.ensureVisible(edit);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      final note = find.byKey(const ValueKey('exam-detail-note'));
      await tester.ensureVisible(note);
      await tester.enterText(note, 'Review fractions');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, l10n.examSaveResults);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(backend.rows[attempt.clientUuid]!.note, 'Review fractions');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'exam history remains usable when study reports fail ($language)',
      (tester) async {
        final backend = DetailsExamBackend();
        final attempt = detailsCompletedAttempt(id: 'tyt', seconds: 9900);
        backend.rows[attempt.clientUuid] = attempt;
        final exams = ExamService(backend: backend);
        final reports = FakeSupabaseService()
          ..fetchError = StateError('offline');
        addTearDown(exams.dispose);
        addTearDown(backend.owner.dispose);
        await exams.initialize();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 568);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
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
              body: ReportsScreen(
                categories: const [],
                service: reports,
                examService: exams,
                loadExamAttempts: () async => exams.attempts,
                loadExamStudySessions: () async => [],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'initial error view');
        final tab = find.text(
          lookupAppLocalizations(Locale(language)).reportsTabExamsShort,
        );
        await tester.ensureVisible(tab);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('exam-history-card-${attempt.clientUuid}')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
