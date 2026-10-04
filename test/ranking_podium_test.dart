import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/widgets/social/ranking_models.dart';
import 'package:pomodoro/widgets/social/ranking_widgets.dart';

// t4-F11: Sunucu lig ödülünü yalnızca puanı > 0 olan ilk 3'e verir
// (process_weekly_leagues; get_league_ranking ödül avatarı da puan > 0 iken).
// Podyum 0 puanlı koltuklara da altın/gümüş/bronz madalya çiziyordu.
Future<void> _pump(WidgetTester tester, List<int> points, {LeagueSnapshot? league}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final entries = [
    for (final (i, p) in points.indexed) RankingEntry(name: 'Üye ${i + 1}', points: p, isMe: i == 0),
  ];
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('tr'),
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(child: RankingStandings(entries: entries, league: league)),
    ),
  ));
  await tester.pump();
}

Finder _medal(int rank) => find.byKey(ValueKey('podium-medal-$rank'));

void main() {
  const room = LeagueSnapshot(
    tier: 1,
    endDate: null,
    promotionZoneEnd: 2,
    demotionZoneStart: 999,
    memberCount: 4,
    myPoints: 12,
  );

  testWidgets('lig odası [12, 0, 0, 0]: yalnızca puanı olan 1. madalya alır', (tester) async {
    await _pump(tester, [12, 0, 0, 0], league: room);
    expect(_medal(1), findsOneWidget);
    expect(_medal(2), findsNothing);
    expect(_medal(3), findsNothing);
    // Sıra rozetleri (#2, #3) kalır; sıra bilgisi doğrudur.
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('#3'), findsOneWidget);
  });

  testWidgets('tamamen 0 puanlı odada madalya yok', (tester) async {
    await _pump(tester, [0, 0, 0, 0], league: const LeagueSnapshot(
      tier: 1,
      endDate: null,
      promotionZoneEnd: 2,
      demotionZoneStart: 999,
      memberCount: 4,
    ));
    expect(_medal(1), findsNothing);
    expect(_medal(2), findsNothing);
    expect(_medal(3), findsNothing);
  });

  testWidgets('puanı olan ilk 3 madalya alır', (tester) async {
    await _pump(tester, [30, 20, 10, 5], league: room);
    expect(_medal(1), findsOneWidget);
    expect(_medal(2), findsOneWidget);
    expect(_medal(3), findsOneWidget);
  });
}
