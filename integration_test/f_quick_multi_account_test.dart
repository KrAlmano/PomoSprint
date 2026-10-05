// Gerçek iOS uygulaması + yerel Supabase: beş yeni hesap, kısa sayaçtan
// kaydedilen seanslar, raporlar, arkadaşlar ve canlı sosyal liste.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pomodoro/screens/friends_sheet.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/screens/history_screen.dart';
import 'package:pomodoro/screens/monthly_tracking_screen.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:pomodoro/screens/social_screen.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/local_test_mode.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/widgets/stats/stats_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/e2e.dart';

void main() {
  initE2e();
  testWidgets('beş hesap: 5/10 saniye → kayıt, rapor, arkadaş, sosyal', (
    tester,
  ) async {
    expect(kQuickTimer && recordLocalQuickSessions, isTrue);
    final accounts = <ApiAccount>[];
    final totals = [75, 25, 50, 25, 50];
    final points = [17, 5, 12, 5, 12];
    final codes = <String>[];
    for (var i = 0; i < 5; i++) {
      late ApiAccount account;
      if (const bool.fromEnvironment('E2E_REUSE')) {
        final email = e2eEmail('qa${i + 1}');
        final auth =
            await LocalApi.request(
                  'POST',
                  '/auth/v1/token?grant_type=password',
                  body: {'email': email, 'password': kE2ePassword},
                )
                as Map;
        account = ApiAccount(auth['user']['id'], email, auth['access_token']);
        await resetAppState(tester);
        await launchApp(tester);
        await waitPastSplash(tester);
        await loginViaUi(tester, email);
        await pumpUntil(tester, find.byType(NavigationBar));
      } else {
        account = await openShellWithNewAccount(
          tester,
          'qa${i + 1}',
          name: 'QA Kullanıcı ${i + 1}',
        );
      }
      accounts.add(account);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('league_info_shown_${account.id}', true);
      // İzin penceresi bu veri senaryosunu durdurmasın. Native bildirimler
      // aşağıda ayrı olarak, gerçek platform eklentisiyle kontrol edilir.
      await NotificationService.instance.setEnabled(false);
      final profile =
          (await LocalApi.request(
                        'GET',
                        '/rest/v1/profiles?select=friend_code&id=eq.${account.id}',
                        token: account.token,
                      )
                      as List)
                  .single
              as Map;
      codes.add(profile['friend_code'] as String);
      for (final minutes
          in (const bool.fromEnvironment('E2E_REUSE')
              ? <int>[]
              : (i == 0 ? [25, 50] : [i.isEven ? 50 : 25]))) {
        if (minutes == 50) await tapOn(tester, find.text('50 dk'));
        await tapOn(tester, find.text(tr('btn_start')));
        await pumpUntil(
          tester,
          find.byType(SessionCompletedDialog),
          timeout: const Duration(seconds: 25),
          reason: '${account.email}: $minutes dk sonucu',
        );
        await pumpUntil(
          tester,
          find.text(trL10n.sessionResultPoints(minutes == 25 ? 5 : 12)),
          reason: 'sunucu puanı',
        );
        expect(find.text(trL10n.sessionResultCoins(20)), findsOneWidget);
        await tapOn(
          tester,
          find.widgetWithText(ElevatedButton, trL10n.sessionCompletedOk),
        );
        await pumpUntilGone(tester, find.byType(SessionCompletedDialog));
      }
      expect(shellStats(tester), (points: points[i], coins: i == 0 ? 40 : 20));
      final sessions =
          await LocalApi.request(
                'GET',
                '/rest/v1/study_sessions?select=duration_minutes,started_at,completed_at,base_points&order=started_at',
                token: account.token,
              )
              as List;
      expect(
        sessions.length,
        i == 0 ? 2 : 1,
        reason: 'hesaba özel seans kaydı',
      );
      expect(
        sessions.fold<int>(0, (sum, s) => sum + (s['duration_minutes'] as int)),
        totals[i],
      );
      for (final s in sessions) {
        expect(
          DateTime.parse(
            s['completed_at'],
          ).difference(DateTime.parse(s['started_at'])).inSeconds,
          s['duration_minutes'] == 25 ? 5 : 10,
        );
      }
      await openTab(tester, 1);
      await pumpUntil(
        tester,
        find.descendant(
          of: find.byType(ReportsScreen),
          matching: find.textContaining('${StatsText.duration(totals[i])} / '),
        ),
        reason: 'günlük rapor ${totals[i]} dk',
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == trL10n.statsTodayPomodoros(totals[i] ~/ 25),
        ),
        findsOneWidget,
      );
      await E2eHost.screenshot(tester, 'e2e-qa${i + 1}-rapor');
      for (final key in ['reports_tab_history', 'reports_tab_monthly']) {
        await tapOn(tester, find.text(tr(key)));
        expect(tester.takeException(), isNull, reason: '$key ekranı');
        if (key == 'reports_tab_history') {
          final screen = tester.widget<HistoryScreen>(
            find.byType(HistoryScreen),
          );
          expect(
            sumMinutesBetween(
              screen.sessions,
              mondayOf(screen.today),
              addDays(mondayOf(screen.today), 6),
            ),
            totals[i],
          );
        } else {
          final screen = tester.widget<MonthlyTrackingScreen>(
            find.byType(MonthlyTrackingScreen),
          );
          expect(
            sumMinutesBetween(
              screen.sessions,
              monthStartOf(screen.today),
              monthEndOf(screen.today),
            ),
            totals[i],
          );
        }
        expect(find.text(trL10n.statsNoStudyTodayTitle), findsNothing);
      }
      final league =
          await LocalApi.rpc('get_my_league_ranking', account) as List;
      expect(
        league.singleWhere((r) => r['is_me'] == true)['weekly_points'],
        points[i],
      );
      debugPrint(
        '[QA] ${account.email}: ${totals[i]} dk, ${points[i]} puan, ${i == 0 ? 40 : 20} kum; günlük/haftalık/aylık ekran açıldı',
      );
    }
    // Beş hesap arasında halka: her kullanıcının iki arkadaşı var.
    for (var i = 0; i < 5; i++) {
      final next = (i + 1) % 5;
      await LocalApi.rpc('add_friend_by_code', accounts[i], {
        'p_code': codes[next],
      });
      await LocalApi.rpc('respond_friend_request', accounts[next], {
        'p_from_user_id': accounts[i].id,
        'p_accept': true,
      });
    }
    for (var i = 0; i < 5; i++) {
      final friends = await LocalApi.rpc('get_my_friends', accounts[i]) as List;
      expect(friends.length, 2, reason: 'QA${i + 1}: karşılıklı iki arkadaş');
      expect(friends.map((r) => r['id']).toSet(), {
        accounts[(i + 1) % 5].id,
        accounts[(i + 4) % 5].id,
      });
    }
    // Son açık hesap QA5: gerçek arkadaş sayfası.
    await openTab(tester, 0);
    await tapOn(tester, find.byTooltip(trL10n.friendsTitle));
    await pumpUntil(tester, find.text(trL10n.friendsYourFriends(2)));
    expect(
      find.descendant(
        of: find.byType(FriendsSheet),
        matching: find.text('QA Kullanıcı 1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(FriendsSheet),
        matching: find.text('QA Kullanıcı 4'),
      ),
      findsOneWidget,
    );
    await E2eHost.screenshot(tester, 'e2e-qa5-arkadaslar');
    Navigator.of(tester.element(find.byType(FriendsSheet))).pop();
    await pumpUntilGone(tester, find.byType(FriendsSheet));
    // QA1 ve QA4 odakta. QA5 ikisini de görmeli.
    for (final a in [accounts[0], accounts[3]]) {
      await LocalApi.rpc('start_study_session', a, {
        'p_duration_minutes': 25,
        'p_category_name': 'Matematik',
      });
    }
    await openTab(tester, 3);
    Finder liveName(String name) => find.descendant(
      of: find.byType(SocialScreen),
      matching: find.text(name),
    );
    await pumpUntil(
      tester,
      liveName('QA Kullanıcı 1'),
      timeout: const Duration(seconds: 8),
    );
    await pumpUntil(
      tester,
      liveName('QA Kullanıcı 4'),
      timeout: const Duration(seconds: 8),
    );
    await E2eHost.screenshot(tester, 'e2e-qa5-canli');
    // Sosyal sekmesi açıkken kısa odak değişimleri de 2 sn QA yoklamasıyla gelir.
    await LocalApi.rpc('cancel_study_session', accounts[0]);
    await pumpUntilGone(
      tester,
      liveName('QA Kullanıcı 1'),
      timeout: const Duration(seconds: 5),
    );
    await LocalApi.rpc('start_study_session', accounts[0], {
      'p_duration_minutes': 1,
      'p_category_name': 'Matematik',
    });
    await pumpUntil(
      tester,
      liveName('QA Kullanıcı 1'),
      timeout: const Duration(seconds: 5),
    );
    await pumpFor(tester, const Duration(seconds: 3));
    await LocalApi.rpc('cancel_study_session', accounts[0]);
    await pumpUntilGone(
      tester,
      liveName('QA Kullanıcı 1'),
      timeout: const Duration(seconds: 5),
    );
    debugPrint(
      '[QA] Açık sosyal sekmede kısa odak başlat/iptal, 2 sn poll: PASS',
    );
    await LocalApi.rpc('start_study_session', accounts[0], {
      'p_duration_minutes': 25,
      'p_category_name': 'Matematik',
    });
    // Sosyalden çıkınca iptal edip hemen dön: 30 sn eski önbellek olmamalı.
    await openTab(tester, 0);
    await LocalApi.rpc('cancel_study_session', accounts[0]);
    await openTab(tester, 3);
    await pumpUntilGone(
      tester,
      liveName('QA Kullanıcı 1'),
      timeout: const Duration(seconds: 8),
    );
    expect(liveName('QA Kullanıcı 4'), findsOneWidget);
    // Görünürlük kapatılınca yoklama onu kaldırır.
    await LocalApi.request(
      'PATCH',
      '/rest/v1/profiles?id=eq.${accounts[3].id}',
      token: accounts[3].token,
      body: {'show_in_social_feed': false},
    );
    await pumpUntilGone(
      tester,
      liveName('QA Kullanıcı 4'),
      timeout: const Duration(seconds: 35),
    );
    await LocalApi.rpc('cancel_study_session', accounts[3]);
    await LocalApi.request(
      'PATCH',
      '/rest/v1/profiles?id=eq.${accounts[3].id}',
      token: accounts[3].token,
      body: {'show_in_social_feed': true},
    );
    // Gerçek iOS bildirim eklentisi: izin durumunu ve native bekleyen
    // kaydın ekleme/iptalini denetle. İzin verilmediyse teslim iddiası yok.
    final permission = await NotificationService.instance.permissionStatus();
    debugPrint('[QA] Native bildirim izni: $permission');
    // Sistem izin penceresi Flutter widget sürücüsüyle tıklanamaz.
    // İzin istemeden gerçek native zamanlama/iptal yollarını ölç.
    await (await SharedPreferences.getInstance()).setBool(
      'notifications_enabled',
      true,
    );
    await NotificationService.instance.scheduleSessionEnd(
      after: const Duration(seconds: 60),
      categoryName: 'QA',
    );
    final plugin = FlutterLocalNotificationsPlugin();
    final pending = await plugin.pendingNotificationRequests();
    debugPrint(
      '[QA] Native bekleyen bildirimler: ${pending.map((n) => n.id).toList()}',
    );
    if (permission == NotificationPermissionStatus.granted) {
      expect(
        pending.any((n) => n.id == 0),
        isTrue,
        reason: 'native bildirim kaydı',
      );
    } else {
      debugPrint(
        '[QA] Native bildirim kaydı/teslimi DOĞRULANAMADI: sistem izni gerekli.',
      );
    }
    await NotificationService.instance.cancelSessionEndNotification();
    expect(
      (await plugin.pendingNotificationRequests()).any((n) => n.id == 0),
      isFalse,
    );
    expect(tester.takeException(), isNull);
    debugPrint(
      '[QA] BEŞ HESAP QA TAMAMLANDI: ${accounts.map((a) => a.email).join(', ')}',
    );
  });
}
