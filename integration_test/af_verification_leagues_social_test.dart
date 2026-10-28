// A5/A7 native gap coverage. New local cohort and I08 presence fixtures only.
// Scores/timestamps are controlled history created by a separate guarded tool;
// this file never inserts economy/history rows or changes clocks/catalogues.
// Visibility changes use the owning QA account API and are explicitly restored.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/screens/ranking_screen.dart';
import 'package:pomodoro/screens/social_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/widgets/avatar_widget.dart';
import 'package:pomodoro/widgets/social/presence_dot.dart';
import 'package:pomodoro/widgets/social/ranking_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'support/e2e.dart';

const _phase = String.fromEnvironment('E2E_AF_PHASE', defaultValue: 'all');
const _socialRun = String.fromEnvironment(
  'E2E_SOCIAL_FIXTURE_RUN',
  defaultValue: 'night-1028',
);
const _cohortRun = String.fromEnvironment(
  'E2E_VERIFY_COHORT_RUN',
  defaultValue: 'verify-1028',
);
AppLocalizations get _text => lookupAppLocalizations(
  Locale(LanguageService.instance.isTurkish ? 'tr' : 'en'),
);

Future<void> _guardDevice() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys()) {
    if (key.startsWith('e2e_real_duration_probe_') ||
        key.startsWith('e2e_normal_http_restart_') ||
        key.startsWith('e2e_marathon_process_probe_') ||
        key.startsWith('e2e_first_use_real25_')) {
      final proof = jsonDecode(prefs.getString(key)!) as Map;
      expect(
        proof['completion_verified'],
        isTrue,
        reason: 'Preserve unfinished probe $key',
      );
    }
    expect(
      key.startsWith('active_session_uid_'),
      isFalse,
      reason: 'Never replace another running normal/Marathon timer',
    );
    if (key.startsWith('pending_sessions_')) {
      expect(
        jsonDecode(prefs.getString(key)!),
        isEmpty,
        reason: 'Never reset a pending study outbox',
      );
    }
    if (key.startsWith('exam_journal_uid_')) {
      final records = jsonDecode(prefs.getString(key)!) as List;
      expect(
        records.every(
          (r) =>
              (r as Map)['pending_action'] == null &&
              ((r['attempt'] as Map?)?['status'] != 'active'),
        ),
        isTrue,
        reason: 'Never replace a pending exam journal',
      );
    }
  }
}

Future<ApiAccount> _signIn(String email) async {
  expect(email.endsWith('@pomosprint.local'), isTrue);
  final response =
      await LocalApi.request(
            'POST',
            '/auth/v1/token?grant_type=password',
            body: {'email': email, 'password': kE2ePassword},
          )
          as Map;
  return ApiAccount(
    (response['user'] as Map)['id'] as String,
    email,
    response['access_token'] as String,
  );
}

Future<void> _login(WidgetTester tester, ApiAccount account) async {
  await _guardDevice();
  await resetAppState(tester);
  await launchApp(tester);
  await waitPastSplash(tester);
  await loginViaUi(tester, account.email);
  await pumpUntil(tester, find.byType(MainNavigationShell));
  expect(SupabaseService.instance.currentUser.value?.id, account.id);
  await NotificationService.instance.setEnabled(false);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('league_info_shown_${account.id}', true);
}

Future<void> _tab(WidgetTester tester, int index) async {
  if (find.byType(NavigationBar).evaluate().isNotEmpty) {
    await openTab(tester, index);
  } else {
    tester
        .widget<NavigationRail>(find.byType(NavigationRail))
        .onDestinationSelected!(index);
    await pumpFor(tester, const Duration(milliseconds: 350));
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
    () => LanguageService.instance.currentLocale.languageCode == code,
    reason: 'Settings changes native language to $code',
  );
  Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
  await pumpUntilGone(tester, find.byType(ProfileScreen));
}

Future<void> _pullRefresh(WidgetTester tester, Finder scope) async {
  final refresh = find
      .descendant(of: scope, matching: find.byType(RefreshIndicator))
      .first;
  await tester.widget<RefreshIndicator>(refresh).onRefresh();
  await pumpFor(tester, const Duration(milliseconds: 450));
}

Future<List<Map<String, dynamic>>> _live(ApiAccount observer) async => [
  for (final r
      in await LocalApi.rpc('get_live_friends_with_breaks', observer) as List)
    Map<String, dynamic>.from(r as Map),
];

Future<void> _showFriend(WidgetTester tester, String owner) async {
  final scope = find.byType(SocialScreen);
  final scroll = find
      .descendant(of: scope, matching: find.byType(Scrollable))
      .first;
  final position = tester.state<ScrollableState>(scroll).position;
  position.jumpTo(0);
  await pumpFor(tester, const Duration(milliseconds: 150));
  await tester.scrollUntilVisible(
    find.byKey(ValueKey('social-friend-$owner')),
    240,
    scrollable: scroll,
    maxScrolls: 40,
    duration: const Duration(milliseconds: 100),
  );
  final card = find.byKey(ValueKey('social-friend-$owner'));
  await Scrollable.ensureVisible(tester.element(card), alignment: 0.5);
  await pumpFor(tester, const Duration(milliseconds: 350));
  final cardRect = tester.getRect(card);
  final viewportRect = tester.getRect(scroll);
  if (card.hitTestable().evaluate().isEmpty) {
    debugPrint(
      '[AF_SOCIAL_VISIBILITY] card=$cardRect viewport=$viewportRect '
      'offset=${position.pixels} extent=${position.maxScrollExtent}',
    );
    await E2eHost.screenshot(tester, 'e2e-af-social-visibility-failure');
  }
  expect(card.hitTestable(), findsOneWidget);
}

void _expectSocialRow(WidgetTester tester, Map<String, dynamic> row) {
  final card = find.byKey(ValueKey('social-friend-${row['id']}'));
  expect(
    find.descendant(of: card, matching: find.text(row['name'] as String)),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: card,
      matching: find.text(SocialScreen.liveStatusText(row, _text)),
    ),
    findsOneWidget,
  );
  final dot = tester.widget<SocialPresenceDot>(
    find.descendant(of: card, matching: find.byType(SocialPresenceDot)),
  );
  expect(dot.onBreak, row['status'] == 'break');
}

Future<void> _waitGoneNaturally(
  WidgetTester tester,
  ApiAccount observer,
  ApiAccount actor,
  String reason,
) async {
  // No navigation, manual refresh, or local stats event between the remote
  // mutation and this assertion: the visible 30-second poll must remove it.
  await pumpUntilGone(
    tester,
    find.byKey(ValueKey('social-friend-${actor.id}')),
    timeout: const Duration(seconds: 45),
    reason: reason,
  );
  expect((await _live(observer)).any((r) => r['id'] == actor.id), isFalse);
  await E2eHost.screenshot(tester, 'e2e-af-${_text.localeName}-$reason');
}

Future<void> _presence(
  ApiAccount actor,
  String status, {
  String examId = 'lgs_verbal',
}) async {
  if (status == 'focus') {
    await LocalApi.rpc('start_study_session', actor, {
      'p_duration_minutes': 25,
      'p_category_name': 'Matematik',
    });
  } else if (status == 'break') {
    final config = await LocalApi.rpc('get_exam_config', actor) as Map;
    final now = DateTime.parse(config['server_time'] as String);
    await LocalApi.rpc('start_study_break', actor, {
      'p_ends_at': now
          .add(const Duration(minutes: 5))
          .toUtc()
          .toIso8601String(),
    });
  } else {
    await LocalApi.rpc('start_exam_attempt', actor, {
      'p_client_uuid': const Uuid().v4(),
      'p_exam_id': examId,
    });
  }
}

Future<void> _restoreVisible(
  WidgetTester tester,
  ApiAccount observer,
  ApiAccount actor,
) async {
  await _pullRefresh(tester, find.byType(SocialScreen));
  await _showFriend(tester, actor.id);
  final row = (await _live(observer)).singleWhere((r) => r['id'] == actor.id);
  _expectSocialRow(tester, row);
}

Future<void> _friendAgain(ApiAccount observer, ApiAccount actor) async {
  final current = await LocalApi.rpc('get_my_friends', observer) as List;
  if (current.any((r) => (r as Map)['id'] == actor.id)) return;
  final profile =
      (await LocalApi.request(
                    'GET',
                    '/rest/v1/profiles?select=friend_code&id=eq.${actor.id}',
                    token: actor.token,
                  )
                  as List)
              .single
          as Map;
  final added =
      await LocalApi.rpc('add_friend_by_code', observer, {
            'p_code': profile['friend_code'],
          })
          as Map;
  expect(added['success'], isTrue);
  final accepted =
      await LocalApi.rpc('respond_friend_request', actor, {
            'p_from_user_id': observer.id,
            'p_accept': true,
          })
          as Map;
  expect(accepted['success'], isTrue);
}

Future<void> _social(WidgetTester tester) async {
  expect(RegExp(r'^[a-z0-9-]{1,32}$').hasMatch(_socialRun), isTrue);
  Future<ApiAccount> role(String value) =>
      _signIn('qa-i08-$_socialRun-$value@pomosprint.local');
  final observer = await role('observer');
  final actors = <String, ApiAccount>{
    for (final r in ['focus2', 'break1', 'exam1', 'focus3', 'focus4'])
      r: await role(r),
  };
  final initial = await _live(observer);
  expect(
    initial,
    hasLength(8),
    reason: 'Use a fresh/refreshed nine-account I08 fixture',
  );
  expect(initial.where((r) => r['status'] == 'focus'), hasLength(4));
  expect(initial.where((r) => r['status'] == 'break'), hasLength(2));
  expect(initial.where((r) => r['status'] == 'exam'), hasLength(2));
  await _login(tester, observer);
  await _tab(tester, 3);
  await pumpUntil(tester, find.byType(SocialScreen));
  await _pullRefresh(tester, find.byType(SocialScreen));
  for (final language in ['tr', 'en']) {
    await _language(tester, language);
    for (final roleName in ['focus2', 'break1', 'exam1']) {
      final actor = actors[roleName]!;
      await _showFriend(tester, actor.id);
      final before = (await _live(
        observer,
      )).singleWhere((r) => r['id'] == actor.id);
      _expectSocialRow(tester, before);
      String? abandonedId;
      try {
        if (roleName == 'exam1') {
          final history =
              await LocalApi.rpc('get_my_exam_attempts', actor, {
                    'p_limit': 100,
                  })
                  as Map;
          final active = (history['attempts'] as List).cast<Map>().singleWhere(
            (r) => r['status'] == 'active',
          );
          abandonedId = active['id'] as String;
          final receipt =
              await LocalApi.rpc('abandon_exam_attempt', actor, {
                    'p_attempt_id': abandonedId,
                  })
                  as Map;
          expect((receipt['attempt'] as Map)['status'], 'abandoned');
        } else {
          await LocalApi.rpc('cancel_study_session', actor);
        }
        await _waitGoneNaturally(
          tester,
          observer,
          actor,
          '${before['status']}-ended',
        );
        if (abandonedId != null) {
          expect(
            await E2eHost.row(
              'select status,points_earned,exam_coins_earned from public.exam_attempts '
              'where id=${sqlText(abandonedId)} and user_id=${sqlText(actor.id)}',
            ),
            {'status': 'abandoned', 'points_earned': 0, 'exam_coins_earned': 0},
          );
        }
      } finally {
        await _presence(actor, before['status'] as String);
      }
      await _restoreVisible(tester, observer, actor);
    }
    final privateActor = actors['focus3']!;
    await _showFriend(tester, privateActor.id);
    try {
      await LocalApi.request(
        'PATCH',
        '/rest/v1/profiles?id=eq.${privateActor.id}',
        token: privateActor.token,
        body: {'show_in_social_feed': false},
      );
      await _waitGoneNaturally(tester, observer, privateActor, 'privacy-off');
      expect(
        (await E2eHost.row(
          'select show_in_social_feed from public.profiles where id=${sqlText(privateActor.id)}',
        ))!['show_in_social_feed'],
        isFalse,
      );
    } finally {
      await LocalApi.request(
        'PATCH',
        '/rest/v1/profiles?id=eq.${privateActor.id}',
        token: privateActor.token,
        body: {'show_in_social_feed': true},
      );
    }
    await _restoreVisible(tester, observer, privateActor);
    final blockedActor = actors['focus4']!;
    await _showFriend(tester, blockedActor.id);
    try {
      final blocked =
          await LocalApi.rpc('block_user', observer, {
                'p_user_id': blockedActor.id,
              })
              as Map;
      expect(blocked['success'], isTrue);
      await _waitGoneNaturally(tester, observer, blockedActor, 'blocked');
      expect(
        (await E2eHost.row(
          'select count(*)::int as n from public.user_blocks where '
          'blocker_id=${sqlText(observer.id)} and blocked_id=${sqlText(blockedActor.id)}',
        ))!['n'],
        1,
      );
    } finally {
      await LocalApi.rpc('unblock_user', observer, {
        'p_user_id': blockedActor.id,
      });
      await _friendAgain(observer, blockedActor);
    }
    await _restoreVisible(tester, observer, blockedActor);
    debugPrint(
      '[AF_SOCIAL] language=$language focus/break/exam ended, privacy off and blocked all removed by natural poll; explicit QA restoration PASS',
    );
  }
  expect(tester.takeException(), isNull);
}

Future<Map<String, Map<String, dynamic>>> _cohort() async {
  expect(RegExp(r'^[a-z0-9-]{1,30}$').hasMatch(_cohortRun), isTrue);
  final rows = await E2eHost.rows(
    'select u.id::text,u.email,u.raw_user_meta_data->>\'qa_verification_role\' as role,'
    'p.user_segment,p.name,u.created_at>now()-interval \'24 hours\' as recent '
    'from auth.users u join public.profiles p on p.id=u.id '
    'where u.raw_user_meta_data->>\'qa_verification_cohort\'=${sqlText(_cohortRun)}',
  );
  expect(rows, hasLength(4));
  final result = <String, Map<String, dynamic>>{};
  for (final row in rows) {
    final role = row['role'] as String;
    expect({'lgs-a', 'lgs-b', 'tus-a', 'tus-b'}.contains(role), isTrue);
    expect(row['email'], 'e2e-sim-cohort-$_cohortRun-$role@pomosprint.local');
    expect(row['recent'], isTrue);
    expect(row['user_segment'], role.startsWith('lgs') ? 'lgs' : 'tus');
    result[role] = row;
  }
  expect(result, hasLength(4));
  return result;
}

List<Map<String, dynamic>> _project(Iterable<Map> rows) => [
  for (final r in rows)
    {
      'id': r['id'],
      'name': r['name'],
      'avatar_id': r['avatar_id'],
      'points': r['points'],
      'rank': r['rank'],
      'is_me': r['is_me'],
      'is_blocked': r['is_blocked'],
    },
];

Future<List<Map<String, dynamic>>> _oracleRows(
  String owner,
  String kind,
  String scope,
) async {
  final uid = sqlText(owner), k = sqlText(kind);
  const month =
      "date_trunc('month',clock_timestamp() at time zone 'Europe/Istanbul')::date";
  final blocked =
      'exists(select 1 from public.user_blocks b where '
      '(b.blocker_id=$uid and b.blocked_id=p.id) or (b.blocker_id=p.id and b.blocked_id=$uid))';
  if (scope == 'global') {
    return E2eHost.rows(
      'with totals as(select user_id,sum(points)::int points,sum(minutes)::int minutes '
      'from public.competition_events where kind=$k and period_month=$month group by user_id),'
      'ranked as(select p.id,p.name,p.avatar_id,t.points,row_number()over(order by t.points desc,t.minutes desc,p.id)::int rank '
      'from totals t join public.profiles p on p.id=t.user_id where p.show_in_social_feed and not $blocked) '
      'select id::text,name,avatar_id,points,rank,id=$uid::uuid as is_me,false as is_blocked from ranked order by rank limit 100',
    );
  }
  return E2eHost.rows(
    'with myroom as(select room_id from public.competition_memberships '
    'where user_id=$uid and kind=$k and period_month=$month),'
    'totals as(select user_id,sum(points)::int points from public.competition_events '
    'where kind=$k and period_month=$month group by user_id),'
    'base as(select p.id,p.name,p.avatar_id,p.show_in_social_feed,m.joined_at,coalesce(t.points,0)points,'
    '$blocked as blocked from public.competition_memberships m join myroom r on r.room_id=m.room_id '
    'join public.profiles p on p.id=m.user_id left join totals t on t.user_id=p.id),'
    'ranked as(select *,row_number()over(order by points desc,joined_at,id)::int rank from base) '
    'select case when id=$uid::uuid or(show_in_social_feed and not blocked)then id::text end as id,'
    'case when id=$uid::uuid or(show_in_social_feed and not blocked)then name end as name,'
    'case when id=$uid::uuid or(show_in_social_feed and not blocked)then avatar_id end as avatar_id,'
    'points,rank,id=$uid::uuid as is_me,blocked as is_blocked from ranked order by rank',
  );
}

Future<List<Map<String, dynamic>>> _rpcRows(
  String owner,
  String kind,
  String scope,
) async {
  expect(Supabase.instance.client.auth.currentUser?.id, owner);
  final response =
      await Supabase.instance.client.rpc(
            'get_monthly_league_ranking',
            params: {'p_kind': kind, 'p_scope': scope},
          )
          as Map;
  expect(response['kind'], kind);
  expect(response['scope'], scope);
  expect(response['segment'], 'lgs');
  final end = (await E2eHost.row(
    "select ((date_trunc('month',clock_timestamp() at time zone 'Europe/Istanbul')+interval '1 month') at time zone 'Europe/Istanbul')::text as ending",
  ))!;
  expect(
    DateTime.parse(response['period_end'] as String).toUtc(),
    DateTime.parse(end['ending'] as String).toUtc(),
  );
  return _project((response['rows'] as List).cast<Map>());
}

Future<void> _studyView(
  WidgetTester tester,
  List<Map<String, dynamic>> expected,
  String scope,
  String state,
) async {
  await _tab(tester, 2);
  await pumpUntil(tester, find.byType(RankingScreen));
  await tapOn(
    tester,
    find.descendant(
      of: find.byType(RankingScreen),
      matching: find.text(
        scope == 'segment' ? _text.rankingTabLeague : _text.rankingTabGlobal,
      ),
    ),
  );
  await _pullRefresh(tester, find.byType(RankingScreen));
  final wanted = scope == 'global' ? expected.take(50).toList() : expected;
  await pumpUntilTrue(
    tester,
    () {
      final f = find.byType(RankingStandings);
      if (f.evaluate().length != 1) return false;
      final rows = tester.widget<RankingStandings>(f).entries;
      return jsonEncode([
            for (final r in rows)
              {
                'id': r.userId,
                'name': r.name,
                'avatar_id': r.avatarId,
                'points': r.points,
                'is_me': r.isMe,
                'is_blocked': r.hidden,
              },
          ]) ==
          jsonEncode([
            for (final r in wanted)
              {
                'id': r['id'],
                'name': r['name'],
                'avatar_id': r['avatar_id'],
                'points': r['points'],
                'is_me': r['is_me'],
                'is_blocked': r['is_blocked'],
              },
          ]);
    },
    reason:
        'native study $scope exact ordered rows/masks match independent SQL',
  );
  await E2eHost.screenshot(
    tester,
    'e2e-af-study-$scope-${_text.localeName}-$state',
  );
}

Future<void> _examView(
  WidgetTester tester,
  List<Map<String, dynamic>> expected,
  String scope,
  String state,
) async {
  await _tab(tester, 4);
  await pumpUntil(tester, find.byType(ExamScreen));
  await tapOn(tester, find.widgetWithText(ChoiceChip, _text.examLeague));
  await tapOn(
    tester,
    find.widgetWithText(
      ChoiceChip,
      scope == 'segment' ? _text.examTargetGroup : _text.examGlobal,
    ),
  );
  await _pullRefresh(tester, find.byType(ExamScreen));
  final rows = find.descendant(
    of: find.byType(ExamScreen),
    matching: find.byType(ListTile),
  );
  await pumpUntilTrue(
    tester,
    () {
      final actual = tester.widgetList<ListTile>(rows).toList();
      if (actual.length != expected.length) return false;
      for (var i = 0; i < actual.length; i++) {
        if ((actual[i].title as Text).data !=
                (expected[i]['name'] ?? _text.userDefault) ||
            (actual[i].leading as Text).data != '${expected[i]['rank']}' ||
            (actual[i].trailing as Text).data != '${expected[i]['points']}' ||
            actual[i].selected != (expected[i]['is_me'] == true)) {
          return false;
        }
      }
      return true;
    },
    reason:
        'native exam $scope exact ordered names/ranks/points match independent SQL',
  );
  await E2eHost.screenshot(
    tester,
    'e2e-af-exam-$scope-${_text.localeName}-$state',
  );
}

Future<String> _economyDigest(Iterable<String> owners) async =>
    (await E2eHost.row(
          'select md5(coalesce(jsonb_agg(to_jsonb(t) order by t.id)::text,\'[]\')) as hash from('
          'select p.id,p.total_minutes,p.lifetime_points,p.coins,p.current_streak,p.longest_streak,p.last_study_date,'
          'coalesce(w.coins,0) as exam_coins,coalesce(w.lifetime_points,0) as exam_points '
          'from public.profiles p left join public.exam_wallets w on w.user_id=p.id '
          'where p.id in(${owners.map(sqlText).join(',')}))t',
        ))!['hash']
        as String;

Future<void> _fourViews(
  WidgetTester tester,
  String owner,
  Map<String, Map<String, dynamic>> cohort,
  String state,
) async {
  for (final kind in ['study', 'exam']) {
    for (final scope in ['segment', 'global']) {
      final expected = _project(await _oracleRows(owner, kind, scope));
      expect(expected, isNotEmpty);
      expect(
        await _rpcRows(owner, kind, scope),
        expected,
        reason: 'independent SQL checks complete scope/order/points/masking',
      );
      final ids = expected.map((r) => r['id']).toSet();
      if (scope == 'segment') {
        expect(
          ids.intersection({cohort['tus-a']!['id'], cohort['tus-b']!['id']}),
          isEmpty,
        );
        expect(expected.length, lessThanOrEqualTo(25));
      } else {
        expect(ids.contains(cohort['tus-a']!['id']), isTrue);
        expect(ids.contains(cohort['tus-b']!['id']), isTrue);
      }
      if (state == 'visible') {
        expect(ids.contains(cohort['lgs-b']!['id']), isTrue);
      } else {
        expect(
          ids.contains(cohort['lgs-b']!['id']),
          isFalse,
          reason:
              'hidden/blocked peer identity cannot escape into either scope',
        );
        if (scope == 'segment') {
          expect(
            expected.any(
              (r) =>
                  r['id'] == null &&
                  r['name'] == null &&
                  r['avatar_id'] == null,
            ),
            isTrue,
          );
        }
      }
      if (kind == 'study') {
        await _studyView(tester, expected, scope, state);
      } else {
        await _examView(tester, expected, scope, state);
      }
      debugPrint(
        '[AF_LEAGUES] lang=${_text.localeName} kind=$kind scope=$scope state=$state rows=${expected.length} exact SQL/RPC/native order PASS',
      );
    }
  }
}

Future<void> _leagues(WidgetTester tester) async {
  final cohort = await _cohort();
  final observer = await _signIn(cohort['lgs-a']!['email'] as String);
  final peer = await _signIn(cohort['lgs-b']!['email'] as String);
  final owners = cohort.values.map((r) => r['id'] as String).toList();
  // The fixture helper must have placed the two peers in the same target room
  // for BOTH products. Do not silently test masking against an absent peer.
  final memberships = await E2eHost.rows(
    'select a.kind,a.room_id=b.room_id as same_room '
    'from public.competition_memberships a join public.competition_memberships b on b.kind=a.kind and b.period_month=a.period_month '
    'where a.user_id=${sqlText(observer.id)} and b.user_id=${sqlText(peer.id)} '
    "and a.period_month=date_trunc('month',now() at time zone 'Europe/Istanbul')::date order by a.kind",
  );
  expect(memberships, [
    {'kind': 'exam', 'same_room': true},
    {'kind': 'study', 'same_room': true},
  ]);
  final before = await _economyDigest(owners);
  await _login(tester, observer);
  for (final language in ['tr', 'en']) {
    await _language(tester, language);
    await _fourViews(tester, observer.id, cohort, 'visible');
    try {
      await LocalApi.request(
        'PATCH',
        '/rest/v1/profiles?id=eq.${peer.id}',
        token: peer.token,
        body: {'show_in_social_feed': false},
      );
      await _fourViews(tester, observer.id, cohort, 'private');
    } finally {
      await LocalApi.request(
        'PATCH',
        '/rest/v1/profiles?id=eq.${peer.id}',
        token: peer.token,
        body: {'show_in_social_feed': true},
      );
    }
    try {
      final result =
          await LocalApi.rpc('block_user', observer, {'p_user_id': peer.id})
              as Map;
      expect(result['success'], isTrue);
      await _fourViews(tester, observer.id, cohort, 'blocked');
    } finally {
      await LocalApi.rpc('unblock_user', observer, {'p_user_id': peer.id});
    }
    expect(
      await _economyDigest(owners),
      before,
      reason: 'scope/privacy/language reads cannot mutate either economy',
    );
  }
  expect(tester.takeException(), isNull);
}

void main() {
  initE2e();
  testWidgets(
    'af1 · social status endings privacy and block natural polling TR EN',
    (tester) async {
      await _social(tester);
    },
    skip: !const {'all', 'social'}.contains(_phase),
    timeout: const Timeout(Duration(minutes: 10)),
  );
  testWidgets(
    'af2 · study exam target global ordered SQL privacy cohort TR EN',
    (tester) async {
      await _leagues(tester);
    },
    skip: !const {'all', 'leagues'}.contains(_phase),
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
