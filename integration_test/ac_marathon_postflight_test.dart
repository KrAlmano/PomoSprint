// Postflight for the already completed native Android S50 run. No new account,
// fixture, reset, timer start, or synthetic elapsed time. This does not rerun
// the 105-minute journey: it verifies its preserved records and final UI.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/models/study_session.dart';
import 'package:pomodoro/screens/history_screen.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/widgets/social/ranking_widgets.dart';
import 'package:pomodoro/widgets/stats/session_type_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/e2e.dart';

const _enabled = bool.fromEnvironment('E2E_MARATHON_POSTFLIGHT');
const _run = String.fromEnvironment('E2E_RUN_ID');
const _expectedRun = 'night-marathon50-android-r14';
const _expectedOwner = 'b550e552-1ef2-48c9-97ba-8f70f44608e8';
const _expectedEmail =
    'e2e-sim-real-marathon-1793140808919309-night-marathon50-android-r14@pomosprint.local';
const _expectedMarathon = '1ff4df42-d5c2-4b1e-8b7b-625a5701396b';
const _owner = String.fromEnvironment('E2E_MARATHON_POSTFLIGHT_OWNER');
const _email = String.fromEnvironment('E2E_MARATHON_POSTFLIGHT_EMAIL');
const _marathon = String.fromEnvironment('E2E_MARATHON_POSTFLIGHT_RUN');

Future<ApiAccount> _freshAccount() async {
  final auth = Supabase.instance.client.auth;
  expect(auth.currentUser?.id, _owner);
  expect(auth.currentUser?.email, _email);
  var session = auth.currentSession;
  if (session != null &&
      (session.expiresAt ?? 0) <=
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 30) {
    await auth.refreshSession();
    session = auth.currentSession;
  }
  expect(session, isNotNull);
  expect(session!.user.id, _owner);
  expect(session.user.email, _email);
  expect(
    session.expiresAt,
    greaterThan(DateTime.now().millisecondsSinceEpoch ~/ 1000),
  );
  return ApiAccount(_owner, _email, session.accessToken);
}

Future<Map<String, dynamic>> _state() async => (await E2eHost.row(
  'select u.email,p.total_minutes,p.lifetime_points,p.coins,'
  'r.target_sessions,r.duration_minutes,r.bonus_awarded,r.is_invalid '
  'from auth.users u join public.profiles p on p.id=u.id '
  'join public.marathon_runs r on r.user_id=u.id '
  'where u.id=${sqlText(_owner)} and r.client_uuid=${sqlText(_marathon)}',
))!;

Future<List<Map<String, dynamic>>> _sessions() => E2eHost.rows(
  'select s.id::text,s.client_uuid::text,s.category_id::text,s.duration_minutes,'
  's.base_points,s.bonus_points,s.was_paused,s.started_at,s.completed_at,m.session_index '
  'from public.study_sessions s join public.marathon_run_sessions m '
  'on m.study_session_id=s.id and m.user_id=s.user_id '
  'where s.user_id=${sqlText(_owner)} and m.marathon_uuid=${sqlText(_marathon)} '
  'order by m.session_index',
);

void main() {
  if (!_enabled) {
    test(
      'ac · S50 postflight is opt-in',
      () {},
      skip: 'Set E2E_MARATHON_POSTFLIGHT=true for the preserved S50 owner',
    );
    return;
  }
  initE2e();
  testWidgets(
    'ac · preserved S50 records, fresh-token duplicate and final reports',
    (tester) async {
      expect(_run, _expectedRun);
      expect(
        _owner,
        _expectedOwner,
        reason: 'Exact preserved S50 owner required',
      );
      expect(
        _email,
        _expectedEmail,
        reason: 'Exact preserved S50 email required',
      );
      expect(
        _marathon,
        _expectedMarathon,
        reason: 'Exact preserved S50 plan required',
      );
      expect(E2eHost.available, isTrue);
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('saved_user');
      expect(cached, isNotNull, reason: 'Retain the original S50 installation');
      expect(
        (jsonDecode(cached!) as Map)['id'],
        _owner,
        reason: 'Never reset or sign in over another current owner',
      );
      for (final key in prefs.getKeys().where(
        (key) => key.startsWith('active_session_uid_'),
      )) {
        fail('An active timer must not be disturbed by postflight: $key');
      }
      final before = await _state();
      expect(before, {
        'email': _email,
        'total_minutes': 100,
        'lifetime_points': 28,
        'coins': 40,
        'target_sessions': 2,
        'duration_minutes': 50,
        'bonus_awarded': 4,
        'is_invalid': false,
      });
      final rows = await _sessions();
      expect(rows, hasLength(2));
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        expect(row['session_index'], index + 1);
        expect(row['duration_minutes'], 50);
        expect(row['base_points'], 12);
        expect(row['bonus_points'], index == 0 ? 0 : 4);
        expect(row['was_paused'], isFalse);
        expect(
          DateTime.parse(
            row['completed_at'] as String,
          ).difference(DateTime.parse(row['started_at'] as String)),
          const Duration(minutes: 50),
        );
      }
      expect(
        await E2eHost.rows(
          'select id from public.study_sessions where user_id=${sqlText(_owner)}',
        ),
        hasLength(2),
      );
      expect(await TimerPersistence.instance.load(_owner), isNull);
      await launchApp(
        tester,
      ); // Preserve native auth, account and completed history.
      await pumpUntil(
        tester,
        find.byType(MainNavigationShell),
        timeout: const Duration(seconds: 50),
      );
      expect(SupabaseService.instance.currentUser.value?.id, _owner);
      var account = await _freshAccount();
      final second = rows.last;
      final duplicate =
          await LocalApi.rpc('complete_marathon_study_session', account, {
                'p_client_uuid': second['client_uuid'],
                'p_category_id': second['category_id'],
                'p_duration_minutes': 50,
                'p_was_paused': false,
                'p_is_verified': 0,
                'p_started_at': second['started_at'],
                'p_marathon_uuid': _marathon,
                'p_target_sessions': 2,
                'p_session_index': 2,
              })
              as Map;
      expect(duplicate['duplicate'], isTrue);
      expect(duplicate['coins_earned'], 0);
      expect(await _state(), before);
      expect(await _sessions(), rows);
      await openTab(tester, 1);
      await tapOn(tester, find.text(tr('reports_tab_history')));
      await pumpUntil(tester, find.byType(HistoryScreen));
      await tester
          .widget<HistoryScreen>(find.byType(HistoryScreen))
          .onRefresh();
      await pumpUntilTrue(
        tester,
        () =>
            tester
                .widget<HistoryScreen>(find.byType(HistoryScreen))
                .sessions
                .length ==
            2,
        reason: 'preserved two S50 focus records',
      );
      final history = tester.widget<HistoryScreen>(find.byType(HistoryScreen));
      expect(
        history.sessions.every((s) => s.kind == StudySessionKind.marathon),
        isTrue,
      );
      expect(history.sessions.fold<int>(0, (n, s) => n + s.minutes), 100);
      final summary = tester.widget<SessionTypeSummary>(
        find.byType(SessionTypeSummary),
      );
      expect(summary.counts.marathonFocusSessions, 2);
      expect(summary.counts.completedMarathons, 1);
      expect(summary.counts.normalSessions, 0);
      expect(summary.counts.completedExams, 0);
      await E2eHost.screenshot(tester, 'e2e-marathon50-postflight-reports');
      account = await _freshAccount();
      final league =
          await LocalApi.rpc('get_monthly_league_ranking', account, {
                'p_kind': 'study',
                'p_scope': 'segment',
              })
              as Map;
      expect(
        (league['rows'] as List).cast<Map>().singleWhere(
          (row) => row['id'] == _owner,
        )['points'],
        28,
      );
      await openTab(tester, 2);
      await pumpUntil(tester, find.byType(RankingStandings));
      await pumpUntilTrue(
        tester,
        () => tester
            .widget<RankingStandings>(find.byType(RankingStandings))
            .entries
            .any((row) => row.userId == _owner && row.points == 28),
        reason: 'S50 league UI shows28 points',
      );
      await E2eHost.screenshot(tester, 'e2e-marathon50-postflight-league');
      expect(await _state(), before);
      expect(await _sessions(), rows);
      expect(tester.takeException(), isNull);
      debugPrint(
        '[MARATHON_POSTFLIGHT] PASS preserved S50 100min/28points/40sand, fresh-token duplicate, reports and league',
      );
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
