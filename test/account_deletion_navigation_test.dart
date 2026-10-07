import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pomodoro/app/app_gate.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/screens/login_screen.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_notification_permissions.dart';
import 'support/fake_supabase_service.dart';

class _DeleteService extends FakeSupabaseService {
  final gate = Completer<void>();
  int deletes = 0;
  @override
  bool get canChangePassword => false;
  @override
  bool get canReauthorizeWithApple => false;
  @override
  Future<bool> getSocialVisibility() async => true;
  @override
  Future<int> getPendingSessionCount() async => 0;
  @override
  Future<AppleRevocation> deleteUserAccount({
    String? appleAuthorizationCode,
  }) async {
    deletes++;
    currentUser.value = null;
    SupabaseService.instance.currentUser.value = null;
    await gate.future;
    return AppleRevocation.notApplicable;
  }
}

void main() {
  final owner = SupabaseService.instance;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'PomoSprint',
      packageName: 'com.pomosprint.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    NotificationService.instance.debugPermissionPlatform =
        FakeNotificationPermissions();
  });
  tearDown(() {
    owner.currentUser.value = null;
    NotificationService.instance.debugPermissionPlatform = null;
  });

  testWidgets(
    'silme oturumu kapatınca AppGate ilerleme ve profili yalnızca bir kez kapatır',
    (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      owner.currentUser.value = UserModel(
        id: 'delete-me',
        name: 'Silinecek',
        email: 'delete@example.com',
      );
      final service = _DeleteService();
      final navigator = GlobalKey<NavigatorState>();
      var exits = 0;
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
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => ProfileScreen(
            service: service,
            onDarkModeChanged: (_) {},
            onLogout: () => exits++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      await tester.tap(find.text(l10n.deleteAccount));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, l10n.deleteAccount));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ProfileScreen), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      service.gate.complete();
      await tester.pumpAndSettle();
      expect(service.deletes, 1);
      expect(
        exits,
        0,
        reason:
            'servis çıkışı tamamladı; eski profile tekrar yönlendirme yaptırılmaz',
      );
      expect(navigator.currentState!.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
