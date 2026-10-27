// I08: one real native observer + eight API-backed local QA friends.
// Fixture setup: i08_multiuser_fixture.py setup/refresh --run-id night-1028.
// This does not claim eight native devices or completed full-duration exams.
// TR/EN is switched through LanguageService to test rendering; the Settings
// language-selection flow is covered separately.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/social_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/widgets/social/presence_dot.dart';

import 'support/e2e.dart';

const _fixtureRun = String.fromEnvironment(
  'E2E_SOCIAL_FIXTURE_RUN',
  defaultValue: 'night-1028',
);

Future<ApiAccount> _signInFixture(String role) async {
  final email = 'qa-i08-$_fixtureRun-$role@pomosprint.local';
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

Finder _socialScrollable() => find
    .descendant(
      of: find.byType(SocialScreen),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _showFriend(WidgetTester tester, String id) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey('social-friend-$id')),
    240,
    scrollable: _socialScrollable(),
    maxScrolls: 40,
    duration: const Duration(milliseconds: 100),
  );
  await pumpFor(tester, const Duration(milliseconds: 150));
}

void _expectFriend(
  WidgetTester tester,
  Map<String, dynamic> row,
  AppLocalizations l10n,
) {
  final card = find.byKey(ValueKey('social-friend-${row['id']}'));
  expect(card, findsOneWidget);
  expect(
    find.descendant(of: card, matching: find.text(row['name'] as String)),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: card,
      matching: find.text(SocialScreen.liveStatusText(row, l10n)),
    ),
    findsOneWidget,
  );
  final dot = tester.widget<SocialPresenceDot>(
    find.descendant(of: card, matching: find.byType(SocialPresenceDot)),
  );
  expect(dot.onBreak, row['status'] == 'break');
  expect(
    tester.takeException(),
    isNull,
    reason: 'native social row must not overflow',
  );
}

void main() {
  initE2e();
  testWidgets(
    'q · eight local friends, TR/EN rows and natural presence polling',
    (tester) async {
      expect(RegExp(r'^[a-z0-9-]{1,32}$').hasMatch(_fixtureRun), isTrue);
      expect(
        const {
          'http://127.0.0.1:54321',
          'http://10.0.2.2:54321',
        }.contains(kSupabaseUrl),
        isTrue,
      );
      final observer = await _signInFixture('observer');
      final initial =
          await LocalApi.rpc('get_live_friends_with_breaks', observer) as List;
      final rows = [
        for (final row in initial) Map<String, dynamic>.from(row as Map),
      ];
      expect(
        rows,
        hasLength(8),
        reason: 'refresh the explicitly named I08 fixture before this test',
      );
      expect(rows.map((r) => r['id']).toSet(), hasLength(8));
      expect(rows.where((r) => r['status'] == 'focus'), hasLength(4));
      expect(rows.where((r) => r['status'] == 'break'), hasLength(2));
      expect(rows.where((r) => r['status'] == 'exam'), hasLength(2));
      final accepted = await LocalApi.rpc('get_my_friends', observer) as List;
      expect(
        accepted.map((r) => (r as Map)['id']).toSet(),
        rows.map((r) => r['id']).toSet(),
      );

      await resetAppState(tester);
      await launchApp(tester);
      await waitPastSplash(tester);
      await loginViaUi(tester, observer.email);
      await pumpUntil(
        tester,
        find.byType(MainNavigationShell),
        reason: 'native fixture observer shell',
      );
      await tapOn(tester, find.text(tr('nav_social')).last);
      await pumpUntil(
        tester,
        find.byKey(ValueKey('social-friend-${rows.first['id']}')),
      );

      for (final language in [AppLanguage.tr, AppLanguage.en]) {
        await LanguageService.instance.setLanguage(language);
        await pumpFor(tester, const Duration(milliseconds: 500));
        final l10n = lookupAppLocalizations(Locale(language.name));
        tester.state<ScrollableState>(_socialScrollable()).position.jumpTo(0);
        await pumpFor(tester, const Duration(milliseconds: 200));
        await E2eHost.screenshot(
          tester,
          'e2e-eight-social-${language.name}-top',
        );
        for (final row in rows) {
          await _showFriend(tester, row['id'] as String);
          _expectFriend(tester, row, l10n);
        }
        await E2eHost.screenshot(
          tester,
          'e2e-eight-social-${language.name}-bottom',
        );
      }

      final actor = await _signInFixture('focus1');
      final target = rows.singleWhere((row) => row['id'] == actor.id);
      expect(target['status'], 'focus');
      var changed = false;
      try {
        tester.state<ScrollableState>(_socialScrollable()).position.jumpTo(0);
        await pumpFor(tester, const Duration(milliseconds: 100));
        await _showFriend(tester, actor.id);
        final config =
            await LocalApi.request(
                  'POST',
                  '/rest/v1/rpc/get_exam_config',
                  body: {},
                )
                as Map;
        final serverNow = DateTime.parse(config['server_time'] as String);
        await LocalApi.rpc('start_study_break', actor, {
          'p_ends_at': serverNow
              .add(const Duration(minutes: 5))
              .toUtc()
              .toIso8601String(),
        });
        changed = true;
        // No tab switch, manual refresh, SQL mutation or stats notification:
        // the existing visible SocialScreen's natural 30-second poll must see it.
        final l10n = lookupAppLocalizations(const Locale('en'));
        await pumpUntilTrue(
          tester,
          () {
            final card = find.byKey(ValueKey('social-friend-${actor.id}'));
            return find
                .descendant(of: card, matching: find.text(l10n.socialOnBreak))
                .evaluate()
                .isNotEmpty;
          },
          timeout: const Duration(seconds: 45),
          reason: 'natural social poll observes focus → break',
        );
        _expectFriend(tester, {...target, 'status': 'break'}, l10n);
        final updated =
            await LocalApi.rpc('get_live_friends_with_breaks', observer)
                as List;
        expect(
          updated.where((row) => (row as Map)['status'] == 'break'),
          hasLength(3),
        );
        await E2eHost.screenshot(tester, 'e2e-eight-social-natural-poll');
      } finally {
        if (changed) {
          await LocalApi.rpc('start_study_session', actor, {
            'p_duration_minutes': 25,
            'p_category_name': 'Matematik',
          });
        }
        await LanguageService.instance.setLanguage(AppLanguage.tr);
      }
      expect(tester.takeException(), isNull);
    },
  );
}
