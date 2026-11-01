import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/screens/history_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:pomodoro/utils/study_day.dart';
import 'package:shared_preferences/shared_preferences.dart';

ExamAttempt exam(
  String id,
  String kind,
  DateTime start,
  int minutes, {
  ExamAttemptStatus status = ExamAttemptStatus.completed,
}) => ExamAttempt(
  id: id,
  clientUuid: id,
  examId: kind,
  startedAt: start,
  endsAt: start.add(Duration(minutes: minutes)),
  durationSeconds: minutes * 60,
  totalQuestions: 120,
  status: status,
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

  test(
    'exam types are nested beneath one total with duplicates and abandoned excluded',
    () {
      final start = DateTime.utc(2026, 10, 28, 8);
      final tyt = exam('tyt-1', 'tyt', start, 165);
      final combined = combineStudyAndExamSessions(
        study: const [],
        exams: [
          tyt,
          tyt,
          exam('ayt-1', 'ayt', start, 90),
          exam(
            'abandoned',
            'tyt',
            start,
            165,
            status: ExamAttemptStatus.abandoned,
          ),
        ],
      );
      final totals = totalsByCategory(combined);
      expect(totals, hasLength(1));
      expect(totals.single.minutes, 255);
      expect(totals.single.examTypes.map((e) => e.id), ['tyt', 'ayt']);
      expect(totals.single.examTypes.map((e) => e.minutes), [165, 90]);
      expect(sumMinutes(combined), 255);
    },
  );

  test('exam breakdown follows 04:00 working day and month boundaries', () {
    final beforeFour = DateTime.utc(2026, 11, 1, 0, 59); // 03:59 Istanbul
    final afterFour = DateTime.utc(2026, 11, 1, 1); // 04:00 Istanbul
    final combined = combineStudyAndExamSessions(
      study: const [],
      exams: [
        exam('old', 'tyt', beforeFour, 165),
        exam('new', 'ayt', afterFour, 90),
      ],
      timeZone: 'Europe/Istanbul',
    );
    final oldDay = totalsByCategory(
      sessionsBetween(combined, DateTime(2026, 10, 31), DateTime(2026, 10, 31)),
    );
    final newDay = totalsByCategory(
      sessionsBetween(combined, DateTime(2026, 11, 1), DateTime(2026, 11, 1)),
    );
    expect(oldDay.single.examTypes.single.id, 'tyt');
    expect(newDay.single.examTypes.single.id, 'ayt');
    expect(sumMinutes(combined), 255);
  });

  for (final language in [AppLanguage.tr, AppLanguage.en]) {
    testWidgets('weekly exam names and totals are readable: ${language.name}', (
      tester,
    ) async {
      await LanguageService.instance.setLanguage(language);
      final now = DateTime.utc(2026, 10, 28, 8);
      final sessions = combineStudyAndExamSessions(
        study: const [],
        exams: [
          exam('tyt', 'tyt', now, 165),
          exam('ayt', 'ayt', now, 90),
          exam('tus', 'tus_basic', now, 135),
        ],
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 1900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language.name),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: HistoryScreen(
              sessions: sessions,
              today: DateTime(2026, 10, 28),
              dailyGoalMinutes: 200,
              categories: const [],
              onRefresh: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('TYT'));
      await tester.pumpAndSettle();
      expect(find.text('TYT'), findsOneWidget);
      expect(find.text('AYT'), findsOneWidget);
      expect(
        find.text(
          language == AppLanguage.tr ? 'TUS Temel Tıp' : 'TUS Basic Medicine',
        ),
        findsOneWidget,
      );
      expect(
        find.text(language == AppLanguage.tr ? 'Deneme' : 'Practice exams'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
