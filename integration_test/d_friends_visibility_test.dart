// (d) İKİ HESAP GÖRÜNÜRLÜĞÜ. A hesabı API ile (onboarding tamam,
// show_in_social_feed true); uygulamada B, A'nın arkadaş koduyla istek
// gönderir → A API ile kabul eder → B'nin arkadaş listesinde A → A API ile
// start_study_session → B'nin canlı akışında (Sosyal) A → Sıralama >
// Arkadaşlar'da ikisi ve B'nin kendi satırı "(Sen)".
//
// Çalıştırma: tool/local_supabase/e2e/sim/run_sim_e2e.sh d

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/screens/friends_sheet.dart';
import 'package:pomodoro/screens/ranking_screen.dart';
import 'package:pomodoro/screens/social_screen.dart';

import 'support/e2e.dart';

void main() {
  initE2e();
  final l10n = trL10n;

  testWidgets(
    'd · arkadaş kodu → kabul → arkadaş listesi, canlı akış, sıralama (is_me)',
    (tester) async {
      final b = await openShellWithNewAccount(
        tester,
        'arkadas-b',
        name: 'Sim Bora',
      );
      final a = await signUpViaApi(e2eEmail('arkadas-a'), 'Sim Ayla');
      await completeOnboardingViaApi(a, showInSocialFeed: true);
      final aProfile =
          (await LocalApi.request(
                        'GET',
                        '/rest/v1/profiles?select=friend_code&id=eq.${a.id}',
                        token: a.token,
                      )
                      as List)
                  .single
              as Map;
      final code = aProfile['friend_code'] as String;

      // B: arkadaş kodu ile istek.
      await tapOn(
        tester,
        find.byTooltip(l10n.friendsTitle),
        settle: const Duration(seconds: 1),
      );
      await pumpUntil(tester, find.byType(FriendsSheet));
      await pumpUntil(
        tester,
        find.text(l10n.friendsYourFriends(0)),
        reason: 'arkadaş listesi yüklendi (boş)',
      );
      final codeField = find.descendant(
        of: find.byType(FriendsSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(codeField, code);
      await pumpFor(tester, const Duration(milliseconds: 300));
      await tapOn(
        tester,
        find.descendant(
          of: find.byType(FriendsSheet),
          matching: find.text(l10n.addBtn),
        ),
      );
      await pumpUntil(
        tester,
        find.text(l10n.friendsRequestSent('Sim Ayla')),
        reason: 'istek gönderildi bildirimi',
      );
      final pending = await E2eHost.row(
        'select status from public.friendships where user_id = ${sqlText(b.id)} and friend_id = ${sqlText(a.id)}',
      );
      expect(
        pending?['status'],
        'pending',
        reason: 'psql: bekleyen istek B → A',
      );

      // A: API ile kabul.
      await LocalApi.rpc('respond_friend_request', a, {
        'p_from_user_id': b.id,
        'p_accept': true,
      });
      final accepted = await E2eHost.rows(
        'select status from public.friendships where (user_id = ${sqlText(b.id)} and friend_id = ${sqlText(a.id)}) '
        'or (user_id = ${sqlText(a.id)} and friend_id = ${sqlText(b.id)})',
      );
      expect(accepted, isNotEmpty);
      expect(
        accepted.every((r) => r['status'] == 'accepted'),
        isTrue,
        reason: 'psql: arkadaşlık kabul edildi ($accepted)',
      );

      // B: sayfa yeniden açılınca A listede.
      Navigator.of(tester.element(find.byType(FriendsSheet))).pop();
      await pumpUntilGone(tester, find.byType(FriendsSheet));
      await tapOn(
        tester,
        find.byTooltip(l10n.friendsTitle),
        settle: const Duration(seconds: 1),
      );
      await pumpUntil(
        tester,
        find.text(l10n.friendsYourFriends(1)),
        reason: 'Arkadaşların (1)',
      );
      expect(
        find.descendant(
          of: find.byType(FriendsSheet),
          matching: find.text('Sim Ayla'),
        ),
        findsOneWidget,
      );
      await E2eHost.screenshot(tester, 'e2e-arkadaslar');
      Navigator.of(tester.element(find.byType(FriendsSheet))).pop();
      await pumpUntilGone(tester, find.byType(FriendsSheet));

      // A: seans başlatır (sosyal görünürlük açık).
      await LocalApi.rpc('start_study_session', a, {
        'p_duration_minutes': 25,
        'p_category_name': 'Matematik',
      });
      final live = await E2eHost.psql(
        "select set_config('request.jwt.claims', json_build_object('sub', ${sqlText(b.id)}, 'role', 'authenticated')::text, true); "
        'select public.get_live_friends()::text',
      );
      expect(
        live,
        contains('Sim Ayla'),
        reason: 'psql: B için get_live_friends A\'yı döndürür',
      );

      // B: Sosyal sekmesinde canlı akış.
      await openTab(tester, 3);
      final liveName = find.descendant(
        of: find.byType(SocialScreen),
        matching: find.text('Sim Ayla'),
      );
      await pumpUntil(
        tester,
        liveName,
        timeout: const Duration(seconds: 45),
        reason: 'canlı akışta A (30 sn yoklama)',
      );
      expect(
        find.descendant(
          of: find.byType(SocialScreen),
          matching: find.text(l10n.socialFocusing),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SocialScreen),
          matching: find.byType(ChoiceChip),
        ),
        findsNothing,
      );
      await E2eHost.screenshot(tester, 'e2e-canli-akis');

      // B: Sıralama > Arkadaşlar: ikisi ve kendi satırı (is_me).
      await openTab(tester, 2);
      await tapOn(
        tester,
        find.descendant(
          of: find.byType(RankingScreen),
          matching: find.text(l10n.rankingTabFriends),
        ),
      );
      final ranking = find.byType(RankingScreen);
      await pumpUntil(
        tester,
        find.descendant(of: ranking, matching: find.textContaining('Sim Ayla')),
        timeout: const Duration(seconds: 20),
        reason: 'Sıralama > Arkadaşlar: A',
      );
      expect(
        find.descendant(of: ranking, matching: find.textContaining('Sim Bora')),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: ranking,
          matching: find.textContaining(l10n.youBadge),
        ),
        findsWidgets,
        reason: 'B\'nin kendi satırı (Sen)',
      );
      await E2eHost.screenshot(tester, 'e2e-siralama-arkadaslar');

      // A'nın canlı oturumu temizlenir (sonraki koşuları etkilemesin).
      await LocalApi.rpc('cancel_study_session', a);
    },
  );
}
