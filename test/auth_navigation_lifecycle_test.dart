import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/app/app_gate.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/screens/login_screen.dart';
import 'package:pomodoro/screens/post_auth_onboarding_screen.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

UserModel user(String id) =>
    UserModel(id: id, name: 'Deneme', email: '$id@example.com');

void main() {
  final service = SupabaseService.instance;
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => service.currentUser.value = null);

  Future<GlobalKey<NavigatorState>> pumpGate(WidgetTester tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AppGate(initialCategories: []),
      ),
    );
    await tester.pumpAndSettle();
    return navigator;
  }

  testWidgets('uzaktan çıkış üstteki özel ekranı kapatır ve girişe döner', (
    tester,
  ) async {
    service.currentUser.value = user('a');
    final navigator = await pumpGate(tester);
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('eski hesabın özel ekranı')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('eski hesabın özel ekranı'), findsOneWidget);

    service.currentUser.value = null;
    await tester.pumpAndSettle();
    expect(find.text('eski hesabın özel ekranı'), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(navigator.currentState!.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aynı hesabın profil yenilemesi açık ekranı kapatmaz', (
    tester,
  ) async {
    service.currentUser.value = user('a');
    final navigator = await pumpGate(tester);
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('profil açık')),
      ),
    );
    await tester.pumpAndSettle();
    service.currentUser.value = user('a').copyWith(name: 'Güncel');
    await tester.pumpAndSettle();
    expect(find.text('profil açık'), findsOneWidget);
    expect(navigator.currentState!.canPop(), isTrue);
  });

  testWidgets(
    'hesap değişiminde onboarding durumu yeniden kurulur; son hesap korunur',
    (tester) async {
      service.currentUser.value = user('a');
      final navigator = await pumpGate(tester);
      final oldState = tester.state(find.byType(PostAuthOnboardingScreen));
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('eski hesap sheet')),
        ),
      );
      await tester.pumpAndSettle();
      service.currentUser.value = null;
      service.currentUser.value = user('b');
      service.currentUser.value = user('c');
      await tester.pumpAndSettle();
      expect(find.text('eski hesap sheet'), findsNothing);
      expect(
        tester.state(find.byType(PostAuthOnboardingScreen)),
        isNot(same(oldState)),
      );
      expect(
        tester
            .widget<PostAuthOnboardingScreen>(
              find.byType(PostAuthOnboardingScreen),
            )
            .key,
        const ValueKey<String?>('c'),
      );
      expect(navigator.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
