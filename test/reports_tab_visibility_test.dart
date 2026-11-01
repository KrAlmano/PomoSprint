import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/details_exam_backend.dart';
import 'support/fake_supabase_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in ['tr', 'en']) {
    testWidgets('report tabs share the available width at 320pt ($language)', (
      tester,
    ) async {
      final backend = DetailsExamBackend();
      final exams = ExamService(backend: backend);
      final reports = FakeSupabaseService();
      final semantics = tester.ensureSemantics();
      addTearDown(exams.dispose);
      addTearDown(backend.owner.dispose);
      await exams.initialize();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 750);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReportsScreen(
            categories: const [],
            service: reports,
            examService: exams,
            loadExamAttempts: () async => exams.attempts,
            loadExamStudySessions: () async => [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = find.byKey(const ValueKey('reports-tab-scroll'));
      final inner = find.descendant(
        of: scroll,
        matching: find.byType(Scrollable),
      );
      expect(tester.state<ScrollableState>(inner).position.maxScrollExtent, 0);
      final widths = [
        for (var i = 0; i < 4; i++)
          tester.getSize(find.byKey(ValueKey('reports-tab-cell-$i'))).width,
      ];
      for (final width in widths) {
        expect(width, closeTo(widths.first, .01));
        expect(width, greaterThanOrEqualTo(44));
      }
      final l10n = lookupAppLocalizations(Locale(language));
      final labels = [
        l10n.reportsTabDailyShort,
        l10n.reportsTabWeeklyShort,
        l10n.reportsTabMonthlyShort,
        l10n.reportsTabExamsShort,
      ];
      final fullLabels = [
        l10n.reportsDailyTab,
        l10n.reportsWeeklyTab,
        l10n.reportsMonthlyTab,
        l10n.examTitle,
      ];
      for (var i = 0; i < labels.length; i++) {
        final label = labels[i];
        final text = find.descendant(of: scroll, matching: find.text(label));
        final rect = tester.getRect(text);
        final viewport = tester.getRect(scroll);
        expect(rect.left, greaterThanOrEqualTo(viewport.left));
        expect(rect.right, lessThanOrEqualTo(viewport.right));
        await tester.tap(text);
        await tester.pumpAndSettle();
        final accessible = find.descendant(
          of: scroll,
          matching: find.bySemanticsLabel(fullLabels[i]),
        );
        expect(
          tester.getSemantics(accessible),
          matchesSemantics(
            label: fullLabels[i],
            isButton: true,
            hasTapAction: true,
            hasSelectedState: true,
            isSelected: true,
          ),
        );
        expect(tester.takeException(), isNull);
      }
      semantics.dispose();
    });
  }

  testWidgets(
    'selected report tab stays visible after in-page navigation and return at large text',
    (tester) async {
      final backend = DetailsExamBackend();
      final exams = ExamService(backend: backend);
      final reports = FakeSupabaseService();
      addTearDown(exams.dispose);
      addTearDown(backend.owner.dispose);
      await exams.initialize();
      final now = DateTime.now().toUtc();
      reports.remoteRows = [
        {
          'id': 'study-1',
          'user_id': 'user-1',
          'category': 'Matematik',
          'duration_minutes': 25,
          'started_at': now
              .subtract(const Duration(minutes: 25))
              .toIso8601String(),
          'completed_at': now.toIso8601String(),
          'client_uuid': 'study-1',
          'session_kind': 'normal',
        },
      ];
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.reset);
      Widget app(bool visible) => MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: TickerMode(
          enabled: visible,
          child: ReportsScreen(
            categories: const [],
            service: reports,
            examService: exams,
            loadExamAttempts: () async => exams.attempts,
            loadExamStudySessions: () async => [],
          ),
        ),
      );
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(const Locale('tr'));
      final scroller = find.byKey(const ValueKey('reports-tab-scroll'));
      final details = find.text(l10n.statsOpenExamDetails);
      final tab = find.descendant(
        of: scroller,
        matching: find.text(l10n.reportsTabExamsShort),
      );
      expect(
        tester.getTopLeft(tab).dx,
        greaterThanOrEqualTo(tester.getBottomRight(scroller).dx),
      );
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      void expectTabVisible() {
        final viewport = tester.getRect(scroller);
        final label = tester.getRect(tab);
        expect(label.left, greaterThanOrEqualTo(viewport.left));
        expect(label.right, lessThanOrEqualTo(viewport.right));
      }

      expectTabVisible();
      expect(
        find.byKey(const ValueKey('exam-reports-inside-reports')),
        findsOneWidget,
      );

      await tester.pumpWidget(app(false));
      await tester.pumpAndSettle();
      final inner = find.descendant(
        of: scroller,
        matching: find.byType(Scrollable),
      );
      tester.state<ScrollableState>(inner).position.jumpTo(0);
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      expectTabVisible();
      expect(tester.takeException(), isNull);
    },
  );
}
