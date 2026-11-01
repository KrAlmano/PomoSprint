import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/details_exam_backend.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in ['tr', 'en']) {
    for (final dark in [false, true]) {
      testWidgets('history status and empty insights $language dark=$dark', (
        tester,
      ) async {
        final backend = DetailsExamBackend();
        final complete = detailsCompletedAttempt(id: 'tyt', seconds: 9900);
        final abandoned = ExamAttempt.fromJson({
          ...complete.toJson(),
          'id': 'abandoned-id',
          'client_uuid': 'abandoned-uuid',
          'status': 'abandoned',
          'completion_kind': null,
        })!;
        backend.rows[complete.clientUuid] = complete;
        backend.rows[abandoned.clientUuid] = abandoned;
        final service = ExamService(backend: backend);
        addTearDown(service.dispose);
        addTearDown(backend.owner.dispose);
        await service.initialize();
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 850);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: ExamScreen(
                service: service,
                historyOnly: true,
                loadStudySessions: () async => [],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(Locale(language));
        expect(
          find.byKey(const ValueKey('exam-insights-section')),
          findsOneWidget,
        );
        expect(find.text(l10n.examInsightsEmpty), findsOneWidget);
        final completed = find.byKey(
          const ValueKey('exam-history-status-completed'),
        );
        final notCompleted = find.byKey(
          const ValueKey('exam-history-status-abandoned'),
        );
        final successIcon = find.descendant(
          of: completed,
          matching: find.byIcon(Icons.check_circle_rounded),
        );
        expect(successIcon, findsOneWidget);
        final color = tester.widget<Icon>(successIcon).color!;
        expect(color.g, greaterThan(color.r));
        expect(
          find.descendant(
            of: notCompleted,
            matching: find.byIcon(Icons.check_circle_rounded),
          ),
          findsNothing,
        );
        expect(find.text(l10n.examAbandoned), findsOneWidget);
        expect(find.text(l10n.examNoAward), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
