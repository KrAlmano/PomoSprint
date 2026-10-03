import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/screens/register_screen.dart';
import 'package:pomodoro/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Kayıt ekranının gerçek yazı tipiyle (Roboto + Material Icons, Flutter
// SDK'sından) çizilmiş PNG'lerini analiz/ekranlar/ altına üretir.
// Normal `flutter test` koşusunda ATLANIR ve dosya yazmaz. Üretmek için:
//
//   flutter test test/register_screenshots_test.dart --dart-define=SCREENSHOTS=true
//
// Not: test ortamında Supabase kapalıdır; ekranlar yalnızca istemci
// durumunu (boş form, satır içi doğrulama) gösterir.

const bool _enabled = bool.fromEnvironment('SCREENSHOTS');
const String _outDir = 'analiz/ekranlar';

String _flutterRoot() {
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  // flutter_tester: <flutter>/bin/cache/artifacts/engine/<platform>/flutter_tester
  final exe = Platform.resolvedExecutable;
  final index = exe.indexOf('${Platform.pathSeparator}bin${Platform.pathSeparator}cache');
  return index > 0 ? exe.substring(0, index) : '';
}

Future<void> _loadFonts() async {
  final fonts = '${_flutterRoot()}/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String name) async => ByteData.view((await File('$fonts/$name').readAsBytes()).buffer);
  final roboto = FontLoader('Roboto');
  for (final file in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Italic.ttf']) {
    roboto.addFont(read(file));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'))).load();
}

final _boundaryKey = GlobalKey();

Future<void> _pump(WidgetTester tester, Size size, {required bool dark}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(
    key: _boundaryKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const RegisterScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  // Avatar görselleri test ortamında eşzamansız çözülür.
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element);
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String fileName) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundaryKey));
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(_outDir).createSync(recursive: true);
    File('$_outDir/$fileName').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('kayıt · telefon 390x844 · açık tema', (tester) async {
    debugDisableShadows = false;
    await _pump(tester, const Size(390, 844), dark: false);
    await tester.enterText(find.byType(TextFormField).at(0), 'Ayşe Yılmaz');
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _capture(tester, 'kayit-telefon-acik.png');
    debugDisableShadows = true;
  }, skip: !_enabled);

  testWidgets('kayıt · telefon 390x844 · koyu tema · eksik onay hataları', (tester) async {
    debugDisableShadows = false;
    await _pump(tester, const Size(390, 844), dark: true);
    final l10n = AppLocalizations.of(tester.element(find.byType(RegisterScreen)))!;
    await tester.enterText(find.byType(TextFormField).at(0), 'Ayşe Yılmaz');
    await tester.enterText(find.byType(TextFormField).at(1), 'ayse@ornek.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'gizli-sifre');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(l10n.registerBtn));
    await tester.tap(find.text(l10n.registerBtn));
    await tester.pumpAndSettle();
    await _capture(tester, 'kayit-telefon-koyu.png');
    debugDisableShadows = true;
  }, skip: !_enabled);

  testWidgets('kayıt · tablet 820x1180 · açık tema', (tester) async {
    debugDisableShadows = false;
    await _pump(tester, const Size(820, 1180), dark: false);
    await _capture(tester, 'kayit-tablet.png');
    debugDisableShadows = true;
  }, skip: !_enabled);
}
