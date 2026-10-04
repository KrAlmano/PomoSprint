import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../theme.dart';

/// Kayıtta onaylanan Kullanım Şartları ve Gizlilik Politikası / KVKK
/// Aydınlatma Metni sürümü. Metinlerden biri değişince güncellenir; kayıt
/// sırasında kullanıcının auth metadata'sına terms_version ve
/// privacy_version olarak yazılır.
const String kLegalDocumentsVersion = '2026-10-03';

enum LegalPage { terms, privacy, kvkk }

/// Yasal sayfanın adresi. Türkçe sayfalar kökte, diğer diller /en/ altında.
/// Bu adresler (/terms, /privacy) gönderilmiş e-postalarda ve eski uygulama
/// sürümlerinde de kullanılıyor; değiştirilmemeli.
Uri legalPageUri(LegalPage page, Locale locale) {
  final turkish = locale.languageCode == 'tr';
  final path = switch (page) {
    LegalPage.terms => turkish ? 'terms' : 'en/terms',
    LegalPage.privacy => turkish ? 'privacy' : 'en/privacy',
    LegalPage.kvkk => turkish ? 'kvkk' : 'en/kvkk',
  };
  return Uri.parse('https://pomosprint.app/$path');
}

/// Yasal sayfayı uygulamanın diline göre harici tarayıcıda açar. Açılamazsa
/// (tarayıcı yok, kısıtlı cihaz) adres bir uyarıyla gösterilir.
Future<void> openLegalPage(BuildContext context, LegalPage page) async {
  final uri = legalPageUri(page, Localizations.localeOf(context));
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('[LEGAL] $uri açılamadı: $e');
  }
  if (!opened && l10n != null) {
    messenger?.showSnackBar(SnackBar(
      content: Text(l10n.legalOpenFailed(uri.toString())),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

/// Düz metin ya da yasal sayfa bağlantısı olan bir metin parçası.
@immutable
class LegalTextPart {
  final String text;
  final LegalPage? link;

  const LegalTextPart(this.text) : link = null;
  const LegalTextPart.link(this.text, LegalPage this.link);
}

/// İçinde dokunulabilir yasal sayfa bağlantıları olan metin. Dokunma
/// tanıyıcıları bu widget'a aittir ve onunla birlikte dispose edilir.
class LegalRichText extends StatefulWidget {
  final List<LegalTextPart> parts;
  final TextStyle? style;
  final TextAlign textAlign;

  const LegalRichText({
    super.key,
    required this.parts,
    this.style,
    this.textAlign = TextAlign.start,
  });

  /// Bağlantılar dahil düz metin (ekran okuyucu etiketi için).
  static String plainText(List<LegalTextPart> parts) => parts.map((p) => p.text).join();

  @override
  State<LegalRichText> createState() => _LegalRichTextState();
}

class _LegalRichTextState extends State<LegalRichText> {
  final Map<LegalPage, TapGestureRecognizer> _recognizers = {};

  TapGestureRecognizer _recognizerFor(LegalPage page) =>
      _recognizers.putIfAbsent(page, () => TapGestureRecognizer()..onTap = () => openLegalPage(context, page));

  @override
  void dispose() {
    for (final r in _recognizers.values) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final linkStyle = TextStyle(
      color: isDark ? AppColors.darkPrimary : AppColors.primary,
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.underline,
      decorationColor: isDark ? AppColors.darkPrimary : AppColors.primary,
    );
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          for (final part in widget.parts)
            if (part.link == null)
              TextSpan(text: part.text)
            else
              TextSpan(text: part.text, style: linkStyle, recognizer: _recognizerFor(part.link!)),
        ],
      ),
      textAlign: widget.textAlign,
    );
  }
}

/// "[prefix] Kullanım Şartları ve Gizlilik Politikası [suffix]" metni;
/// iki bağlantı da dokunulabilir.
class LegalConsentText extends StatelessWidget {
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final TextAlign textAlign;

  const LegalConsentText({
    super.key,
    required this.prefix,
    required this.suffix,
    this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LegalRichText(
      style: style,
      textAlign: textAlign,
      parts: [
        LegalTextPart(prefix),
        LegalTextPart.link(l10n.termsLinkTerms, LegalPage.terms),
        LegalTextPart(l10n.termsAgreeConnector),
        LegalTextPart.link(l10n.termsLinkPrivacy, LegalPage.privacy),
        LegalTextPart(suffix),
      ],
    );
  }
}

/// Google/Apple ile devam bildirimi: "Devam ederek Kullanım Şartları'nı
/// kabul etmiş ve KVKK Aydınlatma Metni'ni okumuş olursun." Sağlayıcıyla
/// ilk girişte hesap oluşturulduğu için şartlar burada bildirilir.
class SocialSignInNotice extends StatelessWidget {
  final TextStyle? style;
  final TextAlign textAlign;

  const SocialSignInNotice({super.key, this.style, this.textAlign = TextAlign.center});

  static List<LegalTextPart> partsFor(AppLocalizations l10n) => [
        LegalTextPart(l10n.authSocialNoticePrefix),
        LegalTextPart.link(l10n.authSocialNoticeTermsLink, LegalPage.terms),
        LegalTextPart(l10n.authSocialNoticeMiddle),
        LegalTextPart.link(l10n.authSocialNoticeKvkkLink, LegalPage.kvkk),
        LegalTextPart(l10n.authSocialNoticeSuffix),
      ];

  @override
  Widget build(BuildContext context) {
    return LegalRichText(
      parts: partsFor(AppLocalizations.of(context)!),
      style: style,
      textAlign: textAlign,
    );
  }
}
