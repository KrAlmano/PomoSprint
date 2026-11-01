import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/details_exam_backend.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final language in ['tr', 'en']) {
    testWidgets('AYT cards show only known selected scope ($language)', (
      tester,
    ) async {
      final backend = DetailsExamBackend();
      final selected = detailsCompletedAttempt(modules: ['mathematics']);
      ExamAttempt variant(
        String uuid, {
        required List<String>? modules,
        bool omitDefinition = false,
      }) {
        final raw = {
          ...selected.toJson(),
          'id': uuid,
          'client_uuid': uuid,
          'selected_module_ids': modules,
        };
        if (omitDefinition) raw.remove('definition');
        return ExamAttempt.fromJson(raw)!;
      }

      final exact = variant('selected', modules: ['mathematics']);
      final legacy = variant('legacy', modules: null);
      final fallback = variant(
        'fallback',
        modules: ['mathematics'],
        omitDefinition: true,
      );
      final unsupported = variant(
        'unsupported',
        modules: ['future_module'],
        omitDefinition: true,
      );
      final tyt = detailsCompletedAttempt(id: 'tyt', seconds: 9900);
      for (final attempt in [exact, legacy, fallback, unsupported, tyt]) {
        backend.rows[attempt.clientUuid] = attempt;
      }
      final service = ExamService(backend: backend);
      addTearDown(service.dispose);
      addTearDown(backend.owner.dispose);
      await service.initialize();
      expect(
        service.attempts
            .firstWhere((a) => a.clientUuid == 'fallback')
            .definition,
        isNull,
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1200);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
      Finder within(String uuid, String text) => find.descendant(
        of: find.byKey(ValueKey('exam-history-card-$uuid')),
        matching: find.text(text),
      );
      for (final uuid in ['selected', 'fallback']) {
        expect(
          within(uuid, l10n.examSelectedQuestions(40, 160)),
          findsOneWidget,
        );
        expect(within(uuid, l10n.examCreditedMinutes(90)), findsOneWidget);
        expect(within(uuid, l10n.examQuestionsMinutes(160, 90)), findsNothing);
      }
      expect(within('legacy', l10n.examModuleUnknown), findsOneWidget);
      expect(within('legacy', l10n.examCreditedMinutes(90)), findsOneWidget);
      expect(
        within('legacy', l10n.examSelectedQuestions(160, 160)),
        findsNothing,
      );
      expect(
        within('legacy', l10n.examQuestionsMinutes(160, 90)),
        findsNothing,
      );
      expect(within('unsupported', l10n.examScopeUnavailable), findsOneWidget);
      expect(
        within('unsupported', l10n.examSelectedQuestions(0, 160)),
        findsNothing,
      );
      expect(
        within(tyt.clientUuid, l10n.examQuestionsMinutes(120, 165)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
