import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/screens/reports_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/details_exam_backend.dart';
import 'support/fake_supabase_service.dart';

class _NavigationHarness extends StatefulWidget {
  const _NavigationHarness({required this.exams, required this.reports});
  final ExamService exams;
  final FakeSupabaseService reports;

  @override
  State<_NavigationHarness> createState() => _NavigationHarnessState();
}

class _NavigationHarnessState extends State<_NavigationHarness> {
  int index = 0;
  int historyRequests = 0;
  String goal = 'yks';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      actions: [
        TextButton(
          key: const ValueKey('reports-nav'),
          onPressed: () => setState(() => index = 0),
          child: const Text('R'),
        ),
        TextButton(
          key: const ValueKey('change-goal'),
          onPressed: () => setState(() => goal = 'dus'),
          child: const Text('G'),
        ),
      ],
    ),
    body: IndexedStack(
      index: index,
      children: [
        ReportsScreen(
          categories: const [],
          service: widget.reports,
          loadExamAttempts: () async => [],
          onOpenExams: () => setState(() {
            historyRequests++;
            index = 1;
          }),
        ),
        ExamScreen(
          service: widget.exams,
          userSegment: goal,
          openHistoryRequest: historyRequests,
          loadStudySessions: () async => [],
        ),
      ],
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_US');
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in ['tr', 'en']) {
    testWidgets('report opens exam history on every request: $language', (
      tester,
    ) async {
      final backend = DetailsExamBackend();
      final exams = ExamService(backend: backend);
      final now = DateTime.now().toUtc();
      final reports = FakeSupabaseService()
        ..remoteRows = [
          {
            'id': 'study1',
            'user_id': 'user-1',
            'category': 'Matematik',
            'duration_minutes': 25,
            'started_at': now.subtract(const Duration(minutes: 25)).toIso8601String(),
            'completed_at': now.toIso8601String(),
            'client_uuid': 'study-1',
            'session_kind': 'normal',
          },
        ];
      addTearDown(exams.dispose);
      addTearDown(backend.owner.dispose);
      await exams.initialize();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _NavigationHarness(exams: exams, reports: reports),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = lookupAppLocalizations(Locale(language));

      Future<void> openHistory() async {
        final open = find.text(l10n.statsOpenExamDetails);
        await tester.ensureVisible(open);
        await tester.tap(open);
        await tester.pumpAndSettle();
        expect(find.text(l10n.examInsights), findsOneWidget);
        expect(find.byKey(const ValueKey('exam-card-tyt')), findsNothing);
      }

      await openHistory();
      await tester.tap(find.byKey(const ValueKey('exam-tab-new')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('exam-card-tyt')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('reports-nav')));
      await tester.pumpAndSettle();
      await openHistory();

      await tester.tap(find.byKey(const ValueKey('change-goal')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.examInsights), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('exam-tab-new')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('exam-card-dus')), findsOneWidget);
      expect(find.byKey(const ValueKey('exam-card-tyt')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
