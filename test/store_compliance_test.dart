import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/avatar_model.dart';
import 'package:pomodoro/models/user_model.dart';
import 'package:pomodoro/screens/character_collection_screen.dart';
import 'package:pomodoro/screens/login_screen.dart';
import 'package:pomodoro/screens/post_auth_onboarding_screen.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/widgets/auth/google_logo.dart';
import 'package:pomodoro/widgets/game_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mağaza uyumu: Premium vitrini (AS-01), nötr yaş sorusu ve isteğe bağlı
// segment (AS-04), sıralamalarda görünürlüğün açıkça sorulması (KVKK-01),
// oyun kuralları (UX-21) ve resmi Google "G" logosu (AS-15).

Widget _app(Widget home, {Locale locale = const Locale('tr'), ThemeData? theme}) => MaterialApp(
      locale: locale,
      theme: theme ?? AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _premiumIds = [
  'avatar_11_doctor',
  'avatar_12_builder',
  'avatar_13_pilot',
  'avatar_14_teacher',
  'avatar_15_athlete',
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AvatarCharacter.clearCachedAvatars();
  });

  group('AS-01 edinme yolu olmayan Premium avatarlar gösterilmez', () {
    final doctor = AvatarCharacter.byId('avatar_11_doctor');
    final gamer = AvatarCharacter.byId('avatar_1_gamer');
    final league = AvatarCharacter.byId('league_gold_monthly');

    test('Premium avatar yalnızca sahibine ya da Premium kullanıcıya listelenir', () {
      expect(doctor.isListedInShop(unlockedAvatars: const [], isPremium: false), isFalse);
      expect(doctor.isListedInShop(unlockedAvatars: const ['avatar_11_doctor'], isPremium: false), isTrue);
      expect(doctor.isListedInShop(unlockedAvatars: const [], isPremium: true), isTrue);
      // Kumla alınabilenler ve varsayılanlar her zaman listelenir.
      expect(gamer.isListedInShop(unlockedAvatars: const [], isPremium: false), isTrue);
      expect(AvatarCharacter.byId(kDefaultAvatarId).isListedInShop(unlockedAvatars: const [], isPremium: false),
          isTrue);
      // Lig ödülleri kum bölümünde değil, kendi bölümünde.
      expect(league.isListedInShop(unlockedAvatars: const [], isPremium: false), isFalse);
    });

    Future<void> pumpCollection(WidgetTester tester, UserModel user) async {
      // Izgaranın tamamı kurulsun diye uzun bir pencere.
      _setView(tester, const Size(1366, 4000));
      await tester.pumpWidget(_app(CharacterCollectionScreen(user: user)));
      await tester.pumpAndSettle();
    }

    testWidgets('Premium olmayan kullanıcı kilitli Premium vitrini görmez', (tester) async {
      await pumpCollection(tester, UserModel(id: 'u1', name: 'Deneme', email: 'd@example.com', coins: 50));
      for (final id in _premiumIds) {
        expect(find.text(AvatarCharacter.byId(id).nameTr), findsNothing, reason: id);
      }
      expect(find.text('Premium'), findsNothing);
      // Kumla alınabilen ve lig ödülü avatarlar yerinde.
      expect(find.text(AvatarCharacter.byId('avatar_1_gamer').nameTr), findsOneWidget);
      expect(find.text(AvatarCharacter.byId('league_gold_monthly').getName(true)), findsOneWidget);
    });

    testWidgets('sahip olunan Premium avatar koleksiyonda kalır', (tester) async {
      await pumpCollection(
        tester,
        UserModel(id: 'u1', name: 'Deneme', email: 'd@example.com', unlockedAvatars: const ['avatar_11_doctor']),
      );
      expect(find.text(AvatarCharacter.byId('avatar_11_doctor').nameTr), findsOneWidget);
      expect(find.text(AvatarCharacter.byId('avatar_12_builder').nameTr), findsNothing);
    });

    test('ARB\'de "Ücretsiz plan" / Premium kategori limiti ifadesi yok', () async {
      final tr = await AppLocalizations.delegate.load(const Locale('tr'));
      final en = await AppLocalizations.delegate.load(const Locale('en'));
      for (final l10n in [tr, en]) {
        final body = l10n.onboardingCategoryStepBodyLimit(8);
        expect(body.toLowerCase(), isNot(contains('premium')));
        expect(body.toLowerCase(), isNot(contains('plan')));
      }
    });
  });

  group('AS-04 nötr yaş sorusu ve isteğe bağlı segment', () {
    test('tekerleğin ilk satırı seçim değildir, yıllar bugünden geriye', () {
      expect(birthYearForPickerIndex(2026, 0), isNull);
      expect(birthYearForPickerIndex(2026, 1), 2026);
      expect(birthYearForPickerIndex(2026, 14), 2013);
    });

    test('onboarding güncellemesi: "Diğer" segmenti ve geçersiz yıl null yazılır', () {
      final at = DateTime.utc(2026, 10, 3, 12);
      final other = SupabaseService.onboardingProfileUpdate(
        birthYear: 1850,
        userSegment: 'other',
        dailyGoalMinutes: 60,
        showInSocialFeed: true,
        completedAt: at,
      );
      expect(other['birth_year'], isNull);
      expect(other['user_segment'], isNull);
      // Yanıt her zaman yazılır: kolon gönderilmezse sunucu varsayılanı
      // (TRUE) kalırdı (t2-01).
      expect(other['show_in_social_feed'], isTrue);

      final yks = SupabaseService.onboardingProfileUpdate(
        birthYear: 2008,
        userSegment: 'yks',
        dailyGoalMinutes: 120,
        showInSocialFeed: false,
        completedAt: at,
      );
      expect(yks['birth_year'], 2008);
      expect(yks['user_segment'], 'yks');
      expect(yks['show_in_social_feed'], isFalse);
      expect(yks['onboarding_completed_at'], at.toIso8601String());
    });

    testWidgets('yaş önceden seçili değil; yıl seçilmeden ilerlenemez, 13 altı devam edemez', (tester) async {
      _setView(tester, const Size(390, 844));
      await tester.pumpWidget(_app(PostAuthOnboardingScreen(onCompleted: () {})));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(PostAuthOnboardingScreen)))!;

      expect(find.text(l10n.onboardingBirthYearPlaceholder), findsOneWidget);
      await tester.tap(find.text(l10n.continueBtn));
      await tester.pumpAndSettle();
      expect(find.text(l10n.onboardingBirthYearRequired), findsOneWidget);
      expect(find.text('1/6'), findsOneWidget);

      void clearSnackBars() =>
          ScaffoldMessenger.of(tester.element(find.byType(PostAuthOnboardingScreen))).clearSnackBars();

      // Birkaç satır aşağı (geçen yıl ve öncesi): 13 yaş altı. Tekerlek
      // çevrilirken uyarı çıkmaz (eşik yaş belli olmaz).
      await tester.timedDrag(find.byType(CupertinoPicker), const Offset(0, -104), const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text(l10n.onboardingUnder13Error), findsNothing);
      expect(find.text(l10n.deleteAccount), findsNothing);
      clearSnackBars();
      await tester.pumpAndSettle();

      // Devam'da değerlendirilir: ilerlenmez, uyarı (satır içi + SnackBar),
      // çıkış ve hesap silme yolu görünür.
      await tester.tap(find.text(l10n.continueBtn));
      await tester.pumpAndSettle();
      expect(find.text('1/6'), findsOneWidget);
      expect(find.text(l10n.onboardingUnder13Error), findsNWidgets(2));
      expect(find.text(l10n.deleteAccount), findsOneWidget, reason: 'hesap silme yolu kalır');
      expect(find.text(l10n.logout), findsOneWidget);

      // Yanıt verildikten sonra yıl bu ekranda değiştirilemez: tekerlek
      // 20 yıl öteye çevrilse de ilerlenmez.
      clearSnackBars();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CupertinoPicker), const Offset(0, -1040));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.continueBtn));
      await tester.pumpAndSettle();
      expect(find.text('1/6'), findsOneWidget);
      expect(find.text(l10n.onboardingUnder13Error), findsNWidgets(2));
    });

    testWidgets('segment atlanabilir, "Diğer" var; görünürlük açıkça sorulur', (tester) async {
      _setView(tester, const Size(390, 844));
      await tester.pumpWidget(_app(PostAuthOnboardingScreen(onCompleted: () {})));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(PostAuthOnboardingScreen)))!;

      Future<void> next() async {
        await tester.tap(find.text(l10n.continueBtn));
        await tester.pumpAndSettle();
      }

      await tester.drag(find.byType(CupertinoPicker), const Offset(0, -1040));
      await tester.pumpAndSettle();
      await next();
      expect(find.text('2/6'), findsOneWidget);
      expect(find.text(l10n.onboardingSegmentOther), findsOneWidget);

      // Segment seçmeden devam: genel öneriler gelir.
      await next();
      expect(find.text('3/6'), findsOneWidget);
      await tester.tap(find.text('Ders Çalışma'));
      await tester.pump();
      await next();

      // KVKK-01: görünürlük adımı, iki seçenek ve varsayılan seçim yok.
      expect(find.text('4/6'), findsOneWidget);
      expect(find.text(l10n.onboardingVisibilityTitle), findsOneWidget);
      expect(find.text(l10n.onboardingVisibilityYes), findsOneWidget);
      expect(find.text(l10n.onboardingVisibilityNo), findsOneWidget);
      final semantics = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.text(l10n.onboardingVisibilityYes)),
        isNot(matchesSemantics(isSelected: true, hasSelectedState: true, isButton: true, label: l10n.onboardingVisibilityYes)),
      );
      semantics.dispose();
      await next();
      expect(find.text(l10n.onboardingSelectOptionError), findsOneWidget);
      expect(find.text('4/6'), findsOneWidget);
      // Uyarı (SnackBar) düğmelerin üstünü kapatmasın.
      ScaffoldMessenger.of(tester.element(find.byType(PostAuthOnboardingScreen))).clearSnackBars();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(l10n.onboardingVisibilityNo));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.onboardingVisibilityNo));
      await tester.pump();
      await next();
      // UX-21: kurallar adımı.
      expect(find.text('5/6'), findsOneWidget);
      expect(find.byType(GameRulesList), findsOneWidget);
      await next();
      expect(find.text(l10n.onboardingFinishBtn), findsOneWidget);
    });
  });

  group('UX-21 oyun kuralları', () {
    testWidgets('sayılar get_points_config\'ten gelir', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(
        body: GameRulesList(config: {
          'pause_penalty_pct': 25,
          'base_points_25min': 6,
          'base_points_50min': 13,
          'coins_per_session': 30,
          'daily_league_session_limit': 12,
        }),
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('%25'), findsOneWidget);
      expect(find.textContaining('25 dk: 6, 50 dk: 13'), findsOneWidget);
      expect(find.textContaining('30 kum tanesi'), findsOneWidget);
      expect(find.textContaining('en fazla 12 seans'), findsOneWidget);
    });

    testWidgets('yapılandırma yoksa canlı değerlerle aynı yedekler', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: GameRulesList(config: {}))));
      await tester.pumpAndSettle();
      expect(find.textContaining('%20'), findsOneWidget);
      expect(find.textContaining('en fazla 16 seans'), findsOneWidget);
    });
  });

  group('AS-15 Google ile Giriş', () {
    testWidgets('resmi çok renkli G logosu kullanılır', (tester) async {
      _setView(tester, const Size(390, 844));
      await tester.pumpWidget(_app(LoginScreen(onLoginSuccess: (_) {})));
      await tester.pumpAndSettle();
      expect(find.byType(GoogleLogo), findsOneWidget);
      expect(find.byIcon(Icons.g_mobiledata), findsNothing);
      final logo = tester.getSize(find.byType(GoogleLogo));
      expect(logo.width, inInclusiveRange(18, 20));
    });

    test('logonun dört resmi rengi', () {
      expect(
        GoogleLogoPainter.parts.map((p) => p.$2).toList(),
        const [Color(0xFFEA4335), Color(0xFF4285F4), Color(0xFFFBBC05), Color(0xFF34A853)],
      );
      // Parçalar 48x48 tuvalin içinde.
      for (final (path, _) in GoogleLogoPainter.parts) {
        final b = path.getBounds();
        expect(b.left, greaterThanOrEqualTo(0));
        expect(b.top, greaterThanOrEqualTo(0));
        expect(b.right, lessThanOrEqualTo(48));
        expect(b.bottom, lessThanOrEqualTo(48));
      }
    });
  });
}
