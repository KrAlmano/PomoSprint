import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/models/study_session.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/details_exam_backend.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'exam insights refresh on visibility and owner switch, ignoring the old request',
    (tester) async {
      final backend = DetailsExamBackend();
      final service = ExamService(backend: backend);
      addTearDown(service.dispose);
      addTearDown(backend.owner.dispose);
      await service.initialize();
      var loads = 0;
      var holdNext = false;
      final oldOwnerRequest = Completer<List<StudySession>>();
      Future<List<StudySession>> load() {
        loads++;
        if (holdNext) {
          holdNext = false;
          return oldOwnerRequest.future;
        }
        return Future.value([]);
      }

      Widget app(bool visible) => MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TickerMode(
          enabled: visible,
          child: Scaffold(
            body: ExamScreen(
              service: service,
              historyOnly: true,
              loadStudySessions: load,
            ),
          ),
        ),
      );
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      final initialLoads = loads;
      expect(initialLoads, greaterThan(0));
      await tester.pumpWidget(app(false));
      await tester.pumpAndSettle();
      holdNext = true;
      await tester.pumpWidget(app(true));
      await tester.pump();
      expect(loads, greaterThan(initialLoads));
      final beforeSwitch = loads;
      backend.owner.value = 'owner-2';
      await tester.pumpAndSettle();
      expect(loads, greaterThan(beforeSwitch));
      oldOwnerRequest.completeError(StateError('old owner request failed'));
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(const Locale('tr'));
      expect(find.text(l10n.statsStaleNotice), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'abandoned exam card does not present planned minutes as elapsed',
    (tester) async {
      final backend = DetailsExamBackend();
      final complete = detailsCompletedAttempt(id: 'tyt', seconds: 9900);
      final abandoned = ExamAttempt.fromJson({
        ...complete.toJson(),
        'status': 'abandoned',
        'completion_kind': null,
      })!;
      backend.rows[abandoned.clientUuid] = abandoned;
      final service = ExamService(backend: backend);
      addTearDown(service.dispose);
      addTearDown(backend.owner.dispose);
      await service.initialize();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
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
      final l10n = lookupAppLocalizations(const Locale('tr'));
      expect(
        find.text(l10n.examSubjectQuestions(abandoned.totalQuestions)),
        findsOneWidget,
      );
      expect(
        find.text(
          l10n.examQuestionsMinutes(
            abandoned.totalQuestions,
            abandoned.durationSeconds ~/ 60,
          ),
        ),
        findsNothing,
      );
      expect(find.text(l10n.examNoAward), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
