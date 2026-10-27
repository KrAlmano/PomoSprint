// (c) SEANS KAYDI VE PUAN + (f) LİG, gerçek akış.
//
// Uygulama kapalıyken biten seans: kullanıcı girişliyken uygulama kapanır;
// cihazdaki TimerPersistence kaydına (gerçek biçim ve sahip anahtarı =
// kullanıcı kimliği) 26 dk önce başlamış 25 dk'lık ÇALIŞAN seans yazılır;
// uygulama yeniden açılınca sayaç seansı tamamlar, kuyruk
// complete_study_session'a gönderir, sonuç diyaloğu sunucunun puanını (5)
// ve kumunu (20) gösterir; üst çubuk güncellenir; psql'de study_sessions ve
// profil toplamları; Raporlar'da bugünkü 25 dk; Sıralama > Lig'de kullanıcı
// puanıyla (is_me → "(Sen)").
//
// Çalıştırma: tool/local_supabase/e2e/sim/run_sim_e2e.sh c

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/main_shell.dart';
import 'package:pomodoro/screens/ranking_screen.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/widgets/social/ranking_widgets.dart';
import 'package:pomodoro/widgets/stats/stats_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'support/e2e.dart';

void main() {
  initE2e();
  final l10n = trL10n;

  testWidgets(
    'c+f · kapalıyken biten seans: diyalog 5 puan / 20 kum, üst çubuk, psql, Raporlar, Lig',
    (tester) async {
      final account = await openShellWithNewAccount(
        tester,
        'seans',
        name: 'Sim Seans',
      );
      expect(shellStats(tester), (
        points: 0,
        coins: 0,
      ), reason: 'yeni hesap: 0 puan, 0 kum');
      final category = (await categoriesViaApi(
        account,
      )).firstWhere((c) => c['name'] == 'Matematik');

      // "Uygulama kapanır": ekran ağacı kapatılır (oturum cihazda kalır).
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 300));

      // Kapalıyken: 26 dk önce başlamış, 25 dk'lık, duraklatılmamış çalışan seans.
      final clientUuid = const Uuid().v4();
      final startedAt = DateTime.now().subtract(const Duration(minutes: 26));
      final running = ActiveTimerSession.start(
        clientUuid: clientUuid,
        categoryId: category['id'] as String,
        categoryName: 'Matematik',
        categoryColorHex: '#E53935',
        durationMinutes: 25,
        totalSeconds: timerDurationSeconds(25, quick: false),
        now: startedAt,
      ).withForegroundSeconds(25 * 60);
      expect(running.isFinishedAt(DateTime.now()), isTrue);
      await TimerPersistence.instance.save(account.id, running);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(TimerPersistence.keyFor(account.id)),
        contains(clientUuid),
      );
      // Lig bilgi sayfası (ilk lig ziyaretinde bir kez açılır) ekranı örtmesin.
      await prefs.setBool('league_info_shown_${account.id}', true);

      // Uygulama yeniden açılır: oturum geri yüklenir, seans tamamlanır.
      await launchApp(tester);
      await pumpUntil(
        tester,
        find.byType(MainNavigationShell),
        timeout: const Duration(seconds: 40),
        reason: 'kabuk',
      );
      await pumpUntil(
        tester,
        find.byType(SessionCompletedDialog),
        timeout: const Duration(seconds: 30),
        reason: 'açılışta süresi dolmuş seansın sonuç diyaloğu',
      );
      try {
        await pumpUntil(
          tester,
          find.text(l10n.sessionResultPoints(5)),
          timeout: const Duration(seconds: 30),
          reason: 'sunucunun puanı (5)',
        );
      } on TestFailure {
        await E2eHost.screenshot(tester, 'e2e-seans-sonucu-hata');
        fail(
          'Sonuç diyaloğunda puan yok. Diyalog metni: ${visibleTexts(find.byType(SessionCompletedDialog))}',
        );
      }
      expect(
        find.text(l10n.sessionResultCoins(20)),
        findsOneWidget,
        reason: 'sunucunun kumu (20)',
      );
      expect(find.text(l10n.sessionCompletedTitle), findsOneWidget);
      for (final unwanted in [
        l10n.sessionNotSavedTitle,
        l10n.sessionRejectedClock,
        l10n.sessionQueuedClockSkew,
        l10n.sessionQueuedOffline,
        l10n.sessionQueuedTimingUnverified,
        l10n.sessionRejectedNotElapsed,
        l10n.sessionRejectedGeneric,
      ]) {
        expect(
          find.text(unwanted),
          findsNothing,
          reason: 'çıkmamalı: $unwanted',
        );
      }
      await E2eHost.screenshot(tester, 'e2e-seans-sonucu');

      await tapOn(
        tester,
        find.widgetWithText(ElevatedButton, l10n.sessionCompletedOk),
      );
      await pumpUntilGone(tester, find.byType(SessionCompletedDialog));
      await pumpUntilTrue(
        tester,
        () => shellStats(tester) == (points: 5, coins: 20),
        reason: 'üst çubuk PUAN 5 / KUM 20 (şu an ${shellStats(tester)})',
      );
      expect(
        prefs.getString(TimerPersistence.keyFor(account.id)),
        isNull,
        reason: 'cihazdaki seans kaydı silindi',
      );
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'kaydedilemeyen seans bildirimi yok',
      );
      await E2eHost.screenshot(tester, 'e2e-sayac-puan');

      // Sunucu (psql)
      final session = (await E2eHost.row(
        'select duration_minutes, category, category_id::text, base_points, bonus_points, was_paused, is_verified, '
        "to_char(started_at at time zone 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS') as started_utc, "
        'extract(epoch from completed_at - started_at)::int as seconds '
        'from public.study_sessions where user_id = ${sqlText(account.id)} and client_uuid = ${sqlText(clientUuid)}',
      ));
      expect(session, isNotNull, reason: 'study_sessions satırı');
      expect(session!['duration_minutes'], 25);
      expect(session['category_id'], category['id']);
      expect(session['base_points'], 5);
      expect(session['bonus_points'], 0);
      expect(session['was_paused'], isFalse);
      expect(session['seconds'], 25 * 60);
      final started = DateTime.parse('${session['started_utc']}Z');
      expect(
        started.difference(startedAt.toUtc()).inSeconds.abs(),
        lessThan(90),
        reason: 'started_at ~ 26 dk önce',
      );
      final profile = (await E2eHost.row(
        'select lifetime_points, coins, total_minutes, current_streak '
        'from public.profiles where id = ${sqlText(account.id)}',
      ))!;
      expect(profile['lifetime_points'], 5);
      expect(profile['coins'], 20);
      expect(profile['total_minutes'], 25);
      expect(profile['current_streak'], 1);
      expect(
        await E2eHost.psql(
          'select count(*) from public.study_sessions where user_id = ${sqlText(account.id)}',
        ),
        '1',
      );

      // Raporlar: bugünkü 25 dk.
      await openTab(tester, 1);
      final todayLine = find.descendant(
        of: find.byType(ReportsScreen),
        matching: find.textContaining('${StatsText.duration(25)} / '),
      );
      await pumpUntil(
        tester,
        todayLine,
        timeout: const Duration(seconds: 20),
        reason: 'Raporlar: bugün 25 dk',
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == l10n.statsTodayPomodoros(1),
        ),
        findsOneWidget,
        reason: 'Bugün 1 Pomodoro tamamlandı',
      );
      expect(find.text(l10n.statsNoStudyTodayTitle), findsNothing);
      await E2eHost.screenshot(tester, 'e2e-raporlar');

      // (f) Lig: kullanıcı puanıyla.
      await openTab(tester, 2);
      final rankingScreen = find.byType(RankingScreen);
      await pumpUntil(
        tester,
        find.descendant(
          of: rankingScreen,
          matching: find.textContaining(l10n.youBadge),
        ),
        timeout: const Duration(seconds: 20),
        reason: 'Lig: is_me satırı "(Sen)"',
      );
      final membership = (await E2eHost.row(
        'select m.weekly_points, l.tier, (select count(*) from public.league_memberships x where x.league_id = m.league_id) as members '
        'from public.league_memberships m join public.leagues l on l.id = m.league_id '
        'where m.user_id = ${sqlText(account.id)}',
      ))!;
      expect(membership['weekly_points'], 5);
      // Güncel uygulamanın çağırdığı v2 RPC, hesabın gerçek JWT'siyle.
      final ranking =
          await LocalApi.rpc('get_my_league_ranking_v2', account) as List;
      final myIndex = ranking.indexWhere((r) => r['is_me'] == true);
      expect(
        myIndex,
        isNonNegative,
        reason: 'get_my_league_ranking_v2 is_me satırı',
      );
      final own = ranking[myIndex] as Map;
      expect(own['id'], account.id);
      expect(own['weekly_points'], 5);
      expect(own['has_league'], isTrue);
      expect(own['room_capacity'], 25);
      expect(own['member_count'], inInclusiveRange(1, 25));
      expect(
        find.textContaining(l10n.rankingMyStatus(myIndex + 1, 5)),
        findsNothing,
        reason: 'kullanıcının kaldırdığı kişisel sıra bandı geri gelmez',
      );
      final standings = tester.widget<RankingStandings>(
        find.descendant(
          of: rankingScreen,
          matching: find.byType(RankingStandings),
        ),
      );
      final ownVisible = standings.entries.singleWhere((entry) => entry.isMe);
      expect(ownVisible.userId, account.id);
      expect(
        ownVisible.points,
        5,
        reason: 'UI kendi satırında sunucunun 5 puanını kullanır',
      );
      await E2eHost.screenshot(tester, 'e2e-lig');
      // Kendi puanı/adı podyumda veya listede gerçekten render edilir.
      final myRow = find.descendant(
        of: rankingScreen,
        matching: find.byWidgetPredicate(
          (w) => w is RankingRow && w.entry.isMe,
        ),
      );
      if (myRow.evaluate().isNotEmpty) {
        expect(myRow, findsOneWidget, reason: 'listede kendi satırı');
        await tester.ensureVisible(myRow);
        await pumpFor(tester, const Duration(milliseconds: 600));
        expect(
          find.descendant(
            of: myRow,
            matching: find.text('Sim Seans ${l10n.youBadge}'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: myRow,
            matching: find.text(l10n.rankingPoints(5)),
          ),
          findsOneWidget,
        );
        await E2eHost.screenshot(tester, 'e2e-lig-satir');
      } else {
        final podium = find.descendant(
          of: rankingScreen,
          matching: find.byType(RankingPodium),
        );
        expect(
          find.descendant(of: podium, matching: find.text('Sim Seans')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: podium, matching: find.text(l10n.youBadge)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: podium,
            matching: find.text(l10n.rankingPoints(5)),
          ),
          findsWidgets,
        );
      }
    },
  );
}
