// Real process-boundary probe, no shortened clocks or historical fixtures.
// start -> OS terminate/shutdown -> resume (focus|break|expired expectation).
// recovered_expired preserves the separately failed baseline break assertion.
// verify checks that retained completed recovery without rewriting its proof.
// Always retain the same installation with --no-uninstall and E2E_RUN_ID.
import 'dart:convert';
import 'dart:io' show pid;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/models/marathon_progress.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/e2e.dart';

const _mode = String.fromEnvironment('E2E_MARATHON_PROBE_MODE');
const _expected = String.fromEnvironment('E2E_MARATHON_PROBE_EXPECT');
const _run = String.fromEnvironment('E2E_RUN_ID');
String get _key => 'e2e_marathon_process_probe_$_run';
String get _email => e2eEmail('marathon-process');

void _log(String phase) => debugPrint(
  '[MARATHON_PROCESS] ${DateTime.now().toUtc().toIso8601String()} $phase',
);

Future<void> _until(
  WidgetTester tester,
  Future<bool> Function() condition, {
  required String phase,
}) async {
  final watch = Stopwatch()..start();
  while (watch.elapsed < const Duration(seconds: 50)) {
    if (await condition()) return;
    expect(tester.takeException(), isNull, reason: phase);
    await tester.pump(const Duration(milliseconds: 200));
  }
  fail('$phase was not observed in 50 seconds');
}

Future<Map<String, dynamic>> _economy(String owner) async => (await E2eHost.row(
  'select p.total_minutes,p.lifetime_points,p.coins,p.current_streak,'
  'coalesce(w.lifetime_points,0) as exam_points,coalesce(w.coins,0) as exam_coins '
  'from public.profiles p left join public.exam_wallets w on w.user_id=p.id '
  'where p.id=${sqlText(owner)}',
))!;

Future<Map<String, dynamic>?> _gate(String owner, String run) => E2eHost.row(
  'select next_session_index,previous_client_uuid::text,break_started_at,break_ends_at,'
  'confirmation_deadline,confirmed_at,next_client_uuid::text '
  'from public.marathon_presence_gates where user_id=${sqlText(owner)} '
  'and marathon_uuid=${sqlText(run)}',
);

Duration _expectDeviceGate(
  ActiveTimerSession saved,
  Map<String, dynamic> gate, {
  Duration? measuredCorrection,
}) {
  final serverBegin = DateTime.parse(
    gate['break_started_at'] as String,
  ).toUtc();
  final serverEnd = DateTime.parse(gate['break_ends_at'] as String).toUtc();
  final serverDeadline = DateTime.parse(
    gate['confirmation_deadline'] as String,
  ).toUtc();
  final deviceEnd = saved.marathon!.breakEndsAt!.toUtc();
  final deviceDeadline = saved.marathon!.presenceDeadline!.toUtc();
  expect(serverEnd.difference(serverBegin), const Duration(seconds: 300));
  expect(serverDeadline.difference(serverEnd), const Duration(seconds: 60));
  expect(deviceDeadline.difference(deviceEnd), const Duration(seconds: 60));
  // SessionSubmitSuccess intentionally subtracts the measured server/device
  // correction from both timestamps. Exact raw SQL/device equality is wrong.
  final correction = serverEnd.difference(deviceEnd);
  expect(
    serverDeadline.difference(deviceDeadline),
    correction,
    reason: 'Both persisted endpoints must have the exact same correction',
  );
  expect(
    correction.inMicroseconds.abs(),
    lessThan(5000000),
    reason:
        'The real-duration probes permit at most five seconds of clock skew',
  );
  if (measuredCorrection != null) {
    expect(
      (correction - measuredCorrection).inMicroseconds.abs(),
      lessThan(5000000),
      reason:
          'Receipt conversion must agree with the measured clock correction',
    );
  }
  return correction;
}

Future<void> _guardBeforeStart(SharedPreferences prefs) async {
  expect(
    prefs.containsKey(_key),
    isFalse,
    reason: 'Resume this run; do not overwrite it',
  );
  for (final key in prefs.getKeys()) {
    if (key.startsWith('e2e_real_duration_probe_') ||
        key.startsWith('e2e_normal_http_restart_') ||
        key.startsWith('e2e_first_use_real25_') ||
        key.startsWith('e2e_marathon_process_probe_')) {
      final marker = jsonDecode(prefs.getString(key)!) as Map;
      expect(
        marker['completion_verified'],
        isTrue,
        reason: 'Another unfinished process probe owns this installation',
      );
    }
    if (key.startsWith('active_session_uid_')) {
      fail('An existing timer must not be cleared by this probe');
    }
    if (key.startsWith('pending_sessions_')) {
      expect(
        jsonDecode(prefs.getString(key)!),
        isEmpty,
        reason: 'Preserve another owner\'s pending sessions',
      );
    }
    if (key.startsWith('exam_journal_uid_')) {
      for (final raw in jsonDecode(prefs.getString(key)!) as List) {
        final record = ExamLocalRecord.fromJson(raw);
        expect(
          record,
          isNotNull,
          reason: 'Preserve malformed journal evidence',
        );
        expect(record!.pendingAction, isNull);
        expect(record.attempt?.status, isNot(ExamAttemptStatus.active));
      }
    }
  }
  final existing = await E2eHost.row(
    'select count(*)::integer as count from auth.users where email=${sqlText(_email)}',
  );
  expect(
    existing!['count'],
    0,
    reason: 'A new deterministic QA account is required',
  );
}

void _expectOriginal(ActiveTimerSession saved, Map<String, dynamic> proof) {
  expect(saved.clientUuid, proof['client_uuid']);
  expect(
    saved.startedAt.toUtc(),
    DateTime.parse(proof['started_at'] as String),
  );
  expect(saved.endsAt!.toUtc(), DateTime.parse(proof['ends_at'] as String));
  expect(saved.durationMinutes, 25);
  expect(saved.totalSeconds, 1500);
  expect(saved.isQuickTest, isFalse);
  expect(saved.recordAccelerated, isFalse);
  expect(saved.pauseUsedCount, 0);
  expect(saved.marathon!.marathonUuid, proof['marathon_uuid']);
  expect(saved.marathon!.totalSessions, 2);
  expect(saved.marathon!.breakSeconds, 300);
  expect(saved.marathon!.presenceClientUuid, isNull);
}

Future<void> _start(WidgetTester tester, SharedPreferences prefs) async {
  await _guardBeforeStart(prefs);
  final account = await openShellWithNewAccount(
    tester,
    'marathon-process',
    name: 'QA Marathon Process',
  );
  expect(account.email, _email);
  await NotificationService.instance.setEnabled(false);
  expect(await _economy(account.id), {
    'total_minutes': 0,
    'lifetime_points': 0,
    'coins': 0,
    'current_streak': 0,
    'exam_points': 0,
    'exam_coins': 0,
  });
  final config = await LocalApi.rpc('get_marathon_config', account) as Map;
  expect(config['available'], isTrue);
  expect(config['break_seconds'], 300);
  expect(config['presence_seconds'], 60);
  await pumpUntilTrue(tester, () {
    final f = find.byKey(const ValueKey('marathon-open-planner'));
    return f.evaluate().isNotEmpty &&
        tester.widget<TextButton>(f).onPressed != null;
  }, reason: 'standard Marathon planner is available');
  await tapOn(tester, find.byKey(const ValueKey('marathon-open-planner')));
  await pumpUntil(
    tester,
    find.byKey(const ValueKey('marathon-planner-dialog')),
  );
  await tapOn(tester, find.byKey(const ValueKey('marathon-count-2')));
  await tapOn(tester, find.byKey(const ValueKey('marathon-duration-25')));
  await tapOn(tester, find.byKey(const ValueKey('marathon-start')));
  await _until(tester, () async {
    final s = await TimerPersistence.instance.load(account.id);
    return s?.isRunning == true && s?.marathon?.phase == MarathonPhase.focus;
  }, phase: 'first Marathon focus is durable');
  final saved = (await TimerPersistence.instance.load(account.id))!;
  final proof = <String, dynamic>{
    'run_id': _run,
    'owner_id': account.id,
    'email': account.email,
    'start_pid': pid,
    'last_pid': pid,
    'stage': 'focus_started',
    'client_uuid': saved.clientUuid,
    'marathon_uuid': saved.marathon!.marathonUuid,
    'started_at': saved.startedAt.toUtc().toIso8601String(),
    'ends_at': saved.endsAt!.toUtc().toIso8601String(),
    'remaining_at_start': saved.remainingSecondsAt(DateTime.now()),
    'completion_verified': false,
    'uses_historical_fixture': false,
  };
  _expectOriginal(saved, proof);
  expect(saved.marathon!.completedSessions, 0);
  expect(await _gate(account.id, saved.marathon!.marathonUuid), isNull);
  expect(await prefs.setString(_key, jsonEncode(proof)), isTrue);
  await E2eHost.screenshot(tester, 'e2e-marathon-process-start');
  _log('START ${jsonEncode(proof)}');
  // Retain auth, timer and proof; the host closes the OS process after exit.
}

Future<void> _oneAcceptedFocus(
  String owner,
  Map<String, dynamic> proof, {
  bool invalid = false,
}) async {
  final rows = await E2eHost.rows(
    'select s.id::text,s.client_uuid::text,s.duration_minutes,s.base_points,s.bonus_points,'
    's.started_at,s.completed_at,m.session_index,m.marathon_uuid::text '
    'from public.study_sessions s join public.marathon_run_sessions m '
    'on m.study_session_id=s.id and m.user_id=s.user_id '
    'where s.user_id=${sqlText(owner)}',
  );
  expect(rows, hasLength(1));
  final row = rows.single;
  expect(row['client_uuid'], proof['client_uuid']);
  expect(row['marathon_uuid'], proof['marathon_uuid']);
  expect(row['session_index'], 1);
  expect(row['duration_minutes'], 25);
  expect(row['base_points'], 5);
  expect(row['bonus_points'], 0);
  final start = DateTime.parse(proof['started_at'] as String);
  final end = DateTime.parse(proof['ends_at'] as String);
  final savedStart = DateTime.parse(row['started_at'] as String);
  final savedEnd = DateTime.parse(row['completed_at'] as String);
  expect(savedEnd.difference(savedStart), const Duration(minutes: 25));
  expect(savedStart.difference(start), savedEnd.difference(end));
  expect(savedStart.difference(start).inMicroseconds.abs(), lessThan(5000000));
  final runs = await E2eHost.rows(
    'select target_sessions,duration_minutes,bonus_awarded,is_invalid '
    'from public.marathon_runs where user_id=${sqlText(owner)} '
    'and client_uuid=${sqlText(proof['marathon_uuid'] as String)}',
  );
  expect(runs, [
    {
      'target_sessions': 2,
      'duration_minutes': 25,
      'bonus_awarded': 0,
      'is_invalid': invalid,
    },
  ]);
  expect(await _economy(owner), {
    'total_minutes': 25,
    'lifetime_points': 5,
    'coins': 20,
    'current_streak': 1,
    'exam_points': 0,
    'exam_coins': 0,
  });
  expect(
    await E2eHost.rows(
      'select kind,points,minutes from public.competition_events '
      'where user_id=${sqlText(owner)}',
    ),
    [
      {'kind': 'study', 'points': 5, 'minutes': 25},
    ],
  );
  expect(
    await E2eHost.rows(
      'select id from public.study_sessions where user_id=${sqlText(owner)}',
    ),
    hasLength(1),
  );
  expect(
    await E2eHost.rows(
      'select id from public.exam_attempts where user_id=${sqlText(owner)}',
    ),
    isEmpty,
  );
}

Future<void> _resume(WidgetTester tester, SharedPreferences prefs) async {
  final raw = prefs.getString(_key);
  expect(
    raw,
    isNotNull,
    reason: 'Installation/proof lost: invalid process resume',
  );
  final proof = Map<String, dynamic>.from(jsonDecode(raw!) as Map);
  expect(proof['run_id'], _run);
  expect(proof['email'], _email);
  expect(
    pid,
    isNot(proof['last_pid']),
    reason: 'A different native OS process is required',
  );
  final owner = proof['owner_id'] as String;
  final run = proof['marathon_uuid'] as String;
  final end = DateTime.parse(proof['ends_at'] as String);
  final before = await TimerPersistence.instance.load(owner);
  expect(before, isNotNull, reason: 'Saved Marathon must survive OS shutdown');
  _expectOriginal(before!, proof);
  final preGate = await _gate(owner, run);
  final resumeAt = DateTime.now().toUtc();
  if (_expected == 'focus') {
    expect(
      resumeAt.isBefore(end.subtract(const Duration(seconds: 10))),
      isTrue,
    );
    expect(before.marathon!.phase, MarathonPhase.focus);
    expect(preGate, isNull);
  } else if (_expected == 'break' || _expected == 'late_rejected') {
    expect(
      resumeAt.isBefore(end),
      isFalse,
      reason: 'Wait the real first 25 minutes',
    );
    expect(
      preGate,
      isNull,
      reason: 'This stage proves first acceptance after reopening',
    );
    expect(before.marathon!.completedSessions, 0);
    if (_expected == 'late_rejected') {
      expect(
        resumeAt.isBefore(end.add(const Duration(seconds: 370))),
        isFalse,
        reason: 'Wait past 300+60 seconds and the clock tolerance',
      );
    }
  } else if (_expected == 'recovered_expired') {
    // Only recover the known, retained baseline run. Do not turn an arbitrary
    // missing marker or a new first-acceptance attempt into a passing result.
    expect(_run, 'night-ab-before31');
    expect(proof['stage'], 'same_focus_resumed');
    expect(proof['completion_verified'], isFalse);
    expect(proof['uses_historical_fixture'], isFalse);
    expect(proof['gate'], isNull);
    expect(preGate, isNotNull);
    expect(before.marathon!.completedSessions, 1);
    expect(before.marathon!.isOnBreak, isTrue);
    expect(preGate!['next_session_index'], 2);
    expect(preGate['previous_client_uuid'], proof['client_uuid']);
    expect(preGate['confirmed_at'], isNull);
    expect(preGate['next_client_uuid'], isNull);
    final begin = DateTime.parse(preGate['break_started_at'] as String).toUtc();
    final deadline = DateTime.parse(
      preGate['confirmation_deadline'] as String,
    ).toUtc();
    expect(
      begin.isAfter(end.add(const Duration(seconds: 360))),
      isTrue,
      reason: 'This recovery is for the already accepted, late baseline gate',
    );
    expect(
      resumeAt.isBefore(deadline.add(const Duration(seconds: 5))),
      isFalse,
      reason:
          'Wait until the actual server gate is expired including clock tolerance',
    );
    final correction = _expectDeviceGate(before, preGate);
    // Observe the existing row/credit before launch, then compare again after
    // expiry. Nothing is inserted, backdated, or re-credited by the probe.
    await _oneAcceptedFocus(owner, proof);
    proof['recovery_from_stage'] = proof['stage'];
    proof['recovery_observed_gate'] = Map<String, dynamic>.from(preGate);
    proof['recovery_observed_clock_correction_us'] = correction.inMicroseconds;
  } else {
    expect(
      proof['gate'],
      isA<Map>(),
      reason: 'First run resume with break expectation',
    );
    expect(preGate, Map<String, dynamic>.from(proof['gate'] as Map));
    final deadline = DateTime.parse(
      preGate!['confirmation_deadline'] as String,
    );
    expect(
      resumeAt.isBefore(deadline),
      isFalse,
      reason: 'Wait the real 300+60-second gate',
    );
    expect(before.marathon!.completedSessions, 1);
    expect(before.marathon!.isResting, isTrue);
  }
  await launchApp(tester); // Never reset, sign in again, or replace this timer.
  await pumpUntil(
    tester,
    find.byType(MainNavigationShell),
    timeout: const Duration(seconds: 50),
    reason: 'persisted Marathon owner',
  );
  expect(Supabase.instance.client.auth.currentUser?.id, owner);
  expect(SupabaseService.instance.currentUser.value?.id, owner);
  if (_expected == 'focus') {
    await _until(
      tester,
      () async =>
          (await TimerPersistence.instance.load(owner))?.isRunning == true,
      phase: 'same focus restored',
    );
    final restored = (await TimerPersistence.instance.load(owner))!;
    _expectOriginal(restored, proof);
    expect(restored.marathon!.completedSessions, 0);
    expect(
      restored.remainingSecondsAt(DateTime.now()),
      lessThan(proof['remaining_at_start'] as int),
    );
    expect(await _economy(owner), {
      'total_minutes': 0,
      'lifetime_points': 0,
      'coins': 0,
      'current_streak': 0,
      'exam_points': 0,
      'exam_coins': 0,
    });
    proof['stage'] = 'same_focus_resumed';
  } else if (_expected == 'break') {
    await _until(tester, () async {
      final s = await TimerPersistence.instance.load(owner);
      return s?.marathon?.completedSessions == 1 &&
          s?.marathon?.isOnBreak == true;
    }, phase: 'late first focus accepted, server break restored');
    final restored = (await TimerPersistence.instance.load(owner))!;
    _expectOriginal(restored, proof);
    final gate = (await _gate(owner, run))!;
    final begin = DateTime.parse(gate['break_started_at'] as String);
    final deadline = DateTime.parse(gate['confirmation_deadline'] as String);
    expect(
      begin.isBefore(resumeAt.subtract(const Duration(seconds: 5))),
      isFalse,
    );
    expect(
      begin.isAfter(DateTime.now().toUtc().add(const Duration(seconds: 5))),
      isFalse,
    );
    _expectDeviceGate(
      restored,
      gate,
      measuredCorrection:
          SupabaseService.instance.serverClockOffset ?? Duration.zero,
    );
    expect(gate['next_session_index'], 2);
    expect(gate['previous_client_uuid'], proof['client_uuid']);
    expect(gate['confirmed_at'], isNull);
    expect(gate['next_client_uuid'], isNull);
    expect(find.byKey(const ValueKey('marathon-break')), findsOneWidget);
    await _oneAcceptedFocus(owner, proof);
    proof['gate'] = gate;
    proof['stage'] = 'first_focus_accepted_break_waiting';
    _log(
      'No automatic second focus; gate expires at ${deadline.toIso8601String()}',
    );
  } else if (_expected == 'late_rejected') {
    await _until(
      tester,
      () async => await TimerPersistence.instance.load(owner) == null,
      phase: 'late unpaused first focus accepted but Marathon stopped',
    );
    await pumpUntil(tester, find.text(trL10n.marathonStoppedInvalid));
    await _oneAcceptedFocus(owner, proof, invalid: true);
    expect(
      await _gate(owner, run),
      isNull,
      reason: 'Late completion must not create a new break/ACK window',
    );
    expect(await SupabaseService.instance.getPendingSessions(), isEmpty);
    expect(await SupabaseService.instance.getRejectedSessions(), isEmpty);
    expect(find.byKey(const ValueKey('marathon-presence')), findsNothing);
    proof['completion_verified'] = true;
    proof['stage'] = 'late_unpaused_stopped_without_new_gate';
  } else {
    await _until(
      tester,
      () async => await TimerPersistence.instance.load(owner) == null,
      phase: 'unconfirmed Marathon expires after persisted gate',
    );
    await pumpUntil(tester, find.text(trL10n.marathonPresenceExpired));
    expect(find.byKey(const ValueKey('marathon-presence')), findsNothing);
    expect(
      await _gate(owner, run),
      preGate,
      reason: 'Reopening does not reset or confirm a persisted gate',
    );
    await _oneAcceptedFocus(owner, proof);
    expect(await SupabaseService.instance.getPendingSessions(), isEmpty);
    expect(await SupabaseService.instance.getRejectedSessions(), isEmpty);
    proof['completion_verified'] = true;
    proof['stage'] = _expected == 'recovered_expired'
        ? 'recovered_failed_break_assertion_then_expired'
        : 'expired_without_second_focus';
  }
  proof['last_pid'] = pid;
  proof['last_resumed_at'] = resumeAt.toIso8601String();
  expect(await prefs.setString(_key, jsonEncode(proof)), isTrue);
  await E2eHost.screenshot(
    tester,
    'e2e-marathon-process-${_expected.replaceAll('_', '-')}',
  );
  expect(tester.takeException(), isNull);
  _log('RESUME ${jsonEncode(proof)}');
  // Even final success retains rows, owner, auth and marker as evidence.
}

Future<void> _verifyRecovered(
  WidgetTester tester,
  SharedPreferences prefs,
) async {
  expect(_run, 'night-ab-before31');
  final raw = prefs.getString(_key);
  expect(raw, isNotNull, reason: 'Retain the completed recovery proof');
  final proof = Map<String, dynamic>.from(jsonDecode(raw!) as Map);
  expect(proof['run_id'], _run);
  expect(proof['email'], _email);
  expect(proof['stage'], 'recovered_failed_break_assertion_then_expired');
  expect(proof['recovery_from_stage'], 'same_focus_resumed');
  expect(proof['completion_verified'], isTrue);
  expect(proof['uses_historical_fixture'], isFalse);
  expect(proof['gate'], isNull);
  expect(proof['recovery_observed_gate'], isA<Map>());
  expect(proof['last_pid'], isA<int>());
  expect(pid, isNot(proof['last_pid']), reason: 'Use a new native process');
  expect(pid, isNot(proof['start_pid']));
  final owner = proof['owner_id'] as String;
  final run = proof['marathon_uuid'] as String;
  final cached = prefs.getString('saved_user');
  expect(cached, isNotNull, reason: 'Never reset or replace the saved owner');
  expect((jsonDecode(cached!) as Map)['id'], owner);
  expect(
    await E2eHost.row(
      'select email from auth.users where id=${sqlText(owner)}',
    ),
    {'email': _email},
  );
  // Read durable state before main() can sync it. There must be no work for
  // this final probe to submit or discard, including a legacy email queue.
  for (final key in prefs.getKeys()) {
    expect(
      key.startsWith('active_session_uid_'),
      isFalse,
      reason: 'Postflight must not disturb another active timer',
    );
  }
  for (final key in [
    'pending_sessions_uid_$owner',
    'pending_sessions_$_email',
    'rejected_sessions_uid_$owner',
  ]) {
    expect(jsonDecode(prefs.getString(key) ?? '[]'), isEmpty, reason: key);
  }
  expect(await TimerPersistence.instance.load(owner), isNull);
  final gate = await _gate(owner, run);
  expect(
    gate,
    Map<String, dynamic>.from(proof['recovery_observed_gate'] as Map),
  );
  expect(gate!['previous_client_uuid'], proof['client_uuid']);
  expect(gate['confirmed_at'], isNull);
  expect(gate['next_client_uuid'], isNull);
  await _oneAcceptedFocus(owner, proof);

  await launchApp(tester);
  await pumpUntil(
    tester,
    find.byType(MainNavigationShell),
    timeout: const Duration(seconds: 50),
    reason: 'the preserved completed recovery owner',
  );
  expect(Supabase.instance.client.auth.currentUser?.id, owner);
  expect(Supabase.instance.client.auth.currentUser?.email, _email);
  expect(SupabaseService.instance.currentUser.value?.id, owner);
  expect(await TimerPersistence.instance.load(owner), isNull);
  expect(await SupabaseService.instance.getPendingSessions(), isEmpty);
  expect(await SupabaseService.instance.getRejectedSessions(), isEmpty);
  expect(find.byKey(const ValueKey('marathon-break')), findsNothing);
  expect(find.byKey(const ValueKey('marathon-presence')), findsNothing);
  expect(await _gate(owner, run), gate);
  await _oneAcceptedFocus(owner, proof);
  await prefs.reload();
  expect(
    prefs.getString(_key),
    raw,
    reason: 'Postflight must not rewrite the completed recovery proof',
  );
  await E2eHost.screenshot(tester, 'e2e-marathon-process-verify-recovered');
  expect(tester.takeException(), isNull);
  _log(
    'VERIFY ${jsonEncode({'run_id': _run, 'owner_id': owner, 'prior_pid': proof['last_pid'], 'verification_pid': pid, 'completion_proof_unchanged': true, 'original_failures_preserved': true})}',
  );
}

void main() {
  if (_mode.isEmpty) {
    test(
      'ab · process probe is opt-in',
      () {},
      skip: 'Set E2E_MARATHON_PROBE_MODE=start, resume or verify',
    );
    return;
  }
  initE2e();
  testWidgets(
    'ab · Marathon OS process probe $_mode $_expected',
    (tester) async {
      expect(RegExp(r'^[a-z0-9-]{1,40}$').hasMatch(_run), isTrue);
      expect(const {'start', 'resume', 'verify'}.contains(_mode), isTrue);
      expect(E2eHost.available, isTrue);
      final prefs = await SharedPreferences.getInstance();
      if (_mode == 'start') {
        await _start(tester, prefs);
      } else if (_mode == 'verify') {
        await _verifyRecovered(tester, prefs);
      } else {
        expect(
          const {
            'focus',
            'break',
            'expired',
            'recovered_expired',
            'late_rejected',
          }.contains(_expected),
          isTrue,
        );
        await _resume(tester, prefs);
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
