import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/exam_model.dart';
import '../utils/async_lock.dart';

enum ExamPendingAction { start, complete, abandon, results }

class ExamLocalRecord {
  const ExamLocalRecord({
    required this.clientUuid,
    required this.definition,
    required this.createdAt,
    this.attempt,
    this.pendingAction,
    this.pendingResults,
    this.errorCode,
  });
  final String clientUuid;
  final ExamDefinition definition;
  final DateTime createdAt;
  final ExamAttempt? attempt;
  final ExamPendingAction? pendingAction;
  final List<ExamSubjectResult>? pendingResults;
  final String? errorCode;
  bool get requiresAttention => pendingAction != null || errorCode != null;
  ExamLocalRecord copy({
    ExamAttempt? attempt,
    ExamPendingAction? action,
    List<ExamSubjectResult>? results,
    String? error,
  }) => ExamLocalRecord(
    clientUuid: clientUuid,
    definition: definition,
    createdAt: createdAt,
    attempt: attempt ?? this.attempt,
    pendingAction: action,
    pendingResults: results,
    errorCode: error,
  );
  Map<String, dynamic> toJson() => {
    'client_uuid': clientUuid,
    'definition': definition.toJson(),
    'created_at': createdAt.toUtc().toIso8601String(),
    'attempt': attempt?.toJson(),
    'pending_action': pendingAction?.name,
    'pending_results': pendingResults?.map((r) => r.toJson()).toList(),
    'error_code': errorCode,
  };
  static ExamLocalRecord? fromJson(Object? value) {
    if (value is! Map) return null;
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
    final prefs = await SharedPreferences.getInstance();
    final key = keyFor(uid);
    final previous = prefs.getString(key);
    final bool saved;
    try {
      saved = await prefs.setString(
        key,
        jsonEncode(rows.map((r) => r.toJson()).toList()),
      );
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
