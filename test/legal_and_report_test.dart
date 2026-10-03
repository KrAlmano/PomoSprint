import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/utils/user_report.dart';
import 'package:pomodoro/widgets/auth/legal_links.dart';
import 'package:pomodoro/widgets/social/user_safety.dart';

void main() {
  group('legalPageUri', () {
    const tr = Locale('tr');
    const en = Locale('en');

    test('Türkçe sayfalar kökte', () {
      expect(legalPageUri(LegalPage.terms, tr).toString(), 'https://pomosprint.app/terms');
      expect(legalPageUri(LegalPage.privacy, tr).toString(), 'https://pomosprint.app/privacy');
      expect(legalPageUri(LegalPage.kvkk, tr).toString(), 'https://pomosprint.app/kvkk');
      expect(legalPageUri(LegalPage.accountDeletion, tr).toString(), 'https://pomosprint.app/hesap-silme');
    });

    test('diğer diller /en/ altında', () {
      expect(legalPageUri(LegalPage.terms, en).toString(), 'https://pomosprint.app/en/terms');
      expect(legalPageUri(LegalPage.privacy, en).toString(), 'https://pomosprint.app/en/privacy');
      expect(legalPageUri(LegalPage.kvkk, en).toString(), 'https://pomosprint.app/en/kvkk');
      expect(legalPageUri(LegalPage.accountDeletion, en).toString(), 'https://pomosprint.app/en/delete-account');
      expect(legalPageUri(LegalPage.kvkk, const Locale('de')).toString(), 'https://pomosprint.app/en/kvkk');
    });

    test('sürüm sabiti tarih biçiminde', () {
      expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(kLegalDocumentsVersion), isTrue);
    });
  });

  group('Google/Apple ile devam bildirimi', () {
    for (final locale in const [Locale('tr'), Locale('en')]) {
      test('${locale.languageCode}: Kullanım Şartları ve KVKK Aydınlatma Metni bağlantılı', () async {
        final l10n = await AppLocalizations.delegate.load(locale);
        final parts = SocialSignInNotice.partsFor(l10n);
        expect(parts.where((p) => p.link != null).map((p) => p.link), [LegalPage.terms, LegalPage.kvkk]);
        final text = LegalRichText.plainText(parts);
        expect(text, contains(l10n.authSocialNoticeTermsLink));
        expect(text, contains(l10n.authSocialNoticeKvkkLink));
      });
    }

    test('TR metni: "kabul etmiş ve ... okumuş olursun"', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(
        LegalRichText.plainText(SocialSignInNotice.partsFor(l10n)),
        "Devam ederek Kullanım Şartları'nı kabul etmiş ve KVKK Aydınlatma Metni'ni okumuş olursun.",
      );
    });

    testWidgets('bağlantılar dokunulabilir span olarak çizilir', (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SocialSignInNotice()),
      ));
      final rich = tester.widget<RichText>(find.descendant(of: find.byType(SocialSignInNotice), matching: find.byType(RichText)));
      final links = <String>[];
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.recognizer != null) links.add(span.text ?? '');
        return true;
      });
      expect(links, ["Kullanım Şartları'nı", "KVKK Aydınlatma Metni'ni"]);
    });
  });

  group('Kullanıcı bildirimi (mailto)', () {
    test('alıcı destek adresi; boşluk %20 (+ değil)', () {
      final uri = buildUserReportUri(subject: 'Konu başlığı', body: 'Satır 1\nSatır 2 & ?=');
      expect(uri.scheme, 'mailto');
      expect(uri.path, kSupportEmail);
      expect(uri.toString(), isNot(contains('+')));
      expect(uri.query, contains('subject=Konu%20ba%C5%9Fl%C4%B1%C4%9F%C4%B1'));
      expect(Uri.decodeComponent(uri.query.split('&body=').last), 'Satır 1\nSatır 2 & ?=');
    });

    test('gövdede bildirilen ad, genel kimlik ve yer var; bildirenin bilgisi yok', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      final uri = userReportUri(
        l10n,
        const UserSafetyTarget(name: 'Kötü Ad', userId: '1f0c8a52-0000-4000-8000-000000000001'),
        UserReportPlace.liveFeed,
      );
      final decoded = Uri.decodeComponent(uri.toString());
      expect(decoded, startsWith('mailto:destek@pomosprint.app?'));
      expect(decoded, contains('Kötü Ad'));
      expect(decoded, contains('1f0c8a52-0000-4000-8000-000000000001'));
      expect(decoded, contains(l10n.reportPlaceLiveFeed));
      // Bildirenin e-postası URL'ye konmaz: tek e-posta adresi alıcıdır.
      expect(RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+').allMatches(decoded).length, 1);
    });

    test('kimliği olmayan satır (Lig/Aylık): "bilinmiyor" yazılır', () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      final uri = userReportUri(l10n, const UserSafetyTarget(name: 'X'), UserReportPlace.league);
      final decoded = Uri.decodeComponent(uri.toString());
      expect(decoded, contains(l10n.reportUserIdUnknown));
      expect(decoded, contains(l10n.reportPlaceLeague));
    });
  });
}
