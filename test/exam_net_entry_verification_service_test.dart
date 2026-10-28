import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/utils/exam_format.dart';
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
const _math = ExamSubjectResult(
  subjectId: 'mathematics',
  correct: 20,
  wrong: 0,
  blank: 20,
);
const _physics = ExamSubjectResult(
  subjectId: 'physics',
  correct: 3,
  wrong: 1,
  blank: 3,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'partial offline edits survive restart and merge without erasing untouched server subjects',
    () async {
      final backend = _PartialResultsBackend();
      final attempt = _completed(backend, results: [_physics]);
      backend.rows[attempt.clientUuid] = attempt;
      var service = ExamService(backend: backend);
      addTearDown(() => service.dispose());
      addTearDown(backend.owner.dispose);
      await service.initialize();
      backend.isAvailable = false;
      await service.saveResults(attempt, [_turkish]);
      expect(
        (await service.persistence.read(
          'owner-1',
        )).single.pendingResults!.single.toJson(),
        _turkish.toJson(),
      );
      service.dispose();
      service = ExamService(backend: backend);
      await service.initialize();
      expect(service.errorCode, isNot('journal_invalid'));
      await service.saveResults(service.attempts.single, [_math]);
      final disk = (await service.persistence.read('owner-1')).single;
      expect(disk.pendingAction, ExamPendingAction.results);
      expect(disk.pendingResults!.map((r) => r.subjectId).toSet(), {
        'turkish',
        'mathematics',
      });
      backend.isAvailable = true;
      await service.sync();
      final saved = service.attempts.single;
      expect(saved.subjectResults.map((r) => r.subjectId).toSet(), {
        'turkish',
        'mathematics',
        'physics',
      });
      expect(
        saved.subjectResults
            .singleWhere((r) => r.subjectId == 'physics')
            .toJson(),
        _physics.toJson(),
      );
      expect(saved.pointsEarned, 33);
      expect(saved.examCoinsEarned, 6);
      expect(backend.completions, 0);
      expect(backend.profileRefreshes, 0);
      expect(backend.calls.where((c) => c.$1 == 'save_exam_results').length, 1);
      expect(
        jsonEncode(
          backend.calls.lastWhere((c) => c.$1 == 'save_exam_results').$2,
        ),
        isNot(contains('points')),
      );
    },
  );

  test(
    'partial validation still rejects empty, unknown, duplicate and malformed journal rows',
    () async {
      final backend = _PartialResultsBackend();
      final attempt = _completed(backend);
      backend.rows[attempt.clientUuid] = attempt;
      final service = ExamService(backend: backend);
      addTearDown(service.dispose);
      addTearDown(backend.owner.dispose);
      await service.initialize();
      for (final results in <List<ExamSubjectResult>>[
        [],
        [_turkish, _turkish],
        [
          const ExamSubjectResult(
            subjectId: 'unknown',
            correct: 0,
            wrong: 0,
            blank: 40,
          ),
        ],
        [
          const ExamSubjectResult(
            subjectId: 'turkish',
            correct: -1,
            wrong: 1,
            blank: 40,
          ),
        ],
        [
          const ExamSubjectResult(
            subjectId: 'turkish',
            correct: 40,
            wrong: 1,
            blank: 0,
          ),
        ],
      ]) {
        await expectLater(
          service.saveResults(attempt, results),
          throwsA(isA<ExamFailure>()),
        );
        final record = ExamLocalRecord(
          clientUuid: attempt.clientUuid,
          definition: attempt.definition!,
          createdAt: attempt.startedAt,
          attempt: attempt,
          pendingAction: ExamPendingAction.results,
          pendingResults: results,
        );
        expect(ExamLocalRecord.fromJson(record.toJson()), isNull);
      }
      expect(backend.calls.where((c) => c.$1 == 'save_exam_results'), isEmpty);
    },
  );
  test(
    'all seven catalog families use the intended divisor and decimal separator',
    () {
      const expected = {
        'tyt': (4, '1.75', '1,75'),
        'ayt': (4, '1.75', '1,75'),
        'ydt': (4, '1.75', '1,75'),
        'lgs_verbal': (3, '1.67', '1,67'),
        'lgs_quantitative': (3, '1.67', '1,67'),
        'tus_basic': (4, '1.75', '1,75'),
        'tus_clinical': (4, '1.75', '1,75'),
      };
      expect(
        offlineExamCatalog.exams.map((e) => e.id).toSet(),
        expected.keys.toSet(),
      );
      for (final exam in offlineExamCatalog.exams) {
        final values = expected[exam.id]!;
        final subject = exam.subjects.first;
        final result = ExamSubjectResult(
          subjectId: subject.id,
          correct: 2,
          wrong: 1,
          blank: subject.questionCount - 3,
        );
        expect(result.isValidFor(subject), isTrue);
        expect(exam.wrongAnswerDivisor, values.$1);
        expect(
          formatExamNet(result.net(exam.wrongAnswerDivisor), 'en'),
          values.$2,
        );
        expect(
          formatExamNet(result.net(exam.wrongAnswerDivisor), 'tr'),
          values.$3,
        );
      }
    },
  );
}
