import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/login_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/widgets/auth/language_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

// AS-06: ilk açılışta dil cihazdan gelir (tr değilse en), uygulamada seçilen
// dil saklanır; cihaz dili / uygulama başına dil ayarı sonradan değişirse en
// son değişiklik geçerli olur. Giriş ekranında dil seçici var.

const _prefKey = 'app_language_code';
const _deviceKey = 'app_language_device_code';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final lang = LanguageService.instance;
  final originalDeviceLocale = LanguageService.deviceLocale;
  var device = const Locale('tr');

  setUp(() {
    LanguageService.deviceLocale = () => device;
  });

  tearDown(() async {
    LanguageService.deviceLocale = originalDeviceLocale;
    SharedPreferences.setMockInitialValues({});
    device = const Locale('tr');
    await lang.init();
  });

  test('cihaz dili eşlemesi: yalnızca Türkçe tr, diğer her dil en', () {
    expect(LanguageService.languageForLocale(const Locale('tr', 'TR')), AppLanguage.tr);
    expect(LanguageService.languageForLocale(const Locale('en', 'US')), AppLanguage.en);
    expect(LanguageService.languageForLocale(const Locale('de')), AppLanguage.en);
    expect(LanguageService.languageForLocale(null), AppLanguage.en);
  });

  test('kayıtlı seçim yoksa ilk açılışta cihaz dili kullanılır', () async {
    SharedPreferences.setMockInitialValues({});
    device = const Locale('de', 'DE');
    await lang.init();
    expect(lang.currentLanguage, AppLanguage.en);

    device = const Locale('tr', 'TR');
    await lang.init();
    expect(lang.currentLanguage, AppLanguage.tr);
  });

  test('uygulamada seçilen dil cihaz değişmedikçe korunur', () async {
    SharedPreferences.setMockInitialValues({});
    device = const Locale('tr');
    await lang.init();
    await lang.setLanguage(AppLanguage.en);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_prefKey), 'en');
    expect(prefs.getString(_deviceKey), 'tr');

    await lang.init(); // yeniden açılış, cihaz aynı
    expect(lang.currentLanguage, AppLanguage.en);
  });

  test('seçimden sonra cihaz dili (uygulama başına dil) değişirse cihaz izlenir', () async {
    SharedPreferences.setMockInitialValues({_prefKey: 'en', _deviceKey: 'tr'});
    device = const Locale('en'); // iOS Ayarlar > PomoSprint > Dil: English
    await lang.init();
    expect(lang.currentLanguage, AppLanguage.en);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_prefKey), isNull, reason: 'eski seçim silinir, cihaz izlenir');

    device = const Locale('tr');
    await lang.init();
    expect(lang.currentLanguage, AppLanguage.tr);
  });

  test('önceki sürümde Profil\'den seçilen dil korunur', () async {
    SharedPreferences.setMockInitialValues({_prefKey: 'en'});
    device = const Locale('tr');
    await lang.init();
    expect(lang.currentLanguage, AppLanguage.en);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_deviceKey), 'tr');
  });

  test('cihazın diliyle aynı seçim ayrıca saklanmaz', () async {
    SharedPreferences.setMockInitialValues({_prefKey: 'en', _deviceKey: 'tr'});
    device = const Locale('tr');
    await lang.init();
    expect(lang.currentLanguage, AppLanguage.en);
    await lang.setLanguage(AppLanguage.tr);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(_prefKey), isNull);
    expect(prefs.getString(_deviceKey), isNull);
  });

  test('uygulama açıkken cihaz dili değişince arayüz dili güncellenir', () async {
    SharedPreferences.setMockInitialValues({});
    device = const Locale('tr');
    await lang.init();
    var notified = 0;
    void listener() => notified++;
    lang.addListener(listener);
    addTearDown(() => lang.removeListener(listener));

    lang.didChangeLocales(const [Locale('en', 'GB')]);
    await pumpEventQueue();
    expect(lang.currentLanguage, AppLanguage.en);
    expect(notified, greaterThan(0));
  });

  testWidgets('giriş ekranında dil seçici var ve seçim uygulanır', (tester) async {
    SharedPreferences.setMockInitialValues({});
    device = const Locale('tr');
    await lang.init();
    await tester.pumpWidget(ListenableBuilder(
      listenable: lang,
      builder: (context, _) => MaterialApp(
        locale: lang.currentLocale,
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginScreen(onLoginSuccess: (_) {}),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(LanguageSwitcher), findsOneWidget);
    expect(find.text('Şifremi Unuttum'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(lang.currentLanguage, AppLanguage.en);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('App language')), findsOneWidget);
  });
}
