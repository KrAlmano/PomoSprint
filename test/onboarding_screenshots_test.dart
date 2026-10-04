import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/screens/post_auth_onboarding_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:pomodoro/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Onboarding'in hedef (segment) ve kategori adımlarının gerçek yazı tipiyle
// (Roboto + Material Icons, Flutter SDK'sından) çizilmiş PNG'lerini
// analiz/ekranlar/ altına üretir: hedef listesi (KPSS ve dil sınavı dahil,
// YKS seçili) ve YKS seçiliyken otomatik seçili gelen kategoriler. Boyut
// iPhone 16 Pro Max (440x956): yedi hedefin hepsi tek ekranda görünür.
// Normal `flutter test` koşusunda ATLANIR ve dosya yazmaz.
// Üretmek için:
//
//   flutter test test/onboarding_screenshots_test.dart --dart-define=SCREENSHOTS=true
//
// Not: test ortamında Supabase kapalıdır; ekranlar yalnızca istemci
// durumunu gösterir. Emoji, cihazdaki gibi sistem yedek yazı tipiyle
// (macOS'ta Apple Color Emoji) çizilir; yazı tipi yoksa emoji kutu görünür.
// (Flutter SDK'daki NotoColorEmoji.ttf CBDT biçiminde; test motoru çizmiyor.)

const bool _enabled = bool.fromEnvironment('SCREENSHOTS');
const String _outDir = 'analiz/ekranlar';
const String _emojiFamily = 'AppleColorEmoji';
const String _emojiFontPath = '/System/Library/Fonts/Apple Color Emoji.ttc';

String _flutterRoot() {
  final fromEnv = Platform.environment['FLUTTER_ROOT'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
  // flutter_tester: <flutter>/bin/cache/artifacts/engine/<platform>/flutter_tester
  final exe = Platform.resolvedExecutable;
  final index = exe.indexOf('${Platform.pathSeparator}bin${Platform.pathSeparator}cache');
  return index > 0 ? exe.substring(0, index) : '';
}

Future<void> _loadFonts() async {
  final root = _flutterRoot();
  final fonts = '$root/bin/cache/artifacts/material_fonts';
  Future<ByteData> read(String path) async => ByteData.view((await File(path).readAsBytes()).buffer);
  final roboto = FontLoader('Roboto');
  for (final file in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Italic.ttf']) {
    roboto.addFont(read('$fonts/$file'));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(read('$fonts/MaterialIcons-Regular.otf'))).load();
  if (File(_emojiFontPath).existsSync()) await (FontLoader(_emojiFamily)..addFont(read(_emojiFontPath))).load();
}

final _boundaryKey = GlobalKey();

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
  final service = SupabaseService.instance;

  setUpAll(() async {
    // Tekil servisler (AsyncLock zincirleri) gerçek zone'da kurulmalı.
    expect(service, isNotNull);
    expect(TimerPersistence.instance, isNotNull);
    if (_enabled) await _loadFonts();
  });

  testWidgets('onboarding · hedef (YKS seçili) ve otomatik seçili kategoriler · 440x956', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => LanguageService.instance.setLanguage(AppLanguage.tr));
    service.currentUser.value = UserModel(id: 'uid-shot', name: 'Ayşe', email: 'ayse@ornek.com');
    addTearDown(() => service.currentUser.value = null);
    debugDisableShadows = false;

    const size = Size(440, 956);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    ThemeData withEmoji(ThemeData theme) =>
        theme.copyWith(textTheme: theme.textTheme.apply(fontFamilyFallback: const [_emojiFamily]));
    await tester.pumpWidget(RepaintBoundary(
      key: _boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('tr'),
        theme: withEmoji(AppTheme.lightTheme),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PostAuthOnboardingScreen(onCompleted: () {}),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(PostAuthOnboardingScreen)))!;

    Future<void> precacheImages() async {
      // Maskot görseli test ortamında eşzamansız çözülür.
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pumpAndSettle();
    }

    await tester.drag(find.byType(CupertinoPicker), const Offset(0, -1040));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.continueBtn));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.onboardingSegmentYks));
    await tester.pumpAndSettle();
    await precacheImages();
    await _capture(tester, 'onboarding-hedef.png');

    await tester.tap(find.text(l10n.continueBtn));
    await tester.pumpAndSettle();
    await precacheImages();
    expect(find.text(l10n.onboardingCategoryStepPreparedTitle), findsOneWidget);
    await _capture(tester, 'onboarding-kategoriler.png');
    // Test çerçevesi gövde bitince denetler (tearDown'dan önce).
    debugDisableShadows = true;
  }, skip: !_enabled);
}
