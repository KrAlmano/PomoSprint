import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../../services/language_service.dart';
import '../../utils/stats_format.dart';

/// İstatistik ekranlarının ortak metin biçimleri (süre, yüzde, kategori adı).
abstract final class StatsText {
  static String duration(int minutes) {
    final lang = LanguageService.instance;
    return formatStudyMinutes(
      minutes,
      hourAbbr: lang.translate('hour_abbr'),
      minAbbr: lang.translate('min_abbr'),
    );
  }

  static String percent(BuildContext context, int percent) =>
      formatPercent(percent, Localizations.localeOf(context).toString());

  /// intl tarih biçimleri için yerel ayar.
  static String get dateLocale => LanguageService.instance.isTurkish ? 'tr_TR' : 'en_US';

  /// Kategori adının görüntülenecek hali. Adı olmayan (bozuk) kayıt arayüz
  /// dilinde 'Diğer' görünür. Kullanıcının 'Diğer' adlı kendi kategorisi
  /// olduğu gibi kalır (toplu seriyle karışmasın diye).
  static String categoryName(BuildContext context, String name) {
    if (name.trim().isEmpty) return AppLocalizations.of(context)!.statsOtherCategory;
    return LanguageService.instance.translateCatName(name);
  }
}
