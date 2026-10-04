import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/services/lock_screen_timer.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/utils/app_info.dart';
import 'package:pomodoro/utils/user_report.dart';
import 'package:pomodoro/widgets/game_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_lock_screen_platform.dart';
import 'support/fake_notification_permissions.dart';

// Profil > Tercihler ve Yardım: bildirim anahtarı "tercih açık VE izin var"ı
// gösterir, hiç sorulmamış izinde sistem penceresini açar, reddedilmiş
// izinde ayarları açan yolu sunar ve ayarlardan dönünce kendini günceller
// (UX-07); görünürlük metni kapsamı doğru anlatır (KVKK-01), destek
// e-postası ve sürüm (UX-17), "Nasıl çalışır?" (UX-21).

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('tr'),
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

const _asked = 'notification_permission_asked';
const _enabled = 'notifications_enabled';

void main() {
  final notifications = NotificationService.instance;
  late FakeNotificationPermissions permissions;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'PomoSprint',
      packageName: 'com.pomosprint.app',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
    permissions = FakeNotificationPermissions();
    notifications.debugPermissionPlatform = permissions;
  });

  tearDown(() {
    notifications.debugPermissionPlatform = null;
    notifications.debugInitializePlugin = null;
    notifications.debugResetInitialization();
  });

  group('UX-07 bildirim izni: kurallar', () {
    test('anahtar "tercih açık VE izin var"ı gösterir', () {
      bool on(bool preference, NotificationPermissionStatus permission) =>
          NotificationService.effectiveEnabled(preference: preference, permission: permission);
      bool blocked(bool preference, NotificationPermissionStatus permission) =>
          NotificationService.isBlockedBySystem(preference: preference, permission: permission);

      expect(on(true, NotificationPermissionStatus.granted), isTrue);
      expect(on(true, NotificationPermissionStatus.denied), isFalse);
      expect(on(false, NotificationPermissionStatus.granted), isFalse);
      // Hiç sorulmamış izin "yok"tur: anahtar kapalı ama engel değil.
      expect(on(true, NotificationPermissionStatus.notDetermined), isFalse);
      expect(blocked(true, NotificationPermissionStatus.notDetermined), isFalse);
      // İzin okunamıyorsa (desteklenmeyen platform) tercih gösterilir.
      expect(on(true, NotificationPermissionStatus.unknown), isTrue);
      expect(blocked(true, NotificationPermissionStatus.unknown), isFalse);

      expect(blocked(true, NotificationPermissionStatus.denied), isTrue);
      expect(blocked(false, NotificationPermissionStatus.denied), isFalse);
    });

    test('iOS "izin yok" yanıtı: hiç sorulmadıysa notDetermined, sorulduysa denied', () async {
      expect(await notifications.permissionStatus(), NotificationPermissionStatus.notDetermined);
      SharedPreferences.setMockInitialValues({_asked: true});
      expect(await notifications.permissionStatus(), NotificationPermissionStatus.denied);
      permissions.granted = true;
      expect(await notifications.permissionStatus(), NotificationPermissionStatus.granted);
      permissions.granted = null;
      expect(await notifications.permissionStatus(), NotificationPermissionStatus.unknown);
    });

    test('ilk BAŞLAT izni bir kez sorar; anahtardan açmak (force) yeniden sorar', () async {
      permissions.grantOnRequest = false;
      expect(await notifications.ensurePermission(), isFalse);
      expect(permissions.dialogs, 1);
      expect(await notifications.ensurePermission(), isFalse);
      expect(permissions.requests, 1, reason: 'BAŞLAT her seferinde sormaz');
      expect(await notifications.ensurePermission(force: true), isFalse);
      expect(permissions.requests, 2);
      expect(permissions.dialogs, 1, reason: 'reddedilmiş izinde sistem penceresi çıkmaz');
      // Tercih kapalıysa hiç sorulmaz.
      SharedPreferences.setMockInitialValues({_enabled: false});
      expect(await notifications.ensurePermission(force: true), isFalse);
      expect(permissions.requests, 2);
    });

    test('izin okunamaz ya da istek hata verirse "soruldu" yazılmaz (görülmemiş pencere reddedildi sayılmaz)',
        () async {
      permissions.granted = null;
      expect(await notifications.ensurePermission(force: true), isFalse);
      expect(permissions.requests, 0);

      permissions.granted = false;
      permissions.requestError = StateError('izin isteği sürüyor');
      expect(await notifications.ensurePermission(force: true), isFalse);
      expect(await notifications.permissionStatus(), NotificationPermissionStatus.notDetermined);

      permissions.requestError = null;
      expect(await notifications.ensurePermission(), isTrue, reason: 'pencere bir sonraki BAŞLAT\'ta çıkar');
      expect(permissions.dialogs, 1);
    });

    test('setEnabled sonucu döndürür; kapatınca kilit ekranı sayacına haber verir', () async {
      final revision = notifications.preferenceRevision.value;
      expect(await notifications.setEnabled(true), isTrue, reason: 'pencerede izin verildi');
      expect(await notifications.setEnabled(false), isFalse);
      expect(notifications.preferenceRevision.value, revision + 2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(_enabled), isFalse);
    });

    test('kilit ekranı sayacı tercihe uyar (iOS Canlı Etkinlik bildirim izni istemez); kapatınca kaldırılır',
        () async {
      final platform = FakeLockScreenPlatform();
      final timer = LockScreenTimer(platform: platform);
      final session = ActiveTimerSession.start(
        clientUuid: 'seans-1',
        categoryId: 'cat-1',
        categoryName: 'Matematik',
        durationMinutes: 25,
        totalSeconds: 25 * 60,
        now: DateTime.now(),
      );

      // Tercih açık, bildirim izni reddedilmiş: Canlı Etkinlik yine gösterilir
      // (Android'de kalıcı bildirimi sistem zaten göstermez).
      SharedPreferences.setMockInitialValues({_asked: true});
      await timer.showRunning(session);
      expect(platform.shown, hasLength(1));

      // Anahtar kapatılınca (preferenceRevision → refresh) kaldırılır.
      await notifications.setEnabled(false);
      await timer.refresh();
      expect(platform.calls.last, 'clear');

      // Yeniden açılınca (izin verilsin ya da verilmesin) geri gelir.
      await notifications.setEnabled(true);
      await timer.refresh();
      expect(platform.shown, hasLength(2));
    });

    test('eklenti başlatması bir kez hata verirse sonraki çağrı yeniden dener', () async {
      notifications.debugResetInitialization();
      var attempts = 0;
      notifications.debugInitializePlugin = () async {
        attempts++;
        if (attempts == 1) throw StateError('geçici');
      };
      await expectLater(notifications.initialize(), throwsStateError);
      await notifications.initialize();
      await notifications.initialize();
      expect(attempts, 2, reason: 'başarılı başlatma saklanır, hata saklanmaz');
    });
  });

  group('UX-07 bildirim anahtarı (Profil)', () {
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

    AppLocalizations l10nOf(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(ProfileScreen)))!;

    Future<void> toggle(WidgetTester tester) async {
      await tester.tap(find.text('Bildirimler ve kilit ekranı sayacı'));
      await tester.pumpAndSettle();
    }

    void resume(WidgetTester tester) {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }

    testWidgets('hiç sorulmamış izin: anahtar kapalı, uyarı yok; açınca sistem penceresi, izin verilince açık',
        (tester) async {
      await pumpProfile(tester);
      final l10n = l10nOf(tester);
      expect(notificationSwitch(tester).value, isFalse, reason: 'izin yok');
      expect(find.text(l10n.profileNotificationsLabelSub), findsOneWidget);
      expect(find.text(l10n.profileOpenSettings), findsNothing,
          reason: 'sorulmamış izin için ayarlar sayfasında iOS\'ta Bildirimler satırı bile yok');

      await toggle(tester);
      expect(permissions.dialogs, 1, reason: 'sistem izin penceresi çıktı');
      expect(notificationSwitch(tester).value, isTrue);
      expect(find.text(l10n.profileNotificationsDenied), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(_enabled), isTrue);
    });

    testWidgets('pencerede reddedilirse kapalı + "Ayarları aç"; ayarlardan izin verip dönünce kendiliğinden açılır',
        (tester) async {
      permissions.grantOnRequest = false;
      await pumpProfile(tester);
      final l10n = l10nOf(tester);

      await toggle(tester);
      expect(permissions.dialogs, 1);
      expect(notificationSwitch(tester).value, isFalse);
      expect(find.text(l10n.profileNotificationsDenied), findsOneWidget, reason: 'SnackBar');
      expect(find.text(l10n.profileNotificationsBlockedSub), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(_enabled), isTrue, reason: 'kullanıcının isteği korunur; anahtarı izin belirler');

      // SnackBar'daki ve karttaki "Ayarları aç" ayarları açar.
      await tester.tap(find.widgetWithText(SnackBarAction, l10n.profileOpenSettings));
      await tester.pumpAndSettle();
      expect(permissions.settingsOpened, 1);
      await tester.tap(find.widgetWithText(TextButton, l10n.profileOpenSettings));
      await tester.pumpAndSettle();
      expect(permissions.settingsOpened, 2);

      // Ayarlardan izin verilip uygulamaya dönülür: yeniden dokunmadan açık.
      permissions.changeInSettings(allow: true);
      resume(tester);
      await tester.pumpAndSettle();
      expect(notificationSwitch(tester).value, isTrue);
      expect(find.text(l10n.profileNotificationsBlockedSub), findsNothing);
      expect(find.widgetWithText(TextButton, l10n.profileOpenSettings), findsNothing);
    });

    testWidgets('daha önce reddedilmiş izin: pencere çıkmaz, "Ayarları aç" yolu gösterilir', (tester) async {
      SharedPreferences.setMockInitialValues({_asked: true});
      permissions.systemDenied = true;
      await pumpProfile(tester);
      final l10n = l10nOf(tester);
      expect(notificationSwitch(tester).value, isFalse, reason: 'tercih açık ama izin yok');
      expect(find.text(l10n.profileNotificationsBlockedSub), findsOneWidget);

      await toggle(tester);
      expect(permissions.requests, 1);
      expect(permissions.dialogs, 0);
      expect(notificationSwitch(tester).value, isFalse);
      expect(find.widgetWithText(SnackBarAction, l10n.profileOpenSettings), findsOneWidget);
    });

    testWidgets('açıkken kapatınca tercih kapanır; izin olsa da anahtar kapalı, uyarı yok', (tester) async {
      permissions.granted = true;
      await pumpProfile(tester);
      final l10n = l10nOf(tester);
      expect(notificationSwitch(tester).value, isTrue);

      final revision = notifications.preferenceRevision.value;
      await toggle(tester);
      expect(notificationSwitch(tester).value, isFalse);
      expect(notifications.preferenceRevision.value, revision + 1, reason: 'kilit ekranı sayacı kaldırılır');
      expect(find.text(l10n.profileOpenSettings), findsNothing, reason: 'kullanıcı kendisi kapattı');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(_enabled), isFalse);

      // Ayarlardan dönüş kullanıcının kapattığı anahtarı açmaz.
      resume(tester);
      await tester.pumpAndSettle();
      expect(notificationSwitch(tester).value, isFalse);
    });

    testWidgets('izin varsa anahtar açık, kapalı tercih kapalı görünür', (tester) async {
      permissions.granted = true;
      SharedPreferences.setMockInitialValues({_enabled: false});
      await pumpProfile(tester);
      final l10n = l10nOf(tester);
      expect(notificationSwitch(tester).value, isFalse);
      expect(find.text(l10n.profileOpenSettings), findsNothing, reason: 'kullanıcı kendisi kapattı');
    });

    testWidgets('KVKK-01: görünürlük metni kapsamı söyler; UX-17/21: yardım bölümü', (tester) async {
      permissions.granted = true;
      await pumpProfile(tester);
      final l10n = l10nOf(tester);

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
