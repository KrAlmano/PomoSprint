// Regression for the overnight native matcher: 250 minutes split over the
// 04:00 study-day boundary produce 225/25 minute cells, not a 250 minute cell.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/models/study_session.dart';
import 'package:pomodoro/screens/monthly_tracking_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:pomodoro/utils/study_day.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _math = 'aaaaaaaa-0000-4000-8000-000000000001';
final _today = DateTime(2026, 10, 8);
final _category = CourseCategory.fromServerRow({
  'id': _math,
  'name': 'Matematik',
  'color_hex': '#EF4444',
  'icon_name': 'calculate',
});

List<StatSession> _sessions() {
  final fixtures = <(DateTime, int)>[
    (DateTime.utc(2026, 10, 7, 19), 50),
    (DateTime.utc(2026, 10, 7, 20), 50),
    (DateTime.utc(2026, 10, 7, 21), 50),
    (DateTime.utc(2026, 10, 7, 22), 25),
    // 03:40 İstanbul starts on the old study day, even though it ends 04:30.
    (DateTime.utc(2026, 10, 8, 0, 40), 50),
    (DateTime.utc(2026, 10, 8, 1, 35), 25),
  ];
  return [
    for (var i = 0; i < fixtures.length; i++)
      StatSession.fromStudySession(
        StudySession.fromJson({
          'id': 'row-$i',
          'user_id': 'heatmap-owner',
          'category': 'Matematik',
          'category_id': _math,
          'duration_minutes': fixtures[i].$2,
          'started_at': fixtures[i].$1.toIso8601String(),
          'completed_at': fixtures[i].$1
              .add(Duration(minutes: fixtures[i].$2))
              .toIso8601String(),
          'client_uuid': 'accepted-$i',
          'categories': {
            'name': 'Matematik',
            'color_hex': '#EF4444',
            'icon_name': 'calculate',
          },
        }),
      ),
  ];
}

Finder _cell(String label) => find.descendant(
  of: find.byType(MonthlyTrackingScreen),
  matching: find.byWidgetPredicate(
    (widget) => widget is Semantics && widget.properties.label == label,
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setStudyTimeZone('Europe/Istanbul');
  });
  tearDown(() => setStudyTimeZone(null));

  for (final language in AppLanguage.values) {
    testWidgets('monthly heatmap splits 250 minutes into 225/25 ($language)', (
      tester,
    ) async {
      await LanguageService.instance.setLanguage(language);
      tester.view.physicalSize = const Size(420, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final sessions = _sessions();
      expect(
        sessions.map((session) => session.clientUuid).toSet(),
        hasLength(6),
      );
      expect(sumMinutes(sessions), 250);
      final days = dailyTotals(
        sessions,
        monthStartOf(_today),
        monthEndOf(_today),
      ).where((day) => day.minutes > 0).toList();
      expect(
        {for (final day in days) dayKeyOf(day.day): day.minutes},
        {20261007: 225, 20261008: 25},
      );
      expect(days.fold<int>(0, (sum, day) => sum + day.minutes), 250);
      expect(totalsByCategory(sessions).single.minutes, 250);

      final isTurkish = language == AppLanguage.tr;
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(isTurkish ? 'tr' : 'en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MonthlyTrackingScreen(
              sessions: sessions,
              today: _today,
              categories: [_category],
              onRefresh: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _cell(isTurkish ? '7 Ekim: 3sa 45dk' : '7 October: 3h 45m'),
        findsOneWidget,
      );
      expect(
        _cell(isTurkish ? '8 Ekim: 25dk' : '8 October: 25m'),
        findsOneWidget,
      );
      // The former monthly-total suffix assertion must not be reintroduced.
      expect(
        find.descendant(
          of: find.byType(MonthlyTrackingScreen),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                (widget.properties.label?.endsWith(
                      isTurkish ? ': 4sa 10dk' : ': 4h 10m',
                    ) ??
                    false),
          ),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
