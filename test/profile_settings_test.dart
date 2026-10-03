import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/utils/app_info.dart';
import 'package:pomodoro/utils/user_report.dart';
import 'package:pomodoro/widgets/game_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Profil > Tercihler ve Yardım: bildirim anahtarı sistem iznini gösterir ve
// ayarları açan yol sunar (UX-07), görünürlük metni kapsamı doğru anlatır
// (KVKK-01), destek e-postası ve sürüm (UX-17), "Nasıl çalışır?" (UX-21).

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('tr'),
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  final notifications = NotificationService.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'PomoSprint',
      packageName: 'com.pomosprint.app',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
  });

  tearDown(() {
    notifications.debugSystemPermission = null;
    notifications.debugOpenSystemSettings = null;
  });

  group('UX-07 bildirim izni', () {
    test('anahtar "tercih açık VE izin var"ı gösterir', () {
      expect(NotificationService.effectiveEnabled(preference: true, permission: true), isTrue);
      expect(NotificationService.effectiveEnabled(preference: true, permission: false), isFalse);
      expect(NotificationService.effectiveEnabled(preference: false, permission: true), isFalse);
      // İzin okunamıyorsa (desteklenmeyen platform) tercih gösterilir.
      expect(NotificationService.effectiveEnabled(preference: true, permission: null), isTrue);

      expect(NotificationService.isBlockedBySystem(preference: true, permission: false), isTrue);
      expect(NotificationService.isBlockedBySystem(preference: false, permission: false), isFalse);
      expect(NotificationService.isBlockedBySystem(preference: true, permission: null), isFalse);
    });

    Future<void> pumpProfile(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(ProfileScreen(onDarkModeChanged: (_) {}, onLogout: () {})));
      await tester.pumpAndSettle();
    }

    SwitchListTile notificationSwitch(WidgetTester tester) => tester.widget<SwitchListTile>(
          find.ancestor(of: find.text('Bildirimler ve kilit ekranı sayacı'), matching: find.byType(SwitchListTile)),
        );

    testWidgets('izin reddedildiyse anahtar kapalı ve "Ayarları aç" var', (tester) async {
      var opened = 0;
      notifications.debugSystemPermission = () async => false;
      notifications.debugOpenSystemSettings = () async {
        opened++;
        return true;
      };
      await pumpProfile(tester);
      final l10n = AppLocalizations.of(tester.element(find.byType(ProfileScreen)))!;

      expect(notificationSwitch(tester).value, isFalse, reason: 'tercih açık ama izin yok');
      expect(find.text(l10n.profileNotificationsBlockedSub), findsOneWidget);
      await tester.tap(find.text(l10n.profileOpenSettings));
      await tester.pumpAndSettle();
      expect(opened, 1);

      // Kullanıcı ayarlardan izin verip dönünce anahtar güncellenir.
      notifications.debugSystemPermission = () async => true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(notificationSwitch(tester).value, isTrue);
      expect(find.text(l10n.profileOpenSettings), findsNothing);
      expect(find.text(l10n.profileNotificationsLabelSub), findsOneWidget);
    });

    testWidgets('izin varsa anahtar açık, kapalı tercih kapalı görünür', (tester) async {
      notifications.debugSystemPermission = () async => true;
      SharedPreferences.setMockInitialValues({'notifications_enabled': false});
      await pumpProfile(tester);
      final l10n = AppLocalizations.of(tester.element(find.byType(ProfileScreen)))!;
      expect(notificationSwitch(tester).value, isFalse);
      expect(find.text(l10n.profileOpenSettings), findsNothing, reason: 'kullanıcı kendisi kapattı');
    });

    testWidgets('KVKK-01: görünürlük metni kapsamı söyler; UX-17/21: yardım bölümü', (tester) async {
      notifications.debugSystemPermission = () async => true;
      await pumpProfile(tester);
      final l10n = AppLocalizations.of(tester.element(find.byType(ProfileScreen)))!;

      expect(find.text(l10n.profileSocialVisibilityTitle), findsOneWidget);
      expect(find.text(l10n.profileSocialVisibilitySub), findsOneWidget);
      expect(l10n.profileSocialVisibilitySub, allOf(contains('aylık sıralama'), contains('pomosprint.app'), contains('canlı liste')));

      // Görünür sürüm numarası.
      expect(find.text(l10n.profileAppVersion('1.2.3 (45)')), findsOneWidget);
      expect(find.text(l10n.profileSupportTitle), findsOneWidget);

      // "Nasıl çalışır?" oyun kurallarını açar.
      await tester.tap(find.text(l10n.gameRulesTitle));
      await tester.pumpAndSettle();
      expect(find.byType(GameRulesList), findsOneWidget);
    });
  });

  group('UX-17 destek e-postası', () {
    test('sürüm metni', () {
      expect(formatAppVersion('1.2.3', '45'), '1.2.3 (45)');
      expect(formatAppVersion('1.2.3', ''), '1.2.3');
      expect(formatAppVersion('1.2.3', '1.2.3'), '1.2.3');
    });

    test('sürüm okunur', () async {
      expect(await loadAppVersion(), '1.2.3 (45)');
    });

    test('mailto destek@, gövdede sürüm ve cihaz; kişisel veri yok', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      final uri = supportEmailUri(l10n, version: '1.2.3 (45)', device: 'ios 18.1');
      expect(uri.scheme, 'mailto');
      expect(uri.path, kSupportEmail);
      final decoded = Uri.decodeComponent(uri.query);
      expect(decoded, contains(l10n.supportEmailSubject));
      expect(decoded, contains('1.2.3 (45)'));
      expect(decoded, contains('ios 18.1'));
      expect(uri.query, isNot(contains('+')), reason: 'boşluk %20 olarak kodlanır');

      final unknown = supportEmailUri(l10n, version: null, device: 'android 14');
      expect(Uri.decodeComponent(unknown.query), contains('-'));
    });
  });
}
