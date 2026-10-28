import 'package:flutter/foundation.dart';

import 'exam_reward_policy.dart';

@immutable
class ExamModule {
  const ExamModule({
    required this.id,
    required this.nameTr,
    required this.nameEn,
    required this.subjectIds,
  });
  final String id;
  final String nameTr;
  final String nameEn;
  final List<String> subjectIds;
  String name(bool turkish) => turkish ? nameTr : nameEn;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name_tr': nameTr,
    'name_en': nameEn,
    'subject_ids': subjectIds,
  };
  static ExamModule? fromJson(Object? value) {
    if (value is! Map || value['subject_ids'] is! List) return null;
    final ids = (value['subject_ids'] as List).whereType<String>().toList();
    final id = value['id'];
    final tr = _localizedLabel(value['name_tr']),
        en = _localizedLabel(value['name_en']);
    if (id is! String ||
        id.isEmpty ||
        tr.isEmpty ||
        en.isEmpty ||
        ids.isEmpty ||
        ids.length != (value['subject_ids'] as List).length ||
        ids.toSet().length != ids.length) {
      return null;
    }
    return ExamModule(
      id: id,
      nameTr: tr,
      nameEn: en,
      subjectIds: List.unmodifiable(ids),
    );
  }
}

const _aytQuestions = <String, int>{
  'literature': 24,
  'history_1': 10,
  'geography_1': 6,
  'history_2': 11,
  'geography_2': 11,
  'philosophy_group': 12,
  'religion': 6,
  'mathematics': 40,
  'physics': 14,
  'chemistry': 13,
  'biology': 13,
};
const _legacyAytModules = <ExamModule>[
  ExamModule(
    id: 'turkish_social_1',
    nameTr: 'Türk Dili ve Edebiyatı–Sosyal Bilimler-1',
    nameEn: 'Turkish Language and Literature–Social Sciences-1',
    subjectIds: ['literature', 'history_1', 'geography_1'],
  ),
  ExamModule(
    id: 'social_2',
    nameTr: 'Sosyal Bilimler-2',
    nameEn: 'Social Sciences-2',
    subjectIds: ['history_2', 'geography_2', 'philosophy_group', 'religion'],
  ),
  ExamModule(
    id: 'mathematics',
    nameTr: 'Matematik',
    nameEn: 'Mathematics',
    subjectIds: ['mathematics'],
  ),
  ExamModule(
    id: 'science',
    nameTr: 'Fen Bilimleri',
    nameEn: 'Science',
    subjectIds: ['physics', 'chemistry', 'biology'],
  ),
];

@immutable
class ExamCapabilities {
  const ExamCapabilities({
    this.aytEarlyFinish = false,
    this.details = false,
    this.aytModulesVersion = 0,
  });
  final bool aytEarlyFinish;
  final bool details;
  final int aytModulesVersion;
  factory ExamCapabilities.fromJson(Object? value) => value is Map
      ? ExamCapabilities(
          aytEarlyFinish: value['ayt_early_finish'] == true,
          details: value['exam_details'] == true,
          aytModulesVersion: _integer(value['ayt_modules_version']),
        )
      : const ExamCapabilities();
}

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
    this.modules = const [],
    this.rewardPoints,
    this.rewardCoins,
    this.rewardPolicyVersion,
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
  final List<ExamModule> modules;
  final int? rewardPoints;
  final int? rewardCoins;
  final int? rewardPolicyVersion;

  int get fullRewardPoints =>
      rewardPoints ?? ExamRewardPolicy.byExam[id]?.points ?? 0;
  int get fullRewardCoins =>
      rewardCoins ?? ExamRewardPolicy.byExam[id]?.sand ?? 0;
  int get effectiveRewardPolicyVersion =>
      rewardPolicyVersion ??
      (rewardPoints != null || rewardCoins != null
          ? 1
          : ExamRewardPolicy.version);

  /// A legacy AYT is mapped only when every subject ID and quota matches.
  List<ExamModule> get effectiveModules {
    if (modules.isNotEmpty) return modules;
    if (id != 'ayt' ||
        totalQuestions != 160 ||
        wrongAnswerDivisor != 4 ||
        subjects.length != _aytQuestions.length ||
        !subjects.every((s) => _aytQuestions[s.id] == s.questionCount)) {
      return const [];
    }
    return _legacyAytModules;
  }

  Set<String> subjectIdsForModules(Iterable<String> ids) => {
    for (final module in effectiveModules)
      if (ids.contains(module.id)) ...module.subjectIds,
  };
  String name(bool turkish) => turkish ? nameTr : nameEn;
  bool get isValid =>
      id.isNotEmpty &&
      nameTr.trim().isNotEmpty &&
      nameEn.trim().isNotEmpty &&
      durationSeconds > 0 &&
      totalQuestions > 0 &&
      wrongAnswerDivisor > 0 &&
      subjects.isNotEmpty &&
      (rewardPoints == null || rewardPoints! >= 0) &&
      (rewardCoins == null || rewardCoins! >= 0) &&
      (rewardPolicyVersion == null || rewardPolicyVersion! >= 0) &&
      subjects.map((s) => s.id).toSet().length == subjects.length &&
      subjects.fold<int>(0, (n, s) => n + s.questionCount) == totalQuestions &&
      (modules.isEmpty ||
          (modules.map((m) => m.id).toSet().length == modules.length &&
              modules.expand((m) => m.subjectIds).length == subjects.length &&
              setEquals(
                modules.expand((m) => m.subjectIds).toSet(),
                subjects.map((s) => s.id).toSet(),
              )));
  Map<String, dynamic> toJson() => {
    'id': id,
    'name_tr': nameTr,
    'name_en': nameEn,
    'segment': segment,
    'duration_seconds': durationSeconds,
    'total_questions': totalQuestions,
    'wrong_answer_divisor': wrongAnswerDivisor,
    'catalog_version': version,
    'reward_points': fullRewardPoints,
    'reward_coins': fullRewardCoins,
    'reward_policy_version': effectiveRewardPolicyVersion,
    'subjects': subjects.map((s) => s.toJson()).toList(),
    if (modules.isNotEmpty) 'modules': modules.map((m) => m.toJson()).toList(),
  };
  static ExamDefinition? fromJson(Object? value) {
    if (value is! Map || value['subjects'] is! List) return null;
    final subjects = (value['subjects'] as List)
        .map(ExamSubject.fromJson)
        .toList();
    if (subjects.any((s) => s == null)) return null;
    final rawModules = value['modules'];
    if (rawModules != null && rawModules is! List) return null;
    final modules = (rawModules as List? ?? const [])
        .map(ExamModule.fromJson)
        .toList();
    if (modules.any((m) => m == null)) return null;
    final result = ExamDefinition(
      id: value['id']?.toString() ?? '',
      nameTr: _localizedLabel(value['name_tr']),
      nameEn: _localizedLabel(value['name_en']),
      segment: (value['segment'] ?? value['group'])?.toString() ?? '',
      durationSeconds: _integer(value['duration_seconds']),
      totalQuestions: _integer(value['total_questions']),
      wrongAnswerDivisor: _integer(value['wrong_answer_divisor']),
      version: _integer(value['catalog_version'], fallback: 1),
      rewardPoints: value['reward_points'] == null
          ? null
          : _integer(value['reward_points'], fallback: -1),
      rewardCoins: value['reward_coins'] == null
          ? null
          : _integer(value['reward_coins'], fallback: -1),
      rewardPolicyVersion: value['reward_policy_version'] == null
          ? null
          : _integer(value['reward_policy_version'], fallback: -1),
      subjects: List.unmodifiable(subjects.cast<ExamSubject>()),
      modules: List.unmodifiable(modules.cast<ExamModule>()),
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
    this.capabilities = const ExamCapabilities(),
  });
  final List<ExamDefinition> exams;
  final bool available;
  final bool fromServer;
  final int version;
  final DateTime? serverTime;
  final ExamCapabilities capabilities;
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
      capabilities: ExamCapabilities.fromJson(value['capabilities']),
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

enum ExamCompletionKind { full, early }

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
    this.plannedDurationSeconds,
    this.elapsedSeconds,
    this.creditedMinutes,
    this.completionKind,
    this.title,
    this.note,
    this.selectedModuleIds,
    this.detailsRevision = 0,
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
  final int? plannedDurationSeconds;
  final int? elapsedSeconds;
  final int? creditedMinutes;
  final ExamCompletionKind? completionKind;
  final String? title;
  final String? note;

  /// Null is unknown legacy scope, never an implicit choice of all tests.
  final List<String>? selectedModuleIds;
  final int detailsRevision;
  bool get isCompleted => status == ExamAttemptStatus.completed;
  int get plannedSeconds =>
      plannedDurationSeconds ?? definition?.durationSeconds ?? durationSeconds;
  int get actualSeconds => isCompleted ? elapsedSeconds ?? durationSeconds : 0;
  int get reportMinutes =>
      isCompleted ? creditedMinutes ?? durationSeconds ~/ 60 : 0;
  bool get finishedEarly => completionKind == ExamCompletionKind.early;
  int? get selectedQuestionCount {
    final selected = selectedModuleIds, exam = definition;
    if (selected == null || exam == null || exam.effectiveModules.isEmpty) {
      return null;
    }
    final ids = exam.subjectIdsForModules(selected);
    return exam.subjects
        .where((s) => ids.contains(s.id))
        .fold<int>(0, (n, s) => n + s.questionCount);
  }

  int remainingSecondsAt(DateTime now) {
    if (status != ExamAttemptStatus.active) return 0;
    final ms = endsAt.difference(now).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil().clamp(0, plannedSeconds);
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
    plannedDurationSeconds: plannedDurationSeconds,
    elapsedSeconds: elapsedSeconds,
    creditedMinutes: creditedMinutes,
    completionKind: completionKind,
    title: title,
    note: note,
    selectedModuleIds: selectedModuleIds,
    detailsRevision: detailsRevision,
  );

  /// Retain a newer accepted metadata revision while accepting lifecycle data.
  ExamAttempt withDetailsFrom(ExamAttempt other) => ExamAttempt(
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
    definition: definition,
    plannedDurationSeconds: plannedDurationSeconds,
    elapsedSeconds: elapsedSeconds,
    creditedMinutes: creditedMinutes,
    completionKind: completionKind,
    subjectResults: other.subjectResults,
    title: other.title,
    note: other.note,
    selectedModuleIds: other.selectedModuleIds,
    detailsRevision: other.detailsRevision,
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
    if (plannedDurationSeconds != null)
      'planned_duration_seconds': plannedDurationSeconds,
    if (elapsedSeconds != null) 'elapsed_seconds': elapsedSeconds,
    if (creditedMinutes != null) 'credited_minutes': creditedMinutes,
    if (completionKind != null) 'completion_kind': completionKind!.name,
    'title': title,
    'note': note,
    'selected_module_ids': selectedModuleIds,
    'details_revision': detailsRevision,
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
    final definition =
        ExamDefinition.fromJson(value['definition']) ??
        ExamDefinition.fromJson({...value, 'id': examId});
    if (definition != null && definition.id != examId) return null;
    final rawPlanned = value['planned_duration_seconds'];
    final rawElapsed = value['elapsed_seconds'];
    final rawCredit = value['credited_minutes'];
    final planned = rawPlanned == null
        ? null
        : _integer(rawPlanned, fallback: -1);
    final elapsed = rawElapsed == null
        ? null
        : _integer(rawElapsed, fallback: -1);
    final credit = rawCredit == null ? null : _integer(rawCredit, fallback: -1);
    final completion = switch (value['completion_kind']) {
      null => null,
      'full' => ExamCompletionKind.full,
      'early' => ExamCompletionKind.early,
      _ => null,
    };
    final completedAt = _date(value['completed_at'] ?? value['finished_at']);
    if ((planned != null && planned <= 0) ||
        (elapsed != null && elapsed < 0) ||
        (credit != null && credit < 0) ||
        (value['completion_kind'] != null && completion == null)) {
      return null;
    }
    if (status == ExamAttemptStatus.completed &&
        (elapsed != null ||
            planned != null ||
            completion != null ||
            credit != null)) {
      final actual = elapsed ?? duration,
          plan = planned ?? definition?.durationSeconds ?? duration;
      if (actual < 1 ||
          actual > plan ||
          duration != actual ||
          (credit != null && credit != actual ~/ 60) ||
          completedAt == null ||
          completedAt.isBefore(start) ||
          completedAt.isAfter(end) ||
          completedAt.difference(start).inSeconds != actual ||
          (completion == ExamCompletionKind.early &&
              !completedAt.isBefore(end)) ||
          (completion == ExamCompletionKind.full && completedAt != end)) {
        return null;
      }
    }
    final rawTitle = value['title'], rawNote = value['note'];
    if ((rawTitle != null &&
            (rawTitle is! String || !validExamText(rawTitle, title: true))) ||
        (rawNote != null &&
            (rawNote is! String || !validExamText(rawNote, title: false)))) {
      return null;
    }
    final rawSelected = value['selected_module_ids'];
    List<String>? selected;
    if (rawSelected != null) {
      if (rawSelected is! List ||
          rawSelected.isEmpty ||
          rawSelected.length > 4 ||
          rawSelected.any((id) => id is! String) ||
          rawSelected.toSet().length != rawSelected.length ||
          examId != 'ayt') {
        return null;
      }
      selected = rawSelected.cast<String>();
      if (definition != null &&
          (definition.effectiveModules.isEmpty ||
              !selected.every(
                (id) => definition.effectiveModules.any((m) => m.id == id),
              ))) {
        return null;
      }
    }
    final revision = _integer(
      value['details_revision'],
      fallback: value['details_revision'] == null ? 0 : -1,
    );
    if (revision < 0) return null;
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
      completedAt: completedAt,
      subjectResults: List.unmodifiable(results.cast<ExamSubjectResult>()),
      definition: definition,
      plannedDurationSeconds: planned,
      elapsedSeconds: elapsed,
      creditedMinutes: credit,
      completionKind: completion,
      title: rawTitle as String?,
      note: rawNote as String?,
      selectedModuleIds: selected == null ? null : List.unmodifiable(selected),
      detailsRevision: revision,
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

/// PostgreSQL char_length counts Unicode scalars; Dart String.length does not.
bool validExamText(String value, {required bool title}) =>
    value.runes.length <= (title ? 120 : 2000) &&
    (!title || value.trim().isNotEmpty) &&
    !value.runes.any(
      (c) =>
          (c < 32 && !(!title && (c == 9 || c == 10))) ||
          (c >= 127 && c <= 159) ||
          (title && (c == 8232 || c == 8233)),
    );
