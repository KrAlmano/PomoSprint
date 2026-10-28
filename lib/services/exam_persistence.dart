import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/exam_model.dart';
import '../models/exam_details.dart';
import '../utils/async_lock.dart';

enum ExamPendingAction {
  start,
  complete,
  abandon,
  results,
  completeEarly,
  details,
}

const _keepExamField = Object();

class ExamLocalRecord {
  const ExamLocalRecord({
    required this.clientUuid,
    required this.definition,
    required this.createdAt,
    this.attempt,
    this.pendingAction,
    this.pendingResults,
    this.errorCode,
    this.pendingDetails,
    this.detailsDraft,
  });
  final String clientUuid;
  final ExamDefinition definition;
  final DateTime createdAt;
  final ExamAttempt? attempt;
  final ExamPendingAction? pendingAction;
  final List<ExamSubjectResult>? pendingResults;
  final String? errorCode;
  final ExamDetailsMutation? pendingDetails;
  final ExamDetailsDraft? detailsDraft;
  bool get requiresAttention => pendingAction != null || errorCode != null;
  ExamLocalRecord copy({
    ExamAttempt? attempt,
    ExamPendingAction? action,
    List<ExamSubjectResult>? results,
    String? error,
    ExamDefinition? definition,
    Object? details = _keepExamField,
    Object? draft = _keepExamField,
  }) => ExamLocalRecord(
    clientUuid: clientUuid,
    definition: definition ?? this.definition,
    createdAt: createdAt,
    attempt: attempt ?? this.attempt,
    pendingAction: action,
    pendingResults: results,
    errorCode: error,
    pendingDetails: identical(details, _keepExamField)
        ? pendingDetails
        : details as ExamDetailsMutation?,
    detailsDraft: identical(draft, _keepExamField)
        ? detailsDraft
        : draft as ExamDetailsDraft?,
  );
  Map<String, dynamic> toJson() => {
    'schema_version': 2,
    'client_uuid': clientUuid,
    'definition': definition.toJson(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'attempt': attempt?.toJson(),
    'pending_action': pendingAction?.name,
    'pending_results': pendingResults?.map((r) => r.toJson()).toList(),
    'error_code': errorCode,
    if (pendingDetails != null) 'pending_details': pendingDetails!.toJson(),
    if (detailsDraft != null) 'details_draft': detailsDraft!.toJson(),
  };
  static ExamLocalRecord? fromJson(Object? value) {
    if (value is! Map) return null;
    if (value['schema_version'] != null &&
        value['schema_version'] != 1 &&
        value['schema_version'] != 2) {
      return null;
    }
    final uuid = value['client_uuid']?.toString() ?? '';
    final definition = ExamDefinition.fromJson(value['definition']);
    final date = DateTime.tryParse(value['created_at']?.toString() ?? '');
    if (uuid.isEmpty || definition == null || date == null) return null;
    final rawAction = value['pending_action'];
    final action = ExamPendingAction.values
        .where((a) => a.name == rawAction)
        .firstOrNull;
    if (rawAction != null && action == null) return null;
    final attempt = ExamAttempt.fromJson(value['attempt']);
    if (value['attempt'] != null && attempt == null) return null;
    if (attempt != null &&
        (attempt.clientUuid != uuid || attempt.examId != definition.id)) {
      return null;
    }
    if (action != null &&
        action != ExamPendingAction.start &&
        attempt == null) {
      return null;
    }
    final rawResults = value['pending_results'];
    if (rawResults != null && rawResults is! List) return null;
    final parsedResults = (rawResults as List?)
        ?.map(ExamSubjectResult.fromJson)
        .toList();
    if (parsedResults != null &&
        (parsedResults.any((r) => r == null) ||
            parsedResults.map((r) => r?.subjectId).toSet().length !=
                parsedResults.length)) {
      return null;
    }
    final results = parsedResults?.cast<ExamSubjectResult>();
    final details = ExamDetailsMutation.fromJson(value['pending_details']);
    final draft = ExamDetailsDraft.fromJson(value['details_draft']);
    if ((value['pending_details'] != null && details == null) ||
        (value['details_draft'] != null && draft == null) ||
        (action == ExamPendingAction.details &&
            (details == null || attempt?.isCompleted != true)) ||
        (details != null && action != ExamPendingAction.details)) {
      return null;
    }
    bool modulesValid(List<String> modules, {bool allowEmpty = false}) =>
        definition.id == 'ayt' &&
        (allowEmpty || modules.isNotEmpty) &&
        modules.length <= 4 &&
        modules.toSet().length == modules.length &&
        modules.every(
          (id) => definition.effectiveModules.any((m) => m.id == id),
        );
    if (details != null) {
      final selected = details.patch.values.containsKey('selected_module_ids')
          ? details.patch.values['selected_module_ids'] as List<String>
          : attempt?.selectedModuleIds;
      final allowed = selected == null
          ? definition.subjects.map((s) => s.id).toSet()
          : definition.subjectIdsForModules(selected);
      if ((selected != null && !modulesValid(selected)) ||
          (details.results != null &&
              (details.results!.isEmpty ||
                  !details.results!.every(
                    (r) =>
                        allowed.contains(r.subjectId) &&
                        definition.subjects.any(r.isValidFor),
                  )))) {
        return null;
      }
    }
    if (draft != null &&
        ((draft.modules != null &&
                !modulesValid(draft.modules!, allowEmpty: true)) ||
            !definition.subjects
                .map((s) => s.id)
                .toSet()
                .containsAll(draft.fields.keys) ||
            !draft.fields.keys.toSet().containsAll(draft.dirtySubjects))) {
      return null;
    }
    if (action == ExamPendingAction.results &&
        (results == null ||
            results.isEmpty ||
            results.length > definition.subjects.length ||
            !results.every(
              (result) => definition.subjects.any(result.isValidFor),
            ))) {
      return null;
    }
    return ExamLocalRecord(
      clientUuid: uuid,
      definition: definition,
      createdAt: date,
      attempt: attempt,
      pendingAction: action,
      pendingResults: results == null ? null : List.unmodifiable(results),
      errorCode: value['error_code']?.toString(),
      pendingDetails: details,
      detailsDraft: draft,
    );
  }
}

/// Owner-scoped durable journal. Failed operations stay visible and retryable.
class ExamPersistence {
  final AsyncLock _lock = AsyncLock();
  final Set<String> _retired = {};
  static String keyFor(String uid) => 'exam_journal_uid_$uid';
  Future<List<ExamLocalRecord>> read(
    String uid,
  ) => _lock.synchronized(() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyFor(uid));
    if (raw == null) return [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('exam_journal_invalid');
    }
    if (decoded is! List) throw const FormatException('exam_journal_invalid');
    final rows = decoded.map(ExamLocalRecord.fromJson).toList();
    // Do not silently drop malformed journal rows and overwrite their evidence.
    if (rows.any((r) => r == null)) {
      throw const FormatException('exam_journal_invalid');
    }
    return rows.cast<ExamLocalRecord>();
  });
  Future<bool> write(
    String uid,
    List<ExamLocalRecord> rows, {
    bool Function()? canCommit,
  }) => _lock.synchronized(() async {
    if (_retired.contains(uid) || (canCommit != null && !canCommit())) {
      return false;
    }
    // A locally constructed row must satisfy the same reader as a cold start.
    // Reject before touching storage; never replace a valid journal with data
    // that would make every record for this owner unreadable on restart.
    final serialized = rows.map((r) => r.toJson()).toList();
    if (serialized.any((row) => ExamLocalRecord.fromJson(row) == null)) {
      throw const FormatException('exam_journal_invalid_write');
    }
    final prefs = await SharedPreferences.getInstance();
    final key = keyFor(uid);
    final previous = prefs.getString(key);
    final bool saved;
    try {
      saved = await prefs.setString(key, jsonEncode(serialized));
    } catch (_) {
      // SharedPreferences updates its in-process cache before native I/O.
      // Restore it as well when the platform write fails.
      if (previous == null || _retired.contains(uid)) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, previous);
      }
      rethrow;
    }
    if (!saved ||
        _retired.contains(uid) ||
        (canCommit != null && !canCommit())) {
      if (previous == null || _retired.contains(uid)) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, previous);
      }
      return false;
    }
    return true;
  });
  Future<void> retireOwner(String uid) {
    _retired.add(uid);
    return _lock.synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyFor(uid));
    });
  }
}
