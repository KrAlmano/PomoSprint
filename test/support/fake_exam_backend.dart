import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/services/exam_service.dart';

class FakeExamBackend implements ExamBackend {
  final ValueNotifier<String?> owner = ValueNotifier('owner-1');
  @override
  String? get ownerId => owner.value;
  @override
  Listenable get ownerChanges => owner;
  @override
  bool isAvailable = true;
  DateTime clock = DateTime.utc(2026, 10, 27, 12);
  @override
  DateTime now() => clock;
  bool featureAvailable = true;
  int completions = 0;
  int profileRefreshes = 0;
  final calls = <(String, Map<String, dynamic>)>[];
  final rows = <String, ExamAttempt>{};
  Future<Object?> Function(String, Map<String, dynamic>)? handler;
  @override
  Future<void> didComplete() async {
    profileRefreshes++;
  }

  @override
  Future<Object?> rpc(String name, Map<String, dynamic> params, {
    required String expectedOwnerId,
  }) async {
    if (ownerId != expectedOwnerId) throw const ExamFailure('owner_changed');
    calls.add((name, params));
    if (handler != null) return handler!(name, params);
    return defaultRpc(name, params);
  }

  Object? defaultRpc(String name, Map<String, dynamic> params) {
    if (!isAvailable) throw const ExamFailure('connection');
    if (name == 'get_my_exam_attempts_v2') {
      throw const PostgrestException(message: 'missing', code: 'PGRST202');
    }
    if (name == 'get_exam_config') {
      return {
        'schema_version': 1,
        'available': featureAvailable,
        'server_time': clock.toIso8601String(),
        'exams': offlineExamCatalog.exams.map((e) => e.toJson()).toList(),
      };
    }
    if (name == 'get_my_exam_attempts') {
      return {
        'server_time': clock.toIso8601String(),
        'attempts': rows.values.map((a) => a.toJson()).toList(),
      };
    }
    if (name == 'get_my_exam_league_ranking') {
      return {'scope': params['p_scope'], 'rows': [], 'exam_coins': 0};
    }
    if (name == 'start_exam_attempt') {
      final uuid = params['p_client_uuid'] as String;
      final old = rows[uuid];
      if (old != null) return {'attempt': old.toJson(), 'duplicate': true};
      final exam = offlineExamCatalog.byId(params['p_exam_id'] as String)!;
      final attempt = ExamAttempt(
        id: 'attempt-$uuid',
        clientUuid: uuid,
        examId: exam.id,
        startedAt: clock,
        endsAt: clock.add(Duration(seconds: exam.durationSeconds)),
        durationSeconds: exam.durationSeconds,
        totalQuestions: exam.totalQuestions,
        status: ExamAttemptStatus.active,
        definition: exam,
      );
      rows[uuid] = attempt;
      return {'attempt': attempt.toJson(), 'duplicate': false};
    }
    final old = rows.values.firstWhere((a) => a.id == params['p_attempt_id']);
    if (name == 'complete_exam_attempt' && clock.isBefore(old.endsAt)) {
      throw const ExamFailure('exam_not_elapsed');
    }
    if (name == 'save_exam_results') {
      final results = (params['p_subject_results'] as List)
          .map(ExamSubjectResult.fromJson)
          .cast<ExamSubjectResult>()
          .toList();
      final next = ExamAttempt.fromJson({
        ...old.toJson(),
        'subject_results': results.map((r) => r.toJson()).toList(),
      })!;
      rows[old.clientUuid] = next;
      return {'attempt': next.toJson()};
    }
    final completed =
        name == 'complete_exam_attempt' || !clock.isBefore(old.endsAt);
    if (old.status == ExamAttemptStatus.active && completed) completions++;
    final next = old.status != ExamAttemptStatus.active
        ? old
        : ExamAttempt.fromJson({
            ...old.toJson(),
            'status': completed ? 'completed' : 'abandoned',
            'completed_at': clock.toIso8601String(),
            'points_earned': completed ? 33 : 0,
            'exam_coins_earned': completed ? 6 : 0,
          })!;
    rows[old.clientUuid] = next;
    return {'attempt': next.toJson()};
  }
}
