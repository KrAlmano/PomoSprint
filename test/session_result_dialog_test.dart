// UX-02: seans sonu diyaloğu sunucu sonucunu bekler ve gösterir (puan, kum,
// seri yalnızca RPC sonucundan; kuyruk; ret nedeni; günlük tavan). Reddedilen
// seanslar Raporlar > Haftalık'tan açılan listede görünür.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/history_screen.dart';
import 'package:pomodoro/screens/rejected_sessions_screen.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/utils/study_day.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_supabase_service.dart';

late AppLocalizations l10n;

Future<void> _pumpDialog(WidgetTester tester, Future<SessionSubmitResult?> result, {Duration? timeout}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => timeout == null
                ? SessionCompletedDialog(minutes: 25, result: result)
                : SessionCompletedDialog(minutes: 25, result: result, resultTimeout: timeout),
          ),
          child: const Text('aç'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('aç'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

RejectedSession _rejected(String uuid, String name, String reason, DateTime at) => RejectedSession(
      clientUuid: uuid,
      startedAt: at.toUtc(),
      minutes: 25,
      categoryName: name,
      reasonCode: reason,
      rejectedAt: at.add(const Duration(hours: 1)).toUtc(),
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  setUp(() => LanguageService.instance.setLanguage(AppLanguage.tr));

  group('Seans sonu diyaloğu', () {
    testWidgets('önce kaydediliyor, sonra RPC sonucundaki puan, kum ve seri', (tester) async {
      final submission = Completer<SessionSubmitResult?>();
      await _pumpDialog(tester, submission.future);
      expect(find.text(l10n.sessionResultSaving), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Değerler istemcide hesaplanmaz: ne gelirse o gösterilir.
      submission.complete(const SessionSubmitSuccess(
        minutes: 25,
        basePoints: 5,
        bonusPoints: 1,
        bonusPct: 10,
        totalPoints: 6,
        coinsEarned: 20,
        streak: 3,
      ));
      await tester.pumpAndSettle();
      expect(find.text(l10n.sessionResultSaving), findsNothing);
      expect(find.text(l10n.sessionResultPoints(6)), findsOneWidget);
      expect(find.text(l10n.sessionResultCoins(20)), findsOneWidget);
      expect(find.text(l10n.sessionResultStreak(3)), findsOneWidget);
      expect(find.text(l10n.sessionPointsBreakdown(5, 1, 10, 6)), findsOneWidget);

      // Kapatma düğmesi her durumda çalışır.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.byType(SessionCompletedDialog), findsNothing);
    });

    testWidgets('ilk seanslarda da (bonus yokken) puan ve kum görünür', (tester) async {
      await _pumpDialog(
        tester,
        Future.value(const SessionSubmitSuccess(minutes: 25, basePoints: 5, totalPoints: 5, coinsEarned: 20, streak: 1)),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.sessionResultPoints(5)), findsOneWidget);
      expect(find.text(l10n.sessionResultCoins(20)), findsOneWidget);
      expect(find.text(l10n.sessionResultStreak(1)), findsOneWidget);
    });

    testWidgets('günlük tavan: sıfır puan yerine tavan bilgisi', (tester) async {
      await _pumpDialog(
        tester,
        Future.value(const SessionSubmitSuccess(minutes: 25, streak: 4, dailyLimitReached: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.sessionDailyLimitReached(SupabaseService.instance.dailySessionLimit)), findsOneWidget);
      expect(find.text(l10n.sessionResultPoints(0)), findsNothing);
      expect(find.text(l10n.sessionResultCoins(0)), findsNothing);
      expect(find.text(l10n.sessionResultStreak(4)), findsOneWidget);
    });

    testWidgets('daha önce kaydedilmiş seans (duplicate)', (tester) async {
      await _pumpDialog(tester, Future.value(const SessionSubmitSuccess(minutes: 25, duplicate: true)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.sessionResultDuplicate), findsOneWidget);
      expect(find.text(l10n.sessionResultPoints(0)), findsNothing);
    });

    testWidgets('çevrimdışı: cihazda kayıtlı, bağlantı gelince gönderilecek', (tester) async {
      await _pumpDialog(
        tester,
        Future.value(const SessionSubmitQueued(reasonCode: SessionReason.network, pendingCount: 1)),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.sessionQueuedOffline), findsOneWidget);
      expect(find.text(l10n.sessionNotSavedTitle), findsNothing);
    });

    testWidgets('saat farkıyla bekletilen seans', (tester) async {
      await _pumpDialog(
        tester,
        Future.value(const SessionSubmitQueued(reasonCode: SessionReason.clockSkew, pendingCount: 1)),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.sessionQueuedClockSkew), findsOneWidget);
    });

    testWidgets('ret: başlık, neden ve kaydedilemeyen seanslar bağlantısı', (tester) async {
      await _pumpDialog(tester, Future.value(const SessionSubmitRejected(SessionReason.overlap)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.sessionNotSavedTitle), findsOneWidget);
      expect(find.text(l10n.sessionRejectedOverlap), findsOneWidget);
      expect(find.text(l10n.sessionResultOk), findsOneWidget);

      // session_not_finished (saat) nedeni de kendi metniyle.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await _pumpDialog(tester, Future.value(const SessionSubmitRejected(SessionReason.notElapsed)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.sessionRejectedClock), findsOneWidget);

      // Bağlantı diyaloğu kapatıp listeyi açar.
      await tester.tap(find.text(l10n.rejectedSessionsTitle));
      await tester.pumpAndSettle();
      expect(find.byType(SessionCompletedDialog), findsNothing);
      expect(find.byType(RejectedSessionsScreen), findsOneWidget);
    });

    testWidgets('zaman aşımında kuyruk mesajı; sonuç sonradan gelince güncellenir', (tester) async {
      final submission = Completer<SessionSubmitResult?>();
      await _pumpDialog(tester, submission.future, timeout: const Duration(seconds: 2));
      expect(find.text(l10n.sessionResultSaving), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text(l10n.sessionResultSaving), findsNothing);
      expect(find.text(l10n.sessionQueuedOffline), findsOneWidget);

      submission.complete(const SessionSubmitSuccess(minutes: 25, basePoints: 5, totalPoints: 5, coinsEarned: 20));
      await tester.pumpAndSettle();
      expect(find.text(l10n.sessionQueuedOffline), findsNothing);
      expect(find.text(l10n.sessionResultPoints(5)), findsOneWidget);
    });

    testWidgets('gönderim hata verirse seans cihazda kalır mesajı', (tester) async {
      final submission = Completer<SessionSubmitResult?>();
      await _pumpDialog(tester, submission.future);
      submission.completeError(StateError('kayıt yazılamadı'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.sessionQueuedOffline), findsOneWidget);
    });
  });

  group('Kaydedilemeyen seanslar', () {
    Future<void> pumpList(WidgetTester tester, FakeSupabaseService service, {Locale locale = const Locale('tr')}) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RejectedSessionsScreen(service: service),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('en yeni üstte; kategori, süre ve ret nedeni görünür', (tester) async {
      final service = FakeSupabaseService()
        ..rejected = [
          _rejected('old', 'Fizik', SessionReason.tooOld, DateTime(2026, 9, 1, 10)),
          _rejected('new', 'Matematik', SessionReason.overlap, DateTime(2026, 9, 2, 10)),
        ];
      await pumpList(tester, service);
      expect(find.text(l10n.rejectedSessionsTitle), findsOneWidget);
      expect(find.text(l10n.rejectedSessionsInfo), findsOneWidget);
      final math = find.text('Matematik · 25 ${l10n.minutesUnit}');
      final physics = find.text('Fizik · 25 ${l10n.minutesUnit}');
      expect(math, findsOneWidget);
      expect(physics, findsOneWidget);
      expect(tester.getTopLeft(math).dy, lessThan(tester.getTopLeft(physics).dy));
      expect(find.textContaining(l10n.sessionRejectedOverlap), findsOneWidget);
      expect(find.textContaining(l10n.sessionRejectedTooOld), findsOneWidget);
    });

    testWidgets('kategori adı arayüz dilinde', (tester) async {
      // Dil hemen değişir; tercih yazımı beklenmez (fake async bölgesi).
      unawaited(LanguageService.instance.setLanguage(AppLanguage.en));
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      final service = FakeSupabaseService()
        ..rejected = [_rejected('a', 'Fizik', SessionReason.tooOld, DateTime(2026, 9, 1, 10))];
      await pumpList(tester, service, locale: const Locale('en'));
      expect(find.text('Physics · 25 ${en.minutesUnit}'), findsOneWidget);
    });

    testWidgets('boş liste', (tester) async {
      await pumpList(tester, FakeSupabaseService());
      expect(find.text(l10n.rejectedSessionsEmpty), findsOneWidget);
    });

    testWidgets('Haftalık: bağlantı yalnızca reddedilen seans varken', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var opened = 0;
      Widget weekly(int count) => MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: HistoryScreen(
                sessions: const [],
                today: studyDayOf(DateTime.now()),
                dailyGoalMinutes: 200,
                categories: const [],
                onRefresh: () async {},
                rejectedSessionCount: count,
                onShowRejectedSessions: () => opened++,
              ),
            ),
          );
      await tester.pumpWidget(weekly(0));
      await tester.pumpAndSettle();
      expect(find.textContaining(l10n.rejectedSessionsTitle), findsNothing);

      await tester.pumpWidget(weekly(2));
      await tester.pumpAndSettle();
      final link = find.text(l10n.rejectedSessionsLink(2));
      expect(link, findsOneWidget);
      await tester.tap(link);
      expect(opened, 1);
    });

    testWidgets('Raporlar, reddedilen seans sayısını Haftalık sekmesine verir', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = FakeSupabaseService()
        ..rejected = [_rejected('a', 'Fizik', SessionReason.tooOld, DateTime(2026, 9, 1, 10))];
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReportsScreen(categories: const [], service: service),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text(LanguageService.instance.translate('reports_tab_history')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.rejectedSessionsLink(1)), findsOneWidget);
      // Gün dönümü zamanlayıcısı test bitmeden iptal edilsin.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
