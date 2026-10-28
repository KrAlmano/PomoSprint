// Opt-in SAME-account journey: native registration -> local Mailpit -> native
// login -> TUS onboarding -> one REAL 25-minute focus -> TUS start/abandon.
// No fixture, clock edit, shortened duration, SQL write or account cleanup.
// --dart-define=E2E_FIRST_USE_REAL25=true --dart-define=E2E_RUN_ID=<unique-id>
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/models/study_session.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/screens/history_screen.dart';
import 'package:pomodoro/screens/monthly_tracking_screen.dart';
import 'package:pomodoro/screens/post_auth_onboarding_screen.dart';
import 'package:pomodoro/screens/register_screen.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/onboarding_categories.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/e2e.dart';

const _enabled = bool.fromEnvironment('E2E_FIRST_USE_REAL25');
const _run = String.fromEnvironment('E2E_RUN_ID');
String get _email => 'e2e-sim-first-use-$_run@pomosprint.local';
String get _marker => 'e2e_first_use_real25_$_run';

void _mark(String phase) => debugPrint(
  '[FIRST_USE] ${DateTime.now().toUtc().toIso8601String()} $phase',
);

Future<void> _until(
  WidgetTester tester,
  Future<bool> Function() condition, {
  required String phase,
  Duration timeout = const Duration(seconds: 45),
}) async {
  final watch = Stopwatch()..start();
  var logged = Duration.zero;
  while (watch.elapsed < timeout) {
    if (await condition()) {
      _mark('$phase complete after ${watch.elapsed.inSeconds}s');
      return;
    }
    expect(tester.takeException(), isNull, reason: phase);
    if (watch.elapsed - logged >= const Duration(seconds: 30)) {
      logged = watch.elapsed;
      _mark('$phase elapsed=${watch.elapsed.inSeconds}s');
    }
    await tester.pump(const Duration(seconds: 1));
  }
  fail('$phase did not finish within ${timeout.inSeconds} real seconds');
}

Future<void> _guardBeforeReset(SharedPreferences prefs) async {
  // A malformed journal also fails closed. Never erase another run's evidence
  // just to prepare this new registration scenario.
  for (final key in prefs.getKeys()) {
    if (key.startsWith('e2e_real_duration_probe_') ||
        key.startsWith('e2e_normal_http_restart_') ||
        key.startsWith('e2e_first_use_real25_')) {
      final value = jsonDecode(prefs.getString(key)!) as Map;
      expect(
        value['completion_verified'],
        isTrue,
        reason: 'An unfinished native probe owns this installation: $key',
      );
    }
    if (key.startsWith('active_session_uid_')) {
      expect(
        prefs.getString(key),
        isNull,
        reason: 'Existing timer must not be cleared by a new-account test',
      );
    }
    if (key.startsWith('exam_journal_uid_')) {
      final rows = jsonDecode(prefs.getString(key)!) as List;
      for (final raw in rows) {
        final record = ExamLocalRecord.fromJson(raw);
        expect(record, isNotNull, reason: 'Preserve malformed exam journal');
        expect(
          record!.pendingAction,
          isNull,
          reason: 'Preserve pending exam operation',
        );
        expect(
          record.attempt?.status,
          isNot(ExamAttemptStatus.active),
          reason: 'Preserve active exam',
        );
      }
    }
    if (key.startsWith('pending_sessions_')) {
      expect(
        jsonDecode(prefs.getString(key)!),
        isEmpty,
        reason: 'Preserve another owner\'s unsent study sessions',
      );
    }
  }
  expect(
    prefs.containsKey(_marker),
    isFalse,
    reason: 'Use a new run ID; do not overwrite this journey',
  );
  final existing = await E2eHost.row(
    'select count(*)::integer as count from auth.users where email=${sqlText(_email)}',
  );
  expect(existing!['count'], 0, reason: 'Registration requires a new email');
}

Future<void> _tab(WidgetTester tester, int index) async {
  if (find.byType(NavigationBar).evaluate().isNotEmpty) {
    await openTab(tester, index);
  } else {
    tester
        .widget<NavigationRail>(find.byType(NavigationRail))
        .onDestinationSelected!(index);
    await pumpFor(tester, const Duration(milliseconds: 600));
  }
}

Future<int> _onboardTus(WidgetTester tester) async {
  final l10n = trL10n;
  await pumpUntil(tester, find.byKey(const ValueKey('onboarding-language-tr')));
  await tapOn(tester, find.byKey(const ValueKey('onboarding-language-tr')));
  await tapOn(
    tester,
    find.byKey(const ValueKey('onboarding-language-continue')),
  );
  await pumpUntil(tester, find.byType(PostAuthOnboardingScreen));
  final picker = find.byType(CupertinoPicker);
  await tester.timedDrag(
    picker,
    const Offset(0, -52.0 * 20),
    const Duration(milliseconds: 1500),
  );
  await pumpFor(tester, const Duration(seconds: 2));
  final index = tester
      .widget<CupertinoPicker>(picker)
      .scrollController!
      .selectedItem;
  expect(index, greaterThan(13));
  final birthYear = DateTime.now().year - (index - 1);
  await tapOn(tester, find.text(l10n.continueBtn));
  await pumpUntil(tester, find.text(l10n.onboardingSegmentTitle));
  await tapOn(tester, find.text(l10n.onboardingSegmentTus));
  await tapOn(tester, find.text(l10n.continueBtn));
  await pumpUntil(tester, find.text(l10n.onboardingCategoryStepPreparedTitle));
  final expected = autoSelectedCategoryNames('tus', kept: const [], limit: 8);
  expect([
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)))
      if (chip.selected) (chip.label as Text).data,
  ], expected);
  await E2eHost.screenshot(tester, 'e2e-first-use-tus-categories');
  await tapOn(tester, find.text(l10n.continueBtn));
  await pumpUntil(tester, find.text(l10n.onboardingVisibilityYes));
  await tapOn(tester, find.text(l10n.onboardingVisibilityYes));
  await tapOn(tester, find.text(l10n.continueBtn));
  await pumpUntil(tester, find.text(l10n.gameRulesTitle));
  await tapOn(tester, find.text(l10n.continueBtn));
  await pumpUntil(tester, find.text(l10n.onboardingGoal2h));
  await tapOn(tester, find.text(l10n.onboardingGoal2h));
  await tapOn(tester, find.text(l10n.continueBtn));
  await pumpUntil(tester, find.text(l10n.onboardingGuideTitle));
  for (final body in [
    l10n.onboardingGuidePomoBody,
    l10n.onboardingGuideMarathonBody,
    l10n.onboardingGuideExamBody,
    l10n.onboardingGuideInsightsBody,
    l10n.onboardingGuideReportsBody,
    l10n.onboardingGuideRankingBody,
    l10n.onboardingGuideSocialBody,
    l10n.onboardingGuideProfileBody,
  ]) {
    expect(find.text(body), findsOneWidget);
  }
  await tester.ensureVisible(find.text(l10n.onboardingGuideProfileBody));
  await E2eHost.screenshot(tester, 'e2e-first-use-guide');
  await tapOn(
    tester,
    find.widgetWithText(ElevatedButton, l10n.onboardingFinishBtn),
  );
  await pumpUntil(tester, find.byType(MainNavigationShell));
  await pumpUntil(tester, find.byType(TimerScreen));
  expect(find.text(l10n.onboardingSaveError), findsNothing);
  return birthYear;
}

Future<Map<String, dynamic>> _economy(String owner) async => (await E2eHost.row(
  'select p.total_minutes,p.lifetime_points,p.coins,p.current_streak,'
  'p.last_study_date::text,p.timezone,coalesce(w.coins,0) as exam_coins,'
  'coalesce(w.lifetime_points,0) as exam_points from public.profiles p '
  'left join public.exam_wallets w on w.user_id=p.id where p.id=${sqlText(owner)}',
))!;

Future<void> _reportRange(
  String owner,
  List<StatSession> sessions,
  DateTime first,
  DateTime last,
) async {
  String day(DateTime value) =>
      sqlText(value.toIso8601String().substring(0, 10));
  final expected = (await E2eHost.row(
    'select count(*)::integer as count,coalesce(sum(s.duration_minutes),0)::integer as minutes '
    'from public.study_sessions s join public.profiles p on p.id=s.user_id '
    'where s.user_id=${sqlText(owner)} and '
    "((s.started_at at time zone p.timezone)-interval '4 hours')::date "
    'between ${day(first)}::date and ${day(last)}::date',
  ))!;
  expect(sumMinutesBetween(sessions, first, last), expected['minutes']);
  final counts = sessionTypeCounts(sessions, first, last);
  expect(counts.normalSessions, expected['count']);
  expect(counts.marathonFocusSessions, 0);
  expect(counts.completedExams, 0);
  expect(sessions.where((s) => s.kind == StudySessionKind.exam), isEmpty);
  expect(sessions.where((s) => s.pending), isEmpty);
  expect(sessions, hasLength(1));
  expect(sessions.single.minutes, 25);
}

Future<void> _reports(WidgetTester tester, String owner) async {
  await _tab(tester, 1);
  await tapOn(tester, find.text(tr('reports_tab_subject')));
  await pumpUntil(tester, find.byType(DailyReportView));
  await tester
      .widget<DailyReportView>(find.byType(DailyReportView))
      .onRefresh();
  await _until(
    tester,
    () async =>
        tester
            .widget<DailyReportView>(find.byType(DailyReportView))
            .sessions
            .length ==
        1,
    phase: 'report refresh',
  );
  final daily = tester.widget<DailyReportView>(find.byType(DailyReportView));
  await _reportRange(owner, daily.sessions, daily.today, daily.today);
  // A focus beginning before 04:00 belongs to yesterday even if it ends after
  // 04:00. Therefore the current daily card may correctly show zero minutes.
  await E2eHost.screenshot(tester, 'e2e-first-use-daily');
  await tapOn(tester, find.text(tr('reports_tab_history')));
  await pumpUntil(tester, find.byType(HistoryScreen));
  final weekly = tester.widget<HistoryScreen>(find.byType(HistoryScreen));
  await _reportRange(
    owner,
    weekly.sessions,
    mondayOf(weekly.today),
    addDays(mondayOf(weekly.today), 6),
  );
  await E2eHost.screenshot(tester, 'e2e-first-use-weekly');
  await tapOn(tester, find.text(tr('reports_tab_monthly')));
  await pumpUntil(tester, find.byType(MonthlyTrackingScreen));
  final monthly = tester.widget<MonthlyTrackingScreen>(
    find.byType(MonthlyTrackingScreen),
  );
  await _reportRange(
    owner,
    monthly.sessions,
    monthStartOf(monthly.today),
    monthEndOf(monthly.today),
  );
  await E2eHost.screenshot(tester, 'e2e-first-use-monthly');
  expect(tester.takeException(), isNull);
}

void main() {
  if (!_enabled) {
    test(
      'h · first-use real25 journey is opt-in',
      () {},
      skip: 'Set E2E_FIRST_USE_REAL25=true for the real 25-minute native run',
    );
    return;
  }
  initE2e();
  testWidgets(
    'h · one account registers, focuses 25 real minutes, then tries TUS',
    (tester) async {
      expect(
        RegExp(r'^[a-z0-9-]{1,40}$').hasMatch(_run),
        isTrue,
        reason: 'E2E_RUN_ID must be a unique bounded lowercase QA id',
      );
      expect(E2eHost.available, isTrue);
      final prefs = await SharedPreferences.getInstance();
      await _guardBeforeReset(prefs);
      await resetAppState(tester);
      await launchApp(tester);
      await waitPastSplash(tester);
      _mark('new account: native registration begins');
      await tapOn(tester, find.text(trL10n.signUpLink));
      await pumpUntil(tester, find.byType(RegisterScreen));
      final fields = find.descendant(
        of: find.byType(RegisterScreen),
        matching: find.byType(TextFormField),
      );
      expect(fields, findsNWidgets(3));
      await tester.enterText(fields.at(0), 'QA First Use');
      await tester.enterText(fields.at(1), _email);
      await tester.enterText(fields.at(2), kE2ePassword);
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpFor(tester, const Duration(milliseconds: 600));
      final checks = find.descendant(
        of: find.byType(RegisterScreen),
        matching: find.byType(Checkbox),
      );
      expect(checks, findsNWidgets(3));
      await tapOn(tester, checks.at(0));
      await tapOn(tester, checks.at(1));
      expect(tester.widget<Checkbox>(checks.at(2)).value, isFalse);
      await tapOn(
        tester,
        find.widgetWithText(ElevatedButton, trL10n.registerBtn),
        settle: const Duration(milliseconds: 200),
      );
      await pumpUntil(tester, find.text(trL10n.verificationSentTitle));
      final unconfirmed = (await E2eHost.row(
        'select id::text,email_confirmed_at is null as unconfirmed '
        'from auth.users where email=${sqlText(_email)}',
      ))!;
      expect(
        unconfirmed['unconfirmed'],
        isTrue,
        reason: 'The registration must actually require email confirmation',
      );
      final owner = unconfirmed['id'] as String;
      final proof = <String, dynamic>{
        'run_id': _run,
        'owner_id': owner,
        'stage': 'registered',
        'completion_verified': false,
        'uses_historical_fixture': false,
      };
      expect(await prefs.setString(_marker, jsonEncode(proof)), isTrue);
      await E2eHost.confirmEmail(_email);
      await tapOn(
        tester,
        find.widgetWithText(ElevatedButton, trL10n.backToLoginBtn),
      );
      await loginViaUi(tester, _email);
      await pumpUntilTrue(
        tester,
        () => Supabase.instance.client.auth.currentUser?.id == owner,
        reason: 'UI login retains the registered account',
      );
      _mark('Mailpit confirmation and native login complete');
      final birthYear = await _onboardTus(tester);
      final service = SupabaseService.instance;
      expect(service.currentUser.value?.id, owner);
      final registered = (await E2eHost.row(
        'select p.user_segment,p.birth_year,p.daily_goal_minutes,p.show_in_social_feed,'
        'p.onboarding_completed_at is not null as onboarded,'
        'u.email_confirmed_at is not null as confirmed,'
        "u.created_at>now()-interval '1 hour' as recent_owner "
        'from public.profiles p join auth.users u on u.id=p.id '
        'where p.id=${sqlText(owner)} and u.email=${sqlText(_email)}',
      ))!;
      expect(registered, {
        'user_segment': 'tus',
        'birth_year': birthYear,
        'daily_goal_minutes': 120,
        'show_in_social_feed': true,
        'onboarded': true,
        'confirmed': true,
        'recent_owner': true,
      });
      final categories = await E2eHost.rows(
        'select name from public.categories where user_id=${sqlText(owner)} '
        'and not is_archived order by sort_order,created_at,id',
      );
      expect([
        for (final category in categories) category['name'],
      ], autoSelectedCategoryNames('tus', kept: const [], limit: 8));
      await NotificationService.instance.setEnabled(false);
      final baseline = await _economy(owner);
      for (final key in [
        'total_minutes',
        'lifetime_points',
        'coins',
        'current_streak',
        'exam_coins',
        'exam_points',
      ]) {
        expect(baseline[key], 0, reason: 'new account baseline $key');
      }
      expect(await service.getPendingSessions(), isEmpty);
      expect(await service.getRejectedSessions(), isEmpty);
      await tapOn(tester, find.text('25 ${tr('minutes_unit_short')}'));
      final wall = Stopwatch()..start();
      await tapOn(tester, find.widgetWithText(ElevatedButton, tr('btn_start')));
      ActiveTimerSession? timer;
      await _until(tester, () async {
        timer = await TimerPersistence.instance.load(owner);
        return timer?.isRunning == true;
      }, phase: 'first real focus start');
      final started = timer!;
      expect(started.isQuickTest, isFalse);
      expect(started.recordAccelerated, isFalse);
      expect(started.marathon, isNull);
      expect(started.durationMinutes, 25);
      expect(started.totalSeconds, 1500);
      expect(
        started.endsAt!.difference(started.startedAt),
        const Duration(minutes: 25),
      );
      proof.addAll({
        'stage': 'focus_running',
        'client_uuid': started.clientUuid,
        'started_at': started.startedAt.toUtc().toIso8601String(),
        'ends_at': started.endsAt!.toUtc().toIso8601String(),
      });
      expect(await prefs.setString(_marker, jsonEncode(proof)), isTrue);
      await E2eHost.screenshot(tester, 'e2e-first-use-focus-start');
      // Each poll only reads local timer/outbox; SQL is used once after natural
      // completion. Stopwatch independently rejects a shortened focus run.
      await _until(
        tester,
        () async => await TimerPersistence.instance.load(owner) == null,
        phase: 'unmodified 1500-second focus',
        timeout: const Duration(minutes: 27),
      );
      expect(wall.elapsed, greaterThanOrEqualTo(const Duration(minutes: 25)));
      expect(DateTime.now().isBefore(started.endsAt!), isFalse);
      await _until(
        tester,
        () async =>
            service.currentUser.value?.lifetimePoints == 5 &&
            (await service.getPendingSessions()).isEmpty,
        phase: 'first focus server acceptance',
      );
      expect(await service.getRejectedSessions(), isEmpty);
      final rows = await E2eHost.rows(
        'select s.id::text,s.client_uuid::text,s.duration_minutes,s.base_points,s.bonus_points,'
        's.started_at,s.completed_at,'
        "((s.started_at at time zone p.timezone)-interval '4 hours')::date::text as expected_day,"
        "((s.completed_at at time zone p.timezone)-interval '4 hours')::date::text as completion_day "
        'from public.study_sessions s join public.profiles p on p.id=s.user_id '
        'where s.user_id=${sqlText(owner)}',
      );
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row['client_uuid'], started.clientUuid);
      expect(row['duration_minutes'], 25);
      expect(row['base_points'], 5);
      expect(row['bonus_points'], 0);
      final savedStart = DateTime.parse(row['started_at'] as String);
      final savedEnd = DateTime.parse(row['completed_at'] as String);
      expect(savedEnd.difference(savedStart), const Duration(minutes: 25));
      final offset = savedStart.difference(started.startedAt);
      expect(
        offset.inSeconds.abs(),
        lessThanOrEqualTo(5),
        reason: 'Local native/server deadlines stay within five seconds',
      );
      expect(savedEnd.difference(started.endsAt!), offset);
      final accepted = await _economy(owner);
      expect(accepted['total_minutes'], 25);
      expect(accepted['lifetime_points'], 5);
      expect(accepted['coins'], 20);
      expect(accepted['current_streak'], 1);
      expect(accepted['last_study_date'], row['expected_day']);
      expect(accepted['exam_coins'], 0);
      expect(accepted['exam_points'], 0);
      final events = await E2eHost.rows(
        'select e.kind,e.points,e.minutes,e.study_day::text,e.period_month::text,'
        "date_trunc('month',e.completed_at at time zone 'Europe/Istanbul')::date::text as expected_month "
        'from public.competition_events e where e.user_id=${sqlText(owner)}',
      );
      expect(events, hasLength(1));
      expect(events.single['kind'], 'study');
      expect(events.single['points'], 5);
      expect(events.single['minutes'], 25);
      expect(events.single['study_day'], row['expected_day']);
      expect(events.single['period_month'], events.single['expected_month']);
      proof.addAll({
        'stage': 'focus_complete',
        'observed_wall_seconds': wall.elapsed.inSeconds,
        'study_day': row['expected_day'],
        'crossed_04_boundary': row['expected_day'] != row['completion_day'],
        'period_month': events.single['period_month'],
      });
      expect(await prefs.setString(_marker, jsonEncode(proof)), isTrue);
      _mark('real25 accepted once: 25 minutes, 5 points, 20 sand, streak 1');
      await pumpUntil(
        tester,
        find.text(trL10n.sessionCompletedTitle),
        reason: 'normal focus completion dialog',
      );
      await pumpUntil(tester, find.text(trL10n.sessionResultPoints(5)));
      expect(find.text(trL10n.sessionResultCoins(20)), findsOneWidget);
      await E2eHost.screenshot(tester, 'e2e-first-use-focus-complete');
      await tapOn(
        tester,
        find.widgetWithText(ElevatedButton, trL10n.sessionCompletedOk),
      );
      await pumpUntilGone(tester, find.text(trL10n.sessionCompletedTitle));
      await _reports(tester, owner);

      final exams = ExamService.instance;
      await _tab(tester, 4);
      await pumpUntil(tester, find.byType(ExamScreen));
      await _until(
        tester,
        () async => exams.catalog.available && exams.backend.ownerId == owner,
        phase: 'same-owner exam catalog',
      );
      expect(exams.attempts, isEmpty);
      await tapOn(tester, find.byKey(const ValueKey('exam-start-tus_basic')));
      await pumpUntil(tester, find.text(trL10n.examRulesTitle));
      expect(find.text(trL10n.examRulesBody), findsOneWidget);
      await tapOn(
        tester,
        find.widgetWithText(FilledButton, trL10n.examReady),
        settle: Duration.zero,
      );
      for (final number in ['3', '2', '1']) {
        await pumpUntil(tester, find.text(number));
      }
      await _until(
        tester,
        () async => exams.activeRecord?.attempt != null,
        phase: 'same-owner first TUS start',
      );
      final attempt = exams.activeRecord!.attempt!;
      expect(attempt.examId, 'tus_basic');
      expect(attempt.durationSeconds, 8100);
      expect(
        attempt.endsAt.difference(attempt.startedAt),
        const Duration(seconds: 8100),
      );
      expect(
        (await ExamPersistence().read(owner)).single.attempt!.id,
        attempt.id,
      );
      final activeExam = (await E2eHost.row(
        'select status,started_at,ends_at,'
        "(definition->>'duration_seconds')::integer as duration_seconds,"
        'extract(epoch from ends_at-started_at)::integer as elapsed_deadline '
        'from public.exam_attempts where id=${sqlText(attempt.id)} '
        'and user_id=${sqlText(owner)}',
      ))!;
      expect(activeExam['status'], 'active');
      expect(activeExam['duration_seconds'], 8100);
      expect(activeExam['elapsed_deadline'], 8100);
      expect(
        DateTime.parse(activeExam['started_at'] as String),
        attempt.startedAt,
      );
      expect(DateTime.parse(activeExam['ends_at'] as String), attempt.endsAt);
      proof.addAll({
        'stage': 'exam_active',
        'attempt_id': attempt.id,
        'exam_started_at': attempt.startedAt.toIso8601String(),
        'exam_ends_at': attempt.endsAt.toIso8601String(),
      });
      expect(await prefs.setString(_marker, jsonEncode(proof)), isTrue);
      final account = ApiAccount(
        owner,
        _email,
        Supabase.instance.client.auth.currentSession!.accessToken,
      );
      Object? earlyError;
      try {
        await LocalApi.rpc('complete_exam_attempt', account, {
          'p_attempt_id': attempt.id,
        });
      } catch (error) {
        earlyError = error;
      }
      expect(earlyError, isA<LocalApiError>());
      expect(earlyError.toString(), contains('exam_not_elapsed'));
      await E2eHost.screenshot(tester, 'e2e-first-use-tus-start');
      await tapOn(tester, find.widgetWithText(TextButton, trL10n.examAbandon));
      await pumpUntil(tester, find.text(trL10n.examAbandonTitle));
      await tapOn(
        tester,
        find.widgetWithText(FilledButton, trL10n.examAbandon),
      );
      await _until(
        tester,
        () async =>
            exams.activeRecord == null &&
            exams.attempts.singleOrNull?.status == ExamAttemptStatus.abandoned,
        phase: 'native TUS abandon',
      );
      final abandoned = (await E2eHost.row(
        'select status,points_earned,exam_coins_earned,elapsed_seconds '
        'from public.exam_attempts where id=${sqlText(attempt.id)} and user_id=${sqlText(owner)}',
      ))!;
      expect(abandoned['status'], 'abandoned');
      expect(abandoned['elapsed_seconds'], greaterThan(0));
      expect(abandoned['points_earned'], 0);
      expect(abandoned['exam_coins_earned'], 0);
      expect(
        await _economy(owner),
        accepted,
        reason: 'Abandoned first exam preserves all accepted normal rewards',
      );
      expect(
        await E2eHost.rows(
          'select source_id from public.competition_events '
          'where user_id=${sqlText(owner)}',
        ),
        hasLength(1),
      );
      expect(
        await E2eHost.rows(
          'select id::text from public.study_sessions '
          'where user_id=${sqlText(owner)}',
        ),
        [
          {'id': row['id']},
        ],
      );
      expect(
        await E2eHost.rows(
          'select id::text from public.exam_attempts '
          'where user_id=${sqlText(owner)}',
        ),
        [
          {'id': attempt.id},
        ],
      );
      await tapOn(tester, find.byKey(const ValueKey('exam-tab-history')));
      await pumpUntil(tester, find.text(trL10n.examAbandoned));
      expect(find.text(trL10n.examNoAward), findsOneWidget);
      await E2eHost.screenshot(tester, 'e2e-first-use-tus-abandoned');
      await _reports(tester, owner);
      proof.addAll({
        'stage': 'complete',
        'completion_verified': true,
        'finished_at': DateTime.now().toUtc().toIso8601String(),
      });
      expect(await prefs.setString(_marker, jsonEncode(proof)), isTrue);
      expect(tester.takeException(), isNull);
      _mark(
        'PASS: same UI-registered owner completed the full first-use journey',
      );
      // Deliberately preserve account, server rows, auth and marker on both
      // success and failure. Do not clean up in a finally block.
    },
    timeout: const Timeout(Duration(minutes: 35)),
  );
}
