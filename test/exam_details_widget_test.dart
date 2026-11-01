import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/exam_catalog_defaults.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/models/exam_details.dart';
import 'package:pomodoro/services/exam_persistence.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:pomodoro/widgets/exam_results_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/details_exam_backend.dart';

Finder field(String subject, int index) =>
    find.byKey(ValueKey('exam-result-$subject-$index'));
const titleField = ValueKey('exam-detail-title');
const noteField = ValueKey('exam-detail-note');

Widget app(Widget home, String language, {double scale = 1}) => MaterialApp(
  locale: Locale(language),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

Future<AppLocalizations> open(
  WidgetTester tester,
  ExamService service,
  ExamAttempt attempt,
  String language, {
  Size size = const Size(430, 932),
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    app(
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open-details'),
            onPressed: () => showExamResultsDialog(
              context,
              service: service,
              attempt: attempt,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
      language,
      scale: scale,
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-details')));
  await tester.pumpAndSettle();
  return AppLocalizations.delegate.load(Locale(language));
}

Future<void> enter(WidgetTester tester, Finder finder, String text) async {
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await tester.pump();
}

Future<void> save(WidgetTester tester, AppLocalizations l10n) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final button = find.widgetWithText(FilledButton, l10n.examSaveResults);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  late DetailsExamBackend backend;
  late ExamService service;
  void prepare() {
    backend = DetailsExamBackend();
    service = ExamService(backend: backend, createUuid: () => 'early-ui');
  }

  tearDown(() {
    service.dispose();
    backend.owner.dispose();
  });

  for (final language in ['tr', 'en']) {
    testWidgets(
      'result cards preserve readable fields and calculated blanks at large text ($language)',
      (tester) async {
        prepare();
        final semantics = tester.ensureSemantics();
        addTearDown(tester.view.reset);
        final attempt = detailsCompletedAttempt(id: 'tyt', seconds: 9900);
        backend.rows[attempt.clientUuid] = attempt;
        await service.initialize();
        for (final size in [const Size(320, 568), const Size(568, 320)]) {
          final l10n = await open(
            tester,
            service,
            attempt,
            language,
            size: size,
            scale: 2,
          );
          final card = find.byKey(const ValueKey('exam-result-card-turkish'));
          expect(card, findsOneWidget);
          for (final (index, label) in [
            (0, l10n.examCorrect),
            (1, l10n.examWrong),
            (2, l10n.examBlank),
          ]) {
            await tester.ensureVisible(field('turkish', index));
            await tester.pumpAndSettle();
            await tester.tap(field('turkish', index));
            await tester.pumpAndSettle();
            final node = tester.getSemantics(field('turkish', index));
            expect(node.label, contains(label));
            expect(
              node.getSemanticsData().hasAction(ui.SemanticsAction.setText),
              isTrue,
            );
          }
          expect(
            find.descendant(of: card, matching: find.byType(FittedBox)),
            findsNothing,
            reason: 'Accessibility text must not be shrunk to fit',
          );
          await enter(tester, field('turkish', 0), '30');
          await enter(tester, field('turkish', 1), '4');
          expect(
            tester.widget<TextField>(field('turkish', 2)).controller!.text,
            '6',
          );
          expect(
            find.text(
              '${l10n.examNet}: ${language == 'tr' ? '29,00' : '29.00'}',
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
        semantics.dispose();
      },
    );
    testWidgets(
      'AYT selects modules before scores and saves one atomic patch ($language)',
      (tester) async {
        prepare();
        addTearDown(tester.view.reset);
        final attempt = detailsCompletedAttempt();
        backend.rows[attempt.clientUuid] = attempt;
        await service.initialize();
        final l10n = await open(tester, service, attempt, language);
        expect(find.text(l10n.examSelectModules), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsNWidgets(4));
        expect(field('mathematics', 0), findsNothing);
        final module = find.byKey(const ValueKey('exam-module-mathematics'));
        await tester.ensureVisible(module);
        await tester.tap(module);
        await tester.pumpAndSettle();
        expect(field('mathematics', 0), findsOneWidget);
        expect(field('literature', 0), findsNothing);
        await enter(tester, field('mathematics', 0), '25');
        await enter(tester, field('mathematics', 1), '4');
        expect(
          tester.widget<TextField>(field('mathematics', 2)).controller!.text,
          '11',
        );
        await enter(tester, find.byKey(titleField), 'AYT 1');
        await enter(
          tester,
          find.byKey(noteField),
          language == 'tr' ? 'Tekrar et' : 'Review',
        );
        await save(tester, l10n);
        expect(find.byType(AlertDialog), findsNothing);
        final calls = backend.calls
            .where((c) => c.$1 == 'save_exam_details')
            .toList();
        expect(calls, hasLength(1));
        expect(calls.single.$2['p_details'], {
          'title': 'AYT 1',
          'note': language == 'tr' ? 'Tekrar et' : 'Review',
          'selected_module_ids': ['mathematics'],
        });
        expect(calls.single.$2['p_expected_revision'], 0);
        expect(calls.single.$2['p_subject_results'], [
          const ExamSubjectResult(
            subjectId: 'mathematics',
            correct: 25,
            wrong: 4,
            blank: 11,
          ).toJson(),
        ]);
        expect(
          backend.calls.where((c) => c.$1 == 'save_exam_results'),
          isEmpty,
        );
        expect(service.attempts.single.selectedQuestionCount, 40);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'metadata-only applies to every completed exam with unchanged score ($language)',
      (tester) async {
        prepare();
        addTearDown(tester.view.reset);
        await service.initialize();
        for (final definition in offlineExamCatalog.exams) {
          final attempt = detailsCompletedAttempt(
            id: definition.id,
            seconds: definition.durationSeconds,
          );
          backend.rows.clear();
          backend.rows[attempt.clientUuid] = attempt;
          await service.refresh();
          final l10n = await open(
            tester,
            service,
            attempt,
            language,
            size: const Size(932, 430),
            scale: 1.5,
          );
          await enter(tester, find.byKey(titleField), 'Personal');
          await save(tester, l10n);
          expect(find.byType(AlertDialog), findsNothing, reason: definition.id);
          final request = backend.calls
              .lastWhere((c) => c.$1 == 'save_exam_details')
              .$2;
          expect(request['p_subject_results'], isNull, reason: definition.id);
          expect(request['p_details'], {'title': 'Personal'});
          expect(backend.rows[attempt.clientUuid]!.subjectResults, isEmpty);
          expect(tester.takeException(), isNull, reason: definition.id);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets(
      'early finish waits for server offline and exposes exact pending language ($language)',
      (tester) async {
        prepare();
        addTearDown(tester.view.reset);
        await service.initialize();
        await service.start(service.catalog.byId('ayt')!);
        backend.clock = backend.clock.add(const Duration(minutes: 90));
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(430, 932);
        await tester.pumpWidget(
          app(Scaffold(body: ExamScreen(service: service)), language),
        );
        await tester.pumpAndSettle();
        final l10n = await AppLocalizations.delegate.load(Locale(language));
        final early = find.byKey(const ValueKey('exam-finish-early'));
        await tester.ensureVisible(early);
        await tester.tap(early);
        await tester.pumpAndSettle();
        expect(find.text(l10n.examFinishEarlyBody), findsOneWidget);
        backend.isAvailable = false;
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(FilledButton, l10n.examFinishEarly),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.examEarlyPendingTitle), findsOneWidget);
        expect(find.text(l10n.examEarlyPendingBody), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byKey(const ValueKey('exam-finish-early')), findsNothing);
        expect(find.text(l10n.examAbandon), findsNothing);
        expect(service.blocksOtherSessions.value, isTrue);
        expect(backend.acceptedEarly, 0);
        expect(tester.takeException(), isNull);
        service.setForeground(false);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'offline draft reopens then immutable queued form remains disabled until retry',
    (tester) async {
      prepare();
      addTearDown(tester.view.reset);
      final attempt = detailsCompletedAttempt();
      backend.rows[attempt.clientUuid] = attempt;
      await service.initialize();
      final l10n = await open(tester, service, attempt, 'tr');
      await enter(tester, find.byKey(noteField), 'Keep draft');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('open-details')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(noteField)).controller!.text,
        'Keep draft',
      );
      backend.isAvailable = false;
      await save(tester, l10n);
      expect(find.text(l10n.examDetailsQueued), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open-details')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(noteField)).enabled, isFalse);
      expect(find.text(l10n.examDetailsPending), findsOneWidget);
      backend.isAvailable = true;
      await tester.tap(find.widgetWithText(TextButton, l10n.examRetry));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(service.attempts.single.note, 'Keep draft');
      expect(service.recordFor(attempt.clientUuid)!.detailsDraft, isNull);
    },
  );

  testWidgets(
    'stale revision requires explicit review and preserves typed note',
    (tester) async {
      prepare();
      addTearDown(tester.view.reset);
      final attempt = detailsCompletedAttempt();
      backend.rows[attempt.clientUuid] = attempt;
      await service.initialize();
      final l10n = await open(tester, service, attempt, 'en');
      await enter(tester, find.byKey(noteField), 'Unsaved note');
      backend.rows[attempt.clientUuid] = detailsCompletedAttempt(
        revision: 1,
        title: 'Other device',
      );
      await save(tester, l10n);
      expect(find.text(l10n.examDetailsConflict), findsOneWidget);
      final reload = find.byKey(const ValueKey('exam-details-reload'));
      await tester.ensureVisible(reload);
      await tester.tap(reload);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byKey(noteField)).controller!.text,
        'Unsaved note',
      );
      expect(
        tester.widget<TextField>(find.byKey(titleField)).controller!.text,
        'Other device',
      );
      await save(tester, l10n);
      expect(find.byType(AlertDialog), findsNothing);
      expect(service.attempts.single.title, 'Other device');
      expect(service.attempts.single.note, 'Unsaved note');
      expect(service.attempts.single.detailsRevision, 2);
    },
  );

  testWidgets(
    'legacy capabilities hide new controls while preserving original score entry',
    (tester) async {
      prepare();
      addTearDown(tester.view.reset);
      backend.detailsAvailable = false;
      backend.earlyAvailable = false;
      final attempt = detailsCompletedAttempt();
      backend.rows[attempt.clientUuid] = attempt;
      await service.initialize();
      await open(tester, service, attempt, 'en');
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.byKey(titleField), findsNothing);
      expect(find.byKey(noteField), findsNothing);
      expect(field('literature', 0), findsOneWidget);
    },
  );

  testWidgets(
    'owner change dismisses private form and never persists under the new owner',
    (tester) async {
      prepare();
      addTearDown(tester.view.reset);
      final attempt = detailsCompletedAttempt();
      backend.rows[attempt.clientUuid] = attempt;
      await service.initialize();
      await open(tester, service, attempt, 'en');
      await enter(tester, find.byKey(noteField), 'Private draft');
      backend.rows.clear();
      backend.owner.value = 'owner-2';
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(await service.persistence.read('owner-2'), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'accepted early completion opens module form and keeps actual/planned times distinct',
    (tester) async {
      prepare();
      addTearDown(tester.view.reset);
      await service.initialize();
      await service.start(service.catalog.byId('ayt')!);
      backend.clock = backend.clock.add(const Duration(minutes: 90));
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 932);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        app(Scaffold(body: ExamScreen(service: service)), 'en'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('exam-finish-early')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, l10n.examFinishEarly),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.examDetailsTitle), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(4));
      expect(service.attempts.single.actualSeconds, 5400);
      expect(service.attempts.single.plannedSeconds, 10800);
      expect(service.attempts.single.examCoinsEarned, 72);
      await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
      await tester.pumpAndSettle();
      expect(find.text(l10n.examCompletedEarly), findsOneWidget);
      expect(service.blocksOtherSessions.value, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'module and details form fits narrow portrait and landscape at double text scale',
    (tester) async {
      prepare();
      addTearDown(tester.view.reset);
      final attempt = detailsCompletedAttempt();
      backend.rows[attempt.clientUuid] = attempt;
      await service.initialize();
      for (final language in ['tr', 'en']) {
        for (final size in const [Size(320, 568), Size(844, 390)]) {
          final l10n = await open(
            tester,
            service,
            attempt,
            language,
            size: size,
            scale: 2,
          );
          expect(find.text(l10n.examSelectModules), findsOneWidget);
          await enter(tester, find.byKey(noteField), 'Note');
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$language $size');
          await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      }
    },
  );
  for (final language in ['tr', 'en']) {
    testWidgets(
      'oversized paste is visible and safe across autosave and cold reopen ($language)',
      (tester) async {
        prepare();
        addTearDown(tester.view.reset);
        final attempt = detailsCompletedAttempt();
        backend.rows[attempt.clientUuid] = attempt;
        backend.rows['uuid-tyt'] = detailsCompletedAttempt(id: 'tyt');
        await service.initialize();
        final l10n = await open(tester, service, attempt, language);
        await enter(tester, find.byKey(titleField), 'x' * 5001);
        expect(
          tester.widget<TextField>(find.byKey(titleField)).controller!.text,
          isEmpty,
        );
        expect(find.text(l10n.examDetailsInvalid), findsOneWidget);
        await enter(tester, find.byKey(titleField), '🧠' * 120);
        await enter(tester, find.byKey(titleField), '🧠' * 121);
        expect(
          tester
              .widget<TextField>(find.byKey(titleField))
              .controller!
              .text
              .runes
              .length,
          120,
        );
        await enter(tester, find.byKey(noteField), 'x' * 20001);
        expect(
          tester.widget<TextField>(find.byKey(noteField)).controller!.text,
          isEmpty,
        );
        await enter(tester, find.byKey(noteField), '🧠' * 2000);
        await enter(tester, find.byKey(noteField), '🧠' * 2001);
        expect(
          tester
              .widget<TextField>(find.byKey(noteField))
              .controller!
              .text
              .runes
              .length,
          2000,
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        service.dispose();
        service = ExamService(backend: backend);
        await service.initialize();
        expect(service.errorCode, isNull);
        expect(service.attempts, hasLength(2));
        await open(
          tester,
          service,
          service.attempts.singleWhere((a) => a.id == attempt.id),
          language,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(titleField))
              .controller!
              .text
              .runes
              .length,
          120,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(noteField))
              .controller!
              .text
              .runes
              .length,
          2000,
        );
        expect(service.recordFor('uuid-tyt')!.detailsDraft, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'catalog explains net rules once without repeating the long introduction',
    (tester) async {
      prepare();
      addTearDown(tester.view.reset);
      for (final enabled in [false, true]) {
        backend.earlyAvailable = enabled;
        await service.initialize();
        await service.refresh();
        for (final language in ['tr', 'en']) {
          final l10n = await AppLocalizations.delegate.load(Locale(language));
          await tester.pumpWidget(
            app(Scaffold(body: ExamScreen(service: service)), language),
          );
          await tester.pumpAndSettle();
          expect(find.text(l10n.examNetInfo), findsOneWidget);
          expect(find.text(l10n.examIntro), findsNothing);
          expect(find.text(l10n.examIntroEarly), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      }
    },
  );
  testWidgets(
    'older readable long draft stays editable and reports its length error accurately',
    (tester) async {
      prepare();
      addTearDown(tester.view.reset);
      final attempt = detailsCompletedAttempt();
      backend.rows[attempt.clientUuid] = attempt;
      await service.persistence.write('owner-1', [
        ExamLocalRecord(
          clientUuid: attempt.clientUuid,
          definition: attempt.definition!,
          createdAt: attempt.startedAt,
          attempt: attempt,
          detailsDraft: ExamDetailsDraft(
            revision: 0,
            title: 'x' * 121,
            note: '',
            dirtyKeys: {'title'},
            fields: {},
            dirtySubjects: {},
          ),
        ),
      ]);
      await service.initialize();
      final l10n = await open(tester, service, attempt, 'en');
      expect(
        tester
            .widget<TextField>(find.byKey(titleField))
            .controller!
            .text
            .length,
        121,
      );
      await enter(tester, find.byKey(noteField), 'Still here');
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text(l10n.examDetailsInvalid), findsOneWidget);
      expect(service.errorCode, isNull);
      await enter(tester, find.byKey(titleField), 'Short title');
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        service.recordFor(attempt.clientUuid)!.detailsDraft!.title,
        'Short title',
      );
      expect(
        service.recordFor(attempt.clientUuid)!.detailsDraft!.note,
        'Still here',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'TR EN answer labels remain readable and inputs fit on narrow screens',
    (tester) async {
      prepare();
      addTearDown(tester.view.reset);
      final attempt = detailsCompletedAttempt(id: 'tyt');
      backend.rows[attempt.clientUuid] = attempt;
      await service.initialize();
      for (final language in ['tr', 'en']) {
        for (final scale in [1.0, 2.0]) {
          final l10n = await open(
            tester,
            service,
            attempt,
            language,
            size: const Size(320, 740),
            scale: scale,
          );
          final fields = [for (var i = 0; i < 3; i++) field('turkish', i)];
          final tops = fields.map((f) => tester.getRect(f).top).toList();
          if (scale == 1) {
            expect(tops[1], closeTo(tops[0], .01));
            expect(tops[2], closeTo(tops[0], .01));
          } else {
            expect(tops[1], greaterThan(tops[0]));
            expect(tops[2], greaterThan(tops[1]));
          }
          for (final label in [
            l10n.examCorrect,
            l10n.examWrong,
            l10n.examBlank,
          ]) {
            final text = tester.widget<Text>(find.text(label).first);
            expect(text.data, label);
          }
          expect(tester.takeException(), isNull, reason: '$language $scale');
          await tester.tap(find.widgetWithText(TextButton, l10n.cancel));
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      }
    },
  );
}
