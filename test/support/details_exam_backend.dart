import 'dart:convert';

import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/services/exam_service.dart';

import 'fake_exam_backend.dart';

/// Contract fake only. Real SQL formulas/idempotency are tested independently.
class DetailsExamBackend extends FakeExamBackend {
  bool detailsAvailable = true;
  bool earlyAvailable = true;
  int acceptedEarly = 0;
  int savedDetails = 0;
  @override
  Object? defaultRpc(String name, Map<String, dynamic> params) {
    if (!isAvailable) throw const ExamFailure('connection');
    if (name == 'get_exam_config') {
      return {
        ...super.defaultRpc(name, params) as Map,
        'capabilities': {
          'exam_details': detailsAvailable,
          'ayt_early_finish': earlyAvailable,
          'ayt_modules_version': 1,
        },
      };
    }
    if (name == 'finish_ayt_early') {
      final old = rows.values.singleWhere(
        (a) => a.id == params['p_attempt_id'],
      );
      if (old.isCompleted) return {'attempt': old.toJson(), 'duplicate': true};
      if (old.examId != 'ayt') {
        throw const ExamFailure('exam_early_finish_not_supported');
      }
      final seconds = clock
          .difference(old.startedAt)
          .inSeconds
          .clamp(0, old.plannedSeconds);
      if (seconds < 1) throw const ExamFailure('exam_early_finish_too_soon');
      final at = old.startedAt.add(Duration(seconds: seconds));
      final next = ExamAttempt.fromJson({
        ...old.toJson(),
        'status': 'completed',
        'completed_at': at.toIso8601String(),
        'duration_seconds': seconds,
        'planned_duration_seconds': old.plannedSeconds,
        'elapsed_seconds': seconds,
        'credited_minutes': seconds ~/ 60,
        'completion_kind': seconds < old.plannedSeconds ? 'early' : 'full',
        'points_earned': seconds ~/ 300,
        'exam_coins_earned':
            old.definition!.fullRewardCoins * seconds ~/ old.plannedSeconds,
      })!;
      rows[old.clientUuid] = next;
      acceptedEarly++;
      return {'attempt': next.toJson(), 'duplicate': false};
    }
    if (name == 'save_exam_details') {
      final old = rows.values.singleWhere(
        (a) => a.id == params['p_attempt_id'],
      );
      final patch = params['p_details'] as Map;
      final results = {for (final r in old.subjectResults) r.subjectId: r};
      for (final raw in (params['p_subject_results'] as List? ?? [])) {
        final r = ExamSubjectResult.fromJson(raw)!;
        results[r.subjectId] = r;
      }
      final raw = {
        ...old.toJson(),
        ...patch,
        'subject_results':
            (results.values.toList()
                  ..sort((a, b) => a.subjectId.compareTo(b.subjectId)))
                .map((r) => r.toJson())
                .toList(),
      };
      final candidate = ExamAttempt.fromJson(raw)!;
      final same =
          candidate.title == old.title &&
          candidate.note == old.note &&
          jsonEncode(candidate.selectedModuleIds) ==
              jsonEncode(old.selectedModuleIds) &&
          jsonEncode(
                candidate.subjectResults.map((r) => r.toJson()).toList(),
              ) ==
              jsonEncode(
                (old.subjectResults.toList()
                      ..sort((a, b) => a.subjectId.compareTo(b.subjectId)))
                    .map((r) => r.toJson())
                    .toList(),
              );
      if (same) return {'attempt': old.toJson(), 'duplicate': true};
      if (params['p_expected_revision'] != old.detailsRevision) {
        throw const ExamFailure('exam_details_conflict');
      }
      final next = ExamAttempt.fromJson({
        ...candidate.toJson(),
        'details_revision': old.detailsRevision + 1,
      })!;
      rows[old.clientUuid] = next;
      savedDetails++;
      return {'attempt': next.toJson(), 'duplicate': false};
    }
    return super.defaultRpc(name, params);
  }
}

ExamAttempt detailsCompletedAttempt({
  String id = 'ayt',
  int seconds = 5400,
  int revision = 0,
  String? title,
  String? note,
  List<String>? modules,
  List<ExamSubjectResult> results = const [],
}) {
  final def = offlineExamCatalog.byId(id)!;
  final start = DateTime.utc(2026, 10, 27, 7);
  return ExamAttempt.fromJson({
    'id': 'completed-$id',
    'client_uuid': 'uuid-$id',
    'exam_id': id,
    'status': 'completed',
    'started_at': start.toIso8601String(),
    'ends_at': start
        .add(Duration(seconds: def.durationSeconds))
        .toIso8601String(),
    'completed_at': start.add(Duration(seconds: seconds)).toIso8601String(),
    'duration_seconds': seconds,
    'planned_duration_seconds': def.durationSeconds,
    'elapsed_seconds': seconds,
    'credited_minutes': seconds ~/ 60,
    'completion_kind': seconds < def.durationSeconds ? 'early' : 'full',
    'total_questions': def.totalQuestions,
    'definition': def.toJson(),
    'details_revision': revision,
    'title': title,
    'note': note,
    'selected_module_ids': modules,
    'points_earned': seconds ~/ 300,
    'exam_coins_earned': def.fullRewardCoins * seconds ~/ def.durationSeconds,
    'subject_results': results.map((r) => r.toJson()).toList(),
  })!;
}
