import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/category_model.dart';
import '../services/language_service.dart';
import '../theme.dart';
import '../utils/responsive.dart';
import '../utils/stats_calculator.dart';
import '../widgets/stats/category_style.dart';
import '../widgets/stats/stats_layout.dart';
import '../widgets/stats/stats_text.dart';

/// Raporlar > Aylık Takip. Veriler ReportsScreen'den gelir; tüm gün ve hafta
/// hesapları stats_calculator ile (04:00 kuralı, takvim aritmetiği) yapılır.
///
/// Düzen: dikey telefonda tek sütun. Yeterli genişlikte (tablet, yatay
/// telefon) ısı haritası ile konu karşılaştırması eşit yükseklikte yan yana,
/// haftalık özet kartları 2-3 sütunlu ızgaradır.
class MonthlyTrackingScreen extends StatelessWidget {
  final List<StatSession> sessions;

  /// Bugünün çalışma günü (04:00 kuralı); gösterilen ay bunun ayıdır.
  final DateTime today;
  final List<CourseCategory> categories;
  final Future<void> Function() onRefresh;

  const MonthlyTrackingScreen({
    super.key,
    required this.sessions,
    required this.today,
    required this.categories,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthStart = monthStartOf(today);
    final monthEnd = monthEndOf(today);
    final monthMinutes = sumMinutesBetween(sessions, monthStart, monthEnd);

    if (monthMinutes <= 0) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: _buildEmptyState(context, isDark),
            ),
          ),
        ),
      );
    }

    final weeks = weeksOfMonth(monthStart, today);
    final monthToDate = monthToDateComparison(sessions, today);
    final growth = percentChangeOf(monthToDate.current, monthToDate.previous);
    final days = dailyTotals(sessions, monthStart, monthEnd);
    final series = weeklyCategorySeries(sessions, weeks);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = StatsLayout.of(context, constraints.maxWidth);
          final chartHeight = layout.chartHeight(160);
          // Yan yana düzen: tablette ve yatay telefonda ısı haritası tüm
          // genişliğe yayılıp ekranı kaplamaz.
          final split = layout.contentWidth >= 480;

          return StatsScrollView(
            layout: layout,
            maxWidth: ContentWidth.dashboard,
            children: [
              if (split)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: layout.isExpanded ? 2 : 1,
                        child: _buildHeatmap(context, isDark, days, fill: true),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: layout.isExpanded ? 3 : 1,
                        child: _buildTopicComparison(context, isDark, weeks, series, chartHeight: chartHeight, fill: true),
                      ),
                    ],
                  ),
                )
              else ...[
                _buildHeatmap(context, isDark, days, maxGridWidth: layout.isShortHeight ? 360 : null),
                const SizedBox(height: 24),
                _buildTopicComparison(context, isDark, weeks, series, chartHeight: chartHeight),
              ],
              const SizedBox(height: 24),
              _buildWeeklySummary(context, isDark, weeks, columns: layout.columns(compact: 1, medium: 2, expanded: 3)),
              if (growth != null && growth > 0) ...[
                const SizedBox(height: 16),
                _buildMotivation(context, isDark, growth),
              ],
              SizedBox(height: layout.bottomSpacing(100)),
            ],
          );
        },
      ),
    );
  }

  Color _colorFor(String name, String? categoryId, String? colorHex) => categoryStyleFor(
        name: name,
        categoryId: categoryId,
        colorHex: colorHex,
        categories: categories,
      ).color;

  // ─── ISI HARİTASI ───
  // [fill]: yan yana düzende kart, satırın kalan yüksekliğini doldurur.
  // [maxGridWidth]: kısa ekranda hücrelerin aşırı büyümesini önler.
  Widget _buildHeatmap(BuildContext context, bool isDark, List<DayStat> days, {bool fill = false, double? maxGridWidth}) {
    final lang = LanguageService.instance;
    final locale = StatsText.dateLocale;
    final monthStart = monthStartOf(today);
    final monthName = DateFormat('MMMM', locale).format(monthStart);
    final cellFormat = DateFormat('d MMMM', locale);
    final weekdayFormat = DateFormat('EEEEE', locale);
    final firstMonday = mondayOf(monthStart);
    final base = isDark ? AppColors.darkPrimary : AppColors.primary;

    Color cellColor(int minutes) {
      if (minutes <= 0) return isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHighest;
      final intensity = (minutes / kPomodoroMinutes) / 15.0; // En koyu ton: 15 pomodoro
      if (intensity <= 0.25) return base.withValues(alpha: 0.2);
      if (intensity <= 0.5) return base.withValues(alpha: 0.4);
      if (intensity <= 0.75) return base.withValues(alpha: 0.7);
      return base;
    }

    // 7 sütunlu takvim: hafta günü başlıkları, ayın ilk gününe kadar boş
    // hücreler, sonra günler. Satırlar Row ile kurulur (GridView değil);
    // böylece kart yan yana düzende eşit yükseklik ölçümüne katılabilir.
    final cells = <Widget>[
      ...List.generate(7, (i) => ExcludeSemantics(
            child: Center(
              child: Text(
                weekdayFormat.format(addDays(firstMonday, i)),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant).withValues(alpha: 0.6),
                ),
              ),
            ),
          )),
      ...List.generate(monthStart.weekday - 1, (_) => const SizedBox.shrink()),
      ...days.map((day) => Semantics(
            label: '${cellFormat.format(day.day)}: '
                '${day.minutes > 0 ? StatsText.duration(day.minutes) : lang.translate('no_study_this_day')}',
            child: Container(
              decoration: BoxDecoration(
                color: cellColor(day.minutes),
                borderRadius: BorderRadius.circular(4),
                border: isSameDay(day.day, today) ? Border.all(color: base, width: 1.5) : null,
              ),
            ),
          )),
    ];
    const gap = 6.0;
    Widget grid = Column(
      children: [
        for (var start = 0; start < cells.length; start += 7) ...[
          if (start > 0) const SizedBox(height: gap),
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: start + i < cells.length ? cells[start + i] : const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
    if (maxGridWidth != null) {
      grid = Center(
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxGridWidth), child: grid),
      );
    }

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          grid,
          const SizedBox(height: 12),
          // Dar sütunda ya da büyük yazı boyutunda lejant küçülür.
          ExcludeSemantics(
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lang.translate('heatmap_less'),
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(width: 6),
                    ...[0.2, 0.4, 0.7, 1.0].map((alpha) => Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: base.withValues(alpha: alpha),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        )),
                    const SizedBox(width: 6),
                    Text(
                      lang.translate('heatmap_more'),
                      style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '$monthName ${lang.translate('month_intensity_suffix')}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '${monthStart.year}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (fill) Expanded(child: card) else card,
      ],
    );
  }

  // ─── KONU KARŞILAŞTIRMASI (ÇİZGİ GRAFİK) ───
  // [fill]: yan yana düzende kart ve grafik, satırın kalan yüksekliğini
  // doldurur; grafik en az [chartHeight] yüksekliğindedir.
  Widget _buildTopicComparison(
    BuildContext context,
    bool isDark,
    List<MonthWeek> weeks,
    List<CategorySeries> series, {
    required double chartHeight,
    bool fill = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    // Toplu seri 'Diğer kategoriler': kullanıcının 'Diğer' adlı kendi
    // kategorisiyle aynı ada düşmez.
    final names = [
      for (final s in series) s.isOther ? l10n.statsOtherCategories : StatsText.categoryName(context, s.name),
    ];
    final colors = [
      for (final s in series) s.isOther ? kStatsNeutralColor : _colorFor(s.name, s.categoryId, s.colorHex),
    ];
    final weekLabels = [for (var i = 0; i < weeks.length; i++) l10n.statsWeekLabel(i + 1)];
    final summary = [
      for (var i = 0; i < series.length; i++)
        '${names[i]}: ${[
          for (var w = 0; w < weekLabels.length; w++) '${weekLabels[w]} ${StatsText.duration(series[i].weeklyMinutes[w])}',
        ].join(', ')}',
    ].join('; ');

    final chart = CustomPaint(
      painter: _MultiLineChartPainter(
        series: [for (final s in series) s.weeklyMinutes],
        colors: colors,
        gridColor: (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant).withValues(alpha: 0.3),
      ),
    );

    final card = Semantics(
      label: summary,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (var i = 0; i < series.length; i++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          names[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (fill)
              Expanded(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: chartHeight),
                  child: SizedBox(width: double.infinity, child: chart),
                ),
              )
            else
              SizedBox(height: chartHeight, width: double.infinity, child: chart),
            const SizedBox(height: 8),
            // Etiketler noktaların altında: grafik tek haftada noktayı ortaya,
            // birden çok haftada kenardan kenara çizer.
            Row(
              mainAxisAlignment: weekLabels.length == 1 ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
              children: weekLabels
                  .map((l) => Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l,
                            style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LanguageService.instance.translate('topic_comparison_title'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        if (fill) Expanded(child: card) else card,
      ],
    );
  }

  // ─── HAFTALIK ÖZET KARTLARI ───
  // Dikey telefonda alt alta; geniş ekranda [columns] sütunlu ızgara.
  Widget _buildWeeklySummary(BuildContext context, bool isDark, List<MonthWeek> weeks, {int columns = 1}) {
    final l10n = AppLocalizations.of(context)!;
    final lang = LanguageService.instance;
    final dateFmt = DateFormat('d MMM', StatsText.dateLocale);

    final cards = weeks.reversed.map((week) {
      // Eşit uzunlukta pencereler: bu haftanın ay içindeki ve bugüne
      // kadarki günleri ile önceki haftanın aynı günleri.
      final comparison = compareWithPreviousWeek(sessions, week, today);
      final pct = comparison.percentChange;
      // Rozet: iki pencerede de çalışma yoksa hiç; önceki boşsa 'Yeni';
      // değişim yoksa nötr (yatay ok), aksi halde artış/düşüş.
      final showNew = pct == null && comparison.minutes > 0;
      final isFlat = pct == 0;
      final isUp = (pct ?? 0) > 0;
      final neutral = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
      final trendColor = isFlat ? neutral : (isUp ? (isDark ? AppColors.darkPrimary : AppColors.primary) : Colors.red);
      final pctText = pct == null ? '' : StatsText.percent(context, pct.abs());
      final trendLabel = isFlat
          ? l10n.statsWeekChangeSame
          : (isUp ? l10n.statsWeekChangeUp(pctText) : l10n.statsWeekChangeDown(pctText));

      return InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showWeekDetailModal(context, week, comparison.to, isDark),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceContainerHigh.withValues(alpha: 0.5) : AppColors.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dateFmt.format(week.rangeStart)} - ${dateFmt.format(week.rangeEnd)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.statsWeekStudyTotal(StatsText.duration(comparison.minutes)),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (pct != null)
                Semantics(
                  label: trendLabel,
                  excludeSemantics: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (isFlat ? neutral : (isUp ? AppColors.primary : Colors.red)).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFlat
                              ? Icons.trending_flat_rounded
                              : (isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded),
                          size: 18,
                          color: trendColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          pctText,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: trendColor),
                        ),
                      ],
                    ),
                  ),
                )
              else if (showNew)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    lang.translate('new_week_label'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lang.translate('weekly_summary_title'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        if (columns <= 1)
          ...cards.map((card) => Padding(padding: const EdgeInsets.only(bottom: 10), child: card))
        else ...[
          StatsGrid(columns: columns, spacing: 12, runSpacing: 10, children: cards),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  void _showWeekDetailModal(BuildContext context, MonthWeek week, DateTime lastDay, bool isDark) {
    final lang = LanguageService.instance;
    final dateFmt = DateFormat('d MMMM, EEEE', StatsText.dateLocale);
    final rangeFmt = DateFormat('d MMM', StatsText.dateLocale);
    // Gelecek günler listelenmez: hafta bugüne kadar gösterilir.
    final days = dailyTotals(sessions, week.rangeStart, lastDay);
    // Yatay telefonda ekranın %60'ı çok kısa kalır; sayfa neredeyse tam açılır.
    final short = Responsive.of(context).isShortHeight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Tablette tam genişliğe yayılmaz.
      constraints: const BoxConstraints(maxWidth: kStatsSheetMaxWidth),
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: short ? 0.9 : 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceContainerLowest : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.translate('week_day_breakdown_title'),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                ),
                              ),
                              Text(
                                '${rangeFmt.format(week.rangeStart)} - ${rangeFmt.format(week.rangeEnd)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: days.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final day = days[index];
                        final dayCategories = totalsByCategory(sessionsBetween(sessions, day.day, day.day));

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      dateFmt.format(day.day),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                      ),
                                    ),
                                  ),
                                  // Günlük sekmeyle aynı: senkron bekleyen seans varsa işaret.
                                  if (day.pendingSessions > 0) ...[
                                    Icon(
                                      Icons.cloud_upload_outlined,
                                      size: 14,
                                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                      semanticLabel: AppLocalizations.of(context)!.statsPendingSessions(day.pendingSessions),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  if (day.minutes > 0)
                                    Text(
                                      StatsText.duration(day.minutes),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                      ),
                                    ),
                                ],
                              ),
                              if (dayCategories.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    lang.translate('no_study_this_day'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: dayCategories.map((c) {
                                      final color = _colorFor(c.name, c.categoryId, c.colorHex);
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${StatsText.categoryName(context, c.name)} • ${StatsText.duration(c.minutes)}',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── AY MOTİVASYON MESAJI ───
  Widget _buildMotivation(BuildContext context, bool isDark, int growthPercent) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.statsMonthMotivation(StatsText.percent(context, growthPercent)),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        // Geniş ekranda metin okunabilir genişlikte ortalanır.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ContentWidth.form),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  size: 48,
                  color: isDark ? AppColors.darkPrimary : AppColors.primaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.statsMonthEmptyTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.statsMonthEmptyDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── ÇOK ÇİZGİLİ KARŞILAŞTIRMA GRAFİĞİ ───
class _MultiLineChartPainter extends CustomPainter {
  final List<List<int>> series;
  final List<Color> colors;
  final Color gridColor;

  _MultiLineChartPainter({required this.series, required this.colors, required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final frac in [0.0, 0.5, 1.0]) {
      final y = size.height * (1 - frac);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (series.isEmpty) return;
    final weekCount = series.first.length;
    if (weekCount == 0) return;

    var maxVal = 1;
    for (final values in series) {
      for (final v in values) {
        if (v > maxVal) maxVal = v;
      }
    }

    for (var s = 0; s < series.length; s++) {
      final values = series[s];
      final color = colors[s];
      final dotPaint = Paint()..color = color;

      if (weekCount == 1) {
        canvas.drawCircle(Offset(size.width / 2, size.height * (1 - values[0] / maxVal)), 4, dotPaint);
        continue;
      }

      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      Offset point(int i) => Offset(size.width * i / (weekCount - 1), size.height * (1 - values[i] / maxVal));

      final path = Path()..moveTo(point(0).dx, point(0).dy);
      for (var i = 1; i < values.length; i++) {
        path.lineTo(point(i).dx, point(i).dy);
      }
      canvas.drawPath(path, linePaint);
      for (var i = 0; i < values.length; i++) {
        canvas.drawCircle(point(i), 3, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MultiLineChartPainter oldDelegate) =>
      oldDelegate.series != series || oldDelegate.colors != colors || oldDelegate.gridColor != gridColor;
}
