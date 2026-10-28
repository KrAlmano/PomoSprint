import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/widgets/exam_results_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_exam_backend.dart';

class _FailingSavePersistence extends ExamPersistence {
  bool failWrites = false;

  @override
  Future<bool> write(
    String uid,
    List<ExamLocalRecord> rows, {
    bool Function()? canCommit,
  }) async {
    if (failWrites) throw StateError('local disk unavailable');
    return super.write(uid, rows, canCommit: canCommit);
  }
}

ExamAttempt _completed(FakeExamBackend backend) {
  final exam = offlineExamCatalog.exams.first;
  final end = backend.clock;
  return ExamAttempt(
    id: 'localized-result',
    clientUuid: 'localized-result-uuid',
    examId: exam.id,
    startedAt: end.subtract(Duration(seconds: exam.durationSeconds)),
    endsAt: end,
    completedAt: end,
    durationSeconds: exam.durationSeconds,
    totalQuestions: exam.totalQuestions,
    status: ExamAttemptStatus.completed,
    definition: exam,
  );
}

Widget _app(
  ValueNotifier<Locale> locale,
  ExamService service,
  ExamAttempt attempt,
) => ValueListenableBuilder<Locale>(
  valueListenable: locale,
  builder: (context, value, _) => MaterialApp(
    locale: value,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          key: const ValueKey('open-results'),
          onPressed: () => showExamResultsDialog(
            context,
            service: service,
            attempt: attempt,
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'server exam and subject labels cannot be whitespace-only in either locale',
    () {
      final definition = offlineExamCatalog.exams.first;
      for (final key in ['name_tr', 'name_en']) {
        expect(
          ExamDefinition.fromJson({...definition.toJson(), key: ' \t\n '}),
          isNull,
          reason: 'An invisible $key must not enable a catalog entry',
        );
        expect(
          ExamSubject.fromJson({
            ...definition.subjects.first.toJson(),
            key: ' \t ',
          }),
          isNull,
          reason: 'Both visible subject translations are required',
        );
      }
    },
  );

  testWidgets(
    'exam net decimal separator follows the active TR and EN locale',
    (tester) async {
      final backend = FakeExamBackend();
      final attempt = _completed(backend);
      backend.rows[attempt.clientUuid] = attempt;
      final service = ExamService(backend: backend);
      final locale = ValueNotifier(const Locale('tr'));
      addTearDown(service.dispose);
      addTearDown(backend.owner.dispose);
      addTearDown(locale.dispose);
      await service.initialize();
      await tester.pumpWidget(_app(locale, service, attempt));
      await tester.tap(find.byKey(const ValueKey('open-results')));
      await tester.pumpAndSettle();
      final tr = await AppLocalizations.delegate.load(const Locale('tr'));
      final trHasComma = find.text('${tr.examNet}: 0,00').evaluate().isNotEmpty;

      locale.value = const Locale('en');
      await tester.pumpAndSettle();
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final enHasDot = find.text('${en.examNet}: 0.00').evaluate().isNotEmpty;
      await tester.pumpWidget(const SizedBox.shrink());

      expect(
        trHasComma,
        isTrue,
        reason: 'Turkish decimal formatting uses a comma',
      );
      expect(enHasDot, isTrue, reason: 'English decimal formatting uses a dot');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a visible results-save error changes language with its dialog', (
    tester,
  ) async {
    final backend = FakeExamBackend();
    final attempt = _completed(backend);
    backend.rows[attempt.clientUuid] = attempt;
    final persistence = _FailingSavePersistence();
    final service = ExamService(backend: backend, persistence: persistence);
    final locale = ValueNotifier(const Locale('tr'));
    addTearDown(service.dispose);
    addTearDown(backend.owner.dispose);
    addTearDown(locale.dispose);
    await service.initialize();
    persistence.failWrites = true;
    await tester.pumpWidget(_app(locale, service, attempt));
    await tester.tap(find.byKey(const ValueKey('open-results')));
    await tester.pumpAndSettle();
    final tr = await AppLocalizations.delegate.load(const Locale('tr'));
    // Saving now sends only intentionally edited subjects; create a valid
    // edit before exercising the persistence-error language transition.
    await tester.enterText(
      find.byKey(const ValueKey('exam-result-turkish-0')),
      '1',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, tr.examSaveResults));
    await tester.pumpAndSettle();
    expect(find.text(tr.examResultsSaveError), findsOneWidget);

    locale.value = const Locale('en');
    await tester.pumpAndSettle();
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final englishError = find.text(en.examResultsSaveError).evaluate().length;
    final staleTurkishError = find
        .text(tr.examResultsSaveError)
        .evaluate()
        .length;
    await tester.pumpWidget(const SizedBox.shrink());

    expect(englishError, 1);
    expect(staleTurkishError, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing three result fields keeps their net through rotation', (
    tester,
  ) async {
    final backend = FakeExamBackend();
    final attempt = _completed(backend);
    backend.rows[attempt.clientUuid] = attempt;
    final service = ExamService(backend: backend);
    final locale = ValueNotifier(const Locale('en'));
    addTearDown(service.dispose);
    addTearDown(backend.owner.dispose);
    addTearDown(locale.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await service.initialize();
    await tester.pumpWidget(_app(locale, service, attempt));
    await tester.tap(find.byKey(const ValueKey('open-results')));
    await tester.pumpAndSettle();
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    final correct = find.byKey(const ValueKey('exam-result-turkish-0'));
    final wrong = find.byKey(const ValueKey('exam-result-turkish-1'));
    final blank = find.byKey(const ValueKey('exam-result-turkish-2'));
    await tester.enterText(correct, '41');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, en.examSaveResults));
    await tester.pumpAndSettle();
    expect(find.text(en.examResultsInvalid), findsOneWidget);
    await tester.enterText(correct, '30');
    await tester.enterText(wrong, '4');
    await tester.enterText(blank, '6');
    FocusManager.instance.primaryFocus?.unfocus();
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(correct).controller!.text, '30');
    expect(tester.widget<TextField>(wrong).controller!.text, '4');
    expect(tester.widget<TextField>(blank).controller!.text, '6');
    expect(find.text('${en.examNet}: 29.00'), findsOneWidget);
    expect(service.attempts.single.subjectResults, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, en.examSaveResults));
    await tester.pumpAndSettle();
    expect(service.records.single.errorCode, isNull);
    expect(service.records.single.pendingAction, isNull);
    expect(find.byType(AlertDialog), findsNothing);
    final saved = service.attempts.single.subjectResults.firstWhere(
      (r) => r.subjectId == 'turkish',
    );
    expect(saved.net(4), 29);
    expect(tester.takeException(), isNull);
  });
}
