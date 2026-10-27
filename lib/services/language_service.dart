import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../utils/category_names.dart';

enum AppLanguage { tr, en }

/// Uygulama dili. Kullanıcı uygulamada bir dil seçmediyse cihazın dili
/// izlenir (Türkçe ise tr, değilse en); böylece iOS ve Android 13+'ün
/// uygulama başına dil ayarı da çalışır. Uygulamada seçilen dil, o andaki
/// cihaz diliyle birlikte saklanır; cihaz dili (ya da uygulama başına dil
/// ayarı) sonradan değişirse en son yapılan değişiklik geçerli olur.
class LanguageService extends ChangeNotifier with WidgetsBindingObserver {
  static final LanguageService instance = LanguageService._internal();
  LanguageService._internal();

  AppLanguage _currentLanguage = AppLanguage.tr;
  AppLanguage get currentLanguage => _currentLanguage;
  Locale get currentLocale => Locale(_currentLanguage.name);

  bool get isTurkish => _currentLanguage == AppLanguage.tr;

  static const String _prefKey = 'app_language_code';
  static const String _deviceAtChoiceKey = 'app_language_device_code';

  /// Cihazın (uygulama başına dil ayarı dahil) tercih ettiği dil.
  @visibleForTesting
  static Locale Function() deviceLocale = () =>
      PlatformDispatcher.instance.locale;

  bool _observing = false;

  /// Cihaz dilinden uygulama dili: Türkçe ise tr, diğer her dilde en.
  static AppLanguage languageForLocale(Locale? locale) =>
      locale?.languageCode.toLowerCase() == 'tr'
      ? AppLanguage.tr
      : AppLanguage.en;

  static AppLanguage _parse(String code) =>
      code == 'en' ? AppLanguage.en : AppLanguage.tr;

  Future<void> init() async {
    await _resolve(languageForLocale(deviceLocale()));
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    notifyListeners();
  }

  // Kayıtlı seçime ve cihaz diline göre geçerli dili belirler.
  Future<void> _resolve(AppLanguage device) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    final deviceAtChoice = prefs.getString(_deviceAtChoiceKey);
    if (saved != null && deviceAtChoice == null) {
      // Önceki sürümde Profil'den seçilmiş: seçim korunur; cihaz dili
      // bundan sonraki değişiklikleri fark etmek için kaydedilir.
      _currentLanguage = _parse(saved);
      await prefs.setString(_deviceAtChoiceKey, device.name);
    } else if (saved != null && deviceAtChoice == device.name) {
      _currentLanguage = _parse(saved);
    } else {
      // Seçim yok ya da seçimden sonra cihaz dili değişti: cihaz izlenir.
      if (saved != null) {
        await prefs.remove(_prefKey);
        await prefs.remove(_deviceAtChoiceKey);
      }
      _currentLanguage = device;
    }
  }

  // Uygulama açıkken cihaz dili ya da (Android 13+) uygulama başına dil
  // ayarı değişti.
  @override
  void didChangeLocales(List<Locale>? locales) {
    final device = languageForLocale(
      (locales == null || locales.isEmpty) ? null : locales.first,
    );
    final before = _currentLanguage;
    unawaited(
      _resolve(device).then((_) {
        if (_currentLanguage != before) notifyListeners();
      }),
    );
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_currentLanguage == language) return;
    _currentLanguage = language;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final device = languageForLocale(deviceLocale());
    if (language == device) {
      // Cihazın diliyle aynı: ayrı seçim saklanmaz, cihaz izlenmeye devam eder.
      await prefs.remove(_prefKey);
      await prefs.remove(_deviceAtChoiceKey);
    } else {
      await prefs.setString(_prefKey, language.name);
      await prefs.setString(_deviceAtChoiceKey, device.name);
    }
  }

  /// Hazır kategori adının arayüz dilindeki karşılığı (DB'deki ad Türkçe ya
  /// da İngilizce olabilir; kullanıcının kendi adı olduğu gibi kalır). Tablo:
  /// utils/category_names.dart.
  String translateCatName(String catName) =>
      localizedKnownCategoryName(catName, turkish: isTurkish);

  /// Eski çağrı noktaları için geçiş köprüsü. Görünen tek metin kaynağı ARB'dir;
  /// burada ikinci bir çeviri sözlüğü tutulmaz. Bilinmeyen anahtar UI'ye sızmaz.
  String translate(String key) {
    final l10n = lookupAppLocalizations(currentLocale);
    return switch (key) {
      'app_language' => l10n.languageSettingsTitle,
      'btn_pause' => l10n.btnPause,
      'btn_start' => l10n.btnStart,
      'categories_section_title' => l10n.categoriesSectionTitle,
      'change_avatar' => l10n.changeAvatar,
      'continue_btn' => l10n.continueBtn,
      'daily_goal_label' => l10n.dailyGoalLabel,
      'dark_mode' => l10n.darkMode,
      'details_link' => l10n.detailsLink,
      'edit_profile' => l10n.editProfileAction,
      'eff_high' => l10n.effHigh,
      'eff_normal' => l10n.effNormal,
      'eff_very_high' => l10n.effVeryHigh,
      'efficiency_msg_close' => l10n.efficiencyMsgClose,
      'efficiency_msg_exceeded' => l10n.efficiencyMsgExceeded,
      'efficiency_msg_low' => l10n.efficiencyMsgLow,
      'efficiency_score_caption' => l10n.efficiencyScoreCaption,
      'efficiency_tip_header' => l10n.efficiencyTipHeader,
      'email' => l10n.email,
      'email_readonly_hint' => l10n.legacyEmailReadonlyHint,
      'heatmap_less' => l10n.heatmapLess,
      'heatmap_more' => l10n.heatmapMore,
      'hour_abbr' => l10n.hourAbbr,
      'hour_toggle' => l10n.hourToggle,
      'logout' => l10n.logout,
      'manage_categories_tile_sub' => l10n.manageCategoriesTileSub,
      'manage_categories_tile_title' => l10n.manageCategoriesTileTitle,
      'min_abbr' => l10n.minAbbr,
      'minutes_unit_short' => l10n.minutesUnit,
      'month_intensity_suffix' => l10n.monthIntensitySuffix,
      'most_efficient_day_label' => l10n.mostEfficientDayLabel,
      'name_surname' => l10n.profileFullNameLabel,
      'nav_ranking' => l10n.onboardingGuideRankingTitle,
      'nav_reports' => l10n.navReports,
      'nav_social' => l10n.navSocial,
      'new_week_label' => l10n.newWeekLabel,
      'no_reports_desc' => l10n.noReportsDesc,
      'no_reports_title' => l10n.noDataTitle,
      'no_study_this_day' => l10n.noStudyThisDay,
      'notifications' => l10n.notificationsAndLockScreen,
      'pause_limit_content' => l10n.pauseLimitContent,
      'pause_limit_title' => l10n.pauseLimitTitle,
      'pause_used_snackbar' => l10n.pauseUsedSnackbar,
      'preferences' => l10n.preferencesSectionTitle,
      'profile_title' => l10n.profileTitle,
      'reports_tab_history' => l10n.reportsWeeklyTab,
      'reports_tab_monthly' => l10n.reportsMonthlyTab,
      'reports_tab_subject' => l10n.reportsDailyTab,
      'reset_and_stop' => l10n.resetAndStop,
      'save_goal_btn' => l10n.saveGoalBtn,
      'session_reset' => l10n.sessionReset,
      'set_daily_goal_title' => l10n.setDailyGoalTitle,
      'start_studying_now' => l10n.startStudyingBtn,
      'tip_2' => l10n.tip2,
      'tip_3' => l10n.tip3,
      'tip_4' => l10n.tip4,
      'today_studies_header' => l10n.todayStudiesHeader,
      'top_subjects_label' => l10n.topSubjectsLabel,
      'topic_comparison_title' => l10n.topicComparisonTitle,
      'total_focus_label' => l10n.totalFocusLabel,
      'total_label' => l10n.totalLabel,
      'week_day_breakdown_title' => l10n.weekDayBreakdownTitle,
      'weekly_analysis_caption' => l10n.weeklyAnalysisCaption,
      'weekly_dist_sub' => l10n.legacyWeeklyDistSub,
      'weekly_dist_title' => l10n.legacyWeeklyDistTitle,
      'weekly_efficiency_caption' => l10n.weeklyEfficiencyCaption,
      'weekly_summary_title' => l10n.weeklySummaryTitle,
      'weekly_trend_caption' => l10n.weeklyTrendCaption,
      _ => throw ArgumentError.value(key, 'key', 'Unknown localization key'),
    };
  }
}
