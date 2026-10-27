import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/exam_catalog_defaults.dart';
import '../models/exam_model.dart';
import '../utils/async_lock.dart';
import 'exam_persistence.dart';
import 'server_clock.dart';
import 'supabase_service.dart';

abstract interface class ExamBackend {
  String? get ownerId;
  Listenable get ownerChanges;
  bool get isAvailable;
  DateTime now();
  Future<Object?> rpc(String name, Map<String, dynamic> params);
  Future<void> didComplete();
}

class SupabaseExamBackend implements ExamBackend {
  SupabaseService get _service => SupabaseService.instance;
  @override
  String? get ownerId => _service.currentUser.value?.id;
  @override
  Listenable get ownerChanges => _service.currentUser;
  @override
  bool get isAvailable =>
      _service.isCloudActive &&
      !_service.isDeviceSessionEnding &&
      ownerId != null &&
      Supabase.instance.client.auth.currentUser?.id == ownerId;
  @override
  DateTime now() =>
      DateTime.now().add(ServerClock.correctionFor(_service.serverClockOffset));
  @override
  Future<Object?> rpc(String name, Map<String, dynamic> params) {
    if (!isAvailable) throw const ExamFailure('unavailable');
    return Supabase.instance.client
        .rpc(name, params: params)
        .timeout(const Duration(seconds: 20));
  }

  @override
  Future<void> didComplete() async {
    await _service.fetchCurrentUserModel();
    _service.notifyConnectionRestored();
  }
}

class ExamFailure implements Exception {
  const ExamFailure(this.code);
  final String code;
  @override
  String toString() => 'ExamFailure($code)';
}

/// Separate from Pomodoro's queue: server-created, unpausable attempts only.
/// Client timestamps are presentation data and never purchase points or time.
class ExamService extends ChangeNotifier {
  ExamService({
    required this.backend,
    ExamPersistence? persistence,
    String Function()? createUuid,
  }) : persistence = persistence ?? ExamPersistence(),
       _createUuid = createUuid ?? const Uuid().v4 {
    backend.ownerChanges.addListener(_onOwnerChanged);
  }
  static final ExamService instance = ExamService(
    backend: SupabaseExamBackend(),
  );
  final ExamBackend backend;
  final ExamPersistence persistence;
  final String Function() _createUuid;
  final AsyncLock _lock = AsyncLock();
  final ValueNotifier<bool> blocksOtherSessions = ValueNotifier(false);
  String? _owner;
  int _epoch = 0;
  bool _disposed = false;
  bool _initialized = false;
  bool _foreground = true;
  bool _refreshing = false;
  bool _historyLoaded = false;
  bool _historyKnownUnavailable = false;
  bool _historyRefreshFailed = false;
  Timer? _timer;
  int _ticks = 0;
  ExamCatalog _catalog = offlineExamCatalog;
  List<ExamLocalRecord> _records = [];
  List<ExamAttempt> _remote = [];
  String? errorCode;
  bool busy = false;
  ExamCatalog get catalog => _catalog;
  List<ExamLocalRecord> get records => List.unmodifiable(_records);
  DateTime now() => backend.now();

  /// Cached attempts remain useful after a failed refresh, but callers must
  /// not present an incomplete first read as a verified zero exam subtotal.
  /// A deliberately disabled feature or missing legacy RPC is not an outage.
  bool get historyIsStale =>
      _owner != null &&
      !_historyKnownUnavailable &&
      (!_historyLoaded ||
          _historyRefreshFailed ||
          errorCode == 'journal_invalid');

  List<ExamAttempt> get attempts {
    final byUuid = {for (final a in _remote) a.clientUuid: a};
    for (final r in _records) {
      final a = r.attempt;
      if (a == null) continue;
      final remote = byUuid[a.clientUuid];
      // A fresh terminal server row supersedes an old active cache.
      if (remote == null ||
          remote.status == ExamAttemptStatus.active ||
          r.pendingAction == ExamPendingAction.results) {
        byUuid[a.clientUuid] = a;
      }
    }
    return byUuid.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  ExamLocalRecord? get activeRecord => _records
      .where(
        (r) =>
            r.pendingAction == ExamPendingAction.start ||
            r.pendingAction == ExamPendingAction.abandon ||
            r.pendingAction == ExamPendingAction.complete ||
            r.attempt?.status == ExamAttemptStatus.active,
      )
      .firstOrNull;
  ExamDefinition? definitionFor(ExamAttempt attempt) =>
      attempt.definition ??
      _records
          .where((r) => r.clientUuid == attempt.clientUuid)
          .firstOrNull
          ?.definition ??
      _catalog.byId(attempt.examId) ??
      offlineExamCatalog.byId(attempt.examId);

  Future<void> initialize() async {
    if (_initialized && _owner == backend.ownerId) return;
    _initialized = true;
    await _switchOwner();
  }

  void _onOwnerChanged() {
    if (_owner != backend.ownerId) unawaited(_switchOwner());
  }

  Future<void> _switchOwner() async {
    final epoch = ++_epoch;
    _owner = backend.ownerId;
    _timer?.cancel();
    _timer = null;
    _records = [];
    _remote = [];
    errorCode = null;
    _catalog = offlineExamCatalog;
    busy = false;
    _refreshing = false;
    _historyLoaded = false;
    _historyKnownUnavailable = false;
    _historyRefreshFailed = false;
    _emit();
    final owner = _owner;
    if (owner == null) return;
    try {
      final rows = await persistence.read(owner);
      if (!_current(owner, epoch)) return;
      _records = rows;
    } catch (_) {
      if (_current(owner, epoch)) errorCode = 'journal_invalid';
    }
    if (!_current(owner, epoch)) return;
    _emit();
    _scheduleTimer();
    await refresh();
  }

  bool _current(String owner, int epoch) =>
      !_disposed &&
      _owner == owner &&
      backend.ownerId == owner &&
      _epoch == epoch;
  void setForeground(bool value) {
    _foreground = value;
    if (!value) {
      _timer?.cancel();
      _timer = null;
    } else {
      _scheduleTimer();
      unawaited(refresh());
    }
  }

  void _scheduleTimer() {
    if (!_records.any(
      (r) =>
          r.pendingAction != null ||
          r.attempt?.status == ExamAttemptStatus.active,
    )) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_disposed || !_foreground || _owner == null || _timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (activeRecord != null) {
        _emit();
        final a = activeRecord?.attempt;
        if (a != null &&
            a.status == ExamAttemptStatus.active &&
            a.remainingSecondsAt(now()) == 0 &&
            activeRecord?.pendingAction == null &&
            !busy) {
          unawaited(
            complete(a.clientUuid).catchError((Object error) {
              if (!_disposed) {
                errorCode = _errorCode(error);
                _emit();
              }
            }),
          );
        }
      }
      if (++_ticks % 30 == 0 && _records.any((r) => r.pendingAction != null)) {
        unawaited(sync());
      }
    });
  }

  void _emit() {
    if (_disposed) return;
    final active = activeRecord;
    final blocks =
        errorCode == 'journal_invalid' ||
        active != null &&
            (active.pendingAction == ExamPendingAction.start ||
                active.pendingAction == ExamPendingAction.abandon ||
                (active.attempt?.remainingSecondsAt(now()) ?? 0) > 0);
    if (blocksOtherSessions.value != blocks) blocksOtherSessions.value = blocks;
    _scheduleTimer();
    notifyListeners();
  }

  Future<bool> _save(
    String owner,
    int epoch,
    List<ExamLocalRecord> rows,
  ) async {
    if (!_current(owner, epoch) || errorCode == 'journal_invalid') return false;
    final saved = await persistence.write(
      owner,
      rows,
      canCommit: () => _current(owner, epoch),
    );
    if (saved && _current(owner, epoch)) {
      _records = rows;
      _emit();
      return true;
    }
    return false;
  }

  Future<void> refresh() async {
    if (!_initialized) {
      await initialize();
      return;
    }
    final owner = _owner, epoch = _epoch;
    if (owner == null || _refreshing) return;
    if (!backend.isAvailable) {
      _historyRefreshFailed = true;
      _emit();
      return;
    }
    _refreshing = true;
    try {
      final raw = await backend.rpc('get_exam_config', {});
      if (!_current(owner, epoch)) return;
      final catalog = ExamCatalog.fromJson(raw);
      _catalog = catalog ?? offlineExamCatalog;
      if (catalog == null) {
        errorCode = 'invalid_catalog';
        _historyRefreshFailed = true;
        _historyKnownUnavailable = false;
        return;
      }
      if (!_catalog.available) {
        _historyKnownUnavailable = true;
        _historyRefreshFailed = false;
        return;
      }
      _historyKnownUnavailable = false;
      await sync();
      if (!_current(owner, epoch)) return;
      final localAtRequest = {for (final row in _records) row.clientUuid: row};
      final fetched = <ExamAttempt>[];
      final cursors = <String>{};
      String? cursor;
      do {
        final history = await backend.rpc('get_my_exam_attempts', {
          'p_limit': 100,
          'p_before': ?cursor,
        });
        if (!_current(owner, epoch)) return;
        if (history is! Map || history['attempts'] is! List) {
          throw const ExamFailure('invalid_response');
        }
        final parsed = (history['attempts'] as List)
            .map(ExamAttempt.fromJson)
            .toList();
        if (parsed.any((a) => a == null)) {
          throw const ExamFailure('invalid_response');
        }
        fetched.addAll(parsed.cast<ExamAttempt>());
        cursor = history['next_cursor'] as String?;
        if (cursor != null && !cursors.add(cursor)) {
          throw const ExamFailure('invalid_response');
        }
      } while (cursor != null);
      // A terminal/net mutation may be committing to native storage while
      // the history request returns. Merge only after that operation commits,
      // then keep the same lock through our own journal write. The network
      // read remains outside the lock so it cannot block an offline action.
      await _lock.synchronized(() async {
        if (!_current(owner, epoch)) return;
        _remote = fetched.map((incoming) {
          final local = _records
              .where((r) => r.clientUuid == incoming.clientUuid)
              .firstOrNull;
          final saved = local?.attempt;
          if (saved != null &&
              (local != localAtRequest[incoming.clientUuid] ||
                  (saved.status != ExamAttemptStatus.active &&
                      incoming.status != saved.status))) {
            return saved;
          }
          return incoming;
        }).toList();
        var rows = List<ExamLocalRecord>.of(_records);
        for (final a in _remote) {
          final i = rows.indexWhere((r) => r.clientUuid == a.clientUuid);
          final definition = definitionFor(a);
          if (definition == null) continue;
          if (i < 0) {
            rows.add(
              ExamLocalRecord(
                clientUuid: a.clientUuid,
                definition: definition,
                createdAt: a.startedAt,
                attempt: a.withDefinition(definition),
              ),
            );
          } else if (i >= 0 && rows[i].pendingAction == null) {
            rows[i] = rows[i].copy(attempt: a.withDefinition(definition));
          }
        }
        await _save(owner, epoch, rows);
        if (_current(owner, epoch)) {
          _historyLoaded = true;
          _historyRefreshFailed = false;
          if (errorCode != 'journal_invalid') errorCode = null;
        }
      });
    } catch (error) {
      if (_current(owner, epoch)) {
        if (error is PostgrestException && error.code == 'PGRST202') {
          _catalog = offlineExamCatalog;
          _historyKnownUnavailable = true;
          _historyRefreshFailed = false;
        } else {
          errorCode = _errorCode(error);
          _historyKnownUnavailable = false;
          _historyRefreshFailed = true;
        }
      }
    } finally {
      if (_current(owner, epoch)) {
        _refreshing = false;
        _emit();
      }
    }
  }

  Future<void> start(ExamDefinition exam) => _lock.synchronized(() async {
    final owner = _owner, epoch = _epoch;
    if (owner == null ||
        !_catalog.available ||
        !backend.isAvailable ||
        activeRecord != null ||
        busy) {
      throw const ExamFailure('exam_overlap');
    }
    final definition = _catalog.byId(exam.id);
    if (definition == null) throw const ExamFailure('invalid_catalog');
    final row = ExamLocalRecord(
      clientUuid: _createUuid(),
      definition: definition,
      createdAt: now(),
      pendingAction: ExamPendingAction.start,
    );
    if (!await _save(owner, epoch, [..._records, row])) {
      throw const ExamFailure('storage');
    }
    await _send(owner, epoch, row);
  });
  Future<void> complete(String uuid) =>
      _transition(uuid, ExamPendingAction.complete);
  Future<void> abandon(String uuid) =>
      _transition(uuid, ExamPendingAction.abandon);
  Future<void> _transition(
    String uuid,
    ExamPendingAction action,
  ) => _lock.synchronized(() async {
    final owner = _owner, epoch = _epoch;
    if (owner == null) return;
    final row = _records.where((r) => r.clientUuid == uuid).firstOrNull;
    if (row == null ||
        row.attempt == null ||
        row.attempt!.status != ExamAttemptStatus.active) {
      return;
    }
    // A requested abandon is never replaced by a later automatic completion.
    if (row.pendingAction == ExamPendingAction.abandon &&
        action != ExamPendingAction.abandon) {
      return;
    }
    if (action == ExamPendingAction.complete &&
        row.attempt!.remainingSecondsAt(now()) > 0) {
      return;
    }
    final next = row.copy(action: action);
    if (await _replace(owner, epoch, next)) await _send(owner, epoch, next);
  });
  Future<void> saveResults(
    ExamAttempt attempt,
    List<ExamSubjectResult> results,
  ) => _lock.synchronized(() async {
    final owner = _owner, epoch = _epoch;
    // A DTO retained by a route from a previous account is not authority to
    // create a new journal row. Resolve only from this owner's current cache.
    final owned = attempts
        .where(
          (a) =>
              a.id == attempt.id &&
              a.clientUuid == attempt.clientUuid &&
              a.examId == attempt.examId &&
              a.catalogVersion == attempt.catalogVersion,
        )
        .firstOrNull;
    final definition = owned == null ? null : definitionFor(owned);
    if (owner == null ||
        !_current(owner, epoch) ||
        owned == null ||
        !owned.isCompleted ||
        definition == null ||
        results.length != definition.subjects.length ||
        results.map((r) => r.subjectId).toSet().length != results.length ||
        !definition.subjects.every(
          (s) => results.any((r) => r.isValidFor(s)),
        )) {
      throw const ExamFailure('exam_result_invalid');
    }
    final prior =
        _records
            .where(
              (r) =>
                  r.clientUuid == owned.clientUuid && r.attempt?.id == owned.id,
            )
            .firstOrNull ??
        ExamLocalRecord(
          clientUuid: owned.clientUuid,
          definition: definition,
          createdAt: owned.startedAt,
          attempt: owned,
        );
    final next = prior.copy(
      attempt: owned,
      action: ExamPendingAction.results,
      results: results,
    );
    if (!await _replace(owner, epoch, next)) throw const ExamFailure('storage');
    await _send(owner, epoch, next);
  });
  Future<bool> _replace(String owner, int epoch, ExamLocalRecord row) {
    final rows = List<ExamLocalRecord>.of(_records);
    final i = rows.indexWhere((r) => r.clientUuid == row.clientUuid);
    if (i < 0) {
      rows.add(row);
    } else {
      rows[i] = row;
    }
    return _save(owner, epoch, rows);
  }

  Future<void> sync() => _lock.synchronized(() async {
    final owner = _owner, epoch = _epoch;
    if (owner == null ||
        !backend.isAvailable ||
        errorCode == 'journal_invalid') {
      return;
    }
    for (final row in List<ExamLocalRecord>.of(_records)) {
      if (!_current(owner, epoch)) return;
      if (row.pendingAction != null) await _send(owner, epoch, row);
    }
  });
  Future<void> retry(String uuid) => _lock.synchronized(() async {
    final owner = _owner, epoch = _epoch;
    final row = _records.where((r) => r.clientUuid == uuid).firstOrNull;
    if (owner != null && row != null && row.pendingAction != null) {
      await _send(owner, epoch, row);
    }
  });
  Future<void> _send(String owner, int epoch, ExamLocalRecord row) async {
    if (!_current(owner, epoch) ||
        !backend.isAvailable ||
        row.pendingAction == null) {
      return;
    }
    busy = true;
    _emit();
    try {
      final action = row.pendingAction!;
      final (name, params) = switch (action) {
        ExamPendingAction.start => (
          'start_exam_attempt',
          <String, dynamic>{
            'p_client_uuid': row.clientUuid,
            'p_exam_id': row.definition.id,
          },
        ),
        ExamPendingAction.complete => (
          'complete_exam_attempt',
          <String, dynamic>{'p_attempt_id': row.attempt!.id},
        ),
        ExamPendingAction.abandon => (
          'abandon_exam_attempt',
          <String, dynamic>{'p_attempt_id': row.attempt!.id},
        ),
        ExamPendingAction.results => (
          'save_exam_results',
          <String, dynamic>{
            'p_attempt_id': row.attempt!.id,
            'p_subject_results': row.pendingResults!
                .map((r) => r.toJson())
                .toList(),
          },
        ),
      };
      final raw = await backend.rpc(name, params);
      if (!_current(owner, epoch)) return;
      final attempt = ExamAttempt.fromJson(raw is Map ? raw['attempt'] : null);
      if (attempt == null ||
          attempt.clientUuid != row.clientUuid ||
          attempt.examId != row.definition.id ||
          (row.attempt != null && row.attempt!.id != attempt.id) ||
          (action == ExamPendingAction.complete && !attempt.isCompleted) ||
          (action == ExamPendingAction.abandon &&
              attempt.status == ExamAttemptStatus.active) ||
          (action == ExamPendingAction.results && !attempt.isCompleted)) {
        throw const ExamFailure('invalid_response');
      }
      final committed = await _replace(
        owner,
        epoch,
        row.copy(attempt: attempt.withDefinition(row.definition)),
      );
      if (committed && _current(owner, epoch)) {
        // The history cache may contain an older completed row. Publishing a
        // successful result edit must not keep showing that stale snapshot
        // until the next network refresh.
        _remote = [
          for (final cached in _remote)
            cached.clientUuid == attempt.clientUuid
                ? attempt.withDefinition(row.definition)
                : cached,
        ];
      }
      if (attempt.isCompleted &&
          action != ExamPendingAction.results &&
          _current(owner, epoch)) {
        // The complete RPC has already committed. A profile refresh failure
        // must not resurrect a completed queue entry or duplicate its reward.
        try {
          await backend.didComplete();
        } catch (_) {
          /* next refresh retries */
        }
      }
      if (_current(owner, epoch)) errorCode = null;
    } catch (error) {
      if (!_current(owner, epoch)) return;
      final code = _errorCode(error);
      final definitiveStartFailure =
          row.pendingAction == ExamPendingAction.start &&
          {
            'exam_overlap',
            'exam_not_found',
            'exam_unavailable',
            'exam_metadata_conflict',
          }.contains(code);
      await _replace(
        owner,
        epoch,
        row.copy(
          action: definitiveStartFailure ? null : row.pendingAction,
          results: row.pendingResults,
          error: code,
        ),
      );
      errorCode = code;
    } finally {
      if (_current(owner, epoch)) {
        busy = false;
        _emit();
      }
    }
  }

  Future<ExamLeagueSnapshot> loadLeague({String scope = 'segment'}) async {
    final owner = _owner, epoch = _epoch;
    if (owner == null || !_catalog.available) return const ExamLeagueSnapshot();
    final response = await backend.rpc('get_my_exam_league_ranking', {
      'p_scope': scope == 'global' ? 'global' : 'segment',
    });
    if (!_current(owner, epoch)) throw const ExamFailure('owner_changed');
    return ExamLeagueSnapshot.fromJson(response);
  }

  static String _errorCode(Object error) {
    if (error is ExamFailure) return error.code;
    if (error is PostgrestException) {
      for (final code in [
        'exam_not_elapsed',
        'exam_not_active',
        'exam_metadata_conflict',
        'exam_result_invalid',
        'exam_overlap',
        'exam_not_found',
        'exam_unavailable',
      ]) {
        if (error.message.contains(code)) return code;
      }
      if (error.code == 'PGRST202') return 'unavailable';
    }
    return 'connection';
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _timer?.cancel();
    backend.ownerChanges.removeListener(_onOwnerChanged);
    blocksOtherSessions.dispose();
    super.dispose();
  }
}
