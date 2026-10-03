import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/language_service.dart';
import '../../theme.dart';

/// Girişten önce dil seçimi (TR | EN). Seçim [LanguageService] ile kaydedilir;
/// Profil'deki dil seçimiyle aynı tercihtir. Seçilmezse cihazın dili
/// kullanılır.
class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Seçili dilim temanın secondaryContainer'ı yerine marka tonlarıyla
    // çizilir; koyu temada da metin okunur kalır (WCAG 4.5:1).
    final style = SegmentedButton.styleFrom(
      selectedBackgroundColor: isDark ? AppColors.darkPrimaryContainer : AppColors.primaryFixed,
      selectedForegroundColor: isDark ? AppColors.darkOnPrimaryContainer : AppColors.onPrimaryFixed,
      foregroundColor: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
    );
    return ListenableBuilder(
      listenable: lang,
      builder: (context, _) => Semantics(
        container: true,
        label: l10n.languagePickerLabel,
        child: SegmentedButton<AppLanguage>(
          style: style,
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: AppLanguage.tr, label: Text('TR'), tooltip: 'Türkçe'),
            ButtonSegment(value: AppLanguage.en, label: Text('EN'), tooltip: 'English'),
          ],
          selected: {lang.currentLanguage},
          onSelectionChanged: (selection) => lang.setLanguage(selection.first),
        ),
      ),
    );
  }
}
