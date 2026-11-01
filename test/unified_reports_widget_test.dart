import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/models/study_session.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:pomodoro/utils/study_day.dart';
import 'package:pomodoro/widgets/stats/session_type_summary.dart';
import 'package:pomodoro/widgets/stats/stats_load_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_supabase_service.dart';

Widget _app(
  Widget child, {
  Locale locale = const Locale('tr'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child,
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setStudyTimeZone('Europe/Istanbul');
  });
  testWidgets(
    'reports injects accepted exam time and keeps normal/exam counts apart',
    (tester) async {
      final now = DateTime.now();
      final day = studyDayOf(now);
      final start = studyDayStart(day).add(const Duration(hours: 1));
      final service = FakeSupabaseService()
        ..remoteRows = [
          {
            'id': 'study1',
            'user_id': 'user-1',
            'category': 'Matematik',
            'duration_minutes': 50,
            'started_at': start.toUtc().toIso8601String(),
            'completed_at': start
                .add(const Duration(minutes: 50))
                .toUtc()
                .toIso8601String(),
            'client_uuid': 's1',
            'session_kind': 'normal',
          },
        ];
      final exam = ExamAttempt(
        id: 'e1',
        clientUuid: 'e1',
        examId: 'tyt',
        startedAt: start,
        endsAt: start.add(const Duration(minutes: 165)),
        durationSeconds: 9900,
        totalQuestions: 120,
        status: ExamAttemptStatus.completed,
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 3500);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          ReportsScreen(
            categories: const [],
            service: service,
            loadExamAttempts: () async => [exam, exam],
            onOpenExams: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final summary = tester.widget<SessionTypeSummary>(
        find.byType(SessionTypeSummary),
      );
      expect(summary.counts.normalSessions, 1);
      expect(summary.counts.completedExams, 1);
      expect(summary.counts.focusEquivalents, 2);
      expect(find.text('Deneme'), findsWidgets);
      expect(find.text('Denemelerim, netler ve içgörüler'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'stale exam cache keeps combined totals and shows a retry warning',
    (tester) async {
      final start = studyDayStart(
        studyDayOf(DateTime.now()),
      ).add(const Duration(hours: 1));
      final service = FakeSupabaseService()
        ..remoteRows = [
          {
            'id': 'study1',
            'user_id': 'user-1',
            'category': 'Matematik',
            'duration_minutes': 50,
            'started_at': start.toIso8601String(),
            'completed_at': start
                .add(const Duration(minutes: 50))
                .toIso8601String(),
            'client_uuid': 's1',
            'session_kind': 'normal',
          },
        ];
      final exam = ExamAttempt(
        id: 'e1',
        clientUuid: 'e1',
        examId: 'tyt',
        startedAt: start,
        endsAt: start.add(const Duration(minutes: 165)),
        durationSeconds: 9900,
        totalQuestions: 120,
        status: ExamAttemptStatus.completed,
      );
      var stale = false;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 3500);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          ReportsScreen(
            categories: const [],
            service: service,
            loadExamAttempts: () async => [exam],
            isExamHistoryStale: () => stale,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StatsStaleBanner), findsNothing);
      stale = true;
      service.notifyStatsChanged();
      await tester.pumpAndSettle();
      expect(find.byType(StatsStaleBanner), findsOneWidget);
      expect(
        tester
            .widget<SessionTypeSummary>(find.byType(SessionTypeSummary))
            .counts
            .completedExams,
        1,
      );
      expect(
        tester
            .widget<DailyReportView>(find.byType(DailyReportView))
            .sessions
            .fold<int>(0, (sum, s) => sum + s.minutes),
        215,
      );
      stale = false;
      final banner = tester.widget<StatsStaleBanner>(
        find.byType(StatsStaleBanner),
      );
      banner.onRetry();
      await tester.pumpAndSettle();
      expect(find.byType(StatsStaleBanner), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'first missing exam history warns while keeping fresh normal totals',
    (tester) async {
      final start = studyDayStart(
        studyDayOf(DateTime.now()),
      ).add(const Duration(hours: 1));
      final service = FakeSupabaseService()
        ..remoteRows = [
          {
            'id': 'study1',
            'user_id': 'user-1',
            'category': 'Matematik',
            'duration_minutes': 50,
            'started_at': start.toIso8601String(),
            'completed_at': start
                .add(const Duration(minutes: 50))
                .toIso8601String(),
            'client_uuid': 's1',
            'session_kind': 'normal',
          },
        ];
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 3500);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          ReportsScreen(
            categories: const [],
            service: service,
            loadExamAttempts: () async => [],
            isExamHistoryStale: () => true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StatsStaleBanner), findsOneWidget);
      final summary = tester.widget<SessionTypeSummary>(
        find.byType(SessionTypeSummary),
      );
      expect(summary.counts.normalSessions, 1);
      expect(summary.counts.completedExams, 0);
      expect(
        tester
            .widget<DailyReportView>(find.byType(DailyReportView))
            .sessions
            .fold<int>(0, (sum, s) => sum + s.minutes),
        50,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'summary presents separate counts and opens exam details in both languages',
    (tester) async {
      var opens = 0;
      for (final locale in const [Locale('tr'), Locale('en')]) {
        await tester.pumpWidget(
          _app(
            SingleChildScrollView(
              child: SessionTypeSummary(
                counts: const SessionTypeCounts(
                  normalSessions: 12,
                  marathonFocusSessions: 6,
                  completedMarathons: 2,
                  completedExams: 3,
                  unknownSessions: 0,
                  pendingSessions: 0,
                  focusEquivalents: 12,
                ),
                onOpenExams: () => opens++,
              ),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        final normal = locale.languageCode == 'tr'
            ? 'Normal seans'
            : 'Regular sessions';
        final exam = locale.languageCode == 'tr'
            ? 'Tamamlanan deneme'
            : 'Completed practice exams';
        expect(find.text(normal), findsOneWidget);
        expect(find.text(exam), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
        expect(opens, locale.languageCode == 'tr' ? 1 : 2);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'mixed count summary fits all screen sizes and both languages at 2x text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final size in const [
        Size(320, 568),
        Size(390, 844),
        Size(844, 390),
        Size(768, 1024),
        Size(1024, 768),
      ]) {
        for (final lang in ['tr', 'en']) {
          tester.view.physicalSize = size;
          await tester.pumpWidget(
            _app(
              SingleChildScrollView(
                child: SessionTypeSummary(
                  counts: const SessionTypeCounts(
                    normalSessions: 12,
                    marathonFocusSessions: 7,
                    completedMarathons: 2,
                    completedExams: 3,
                    unknownSessions: 2,
                    pendingSessions: 1,
                    focusEquivalents: 31,
                  ),
                  onOpenExams: () {},
                ),
              ),
              locale: Locale(lang),
              scale: 2,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$size $lang');
        }
      }
    },
  );
  testWidgets(
    'deneme category label is localized independently of a personal category name',
    (tester) async {
      await LanguageService.instance.setLanguage(AppLanguage.en);
      final day = DateTime(2026, 10, 27);
      final sessions = [
        StatSession(
          day: day,
          minutes: 25,
          categoryName: 'Deneme',
          clientUuid: 'personal',
        ),
      ];
      sessions.add(
        StatSession(
          day: day,
          minutes: 165,
          categoryName: '',
          categoryId: kExamStatsCategoryId,
          clientUuid: 'exam',
          kind: StudySessionKind.exam,
        ),
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 3500);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          DailyReportView(
            sessions: sessions,
            today: day,
            dailyGoalMinutes: 200,
            hasHistory: true,
            categories: const [],
            onRefresh: () async {},
            showDistributionPercent: false,
            onDistributionModeChanged: (_) {},
          ),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Practice exams'), findsWidgets);
      expect(find.text('Deneme'), findsWidgets);
      expect(tester.takeException(), isNull);
      await LanguageService.instance.setLanguage(AppLanguage.tr);
    },
  );
}
