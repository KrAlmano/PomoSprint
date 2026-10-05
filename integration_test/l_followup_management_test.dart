import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/screens/friends_sheet.dart';
import 'package:pomodoro/screens/social_screen.dart';
import 'package:pomodoro/services/device_time_zone.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/utils/study_day.dart';
import 'support/e2e.dart';

void main() {
  initE2e();
  testWidgets('l · native saat dilimi, onay kaydı ve arkadaş yönetimi gerçek UI', (
    tester,
  ) async {
    final service = SupabaseService.instance;
    final a = await openShellWithNewAccount(
      tester,
      'manage-a',
      name: 'QA Yönetici',
    );
    final b = await signUpViaApi(e2eEmail('manage-b'), 'QA Arkadaş');
    await completeOnboardingViaApi(b);
    final zone = await DeviceTimeZone.read();
    expect(
      zone,
      isNotNull,
      reason: 'Gerçek ${Platform.operatingSystem} IANA kanalı',
    );
    final initial = await E2eHost.row(
      'select timezone from profiles where id=${sqlText(a.id)}',
    );
    expect(initial!['timezone'], zone);
    expect(service.currentUser.value!.timezone, zone);
    // Seyahat/DST: gerçek sunucu güncellemesi, yalnızca sistem okuması testten verilir.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      DeviceTimeZone.channel,
      (_) async => 'America/New_York',
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        DeviceTimeZone.channel,
        null,
      ),
    );
    await service.syncDeviceTimeZone();
    expect(
      (await E2eHost.row(
        'select timezone from profiles where id=${sqlText(a.id)}',
      ))!['timezone'],
      'America/New_York',
    );
    expect(service.currentUser.value!.timezone, 'America/New_York');
    expect(activeStudyTimeZone, 'America/New_York');
    expect(
      studyDayKey(studyDayOf(DateTime.utc(2026, 3, 8, 7, 59))),
      '2026-03-07',
    );
    expect(studyDayKey(studyDayOf(DateTime.utc(2026, 3, 8, 8))), '2026-03-08');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      DeviceTimeZone.channel,
      (_) async => 'bad/zone',
    );
    await service.syncDeviceTimeZone();
    expect(service.currentUser.value!.timezone, 'America/New_York');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      DeviceTimeZone.channel,
      null,
    );
    await service.syncDeviceTimeZone();
    expect(service.currentUser.value!.timezone, zone);
    // signup metadata'sı olmayan provider hesabı gibi: consent ledger temizliği yok;
    // mevcut sürümün idempotent tekrarını ve başka hesaba yazılmadığını sınar.
    final before = await E2eHost.row(
      'select count(*) n from consents where user_id=${sqlText(a.id)}',
    );
    await service.acceptLegalDocuments();
    await service.acceptLegalDocuments();
    final after = await E2eHost.row(
      'select count(*) n from consents where user_id=${sqlText(a.id)}',
    );
    expect(
      after!['n'],
      before!['n'],
    ); // signup ile zaten kayıtlı; RPC unchanged.
    final latest = await E2eHost.rows(
      'select kind,document_version from consents where user_id=${sqlText(a.id)}',
    );
    expect(
      latest
          .where((r) => r['kind'] == 'terms' || r['kind'] == 'privacy_notice')
          .length,
      greaterThanOrEqualTo(2),
    );
    final code =
        ((await LocalApi.request(
                      'GET',
                      '/rest/v1/profiles?select=friend_code&id=eq.${b.id}',
                      token: b.token,
                    ))
                    as List)
                .single['friend_code']
            as String;
    await tapOn(tester, find.byTooltip(trL10n.friendsTitle));
    await pumpUntil(tester, find.byType(FriendsSheet));
    await pumpUntil(tester, find.text(trL10n.friendsYourFriends(0)));
    await tester.enterText(
      find.descendant(
        of: find.byType(FriendsSheet),
        matching: find.byType(TextField),
      ),
      code,
    );
    await tapOn(tester, find.text(trL10n.addBtn));
    await pumpUntil(tester, find.byTooltip(trL10n.friendsCancelRequest));
    await E2eHost.screenshot(tester, 'e2e-giden-istek');
    await tapOn(tester, find.byTooltip(trL10n.friendsCancelRequest));
    await tapOn(tester, find.text(trL10n.friendActionCancel));
    expect(
      (await LocalApi.rpc('get_outgoing_friend_requests', a) as List).length,
      1,
    );
    await tapOn(tester, find.byTooltip(trL10n.friendsCancelRequest));
    await tapOn(tester, find.text(trL10n.friendActionConfirm));
    await pumpUntilGone(tester, find.byTooltip(trL10n.friendsCancelRequest));
    expect(await LocalApi.rpc('get_outgoing_friend_requests', a), isEmpty);
    // Yeni isteği karşı hesap kabul eder; UI yeniden okunur.
    await LocalApi.rpc('add_friend_by_code', a, {'p_code': code});
    await LocalApi.rpc('respond_friend_request', b, {
      'p_from_user_id': a.id,
      'p_accept': true,
    });
    Navigator.of(tester.element(find.byType(FriendsSheet))).pop();
    await pumpUntilGone(tester, find.byType(FriendsSheet));
    await tapOn(tester, find.byTooltip(trL10n.friendsTitle));
    await pumpUntil(tester, find.text(trL10n.friendsYourFriends(1)));
    await tapOn(tester, find.byTooltip(trL10n.userActionsTooltip));
    await tapOn(tester, find.text(trL10n.friendsRemoveAction));
    await tapOn(tester, find.text(trL10n.friendActionConfirm));
    await pumpUntil(tester, find.text(trL10n.friendsYourFriends(0)));
    expect(await LocalApi.rpc('get_my_friends', b), isEmpty);
    // Tekrar arkadaşlık + canlı odak; canlı satırdan engelleme.
    await LocalApi.rpc('add_friend_by_code', a, {'p_code': code});
    await LocalApi.rpc('respond_friend_request', b, {
      'p_from_user_id': a.id,
      'p_accept': true,
    });
    Navigator.of(tester.element(find.byType(FriendsSheet))).pop();
    await pumpUntilGone(tester, find.byType(FriendsSheet));
    await LocalApi.rpc('start_study_session', b, {
      'p_duration_minutes': 25,
      'p_category_name': 'Matematik',
    });
    await openTab(tester, 3);
    await pumpUntil(
      tester,
      find.descendant(
        of: find.byType(SocialScreen),
        matching: find.text('QA Arkadaş'),
      ),
    );
    await tapOn(
      tester,
      find.descendant(
        of: find.byType(SocialScreen),
        matching: find.byTooltip(trL10n.userActionsTooltip),
      ),
    );
    await tapOn(tester, find.text(trL10n.blockUserAction));
    await tapOn(tester, find.text(trL10n.friendActionConfirm));
    await pumpUntilGone(
      tester,
      find.descendant(
        of: find.byType(SocialScreen),
        matching: find.text('QA Arkadaş'),
      ),
    );
    expect(await LocalApi.rpc('get_my_friends', b), isEmpty);
    expect((await LocalApi.rpc('get_my_blocks', a) as List).single['id'], b.id);
    expect(await LocalApi.rpc('get_live_friends', a), isEmpty);
    await tapOn(tester, find.byTooltip(trL10n.friendsTitle));
    await pumpUntil(tester, find.byTooltip(trL10n.unblockUserAction));
    await E2eHost.screenshot(tester, 'e2e-engellenen-kullanicilar');
    await tapOn(tester, find.byTooltip(trL10n.unblockUserAction));
    await tapOn(tester, find.text(trL10n.friendActionConfirm));
    await pumpUntilGone(tester, find.byTooltip(trL10n.unblockUserAction));
    expect(await LocalApi.rpc('get_my_blocks', a), isEmpty);
    expect(await LocalApi.rpc('get_my_friends', a), isEmpty);
    await LocalApi.rpc('cancel_study_session', b);
    // Provider benzeri eksik onay metadata: gerçek Auth hesabı, gerçek ledger.
    await resetAppState(tester);
    final raw =
        await LocalApi.request(
              'POST',
              '/auth/v1/signup',
              body: {
                'email': e2eEmail('provider-consent'),
                'password': kE2ePassword,
                'data': {'name': 'QA Onay'},
              },
            )
            as Map;
    final c = ApiAccount(
      (raw['user'] as Map)['id'] as String,
      e2eEmail('provider-consent'),
      raw['access_token'] as String,
    );
    await completeOnboardingViaApi(c);
    await launchApp(tester);
    await waitPastSplash(tester);
    await loginViaUi(tester, c.email);
    expect(
      (await E2eHost.row(
        'select count(*) n from consents where user_id=${sqlText(c.id)}',
      ))!['n'],
      0,
    );
    await service.acceptLegalDocuments();
    await service.acceptLegalDocuments();
    expect(
      (await E2eHost.row(
        "select count(*) n from consents where user_id=${sqlText(c.id)} and source='app_legal_acceptance'",
      ))!['n'],
      2,
    );
    expect(tester.takeException(), isNull);
    debugPrint(
      '[QA] ${Platform.operatingSystem}: IANA native/profile/cache/DST, legal idempotency, cancel/remove/block/unblock gerçek UI: PASS',
    );
  });
}
