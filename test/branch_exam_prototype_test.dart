import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/prototypes/branch_exam_prototype_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final language in ['tr', 'en']) {
    testWidgets('isolated branch preview: $language', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 1100);
      addTearDown(tester.view.reset);
      final locale = Locale(language);
      final l10n = lookupAppLocalizations(locale);
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const BranchExamPrototypeScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.branchPrototypeNotice), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('branch-prototype-configure')),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.branchExamReward(20)), findsOneWidget);
      for (final (minutes, sand) in [(50, 40), (75, 60), (25, 20)]) {
        final choice = find.byKey(ValueKey('branch-exam-duration-$minutes'));
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(find.text(l10n.branchExamReward(sand)), findsOneWidget);
      }

      final questions = find.byKey(const ValueKey('branch-exam-questions'));
      final confirm = find.byKey(const ValueKey('branch-exam-confirm'));
      await tester.enterText(questions, '0');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text(l10n.branchExamQuestionsInvalid), findsOneWidget);
      await tester.enterText(questions, '201');
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text(l10n.branchExamQuestionsInvalid), findsOneWidget);
      await tester.enterText(questions, '40');
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.text(l10n.branchPrototypeNoLeague), findsOneWidget);
      expect(find.text(l10n.branchExamReward(20)), findsOneWidget);
      expect(find.text(l10n.branchPrototypeNotice), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('branch-prototype-start')));
      await tester.pump();
      expect(find.text(l10n.branchPrototypeRunning), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();
      expect(find.text(l10n.branchPrototypeResults), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('branch-prototype-correct')),
        '30',
      );
      await tester.enterText(
        find.byKey(const ValueKey('branch-prototype-wrong')),
        '11',
      );
      final show = find.byKey(const ValueKey('branch-prototype-show-result'));
      await tester.ensureVisible(show);
      await tester.tap(show);
      await tester.pumpAndSettle();
      expect(find.text(l10n.branchPrototypeResultInvalid), findsWidgets);
      await tester.enterText(
        find.byKey(const ValueKey('branch-prototype-wrong')),
        '4',
      );
      await tester.ensureVisible(show);
      await tester.tap(show);
      await tester.pumpAndSettle();
      expect(find.text('${l10n.examBlank}: 6'), findsOneWidget);
      expect(
        find.text('${l10n.examNet}: ${language == 'tr' ? '29,00' : '29.00'}'),
        findsOneWidget,
      );
      expect(find.text(l10n.branchPrototypeNoSave), findsOneWidget);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
