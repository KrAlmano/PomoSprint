// Opt-in, two-process native test. A REAL 25-minute normal session completes
// behind the local HTTP503 proxy, remains in the durable outbox, then survives
// an OS process restart and is accepted once after reconnect. No clock edits,
// shortened timers, database writes, or production requests are made here.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/models/study_session.dart';
import 'package:pomodoro/screens/history_screen.dart';
import 'package:pomodoro/screens/monthly_tracking_screen.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:pomodoro/widgets/stats/session_type_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/e2e.dart';
import 'support/local_proxy.dart';

const _enabled = bool.fromEnvironment('E2E_NORMAL_HTTP_REAL25');
const _mode = String.fromEnvironment('E2E_NORMAL_HTTP_MODE');
const _run = String.fromEnvironment('E2E_RUN_ID');
const _preseeded = bool.fromEnvironment('E2E_NORMAL_HTTP_PRESEEDED');
String get _key => 'e2e_normal_http_restart_$_run';
String get _email => 'e2e-sim-http-normal-$_run@pomosprint.local';

Future<Map<String, dynamic>> _profile(String owner) async => (await E2eHost.row(
  'select p.total_minutes,p.lifetime_points,p.coins,p.current_streak,'
  'p.last_study_date::text,p.timezone,'
  'coalesce(w.lifetime_points,0) as exam_points,'
  'coalesce(w.coins,0) as exam_coins '
  'from public.profiles p left join public.exam_wallets w on w.user_id=p.id '
  'where p.id=${sqlText(owner)}',
))!;

Future<List<Map<String, dynamic>>> _studyRows(String owner) => E2eHost.rows(
  'select id::text,client_uuid::text,duration_minutes,base_points,bonus_points,'
  'started_at,completed_at from public.study_sessions '
  'where user_id=${sqlText(owner)} order by id',
);

Future<List<Map<String, dynamic>>> _examRows(String owner) => E2eHost.rows(
  'select id::text,status,started_at,ends_at,finished_at,points_earned,'
  'exam_coins_earned from public.exam_attempts '
  'where user_id=${sqlText(owner)} order by id',
);

Future<void> _assertQaOwner(String owner) async {
  expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(owner), isTrue);
  final row = await E2eHost.row(
    'select email=${sqlText(_email)} as expected_email,'
    "created_at>now()-interval '12 hours' as recent_owner "
    'from auth.users where id=${sqlText(owner)}',
  );
  expect(row, {
    'expected_email': true,
    'recent_owner': true,
  }, reason: 'Only this run\'s recent, explicitly named local QA account');
}

Future<void> _until(
  WidgetTester tester,
  Future<bool> Function() condition, {
  required String phase,
  required Duration timeout,
}) async {
  final elapsed = Stopwatch()..start();
  var lastLog = Duration.zero;
  while (elapsed.elapsed < timeout) {
    if (await condition()) return;
    expect(tester.takeException(), isNull, reason: phase);
    if (elapsed.elapsed - lastLog >= const Duration(seconds: 30)) {
      lastLog = elapsed.elapsed;
      debugPrint('[NORMAL_HTTP] $phase elapsed=${elapsed.elapsed.inSeconds}s');
    }
    await tester.pump(const Duration(seconds: 1));
  }
  fail('$phase did not finish in ${timeout.inSeconds} real seconds');
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

// SQL intentionally computes totals independently from the Dart calculator.
// Both domains use the profile's 04:00 workday; league attribution is checked
// separately using the completion's calendar month in Europe/Istanbul.
Future<Map<String, dynamic>> _rangeSql(
  String owner,
  DateTime first,
  DateTime last,
) async {
  String day(DateTime value) =>
      sqlText(value.toIso8601String().substring(0, 10));
  final range = '${day(first)}::date and ${day(last)}::date';
  return (await E2eHost.row(
    'with entries as ('
    'select s.duration_minutes as minutes,'
    "((s.started_at at time zone p.timezone)-interval '4 hours')::date as day,"
    "case when exists(select 1 from public.marathon_run_sessions m "
    "where m.user_id=s.user_id and m.study_session_id=s.id) then 'marathon' "
    "else 'normal' end as kind from public.study_sessions s "
    'join public.profiles p on p.id=s.user_id where s.user_id=${sqlText(owner)} '
    'union all select (a.definition->>\'duration_seconds\')::integer/60,'
    "((a.started_at at time zone p.timezone)-interval '4 hours')::date,'exam' "
    'from public.exam_attempts a join public.profiles p on p.id=a.user_id '
    "where a.user_id=${sqlText(owner)} and a.status='completed'"
    '), completed_runs as ('
    'select r.client_uuid,max(s.completed_at) as finished_at,p.timezone '
    'from public.marathon_runs r join public.marathon_run_sessions m '
    'on m.user_id=r.user_id and m.marathon_uuid=r.client_uuid '
    'join public.study_sessions s on s.id=m.study_session_id '
    'join public.profiles p on p.id=r.user_id '
    'where r.user_id=${sqlText(owner)} and not r.is_invalid '
    'group by r.client_uuid,r.target_sessions,p.timezone '
    'having count(*)=r.target_sessions) '
    'select coalesce(sum(minutes),0)::integer as minutes,'
    "count(*) filter(where kind='normal')::integer as normal_count,"
    "count(*) filter(where kind='marathon')::integer as marathon_focus_count,"
    "count(*) filter(where kind='exam')::integer as exam_count,"
    "coalesce(sum(minutes/25) filter(where kind<>'exam'),0)::integer as equivalents,"
    '(select count(*)::integer from completed_runs '
    "where ((finished_at at time zone timezone)-interval '4 hours')::date "
    'between $range) as completed_marathons '
    'from entries where day between $range',
  ))!;
}

Future<void> _assertRange(
  String owner,
  List<StatSession> sessions,
  DateTime first,
  DateTime last,
) async {
  final expected = await _rangeSql(owner, first, last);
  final counts = sessionTypeCounts(sessions, first, last);
  expect(sumMinutesBetween(sessions, first, last), expected['minutes']);
  expect(counts.normalSessions, expected['normal_count']);
  expect(counts.marathonFocusSessions, expected['marathon_focus_count']);
  expect(counts.completedMarathons, expected['completed_marathons']);
  expect(counts.completedExams, expected['exam_count']);
  expect(counts.focusEquivalents, expected['equivalents']);
  expect(counts.pendingSessions, 0);
  expect(counts.unknownSessions, 0);
  expect(
    sessions
        .where((s) => s.kind == StudySessionKind.exam)
        .every((s) => s.categoryId == kExamStatsCategoryId && s.pomodoros == 0),
    isTrue,
  );
}

Future<void> _assertReports(WidgetTester tester, String owner) async {
  await _tab(tester, 1);
  await tapOn(tester, find.text(tr('reports_tab_subject')));
  await pumpUntil(tester, find.byType(DailyReportView));
  await tester
      .widget<DailyReportView>(find.byType(DailyReportView))
      .onRefresh();
  await pumpFor(tester, const Duration(milliseconds: 500));
  final daily = tester.widget<DailyReportView>(find.byType(DailyReportView));
  await _assertRange(owner, daily.sessions, daily.today, daily.today);
  await E2eHost.screenshot(tester, 'e2e-normal-http-daily');

  await tapOn(tester, find.text(tr('reports_tab_history')));
  await pumpUntil(tester, find.byType(HistoryScreen));
  final weekly = tester.widget<HistoryScreen>(find.byType(HistoryScreen));
  final monday = mondayOf(weekly.today);
  await _assertRange(owner, weekly.sessions, monday, addDays(monday, 6));
  await E2eHost.screenshot(tester, 'e2e-normal-http-weekly');

  await tapOn(tester, find.text(tr('reports_tab_monthly')));
  await pumpUntil(tester, find.byType(MonthlyTrackingScreen));
  final monthly = tester.widget<MonthlyTrackingScreen>(
    find.byType(MonthlyTrackingScreen),
  );
  await _assertRange(
    owner,
    monthly.sessions,
    monthStartOf(monthly.today),
    monthEndOf(monthly.today),
  );
  await E2eHost.screenshot(tester, 'e2e-normal-http-monthly');
  expect(find.byType(SessionTypeSummary), findsWidgets);
  expect(tester.takeException(), isNull);
}

Future<ApiAccount> _openStartAccount(WidgetTester tester) async {
  if (!_preseeded) {
    return openShellWithNewAccount(
      tester,
      'http-normal',
      name: 'QA HTTP Normal',
    );
  }
  // Optional controlled history is prepared externally for this exact email.
  // This path never modifies its dates, subjects, or previous study rows.
  await resetAppState(tester);
  final result =
      await LocalApi.request(
            'POST',
            '/auth/v1/token?grant_type=password',
            body: {'email': _email, 'password': kE2ePassword},
          )
          as Map;
  final account = ApiAccount(
    (result['user'] as Map)['id'] as String,
    _email,
    result['access_token'] as String,
  );
  await _assertQaOwner(account.id);
  await launchApp(tester);
  await waitPastSplash(tester);
  await loginViaUi(tester, _email);
  await pumpUntil(tester, find.byType(MainNavigationShell));
  return account;
}

Future<void> _start(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  expect(
    prefs.containsKey(_key),
    isFalse,
    reason: 'Resume an existing run; do not overwrite it',
  );
  for (final key in prefs.getKeys().where(
    (key) =>
        key.startsWith('e2e_real_duration_probe_') ||
        key.startsWith('e2e_normal_http_restart_'),
  )) {
    final record = jsonDecode(prefs.getString(key)!) as Map;
    expect(
      record['completion_verified'],
      isTrue,
      reason: 'Another unfinished probe owns this app installation',
    );
  }
  var leaveProxyClosed = false;
  await setLocalHttpProxyAvailable(true);
  try {
    final account = await _openStartAccount(tester);
    final service = SupabaseService.instance;
    await _assertQaOwner(account.id);
    await NotificationService.instance.setEnabled(false);
    expect(await service.getPendingSessions(), isEmpty);
    expect(await service.getRejectedSessions(), isEmpty);
    expect(await TimerPersistence.instance.load(account.id), isNull);
    final baseline = await _profile(account.id);
    final beforeStudy = await _studyRows(account.id);
    final beforeExams = await _examRows(account.id);
    if (!_preseeded) {
      expect(beforeStudy, isEmpty);
      expect(beforeExams, isEmpty);
      expect(baseline['total_minutes'], 0);
      expect(baseline['lifetime_points'], 0);
      expect(baseline['coins'], 0);
    }
    expect(beforeExams.every((row) => row['status'] != 'active'), isTrue);
    if (_preseeded) {
      expect(
        beforeExams.any((row) => row['status'] == 'completed'),
        isTrue,
        reason: 'Preseeded mode must actually exercise shared exam totals',
      );
      await _assertReports(tester, account.id);
      await _tab(tester, 0);
    }
    await tapOn(tester, find.text('25 ${tr('minutes_unit_short')}'));
    final watch = Stopwatch()..start();
    await tapOn(tester, find.widgetWithText(ElevatedButton, tr('btn_start')));
    ActiveTimerSession? started;
    await _until(
      tester,
      () async {
        started = await TimerPersistence.instance.load(account.id);
        return started?.isRunning == true;
      },
      phase: 'real UI start',
      timeout: const Duration(seconds: 30),
    );
    final timer = started!;
    expect(timer.isQuickTest, isFalse);
    expect(timer.marathon, isNull);
    expect(timer.totalSeconds, 1500);
    expect(timer.durationMinutes, 25);
    expect(
      timer.endsAt!.difference(timer.startedAt),
      const Duration(minutes: 25),
    );
    final proof = <String, dynamic>{
      'run_id': _run,
      'owner_id': account.id,
      'email': _email,
      'start_pid': pid,
      'client_uuid': timer.clientUuid,
      'baseline': baseline,
      'before_study': beforeStudy,
      'before_exams': beforeExams,
      'preseeded_controlled_history': _preseeded,
      'started_at': timer.startedAt.toUtc().toIso8601String(),
      'ends_at': timer.endsAt!.toUtc().toIso8601String(),
      'stage': 'running',
      'completion_verified': false,
    };
    // If the first phase itself is interrupted, a later start must not clear
    // the active timer/outbox. Only a fully observed pending phase may resume.
    expect(await prefs.setString(_key, jsonEncode(proof)), isTrue);
    final reservation = (await E2eHost.row(
      'select active_session_ends_at '
      'from public.profiles where id=${sqlText(account.id)}',
    ))!;
    expect(reservation['active_session_ends_at'], isNotNull);
    expect(
      DateTime.parse(
        reservation['active_session_ends_at'] as String,
      ).difference(timer.endsAt!).inSeconds.abs(),
      lessThanOrEqualTo(5),
    );
    await setLocalHttpProxyAvailable(false);
    await _until(
      tester,
      () async => (await service.getPendingSessions()).any(
        (pending) => pending.clientUuid == timer.clientUuid,
      ),
      phase: 'full 1500-second focus behind HTTP503',
      timeout: const Duration(minutes: 27),
    );
    expect(watch.elapsed, greaterThanOrEqualTo(const Duration(minutes: 25)));
    expect(DateTime.now().isBefore(timer.endsAt!), isFalse);
    await _until(
      tester,
      () async => await TimerPersistence.instance.load(account.id) == null,
      phase: 'completed timer leaves one durable outbox record',
      timeout: const Duration(seconds: 30),
    );
    final pending = (await service.getPendingSessions()).single;
    expect(pending.clientUuid, timer.clientUuid);
    expect(pending.startedAt, timer.startedAt.toUtc());
    expect(pending.minutes, 25);
    expect(pending.recordAccelerated, isFalse);
    expect(pending.marathonUuid, isNull);
    expect(pending.wasPaused, isFalse);
    expect(
      pending.clockOffsetMs,
      isNotNull,
      reason: 'The real online start supplied the original clock correction',
    );
    await pumpUntil(tester, find.text(trL10n.sessionQueuedOffline));
    expect(await service.getRejectedSessions(), isEmpty);
    expect(await _studyRows(account.id), beforeStudy);
    expect(await _examRows(account.id), beforeExams);
    expect(
      await _profile(account.id),
      baseline,
      reason: 'HTTP503 completion has not credited server economy',
    );
    proof.addAll({
      'pending': pending.toJson(),
      'observed_wall_seconds': watch.elapsed.inSeconds,
      'stage': 'awaiting_process_restart',
    });
    expect(await prefs.setString(_key, jsonEncode(proof)), isTrue);
    await E2eHost.screenshot(tester, 'e2e-normal-http-durable-pending');
    expect(tester.takeException(), isNull);
    leaveProxyClosed = true;
    debugPrint(
      '[NORMAL_HTTP] START-STAGE PASS: real1500s, one durable pending, '
      'no server reward; awaiting OS process restart. controlled_history=$_preseeded',
    );
  } finally {
    // Successful start deliberately leaves HTTP503 active. The next process
    // must observe the durable queue before reconnecting. Failures release it.
    if (!leaveProxyClosed) await setLocalHttpProxyAvailable(true);
  }
}

Future<void> _resume(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  expect(
    raw,
    isNotNull,
    reason: 'Missing durable start proof; never reset app data between phases',
  );
  final proof = Map<String, dynamic>.from(jsonDecode(raw!) as Map);
  expect(proof['run_id'], _run);
  expect(proof['email'], _email);
  expect(proof['stage'], 'awaiting_process_restart');
  expect(proof['completion_verified'], isFalse);
  expect(
    proof['start_pid'],
    isNot(pid),
    reason: 'A new OS application process is mandatory',
  );
  final owner = proof['owner_id'] as String;
  final uuid = proof['client_uuid'] as String;
  final baseline = Map<String, dynamic>.from(proof['baseline'] as Map);
  await _assertQaOwner(owner);
  await setLocalHttpProxyAvailable(false);
  try {
    await launchApp(tester); // Preserve auth, outbox and all application data.
    await pumpUntil(
      tester,
      find.byType(MainNavigationShell),
      timeout: const Duration(seconds: 90),
      reason: 'cached owner opens during HTTP503',
    );
    final service = SupabaseService.instance;
    expect(service.currentUser.value?.id, owner);
    expect(Supabase.instance.client.auth.currentUser?.id, owner);
    final pending = (await service.getPendingSessions()).single;
    final savedPending = Map<String, dynamic>.from(proof['pending'] as Map);
    // Retry metadata may change, but the source identity, actual start and
    // clock snapshot must remain exactly the same after process restart.
    for (final key in [
      'client_uuid',
      'category_id',
      'category_name',
      'minutes',
      'was_paused',
      'is_verified',
      'started_at',
      'clock_offset_ms',
    ]) {
      expect(pending.toJson()[key], savedPending[key], reason: 'durable $key');
    }
    expect(pending.clientUuid, uuid);
    expect(await _studyRows(owner), proof['before_study']);
    expect(await _examRows(owner), proof['before_exams']);
    expect(await _profile(owner), baseline);
    await E2eHost.screenshot(tester, 'e2e-normal-http-restarted-offline');

    await setLocalHttpProxyAvailable(true);
    await service.syncPendingSessions();
    await _until(
      tester,
      () async => (await service.getPendingSessions()).isEmpty,
      phase: 'reconnect submits the original outbox',
      timeout: const Duration(seconds: 60),
    );
    expect(await service.getRejectedSessions(), isEmpty);
    final allRows = await _studyRows(owner);
    final accepted = allRows.singleWhere((row) => row['client_uuid'] == uuid);
    expect(allRows.length, (proof['before_study'] as List).length + 1);
    expect(
      allRows.where((row) => row['client_uuid'] != uuid).toList(),
      proof['before_study'],
    );
    expect(accepted['duration_minutes'], 25);
    expect(accepted['base_points'], 5);
    expect(accepted['bonus_points'], 0);
    final savedStart = DateTime.parse(accepted['started_at'] as String);
    final savedEnd = DateTime.parse(accepted['completed_at'] as String);
    final originalStart = DateTime.parse(proof['started_at'] as String);
    final originalEnd = DateTime.parse(proof['ends_at'] as String);
    expect(savedEnd.difference(savedStart), const Duration(minutes: 25));
    expect(
      savedStart.difference(originalStart),
      savedEnd.difference(originalEnd),
    );
    // SessionQueue uses the immutable entry offset before its current HTTP
    // clock sample. It adds that exact millisecond correction to startedAt;
    // the server derives completed_at from that start plus the duration.
    // Only sub-millisecond serialization precision is tolerated here.
    expect(pending.clockOffsetMs, isNotNull);
    final expectedCorrection = Duration(milliseconds: pending.clockOffsetMs!);
    for (final correction in [
      savedStart.difference(originalStart),
      savedEnd.difference(originalEnd),
    ]) {
      expect(
        (correction - expectedCorrection).inMicroseconds.abs(),
        lessThan(1000),
        reason: 'Server dates use the exact durable entry clock correction',
      );
    }
    expect(await _examRows(owner), proof['before_exams']);
    final after = await _profile(owner);
    expect(after['total_minutes'], (baseline['total_minutes'] as num) + 25);
    expect(after['lifetime_points'], (baseline['lifetime_points'] as num) + 5);
    expect(after['coins'], (baseline['coins'] as num) + 20);
    expect(after['exam_points'], baseline['exam_points']);
    expect(after['exam_coins'], baseline['exam_coins']);
    final event = (await E2eHost.row(
      'select e.kind,e.points,e.minutes,e.study_day::text,e.period_month::text,'
      "date_trunc('month',e.completed_at at time zone 'Europe/Istanbul')::date::text as expected_month,"
      "((s.started_at at time zone p.timezone)-interval '4 hours')::date::text as expected_day "
      'from public.competition_events e join public.profiles p on p.id=e.user_id '
      'join public.study_sessions s on s.id=e.source_id '
      'where e.user_id=${sqlText(owner)} and e.source_id=${sqlText(accepted['id'] as String)}',
    ))!;
    expect(event['kind'], 'study');
    expect(event['points'], 5);
    expect(event['minutes'], 25);
    expect(event['study_day'], event['expected_day']);
    expect(event['period_month'], event['expected_month']);
    final day = DateTime.parse(event['expected_day'] as String);
    final last = baseline['last_study_date'] as String?;
    final distance = last == null
        ? null
        : day.difference(DateTime.parse(last)).inDays;
    final previousStreak = (baseline['current_streak'] as num).toInt();
    expect(
      after['current_streak'],
      distance == null || distance > 1
          ? 1
          : distance == 1
          ? previousStreak + 1
          : previousStreak,
    );
    expect(
      after['last_study_date'],
      last == null || day.isAfter(DateTime.parse(last))
          ? event['expected_day']
          : last,
    );
    final account = ApiAccount(
      owner,
      _email,
      Supabase.instance.client.auth.currentSession!.accessToken,
    );
    await service.syncPendingSessions();
    final duplicate =
        await LocalApi.rpc('complete_study_session', account, {
              'p_client_uuid': uuid,
              'p_category_id': pending.categoryId,
              'p_duration_minutes': 25,
              'p_was_paused': false,
              'p_is_verified': pending.foregroundSeconds,
              'p_started_at': savedStart.toUtc().toIso8601String(),
            })
            as Map;
    expect(duplicate['duplicate'], isTrue);
    expect(await _studyRows(owner), allRows);
    expect(await _profile(owner), after);
    expect(await service.getPendingSessions(), isEmpty);
    await service.fetchCurrentUserModel();
    await _assertReports(tester, owner);
    proof['stage'] = 'verified';
    proof['completion_verified'] = true;
    proof['resume_pid'] = pid;
    proof['verified_at'] = DateTime.now().toUtc().toIso8601String();
    expect(await prefs.setString(_key, jsonEncode(proof)), isTrue);
    debugPrint(
      '[NORMAL_HTTP] FINAL PASS: different process, one real25 row, '
      '+5 normal points/+20 sand, exam wallet unchanged, daily/weekly/monthly SQL match; '
      'controlled_history=${proof['preseeded_controlled_history']}',
    );
  } finally {
    await setLocalHttpProxyAvailable(true);
  }
}

void main() {
  initE2e();
  testWidgets(
    'w · real25 HTTP503 / process restart / one row / shared reports ($_mode)',
    (tester) async {
      expect(_enabled, isTrue);
      expect({'start', 'resume'}.contains(_mode), isTrue);
      expect(RegExp(r'^[a-z0-9-]{1,40}$').hasMatch(_run), isTrue);
      expect(kE2eHttpProxy && E2eHost.available, isTrue);
      expect(
        {
          'http://127.0.0.1:54325',
          'http://10.0.2.2:54325',
        }.contains(kSupabaseUrl),
        isTrue,
      );
      if (_mode == 'start') {
        await _start(tester);
      } else {
        await _resume(tester);
      }
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 35)),
  );
}
