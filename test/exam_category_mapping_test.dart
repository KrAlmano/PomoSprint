import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_insights.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/models/study_session.dart';

final _now = DateTime.utc(2026, 10, 28, 12);

ExamAttempt _attempt(
  ExamDefinition exam,
  String id,
  DateTime at,
  List<String> subjectIds,
) => ExamAttempt(
  id: id,
  clientUuid: id,
  examId: exam.id,
  startedAt: at,
  endsAt: at.add(Duration(seconds: exam.durationSeconds)),
  durationSeconds: exam.durationSeconds,
  totalQuestions: exam.totalQuestions,
  status: ExamAttemptStatus.completed,
  definition: exam,
  subjectResults: [
    for (final subject in exam.subjects.where((s) => subjectIds.contains(s.id)))
      ExamSubjectResult(
        subjectId: subject.id,
        correct: subject.questionCount,
        wrong: 0,
        blank: 0,
      ),
  ],
);

StudySession _study(String category, {String id = 'study', int minutes = 50}) =>
    StudySession(
      id: id,
      clientUuid: id,
      userId: 'owner',
      categoryName: category,
      startedAt: _now.subtract(const Duration(days: 5)),
      completedAt: _now
          .subtract(const Duration(days: 5))
          .add(Duration(minutes: minutes)),
      minutes: minutes,
      pomodoros: minutes ~/ 25,
    );

List<ExamTimeInsight> _insights(
  ExamDefinition exam,
  List<String> subjects,
  List<StudySession> studies,
) => buildExamTimeInsights(
  attempts: [
    _attempt(exam, 'before', _now.subtract(const Duration(days: 10)), subjects),
    _attempt(exam, 'after', _now.subtract(const Duration(days: 1)), subjects),
  ],
  studySessions: studies,
  definitionFor: (attempt) => attempt.definition,
  now: _now,
);

void main() {
  test(
    'TUS combined category matches both subjects in TR, EN and normalized forms',
    () {
      final exam = offlineExamCatalog.byId('tus_basic')!;
      for (final category in [
        'Fizyoloji, Histoloji ve Embriyoloji',
        'Physiology, Histology and Embryology',
        ' FİZYOLOJİ, HİSTOLOJİ VE EMBRİYOLOJİ ',
        ' physiology, histology and embryology ',
      ]) {
        final rows = _insights(
          exam,
          ['histology_embryology', 'physiology'],
          [_study(category)],
        );
        expect(rows.map((r) => r.subject.id).toSet(), {
          'histology_embryology',
          'physiology',
        }, reason: category);
        // Both comparisons reference one shared category total, not an invented
        // split into 25-minute subject totals or a 100-minute study record.
        expect(rows.map((r) => r.studyMinutes), everyElement(50));
      }
    },
  );

  test(
    'AYT literature includes both literature and Turkish study categories',
    () {
      final exam = offlineExamCatalog.byId('ayt')!;
      for (final category in [
        'Edebiyat',
        'Literature',
        'Türkçe',
        'Turkish',
        ' TÜRKÇE ',
        ' literature ',
      ]) {
        final rows = _insights(exam, ['literature'], [_study(category)]);
        expect(rows, hasLength(1), reason: category);
        expect(rows.single.studyMinutes, 50, reason: category);
      }
    },
  );

  test('AYT category aliases sum each real study once', () {
    final first = _study('Edebiyat', id: 'one', minutes: 25);
    final second = _study('Turkish', id: 'two', minutes: 50);
    final rows = _insights(
      offlineExamCatalog.byId('ayt')!,
      ['literature'],
      [first, first, second],
    );
    expect(rows.single.studyMinutes, 75);
  });

  test(
    'unmapped small-internship work is never assigned to a clinical subject',
    () {
      final exam = offlineExamCatalog.byId('tus_clinical')!;
      expect(exam.subjects.any((s) => s.id == 'small_internships'), isFalse);
      for (final category in [
        'Küçük Stajlar',
        'Other Clinical Specialties',
        ' KÜÇÜK STAJLAR ',
      ]) {
        final rows = _insights(exam, exam.subjects.map((s) => s.id).toList(), [
          _study(category),
        ]);
        expect(rows.map((r) => r.studyMinutes), everyElement(0));
        expect(rows.any((r) => r.subject.id == 'small_internships'), isFalse);
      }
    },
  );

  test(
    'insufficient TUS observations remain silent even with small-internship work',
    () {
      final exam = offlineExamCatalog.byId('tus_clinical')!;
      final rows = buildExamTimeInsights(
        attempts: [
          _attempt(exam, 'single', _now.subtract(const Duration(days: 1)), [
            'surgery_group',
          ]),
        ],
        studySessions: [_study('Küçük Stajlar')],
        definitionFor: (attempt) => attempt.definition,
        now: _now,
      );
      expect(rows, isEmpty);
    },
  );
}
