import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../theme.dart';

enum LegalPage { terms, privacy }

/// Yasal sayfanın adresi: Türkçe için /terms, /privacy; diğer dillerde
/// /en/terms, /en/privacy.
Uri legalPageUri(LegalPage page, Locale locale) {
  final prefix = locale.languageCode == 'tr' ? '' : 'en/';
  return Uri.parse('https://pomosprint.app/$prefix${page.name}');
}

/// Yasal sayfayı uygulamanın diline göre harici tarayıcıda açar.
Future<void> openLegalPage(BuildContext context, LegalPage page) async {
  final uri = legalPageUri(page, Localizations.localeOf(context));
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('[LEGAL] $uri açılamadı: $e');
  }
}

/// "[prefix] Kullanım Şartları ve Gizlilik Politikası [suffix]" metni;
/// iki bağlantı da dokunulabilir. Dokunma tanıyıcıları bu widget'a aittir
/// ve onunla birlikte dispose edilir.
class LegalConsentText extends StatefulWidget {
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
  State<LegalConsentText> createState() => _LegalConsentTextState();
}

class _LegalConsentTextState extends State<LegalConsentText> {
  late final TapGestureRecognizer _termsRecognizer = TapGestureRecognizer()
    ..onTap = () => openLegalPage(context, LegalPage.terms);
  late final TapGestureRecognizer _privacyRecognizer = TapGestureRecognizer()
    ..onTap = () => openLegalPage(context, LegalPage.privacy);

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const linkStyle = TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.bold,
      decoration: TextDecoration.underline,
    );
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: widget.prefix),
          TextSpan(text: l10n.termsLinkTerms, style: linkStyle, recognizer: _termsRecognizer),
          TextSpan(text: l10n.termsAgreeConnector),
          TextSpan(text: l10n.termsLinkPrivacy, style: linkStyle, recognizer: _privacyRecognizer),
          TextSpan(text: widget.suffix),
        ],
      ),
      textAlign: widget.textAlign,
    );
  }
}
