import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/services/service_errors.dart';
import 'package:pomodoro/widgets/auth/change_password_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('password change error does not log provider message', (
    tester,
  ) async {
    final messages = <String>[];
    final previousPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = previousPrint);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showChangePasswordDialog(
                context,
                changePassword:
                    ({required currentPassword, required newPassword}) async {
                      throw StateError('SYNTHETIC_PROVIDER_SECRET');
                    },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Oldpassword1');
    await tester.enterText(fields.at(1), 'Newpassword1');
    await tester.enterText(fields.at(2), 'Newpassword1');
    final l10n = lookupAppLocalizations(const Locale('tr'));
    await tester.tap(find.text(l10n.changePasswordSave));
    await tester.pumpAndSettle();
    debugPrint = previousPrint;

    expect(messages.join('\n'), isNot(contains('SYNTHETIC_PROVIDER_SECRET')));
    expect(messages.join('\n'), contains('StateError'));
    expect(find.text(l10n.authErrUnknown), findsOneWidget);
  });

  for (final language in ['tr', 'en']) {
    testWidgets('reauthentication requirement is understandable in $language', (
      tester,
    ) async {
      final locale = Locale(language);
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showChangePasswordDialog(
                  context,
                  changePassword:
                      ({required currentPassword, required newPassword}) async {
                        throw const AuthException(
                          'reauthentication required',
                          code: 'reauthentication_needed',
                        );
                      },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Oldpassword1');
      await tester.enterText(fields.at(1), 'Newpassword1');
      await tester.enterText(fields.at(2), 'Newpassword1');
      final l10n = lookupAppLocalizations(locale);
      await tester.tap(find.text(l10n.changePasswordSave));
      await tester.pumpAndSettle();
      expect(find.text(l10n.changePasswordReauthenticate), findsOneWidget);
    });

    testWidgets('uncertain password update is explained in $language', (
      tester,
    ) async {
      final locale = Locale(language);
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showChangePasswordDialog(
                  context,
                  changePassword:
                      ({required currentPassword, required newPassword}) async {
                        throw const AuthFailure(
                          AuthErrorCode.passwordChangeOutcomeUnknown,
                        );
                      },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Oldpassword1');
      await tester.enterText(fields.at(1), 'Newpassword1');
      await tester.enterText(fields.at(2), 'Newpassword1');
      final l10n = lookupAppLocalizations(locale);
      await tester.tap(find.text(l10n.changePasswordSave));
      await tester.pumpAndSettle();
      expect(find.text(l10n.changePasswordOutcomeUnknown), findsOneWidget);
    });
  }
}
