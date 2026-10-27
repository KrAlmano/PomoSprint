// Opt-in native UI gaps: incoming friend responses and a 500-sand purchase.
// Only fresh loopback QA accounts are used. Funding is controlled historical
// data accepted by public completion RPCs, not 625 minutes of real waiting.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/screens/character_collection_screen.dart';
import 'package:pomodoro/screens/friends_sheet.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/widgets/avatar_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'support/e2e.dart';

const _enabled = bool.fromEnvironment('E2E_EXTRA_JOURNEYS');
const _avatarId = 'special_gold_miner';

Future<void> _preserveActiveWork() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys()) {
    if (key.startsWith('e2e_real_duration_probe_') ||
        key.startsWith('e2e_normal_http_restart_')) {
      final marker = jsonDecode(prefs.getString(key)!) as Map;
      expect(
        marker['completion_verified'],
        isTrue,
        reason: 'An unfinished real-duration probe owns this installation',
      );
    }
    if (key.startsWith('active_session_uid_')) {
      expect(
        prefs.getString(key),
        isNull,
        reason: 'Never replace a persisted timer with a QA account',
      );
    }
    if (key.startsWith('exam_journal_uid_')) {
      final raw = jsonDecode(prefs.getString(key)!) as List;
      for (final value in raw) {
        final record = ExamLocalRecord.fromJson(value);
        expect(
          record,
          isNotNull,
          reason: 'A damaged journal must be preserved',
        );
        expect(
          record!.pendingAction,
          isNull,
          reason: 'Pending exam operations must not be reset for QA',
        );
        expect(record.attempt?.status, isNot(ExamAttemptStatus.active));
      }
    }
  }
  expect(
    ExamService.instance.activeRecord,
    isNull,
    reason: 'The current owner still has an active/pending exam',
  );
}

Future<ApiAccount> _freshAccount(
  WidgetTester tester,
  String tag,
  String name, {
  Future<void> Function(ApiAccount)? beforeLogin,
}) async {
  await _preserveActiveWork();
  await launchApp(tester);
  await waitPastSplash(tester);
  await _preserveActiveWork();
  final service = SupabaseService.instance;
  if (service.currentUser.value != null) {
    await service.signOutFully();
    await pumpFor(tester, const Duration(milliseconds: 300));
  }
  final account = await signUpViaApi(
    e2eEmail('$tag-${DateTime.now().microsecondsSinceEpoch}'),
    name,
  );
  await completeOnboardingViaApi(account);
  await beforeLogin?.call(account);
  final user = await service.loginUser(account.email, kE2ePassword);
  expect(user, isNotNull);
  await service.setCurrentUser(user);
  await pumpUntil(tester, find.byType(MainNavigationShell));
  expect(service.currentUser.value?.id, account.id);
  await NotificationService.instance.setEnabled(false);
  return account;
}

Future<List<Map<String, dynamic>>> _rpcRows(
  String name,
  ApiAccount account,
) async => [
  for (final row in await LocalApi.rpc(name, account) as List)
    Map<String, dynamic>.from(row as Map),
];

Future<Map<String, dynamic>> _wallet(ApiAccount account) async =>
    (await E2eHost.row(
      'select coins,total_minutes,lifetime_points,avatar_id,timezone '
      'from public.profiles where id=${sqlText(account.id)}',
    ))!;

/// Choose real, non-overlapping intervals within the last 24 hours, split
/// across two 04:00 study days with at most 16 completions in either day.
({String timezone, List<DateTime> starts}) _fundingPlan(DateTime now) {
  for (final (zone, offset) in [('UTC', 0), ('Pacific/Honolulu', -10)]) {
    final local = now.toUtc().add(Duration(hours: offset));
    var boundary = DateTime.utc(local.year, local.month, local.day, 4);
    if (local.isBefore(boundary)) {
      boundary = boundary.subtract(const Duration(days: 1));
    }
    final utcBoundary = boundary.subtract(Duration(hours: offset));
    for (final before in [13, 12, 11, 10, 9, 14, 15, 16]) {
      final starts = [
        for (var i = -before; i < 25 - before; i++)
          utcBoundary.add(Duration(minutes: i * 25)),
      ];
      if (starts.first.isAfter(
            now
                .subtract(const Duration(hours: 24))
                .add(const Duration(minutes: 1)),
          ) &&
          starts.last.add(const Duration(minutes: 26)).isBefore(now)) {
        return (timezone: zone, starts: starts);
      }
    }
  }
  throw StateError(
    'No safe 24-hour funding window; do not bypass server rules',
  );
}

Future<void> _fundThroughCompletions(ApiAccount account) async {
  final baseline = await _wallet(account);
  expect(baseline['coins'], 0);
  expect(baseline['total_minutes'], 0);
  final clock = (await E2eHost.row('select clock_timestamp()::text as now'))!;
  final plan = _fundingPlan(DateTime.parse(clock['now'] as String).toUtc());
  // A test-owned preference, never a balance assignment. Native sign-in may
  // restore the device timezone; it must not change the accepted economics.
  await LocalApi.request(
    'PATCH',
    '/rest/v1/profiles?id=eq.${account.id}',
    token: account.token,
    body: {'timezone': plan.timezone},
  );
  final category = (await categoriesViaApi(account)).first;
  for (final startedAt in plan.starts) {
    final receipt =
        await LocalApi.rpc('complete_study_session', account, {
              'p_client_uuid': const Uuid().v4(),
              'p_category_id': category['id'],
              'p_duration_minutes': 25,
              'p_was_paused': false,
              'p_is_verified': 0,
              'p_started_at': startedAt.toIso8601String(),
            })
            as Map;
    expect(receipt['error'], isNull);
    expect(receipt['duplicate'], isNot(true));
    expect(receipt['coins_earned'], 20);
  }
  final funded = await _wallet(account);
  expect(funded['timezone'], plan.timezone);
  expect(funded['coins'], 500);
  expect(funded['total_minutes'], 625);
  final days = await E2eHost.rows(
    'select ((s.started_at at time zone p.timezone)-interval \'4 hours\')::date::text as day,'
    'count(*)::int as sessions from public.study_sessions s '
    'join public.profiles p on p.id=s.user_id '
    'where s.user_id=${sqlText(account.id)} group by 1 order by 1',
  );
  expect(days, hasLength(2));
  expect(
    days.map((d) => d['sessions'] as int),
    everyElement(lessThanOrEqualTo(16)),
  );
  expect(days.fold<int>(0, (sum, d) => sum + (d['sessions'] as int)), 25);
  debugPrint(
    '[EXTRA_QA_FIXTURE] ${jsonEncode({'kind': 'public_rpc_historical_funding', 'timezone': plan.timezone, 'sessions': 25, 'minutes': 625, 'coins': 500, 'real_wait_minutes': 0, 'direct_balance_update': false})}',
  );
}

Future<void> _openCollection(WidgetTester tester) async {
  await tapOn(
    tester,
    find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(AvatarWidget),
    ),
  );
  await pumpUntil(tester, find.byType(ProfileScreen));
  await tapOn(
    tester,
    find
        .descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(AvatarWidget),
        )
        .first,
  );
  await pumpUntil(tester, find.byType(CharacterCollectionScreen));
}

Future<void> _showSpecial(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('avatar-card-$_avatarId')),
    200,
    scrollable: find
        .descendant(
          of: find.byType(CharacterCollectionScreen),
          matching: find.byType(Scrollable),
        )
        .first,
    maxScrolls: 30,
  );
}

void main() {
  if (_enabled) {
    initE2e();
  } else {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  }

  testWidgets(
    'z1 · incoming friend requests are accepted and rejected through the real UI',
    (tester) async {
      expect(E2eHost.available, isTrue);
      final observer = await _freshAccount(
        tester,
        'extra-friends',
        'QA Gözlemci',
      );
      final accepted = await signUpViaApi(
        e2eEmail('extra-accept-${DateTime.now().microsecondsSinceEpoch}'),
        'QA Kabul',
      );
      final rejected = await signUpViaApi(
        e2eEmail('extra-reject-${DateTime.now().microsecondsSinceEpoch}'),
        'QA Ret',
      );
      await completeOnboardingViaApi(accepted);
      await completeOnboardingViaApi(rejected);
      final code =
          (await E2eHost.row(
                'select friend_code from public.profiles where id=${sqlText(observer.id)}',
              ))!['friend_code']
              as String;
      for (final sender in [accepted, rejected]) {
        final result =
            await LocalApi.rpc('add_friend_by_code', sender, {'p_code': code})
                as Map;
        expect(result['success'], isTrue);
      }
      await tapOn(tester, find.byTooltip(trL10n.friendsTitle));
      await pumpUntil(tester, find.byType(FriendsSheet));
      await pumpUntil(tester, find.text(trL10n.friendsIncoming(2)));
      Finder requestAction(String name, String tooltip) => find.descendant(
        of: find
            .ancestor(of: find.text(name), matching: find.byType(Row))
            .first,
        matching: find.byTooltip(tooltip),
      );
      await tapOn(tester, requestAction('QA Kabul', trL10n.friendsAccept));
      await pumpUntil(tester, find.text(trL10n.friendsYourFriends(1)));
      await tapOn(tester, requestAction('QA Ret', trL10n.friendsReject));
      await pumpUntilGone(tester, find.text('QA Ret'));
      final links = await E2eHost.rows(
        'select user_id::text,friend_id::text,status from public.friendships '
        'where (user_id=${sqlText(observer.id)} and friend_id=${sqlText(accepted.id)}) '
        'or (user_id=${sqlText(accepted.id)} and friend_id=${sqlText(observer.id)})',
      );
      expect(links, hasLength(2));
      expect(links.map((r) => r['status']), everyElement('accepted'));
      expect(
        (await _rpcRows('get_my_friends', observer)).map((r) => r['id']),
        contains(accepted.id),
      );
      expect(
        (await _rpcRows('get_my_friends', accepted)).map((r) => r['id']),
        contains(observer.id),
      );
      expect(await _rpcRows('get_incoming_friend_requests', observer), isEmpty);
      expect(await _rpcRows('get_outgoing_friend_requests', rejected), isEmpty);
      expect(
        await E2eHost.rows(
          'select user_id from public.friendships '
          'where (user_id=${sqlText(observer.id)} and friend_id=${sqlText(rejected.id)}) '
          'or (user_id=${sqlText(rejected.id)} and friend_id=${sqlText(observer.id)})',
        ),
        isEmpty,
      );
      await E2eHost.screenshot(tester, 'e2e-extra-friend-responses');
      expect(tester.takeException(), isNull);
      debugPrint(
        '[EXTRA_QA] incoming accept/reject UI + bidirectional RPC/SQL: PASS',
      );
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 4)),
  );

  testWidgets(
    'z2 · special avatar purchase costs 500 once and real UI equips it',
    (tester) async {
      expect(E2eHost.available, isTrue);
      final account = await _freshAccount(
        tester,
        'extra-avatar',
        'QA Koleksiyon',
        beforeLogin: _fundThroughCompletions,
      );
      final service = SupabaseService.instance;
      final before = await _wallet(account);
      expect(before['coins'], 500);
      expect(before['total_minutes'], 625);
      expect(service.currentUser.value!.coins, 500);
      final catalog = (await E2eHost.row(
        'select cost_coins,is_active from public.avatars where id=${sqlText(_avatarId)}',
      ))!;
      expect(catalog['cost_coins'], 500);
      expect(catalog['is_active'], isTrue);
      await _openCollection(tester);
      await _showSpecial(tester);
      await tapOn(tester, find.byKey(const ValueKey('avatar-card-$_avatarId')));
      await pumpUntil(tester, find.byType(AlertDialog));
      final buy = find.widgetWithText(
        ElevatedButton,
        trL10n.avatarPurchaseTitle,
      );
      expect(tester.widget<ElevatedButton>(buy).onPressed, isNotNull);
      await tapOn(tester, buy);
      await pumpUntilGone(tester, find.byType(AlertDialog));
      await pumpUntilTrue(
        tester,
        () =>
            service.currentUser.value!.coins == 0 &&
            service.currentUser.value!.unlockedAvatars.contains(_avatarId),
        reason: 'Server-approved purchase reaches the real collection',
      );
      await tapOn(
        tester,
        find.widgetWithText(ElevatedButton, trL10n.confirmSelection),
      );
      await pumpUntilGone(tester, find.byType(CharacterCollectionScreen));
      expect(service.currentUser.value!.avatarId, _avatarId);
      final purchased = await _wallet(account);
      expect(purchased['coins'], 0);
      expect(purchased['avatar_id'], _avatarId);
      expect(purchased['total_minutes'], before['total_minutes']);
      expect(purchased['lifetime_points'], before['lifetime_points']);
      final unlocks = await E2eHost.rows(
        'select unlock_type,coins_spent from public.avatar_unlocks '
        'where user_id=${sqlText(account.id)} and avatar_id=${sqlText(_avatarId)}',
      );
      expect(unlocks, [
        {'unlock_type': 'coins', 'coins_spent': 500},
      ]);
      // Current RPC returns the unchanged balance for an already-owned avatar.
      // Do not invent an idempotency field or replace a real error with success.
      expect(
        await LocalApi.rpc('purchase_avatar', account, {
          'p_avatar_id': _avatarId,
        }),
        0,
      );
      expect((await _wallet(account))['coins'], 0);
      expect(
        await E2eHost.rows(
          'select unlock_type,coins_spent from public.avatar_unlocks '
          'where user_id=${sqlText(account.id)} and avatar_id=${sqlText(_avatarId)}',
        ),
        unlocks,
      );
      // Reopen and tap the owned avatar: selection, not a second purchase dialog.
      await tapOn(
        tester,
        find
            .descendant(
              of: find.byType(ProfileScreen),
              matching: find.byType(AvatarWidget),
            )
            .first,
      );
      await pumpUntil(tester, find.byType(CharacterCollectionScreen));
      await _showSpecial(tester);
      await tapOn(tester, find.byKey(const ValueKey('avatar-card-$_avatarId')));
      expect(find.byType(AlertDialog), findsNothing);
      await E2eHost.screenshot(tester, 'e2e-extra-special-avatar-owned');
      await tapOn(
        tester,
        find.widgetWithText(ElevatedButton, trL10n.confirmSelection),
      );
      await pumpUntilGone(tester, find.byType(CharacterCollectionScreen));
      expect((await _wallet(account))['coins'], 0);
      expect(tester.takeException(), isNull);
      debugPrint(
        '[EXTRA_QA] 500-sand purchase/equip/repeated-owned RPC + UI, one unlock: PASS',
      );
    },
    skip: !_enabled,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
