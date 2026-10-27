import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/avatar_model.dart';
import 'package:pomodoro/models/category_model.dart';
import 'package:pomodoro/screens/login_screen.dart';
import 'package:pomodoro/screens/post_auth_onboarding_screen.dart';
import 'package:pomodoro/screens/profile_screen.dart';
import 'package:pomodoro/screens/timer_screen.dart';
import 'package:pomodoro/services/language_service.dart';
import 'package:pomodoro/services/notification_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/widgets/auth/legal_links.dart';
import 'package:pomodoro/widgets/avatar_widget.dart';
import 'package:pomodoro/widgets/hourglass_widget.dart';
import 'package:pomodoro/widgets/shell_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_notification_permissions.dart';

// Erişilebilirlik ve uygulama içi metinler: ekran okuyucu etiketleri ve 48 dp
// dokunma hedefleri (UX-05), koyu temada metin kontrastı (UX-06), ARB'ye
// taşınan metinler (UX-13), Hareketi Azalt (UX-19).

Widget _app(
  Widget home, {
  Locale locale = const Locale('tr'),
  ThemeData? theme,
  bool disableAnimations = false,
}) =>
    MaterialApp(
      locale: locale,
      theme: theme ?? AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: home,
    );

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('UX-05 ekran okuyucu ve dokunma hedefleri', () {
    for (final size in const [Size(390, 844), Size(844, 390)]) {
      testWidgets('üst çubuk: Profil ve Arkadaşlar etiketli düğme, en az 48 dp ($size)', (tester) async {
        final semantics = tester.ensureSemantics();
        _setView(tester, size);
        var profileTaps = 0;
        var friendsTaps = 0;
        await tester.pumpWidget(_app(Builder(
          builder: (context) => Scaffold(
            appBar: buildShellAppBar(
              context,
              streakDays: 3,
              points: 10,
              coins: 20,
              onStatsTap: () {},
              onFriendsTap: () => friendsTaps++,
              onProfileTap: () => profileTaps++,
              avatarBuilder: (size) => AvatarWidget(avatar: AvatarCharacter.byId(null), size: size),
            ),
          ),
        )));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)))!;

        // Hesap silmenin de bulunduğu Profil'e ekran okuyucuyla ulaşılır.
        final profile = find.bySemanticsLabel(l10n.profileTitle);
        expect(tester.getSemantics(profile),
            matchesSemantics(label: l10n.profileTitle, isButton: true, hasTapAction: true));
        final friends = find.bySemanticsLabel(l10n.friendsTitle);
        expect(tester.getSemantics(friends),
            matchesSemantics(label: l10n.friendsTitle, isButton: true, hasTapAction: true));

        // İki kez dokunma (semantik "tap") düğmeyi çalıştırır.
        tester.semantics.tap(find.semantics.byLabel(l10n.profileTitle));
        tester.semantics.tap(find.semantics.byLabel(l10n.friendsTitle));
        expect(profileTaps, 1);
        expect(friendsTaps, 1);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }

    testWidgets('giriş ekranı (koyu tema): dokunma hedefleri, etiketler ve metin kontrastı', (tester) async {
      final semantics = tester.ensureSemantics();
      _setView(tester, const Size(390, 844));
      await tester.pumpWidget(_app(LoginScreen(onLoginSuccess: (_) {}), theme: AppTheme.darkTheme));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(LoginScreen)))!;

      // "Kayıt Ol" yalnızca metin değil, düğme.
      expect(
        tester.getSemantics(find.text(l10n.signUpLink)),
        isSemantics(label: l10n.signUpLink, isButton: true, hasTapAction: true),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      // UX-06: koyu temadaki kırmızı bağlantılar (Şifremi unuttum, Kayıt ol,
      // yasal metinler) ve dil seçici WCAG eşiğini geçer.
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });

    // Tek TimerScreen testi: TimerPersistence tekilinin kilit zinciri onu
    // ilk kullanan testin fake async bölgesine bağlıdır (bkz. timer_screen_test).
    testWidgets('sayaç: 25/50 seçimi ve kalan süre etiketli, yalnızca kategori çipleri', (tester) async {
      final semantics = tester.ensureSemantics();
      // Dikey ekran (yatayda süre çipleri gizlenir).
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(TimerScreen(
        categories: CourseCategory.initialCategories(),
        sessionOwnerKey: 'a11y-owner',
        onOpenSettings: () {},
        onSessionCompleted: (_) async => null,
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final l10n = AppLocalizations.of(tester.element(find.byType(TimerScreen)))!;

      // Süre seçenekleri: seçili durumuyla düğme, ekran okuyucuyla seçilebilir.
      final option25 = find.bySemanticsLabel(l10n.timerDurationOption(25));
      final option50 = find.bySemanticsLabel(l10n.timerDurationOption(50));
      expect(
        tester.getSemantics(option25),
        matchesSemantics(
            label: l10n.timerDurationOption(25), isButton: true, hasSelectedState: true, isSelected: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(option50),
        matchesSemantics(label: l10n.timerDurationOption(50), isButton: true, hasSelectedState: true, hasTapAction: true),
      );
      tester.semantics.tap(find.semantics.byLabel(l10n.timerDurationOption(50)));
      await tester.pump();
      expect(tester.getSemantics(option50),
          matchesSemantics(label: l10n.timerDurationOption(50), isButton: true, hasSelectedState: true, isSelected: true, hasTapAction: true));
      // Çip en az 48 dp yüksekliğinde dokunma alanında.
      expect(tester.getSemantics(option50).rect.height, greaterThanOrEqualTo(kMinInteractiveDimension));

      expect(find.byTooltip(l10n.timerEditCategories), findsNothing);
      expect(find.byType(FilterChip), findsWidgets);

      // Sayaç "X dakika Y saniye kaldı" diye okunur.
      expect(find.bySemanticsLabel(RegExp(r'^\d+ dakika \d+ saniye kaldı$')), findsOneWidget);

      // Sayaçta yalnızca kategoriler var; başlık kaldırıldı.
      expect(find.text(l10n.selectSubject), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      semantics.dispose();
    });
  });

  group('UX-05/UX-06 erişilebilirlik kılavuzları (açık ve koyu tema)', () {
    Future<void> expectGuidelines(WidgetTester tester, String context) async {
      for (final guideline in [androidTapTargetGuideline, labeledTapTargetGuideline, textContrastGuideline]) {
        final result = await guideline.evaluate(tester);
        expect(result.passed, isTrue, reason: '$context: ${guideline.description}\n${result.reason}');
      }
    }

    for (final dark in [false, true]) {
      final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;

      testWidgets('Profil (koyu=$dark)', (tester) async {
        final semantics = tester.ensureSemantics();
        // İzin reddedilmiş: "Ayarları aç" düğmesi de denetlenir.
        SharedPreferences.setMockInitialValues({'notification_permission_asked': true});
        NotificationService.instance.debugPermissionPlatform = FakeNotificationPermissions(systemDenied: true);
        addTearDown(() => NotificationService.instance.debugPermissionPlatform = null);
        tester.view.physicalSize = const Size(400, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_app(ProfileScreen(onDarkModeChanged: (_) {}, onLogout: () {}), theme: theme));
        await tester.pumpAndSettle();
        await expectGuidelines(tester, 'Profil');
        semantics.dispose();
      });

      testWidgets('Onboarding adımları (koyu=$dark)', (tester) async {
        final semantics = tester.ensureSemantics();
        _setView(tester, const Size(390, 844));
        await tester.pumpWidget(_app(PostAuthOnboardingScreen(onCompleted: () {}), theme: theme));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(find.byType(PostAuthOnboardingScreen)))!;
        Future<void> tapAndSettle(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        await expectGuidelines(tester, 'yaş');
        await tester.drag(find.byType(CupertinoPicker), const Offset(0, -1040));
        await tester.pumpAndSettle();
        await tapAndSettle(find.text(l10n.continueBtn));
        await tapAndSettle(find.text(l10n.onboardingSegmentOther));
        await expectGuidelines(tester, 'segment');
        await tapAndSettle(find.text(l10n.continueBtn));
        // Segment seçilince öneriler seçili gelir: seçili çipler koyu temada
        // da okunur. Biri kaldırılınca seçilmemiş çip de denetlenir.
        expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Okuma')).selected, isTrue);
        await tapAndSettle(find.text('Okuma'));
        await expectGuidelines(tester, 'kategoriler');
        await tapAndSettle(find.text(l10n.continueBtn));
        await tapAndSettle(find.text(l10n.onboardingVisibilityNo));
        await expectGuidelines(tester, 'görünürlük');
        await tapAndSettle(find.text(l10n.continueBtn));
        await expectGuidelines(tester, 'kurallar');
        semantics.dispose();
      });
    }
  });

  group('UX-06 koyu temada okunur kırmızı', () {
    testWidgets('bağlantılar koyu temada darkPrimary', (tester) async {
      _setView(tester, const Size(390, 844));
      await tester.pumpWidget(_app(LoginScreen(onLoginSuccess: (_) {}), theme: AppTheme.darkTheme));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(LoginScreen)))!;
      Color? colorOf(String text) => tester.widget<Text>(find.text(text)).style?.color;
      expect(colorOf(l10n.forgotPassword), AppColors.darkPrimary);
      expect(colorOf(l10n.signUpLink), AppColors.darkPrimary);
      expect(find.byType(SocialSignInNotice), findsOneWidget);
    });

    testWidgets('açık temada marka kırmızısı korunur', (tester) async {
      _setView(tester, const Size(390, 844));
      await tester.pumpWidget(_app(LoginScreen(onLoginSuccess: (_) {})));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(LoginScreen)))!;
      expect(tester.widget<Text>(find.text(l10n.forgotPassword)).style?.color, AppColors.primary);
    });
  });

  group('UX-13 ARB\'ye taşınan metinler', () {
    testWidgets('tebrik diyaloğu İngilizcede İngilizce', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: SessionCompletedDialog(minutes: 50)), locale: const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('Congratulations! 🎉'), findsOneWidget);
      expect(find.textContaining('50-minute'), findsOneWidget);
      expect(find.text('Awesome!'), findsOneWidget);
    });

    test('İngilizce onboarding LGS ve YKS\'yi açıklar', () async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      expect(en.onboardingSegmentLgs, contains('entrance exam'));
      expect(en.onboardingSegmentYks, contains('entrance exam'));
    });

    test('canlı listede hazır kategori adı arayüz diline çevrilir', () async {
      final lang = LanguageService.instance;
      await lang.setLanguage(AppLanguage.en);
      addTearDown(() => lang.setLanguage(AppLanguage.tr));
      expect(lang.translateCatName('Matematik'), isNot('Matematik'));
      expect(lang.translateCatName('Kendi Kategorim'), 'Kendi Kategorim');
    });

    test('bildirim anahtarının etiketi kilit ekranı sayacını da kapsar (UX-07)', () async {
      final lang = LanguageService.instance;
      await lang.setLanguage(AppLanguage.tr);
      expect(lang.translate('notifications'), contains('kilit ekranı'));
      await lang.setLanguage(AppLanguage.en);
      addTearDown(() => lang.setLanguage(AppLanguage.tr));
      expect(lang.translate('notifications'), contains('lock screen'));
    });
  });

  group('UX-19 Hareketi Azalt', () {
    testWidgets('kum saati çalışırken bile durağan kalır', (tester) async {
      await tester.pumpWidget(_app(
        const Scaffold(body: Center(child: HourglassWidget(isRunning: true, size: 200))),
        disableAnimations: true,
      ));
      // Lottie dosyası yüklenir; animasyon başlamadığı için ekran yerleşir
      // (sürekli akan kumla pumpAndSettle zaman aşımına uğrardı).
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('kum saati Hareketi Azalt kapalıyken akar', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: Center(child: HourglassWidget(isRunning: true, size: 200)))));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
