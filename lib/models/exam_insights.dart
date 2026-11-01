import '../utils/category_names.dart';
import 'exam_model.dart';
import 'study_session.dart';

/// A descriptive comparison, never a claim of causation or an exam score.
class ExamTimeInsight {
  const ExamTimeInsight({
    required this.subject,
    required this.studyMinutes,
    required this.firstAt,
    required this.lastAt,
    required this.before,
    required this.after,
    required this.hasAnsweredQuestions,
  });
  final ExamSubject subject;
  final int studyMinutes;
  final DateTime firstAt;
  final DateTime lastAt;
  final double before;
  final double after;
  /// Distinguishes entirely blank results from attempted zero-net results.
  final bool hasAnsweredQuestions;
}

List<ExamTimeInsight> buildExamTimeInsights({
  required List<ExamAttempt> attempts,
  required List<StudySession> studySessions,
  required ExamDefinition? Function(ExamAttempt) definitionFor,
  required DateTime now,
}) {
  final cutoff = now.subtract(const Duration(days: 21));
  final groups =
      <
        String,
        List<
          ({
            ExamAttempt attempt,
            ExamDefinition exam,
            ExamSubject subject,
            ExamSubjectResult result,
          })
        >
      >{};
  final seen = <String>{};
  for (final attempt in attempts) {
    if (!attempt.isCompleted ||
        !seen.add(attempt.clientUuid) ||
        attempt.startedAt.isBefore(cutoff) ||
        attempt.startedAt.isAfter(now)) {
      continue;
    }
    final exam = definitionFor(attempt);
    if (exam == null) continue;
    for (final subject in exam.subjects) {
      // Only catalog-declared category mappings may contribute study time.
      // A shared category total can contextualize multiple subject results;
      // it is neither split into subject time nor added to study totals here.
      if (subject.categoryKeys.isEmpty) continue;
      final result = attempt.subjectResults
          .where((r) => r.isValidFor(subject))
          .firstOrNull;
      if (result == null) continue;
      final key =
          '${exam.id}:${attempt.catalogVersion}:${subject.id}:${subject.questionCount}';
      groups.putIfAbsent(key, () => []).add((
        attempt: attempt,
        exam: exam,
        subject: subject,
        result: result,
      ));
    }
  }
  final insights = <ExamTimeInsight>[];
  for (final group in groups.values) {
    group.sort((a, b) => a.attempt.startedAt.compareTo(b.attempt.startedAt));
    if (group.length < 2) continue;
    final first = group.first, last = group.last;
    if (last.attempt.startedAt.difference(first.attempt.startedAt) <
        const Duration(days: 1)) {
      continue;
    }
    final keys = first.subject.categoryKeys.map(categoryMatchKey).toSet();
    var minutes = 0;
    final sessionIds = <String>{};
    for (final session in studySessions) {
      final date = session.startedAt ?? session.completedAt;
      if (!sessionIds.add(session.clientUuid ?? session.id) ||
          date.isBefore(first.attempt.startedAt) ||
          date.isAfter(last.attempt.startedAt) ||
          !keys.contains(categoryMatchKey(session.categoryName))) {
        continue;
      }
      if (session.minutes > 0) minutes += session.minutes;
    }
    insights.add(
      ExamTimeInsight(
        subject: first.subject,
        studyMinutes: minutes,
        firstAt: first.attempt.startedAt,
        lastAt: last.attempt.startedAt,
        before: first.result.net(first.exam.wrongAnswerDivisor),
        after: last.result.net(last.exam.wrongAnswerDivisor),
        hasAnsweredQuestions: group.any(
          (entry) => entry.result.correct + entry.result.wrong > 0,
        ),
      ),
    );
  }
  return insights;
}
