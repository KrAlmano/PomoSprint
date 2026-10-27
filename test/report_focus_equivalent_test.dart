import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/study_session.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:pomodoro/widgets/stats/session_type_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
  });

  for (final language in ['tr', 'en']) {
    testWidgets(
      '50 minutes means one session and two explicit focus equivalents: $language',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await LanguageService.instance.setLanguage(
          language == 'tr' ? AppLanguage.tr : AppLanguage.en,
        );
        final semantics = tester.ensureSemantics();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(430, 3500);
        addTearDown(tester.view.reset);
        final day = DateTime(2026, 10, 28);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DailyReportView(
                sessions: [
                  StatSession(
                    day: day,
                    minutes: 50,
                    categoryName: 'Matematik',
                    clientUuid: 'one-fifty-minute-session',
                    kind: StudySessionKind.normal,
                  ),
                ],
                today: day,
                dailyGoalMinutes: 200,
                hasHistory: true,
                categories: const [],
                onRefresh: () async {},
                showDistributionPercent: false,
                onDistributionModeChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final summary = tester.widget<SessionTypeSummary>(
          find.byType(SessionTypeSummary),
        );
        expect(summary.counts.normalSessions, 1);
        expect(summary.counts.focusEquivalents, 2);
        final l10n = await AppLocalizations.delegate.load(Locale(language));
        final label = l10n.statsTodayPomodoros(2);
        expect(
          find.bySemanticsLabel(RegExp(RegExp.escape(label))),
          findsWidgets,
        );
        expect(label, contains('25'));
        expect(
          label.toLowerCase(),
          contains(language == 'tr' ? 'eşdeğer' : 'equivalent'),
        );
        expect(
          label.toLowerCase(),
          isNot(contains(language == 'tr' ? 'tamamlandı' : 'completed')),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
