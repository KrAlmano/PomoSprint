// A1–A4: real native controls + fixed-loopback SQL/verifier assertions.
// official: seven untouched official definitions, TR+EN starts/abandonments.
// short: root has explicitly installed temporary 60-second local definitions;
//        wait the real server minute per attempt, never move any clock/date.
// reports: UI login to an explicitly prepared local mixed-history account.
// Root restores catalogue+parity after short; this test never writes catalogue.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/screens/history_screen.dart';
import 'package:pomodoro/screens/monthly_tracking_screen.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/utils/exam_format.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:pomodoro/widgets/avatar_widget.dart';
import 'package:pomodoro/widgets/stats/session_type_summary.dart';
import 'package:pomodoro/widgets/stats/stats_text.dart';
import 'package:pomodoro/widgets/stats/progress_ring.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/e2e.dart';
import 'support/local_proxy.dart';

const _phase = String.fromEnvironment(
  'E2E_VERIFY_PHASE',
  defaultValue: 'official',
);
const _fixtureEmail = String.fromEnvironment('E2E_EXAM_FIXTURE_EMAIL');
const _metadata = <String, (int, int, int)>{
  'tyt': (9900, 120, 4),
  'ayt': (10800, 160, 4),
  'ydt': (7200, 80, 4),
  'lgs_verbal': (4500, 50, 3),
  'lgs_quantitative': (4800, 40, 3),
  'tus_basic': (8100, 100, 4),
  'tus_clinical': (8100, 100, 4),
};

AppLocalizations get _l10n => lookupAppLocalizations(
  Locale(LanguageService.instance.isTurkish ? 'tr' : 'en'),
);

Future<void> _until(
  WidgetTester tester,
  Future<bool> Function() condition, {
  required String reason,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (await condition()) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail(reason);
}

Future<void> _guardCompletedDeviceProbes() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys()) {
    if (key.startsWith('e2e_real_duration_probe_') ||
        key.startsWith('e2e_marathon_process_probe_') ||
        key.startsWith('e2e_first_use_real25_')) {
      final value = jsonDecode(prefs.getString(key)!);
      expect(value, isA<Map>(), reason: 'Preserve malformed proof: $key');
      expect(
        (value as Map)['completion_verified'],
        isTrue,
        reason: 'Never reset an unfinished real-duration device probe: $key',
      );
    }
  }
}

Future<void> _cancelKnownPriorOfficialFocus(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('saved_user');
  if (raw == null) return;
  final savedUser = jsonDecode(raw) as Map;
  final owner = savedUser['id'] as String?;
  if (owner == null) return;
  final active = await TimerPersistence.instance.load(owner);
  if (active == null) return;
  final email = savedUser['email']?.toString() ?? '';
  expect(
    RegExp(
      r'^e2e-sim-verify-official-[a-z0-9-]+@pomosprint\.local$',
    ).hasMatch(email),
    isTrue,
    reason:
        'Only the previous explicitly disposable AD official QA focus may be cancelled',
  );
  expect(active.durationMinutes, 25);
  expect(active.totalSeconds, 1500);
  expect(active.isQuickTest, isFalse);
  expect(active.recordAccelerated, isFalse);
  expect(active.marathon, isNull);
  final identity = await E2eHost.row(
    'select email=${sqlText(email)} as exact_owner,'
    "created_at>now()-interval '6 hours' as recent from auth.users where id=${sqlText(owner)}",
  );
  expect(identity, {'exact_owner': true, 'recent': true});
  for (final key in [
    'pending_sessions_uid_$owner',
    'pending_sessions_$email',
    'rejected_sessions_uid_$owner',
  ]) {
    expect(jsonDecode(prefs.getString(key) ?? '[]'), isEmpty, reason: key);
  }
  for (final row in await ExamPersistence().read(owner)) {
    expect(row.pendingAction, isNull);
    expect(row.attempt?.status, isNot(ExamAttemptStatus.active));
  }
  final before = await _economy(owner);
  expect(before['total_minutes'], 0);
  expect(before['lifetime_points'], 0);
  expect(before['coins'], 0);
  expect(before['exam_points'], 0);
  expect(before['exam_coins'], 0);
  await launchApp(tester); // Keep the same prior owner; never reset first.
  await pumpUntil(tester, find.byType(MainNavigationShell));
  expect(SupabaseService.instance.currentUser.value?.id, owner);
  await _tab(tester, 0);
  await tapOn(tester, find.widgetWithText(TextButton, _l10n.timerResetBtn));
  await pumpUntil(tester, find.text(_l10n.timerResetConfirmTitle));
  final action = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(TextButton, _l10n.timerResetConfirmAction),
  );
  expect(action, findsOneWidget);
  await tapOn(tester, action);
  await _until(
    tester,
    () async => await TimerPersistence.instance.load(owner) == null,
    reason:
        'Explicit user-authorized QA reset removes only the incomplete test focus',
  );
  expect(await _economy(owner), before);
  expect(
    await E2eHost.rows(
      'select id from public.study_sessions where user_id=${sqlText(owner)}',
    ),
    isEmpty,
  );
  await E2eHost.screenshot(tester, 'e2e-ad-prior-qa-focus-cancelled');
  debugPrint(
    '[AD_RECOVERY] Explicitly cancelled prior failed-test focus owner=$owner uuid=${active.clientUuid}; completed rows/economy unchanged; no silent reset.',
  );
}

Future<void> _tab(WidgetTester tester, int index) async {
  if (find.byType(NavigationBar).evaluate().isNotEmpty) {
    await openTab(tester, index);
  } else {
    tester
        .widget<NavigationRail>(find.byType(NavigationRail))
        .onDestinationSelected!(index);
    await pumpFor(tester, const Duration(milliseconds: 300));
  }
}

Future<void> _language(WidgetTester tester, String code) async {
  await tapOn(
    tester,
    find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(AvatarWidget),
    ),
  );
  await pumpUntil(tester, find.byType(ProfileScreen));
  await tapOn(tester, find.text(code == 'tr' ? 'Türkçe' : 'English'));
  await pumpUntilTrue(
    tester,
    () => LanguageService.instance.isTurkish == (code == 'tr'),
    reason: 'Settings applies $code',
  );
  Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
  await pumpUntilGone(tester, find.byType(ProfileScreen));
}

Future<void> _catalog(WidgetTester tester) async {
  await _tab(tester, 4);
  await pumpUntil(tester, find.byType(ExamScreen));
  await pumpUntilTrue(
    tester,
    () => ExamService.instance.catalog.available,
    reason: 'local exam catalogue available',
  );
  await tapOn(tester, find.byKey(const ValueKey('exam-tab-new')));
}

Future<void> _field(
  WidgetTester tester,
  String subject,
  int index,
  String value,
) async {
  final finder = find.byKey(ValueKey('exam-result-$subject-$index'));
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await pumpFor(tester, const Duration(milliseconds: 100));
  await tester.tap(finder);
  await pumpFor(tester, const Duration(milliseconds: 100));
  await tester.enterText(finder, value);
  await pumpFor(tester, const Duration(milliseconds: 100));
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(tester, const Duration(milliseconds: 100));
}

String _fieldText(WidgetTester tester, String subject, int index) => tester
    .widget<TextField>(find.byKey(ValueKey('exam-result-$subject-$index')))
    .controller!
    .text;

Future<Map<String, dynamic>> _economy(String owner) async => (await E2eHost.row(
  'select p.total_minutes,p.lifetime_points,p.coins,'
  'p.current_streak,p.longest_streak,p.last_study_date::text,'
  'coalesce(w.lifetime_points,0) as exam_points,coalesce(w.coins,0) as exam_coins '
  'from public.profiles p left join public.exam_wallets w on w.user_id=p.id '
  'where p.id=${sqlText(owner)}',
))!;

Future<ExamAttempt> _start(
  WidgetTester tester,
  String id, {
  required int seconds,
}) async {
  await _catalog(tester);
  final exam = ExamService.instance.catalog.byId(id)!;
  expect(exam.durationSeconds, seconds);
  expect(exam.totalQuestions, _metadata[id]!.$2);
  expect(exam.wrongAnswerDivisor, _metadata[id]!.$3);
  expect(
    exam.subjects.fold<int>(0, (sum, s) => sum + s.questionCount),
    exam.totalQuestions,
  );
  final start = find.byKey(ValueKey('exam-start-$id'));
  final card = find.ancestor(of: start, matching: find.byType(Card)).first;
  expect(
    find.descendant(
      of: card,
      matching: find.text(exam.name(LanguageService.instance.isTurkish)),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: card,
      matching: find.text(_l10n.examSubjectQuestions(exam.totalQuestions)),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: card,
      matching: find.text('${seconds ~/ 60} ${_l10n.minutesUnit}'),
    ),
    findsOneWidget,
  );
  await tapOn(tester, start);
  await pumpUntil(tester, find.text(_l10n.examRulesTitle));
  expect(find.text(_l10n.examRulesBody), findsOneWidget);
  await tapOn(
    tester,
    find.widgetWithText(FilledButton, _l10n.examReady),
    settle: Duration.zero,
  );
  for (final number in ['3', '2', '1']) {
    await pumpUntil(tester, find.text(number));
  }
  await pumpUntil(tester, find.byKey(const ValueKey('exam-countdown')));
  final service = ExamService.instance;
  await pumpUntilTrue(
    tester,
    () => service.activeRecord?.attempt != null,
    reason: 'server attempt saved for $id',
  );
  final attempt = service.activeRecord!.attempt!;
  expect(attempt.examId, id);
  expect(attempt.durationSeconds, seconds);
  expect(attempt.endsAt.difference(attempt.startedAt).inSeconds, seconds);
  expect(find.text(_l10n.examNoPause), findsOneWidget);
  expect(
    find.descendant(
      of: find.byType(ExamScreen),
      matching: find.byIcon(Icons.pause),
    ),
    findsNothing,
  );
  final owner = SupabaseService.instance.currentUser.value!.id!;
  final disk = (await ExamPersistence().read(
    owner,
  )).singleWhere((r) => r.clientUuid == attempt.clientUuid);
  expect(disk.attempt!.id, attempt.id);
  expect(disk.attempt!.startedAt, attempt.startedAt);
  expect(disk.attempt!.endsAt, attempt.endsAt);
  return attempt;
}

Future<void> _abandon(
  WidgetTester tester,
  ApiAccount account,
  ExamAttempt attempt,
) async {
  await tapOn(tester, find.widgetWithText(TextButton, _l10n.examAbandon));
  await pumpUntil(tester, find.text(_l10n.examAbandonTitle));
  await tapOn(tester, find.widgetWithText(FilledButton, _l10n.examAbandon));
  await pumpUntilGone(tester, find.byKey(const ValueKey('exam-countdown')));
  await tapOn(tester, find.byKey(const ValueKey('exam-tab-history')));
  expect(find.text(_l10n.examAbandoned), findsWidgets);
  expect(find.text(_l10n.examNoAward), findsWidgets);
  final row = (await E2eHost.row(
    'select status,started_at,ends_at,finished_at,'
    'elapsed_seconds,points_earned,exam_coins_earned from public.exam_attempts '
    'where id=${sqlText(attempt.id)} and user_id=${sqlText(account.id)}',
  ))!;
  expect(row['status'], 'abandoned');
  expect(row['finished_at'], isNotNull);
  expect(row['elapsed_seconds'], greaterThanOrEqualTo(0));
  expect(row['points_earned'], 0);
  expect(row['exam_coins_earned'], 0);
  expect(
    DateTime.parse(row['started_at'] as String),
    attempt.startedAt.toUtc(),
  );
  expect(DateTime.parse(row['ends_at'] as String), attempt.endsAt.toUtc());
}

Future<void> _examBlocksFocus(
  WidgetTester tester,
  ApiAccount account,
  ExamAttempt attempt,
) async {
  Object? failure;
  try {
    await LocalApi.rpc('start_study_session', account, {
      'p_duration_minutes': 25,
      'p_category_name': 'Matematik',
    });
  } catch (e) {
    failure = e;
  }
  expect(failure, isA<LocalApiError>());
  expect(failure.toString(), contains('exam_overlap'));
  await _tab(tester, 0);
  await tapOn(tester, find.byKey(const ValueKey('timer-start-pause')));
  await pumpUntil(
    tester,
    find.text(_l10n.examConflict),
    timeout: const Duration(seconds: 15),
  );
  expect(await TimerPersistence.instance.load(account.id), isNull);
  expect(ExamService.instance.activeRecord!.attempt!.id, attempt.id);
  final planner = find.byKey(const ValueKey('marathon-open-planner'));
  await tapOn(tester, planner);
  await pumpUntil(
    tester,
    find.byKey(const ValueKey('marathon-planner-dialog')),
  );
  await tapOn(tester, find.byKey(const ValueKey('marathon-count-2')));
  await tapOn(tester, find.byKey(const ValueKey('marathon-start')));
  await pumpUntil(
    tester,
    find.text(_l10n.examConflict),
    timeout: const Duration(seconds: 15),
  );
  expect(await TimerPersistence.instance.load(account.id), isNull);
  expect(
    (await E2eHost.row(
      'select count(*)::int as count from public.marathon_runs '
      'where user_id=${sqlText(account.id)}',
    ))!['count'],
    0,
  );
  await _tab(tester, 4);
}

Future<void> _reverseFocusConflict(
  WidgetTester tester,
  ApiAccount account, {
  required bool marathon,
}) async {
  await _tab(tester, 0);
  if (marathon) {
    await tapOn(tester, find.byKey(const ValueKey('marathon-open-planner')));
    await pumpUntil(
      tester,
      find.byKey(const ValueKey('marathon-planner-dialog')),
    );
    await tapOn(tester, find.byKey(const ValueKey('marathon-count-2')));
    await tapOn(tester, find.byKey(const ValueKey('marathon-start')));
  } else {
    await tapOn(tester, find.byKey(const ValueKey('timer-start-pause')));
  }
  await _until(
    tester,
    () async =>
        (await TimerPersistence.instance.load(account.id))?.isRunning == true,
    reason: 'normal/Marathon real focus is durable',
  );
  final focus = (await TimerPersistence.instance.load(account.id))!;
  expect(focus.marathon != null, marathon);
  await _catalog(tester);
  await tapOn(tester, find.byKey(const ValueKey('exam-start-tyt')));
  await pumpUntil(tester, find.text(_l10n.examConflict));
  expect(ExamService.instance.activeRecord, isNull);
  expect(
    (await TimerPersistence.instance.load(account.id))!.clientUuid,
    focus.clientUuid,
  );
  await _tab(tester, 0);
  await tapOn(
    tester,
    marathon
        ? find.byKey(const ValueKey('marathon-stop'))
        : find.widgetWithText(TextButton, _l10n.timerResetBtn),
  );
  await pumpUntil(
    tester,
    find.text(
      marathon ? _l10n.marathonStopConfirmTitle : _l10n.timerResetConfirmTitle,
    ),
  );
  final confirmation = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(
      TextButton,
      marathon
          ? _l10n.marathonStopConfirmAction
          : _l10n.timerResetConfirmAction,
    ),
  );
  expect(confirmation, findsOneWidget);
  await tapOn(tester, confirmation);
  await _until(
    tester,
    () async => await TimerPersistence.instance.load(account.id) == null,
    reason: 'uncompleted focus explicitly cancelled without reward',
  );
}

Future<void> _untilNaturallyCompleted(
  WidgetTester tester,
  ExamAttempt started,
) async {
  expect(started.durationSeconds, 60);
  final at = DateTime.now();
  await _until(
    tester,
    () async => ExamService.instance.attempts.any(
      (a) => a.id == started.id && a.isCompleted,
    ),
    reason: 'server minute must elapse naturally',
    // HTTP Date has one-second precision. An early server rejection remains
    // durable and the service retries pending completion every 30 seconds.
    timeout: const Duration(seconds: 120),
  );
  final completed = ExamService.instance.attempts.singleWhere(
    (a) => a.id == started.id,
  );
  expect(completed.endsAt, started.endsAt);
  expect(completed.startedAt, started.startedAt);
  expect(DateTime.now().difference(at).inSeconds, greaterThanOrEqualTo(52));
  expect(ExamService.instance.activeRecord, isNull);
  expect(find.text(_l10n.examEnterResults), findsWidgets);
}

Future<Map<String, dynamic>> _subjectRow(
  String attempt,
  String subject,
) async => (await E2eHost.row(
  'select correct,wrong,blank,net::float,updated_at '
  'from public.exam_subject_results where attempt_id=${sqlText(attempt)} '
  'and subject_id=${sqlText(subject)}',
))!;

Future<void> _netJourney(
  WidgetTester tester,
  ApiAccount account,
  ExamAttempt attempt, {
  required bool offline,
}) async {
  final exam = ExamService.instance.definitionFor(attempt)!;
  final first = exam.subjects.first;
  final economy = await _economy(account.id);
  await tapOn(
    tester,
    find.widgetWithText(TextButton, _l10n.examEnterResults).first,
  );
  await pumpUntil(tester, find.byKey(ValueKey('exam-result-${first.id}-0')));
  await _field(tester, first.id, 0, '${first.questionCount + 1}');
  await tapOn(tester, find.widgetWithText(FilledButton, _l10n.examSaveResults));
  await pumpUntil(tester, find.text(_l10n.examResultsInvalid));
  expect(
    await E2eHost.rows(
      'select subject_id from public.exam_subject_results where attempt_id=${sqlText(attempt.id)}',
    ),
    isEmpty,
  );
  await _field(tester, first.id, 0, '-1');
  expect(_fieldText(tester, first.id, 0), '-1');
  await tapOn(tester, find.widgetWithText(FilledButton, _l10n.examSaveResults));
  await pumpUntil(tester, find.text(_l10n.examResultsInvalid));
  await _field(tester, first.id, 0, '${first.questionCount - 2}');
  await _field(tester, first.id, 1, '1');
  expect(
    _fieldText(tester, first.id, 2),
    '1',
    reason: 'blank recalculates from correct and wrong',
  );
  await _field(tester, first.id, 2, '2');
  expect(
    _fieldText(tester, first.id, 2),
    '2',
    reason: 'blank remains manually editable',
  );
  await tapOn(tester, find.widgetWithText(FilledButton, _l10n.examSaveResults));
  await pumpUntil(tester, find.text(_l10n.examResultsInvalid));
  await _field(tester, first.id, 2, '1');
  await tapOn(tester, find.widgetWithText(FilledButton, _l10n.examSaveResults));
  await pumpUntilGone(tester, find.byType(AlertDialog));
  final partial = await _subjectRow(attempt.id, first.id);
  expect(partial['correct'], first.questionCount - 2);
  expect(partial['wrong'], 1);
  expect(partial['blank'], 1);
  expect(
    partial['net'],
    closeTo(first.questionCount - 2 - 1 / exam.wrongAnswerDivisor, .0000001),
  );
  expect(
    (await E2eHost.rows(
      'select subject_id from public.exam_subject_results '
      'where attempt_id=${sqlText(attempt.id)}',
    )).length,
    1,
    reason:
        'only the dirty subject is submitted; untouched subjects stay missing',
  );
  // UI partial entry now also produces a partial RPC: untouched rows are absent.
  await tapOn(
    tester,
    find.widgetWithText(TextButton, _l10n.examEditResults).first,
  );
  for (final subject in exam.subjects) {
    await _field(tester, subject.id, 0, '${subject.questionCount - 3}');
    await _field(tester, subject.id, 1, '2');
    expect(_fieldText(tester, subject.id, 2), '1');
    expect(
      find.text(
        '${_l10n.examNet}: ${formatExamNet(subject.questionCount - 3 - 2 / exam.wrongAnswerDivisor, _l10n.localeName)}',
      ),
      findsWidgets,
    );
  }
  if (offline) {
    expect(
      kE2eHttpProxy,
      isTrue,
      reason: 'explicit local proxy required for offline net check',
    );
    await setLocalHttpProxyAvailable(false);
  }
  try {
    await tapOn(
      tester,
      find.widgetWithText(FilledButton, _l10n.examSaveResults),
    );
    await pumpUntilGone(tester, find.byType(AlertDialog));
    if (offline) {
      await pumpUntil(tester, find.text(_l10n.examQueuedResults));
      final record = ExamService.instance.records.singleWhere(
        (r) => r.clientUuid == attempt.clientUuid,
      );
      expect(record.pendingAction, ExamPendingAction.results);
      expect(
        (await _subjectRow(attempt.id, first.id))['correct'],
        partial['correct'],
      );
      await E2eHost.screenshot(
        tester,
        'e2e-ad-net-offline-${_l10n.localeName}',
      );
    }
  } finally {
    if (offline) await setLocalHttpProxyAvailable(true);
  }
  if (offline) {
    await ExamService.instance.retry(attempt.clientUuid);
  }
  await _until(tester, () async {
    final row = await _subjectRow(attempt.id, first.id);
    return row['correct'] == first.questionCount - 3;
  }, reason: 'latest edited net persisted after retry');
  final rows = await E2eHost.rows(
    'select subject_id,correct,wrong,blank,net::float,updated_at '
    'from public.exam_subject_results where attempt_id=${sqlText(attempt.id)}',
  );
  expect(rows.length, exam.subjects.length);
  for (final subject in exam.subjects) {
    final row = rows.singleWhere((r) => r['subject_id'] == subject.id);
    expect(row['correct'], subject.questionCount - 3);
    expect(row['wrong'], 2);
    expect(row['blank'], 1);
    expect(
      row['net'],
      closeTo(
        subject.questionCount - 3 - 2 / exam.wrongAnswerDivisor,
        .0000001,
      ),
    );
    expect(row['updated_at'], isNotNull);
  }
  expect(
    await _economy(account.id),
    economy,
    reason: 'net edit cannot change any economy/streak/time value',
  );
  await E2eHost.screenshot(
    tester,
    'e2e-ad-nets-${attempt.examId.replaceAll('_', '-')}-${_l10n.localeName}',
  );
}

Future<Map<String, dynamic>> _independentReport(String owner) async {
  final host = const String.fromEnvironment(
    'E2E_HOST_ADDRESS',
    defaultValue: '127.0.0.1',
  );
  expect({'127.0.0.1', '10.0.2.2'}.contains(host), isTrue);
  final uri = Uri(
    scheme: 'http',
    host: host,
    port: kE2eHostPort,
    path: '/verify-reports',
    queryParameters: {'owner': owner},
  );
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final response = await (await http.getUrl(
      uri,
    )).close().timeout(const Duration(seconds: 30));
    final raw = await utf8.decodeStream(response);
    expect(
      response.statusCode,
      200,
      reason: 'independent fixed local verifier endpoint',
    );
    final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    expect(data['schema_version'], 1);
    expect(data['status'], 'PASS');
    return data;
  } finally {
    http.close(force: true);
  }
}

void _verifyRangeWidgets(
  WidgetTester tester,
  Finder scope,
  List<StatSession> sessions,
  Map<String, dynamic> report, {
  required bool monthly,
}) {
  final first = DateTime.parse(report['start'] as String);
  final last = DateTime.parse(report['end'] as String);
  final ranged = sessionsBetween(sessions, first, last).toList();
  expect(
    sumMinutes(ranged),
    report['total_minutes'],
    reason: 'native report inputs equal independently recomputed DB duration',
  );
  expect(
    sessions.any((s) => s.pending),
    isFalse,
    reason:
        'this comparison is accepted history; offline queue must already be delivered',
  );
  final expectedCounts = Map<String, dynamic>.from(report['counts'] as Map);
  final summaryFinder = find.descendant(
    of: scope,
    matching: find.byType(SessionTypeSummary),
  );
  expect(summaryFinder, findsOneWidget);
  final actual = tester.widget<SessionTypeSummary>(summaryFinder).counts;
  expect(actual.normalSessions, expectedCounts['normal_sessions']);
  expect(
    actual.marathonFocusSessions,
    expectedCounts['marathon_focus_sessions'],
  );
  expect(actual.completedMarathons, expectedCounts['completed_marathons']);
  expect(actual.completedExams, expectedCounts['completed_exams']);
  expect(actual.focusEquivalents, report['focus_equivalents']);
  for (final pair in [
    (_l10n.statsNormalSessions, expectedCounts['normal_sessions']),
    (_l10n.statsCompletedMarathons, expectedCounts['completed_marathons']),
    (_l10n.statsCompletedExams, expectedCounts['completed_exams']),
  ]) {
    expect(
      find.descendant(
        of: summaryFinder,
        matching: find.text('${pair.$1}: ${pair.$2}'),
      ),
      findsOneWidget,
    );
  }
  expect(
    find.descendant(
      of: summaryFinder,
      matching: find.text(
        _l10n.statsMarathonFocusCount(actual.marathonFocusSessions),
      ),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: summaryFinder,
      matching: find.text(_l10n.statsFocusEquivalent(actual.focusEquivalents)),
    ),
    findsOneWidget,
  );
  final categories = totalsByCategory(ranged);
  final minutes = <String, int>{
    for (final c in categories)
      (c.key.startsWith('id:') ? c.key.substring(3) : c.key): c.minutes,
  };
  expect(minutes, Map<String, dynamic>.from(report['category_minutes'] as Map));
  final percentages = roundedPercents(
    categories.map((c) => c.minutes).toList(),
  );
  expect({
    for (var i = 0; i < categories.length; i++)
      (categories[i].key.startsWith('id:')
              ? categories[i].key.substring(3)
              : categories[i].key):
          percentages[i],
  }, Map<String, dynamic>.from(report['category_percentages'] as Map));
  final days = dailyTotals(sessions, first, last);
  expect(
    {for (final d in days) d.day.toIso8601String().substring(0, 10): d.minutes},
    {
      for (final row in report['days'] as List)
        (row as Map)['day']: row['minutes'],
    },
  );
  if (monthly) {
    // The monthly view renders daily heatmap labels, not a monthly goal ring.
    final formatter = DateFormat('d MMMM', StatsText.dateLocale);
    for (final day in days) {
      final label =
          '${formatter.format(day.day)}: '
          '${day.minutes > 0 ? StatsText.duration(day.minutes) : tr('no_study_this_day')}';
      expect(
        find.descendant(
          of: scope,
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == label,
          ),
        ),
        findsWidgets,
      );
    }
  } else {
    final context = tester.element(scope);
    expect(
      find.descendant(
        of: scope,
        matching: find.text(
          StatsText.percent(context, report['efficiency'] as int),
        ),
      ),
      findsWidgets,
    );
    final ringProgress = (report['goal_percentage'] as int) / 100;
    final painters = find
        .descendant(of: scope, matching: find.byType(CustomPaint))
        .evaluate()
        .map((e) => (e.widget as CustomPaint).painter)
        .whereType<ProgressRingPainter>();
    expect(
      painters.any((p) => (p.progress - ringProgress).abs() < .011),
      isTrue,
      reason: 'painted goal/efficiency ring agrees with independent DB target',
    );
  }
}

Future<void> _verifyReports(WidgetTester tester, String owner) async {
  await _tab(tester, 1);
  await tapOn(tester, find.text(tr('reports_tab_subject')));
  await pumpUntil(tester, find.byType(DailyReportView));
  await tester
      .widget<DailyReportView>(find.byType(DailyReportView))
      .onRefresh();
  final reference = await _independentReport(owner);
  final reports = Map<String, dynamic>.from(
    (reference['expected'] as Map)['reports'] as Map,
  );
  await _until(tester, () async {
    await tester.pump();
    final w = tester.widget<DailyReportView>(find.byType(DailyReportView));
    return sumMinutesBetween(w.sessions, w.today, w.today) ==
        (reports['daily'] as Map)['total_minutes'];
  }, reason: 'native refreshed daily history matches independent snapshot');
  final daily = tester.widget<DailyReportView>(find.byType(DailyReportView));
  expect(daily.dailyGoalMinutes, (reports['daily'] as Map)['goal_minutes']);
  _verifyRangeWidgets(
    tester,
    find.byType(DailyReportView),
    daily.sessions,
    Map<String, dynamic>.from(reports['daily'] as Map),
    monthly: false,
  );
  await Scrollable.ensureVisible(
    tester.element(find.byType(SessionTypeSummary)),
  );
  await E2eHost.screenshot(tester, 'e2e-ad-daily-${_l10n.localeName}');
  await tapOn(tester, find.text(tr('reports_tab_history')));
  await pumpUntil(tester, find.byType(HistoryScreen));
  final week = tester.widget<HistoryScreen>(find.byType(HistoryScreen));
  expect(week.dailyGoalMinutes * 7, (reports['weekly'] as Map)['goal_minutes']);
  _verifyRangeWidgets(
    tester,
    find.byType(HistoryScreen),
    week.sessions,
    Map<String, dynamic>.from(reports['weekly'] as Map),
    monthly: false,
  );
  await Scrollable.ensureVisible(
    tester.element(find.byType(SessionTypeSummary)),
  );
  await E2eHost.screenshot(tester, 'e2e-ad-weekly-${_l10n.localeName}');
  await tapOn(tester, find.text(tr('reports_tab_monthly')));
  await pumpUntil(tester, find.byType(MonthlyTrackingScreen));
  final month = tester.widget<MonthlyTrackingScreen>(
    find.byType(MonthlyTrackingScreen),
  );
  _verifyRangeWidgets(
    tester,
    find.byType(MonthlyTrackingScreen),
    month.sessions,
    Map<String, dynamic>.from(reports['monthly'] as Map),
    monthly: true,
  );
  await E2eHost.screenshot(tester, 'e2e-ad-monthly-${_l10n.localeName}');
  expect(tester.takeException(), isNull);
  debugPrint(
    '[AD_REPORTS] owner=$owner lang=${_l10n.localeName} DB/UI daily weekly monthly PASS ${jsonEncode(reports)}',
  );
}

void main() {
  initE2e();
  testWidgets(
    'ad1 · official seven exam catalogues and abandonment matrix TR EN',
    (tester) async {
      await _guardCompletedDeviceProbes();
      await _cancelKnownPriorOfficialFocus(tester);
      final account = await openShellWithNewAccount(
        tester,
        'verify-official',
        name: 'QA Exam Matrix',
      );
      await NotificationService.instance.setEnabled(false);
      final baseline = await _economy(account.id);
      for (final language in ['tr', 'en']) {
        await _language(tester, language);
        for (final entry in _metadata.entries) {
          final attempt = await _start(
            tester,
            entry.key,
            seconds: entry.value.$1,
          );
          Object? early;
          try {
            await LocalApi.rpc('complete_exam_attempt', account, {
              'p_attempt_id': attempt.id,
            });
          } catch (error) {
            early = error;
          }
          expect(early, isA<LocalApiError>());
          expect(early.toString(), contains('exam_not_elapsed'));
          if (entry.key == 'tyt') {
            await _examBlocksFocus(tester, account, attempt);
            await launchApp(tester); // Widget-tree reconstruction, not OS kill.
            await pumpUntil(tester, find.byType(MainNavigationShell));
            await _tab(tester, 4);
            await pumpUntil(
              tester,
              find.byKey(const ValueKey('exam-countdown')),
            );
            expect(ExamService.instance.activeRecord!.attempt!.id, attempt.id);
            expect(
              ExamService.instance.activeRecord!.attempt!.endsAt,
              attempt.endsAt,
            );
          }
          await _abandon(tester, account, attempt);
          expect(await _economy(account.id), baseline);
          debugPrint(
            '[AD_OFFICIAL] $language ${entry.key} duration=${entry.value.$1} questions=${entry.value.$2} abandoned no-award PASS',
          );
        }
        await E2eHost.screenshot(tester, 'e2e-ad-official-history-$language');
      }
      await _reverseFocusConflict(tester, account, marathon: false);
      await _reverseFocusConflict(tester, account, marathon: true);
      expect(await _economy(account.id), baseline);
      final rows = await E2eHost.rows(
        'select status,points_earned,exam_coins_earned from public.exam_attempts where user_id=${sqlText(account.id)}',
      );
      expect(rows.length, 14);
      expect(
        rows.every(
          (r) =>
              r['status'] == 'abandoned' &&
              r['points_earned'] == 0 &&
              r['exam_coins_earned'] == 0,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      debugPrint(
        '[AD_OFFICIAL] owner=${account.id} all14 attempts and bidirectional normal/Marathon conflict PASS',
      );
    },
    skip: _phase != 'official',
    timeout: const Timeout(Duration(minutes: 12)),
  );

  testWidgets(
    'ad2 · fourteen natural local60 exams and all-subject net entry TR EN',
    (tester) async {
      await _guardCompletedDeviceProbes();
      expect(
        kE2eHttpProxy,
        isTrue,
        reason: 'run short matrix through local503 proxy',
      );
      final account = await openShellWithNewAccount(
        tester,
        'verify-short',
        name: 'QA Natural Minute',
      );
      await NotificationService.instance.setEnabled(false);
      for (final language in ['tr', 'en']) {
        await _language(tester, language);
        for (final id in _metadata.keys) {
          final before = await _economy(account.id);
          final expected = (await E2eHost.row(
            'select (definition->>\'reward_points\')::int as points,'
            '(definition->>\'reward_coins\')::int as coins from public.exam_catalog where id=${sqlText(id)}',
          ))!;
          final started = await _start(tester, id, seconds: 60);
          await _untilNaturallyCompleted(tester, started);
          final completed = ExamService.instance.attempts.singleWhere(
            (a) => a.id == started.id,
          );
          expect(completed.pointsEarned, expected['points']);
          expect(completed.examCoinsEarned, expected['coins']);
          final after = await _economy(account.id);
          expect(after['total_minutes'], (before['total_minutes'] as int) + 1);
          expect(
            after['exam_points'],
            (before['exam_points'] as int) + (expected['points'] as int),
          );
          expect(
            after['exam_coins'],
            (before['exam_coins'] as int) + (expected['coins'] as int),
          );
          expect(after['lifetime_points'], before['lifetime_points']);
          expect(after['coins'], before['coins']);
          final duplicate =
              await LocalApi.rpc('complete_exam_attempt', account, {
                    'p_attempt_id': started.id,
                  })
                  as Map;
          expect(duplicate['duplicate'], isTrue);
          expect(await _economy(account.id), after);
          await _netJourney(
            tester,
            account,
            completed,
            offline: id == 'lgs_quantitative',
          );
          debugPrint(
            '[AD_SHORT] $language $id real60 server-minute and editable-net/no-economy-change PASS',
          );
        }
      }
      final data = await _independentReport(account.id);
      expect((data['expected'] as Map)['reports'], isA<Map>());
      expect(tester.takeException(), isNull);
      debugPrint(
        '[AD_SHORT] owner=${account.id} fourteen natural60 completed, no clock/history mutation',
      );
    },
    skip: _phase != 'short',
    timeout: const Timeout(Duration(minutes: 45)),
  );
  testWidgets(
    'ad3 · mixed-history reports independently match DB TR EN',
    (tester) async {
      await _guardCompletedDeviceProbes();
      expect(
        _fixtureEmail.startsWith('e2e-sim-') &&
            _fixtureEmail.endsWith('@pomosprint.local'),
        isTrue,
        reason: 'only explicitly selected local QA mixed-history owner',
      );
      await resetAppState(tester);
      await launchApp(tester);
      await waitPastSplash(tester);
      await loginViaUi(tester, _fixtureEmail);
      await pumpUntil(tester, find.byType(MainNavigationShell));
      final owner = SupabaseService.instance.currentUser.value!.id!;
      final before = await _economy(owner);
      await NotificationService.instance.setEnabled(false);
      for (final language in ['tr', 'en']) {
        await _language(tester, language);
        await _verifyReports(tester, owner);
      }
      expect(
        await _economy(owner),
        before,
        reason: 'report and language viewing must not change any ledger',
      );
    },
    skip: _phase != 'reports',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
