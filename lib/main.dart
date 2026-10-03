import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app/app_gate.dart';
import 'app/error_reporting.dart';
import 'app/theme_controller.dart';
import 'l10n/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'services/language_service.dart';
import 'services/notification_service.dart';
import 'theme.dart';
import 'widgets/snackbar_width_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env burada erkenden yükleniyor ki Sentry DSN'ine erişebilelim;
  // SupabaseService.initialize() aynı dosyayı kendi ihtiyacı için tekrar
  // yükler, bu zararsızdır. DSN boşsa Sentry SDK kendini otomatik devre
  // dışı bırakır — .env'de SENTRY_DSN olmaması uygulamayı bozmaz.
  String sentryDsn = '';
  try {
    await dotenv.load(fileName: ".env");
    sentryDsn = dotenv.env['SENTRY_DSN'] ?? '';
  } catch (_) {
    // .env okunamazsa (ör. asset eksik) Sentry'siz devam et.
  }

  await SentryFlutter.init(
    (options) => configureSentry(options, dsn: sentryDsn),
    appRunner: _startApp,
  );
}

// Sentry'den SONRA çalışır: başlatma hataları raporlanır ve uygulamanın
// açılmasını engellemez.
Future<void> _startApp() async {
  await _guardedInit('language', LanguageService.instance.init);
  await _guardedInit('theme', ThemeController.instance.init);
  // Bildirim eklentisi izin istemeden ve runApp'i bekletmeden başlar.
  unawaited(_guardedInit('notifications', NotificationService.instance.initialize));
  runApp(const PomodoroApp());
}

Future<void> _guardedInit(String name, Future<void> Function() init) async {
  try {
    await init();
  } catch (e, st) {
    debugPrint('[INIT] $name başlatılamadı: $e');
    await Sentry.captureException(e, stackTrace: st);
  }
}

class PomodoroApp extends StatelessWidget {
  const PomodoroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([LanguageService.instance, ThemeController.instance]),
      builder: (context, _) {
        return MaterialApp(
          title: 'PomoSprint - Pomodoro',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.instance.value,
          locale: LanguageService.instance.currentLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Tablette ve yatay telefonda SnackBar'lar tam genişliğe yayılmaz.
          builder: (context, child) => SnackBarWidthScope(child: child!),
          // Splash yalnızca bir kez çalışır (Supabase.initialize tek sefer);
          // giriş, onboarding ve çıkış yönlendirmelerinin tamamı AppGate'te.
          home: SplashScreen(
            onNavigate: (categories) => AppGate(initialCategories: categories),
          ),
        );
      },
    );
  }
}
