import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/post_auth_onboarding_screen.dart';
import 'package:pomodoro/services/onboarding_draft.dart';
import 'package:pomodoro/widgets/auth/category_name_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_supabase_service.dart';

class _DialogService extends FakeSupabaseService {
  @override
  bool get canReauthorizeWithApple => false;
}

void main() {
  testWidgets(
    'onboarding delete confirmation follows a device language change',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = _DialogService();
      final locale = ValueNotifier(const Locale('tr'));
      addTearDown(locale.dispose);
      final tr = await AppLocalizations.delegate.load(const Locale('tr'));
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (context, value, _) => MaterialApp(
            locale: value,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PostAuthOnboardingScreen(
              service: service,
              onCompleted: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<CupertinoPicker>(find.byType(CupertinoPicker))
          .scrollController!
          .jumpToItem(6);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.continueBtn));
      await tester.pumpAndSettle();
      final delete = find.widgetWithText(TextButton, tr.deleteAccount);
      await tester.ensureVisible(delete);
      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      locale.value = const Locale('en');
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      final updated = find
          .descendant(of: dialog, matching: find.text(en.deleteAccount))
          .evaluate()
          .length;
      final stale = find
          .descendant(of: dialog, matching: find.text(tr.deleteAccount))
          .evaluate()
          .length;
      // Never confirm account deletion; this checks only the open dialog.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(updated, 2);
      expect(stale, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'onboarding category labels update while typed value is retained',
    (tester) async {
      final service = _DialogService();
      SharedPreferences.setMockInitialValues({
        OnboardingDraftStore.keyFor(service.currentUser.value!.id!): jsonEncode(
          OnboardingDraft(
            step: 2,
            birthYear: 2000,
            segment: 'yks',
            selectedCategories: const ['Matematik'],
            autoCategories: const ['Matematik'],
            dailyGoalMinutes: 120,
          ).toJson(),
        ),
      });
      final locale = ValueNotifier(const Locale('tr'));
      addTearDown(locale.dispose);
      final tr = await AppLocalizations.delegate.load(const Locale('tr'));
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (context, value, _) => MaterialApp(
            locale: value,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PostAuthOnboardingScreen(
              service: service,
              onCompleted: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final open = find.text(tr.onboardingCreateOwnCategory);
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'My Biology 🧪');
      locale.value = const Locale('en');
      await tester.pumpAndSettle();
      final currentTitle = find
          .text(en.onboardingAddCategoryTitle)
          .evaluate()
          .length;
      final currentButton = find.text(en.addBtn).evaluate().length;
      final field = tester.widget<TextField>(find.byType(TextField));
      final hint = field.decoration!.hintText;
      final typed = field.controller!.text;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(currentTitle, 1);
      expect(currentButton, 1);
      expect(hint, en.onboardingCategoryHint);
      expect(typed, 'My Biology 🧪');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom category labels remain caller-owned after locale changes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final locale = ValueNotifier(const Locale('tr'));
      addTearDown(locale.dispose);
      await tester.pumpWidget(
        ValueListenableBuilder<Locale>(
          valueListenable: locale,
          builder: (context, value, _) => MaterialApp(
            locale: value,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Open'),
                  onPressed: () => CategoryNameDialog.show(
                    context,
                    title: 'Caller title',
                    confirmLabel: 'Caller confirm',
                    hintText: 'Caller hint',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'User entry');
      locale.value = const Locale('en');
      await tester.pumpAndSettle();
      expect(find.text('Caller title'), findsOneWidget);
      expect(find.text('Caller confirm'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.hintText, 'Caller hint');
      expect(field.controller!.text, 'User entry');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
