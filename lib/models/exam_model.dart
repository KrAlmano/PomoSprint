import 'package:flutter/foundation.dart';

@immutable
class ExamSubject {
  const ExamSubject({
    required this.id,
    required this.nameTr,
    required this.nameEn,
    required this.questionCount,
    this.categoryKeys = const [],
  });
  final String id;
  final String nameTr;
  final String nameEn;
  final int questionCount;
  final List<String> categoryKeys;
  String name(bool turkish) => turkish ? nameTr : nameEn;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name_tr': nameTr,
    'name_en': nameEn,
    'question_count': questionCount,
    'category_keys': categoryKeys,
  };
  static ExamSubject? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id']?.toString() ?? '';
    final tr = _localizedLabel(value['name_tr']);
    final en = _localizedLabel(value['name_en']);
    final count = _integer(value['question_count']);
    if (id.isEmpty || tr.isEmpty || en.isEmpty || count <= 0) return null;
    return ExamSubject(
      id: id,
      nameTr: tr,
      nameEn: en,
      questionCount: count,
      categoryKeys: List.unmodifiable(
        value['category_keys'] is List
            ? (value['category_keys'] as List).whereType<String>()
            : const <String>[],
      ),
    );
  }
}

@immutable
class ExamDefinition {
  const ExamDefinition({
    required this.id,
    required this.nameTr,
    required this.nameEn,
    required this.segment,
    required this.durationSeconds,
    required this.totalQuestions,
    required this.wrongAnswerDivisor,
    required this.subjects,
    this.version = 1,
  });
  final String id;
  final String nameTr;
  final String nameEn;
  final String segment;
  final int durationSeconds;
  final int totalQuestions;
  final int wrongAnswerDivisor;
  final int version;
  final List<ExamSubject> subjects;
  String name(bool turkish) => turkish ? nameTr : nameEn;
  bool get isValid =>
      id.isNotEmpty &&
      nameTr.trim().isNotEmpty &&
      nameEn.trim().isNotEmpty &&
      durationSeconds > 0 &&
      totalQuestions > 0 &&
      wrongAnswerDivisor > 0 &&
      subjects.isNotEmpty &&
      subjects.map((s) => s.id).toSet().length == subjects.length &&
      subjects.fold<int>(0, (n, s) => n + s.questionCount) == totalQuestions;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name_tr': nameTr,
    'name_en': nameEn,
    'segment': segment,
    'duration_seconds': durationSeconds,
    'total_questions': totalQuestions,
    'wrong_answer_divisor': wrongAnswerDivisor,
    'catalog_version': version,
    'subjects': subjects.map((s) => s.toJson()).toList(),
  };
  static ExamDefinition? fromJson(Object? value) {
    if (value is! Map || value['subjects'] is! List) return null;
    final subjects = (value['subjects'] as List)
        .map(ExamSubject.fromJson)
        .toList();
    if (subjects.any((s) => s == null)) return null;
    final result = ExamDefinition(
      id: value['id']?.toString() ?? '',
      nameTr: _localizedLabel(value['name_tr']),
      nameEn: _localizedLabel(value['name_en']),
      segment: (value['segment'] ?? value['group'])?.toString() ?? '',
      durationSeconds: _integer(value['duration_seconds']),
      totalQuestions: _integer(value['total_questions']),
      wrongAnswerDivisor: _integer(value['wrong_answer_divisor']),
      version: _integer(value['catalog_version'], fallback: 1),
      subjects: List.unmodifiable(subjects.cast<ExamSubject>()),
    );
    return result.isValid ? result : null;
  }
}

@immutable
class ExamCatalog {
  const ExamCatalog({
    required this.exams,
    this.available = false,
    this.fromServer = false,
    this.version = 1,
    this.serverTime,
  });
  final List<ExamDefinition> exams;
  final bool available;
  final bool fromServer;
  final int version;
  final DateTime? serverTime;
  ExamDefinition? byId(String id) {
    for (final exam in exams) {
      if (exam.id == id) return exam;
    }
    return null;
  }

  static ExamCatalog? fromJson(Object? value) {
    if (value is! Map ||
        value['exams'] is! List ||
        value['schema_version'] != 1) {
      return null;
    }
    final exams = (value['exams'] as List)
        .map(ExamDefinition.fromJson)
        .toList();
    if (exams.isEmpty || exams.any((e) => e == null)) return null;
    final valid = exams.cast<ExamDefinition>();
    if (valid.map((e) => e.id).toSet().length != valid.length) return null;
    return ExamCatalog(
      exams: List.unmodifiable(valid),
      available: value['available'] == true,
      fromServer: true,
      serverTime: _date(value['server_time']),
    );
  }
}

@immutable
class ExamSubjectResult {
  const ExamSubjectResult({
    required this.subjectId,
    required this.correct,
    required this.wrong,
    required this.blank,
  });
  final String subjectId;
  final int correct;
  final int wrong;
  final int blank;
  int get answeredTotal => correct + wrong + blank;
  bool isValidFor(ExamSubject subject) =>
      subjectId == subject.id &&
      correct >= 0 &&
      wrong >= 0 &&
      blank >= 0 &&
      answeredTotal == subject.questionCount;
  double net(int divisor) => correct - wrong / divisor;
  Map<String, dynamic> toJson() => {
    'subject_id': subjectId,
    'correct': correct,
    'wrong': wrong,
    'blank': blank,
  };
  static ExamSubjectResult? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['subject_id']?.toString() ?? '';
    if (id.isEmpty ||
        !['correct', 'wrong', 'blank'].every(
          (key) =>
              value[key] is num &&
              (value[key] as num).isFinite &&
              value[key] == (value[key] as num).toInt(),
        )) {
      return null;
    }
    final result = ExamSubjectResult(
      subjectId: id,
      correct: _integer(value['correct']),
      wrong: _integer(value['wrong']),
      blank: _integer(value['blank']),
    );
    return result.correct >= 0 && result.wrong >= 0 && result.blank >= 0
        ? result
        : null;
  }
}

enum ExamAttemptStatus { active, completed, abandoned }

/// Only server snapshots are accepted as completed or rewarded attempts.
@immutable
class ExamAttempt {
  const ExamAttempt({
    required this.id,
    required this.clientUuid,
    required this.examId,
    required this.startedAt,
    required this.endsAt,
    required this.durationSeconds,
    required this.totalQuestions,
    required this.status,
    this.catalogVersion = 1,
    this.pointsEarned = 0,
    this.examCoinsEarned = 0,
    this.completedAt,
    this.subjectResults = const [],
    this.definition,
  });
  final String id;
  final String clientUuid;
  final String examId;
  final int catalogVersion;
  final DateTime startedAt;
  final DateTime endsAt;
  final DateTime? completedAt;
  final int durationSeconds;
  final int totalQuestions;
  final ExamAttemptStatus status;
  final int pointsEarned;
  final int examCoinsEarned;
  final List<ExamSubjectResult> subjectResults;
  final ExamDefinition? definition;
  bool get isCompleted => status == ExamAttemptStatus.completed;
  int remainingSecondsAt(DateTime now) {
    final ms = endsAt.difference(now).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil().clamp(0, durationSeconds);
  }

  ExamAttempt withDefinition(ExamDefinition? value) => ExamAttempt(
    id: id,
    clientUuid: clientUuid,
    examId: examId,
    startedAt: startedAt,
    endsAt: endsAt,
    durationSeconds: durationSeconds,
    totalQuestions: totalQuestions,
    status: status,
    catalogVersion: catalogVersion,
    pointsEarned: pointsEarned,
    examCoinsEarned: examCoinsEarned,
    completedAt: completedAt,
    subjectResults: subjectResults,
    definition: value ?? definition,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'client_uuid': clientUuid,
    'exam_id': examId,
    'catalog_version': catalogVersion,
    'started_at': startedAt.toUtc().toIso8601String(),
    'ends_at': endsAt.toUtc().toIso8601String(),
    'duration_seconds': durationSeconds,
    'total_questions': totalQuestions,
    'status': status.name,
    'points_earned': pointsEarned,
    'exam_coins_earned': examCoinsEarned,
    'completed_at': completedAt?.toUtc().toIso8601String(),
    'subject_results': subjectResults.map((r) => r.toJson()).toList(),
    if (definition != null) 'definition': definition!.toJson(),
  };
  static ExamAttempt? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id']?.toString() ?? '';
    final uuid = value['client_uuid']?.toString() ?? '';
    final examId = value['exam_id']?.toString() ?? '';
    final start = _date(value['started_at']);
    final end = _date(value['ends_at']);
    final duration = _integer(value['duration_seconds']);
    final total = _integer(value['total_questions']);
    final status = switch (value['status']) {
      'active' => ExamAttemptStatus.active,
      'completed' => ExamAttemptStatus.completed,
      'abandoned' => ExamAttemptStatus.abandoned,
      _ => null,
    };
    if (id.isEmpty ||
        uuid.isEmpty ||
        examId.isEmpty ||
        start == null ||
        end == null ||
        duration <= 0 ||
        total <= 0 ||
        status == null ||
        !end.isAfter(start)) {
      return null;
    }
    final rawResults = value['subject_results'];
    if (rawResults != null && rawResults is! List) return null;
    final results = (rawResults as List? ?? const [])
        .map(ExamSubjectResult.fromJson)
        .toList();
    if (results.any((result) => result == null) ||
        results.map((result) => result?.subjectId).toSet().length !=
            results.length) {
      return null;
    }
    return ExamAttempt(
      id: id,
      clientUuid: uuid,
      examId: examId,
      startedAt: start,
      endsAt: end,
      durationSeconds: duration,
      totalQuestions: total,
      status: status,
      catalogVersion: _integer(value['catalog_version'], fallback: 1),
      pointsEarned: _integer(value['points_earned']),
      examCoinsEarned: _integer(value['exam_coins_earned']),
      completedAt: _date(value['completed_at'] ?? value['finished_at']),
      subjectResults: List.unmodifiable(results.cast<ExamSubjectResult>()),
      definition:
          ExamDefinition.fromJson(value['definition']) ??
          ExamDefinition.fromJson({...value, 'id': examId}),
    );
  }
}

@immutable
class ExamLeagueSnapshot {
  const ExamLeagueSnapshot({
    this.scope = 'segment',
    this.segment,
    this.tier = 1,
    this.periodEnd,
    this.examCoins = 0,
    this.phase = 'preparing',
    this.rows = const [],
  });
  final String scope;
  final String? segment;
  final int tier;
  final DateTime? periodEnd;
  final int examCoins;
  final String phase;
  final List<Map<String, dynamic>> rows;
  factory ExamLeagueSnapshot.fromJson(Object? value) {
    if (value is! Map) return const ExamLeagueSnapshot();
    return ExamLeagueSnapshot(
      scope: value['scope']?.toString() ?? 'segment',
      segment: value['segment']?.toString(),
      tier: _integer(value['tier'], fallback: 1).clamp(1, 5),
      periodEnd: _date(value['period_end']),
      examCoins: _integer(value['exam_coins']),
      phase: value['competition_phase']?.toString() ?? 'preparing',
      rows: List.unmodifiable(
        value['rows'] is List
            ? (value['rows'] as List).whereType<Map>().map(
                (r) => Map<String, dynamic>.from(r),
              )
            : const <Map<String, dynamic>>[],
      ),
    );
  }
}

int _integer(Object? value, {int fallback = 0}) =>
    value is num && value.isFinite && value == value.toInt()
    ? value.toInt()
    : fallback;
DateTime? _date(Object? value) => DateTime.tryParse(value?.toString() ?? '');

String _localizedLabel(Object? value) => value is String ? value.trim() : '';
