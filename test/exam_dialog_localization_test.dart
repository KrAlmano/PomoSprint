import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/exam_screen.dart';
import 'package:pomodoro/services/exam_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_exam_backend.dart';

Widget _app(ValueNotifier<Locale> locale, ExamService service) =>
    ValueListenableBuilder<Locale>(
      valueListenable: locale,
      builder: (context, value, _) => MaterialApp(
        locale: value,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ExamScreen(service: service)),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('open exam rules follow a device language change', (
    tester,
  ) async {
    final backend = FakeExamBackend();
    final service = ExamService(backend: backend);
    final locale = ValueNotifier(const Locale('tr'));
    addTearDown(backend.owner.dispose);
    addTearDown(locale.dispose);
    final tr = await AppLocalizations.delegate.load(const Locale('tr'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(_app(locale, service));
    await tester.pumpAndSettle();
    final start = find.byKey(const ValueKey('exam-start-tyt'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text(tr.examRulesTitle), findsOneWidget);

    locale.value = const Locale('en');
    await tester.pumpAndSettle();
    final updated = find.text(en.examRulesTitle).evaluate().length;
    final stale = find.text(tr.examRulesTitle).evaluate().length;
    final updatedBody = find.text(en.examRulesBody).evaluate().length;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    service.dispose();

    expect(updated, 1);
    expect(updatedBody, 1);
    expect(stale, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'open exam abandon confirmation follows a device language change',
    (tester) async {
      final backend = FakeExamBackend();
      final service = ExamService(backend: backend);
      final locale = ValueNotifier(const Locale('tr'));
      addTearDown(backend.owner.dispose);
      addTearDown(locale.dispose);
      final tr = await AppLocalizations.delegate.load(const Locale('tr'));
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      await service.initialize();
      await service.start(service.catalog.exams.first);
      await tester.pumpWidget(_app(locale, service));
      await tester.pumpAndSettle();
      final abandon = find.widgetWithText(TextButton, tr.examAbandon);
      await tester.ensureVisible(abandon);
      await tester.tap(abandon);
      await tester.pumpAndSettle();
      expect(find.text(tr.examAbandonTitle), findsOneWidget);

      locale.value = const Locale('en');
      await tester.pumpAndSettle();
      final updated = find.text(en.examAbandonTitle).evaluate().length;
      final stale = find.text(tr.examAbandonTitle).evaluate().length;
      final updatedBody = find.text(en.examAbandonBody).evaluate().length;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      service.dispose();

      expect(updated, 1);
      expect(updatedBody, 1);
      expect(stale, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
