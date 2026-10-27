import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/avatar_model.dart';
import 'package:pomodoro/screens/forgot_password_screen.dart';
import 'package:pomodoro/screens/login_screen.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/widgets/social/user_safety.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(ValueNotifier<Locale> locale, Widget child) =>
    ValueListenableBuilder<Locale>(
      valueListenable: locale,
      builder: (context, value, _) => MaterialApp(
        locale: value,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'known remote avatars retain bilingual fallback names when a label is missing',
    () {
      final known = AvatarCharacter.fallbackCatalog.firstWhere(
        (a) => !a.isLeagueAward,
      );
      for (final label in ['name_tr', 'name_en']) {
        final missing = {...known.toMap()}..remove(label);
        final blank = {...known.toMap(), label: ' \t '};
        for (final row in [missing, blank]) {
          final actual = AvatarCharacter.fromMap(row);
          expect(actual.getName(true), known.getName(true));
          expect(actual.getName(false), known.getName(false));
        }
      }
      expect(
        () => AvatarCharacter.fromMap({
          'id': 'unknown_future_avatar',
          'name_tr': 'Ad',
        }),
        throwsFormatException,
        reason:
            'An unknown missing translation must not display a raw asset ID',
      );
    },
  );

  testWidgets('login validation message follows a locale switch', (
    tester,
  ) async {
    final locale = ValueNotifier(const Locale('tr'));
    addTearDown(locale.dispose);
    final tr = await AppLocalizations.delegate.load(const Locale('tr'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(_app(locale, LoginScreen(onLoginSuccess: (_) {})));
    await tester.ensureVisible(find.text(tr.loginBtn));
    await tester.tap(find.text(tr.loginBtn));
    await tester.pumpAndSettle();
    expect(find.text(tr.errFillFields), findsOneWidget);
    locale.value = const Locale('en');
    await tester.pumpAndSettle();
    final updated = find.text(en.errFillFields).evaluate().length;
    final stale = find.text(tr.errFillFields).evaluate().length;
    await tester.pumpWidget(const SizedBox.shrink());
    expect(updated, 1);
    expect(stale, 0);
  });

  testWidgets(
    'recovery network error follows a locale switch without retrying',
    (tester) async {
      final locale = ValueNotifier(const Locale('tr'));
      addTearDown(locale.dispose);
      final tr = await AppLocalizations.delegate.load(const Locale('tr'));
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      var requests = 0;
      await tester.pumpWidget(
        _app(
          locale,
          ForgotPasswordScreen(
            initialEmail: 'person@example.com',
            localTestEnvironment: false,
            sendResetEmail: (_) async {
              requests++;
              throw const AuthFailure(AuthErrorCode.network);
            },
          ),
        ),
      );
      await tester.tap(find.text(tr.sendPasswordResetEmail));
      await tester.pumpAndSettle();
      expect(find.text(tr.authErrNetwork), findsOneWidget);
      locale.value = const Locale('en');
      await tester.pumpAndSettle();
      final updated = find.text(en.authErrNetwork).evaluate().length;
      final stale = find.text(tr.authErrNetwork).evaluate().length;
      await tester.pumpWidget(const SizedBox.shrink());
      expect(updated, 1);
      expect(stale, 0);
      expect(requests, 1);
    },
  );

  testWidgets(
    'friend action response error follows an open dialog locale switch',
    (tester) async {
      final locale = ValueNotifier(const Locale('tr'));
      addTearDown(locale.dispose);
      final tr = await AppLocalizations.delegate.load(const Locale('tr'));
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.pumpWidget(
        _app(
          locale,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => confirmFriendAction(
                  context,
                  title: 'Action',
                  body: 'Account',
                  operation: () async => {
                    'success': false,
                    'code': 'rate_limited',
                  },
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.friendActionConfirm));
      await tester.pumpAndSettle();
      expect(find.text(tr.friendsErrRateLimited), findsOneWidget);
      locale.value = const Locale('en');
      await tester.pumpAndSettle();
      final updated = find.text(en.friendsErrRateLimited).evaluate().length;
      final stale = find.text(tr.friendsErrRateLimited).evaluate().length;
      await tester.pumpWidget(const SizedBox.shrink());
      expect(updated, 1);
      expect(stale, 0);
    },
  );
}
