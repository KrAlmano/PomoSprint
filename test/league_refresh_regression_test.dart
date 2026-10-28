import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/competition_target.dart';
import 'package:pomodoro/models/league_rules.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/screens/ranking_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/widgets/social/countdown_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_exam_backend.dart';
import 'support/fake_supabase_service.dart';

Widget app(Widget child) => MaterialApp(
  locale: const Locale('tr'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

class PeriodService extends FakeSupabaseService {
  PeriodService({DateTime Function()? clock, this.firstEnd})
    : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  final DateTime? firstEnd;
  int loads = 0;
  DateTime get end => loads <= 1
      ? firstEnd ?? clock().subtract(const Duration(seconds: 1))
      : clock().add(const Duration(days: 30));
  Map<String, dynamic> get config => {
    'policy_version': 2,
    'period_kind': 'calendar_month',
    'period_timezone': 'Europe/Istanbul',
    'reset_hour': 0,
    'period_end': end.toUtc().toIso8601String(),
    'competition_phase': 'active',
  };
  @override
  Future<LeagueRules> getLeagueRules() async =>
      LeagueRules.fromAppConfig(config);
  @override
  Future<List<Map<String, dynamic>>> getLeagueRanking() async {
    loads++;
    return [
      {
        'id': currentUser.value!.id,
        'name': 'Test User',
        'is_me': true,
        'weekly_points': loads == 1 ? 99 : 0,
        'has_league': false,
        'member_count': 0,
        'competition_phase': 'active',
        'league_config': config,
      },
    ];
  }

  @override
  Future<CompetitionTarget> getCompetitionTarget() async =>
      CompetitionTarget(currentSegment: loads == 1 ? 'yks' : 'tus');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'open ranking reloads a finished period once and refreshes target',
    (tester) async {
      final service = PeriodService();
      await tester.pumpWidget(
        app(
          RankingScreen(
            currentUser: service.currentUser.value,
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.loads, 2);
      expect(find.textContaining('TUS'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(
        service.loads,
        2,
        reason: 'no repeated request loop for the boundary',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('pull refresh reloads the visible exam league wallet', (
    tester,
  ) async {
    final backend = FakeExamBackend();
    var wallet = 5;
    var loads = 0;
    backend.handler = (name, params) async {
      if (name == 'get_my_exam_league_ranking') {
        loads++;
        return {
          'scope': params['p_scope'],
          'exam_coins': wallet,
          'rows': [],
          'period_end': backend.clock
              .add(const Duration(days: 30))
              .toIso8601String(),
        };
      }
      return backend.defaultRpc(name, params);
    };
    final service = ExamService(backend: backend);
    await tester.pumpWidget(app(ExamScreen(service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exam-tab-league')));
    await tester.pumpAndSettle();
    expect(loads, 1);
    wallet = 17;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(loads, 2);
    expect(find.text('Deneme kumu: 17'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
    backend.owner.dispose();
  });

  testWidgets('open exam league reloads once when its period has ended', (
    tester,
  ) async {
    final backend = FakeExamBackend();
    var loads = 0;
    backend.handler = (name, params) async {
      if (name == 'get_my_exam_league_ranking') {
        loads++;
        return {
          'scope': params['p_scope'],
          'exam_coins': loads,
          'rows': [],
          'period_end': backend.clock
              .add(
                loads == 1
                    ? const Duration(seconds: -1)
                    : const Duration(days: 30),
              )
              .toIso8601String(),
        };
      }
      return backend.defaultRpc(name, params);
    };
    final service = ExamService(backend: backend);
    await tester.pumpWidget(app(ExamScreen(service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exam-tab-league')));
    await tester.pumpAndSettle();
    expect(loads, 2);
    await tester.pump(const Duration(seconds: 10));
    expect(loads, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
    backend.owner.dispose();
  });

  testWidgets('hidden ranking does not fetch or poll until shown', (
    tester,
  ) async {
    final service = PeriodService();
    var visible = false;
    late StateSetter rebuild;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return TickerMode(
              enabled: visible,
              child: RankingScreen(
                currentUser: service.currentUser.value,
                service: service,
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(hours: 1));
    expect(service.loads, 0);
    rebuild(() => visible = true);
    await tester.pumpAndSettle();
    expect(service.loads, 2);
    rebuild(() => visible = false);
    await tester.pump();
    await tester.pump(const Duration(hours: 1));
    expect(service.loads, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('elapsed countdown calls once only while visible', (
    tester,
  ) async {
    var calls = 0;
    var visible = false;
    late StateSetter rebuild;
    final end = DateTime.now().subtract(const Duration(seconds: 1));
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return TickerMode(
              enabled: visible,
              child: CountdownText(target: end, onElapsed: () => calls++),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 0);
    rebuild(() => visible = true);
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.pump(const Duration(days: 2));
    expect(calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'exam league pauses hidden refresh and reloads on foreground return',
    (tester) async {
      final backend = FakeExamBackend();
      var loads = 0;
      backend.handler = (name, params) async {
        if (name == 'get_my_exam_league_ranking') {
          loads++;
          return {
            'scope': params['p_scope'],
            'exam_coins': loads,
            'rows': [],
            'period_end': backend.clock
                .add(const Duration(seconds: 5))
                .toIso8601String(),
          };
        }
        return backend.defaultRpc(name, params);
      };
      final service = ExamService(backend: backend);
      await tester.pumpWidget(app(ExamScreen(service: service)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('exam-tab-league')));
      await tester.pumpAndSettle();
      expect(loads, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      backend.clock = backend.clock.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(loads, 1, reason: 'no background league polling');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(loads, 2);
      expect(find.text('Deneme kumu: 2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      backend.owner.dispose();
    },
  );

  testWidgets('foreground rollover bypasses a still-fresh ranking cache', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 31, 20, 59, 59);
    final service = PeriodService(
      clock: () => now,
      firstEnd: now.add(const Duration(seconds: 1)),
    );
    await tester.pumpWidget(
      app(
        RankingScreen(
          currentUser: service.currentUser.value,
          service: service,
          now: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.loads, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(service.loads, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(
      service.loads,
      2,
      reason: 'period end must bypass the thirty-second cache',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'unavailable league clears loading and ignores the previous reply',
    (tester) async {
      final backend = FakeExamBackend();
      final oldReply = Completer<Object?>();
      var loads = 0;
      backend.handler = (name, params) async {
        if (name == 'get_my_exam_league_ranking') {
          loads++;
          if (loads == 1) return oldReply.future;
          return {'scope': params['p_scope'], 'exam_coins': 23, 'rows': []};
        }
        return backend.defaultRpc(name, params);
      };
      final service = ExamService(backend: backend);
      await tester.pumpWidget(app(ExamScreen(service: service)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('exam-tab-league')));
      await tester.pump();
      expect(loads, 1);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      backend.featureAvailable = false;
      await service.refresh();
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      oldReply.complete({'scope': 'segment', 'exam_coins': 99, 'rows': []});
      await tester.pumpAndSettle();
      expect(find.text('Deneme kumu: 99'), findsNothing);
      backend.featureAvailable = true;
      await service.refresh();
      await tester.pumpAndSettle();
      expect(loads, 2);
      expect(find.text('Deneme kumu: 23'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
      backend.owner.dispose();
    },
  );

  testWidgets('unavailable league also clears a previous load error', (
    tester,
  ) async {
    final backend = FakeExamBackend();
    backend.handler = (name, params) async {
      if (name == 'get_my_exam_league_ranking') {
        throw const ExamFailure('connection');
      }
      return backend.defaultRpc(name, params);
    };
    final service = ExamService(backend: backend);
    await tester.pumpWidget(app(ExamScreen(service: service)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exam-tab-league')));
    await tester.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsOneWidget);
    backend.featureAvailable = false;
    await service.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
    backend.owner.dispose();
  });
}
