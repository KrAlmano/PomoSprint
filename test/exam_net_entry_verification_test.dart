import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/widgets/exam_results_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_exam_backend.dart';

// Model the documented SQL upsert: omitted subjects remain untouched.
class _PartialResultsBackend extends FakeExamBackend {
  @override
  Object? defaultRpc(String name, Map<String, dynamic> params) {
    if (name != 'save_exam_results') return super.defaultRpc(name, params);
    if (!isAvailable) throw const ExamFailure('connection');
    final old = rows.values.singleWhere((a) => a.id == params['p_attempt_id']);
    final merged = {
      for (final result in old.subjectResults) result.subjectId: result,
      for (final raw in params['p_subject_results'] as List)
        (raw as Map)['subject_id'] as String: ExamSubjectResult.fromJson(raw)!,
    };
    final next = ExamAttempt.fromJson({
      ...old.toJson(),
      'subject_results': merged.values.map((r) => r.toJson()).toList(),
    })!;
    rows[old.clientUuid] = next;
    return {'attempt': next.toJson()};
  }
}

ExamAttempt _completed(
  FakeExamBackend backend, {
  List<ExamSubjectResult> results = const [],
}) {
  final exam = offlineExamCatalog.byId('tyt')!;
  return ExamAttempt(
    id: 'net-verification-attempt',
    clientUuid: 'net-verification-uuid',
    examId: exam.id,
    startedAt: backend.clock.subtract(Duration(seconds: exam.durationSeconds)),
    endsAt: backend.clock,
    completedAt: backend.clock,
    durationSeconds: exam.durationSeconds,
    totalQuestions: exam.totalQuestions,
    status: ExamAttemptStatus.completed,
    pointsEarned: 33,
    examCoinsEarned: 6,
    subjectResults: results,
    definition: exam,
  );
}

const _turkish = ExamSubjectResult(
  subjectId: 'turkish',
  correct: 30,
  wrong: 4,
  blank: 6,
);
const _physics = ExamSubjectResult(
  subjectId: 'physics',
  correct: 3,
  wrong: 1,
  blank: 3,
);

Finder _field(String subject, int index) =>
    find.byKey(ValueKey('exam-result-$subject-$index'));

Future<AppLocalizations> _open(
  WidgetTester tester,
  ExamService service,
  ExamAttempt attempt,
  String language,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 1400);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open-net'),
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
  await tester.tap(find.byKey(const ValueKey('open-net')));
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(Locale(language));
}

Future<void> _save(WidgetTester tester, AppLocalizations l10n) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, l10n.examSaveResults));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in ['tr', 'en']) {
    testWidgets('automatic blanks save only the edited subject ($language)', (
      tester,
    ) async {
      final backend = _PartialResultsBackend();
      final attempt = _completed(backend);
      backend.rows[attempt.clientUuid] = attempt;
      final service = ExamService(backend: backend);
      addTearDown(service.dispose);
      addTearDown(backend.owner.dispose);
      addTearDown(tester.view.reset);
      await service.initialize();
      final l10n = await _open(tester, service, attempt, language);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, l10n.examSaveResults),
            )
            .onPressed,
        isNull,
        reason: 'Opening a missing result must not manufacture zero scores',
      );
      await tester.enterText(_field('turkish', 0), '30');
      await tester.enterText(_field('turkish', 1), '3');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(_field('turkish', 2)).controller!.text,
        '7',
      );
      expect(
        find.text('${l10n.examNet}: ${language == 'tr' ? '29,25' : '29.25'}'),
        findsOneWidget,
      );
      await _save(tester, l10n);
      expect(find.byType(AlertDialog), findsNothing);
      final payload = backend.calls
          .lastWhere((c) => c.$1 == 'save_exam_results')
          .$2;
      expect(
        payload.keys,
        unorderedEquals(['p_attempt_id', 'p_subject_results']),
      );
      expect(payload['p_subject_results'], [
        const ExamSubjectResult(
          subjectId: 'turkish',
          correct: 30,
          wrong: 3,
          blank: 7,
        ).toJson(),
      ]);
      expect(service.attempts.single.subjectResults.map((r) => r.subjectId), [
        'turkish',
      ]);
      expect(service.attempts.single.pointsEarned, 33);
      expect(service.attempts.single.examCoinsEarned, 6);
      expect(backend.completions, 0);
      expect(backend.profileRefreshes, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'manual blanks and invalid negative/overflow remain explicit ($language)',
      (tester) async {
        final backend = _PartialResultsBackend();
        final attempt = _completed(backend);
        backend.rows[attempt.clientUuid] = attempt;
        final service = ExamService(backend: backend);
        addTearDown(service.dispose);
        addTearDown(backend.owner.dispose);
        addTearDown(tester.view.reset);
        await service.initialize();
        final l10n = await _open(tester, service, attempt, language);
        await tester.enterText(_field('turkish', 0), '30');
        await tester.enterText(_field('turkish', 1), '4');
        await tester.enterText(_field('turkish', 2), '5');
        await _save(tester, l10n);
        expect(find.text(l10n.examResultsInvalid), findsOneWidget);
        await tester.enterText(_field('turkish', 0), '-1');
        expect(
          tester.widget<TextField>(_field('turkish', 0)).controller!.text,
          '-1',
          reason: 'A pasted negative must not silently become a valid positive',
        );
        await _save(tester, l10n);
        expect(find.text(l10n.examResultsInvalid), findsOneWidget);
        await tester.enterText(_field('turkish', 0), '41');
        await _save(tester, l10n);
        expect(find.text(l10n.examResultsInvalid), findsOneWidget);
        expect(
          backend.calls.where((c) => c.$1 == 'save_exam_results'),
          isEmpty,
        );
        await tester.enterText(_field('turkish', 0), '30');
        await tester.enterText(_field('turkish', 2), '6');
        await _save(tester, l10n);
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          service.attempts.single.subjectResults.single.toJson(),
          _turkish.toJson(),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'queued partial values and existing server values reopen together',
    (tester) async {
      final backend = _PartialResultsBackend();
      final attempt = _completed(backend, results: [_physics]);
      backend.rows[attempt.clientUuid] = attempt;
      final service = ExamService(backend: backend);
      addTearDown(service.dispose);
      addTearDown(backend.owner.dispose);
      addTearDown(tester.view.reset);
      await service.initialize();
      backend.isAvailable = false;
      await service.saveResults(attempt, [_turkish]);
      final l10n = await _open(tester, service, attempt, 'tr');
      expect(
        tester.widget<TextField>(_field('turkish', 0)).controller!.text,
        '30',
      );
      expect(
        tester.widget<TextField>(_field('physics', 0)).controller!.text,
        '3',
      );
      await tester.enterText(_field('mathematics', 0), '20');
      await _save(tester, l10n);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text(l10n.examQueuedResults), findsOneWidget);
      expect(
        (await service.persistence.read(
          'owner-1',
        )).single.pendingResults!.map((r) => r.subjectId).toSet(),
        {'turkish', 'mathematics'},
      );
      expect(backend.calls.where((c) => c.$1 == 'save_exam_results'), isEmpty);
      expect(tester.takeException(), isNull);
      service.setForeground(false);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
