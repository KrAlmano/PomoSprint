import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/category_model.dart';
import '../services/language_service.dart';
import '../theme.dart';
import '../utils/responsive.dart';
import '../utils/stats_calculator.dart';
import '../utils/study_day.dart';
import '../widgets/stats/category_style.dart';
import '../widgets/stats/daily_goal_sheet.dart';
import '../widgets/stats/progress_ring.dart';
import '../widgets/stats/stats_empty_card.dart';
import '../widgets/stats/stats_layout.dart';
import '../widgets/stats/stats_text.dart';

/// Raporlar > Haftalık Çalışma: içinde bulunulan Pazartesi-Pazar haftası.
/// Veriler ReportsScreen'den gelir (tek yükleme, ortak 'bugün').
///
/// Düzen: tek sütunlu liste, geniş ekranda okuma genişliğinde ortalanır;
/// yeterince genişse verimlilik ve hedef kartları yan yana durur.
class HistoryScreen extends StatefulWidget {
  final List<StatSession> sessions;

  /// Bugünün çalışma günü (04:00 kuralı).
  final DateTime today;
  final int dailyGoalMinutes;
  final List<CourseCategory> categories;
  final Future<void> Function() onRefresh;
  final VoidCallback? onStartTimer;

  const HistoryScreen({
    super.key,
    required this.sessions,
    required this.today,
    required this.dailyGoalMinutes,
    required this.categories,
    required this.onRefresh,
    this.onStartTimer,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Kullanıcının seçtiği gün (Pzt=0..Paz=6); null ise bugün.
  int? _selectedDayIndex;

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Hafta değişince seçim bugüne döner.
    if (!isSameDay(mondayOf(oldWidget.today), mondayOf(widget.today))) _selectedDayIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    final monday = mondayOf(widget.today);
    final sunday = addDays(monday, 6);
    final days = dailyTotals(widget.sessions, monday, sunday);
    final weekSessions = sessionsBetween(widget.sessions, monday, sunday).toList();
    final weekMinutes = sumMinutes(weekSessions);
    final subjects = totalsByCategory(weekSessions);
    final selectedIndex = (_selectedDayIndex ?? studyDaysBetween(monday, widget.today)).clamp(0, 6);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = StatsLayout.of(context, constraints.maxWidth, maxContentWidth: ContentWidth.reading);
          // 2. Haftalık verimlilik  2.5 Haftalık hedef (günlük hedef × 7)
          final efficiency = _buildEfficiencyCard(weekMinutes);
          final weeklyGoal = _buildWeeklyGoalSetting();

          return StatsScrollView(
            layout: layout,
            maxWidth: ContentWidth.reading,
            children: [
              // 1. Haftalık trend (sütun grafik)
              _buildWeeklyTrendChart(days, selectedIndex, layout),
              const SizedBox(height: 24),

              if (layout.isWide)
                StatsGrid(columns: 2, children: [efficiency, weeklyGoal])
              else ...[
                efficiency,
                const SizedBox(height: 16),
                weeklyGoal,
              ],
              const SizedBox(height: 16),

              // 3. Toplam süre ve en verimli gün
              _buildStatsBento(weekMinutes, busiestDay(days)),
              const SizedBox(height: 24),

              // 4. Ders bazında haftalık analiz
              _buildWeeklyAnalysis(subjects),
              SizedBox(height: layout.bottomSpacing(100)),
            ],
          );
        },
      ),
    );
  }

  // --- 1. HAFTALIK TREND ---
  Widget _buildWeeklyTrendChart(List<DayStat> days, int selectedIndex, StatsLayout layout) {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = StatsText.dateLocale;
    final accent = isDark ? AppColors.darkPrimary : AppColors.primary;
    // Grafik yüksekliği ekrana göre: dikey telefonda 160 (sütun en çok 120),
    // yatay telefonda kısa, tablette yüksek.
    final chartHeight = layout.chartHeight(160);
    final maxBarHeight = chartHeight * 0.75;
    final barWidth = layout.isWide ? 40.0 : 32.0;

    final maxMins = max(60, days.map((d) => d.minutes).reduce(max)); // en az 1 saatlik ölçek
    final selected = days[selectedIndex];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFFD9DADC)).withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.translate('weekly_trend_caption'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d MMM', locale).format(selected.day),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_rounded, size: 16, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      StatsText.duration(selected.minutes),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: layout.isShortHeight ? 20 : 32),
          SizedBox(
            height: chartHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(days.length, (index) {
                final day = days[index];
                final heightFactor = (day.minutes / maxMins).clamp(0.0, 1.0);
                final isSelected = index == selectedIndex;
                final semanticsLabel = '${DateFormat('EEEE, d MMMM', locale).format(day.day)}: '
                    '${day.minutes > 0 ? StatsText.duration(day.minutes) : lang.translate('no_study_this_day')}';

                return Expanded(
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label: semanticsLabel,
                    excludeSemantics: true,
                    onTap: () => setState(() => _selectedDayIndex = index),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selectedDayIndex = index),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Sütun, gün etiketinden kalan yüksekliğe sığar
                          // (büyük yazı boyutunda taşmaz). Dar ekranlarda
                          // payına düşen genişliğe sığar.
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, box) {
                                final barArea = min(maxBarHeight, max(0.0, box.maxHeight - 4));
                                return Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: barWidth,
                                    height: barArea * heightFactor + 4, // en az 4 px
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected ? accent : accent.withValues(alpha: 0.2),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: accent.withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              DateFormat('E', locale).format(day.day),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? accent
                                    : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. HAFTALIK VERİMLİLİK ---
  Widget _buildEfficiencyCard(int weekMinutes) {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Haftalık hedef = günlük hedef × 7
    final efficiency = goalPercent(weekMinutes, widget.dailyGoalMinutes * 7);

    String label = lang.translate('eff_normal');
    if (efficiency >= 80) {
      label = lang.translate('eff_very_high');
    } else if (efficiency >= 50) {
      label = lang.translate('eff_high');
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFFD9DADC)).withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.translate('weekly_efficiency_caption'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  StatsText.percent(context, efficiency),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0055D4),
                  ),
                ),
              ],
            ),
          ),
          ExcludeSemantics(
            child: SizedBox(
              width: 72,
              height: 72,
              child: CustomPaint(
                painter: ProgressRingPainter(
                  progress: efficiency / 100,
                  trackColor: isDark ? AppColors.darkSurfaceContainerHighest : AppColors.surfaceContainerHighest,
                  progressColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                  strokeWidth: 6,
                ),
                child: Center(
                  child: Icon(Icons.bolt_rounded, size: 28, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. TOPLAM SÜRE VE EN VERİMLİ GÜN ---
  Widget _buildStatsBento(int weekMinutes, DayStat? best) {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hourAbbr = lang.translate('hour_abbr');
    final minAbbr = lang.translate('min_abbr');
    final hours = weekMinutes ~/ 60;
    final mins = weekMinutes % 60;
    const bigNumber = TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white, height: 1);
    const unit = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white);
    // En verimli günün çubuğu, o günün günlük hedefe oranıdır.
    final bestFactor = best == null ? 0.0 : (best.minutes / max(1, widget.dailyGoalMinutes)).clamp(0.0, 1.0);

    // Uzun metin ya da büyük yazı boyutunda kartlar birlikte uzar.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Semantics(
              label: '${lang.translate('total_focus_label').replaceAll('\n', ' ')}: ${StatsText.duration(weekMinutes)}',
              excludeSemantics: true,
              child: Container(
                constraints: const BoxConstraints(minHeight: 120),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFB4261F),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB4261F).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Icon(
                        Icons.schedule_rounded,
                        size: 80,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          lang.translate('total_focus_label'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (hours > 0 || mins == 0) ...[
                                Text('$hours', style: bigNumber),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4, left: 2, right: 4),
                                  child: Text(hourAbbr, style: unit),
                                ),
                              ],
                              if (mins > 0) ...[
                                Text('$mins', style: bigNumber),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4, left: 2),
                                  child: Text(minAbbr, style: unit),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: MergeSemantics(
              child: Container(
                constraints: const BoxConstraints(minHeight: 120),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang.translate('most_efficient_day_label'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      best == null ? '-' : DateFormat('EEEE', StatsText.dateLocale).format(best.day),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        height: 1.1,
                      ),
                    ),
                    if (best != null)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurfaceContainerHighest : const Color(0xFFD9DADC),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: bestFactor,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0055D4),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Dar kartta ya da büyük yazı boyutunda küçülür.
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 88),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                StatsText.duration(best.minutes),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0055D4),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. HAFTALIK ANALİZ ---
  Widget _buildWeeklyAnalysis(List<CategoryStat> subjects) {
    final lang = LanguageService.instance;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (subjects.isEmpty) {
      return StatsEmptyCard(
        icon: Icons.bar_chart_rounded,
        title: l10n.statsNoStudyThisWeekTitle,
        description: l10n.statsNoStudyThisWeekDesc,
        actionLabel: lang.translate('start_studying_now'),
        onAction: widget.onStartTimer,
      );
    }

    final maxSubjectMins = max(1, subjects.first.minutes);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFFD9DADC)).withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.translate('weekly_analysis_caption'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lang.translate('top_subjects_label'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              ExcludeSemantics(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.bar_chart_rounded, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...subjects.map((sub) {
            final style = categoryStyleFor(
              name: sub.name,
              categoryId: sub.categoryId,
              colorHex: sub.colorHex,
              categories: widget.categories,
            );
            final factor = (sub.minutes / maxSubjectMins).clamp(0.0, 1.0);

            return MergeSemantics(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            StatsText.categoryName(context, sub.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          StatsText.duration(sub.minutes),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceContainerHighest : AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: factor,
                        child: Container(
                          decoration: BoxDecoration(
                            color: style.color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- 2.5 HAFTALIK HEDEF ---
  Widget _buildWeeklyGoalSetting() {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weeklyGoal = widget.dailyGoalMinutes * 7;

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: () => showDailyGoalSheet(context, initialGoalMinutes: widget.dailyGoalMinutes),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceContainerLowest : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : const Color(0xFFD9DADC)).withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.flag_rounded,
                    color: isDark ? AppColors.darkPrimary : AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.statsWeeklyGoalTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.statsWeeklyGoalSubtitle(StatsText.duration(weeklyGoal)),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: isDark ? AppColors.darkPrimary : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
