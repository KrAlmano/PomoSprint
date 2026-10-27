import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/l10n/app_localizations_en.dart';
import 'package:pomodoro/l10n/app_localizations_tr.dart';
import 'package:pomodoro/models/competition_target.dart';
import 'package:pomodoro/models/league_rules.dart';
import 'package:pomodoro/screens/ranking_screen.dart';
import 'package:pomodoro/widgets/competition_target_dialog.dart';
import 'package:pomodoro/widgets/league_info_sheet.dart';
import 'package:pomodoro/widgets/social/ranking_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_supabase_service.dart';

Map<String, dynamic> monthlyConfig() => {
  'policy_version': 2,
  'period_kind': 'calendar_month',
  'period_timezone': 'Europe/Istanbul',
  'reset_hour': 0,
  'period_start': '2026-10-01T00:00:00+03:00',
  'period_end': '2026-11-01T00:00:00+03:00',
  'league_room_capacity': 25,
  'league_launch_min_active_users': 3,
  'competition_phase': 'active',
};

class _LeagueService extends FakeSupabaseService {
  _LeagueService({this.monthly = true});
  final bool monthly;
  CompetitionTarget target = const CompetitionTarget(currentSegment: 'yks');
  @override
  Future<LeagueRules> getLeagueRules() async => monthly
      ? LeagueRules.fromAppConfig(monthlyConfig())
      : LeagueRules.fromAppConfig({
          'policy_version': 1,
          'competition_phase': 'active',
        });
  @override
  Future<List<Map<String, dynamic>>> getLeagueRanking() async => [
    {
      'id': currentUser.value!.id,
      'name': 'Test User',
      'is_me': true,
      'weekly_points': 8,
      'has_league': true,
      'member_count': 1,
      'end_date': '2026-10-31T23:59:59.999999+03:00',
      'competition_phase': 'active',
      if (monthly) 'league_config': monthlyConfig(),
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> getMonthlyRanking({
    int limit = 50,
  }) async => [
    {
      'id': currentUser.value!.id,
      'name': 'Test User',
      'is_me': true,
      'total_points': 8,
      if (monthly) 'period_end': '2026-11-01T00:00:00+03:00',
    },
  ];
  @override
  Future<CompetitionTarget> getCompetitionTarget() async => target;
  @override
  Future<CompetitionTarget> setCompetitionTarget(String segment) async =>
      target = CompetitionTarget(
        currentSegment: target.currentSegment,
        pendingSegment: segment,
        effectiveAt: DateTime.utc(2026, 10, 31, 21),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('only explicit version 2 calendar contract changes the period', () {
    final monthly = LeagueRules.fromAppConfig(monthlyConfig());
    expect(monthly.isCalendarMonthly, isTrue);
    expect(monthly.periodEnd, DateTime.utc(2026, 10, 31, 21));
    expect(
      LeagueRules.fromAppConfig({'policy_version': 1}).isCalendarMonthly,
      isFalse,
    );
    expect(LeagueRules.standard.isCalendarMonthly, isFalse);
    expect(
      LeagueRules.fromAppConfig({
        ...monthlyConfig(),
        'reset_hour': 4,
      }).isCalendarMonthly,
      isFalse,
    );
    expect(
      LeagueRules.fromAppConfig({
        ...monthlyConfig(),
        'period_timezone': 'America/New_York',
      }).isCalendarMonthly,
      isFalse,
    );
  });

  test('Istanbul midnight is independent from the 04:00 study month', () {
    final justAfterMidnight = DateTime.utc(2026, 10, 31, 21, 30);
    expect(
      nextCalendarMonthReset(justAfterMidnight),
      DateTime.utc(2026, 11, 30, 21),
    );
    expect(
      nextMonthlyLeaderboardReset(justAfterMidnight),
      DateTime.utc(2026, 11, 1, 1),
    );
    expect(
      nextCalendarMonthReset(DateTime.utc(2026, 10, 31, 20, 59)),
      DateTime.utc(2026, 10, 31, 21),
    );
    expect(
      nextCalendarMonthReset(DateTime.utc(2026, 12, 31, 21)),
      DateTime.utc(2027, 1, 31, 21),
    );
  });

  test('ranking row metadata preserves monthly end and eligibility rules', () {
    final rules = LeagueRules.fromAppConfig(monthlyConfig());
    final snapshot = LeagueSnapshot.fromRows([
      {
        'is_me': true,
        'weekly_points': 10,
        'member_count': 3,
        'has_league': true,
        'competition_phase': 'active',
        'promotion_eligible': true,
        'award_eligible': false,
        'league_config': monthlyConfig(),
      },
    ], rules: rules);
    expect(snapshot.rules.isCalendarMonthly, isTrue);
    expect(snapshot.endDate, DateTime.utc(2026, 10, 31, 21));
    expect(snapshot.isPromotionRank(1, 10), isTrue);
    expect(snapshot.earnsAward(1, 10), isFalse);
  });

  test('target response validates category and pending effective time', () {
    expect(
      CompetitionTarget.fromJson({'current_segment': 'tus'})!.currentSegment,
      'tus',
    );
    expect(CompetitionTarget.fromJson({'current_segment': 'admin'}), isNull);
    expect(
      CompetitionTarget.fromJson({
        'current_segment': 'yks',
        'pending_segment': 'tus',
      }),
      isNull,
    );
    expect(
      CompetitionTarget.fromJson({
        'current_segment': 'yks',
        'pending_segment': 'tus',
        'effective_at': '2026-11-01T00:00:00+03:00',
      })!.effectiveAt,
      DateTime.utc(2026, 10, 31, 21),
    );
  });

  test('monthly preparation never reuses the old fourteen-day claim', () {
    for (final l10n in [AppLocalizationsTr(), AppLocalizationsEn()]) {
      final rules = LeagueRules.fromAppConfig({
        ...monthlyConfig(),
        'competition_phase': 'preparing',
      });
      expect(
        leaguePreparationText(l10n, rules),
        l10n.leagueCalendarPreparingGeneric,
      );
    }
  });

  for (final language in ['tr', 'en']) {
    testWidgets('monthly target and global view are localized: $language', (
      tester,
    ) async {
      final service = _LeagueService();
      final l10n = language == 'tr'
          ? AppLocalizationsTr()
          : AppLocalizationsEn();
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RankingScreen(
            currentUser: service.currentUser.value,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.rankingTabGlobal), findsOneWidget);
      expect(
        find.text(l10n.leagueTargetCurrent(l10n.onboardingSegmentYks)),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('league-change-target')),
      );
      await tester.tap(find.byKey(const ValueKey('league-change-target')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('competition-target-tus')),
      );
      await tester.tap(find.byKey(const ValueKey('competition-target-tus')));
      await tester.tap(find.byKey(const ValueKey('competition-target-save')));
      await tester.pumpAndSettle();
      expect(service.target.currentSegment, 'yks');
      expect(service.target.pendingSegment, 'tus');
      expect(find.textContaining(l10n.onboardingSegmentTus), findsOneWidget);
      await tester.ensureVisible(find.text(l10n.rankingTabGlobal));
      await tester.tap(find.text(l10n.rankingTabGlobal));
      await tester.pumpAndSettle();
      expect(find.text(l10n.leagueGlobalScopeBody), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('legacy server keeps monthly tab and no target editor', (
    tester,
  ) async {
    final service = _LeagueService(monthly: false);
    final l10n = AppLocalizationsTr();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RankingScreen(
          currentUser: service.currentUser.value,
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n.rankingTabMonthly), findsOneWidget);
    expect(find.byKey(const ValueKey('league-change-target')), findsNothing);
  });

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    testWidgets('target dialog fits $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: CompetitionTargetDialog(
              target: const CompetitionTarget(currentSegment: 'yks'),
              save: (_) async => const CompetitionTarget(currentSegment: 'yks'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('competition-target-save')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
