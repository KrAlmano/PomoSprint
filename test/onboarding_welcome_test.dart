import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/widgets/auth/onboarding_welcome_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    String uid, {
    Size size = const Size(390, 844),
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: LanguageService.instance,
        builder: (context, _) => MaterialApp(
          locale: LanguageService.instance.currentLocale,
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingWelcomeGate(
            key: ValueKey(uid),
            ownerId: uid,
            onSignOut: () async {},
            child: const Scaffold(body: Text('age-step')),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in AppLanguage.values) {
    testWidgets(
      'kayıt sonrası ${language.name} açık seçim ister ve yaş adımına geçer',
      (tester) async {
        await open(tester, 'new-owner');
        final proceed = find.byKey(
          const ValueKey('onboarding-language-continue'),
        );
        expect(tester.widget<FilledButton>(proceed).onPressed, isNull);
        expect(find.text('age-step'), findsNothing);
        await tester.tap(
          find.byKey(ValueKey('onboarding-language-${language.name}')),
        );
        await tester.pump();
        await tester.tap(proceed);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        expect(find.text('age-step'), findsOneWidget);
        expect(LanguageService.instance.currentLanguage, language);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getBool(OnboardingWelcomeGate.keyFor('new-owner')),
          isTrue,
        );
      },
    );
  }

  testWidgets('önceki tercih başka hesabın dil sorusunu atlatmaz', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      OnboardingWelcomeGate.keyFor('old-owner'): true,
    });
    await open(tester, 'old-owner');
    expect(find.text('age-step'), findsOneWidget);
    await open(tester, 'new-owner');
    expect(find.text('age-step'), findsNothing);
    expect(
      find.byKey(const ValueKey('onboarding-language-tr')),
      findsOneWidget,
    );
  });

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    for (final dark in [false, true]) {
      testWidgets(
        'karşılama ${size.width}x${size.height} dark=$dark taşmadan kayar',
        (tester) async {
          await open(tester, 'layout-owner', size: size, dark: dark);
          await tester.ensureVisible(
            find.byKey(const ValueKey('onboarding-language-continue')),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
