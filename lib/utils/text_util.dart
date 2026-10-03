import '../l10n/app_localizations.dart';

class TextUtil {
  /// Sayaçtaki kategori başlığı: iş segmentinde "KATEGORİ SEÇ", diğerlerinde
  /// "DERS SEÇ" (metinler ARB'de).
  static String getCategorySelectionLabel(AppLocalizations l10n, String? userSegment) {
    if (userSegment == 'work') return l10n.selectCategory;
    return l10n.selectSubject;
  }
}
