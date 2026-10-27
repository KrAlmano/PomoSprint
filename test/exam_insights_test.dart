import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_insights.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/models/study_session.dart';

void main() {
  final now = DateTime.utc(2026, 10, 28, 12);
  final exam = offlineExamCatalog.byId('tyt')!;
  ExamAttempt attempt(
    String id,
    DateTime date,
    int correct, {
    bool completed = true,
  }) => ExamAttempt(
    id: id,
    clientUuid: id,
    examId: 'tyt',
    startedAt: date,
    endsAt: date.add(const Duration(minutes: 165)),
    durationSeconds: 9900,
    totalQuestions: 120,
    status: completed
        ? ExamAttemptStatus.completed
        : ExamAttemptStatus.abandoned,
    definition: exam,
    subjectResults: [
      ExamSubjectResult(
        subjectId: 'physics',
        correct: correct,
        wrong: 0,
        blank: 7 - correct,
      ),
    ],
  );
  StudySession study(
    String id,
    DateTime date,
    String category, {
    int minutes = 50,
  }) => StudySession(
    id: id,
    userId: 'owner',
    categoryName: category,
    clientUuid: id,
    minutes: minutes,
    pomodoros: 2,
    startedAt: date,
    completedAt: date.add(Duration(minutes: minutes)),
  );
  test(
    'same exam subject compares valid net with matching localized study only, no double count',
    () {
      final first = attempt('a', now.subtract(const Duration(days: 10)), 3);
      final last = attempt('b', now.subtract(const Duration(days: 1)), 6);
      final s = study('s', now.subtract(const Duration(days: 5)), 'Physics');
      final rows = buildExamTimeInsights(
        attempts: [first, last, last],
        studySessions: [
          s,
          s,
          study('other', now.subtract(const Duration(days: 5)), 'Chemistry'),
        ],
        definitionFor: (a) => a.definition,
        now: now,
      );
      expect(rows, hasLength(1));
      expect(rows.single.studyMinutes, 50);
      expect(rows.single.before, 3);
      expect(rows.single.after, 6);
    },
  );
  test(
    'insufficient, abandoned, same-day, old and future observations cannot form a trend',
    () {
      for (final rows in [
        [attempt('a', now.subtract(const Duration(days: 2)), 3)],
        [
          attempt(
            'a',
            now.subtract(const Duration(days: 10)),
            3,
            completed: false,
          ),
          attempt('b', now, 6),
        ],
        [
          attempt('a', now.subtract(const Duration(hours: 3)), 3),
          attempt('b', now, 6),
        ],
        [
          attempt('a', now.subtract(const Duration(days: 30)), 3),
          attempt('b', now, 6),
        ],
        [
          attempt('a', now.subtract(const Duration(days: 3)), 3),
          attempt('b', now.add(const Duration(days: 1)), 6),
        ],
      ]) {
        expect(
          buildExamTimeInsights(
            attempts: rows,
            studySessions: [],
            definitionFor: (a) => a.definition,
            now: now,
          ),
          isEmpty,
        );
      }
    },
  );
  test(
    'zero matching study remains factual, and changed catalog versions never compare',
    () {
      final first = attempt('a', now.subtract(const Duration(days: 10)), 6);
      final last = attempt('b', now.subtract(const Duration(days: 1)), 3);
      final result = buildExamTimeInsights(
        attempts: [first, last],
        studySessions: [],
        definitionFor: (a) => a.definition,
        now: now,
      );
      expect(result.single.studyMinutes, 0);
      expect(result.single.after, 3);
      final changed = ExamAttempt.fromJson({
        ...last.toJson(),
        'catalog_version': 2,
      })!;
      expect(
        buildExamTimeInsights(
          attempts: [first, changed],
          studySessions: [],
          definitionFor: (a) => a.definition,
          now: now,
        ),
        isEmpty,
      );
    },
  );
}
