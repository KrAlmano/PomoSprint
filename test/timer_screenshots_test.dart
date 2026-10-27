import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/avatar_model.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/widgets/avatar_widget.dart';
import 'package:pomodoro/widgets/shell_app_bar.dart';
import 'package:pomodoro/widgets/shell_navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Sayaç ekranının kabuk içinde (üst çubuk + gezinme, gerçek iPhone güvenli
// alanlarıyla), gerçek yazı tipiyle (Roboto + Material Icons, Flutter
// SDK'sından) çizilmiş PNG'lerini analiz/ekranlar/ altına üretir.
// Normal `flutter test` koşusunda ATLANIR ve dosya yazmaz. Üretmek için:
//
//   flutter test test/timer_screenshots_test.dart --dart-define=SCREENSHOTS=true
//
// (TimerPersistence tekil olduğu için dosyada tek testWidgets var; bkz.
// timer_screen_test.dart.)

const bool _enabled = bool.fromEnvironment('SCREENSHOTS');
const String _outDir = 'analiz/ekranlar';
const double _pixelRatio = 2;

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

const _destinations = [
  ShellDestination(icon: Icons.timer_outlined, selectedIcon: Icons.timer, label: 'Pomo'),
  ShellDestination(icon: Icons.analytics_outlined, selectedIcon: Icons.analytics, label: 'Raporlar'),
  ShellDestination(icon: Icons.leaderboard_outlined, selectedIcon: Icons.leaderboard, label: 'Sıralama'),
  ShellDestination(icon: Icons.groups_outlined, selectedIcon: Icons.groups, label: 'Sosyal'),
];

final _boundaryKey = GlobalKey();

void main() {
  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });

  testWidgets('sayaç · iPhone 16 Pro, iPhone SE, yatay', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await LanguageService.instance.setLanguage(AppLanguage.tr);
    debugDisableShadows = false;
    final categories = CourseCategory.initialCategories();

    Future<void> capture(String fileName, Size size, EdgeInsets safeArea) async {
      tester.view.physicalSize = size * _pixelRatio;
      tester.view.devicePixelRatio = _pixelRatio;
      final padding = FakeViewPadding(
        left: safeArea.left * _pixelRatio,
        top: safeArea.top * _pixelRatio,
        right: safeArea.right * _pixelRatio,
        bottom: safeArea.bottom * _pixelRatio,
      );
      tester.view.padding = padding;
      tester.view.viewPadding = padding;
      await tester.pumpWidget(RepaintBoundary(
        key: _boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('tr'),
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => ShellNavigationScaffold(
              showNavigation: MediaQuery.orientationOf(context) != Orientation.landscape,
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: _destinations,
              appBar: MediaQuery.orientationOf(context) == Orientation.landscape ? null : buildShellAppBar(
                context,
                streakDays: 7,
                points: 1240,
                coins: 85,
                onStatsTap: () {},
                onFriendsTap: () {},
                onProfileTap: () {},
                avatarBuilder: (s) => AvatarWidget(avatar: AvatarCharacter.byId(null), size: s),
              ),
              body: TimerScreen(
                key: UniqueKey(),
                categories: categories,
                sessionOwnerKey: 'screenshot-owner',
                onOpenSettings: () {},
                onSessionCompleted: (_) async => null,
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      // Kum saati (Lottie) ve avatar görselleri eşzamansız yüklenir.
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: fileName);
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundaryKey));
        final image = await boundary.toImage(pixelRatio: _pixelRatio);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory(_outDir).createSync(recursive: true);
        File('$_outDir/$fileName').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    await capture('sayac-iphone16pro.png', const Size(402, 874), const EdgeInsets.only(top: 62, bottom: 34));
    await capture('sayac-iphonese.png', const Size(375, 667), const EdgeInsets.only(top: 20));
    await capture('sayac-yatay.png', const Size(874, 402), const EdgeInsets.only(left: 62, right: 62, bottom: 21));
    debugDisableShadows = true;
    tester.view.reset();
  }, skip: !_enabled);
}
