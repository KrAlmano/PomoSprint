import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_model.dart';

void main() {
  test(
    'offline reference preserves twenty official question structures and current32 reward policy',
    () {
      final json = jsonDecode(
        File('supabase/proposed/exam_catalog_v1.json').readAsStringSync(),
      );
      final parsed = ExamCatalog.fromJson(json)!;
      Map<String, dynamic> structure(ExamDefinition e) => e.toJson()
        ..remove('reward_points')
        ..remove('reward_coins')
        ..remove('reward_policy_version')
        ..remove('modules');
      expect(
        parsed.exams.map(structure).toList(),
        offlineExamCatalog.exams.map(structure).toList(),
      );
      final latest = ExamCatalog.fromJson(
        jsonDecode(
          File('supabase/proposed/exam_catalog_32.json').readAsStringSync(),
        ),
      )!;
      for (final exam in latest.exams) {
        final offline = offlineExamCatalog.byId(exam.id)!;
        expect(offline.fullRewardCoins, exam.fullRewardCoins, reason: exam.id);
        expect(
          offline.fullRewardPoints,
          exam.fullRewardPoints,
          reason: exam.id,
        );
      }
      expect(parsed.available, isFalse);
    },
  );
  test(
    'offline catalog is read only and every official question sum is consistent',
    () {
      expect(offlineExamCatalog.available, isFalse);
      expect(offlineExamCatalog.fromServer, isFalse);
      expect(offlineExamCatalog.exams, hasLength(20));
      for (final exam in offlineExamCatalog.exams) {
        expect(exam.isValid, isTrue, reason: exam.id);
        expect(ExamDefinition.fromJson(exam.toJson())?.toJson(), exam.toJson());
      }
      expect(offlineExamCatalog.byId('tyt')!.durationSeconds, 165 * 60);
      expect(offlineExamCatalog.byId('ayt')!.totalQuestions, 160);
      expect(offlineExamCatalog.byId('tus_basic')!.durationSeconds, 135 * 60);
      expect(offlineExamCatalog.byId('tus_clinical')!.totalQuestions, 100);
    },
  );
  test('incomplete schema and invalid catalog fail closed', () {
    final exam = offlineExamCatalog.exams.first.toJson();
    expect(
      ExamCatalog.fromJson({
        'available': true,
        'exams': [exam],
      }),
      isNull,
    );
    expect(
      ExamCatalog.fromJson({
        'schema_version': 1,
        'available': true,
        'exams': [exam, exam],
      }),
      isNull,
    );
    expect(ExamDefinition.fromJson({...exam, 'total_questions': 1}), isNull);
    final parsed = ExamCatalog.fromJson({
      'schema_version': 1,
      'exams': [exam],
    })!;
    expect(parsed.available, isFalse);
  });
  test('catalog accepts group and exact negative net remains valid', () {
    final exam = offlineExamCatalog.exams.first;
    final json = exam.toJson()..remove('segment');
    json['group'] = 'yks';
    expect(ExamDefinition.fromJson(json)!.segment, 'yks');
    final subject = exam.subjects.first;
    final result = ExamSubjectResult(
      subjectId: subject.id,
      correct: 0,
      wrong: 4,
      blank: 36,
    );
    expect(result.isValidFor(subject), isTrue);
    expect(result.net(4), -1);
    expect(
      const ExamSubjectResult(
        subjectId: 'a',
        correct: -1,
        wrong: 0,
        blank: 1,
      ).isValidFor(subject),
      isFalse,
    );
    expect(
      ExamSubjectResult.fromJson({
        'subject_id': 'a',
        'correct': 0.5,
        'wrong': 0,
        'blank': 0,
      }),
      isNull,
    );
  });
  test(
    'remaining time is absolute, clamps elapsed, and survives JSON round trip',
    () {
      final start = DateTime.utc(2026, 10, 27, 8);
      final a = ExamAttempt(
        id: '1',
        clientUuid: '2',
        examId: 'tyt',
        startedAt: start,
        endsAt: start.add(const Duration(minutes: 165)),
        durationSeconds: 9900,
        totalQuestions: 120,
        status: ExamAttemptStatus.active,
      );
      final restored = ExamAttempt.fromJson(a.toJson())!;
      expect(
        restored.remainingSecondsAt(start.add(const Duration(minutes: 100))),
        65 * 60,
      );
      expect(
        restored.remainingSecondsAt(start.subtract(const Duration(hours: 1))),
        9900,
      );
      expect(
        restored.remainingSecondsAt(start.add(const Duration(days: 1))),
        0,
      );
    },
  );
}
