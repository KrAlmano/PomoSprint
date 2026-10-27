// Two-process REAL duration probe. Start through the actual UI, end the test
// without cleanup, wait with the app process closed, then run mode=resume with
// the SAME E2E_RUN_ID and app installation/data. No timer/catalog/SQL dates are
// changed. Notification delivery is outside this probe (disabled at setup).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/e2e.dart';

const _mode = String.fromEnvironment('E2E_PROBE_MODE');
const _run = String.fromEnvironment('E2E_RUN_ID');
const _requireCompleted = bool.fromEnvironment('E2E_PROBE_REQUIRE_COMPLETED');
const _startModes = {
  'normal25_start',
  'normal50_start',
  'exam_lgs_start',
  'exam_tus_start',
};
String get _key => 'e2e_real_duration_probe_$_run';

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
  final unfinished = prefs
      .getKeys()
      .where(
        (key) =>
            key.startsWith('e2e_real_duration_probe_') ||
            key.startsWith('e2e_normal_http_restart_'),
      )
      .where((key) {
        final value = jsonDecode(prefs.getString(key)!) as Map;
        return value['completion_verified'] != true;
      });
  expect(
    unfinished,
    isEmpty,
    reason:
        'This app installation already has an unfinished real-duration or HTTP restart probe',
  );
  final account = await openShellWithNewAccount(
    tester,
    'probe-${_mode.replaceAll('_', '-')}',
    name: 'QA Real Duration',
  );
  await NotificationService.instance.setEnabled(false);
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
    final id = _mode == 'exam_lgs_start' ? 'lgs_verbal' : 'tus_basic';
    final duration = id == 'lgs_verbal' ? 4500 : 8100;
    await tapOn(tester, find.byKey(ValueKey('exam-start-$id')));
    await pumpUntil(tester, find.text(trL10n.examRulesTitle));
    await tapOn(tester, find.widgetWithText(FilledButton, trL10n.examReady));
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
      'select status,started_at,ends_at from public.exam_attempts where id=${sqlText(attempt.id)} and user_id=${sqlText(account.id)}',
    );
    expect(row!['status'], 'active');
    expect(DateTime.parse(row['started_at'] as String), attempt.startedAt);
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
    'e2e-real-probe-${_mode.replaceAll('_', '-')}',
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
      final expectedPoints = proof['mode'] == 'exam_lgs_start' ? 15 : 27;
      final expectedCoins = proof['mode'] == 'exam_lgs_start' ? 3 : 5;
      expect(duration, proof['mode'] == 'exam_lgs_start' ? 4500 : 8100);
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
  await E2eHost.screenshot(tester, 'e2e-real-probe-resume');
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
