import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme.dart';

/// Supabase Auth şifre kuralı (panel: en az 6 karakter; küçük harf, büyük
/// harf ve rakam). Sitedeki sıfırlama sayfası (landing/js/reset-password.js)
/// ve `authErrWeakPassword` metni aynı kuralı söyler; panel ayarı değişirse
/// üçü birlikte değişmeli. Sunucu ASCII harf/rakam arar (ş, ğ sayılmaz).
class PasswordRules {
  PasswordRules._();

  static const int minLength = 6;

  static bool hasMinLength(String value) => value.length >= minLength;
  static bool hasMixedCase(String value) => value.contains(RegExp('[a-z]')) && value.contains(RegExp('[A-Z]'));
  static bool hasDigit(String value) => value.contains(RegExp('[0-9]'));
  static bool isSatisfied(String value) => hasMinLength(value) && hasMixedCase(value) && hasDigit(value);
}

/// Yeni şifre için alan hatası (null: geçerli). Kayıt ve şifre değiştirme
/// aynı kuralı kullanır.
String? passwordRuleError(AppLocalizations l10n, String value) {
  if (value.isEmpty) return l10n.registerErrPasswordRequired;
  if (!PasswordRules.hasMinLength(value)) return l10n.errShortPassword;
  if (!PasswordRules.hasMixedCase(value) || !PasswordRules.hasDigit(value)) return l10n.authErrWeakPassword;
  return null;
}

/// Şifre alanının altında, yazdıkça güncellenen kural listesi.
class PasswordRuleChecklist extends StatelessWidget {
  final String password;

  const PasswordRuleChecklist({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    const ok = Color(0xFF2E7D32);
    const okDark = Color(0xFF81C784);

    Widget rule(String text, bool met) => Semantics(
          checked: met,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: met ? (isDark ? okDark : ok) : muted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 12, color: met ? (isDark ? okDark : ok) : muted),
                ),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          rule(l10n.passwordRuleLength, PasswordRules.hasMinLength(password)),
          rule(l10n.passwordRuleCase, PasswordRules.hasMixedCase(password)),
          rule(l10n.passwordRuleDigit, PasswordRules.hasDigit(password)),
        ],
      ),
    );
  }
}
