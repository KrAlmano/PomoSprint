import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/models/avatar_model.dart';
import 'package:pomodoro/models/registration_consent.dart';
import 'package:pomodoro/screens/register_screen.dart';
import 'package:pomodoro/services/supabase_service.dart';
import 'package:pomodoro/theme.dart';
import 'package:pomodoro/widgets/auth/auth_error_banner.dart';
import 'package:pomodoro/widgets/auth/legal_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

RegistrationConsent _consent({bool terms = true, bool privacy = true, bool marketing = false}) => RegistrationConsent(
      termsAccepted: terms,
      privacyAcknowledged: privacy,
      marketingConsent: marketing,
      legalVersion: kLegalDocumentsVersion,
      acceptedAt: DateTime.utc(2026, 10, 3, 12, 30),
    );

void main() {
  group('RegistrationConsent', () {
    test('iki zorunlu onay olmadan metadata üretilmez', () {
      expect(_consent(terms: false).hasRequired, isFalse);
      expect(_consent(privacy: false).hasRequired, isFalse);
      expect(_consent(terms: false, privacy: false, marketing: true).hasRequired, isFalse);
      expect(() => _consent(terms: false).toMetadata(), throwsStateError);
      expect(() => _consent(privacy: false).toMetadata(), throwsStateError);
      expect(_consent().hasRequired, isTrue);
    });

    test('metadata: sürümler, UTC kabul anı ve pazarlama bayrağı', () {
      final meta = _consent().toMetadata();
      expect(meta['terms_version'], kLegalDocumentsVersion);
      expect(meta['privacy_version'], kLegalDocumentsVersion);
      expect(meta['terms_accepted_at'], '2026-10-03T12:30:00.000Z');
      expect(meta['marketing_consent'], isFalse);
      // handle_newsletter_subscription trigger'ının okuduğu mevcut anahtar.
      expect(meta['newsletter'], isFalse);

      final withMarketing = _consent(marketing: true).toMetadata();
      expect(withMarketing['marketing_consent'], isTrue);
      expect(withMarketing['newsletter'], isTrue);
    });

    test('yerel saatli kabul anı UTC\'ye çevrilir', () {
      final local = DateTime(2026, 10, 3, 15, 30);
      final meta = RegistrationConsent(
        termsAccepted: true,
        privacyAcknowledged: true,
        legalVersion: kLegalDocumentsVersion,
        acceptedAt: local,
      ).toMetadata();
      expect(meta['terms_accepted_at'], local.toUtc().toIso8601String());
      expect((meta['terms_accepted_at'] as String).endsWith('Z'), isTrue);
    });
  });

  group('SupabaseService.signUpMetadata', () {
    test('handle_new_user anahtarları + onay kaydı', () {
      final data = SupabaseService.signUpMetadata(
        email: '  Ayse@Example.com ',
        avatarId: 'avatar_2_glasses',
        name: '  Ayşe Yılmaz ',
        consent: _consent(marketing: true),
      );
      expect(data, {
        'name': 'Ayşe Yılmaz',
        'avatar_id': 'avatar_2_glasses',
        'newsletter': true,
        'marketing_consent': true,
        'terms_version': kLegalDocumentsVersion,
        'privacy_version': kLegalDocumentsVersion,
        'terms_accepted_at': '2026-10-03T12:30:00.000Z',
      });
    });

    test('ücretli avatar varsayılana çekilir, ad yoksa e-posta yerel kısmı', () {
      final data = SupabaseService.signUpMetadata(
        email: 'Ali@Example.com',
        avatarId: 'avatar_does_not_exist',
        consent: _consent(),
      );
      expect(data['avatar_id'], kDefaultAvatarId);
      expect(data['name'], 'ali');
      expect(data['newsletter'], isFalse);
    });

    test('zorunlu onay yoksa istek verisi hiç oluşmaz', () {
      expect(
        () => SupabaseService.signUpMetadata(email: 'a@b.co', avatarId: kDefaultAvatarId, consent: _consent(privacy: false)),
        throwsStateError,
      );
    });

    test('registerUser zorunlu onay olmadan ağa çıkmadan durur', () async {
      // Bulut kapalı olsa bile önce onay denetlenir (StateError, AuthFailure değil).
      await expectLater(
        SupabaseService.instance.registerUser(
          email: 'a@b.co',
          password: '123456',
          avatarId: kDefaultAvatarId,
          consent: _consent(terms: false),
        ),
        throwsStateError,
      );
    });
  });

  group('Kayıt formu doğrulamaları', () {
    late AppLocalizations l10n;
    setUpAll(() async => l10n = await AppLocalizations.delegate.load(const Locale('tr')));

    test('ad 1..50, boş ve küfürlü ad reddedilir', () {
      expect(registerNameError(l10n, '   '), l10n.registerErrNameRequired);
      expect(registerNameError(l10n, 'A'), isNull);
      expect(registerNameError(l10n, 'a' * 50), isNull);
      expect(registerNameError(l10n, 'a' * 51), l10n.registerErrNameTooLong);
      expect(registerNameError(l10n, 'orospu'), l10n.nameNotAllowed);
    });

    test('e-posta biçimi', () {
      expect(registerEmailError(l10n, ''), l10n.registerErrEmailRequired);
      expect(registerEmailError(l10n, 'ayse'), l10n.authErrInvalidEmail);
      expect(registerEmailError(l10n, 'ayse@posta'), l10n.authErrInvalidEmail);
      expect(registerEmailError(l10n, 'ay se@posta.com'), l10n.authErrInvalidEmail);
      expect(registerEmailError(l10n, ' ayse@posta.com '), isNull);
    });

    test('şifre en az 6 karakter', () {
      expect(registerPasswordError(l10n, ''), l10n.registerErrPasswordRequired);
      expect(registerPasswordError(l10n, '12345'), l10n.errShortPassword);
      expect(registerPasswordError(l10n, '123456'), isNull);
    });
  });

  group('Kayıt ekranı onay akışı', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<AppLocalizations> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RegisterScreen(),
      ));
      await tester.pumpAndSettle();
      return AppLocalizations.of(tester.element(find.byType(RegisterScreen)))!;
    }

    Future<void> fillValidFields(WidgetTester tester) async {
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Ayşe Yılmaz');
      await tester.enterText(fields.at(1), 'ayse@example.com');
      await tester.enterText(fields.at(2), 'gizli-sifre');
      await tester.pump();
    }

    Future<void> submit(WidgetTester tester, AppLocalizations l10n) async {
      await tester.ensureVisible(find.text(l10n.registerBtn));
      await tester.tap(find.text(l10n.registerBtn));
      await tester.pumpAndSettle();
    }

    List<bool?> checkboxValues(WidgetTester tester) =>
        tester.widgetList<Checkbox>(find.byType(Checkbox)).map((c) => c.value).toList();

    testWidgets('üç onay var; hepsi işaretsiz başlar, "tümünü kabul et" yok', (tester) async {
      final l10n = await pump(tester);
      expect(checkboxValues(tester), [false, false, false]);
      expect(find.text(l10n.registerConsentRequiredTag), findsNWidgets(2));
      expect(find.text(l10n.registerConsentOptionalTag), findsOneWidget);
      expect(find.textContaining(RegExp('tümünü', caseSensitive: false)), findsNothing);
    });

    testWidgets('zorunlu onaylar olmadan istek gönderilmez, satır içi hata gösterilir', (tester) async {
      final l10n = await pump(tester);
      await fillValidFields(tester);
      await submit(tester, l10n);

      expect(find.text(l10n.errAcceptTerms), findsOneWidget);
      expect(find.text(l10n.errAcknowledgePrivacy), findsOneWidget);
      // İstek gönderilseydi (bulut kapalı) hata kutusu çıkardı.
      expect(find.byType(AuthErrorBanner), findsNothing);
      expect(tester.widgetList<Checkbox>(find.byType(Checkbox)).take(2).every((c) => c.isError), isTrue);

      // Yalnızca şartlar: gizlilik hatası kalır, istek yine gönderilmez.
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pump();
      expect(find.text(l10n.errAcceptTerms), findsNothing);
      await submit(tester, l10n);
      expect(find.text(l10n.errAcknowledgePrivacy), findsOneWidget);
      expect(find.byType(AuthErrorBanner), findsNothing);
    });

    testWidgets('satıra dokunmak kutuyu değiştirir; iki zorunlu onayla istek gönderilir', (tester) async {
      final l10n = await pump(tester);
      await fillValidFields(tester);

      await tester.ensureVisible(find.text(l10n.registerConsentOptionalTag));
      // Pazarlama onayı metnine dokunmak kutuyu işaretler ve kaldırır.
      await tester.tap(find.text(l10n.registerConsentMarketingHint));
      await tester.pump();
      expect(checkboxValues(tester), [false, false, true]);
      await tester.tap(find.text(l10n.registerConsentMarketingHint));
      await tester.pump();
      expect(checkboxValues(tester), [false, false, false]);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      await submit(tester, l10n);

      // Testte bulut kapalı: istek servise ulaşır ve "bağlantı yok" hatası döner.
      expect(find.byType(AuthErrorBanner), findsOneWidget);
      expect(find.text(l10n.authErrCloudUnavailable), findsOneWidget);
      expect(find.text(l10n.errAcceptTerms), findsNothing);
      expect(find.text(l10n.errAcknowledgePrivacy), findsNothing);
    });

    testWidgets('alan hataları: boş form ve küfürlü ad', (tester) async {
      final l10n = await pump(tester);
      await submit(tester, l10n);
      expect(find.text(l10n.registerErrNameRequired), findsOneWidget);
      expect(find.text(l10n.registerErrEmailRequired), findsOneWidget);
      expect(find.text(l10n.registerErrPasswordRequired), findsOneWidget);
      expect(find.byType(AuthErrorBanner), findsNothing);

      await tester.enterText(find.byType(TextFormField).at(0), 'Siktir Git');
      await tester.pump();
      expect(find.text(l10n.nameNotAllowed), findsOneWidget);
    });

    testWidgets('telefon/yatay/tablet ve büyük metinde, hatalar görünürken taşmaz', (tester) async {
      for (final size in const [Size(390, 844), Size(844, 390), Size(568, 320), Size(820, 1180), Size(1366, 1024)]) {
        for (final scale in const [1.0, 2.0]) {
          final label = '$size x$scale';
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(MaterialApp(
            key: UniqueKey(),
            locale: const Locale('tr'),
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const RegisterScreen(),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
          final l10n = AppLocalizations.of(tester.element(find.byType(RegisterScreen)))!;
          await submit(tester, l10n);
          expect(tester.takeException(), isNull, reason: '$label (hatalarla)');
          expect(find.text(l10n.errAcceptTerms), findsOneWidget, reason: label);
          // Form tablette form genişliğinde kalır.
          expect(tester.getSize(find.byType(TextFormField).first).width, lessThanOrEqualTo(480), reason: label);
        }
      }
    });

    testWidgets('ad alanı 50 karakterde kesilir (sunucu CHECK 1..50)', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextFormField).at(0), 'a' * 60);
      await tester.pump();
      final field = tester.widget<EditableText>(find.byType(EditableText).first);
      expect(field.controller.text.length, 50);
    });
  });
}
