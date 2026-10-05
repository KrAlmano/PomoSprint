import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/forgot_password_screen.dart';
import 'package:pomodoro/screens/login_screen.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(
  Widget home, {
  Locale locale = const Locale('tr'),
  bool dark = false,
}) => MaterialApp(
  theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('login opens recovery without requiring an email first', (
    tester,
  ) async {
    await tester.pumpWidget(app(LoginScreen(onLoginSuccess: (_) {})));
    await tester.tap(find.text('Şifremi Unuttum'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
  });

  testWidgets(
    'invalid email stays in form; one request opens sent screen and returns to login',
    (tester) async {
      final request = Completer<void>();
      final emails = <String>[];
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ForgotPasswordScreen(
                      sendResetEmail: (email) {
                        emails.add(email);
                        return request.future;
                      },
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'invalid');
      await tester.tap(find.text('Doğrulama maili gönder'));
      await tester.pump();
      expect(emails, isEmpty);
      await tester.enterText(
        find.byType(TextFormField),
        ' person@example.com ',
      );
      await tester.tap(find.text('Doğrulama maili gönder'));
      await tester.pump();
      expect(emails, ['person@example.com']);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      request.complete();
      await tester.pumpAndSettle();
      expect(find.byType(PasswordResetSentScreen), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.text("Anladım, Giriş Yap'a Dön"));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    },
  );

  testWidgets('request failure keeps email and allows retry', (tester) async {
    await tester.pumpWidget(
      app(
        ForgotPasswordScreen(
          initialEmail: 'person@example.com',
          sendResetEmail: (_) async =>
              throw AuthFailure(AuthErrorCode.network),
        ),
      ),
    );
    await tester.tap(find.text('Doğrulama maili gönder'));
    await tester.pumpAndSettle();
    expect(find.byType(PasswordResetSentScreen), findsNothing);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      'person@example.com',
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  for (final size in const [
    Size(320, 568),
    Size(390, 844),
    Size(568, 320),
    Size(844, 390),
    Size(820, 1180),
    Size(1180, 820),
  ]) {
    for (final locale in const [Locale('tr'), Locale('en')]) {
      testWidgets(
        'recovery and sent fit $size $locale with keyboard and large text',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.view.viewInsets = const FakeViewPadding(bottom: 150);
          tester.platformDispatcher.textScaleFactorTestValue = 1.5;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          for (final screen in const [
            ForgotPasswordScreen(),
            PasswordResetSentScreen(),
          ]) {
            await tester.pumpWidget(
              app(screen, locale: locale, dark: locale.languageCode == 'en'),
            );
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.byType(FilledButton));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
