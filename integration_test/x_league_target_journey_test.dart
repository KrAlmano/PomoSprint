// Local controlled fixture only. Run change, stop the native process, then run
// resume with the same app data. The fixture contains completed historical
// normal/exam sessions; this is not proof of waiting their full durations.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/models/competition_target.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/screens/login_screen.dart';
import 'package:pomodoro/screens/ranking_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/widgets/app_logo.dart';
import 'package:pomodoro/widgets/competition_target_dialog.dart';
import 'package:pomodoro/widgets/league_info_sheet.dart';
import 'package:pomodoro/widgets/social/ranking_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/e2e.dart';

const _fixtureEmail = String.fromEnvironment('E2E_LEAGUE_FIXTURE_EMAIL');
const _phase = String.fromEnvironment(
  'E2E_LEAGUE_PHASE',
  defaultValue: 'change',
);
const _checkpointKey = 'e2e_league_target_journey_v1';

Future<void> _verifyLoginLogo(WidgetTester tester) async {
  final logo = find.byKey(const ValueKey('login-app-logo'));
  await pumpUntil(tester, logo, reason: 'native login logo');
  expect(tester.widget<AppLogo>(logo).size, 72);
  final frame = find.descendant(of: logo, matching: find.byType(RawImage));
  debugPrint('[LEAGUE_JOURNEY] waiting for decoded login logo frame');
  await pumpUntilTrue(
    tester,
    () {
      if (frame.evaluate().length != 1) return false;
      final decoded = tester.widget<RawImage>(frame).image;
      return decoded != null && decoded.width > 0 && decoded.height > 0;
    },
    reason: 'login logo has a decoded frame, not an empty image placeholder',
  );
  await Scrollable.ensureVisible(tester.element(logo), alignment: 0.25);
  await pumpFor(tester, const Duration(milliseconds: 300));
  final rect = tester.getRect(logo);
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(rect.width, 72);
  expect(rect.height, 72);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(size.height));
  expect(tester.takeException(), isNull);
  await E2eHost.screenshot(tester, 'e2e-league-login-logo-decoded');
}

Future<Map<String, dynamic>> _databaseState(
  String owner,
) async => (await E2eHost.row(
  'select p.user_segment,p.total_minutes,p.lifetime_points,p.coins,'
  'p.current_streak,p.league_tier,'
  'coalesce(w.coins,0) as exam_coins,'
  'coalesce(w.lifetime_points,0) as exam_points,'
  '(select count(*)::int from public.study_sessions s '
  'where s.user_id=p.id) as normal_rows,'
  '(select count(*)::int from public.exam_attempts a '
  "where a.user_id=p.id and a.status='completed') as exam_rows,"
  '(select coalesce(jsonb_agg(to_jsonb(m) order by m.kind,m.period_month),'
  "'[]'::jsonb) from public.competition_memberships m "
  'where m.user_id=p.id) as memberships,'
  '(select coalesce(jsonb_agg(to_jsonb(e) order by e.kind,e.source_id),'
  "'[]'::jsonb) from public.competition_events e "
  'where e.user_id=p.id) as events,'
  '(select coalesce(jsonb_agg(to_jsonb(h) order by h.from_month),'
  "'[]'::jsonb) from public.competition_target_history h "
  'where h.user_id=p.id) as target_history '
  'from public.profiles p left join public.exam_wallets w on w.user_id=p.id '
  'where p.id=${sqlText(owner)}',
))!;

Future<Map<String, dynamic>> _ranking(
  String owner,
  String kind,
  String scope,
) async {
  final value = await Supabase.instance.client.rpc(
    'get_monthly_league_ranking',
    params: {'p_kind': kind, 'p_scope': scope},
  );
  expect(Supabase.instance.client.auth.currentUser?.id, owner);
  expect(value, isA<Map>());
  final result = Map<String, dynamic>.from(value as Map);
  expect(result['kind'], kind);
  expect(result['scope'], scope);
  final rows = (result['rows'] as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .where((row) => row['is_me'] == true)
      .toList();
  expect(rows, hasLength(1));
  expect(rows.single['id'], owner);
  return {...result, 'own_points': rows.single['points']};
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

Future<void> _openStudyLeague(WidgetTester tester) async {
  await _tab(tester, 2);
  await pumpUntil(tester, find.byType(RankingScreen));
  await pumpUntil(tester, find.byKey(const ValueKey('league-change-target')));
  // An earned fixture can trigger the existing one-time help sheet.
  await pumpFor(tester, const Duration(milliseconds: 700));
  if (find.byType(LeagueInfoSheet).evaluate().isNotEmpty) {
    Navigator.of(tester.element(find.byType(LeagueInfoSheet))).pop();
    await pumpUntilGone(tester, find.byType(LeagueInfoSheet));
  }
  await tapOn(tester, find.text(trL10n.rankingTabLeague));
}

void _expectTarget(CompetitionTarget target, DateTime periodEnd) {
  expect(target.currentSegment, 'yks');
  expect(target.pendingSegment, 'tus');
  expect(target.effectiveAt?.toUtc(), periodEnd.toUtc());
}

void _expectTargetText(CompetitionTarget target) {
  expect(
    find.text(trL10n.leagueTargetCurrent(trL10n.onboardingSegmentYks)),
    findsOneWidget,
  );
  expect(
    find.text(
      trL10n.leagueTargetPending(
        trL10n.onboardingSegmentTus,
        competitionDate(trL10n, target.effectiveAt!),
      ),
    ),
    findsOneWidget,
  );
}

Future<void> _expectStudyPoints(
  WidgetTester tester,
  String owner,
  int points, {
  required bool global,
}) async {
  await pumpUntilTrue(tester, () {
    final matches = find.byType(RankingStandings);
    if (matches.evaluate().length != 1) return false;
    final standings = tester.widget<RankingStandings>(matches);
    final own = standings.entries.where((entry) => entry.isMe).toList();
    return own.length == 1 &&
        own.single.userId == owner &&
        own.single.points == points &&
        (global ? standings.league == null : standings.league != null);
  }, reason: 'native normal ${global ? 'global' : 'target'} own points');
}

Future<void> _expectExamPoints(WidgetTester tester, int points) async {
  final own = find.descendant(
    of: find.byType(ExamScreen),
    matching: find.byWidgetPredicate(
      (widget) => widget is ListTile && widget.selected,
    ),
  );
  await pumpUntilTrue(tester, () {
    if (own.evaluate().length != 1) return false;
    final trailing = tester.widget<ListTile>(own).trailing;
    return trailing is Text && trailing.data == '$points';
  }, reason: 'native exam own points');
}

Future<void> _verifyViews(
  WidgetTester tester,
  String owner,
  int studyPoints,
  int examPoints,
  DateTime periodEnd,
  Map<String, dynamic> expectedState,
) async {
  final target = await SupabaseService.instance.getCompetitionTarget();
  _expectTarget(target, periodEnd);
  await _openStudyLeague(tester);
  _expectTargetText(target);
  await _expectStudyPoints(tester, owner, studyPoints, global: false);
  await E2eHost.screenshot(tester, 'e2e-league-target-$_phase');
  await tapOn(tester, find.text(trL10n.rankingTabGlobal));
  await pumpUntil(tester, find.text(trL10n.leagueGlobalScopeBody));
  await _expectStudyPoints(tester, owner, studyPoints, global: true);
  await E2eHost.screenshot(tester, 'e2e-league-global-$_phase');
  expect(await _databaseState(owner), expectedState);

  await _tab(tester, 4);
  await tapOn(tester, find.widgetWithText(ChoiceChip, trL10n.examLeague));
  await _expectExamPoints(tester, examPoints);
  await tapOn(tester, find.widgetWithText(ChoiceChip, trL10n.examGlobal));
  await _expectExamPoints(tester, examPoints);
  expect(
    tester
        .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, trL10n.examGlobal))
        .selected,
    isTrue,
  );
  for (final kind in ['study', 'exam']) {
    for (final scope in ['segment', 'global']) {
      final response = await _ranking(owner, kind, scope);
      expect(response['segment'], 'yks');
      expect(response['pending_segment'], 'tus');
      expect(
        DateTime.parse(response['segment_effective_at'] as String).toUtc(),
        periodEnd.toUtc(),
      );
      expect(
        response['own_points'],
        kind == 'study' ? studyPoints : examPoints,
      );
    }
  }
  await E2eHost.screenshot(tester, 'e2e-exam-league-global-$_phase');
  expect(
    await _databaseState(owner),
    expectedState,
    reason: 'reading either global view gives no reward and moves no room',
  );
  expect(tester.takeException(), isNull);
}

Future<void> _change(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  expect(prefs.containsKey(_checkpointKey), isFalse);
  final unfinished = prefs.getKeys().where((key) {
    if (!key.startsWith('e2e_real_duration_probe_') &&
        !key.startsWith('e2e_normal_http_restart_')) {
      return false;
    }
    final value = jsonDecode(prefs.getString(key)!) as Map;
    return value['completion_verified'] != true;
  });
  expect(
    unfinished,
    isEmpty,
    reason: 'do not reset an unfinished duration run',
  );
  await resetAppState(tester);
  await launchApp(tester);
  await waitPastSplash(tester);
  await _verifyLoginLogo(tester);
  await loginViaUi(tester, _fixtureEmail);
  await pumpUntil(tester, find.byType(MainNavigationShell));
  await NotificationService.instance.setEnabled(false);
  final owner = SupabaseService.instance.currentUser.value!.id!;
  expect(Supabase.instance.client.auth.currentUser?.email, _fixtureEmail);
  await ExamService.instance.refresh();
  expect(ExamService.instance.activeRecord, isNull);
  final before = await _databaseState(owner);
  expect(before['normal_rows'], greaterThanOrEqualTo(1));
  expect(before['exam_rows'], greaterThanOrEqualTo(1));
  expect(before['lifetime_points'], greaterThan(0));
  expect(before['exam_points'], greaterThan(0));
  final initialTarget = await SupabaseService.instance.getCompetitionTarget();
  expect(initialTarget.currentSegment, 'yks');
  expect(initialTarget.pendingSegment, isNull);
  final study = await _ranking(owner, 'study', 'segment');
  final exam = await _ranking(owner, 'exam', 'segment');
  final studyPoints = study['own_points'] as int;
  final examPoints = exam['own_points'] as int;
  expect(studyPoints, greaterThan(0));
  expect(examPoints, greaterThan(0));
  final periodEnd = DateTime.parse(study['period_end'] as String);
  expect(exam['period_end'], study['period_end']);

  await _openStudyLeague(tester);
  await tapOn(tester, find.byKey(const ValueKey('league-change-target')));
  await pumpUntil(tester, find.byType(CompetitionTargetDialog));
  expect(find.text(trL10n.leagueTargetPolicy), findsOneWidget);
  await tapOn(tester, find.byKey(const ValueKey('competition-target-tus')));
  await tapOn(tester, find.byKey(const ValueKey('competition-target-save')));
  await pumpUntilGone(tester, find.byType(CompetitionTargetDialog));
  final changed = await SupabaseService.instance.getCompetitionTarget();
  _expectTarget(changed, periodEnd);
  final after = await _databaseState(owner);
  for (final key in before.keys.where(
    (key) => key != 'user_segment' && key != 'target_history',
  )) {
    expect(after[key], before[key], reason: 'target change preserves $key');
  }
  expect(after['user_segment'], 'tus');
  await _verifyViews(tester, owner, studyPoints, examPoints, periodEnd, after);
  final proof = {
    'phase': 'change_verified',
    'email': _fixtureEmail,
    'owner': owner,
    'start_pid': pid,
    'study_points': studyPoints,
    'exam_points': examPoints,
    'period_end': periodEnd.toUtc().toIso8601String(),
    'database_state': after,
    'scope': 'controlled historical fixture; real target/global UI',
  };
  expect(await prefs.setString(_checkpointKey, jsonEncode(proof)), isTrue);
  expect(prefs.getString(_checkpointKey), jsonEncode(proof));
  debugPrint('[LEAGUE_JOURNEY] change verified; stop process before resume');
}

Future<void> _resume(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_checkpointKey);
  expect(raw, isNotNull, reason: 'same native app data must survive restart');
  final proof = Map<String, dynamic>.from(jsonDecode(raw!) as Map);
  expect(proof['phase'], 'change_verified');
  expect(proof['email'], _fixtureEmail);
  expect(
    proof['start_pid'],
    isNot(pid),
    reason: 'resume requires a different native OS application process',
  );
  final owner = proof['owner'] as String;
  await launchApp(
    tester,
  ); // Do not reset prefs/auth, sign in, or mutate target.
  await pumpUntil(tester, find.byType(MainNavigationShell));
  expect(find.byType(LoginScreen), findsNothing);
  expect(Supabase.instance.client.auth.currentUser?.id, owner);
  expect(SupabaseService.instance.currentUser.value?.id, owner);
  await ExamService.instance.refresh();
  final state = Map<String, dynamic>.from(proof['database_state'] as Map);
  expect(await _databaseState(owner), state);
  await _verifyViews(
    tester,
    owner,
    proof['study_points'] as int,
    proof['exam_points'] as int,
    DateTime.parse(proof['period_end'] as String),
    state,
  );
  proof['phase'] = 'resume_verified';
  proof['resume_pid'] = pid;
  expect(await prefs.setString(_checkpointKey, jsonEncode(proof)), isTrue);
  debugPrint(
    '[LEAGUE_JOURNEY] persisted auth/target/points verified after restart',
  );
}

void main() {
  initE2e();
  testWidgets(
    'x · current target and both league balances survive deferred change/global/restart',
    (tester) async {
      expect(E2eHost.available, isTrue);
      expect(_fixtureEmail.startsWith('e2e-sim-'), isTrue);
      expect(_fixtureEmail.endsWith('@pomosprint.local'), isTrue);
      expect({'change', 'resume'}.contains(_phase), isTrue);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      if (_phase == 'change') {
        await _change(tester);
      } else {
        await _resume(tester);
      }
    },
    skip: _fixtureEmail.isEmpty,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
