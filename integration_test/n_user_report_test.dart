// Gerçek uygulama + yerel RPC: arkadaş menüsünden bildirim, aynı bildirimin
// yinelenmesi ve vazgeçmenin yeni satır yazmaması. Canlıya bağlanmaz.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/screens/friends_sheet.dart';
import 'support/e2e.dart';

void main() {
  initE2e();
  testWidgets('n · arkadaş bildirimi gerçek UI/RPC ve duplicate', (
    tester,
  ) async {
    final a = await openShellWithNewAccount(
      tester,
      'report-a',
      name: 'QA Bildiren',
    );
    final b = await signUpViaApi(e2eEmail('report-b'), 'QA Hedef');
    await completeOnboardingViaApi(b);
    final code =
        ((await LocalApi.request(
                      'GET',
                      '/rest/v1/profiles?select=friend_code&id=eq.${b.id}',
                      token: b.token,
                    ))
                    as List)
                .single['friend_code']
            as String;
    await LocalApi.rpc('add_friend_by_code', a, {'p_code': code});
    await LocalApi.rpc('respond_friend_request', b, {
      'p_from_user_id': a.id,
      'p_accept': true,
    });
    await tapOn(tester, find.byTooltip(trL10n.friendsTitle));
    await pumpUntil(tester, find.byType(FriendsSheet));
    await pumpUntil(tester, find.text(trL10n.friendsYourFriends(1)));

    Future<void> openReport() async {
      await tapOn(tester, find.byTooltip(trL10n.userActionsTooltip));
      await tapOn(tester, find.text(trL10n.reportUserAction));
      await pumpUntil(tester, find.byType(DropdownButtonFormField<String>));
    }

    Future<void> selectSpam() async {
      await tapOn(tester, find.byType(DropdownButtonFormField<String>));
      await tapOn(tester, find.text(trL10n.reportReasonSpam).last);
    }

    Future<int> rowCount() async =>
        (await E2eHost.row(
              'select count(*) n from user_reports where reporter_id=${sqlText(a.id)} '
              'and target_user_id=${sqlText(b.id)}',
            ))!['n']
            as int;

    await openReport();
    await tapOn(
      tester,
      find.widgetWithText(FilledButton, trL10n.reportSendButton),
    );
    expect(find.text(trL10n.reportChooseReason), findsOneWidget);
    expect(await rowCount(), 0);
    await selectSpam();
    await tester.enterText(
      find.byType(TextFormField).last,
      '  Yerel QA bildirimi  ',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tapOn(
      tester,
      find.widgetWithText(FilledButton, trL10n.reportSendButton),
    );
    await pumpUntilGone(tester, find.byType(DropdownButtonFormField<String>));
    await pumpUntil(tester, find.text(trL10n.reportSent));
    expect(await rowCount(), 1);
    expect(
      await E2eHost.row(
        'select place,reason,details from user_reports where reporter_id=${sqlText(a.id)} '
        'and target_user_id=${sqlText(b.id)}',
      ),
      {
        'place': 'friends_list',
        'reason': 'spam',
        'details': 'Yerel QA bildirimi',
      },
    );
    await E2eHost.screenshot(tester, 'e2e-bildirme-kaydedildi');

    await openReport();
    await selectSpam();
    await tapOn(
      tester,
      find.widgetWithText(FilledButton, trL10n.reportSendButton),
    );
    await pumpUntilGone(tester, find.byType(DropdownButtonFormField<String>));
    await pumpUntil(tester, find.text(trL10n.reportAlreadyReceived));
    expect(await rowCount(), 1);
    await openReport();
    await E2eHost.screenshot(tester, 'e2e-bildirme-formu');
    await tapOn(tester, find.widgetWithText(TextButton, trL10n.cancel));
    await pumpUntilGone(tester, find.byType(DropdownButtonFormField<String>));
    expect(await rowCount(), 1);
    expect(tester.takeException(), isNull);
    debugPrint(
      '[QA] Bildirme formu, gerçek RPC, zorunlu neden, duplicate ve iptal: PASS',
    );
  });
}
