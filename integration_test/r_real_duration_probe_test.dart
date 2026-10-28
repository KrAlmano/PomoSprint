// Two-process REAL duration probe. Start through the actual UI, end the test
// without cleanup, wait with the app process closed, then run mode=resume with
// the SAME E2E_RUN_ID and app installation/data. No timer/catalog/SQL dates are
// changed. Notification delivery is outside this probe (disabled at setup).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/widgets/avatar_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/e2e.dart';

const _mode = String.fromEnvironment('E2E_PROBE_MODE');
const _run = String.fromEnvironment('E2E_RUN_ID');
const _requireCompleted = bool.fromEnvironment('E2E_PROBE_REQUIRE_COMPLETED');
const _catalogExamId = String.fromEnvironment('E2E_PROBE_EXAM_ID');
const _probeLanguage = String.fromEnvironment(
  'E2E_PROBE_LANGUAGE',
  defaultValue: 'tr',
);
const _expectOfflineCompletion = bool.fromEnvironment(
  'E2E_PROBE_EXPECT_OFFLINE_COMPLETION',
);
const _catalogQuestions = <String, int>{
  'tyt': 120,
  'ayt': 160,
  'ydt': 80,
  'lgs_verbal': 50,
  'lgs_quantitative': 40,
  'tus_basic': 100,
  'tus_clinical': 100,
};
const _startModes = {
  'normal25_start',
  'normal50_start',
  'exam_lgs_start',
  'exam_tus_start',
  // A1 lifecycle matrix only. The local catalogue must be an explicitly
  // installed natural 60-second/zero-reward fixture. Never called a real
  // official-duration run; existing LGS75/TUS135 modes remain unchanged.
  'exam_catalog_start',
};
String get _key => 'e2e_real_duration_probe_$_run';

AppLocalizations get _probeText => lookupAppLocalizations(
  Locale(LanguageService.instance.currentLocale.languageCode),
);

Future<void> _catalogLanguage(WidgetTester tester) async {
  await tapOn(
    tester,
    find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(AvatarWidget),
    ),
  );
  await pumpUntil(tester, find.byType(ProfileScreen));
  await tapOn(tester, find.text(_probeLanguage == 'tr' ? 'Türkçe' : 'English'));
  await pumpUntilTrue(
    tester,
    () => LanguageService.instance.currentLocale.languageCode == _probeLanguage,
    reason: 'Real Settings language selection is persisted before OS closure',
  );
  Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
  await pumpUntilGone(tester, find.byType(ProfileScreen));
}

Future<Map<String, dynamic>> _economy(String uid) async => (await E2eHost.row(
  'select p.total_minutes,p.lifetime_points,p.coins,p.current_streak,p.last_study_date,p.timezone,'
  'coalesce(w.coins,0) as exam_coins,coalesce(w.lifetime_points,0) as exam_points '
  'from public.profiles p left join public.exam_wallets w on w.user_id=p.id '
  'where p.id=${sqlText(uid)}',
))!;

// This checks the persisted attribution rather than merely comparing two
// client labels. It does not claim the live run crossed a day/month boundary.
Future<void> _attribution(
  String owner,
  String sourceId,
  String kind,
  int minutes,
  int points,
  DateTime expectedCompletedAt,
) async {
  final rows = await E2eHost.rows(
    'select e.completed_at,e.period_month::text,e.study_day::text,e.points,e.minutes,'
    'date_trunc(\'month\',e.completed_at at time zone \'Europe/Istanbul\')::date::text as expected_month,'
    '((s.started_at at time zone p.timezone)-interval \'4 hours\')::date::text as expected_study_day,'
    'p.current_streak,p.last_study_date::text '
    'from public.competition_events e join public.profiles p on p.id=e.user_id '
    'join public.${kind == 'study' ? 'study_sessions' : 'exam_attempts'} s on s.id=e.source_id '
    'where e.user_id=${sqlText(owner)} and e.kind=${sqlText(kind)} and e.source_id=${sqlText(sourceId)}',
  );
  expect(
    rows,
    hasLength(1),
    reason: 'one source creates exactly one monthly event',
  );
  final event = rows.single;
  expect(DateTime.parse(event['completed_at'] as String), expectedCompletedAt);
  expect(event['period_month'], event['expected_month']);
  expect(event['study_day'], event['expected_study_day']);
  expect(event['last_study_date'], event['expected_study_day']);
  expect(
    event['current_streak'],
    1,
    reason: 'a fresh account has one completed study day',
  );
  expect(event['minutes'], minutes);
  expect(event['points'], points);
}

Future<void> _tab(WidgetTester tester, int index) async {
  if (find.byType(NavigationBar).evaluate().isNotEmpty) {
    await openTab(tester, index);
  } else {
    tester
        .widget<NavigationRail>(find.byType(NavigationRail))
        .onDestinationSelected!(index);
    await pumpFor(tester, const Duration(milliseconds: 500));
  }
}

Future<void> _start(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  expect(
    prefs.containsKey(_key),
    isFalse,
    reason: 'Existing probe must be resumed, not overwritten',
  );
  // Starting a new probe uses the shared reset helper. Refuse to clear any
  // other owner's unfinished lifecycle marker, timer or durable outbox.
  for (final key in prefs.getKeys()) {
    if (key.startsWith('e2e_real_duration_probe_') ||
        key.startsWith('e2e_normal_http_restart_') ||
        key.startsWith('e2e_marathon_process_probe_') ||
        key.startsWith('e2e_first_use_real25_')) {
      final value = jsonDecode(prefs.getString(key)!) as Map;
      expect(
        value['completion_verified'],
        isTrue,
        reason: 'Preserve unfinished lifecycle probe $key',
      );
    }
    expect(
      key.startsWith('active_session_uid_'),
      isFalse,
      reason: 'Do not clear an existing focus or Marathon timer',
    );
    if (key.startsWith('pending_sessions_')) {
      expect(
        jsonDecode(prefs.getString(key)!),
        isEmpty,
        reason: 'Do not clear another owner’s pending study outbox',
      );
    }
    if (key.startsWith('exam_journal_uid_')) {
      final records = jsonDecode(prefs.getString(key)!) as List;
      for (final raw in records) {
        final record = ExamLocalRecord.fromJson(raw);
        expect(record, isNotNull);
        expect(
          record!.pendingAction,
          isNull,
          reason: 'Do not clear a pending exam action',
        );
        expect(
          record.attempt?.status,
          isNot(ExamAttemptStatus.active),
          reason: 'Do not clear an existing active exam',
        );
      }
    }
  }
  final account = await openShellWithNewAccount(
    tester,
    'probe-${_mode.replaceAll('_', '-')}',
    name: 'QA Real Duration',
  );
  await NotificationService.instance.setEnabled(false);
  if (_mode == 'exam_catalog_start') {
    expect(_catalogQuestions, contains(_catalogExamId));
    expect({'tr', 'en'}, contains(_probeLanguage));
    await _catalogLanguage(tester);
  }
  final baseline = await _economy(account.id);
  expect(baseline['total_minutes'], 0);
  expect(baseline['lifetime_points'], 0);
  expect(baseline['exam_points'], 0);
  expect(baseline['current_streak'], 0);
  final Map<String, dynamic> proof = {
    'run_id': _run,
    'mode': _mode,
    'owner_id': account.id,
    'email': account.email,
    'baseline': baseline,
    'scope': 'real UI start, untouched wall-clock duration',
    'notification_delivery_tested': false,
  };
  if (_mode.startsWith('normal')) {
    final minutes = _mode == 'normal25_start' ? 25 : 50;
    if (minutes == 50) {
      await tapOn(tester, find.text('50 ${tr('minutes_unit_short')}'));
    }
    await tapOn(tester, find.widgetWithText(ElevatedButton, tr('btn_start')));
    ActiveTimerSession? saved;
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      saved = await TimerPersistence.instance.load(account.id);
      if (saved != null && saved.isRunning) break;
    }
    expect(
      saved,
      isNotNull,
      reason: 'UI start must persist a real running timer',
    );
    expect(saved!.isQuickTest, isFalse);
    expect(saved.totalSeconds, minutes * 60);
    expect(saved.endsAt!.difference(saved.startedAt).inSeconds, minutes * 60);
    final reservation = await E2eHost.row(
      'select active_session_ends_at from public.profiles where id=${sqlText(account.id)}',
    );
    expect(reservation!['active_session_ends_at'], isNotNull);
    final remoteEnd = DateTime.parse(
      reservation['active_session_ends_at'] as String,
    );
    expect(
      remoteEnd.difference(saved.endsAt!).inSeconds.abs(),
      lessThanOrEqualTo(5),
    );
    proof.addAll({
      'client_uuid': saved.clientUuid,
      'category_id': saved.categoryId,
      'duration_seconds': saved.totalSeconds,
      'started_at': saved.startedAt.toUtc().toIso8601String(),
      'ends_at': saved.endsAt!.toUtc().toIso8601String(),
      'remaining_at_start': saved.remainingSecondsAt(DateTime.now()),
      'clock_offset_at_start_ms':
          SupabaseService.instance.serverClockOffset?.inMilliseconds,
    });
  } else {
    final exams = ExamService.instance;
    await _tab(tester, 4);
    await pumpUntilTrue(
      tester,
      () => exams.catalog.available,
      reason: 'standard server exam catalog',
    );
    final catalogProbe = _mode == 'exam_catalog_start';
    final id = catalogProbe
        ? _catalogExamId
        : _mode == 'exam_lgs_start'
        ? 'lgs_verbal'
        : 'tus_basic';
    final duration = catalogProbe
        ? 60
        : id == 'lgs_verbal'
        ? 4500
        : 8100;
    final definition = exams.catalog.byId(id);
    expect(definition, isNotNull);
    expect(definition!.durationSeconds, duration);
    if (catalogProbe) {
      expect(definition.totalQuestions, _catalogQuestions[id]);
      proof['scope'] =
          'SHORT local-catalog natural60 lifecycle, NOT official duration';
      proof['exam_id'] = id;
      proof['language'] = _probeLanguage;
      proof['total_questions'] = definition.totalQuestions;
    }
    await tapOn(tester, find.byKey(ValueKey('exam-start-$id')));
    await pumpUntil(tester, find.text(_probeText.examRulesTitle));
    await tapOn(
      tester,
      find.widgetWithText(FilledButton, _probeText.examReady),
    );
    await pumpUntilTrue(
      tester,
      () => exams.activeRecord?.attempt != null,
      reason: 'server-created exam start',
    );
    final attempt = exams.activeRecord!.attempt!;
    expect(attempt.examId, id);
    expect(attempt.durationSeconds, duration);
    expect(attempt.endsAt.difference(attempt.startedAt).inSeconds, duration);
    final disk = await ExamPersistence().read(account.id);
    expect(disk.single.attempt!.id, attempt.id);
    expect(disk.single.pendingAction, isNull);
    final row = await E2eHost.row(
      'select status,started_at,ends_at,definition from public.exam_attempts where id=${sqlText(attempt.id)} and user_id=${sqlText(account.id)}',
    );
    expect(row!['status'], 'active');
    expect(DateTime.parse(row['started_at'] as String), attempt.startedAt);
    if (catalogProbe) {
      final snapshot = Map<String, dynamic>.from(row['definition'] as Map);
      expect(snapshot['duration_seconds'], 60);
      expect(snapshot['reward_points'], 0);
      expect(snapshot['reward_coins'], 0);
      proof['definition_snapshot'] = snapshot;
      proof['expected_points'] = snapshot['reward_points'];
      proof['expected_coins'] = snapshot['reward_coins'];
      expect(find.text(_probeText.examNoPause), findsOneWidget);
    }
    proof.addAll({
      'client_uuid': attempt.clientUuid,
      'attempt_id': attempt.id,
      'duration_seconds': duration,
      'started_at': attempt.startedAt.toUtc().toIso8601String(),
      'ends_at': attempt.endsAt.toUtc().toIso8601String(),
      'remaining_at_start': attempt.remainingSecondsAt(exams.now()),
    });
  }
  proof['observed_at'] = DateTime.now().toUtc().toIso8601String();
  expect(await prefs.setString(_key, jsonEncode(proof)), isTrue);
  expect(tester.takeException(), isNull);
  await E2eHost.screenshot(
    tester,
    _mode == 'exam_catalog_start'
        ? 'e2e-r-catalog-${_catalogExamId.replaceAll('_', '-')}-$_probeLanguage-start'
        : 'e2e-real-probe-${_mode.replaceAll('_', '-')}',
  );
  debugPrint('[REAL_PROBE_START] ${jsonEncode(proof)}');
  // Intentionally no resetAppState / signOut / timer clear / account cleanup.
}

Future<void> _resume(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  expect(
    raw,
    isNotNull,
    reason: 'Probe marker/app data lost; this is not a valid resume',
  );
  final proof = Map<String, dynamic>.from(jsonDecode(raw!) as Map);
  expect(proof['run_id'], _run);
  expect(_startModes.contains(proof['mode']), isTrue);
  final owner = proof['owner_id'] as String;
  final uuid = proof['client_uuid'] as String;
  final end = DateTime.parse(proof['ends_at'] as String);
  final started = DateTime.parse(proof['started_at'] as String);
  final duration = proof['duration_seconds'] as int;
  final baseline = Map<String, dynamic>.from(proof['baseline'] as Map);
  final isNormal = (proof['mode'] as String).startsWith('normal');
  final catalogProbe = proof['mode'] == 'exam_catalog_start';
  if (catalogProbe) {
    expect(_catalogQuestions, contains(proof['exam_id']));
    expect({'tr', 'en'}, contains(proof['language']));
    expect(duration, 60);
    expect(proof['expected_points'], 0);
    expect(proof['expected_coins'], 0);
    final disk = await ExamPersistence().read(owner);
    final original = disk.singleWhere((record) => record.clientUuid == uuid);
    expect(original.attempt!.id, proof['attempt_id']);
    expect(original.attempt!.examId, proof['exam_id']);
    expect(original.attempt!.startedAt, started);
    expect(original.attempt!.endsAt, end);
    expect(original.definition.totalQuestions, proof['total_questions']);
  }
  if (isNormal && proof['completion_verified'] != true) {
    final persisted = await TimerPersistence.instance.load(owner);
    expect(
      persisted,
      isNotNull,
      reason: 'The original timer must survive process closure',
    );
    expect(persisted!.clientUuid, uuid);
    expect(persisted.startedAt.toUtc(), started);
    expect(persisted.endsAt!.toUtc(), end);
  }
  await launchApp(tester); // Only app launch: keep persisted auth and sessions.
  await pumpUntil(
    tester,
    find.byType(MainNavigationShell),
    timeout: const Duration(seconds: 50),
    reason: 'same persisted auth owner',
  );
  expect(SupabaseService.instance.currentUser.value?.id, owner);
  expect(Supabase.instance.client.auth.currentUser?.id, owner);
  if (catalogProbe) {
    expect(
      LanguageService.instance.currentLocale.languageCode,
      proof['language'],
      reason: 'The selected language survives real OS process closure',
    );
  }
  final account = ApiAccount(
    owner,
    proof['email'] as String,
    Supabase.instance.client.auth.currentSession!.accessToken,
  );
  var completed = false;
  if (isNormal) {
    if (DateTime.now().isBefore(end.subtract(const Duration(seconds: 2)))) {
      final saved = await TimerPersistence.instance.load(owner);
      expect(saved, isNotNull);
      expect(saved!.clientUuid, uuid);
      expect(saved.startedAt.toUtc(), started);
      expect(saved.endsAt!.toUtc(), end);
      expect(
        saved.remainingSecondsAt(DateTime.now()),
        lessThan(proof['remaining_at_start'] as int),
      );
      expect(
        await _economy(owner),
        baseline,
        reason: 'unfinished session has no reward',
      );
    } else {
      List<Map<String, dynamic>> rows = [];
      final until = DateTime.now().add(const Duration(seconds: 40));
      while (rows.isEmpty && DateTime.now().isBefore(until)) {
        await pumpFor(tester, const Duration(milliseconds: 250));
        rows = await E2eHost.rows(
          'select id,duration_minutes,base_points,bonus_points,started_at,completed_at from public.study_sessions where user_id=${sqlText(owner)} and client_uuid=${sqlText(uuid)}',
        );
      }
      expect(rows, hasLength(1));
      expect(rows.single['duration_minutes'], duration ~/ 60);
      final expectedPoints = proof['mode'] == 'normal25_start' ? 5 : 12;
      expect(duration, proof['mode'] == 'normal25_start' ? 1500 : 3000);
      expect(rows.single['base_points'], expectedPoints);
      expect(rows.single['bonus_points'], 0);
      // Normal timers persist device-clock dates. The queue converts them to
      // server time with its measured correction, truncated to milliseconds.
      // A restart measures that clock again. The two persisted server dates
      // must have exactly the same correction, within <5 s of the independently
      // measured local-server clock (HTTP Date has one-second precision).
      final correction = Duration(
        milliseconds:
            SupabaseService.instance.serverClockOffset?.inMilliseconds ?? 0,
      );
      final serverStarted = started.add(correction);
      final serverEnded = end.add(correction);
      final savedStarted = DateTime.parse(rows.single['started_at'] as String);
      final savedEnded = DateTime.parse(rows.single['completed_at'] as String);
      expect(
        savedStarted.difference(started),
        savedEnded.difference(end),
        reason:
            'one clock correction preserves both original timestamps and the exact duration',
      );
      expect(
        savedStarted.difference(serverStarted).inMicroseconds.abs(),
        lessThan(5000000),
      );
      expect(
        savedEnded.difference(serverEnded).inMicroseconds.abs(),
        lessThan(5000000),
      );
      proof['completion_clock_offset_ms'] = correction.inMilliseconds;
      proof['expected_server_started_at'] = serverStarted.toIso8601String();
      proof['expected_server_ends_at'] = serverEnded.toIso8601String();
      final beforeDuplicate = await _economy(owner);
      expect(
        beforeDuplicate['total_minutes'],
        (baseline['total_minutes'] as num) + duration ~/ 60,
      );
      expect(
        beforeDuplicate['lifetime_points'],
        (baseline['lifetime_points'] as num) + expectedPoints,
      );
      expect(beforeDuplicate['coins'], (baseline['coins'] as num) + 20);
      expect(beforeDuplicate['exam_points'], baseline['exam_points']);
      expect(beforeDuplicate['exam_coins'], baseline['exam_coins']);
      await _attribution(
        owner,
        rows.single['id'] as String,
        'study',
        duration ~/ 60,
        expectedPoints,
        savedEnded,
      );
      final duplicate =
          await LocalApi.rpc('complete_study_session', account, {
                'p_client_uuid': uuid,
                'p_category_id': proof['category_id'],
                'p_duration_minutes': duration ~/ 60,
                'p_was_paused': false,
                'p_is_verified': 0,
                'p_started_at': proof['started_at'],
              })
              as Map;
      expect(duplicate['duplicate'], isTrue);
      expect(await _economy(owner), beforeDuplicate);
      completed = true;
    }
  } else {
    final exams = ExamService.instance;
    await _tab(tester, 4);
    await pumpUntilTrue(
      tester,
      () => exams.attempts.any((a) => a.clientUuid == uuid),
      reason: 'same server exam restored',
    );
    if (_expectOfflineCompletion) {
      expect(
        catalogProbe,
        isTrue,
        reason: 'Offline short matrix must never replace a real-duration probe',
      );
      expect(
        kSupabaseUrl.endsWith(':54325') ||
            (defaultTargetPlatform == TargetPlatform.android &&
                kSupabaseUrl == 'http://127.0.0.1:54321'),
        isTrue,
        reason:
            'Only the local iOS proxy or selected Android adb reverse is interrupted',
      );
      expect(
        _requireCompleted,
        isFalse,
        reason:
            'Pending offline is intermediate evidence, not accepted completion',
      );
      await pumpUntilTrue(
        tester,
        () => exams.records.any(
          (record) =>
              record.clientUuid == uuid &&
              record.pendingAction == ExamPendingAction.complete &&
              record.attempt?.status == ExamAttemptStatus.active &&
              record.errorCode == 'connection' &&
              !exams.busy,
        ),
        timeout: const Duration(seconds: 45),
        reason:
            'Natural deadline queues completion durably while proxy is offline',
      );
      final disk = await ExamPersistence().read(owner);
      final pending = disk.singleWhere((record) => record.clientUuid == uuid);
      expect(pending.pendingAction, ExamPendingAction.complete);
      expect(
        pending.errorCode,
        'connection',
        reason:
            'The real SDK request failed while the local transport was unavailable',
      );
      expect(pending.attempt!.id, proof['attempt_id']);
      expect(pending.attempt!.startedAt, started);
      expect(pending.attempt!.endsAt, end);
      expect(pending.attempt!.durationSeconds, 60);
      expect(pending.attempt!.totalQuestions, proof['total_questions']);
      expect(await _economy(owner), baseline);
      final server = (await E2eHost.row(
        'select status,points_earned,exam_coins_earned,started_at,ends_at '
        'from public.exam_attempts where id=${sqlText(proof['attempt_id'] as String)} '
        'and user_id=${sqlText(owner)}',
      ))!;
      expect(server['status'], 'active');
      expect(server['points_earned'], 0);
      expect(server['exam_coins_earned'], 0);
      expect(DateTime.parse(server['started_at'] as String), started);
      expect(DateTime.parse(server['ends_at'] as String), end);
      expect(find.text(_probeText.examPending), findsOneWidget);
      expect(find.text(_probeText.examPendingBody), findsOneWidget);
      proof['offline_pending_verified'] = true;
      proof['last_resume_at'] = DateTime.now().toUtc().toIso8601String();
      proof['completion_verified'] = false;
      expect(await prefs.setString(_key, jsonEncode(proof)), isTrue);
      await E2eHost.screenshot(
        tester,
        'e2e-r-catalog-${(proof['exam_id'] as String).replaceAll('_', '-')}-${proof['language']}-offline',
      );
      expect(tester.takeException(), isNull);
      debugPrint('[CATALOG_PROBE_OFFLINE] ${jsonEncode(proof)}');
      return; // Preserve marker/journal for a separate reconnected OS launch.
    }
    if (exams.now().isBefore(end.subtract(const Duration(seconds: 2)))) {
      final attempt = exams.attempts.singleWhere((a) => a.clientUuid == uuid);
      expect(attempt.status, ExamAttemptStatus.active);
      expect(attempt.startedAt, started);
      expect(attempt.endsAt, end);
      expect(
        attempt.remainingSecondsAt(exams.now()),
        lessThan(proof['remaining_at_start'] as int),
      );
      expect(await _economy(owner), baseline);
    } else {
      await pumpUntilTrue(
        tester,
        () => exams.attempts.any((a) => a.clientUuid == uuid && a.isCompleted),
        timeout: const Duration(seconds: 40),
        reason: 'natural exam deadline completes once',
      );
      final attempt = exams.attempts.singleWhere((a) => a.clientUuid == uuid);
      expect(attempt.durationSeconds, duration);
      expect(attempt.startedAt, started);
      expect(attempt.endsAt, end);
      final expectedPoints = catalogProbe
          ? proof['expected_points'] as int
          : proof['mode'] == 'exam_lgs_start'
          ? 15
          : 27;
      final expectedCoins = catalogProbe
          ? proof['expected_coins'] as int
          : proof['mode'] == 'exam_lgs_start'
          ? 3
          : 5;
      expect(
        duration,
        catalogProbe
            ? 60
            : proof['mode'] == 'exam_lgs_start'
            ? 4500
            : 8100,
      );
      if (catalogProbe) {
        expect(attempt.examId, proof['exam_id']);
        expect(attempt.totalQuestions, proof['total_questions']);
      }
      expect(attempt.pointsEarned, expectedPoints);
      expect(attempt.examCoinsEarned, expectedCoins);
      final rows = await E2eHost.rows(
        'select id,status,started_at,ends_at,finished_at,elapsed_seconds,points_earned,exam_coins_earned from public.exam_attempts where user_id=${sqlText(owner)} and client_uuid=${sqlText(uuid)}',
      );
      expect(rows, hasLength(1));
      expect(rows.single['status'], 'completed');
      expect(rows.single['id'], proof['attempt_id']);
      expect(DateTime.parse(rows.single['started_at'] as String), started);
      expect(DateTime.parse(rows.single['ends_at'] as String), end);
      expect(DateTime.parse(rows.single['finished_at'] as String), end);
      expect(rows.single['elapsed_seconds'], duration);
      expect(rows.single['points_earned'], expectedPoints);
      expect(rows.single['exam_coins_earned'], expectedCoins);
      final beforeDuplicate = await _economy(owner);
      expect(
        beforeDuplicate['total_minutes'],
        (baseline['total_minutes'] as num) + duration ~/ 60,
      );
      expect(beforeDuplicate['lifetime_points'], baseline['lifetime_points']);
      expect(beforeDuplicate['coins'], baseline['coins']);
      expect(
        beforeDuplicate['exam_points'],
        (baseline['exam_points'] as num) + expectedPoints,
      );
      expect(
        beforeDuplicate['exam_coins'],
        (baseline['exam_coins'] as num) + expectedCoins,
      );
      await _attribution(
        owner,
        attempt.id,
        'exam',
        duration ~/ 60,
        expectedPoints,
        end,
      );
      final duplicate =
          await LocalApi.rpc('complete_exam_attempt', account, {
                'p_attempt_id': attempt.id,
              })
              as Map;
      expect(duplicate['duplicate'], isTrue);
      expect(await _economy(owner), beforeDuplicate);
      completed = true;
    }
  }
  if (_requireCompleted) {
    expect(
      completed,
      isTrue,
      reason:
          'Final real-duration evidence requires the natural deadline to have elapsed',
    );
  }
  proof['last_resume_at'] = DateTime.now().toUtc().toIso8601String();
  proof['completion_verified'] = completed;
  expect(await prefs.setString(_key, jsonEncode(proof)), isTrue);
  await E2eHost.screenshot(
    tester,
    catalogProbe
        ? 'e2e-r-catalog-${(proof['exam_id'] as String).replaceAll('_', '-')}-${proof['language']}-resume'
        : 'e2e-real-probe-resume',
  );
  expect(tester.takeException(), isNull);
  debugPrint(
    '[REAL_PROBE_RESUME] run=$_run mode=${proof['mode']} owner=$owner completed=$completed evidence=${completed ? 'final-completion' : 'intermediate-resume-only'}',
  );
}

void main() {
  initE2e();
  testWidgets('r · real duration $_mode without changing dates or speed', (
    tester,
  ) async {
    expect(
      _mode == 'resume' || _startModes.contains(_mode),
      isTrue,
      reason: 'Set an explicit supported E2E_PROBE_MODE',
    );
    expect(
      RegExp(r'^[a-z0-9-]{1,40}$').hasMatch(_run),
      isTrue,
      reason: 'The same explicit E2E_RUN_ID is required across processes',
    );
    expect(
      const {
        'http://127.0.0.1:54321',
        'http://10.0.2.2:54321',
        'http://127.0.0.1:54325',
        'http://10.0.2.2:54325',
      }.contains(kSupabaseUrl),
      isTrue,
    );
    expect(
      E2eHost.available,
      isTrue,
      reason: 'Read-only SQL/screenshot evidence requires the local host',
    );
    if (_mode == 'resume') {
      await _resume(tester);
    } else {
      await _start(tester);
    }
  });
}
