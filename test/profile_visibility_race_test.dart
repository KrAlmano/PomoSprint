import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_notification_permissions.dart';
import 'support/fake_supabase_service.dart';

class _ProfileService extends FakeSupabaseService {
  final read = Completer<bool>();
  Completer<void>? save;
  final values = <bool>[];

  @override
  bool get canChangePassword => false;
  @override
  Future<bool> getSocialVisibility() => read.future;
  @override
  Future<void> setSocialVisibility(bool value) async {
    values.add(value);
    await save?.future;
  }
}

void main() {
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
  tearDown(() => NotificationService.instance.debugPermissionPlatform = null);

  Future<void> pump(WidgetTester tester, _ProfileService service) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ProfileScreen(
          service: service,
          onDarkModeChanged: (_) {},
          onLogout: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  SwitchListTile visibility(WidgetTester tester) {
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ProfileScreen)),
    )!;
    return tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text(l10n.profileSocialVisibilityTitle),
        matching: find.byType(SwitchListTile),
      ),
    );
  }

  testWidgets(
    'ilk okuma ve kayıt sürerken görünürlük ikinci kez değiştirilemez',
    (tester) async {
      final service = _ProfileService();
      await pump(tester, service);
      expect(visibility(tester).onChanged, isNull);
      service.read.complete(false);
      await tester.pumpAndSettle();
      expect(visibility(tester).value, isFalse);
      final originalCallback = visibility(tester).onChanged!;
      service.save = Completer<void>();
      originalCallback(true);
      await tester.pump();
      expect(visibility(tester).value, isTrue);
      expect(visibility(tester).onChanged, isNull);
      // Yeniden build edilmeden eldeki eski callback de ikinci isteği açamaz.
      originalCallback(false);
      await tester.pump();
      expect(service.values, [true]);
      service.save!.complete();
      await tester.pumpAndSettle();
      expect(visibility(tester).onChanged, isNotNull);
      expect(visibility(tester).value, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'kayıt hatasında önceki görünürlük korunur ve tekrar denenebilir',
    (tester) async {
      final service = _ProfileService();
      service.read.complete(false);
      await pump(tester, service);
      service.save = Completer<void>();
      visibility(tester).onChanged!(true);
      await tester.pump();
      service.save!.completeError(
        const ServiceException(ServiceErrorCode.network),
      );
      await tester.pumpAndSettle();
      expect(visibility(tester).value, isFalse);
      expect(visibility(tester).onChanged, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}
