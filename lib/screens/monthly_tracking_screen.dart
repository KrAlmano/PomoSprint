import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/category_model.dart';
import '../models/study_session.dart';
import '../services/supabase_service.dart';
import '../services/language_service.dart';
import '../theme.dart';

/// Ay içindeki bir Pazartesi-Pazar haftası. [start]/[end] haftanın GERÇEK
/// sınırları (ay dışına taşabilir); [rangeStart]/[rangeEnd] bu ay içinde
/// GÖRÜNTÜLENEN kırpılmış aralık (kart etiketleri için).
class _WeekBucket {
  final DateTime start;
  final DateTime end;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  int totalMinutes = 0;
  final Map<String, int> categoryMinutes = {};
  // gün (ayın günü, 1-31) -> {minutes: int, categories: Map<String,int>}
  final Map<int, Map<String, dynamic>> dayBreakdown = {};

  _WeekBucket({
    required this.start,
    required this.end,
    required this.rangeStart,
    required this.rangeEnd,
  });
}

class MonthlyTrackingScreen extends StatefulWidget {
  final List<CourseCategory> categories;

  const MonthlyTrackingScreen({super.key, required this.categories});

  @override
  State<MonthlyTrackingScreen> createState() => _MonthlyTrackingScreenState();
}

class _MonthlyTrackingScreenState extends State<MonthlyTrackingScreen> {
  bool _isLoading = true;
  List<StudySession> _allSessions = [];

  DateTime _monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Map<int, int> _dayMinutes = {};
  List<_WeekBucket> _weeks = [];
  Map<String, List<int>> _categoryWeeklyMinutes = {};
  List<String> _activeCategoryNames = [];
  int _prevMonthTotalMinutes = 0;
  int _thisMonthTotalMinutes = 0;

  @override
  void initState() {
    super.initState();
    Future.wait([
      initializeDateFormatting('tr_TR', null),
      initializeDateFormatting('en_US', null),
    ]).then((_) => _fetch());
    SupabaseService.instance.addRankingListener(_onStatsUpdated);
    LanguageService.instance.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    SupabaseService.instance.removeRankingListener(_onStatsUpdated);
    LanguageService.instance.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onStatsUpdated() => _fetch();

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  String get _dateLocale => LanguageService.instance.isTurkish ? 'tr_TR' : 'en_US';

  Future<void> _fetch() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      _allSessions = await SupabaseService.instance.fetchStudySessions();
      _processData();
    } catch (e) {
      debugPrint('Error fetching sessions in MonthlyTrackingScreen: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _colorForCategory(String name) {
    final match = widget.categories.where((c) => c.name == name);
    if (match.isNotEmpty) return match.first.color;
    // Eski kayıtlarda kategori silinmiş/yeniden adlandırılmış olabilir:
    // isim bazlı sabit bir renk seç ki aynı ders her zaman aynı renkte kalsın.
    const palette = [
      AppColors.primary,
      Color(0xFF0055D4),
      Color(0xFF586062),
      Color(0xFF8E706C),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
    ];
    return palette[name.hashCode.abs() % palette.length];
  }

  DateTime _mondayOf(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  int _totalMinutesForWeek(DateTime monday) {
    final sunday = monday.add(const Duration(days: 6));
    int total = 0;
    for (final s in _allSessions) {
      final local = s.createdAt.toLocal();
      final d = DateTime(local.year, local.month, local.day);
      if (!d.isBefore(monday) && !d.isAfter(sunday)) total += s.minutes;
    }
    return total;
  }

  void _processData() {
    final now = DateTime.now();
    _monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final today = DateTime(now.year, now.month, now.day);

    final monthSessions = _allSessions.where((s) {
      final local = s.createdAt.toLocal();
      final d = DateTime(local.year, local.month, local.day);
      return !d.isBefore(_monthStart) && !d.isAfter(monthEnd);
    }).toList();

    // Isı haritası: gün -> toplam dakika
    final dayMinutes = <int, int>{};
    for (final s in monthSessions) {
      final d = s.createdAt.toLocal();
      dayMinutes[d.day] = (dayMinutes[d.day] ?? 0) + s.minutes;
    }

    // Ay içinde başlamış olan Pazartesi-Pazar haftaları
    final weeks = <_WeekBucket>[];
    var cursor = _mondayOf(_monthStart);
    while (!cursor.isAfter(monthEnd)) {
      if (!cursor.isAfter(today)) {
        final sunday = cursor.add(const Duration(days: 6));
        final rangeStart = cursor.isBefore(_monthStart) ? _monthStart : cursor;
        final rangeEnd = sunday.isAfter(monthEnd) ? monthEnd : sunday;
        weeks.add(_WeekBucket(start: cursor, end: sunday, rangeStart: rangeStart, rangeEnd: rangeEnd));
      }
      cursor = cursor.add(const Duration(days: 7));
    }

    final categoryTotals = <String, int>{};
    for (final s in monthSessions) {
      final local = s.createdAt.toLocal();
      final d = DateTime(local.year, local.month, local.day);
      for (final w in weeks) {
        if (!d.isBefore(w.start) && !d.isAfter(w.end)) {
          w.totalMinutes += s.minutes;
          w.categoryMinutes[s.categoryName] = (w.categoryMinutes[s.categoryName] ?? 0) + s.minutes;
          final dayEntry = w.dayBreakdown.putIfAbsent(d.day, () => {'minutes': 0, 'categories': <String, int>{}});
          dayEntry['minutes'] = (dayEntry['minutes'] as int) + s.minutes;
          (dayEntry['categories'] as Map<String, int>)[s.categoryName] =
              ((dayEntry['categories'] as Map<String, int>)[s.categoryName] ?? 0) + s.minutes;
          break;
        }
      }
      categoryTotals[s.categoryName] = (categoryTotals[s.categoryName] ?? 0) + s.minutes;
    }

    final activeCategoryNames = categoryTotals.keys.toList()
      ..sort((a, b) => categoryTotals[b]!.compareTo(categoryTotals[a]!));
    final categoryWeekly = <String, List<int>>{};
    for (final name in activeCategoryNames) {
      categoryWeekly[name] = weeks.map((w) => w.categoryMinutes[name] ?? 0).toList();
    }

    final prevMonthRef = DateTime(now.year, now.month - 1, 1);
    final prevMonthStart = DateTime(prevMonthRef.year, prevMonthRef.month, 1);
    final prevMonthEnd = DateTime(prevMonthRef.year, prevMonthRef.month + 1, 0);
    int prevTotal = 0;
    for (final s in _allSessions) {
      final local = s.createdAt.toLocal();
      final d = DateTime(local.year, local.month, local.day);
      if (!d.isBefore(prevMonthStart) && !d.isAfter(prevMonthEnd)) prevTotal += s.minutes;
    }

    _dayMinutes = dayMinutes;
    _weeks = weeks;
    _categoryWeeklyMinutes = categoryWeekly;
    _activeCategoryNames = activeCategoryNames.take(6).toList();
    _prevMonthTotalMinutes = prevTotal;
    _thisMonthTotalMinutes = monthSessions.fold<int>(0, (sum, s) => sum + s.minutes);
  }

  String _formatDuration(int minutes, bool isTurkish) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0) {
      return isTurkish ? '${h}sa ${m.toString().padLeft(2, '0')}dk' : '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return isTurkish ? '${m}dk' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: isDark ? AppColors.darkPrimary : AppColors.primary));
    }

    final lang = LanguageService.instance;
    final isTurkish = lang.isTurkish;

    if (_thisMonthTotalMinutes <= 0) {
      return _buildEmptyState(isDark, isTurkish);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeatmap(isDark, isTurkish),
          const SizedBox(height: 24),
          _buildTopicComparison(isDark, isTurkish),
          const SizedBox(height: 24),
          _buildWeeklySummary(isDark, isTurkish),
          if (_prevMonthTotalMinutes > 0) ...[
            const SizedBox(height: 16),
            _buildMotivation(isDark, isTurkish),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // ─── ISI HARİTASI ───
  Widget _buildHeatmap(bool isDark, bool isTurkish) {
    final monthEnd = DateTime(_monthStart.year, _monthStart.month + 1, 0);
    final daysInMonth = monthEnd.day;
    final firstWeekday = _monthStart.weekday; // 1=Pzt .. 7=Paz
    final monthName = DateFormat('MMMM', _dateLocale).format(_monthStart);
    final year = _monthStart.year;

    Color cellColor(int minutes) {
      final base = isDark ? AppColors.darkPrimary : AppColors.primary;
      final empty = isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHighest;
      if (minutes <= 0) return empty;
      
      final intensity = (minutes / 25.0) / 15.0; // 1 pomodoro = 25 dk. Max 15 pomodoro.
      if (intensity <= 0.25) return base.withValues(alpha: 0.2);
      if (intensity <= 0.5) return base.withValues(alpha: 0.4);
      if (intensity <= 0.75) return base.withValues(alpha: 0.7);
      return base;
    }

    final dayHeaders = isTurkish
        ? ['P', 'S', 'Ç', 'P', 'C', 'C', 'P']
        : ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '$monthName ${LanguageService.instance.translate('month_intensity_suffix')}',
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
                  '$year',
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                children: [
                  ...dayHeaders.map((d) => Center(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant).withValues(alpha: 0.6),
                          ),
                        ),
                      )),
                  ...List.generate(firstWeekday - 1, (_) => const SizedBox.shrink()),
                  ...List.generate(daysInMonth, (index) {
                    final day = index + 1;
                    final minutes = _dayMinutes[day] ?? 0;
                    return AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cellColor(minutes),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    LanguageService.instance.translate('heatmap_less'),
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(width: 6),
                  ...[0.2, 0.4, 0.7, 1.0].map((alpha) => Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.darkPrimary : AppColors.primary).withValues(alpha: alpha),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )),
                  const SizedBox(width: 6),
                  Text(
                    LanguageService.instance.translate('heatmap_more'),
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── KONU KARŞILAŞTIRMASI (ÇİZGİ GRAFİK) ───
  Widget _buildTopicComparison(bool isDark, bool isTurkish) {
    final colors = {for (final name in _activeCategoryNames) name: _colorForCategory(name)};
    final weekLabels = List.generate(_weeks.length, (i) => isTurkish ? 'Hafta ${i + 1}' : 'Week ${i + 1}');

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
        Container(
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
                children: _activeCategoryNames.map((name) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: colors[name], shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        LanguageService.instance.translateCatName(name),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                width: double.infinity,
                child: CustomPaint(
                  painter: _MultiLineChartPainter(
                    series: _categoryWeeklyMinutes,
                    colors: colors,
                    gridColor: (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant).withValues(alpha: 0.3),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: weekLabels
                    .map((l) => Text(
                          l,
                          style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── HAFTALIK ÖZET KARTLARI ───
  Widget _buildWeeklySummary(bool isDark, bool isTurkish) {
    final cards = _weeks.reversed.toList(); // en yeni hafta üstte
    final dateFmt = DateFormat('d MMM', _dateLocale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LanguageService.instance.translate('weekly_summary_title'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ...cards.map((week) {
          final prevTotal = _totalMinutesForWeek(week.start.subtract(const Duration(days: 7)));
          final hasBaseline = prevTotal > 0;
          final pct = hasBaseline ? ((week.totalMinutes - prevTotal) / prevTotal * 100).round() : 0;
          final isUp = pct >= 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showWeekDetailModal(week, isDark, isTurkish),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceContainerHigh.withValues(alpha: 0.5) : AppColors.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
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
                          isTurkish
                              ? '${_formatDuration(week.totalMinutes, isTurkish)} Çalışma'
                              : '${_formatDuration(week.totalMinutes, isTurkish)} Study',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    if (hasBaseline)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (isUp ? AppColors.primary : Colors.red).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                              size: 18,
                              color: isUp ? (isDark ? AppColors.darkPrimary : AppColors.primary) : Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '%${pct.abs()}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isUp ? (isDark ? AppColors.darkPrimary : AppColors.primary) : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          LanguageService.instance.translate('new_week_label'),
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
            ),
          );
        }),
      ],
    );
  }

  void _showWeekDetailModal(_WeekBucket week, bool isDark, bool isTurkish) {
    final dateFmt = DateFormat('d MMMM, EEEE', _dateLocale);
    final rangeFmt = DateFormat('d MMM', _dateLocale);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            final days = <DateTime>[];
            for (var d = week.rangeStart; !d.isAfter(week.rangeEnd); d = d.add(const Duration(days: 1))) {
              days.add(d);
            }
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LanguageService.instance.translate('week_day_breakdown_title'),
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
                        IconButton(
                          icon: const Icon(Icons.close),
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
                        final entry = week.dayBreakdown[day.day];
                        final minutes = entry == null ? 0 : entry['minutes'] as int;
                        final categories = entry == null ? <String, int>{} : entry['categories'] as Map<String, int>;

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
                                      dateFmt.format(day),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                                      ),
                                    ),
                                  ),
                                  if (minutes > 0)
                                    Text(
                                      _formatDuration(minutes, isTurkish),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                      ),
                                    ),
                                ],
                              ),
                              if (categories.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    LanguageService.instance.translate('no_study_this_day'),
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
                                    children: categories.entries.map((e) {
                                      final color = _colorForCategory(e.key);
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${LanguageService.instance.translateCatName(e.key)} • ${_formatDuration(e.value, isTurkish)}',
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

  // ─── AY SONU MOTİVASYON MESAJI ───
  Widget _buildMotivation(bool isDark, bool isTurkish) {
    final pct = ((_thisMonthTotalMinutes - _prevMonthTotalMinutes) / _prevMonthTotalMinutes * 100).round();
    if (pct <= 0) return const SizedBox.shrink();

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
            isTurkish
                ? 'Bu ay odağını %$pct artırarak harika bir iş çıkardın!'
                : 'You increased your focus by $pct% this month — great job!',
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

  Widget _buildEmptyState(bool isDark, bool isTurkish) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
              isTurkish ? 'Bu ay henüz çalışma kaydın yok' : 'No study recorded this month yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isTurkish
                  ? 'İlk pomodoro seansını tamamladığında aylık takip burada görünecek.'
                  : 'Your monthly tracking will show up here once you complete your first pomodoro.',
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
    );
  }
}

// ─── ÇOK ÇİZGİLİ KARŞILAŞTIRMA GRAFİĞİ ───
class _MultiLineChartPainter extends CustomPainter {
  final Map<String, List<int>> series;
  final Map<String, Color> colors;
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
    final weekCount = series.values.first.length;
    if (weekCount == 0) return;

    int maxVal = 1;
    for (final values in series.values) {
      for (final v in values) {
        if (v > maxVal) maxVal = v;
      }
    }

    series.forEach((name, values) {
      final color = colors[name] ?? AppColors.primary;
      final dotPaint = Paint()..color = color;

      if (weekCount == 1) {
        final x = size.width / 2;
        final y = size.height * (1 - values[0] / maxVal);
        canvas.drawCircle(Offset(x, y), 4, dotPaint);
        return;
      }

      final linePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      for (int i = 0; i < values.length; i++) {
        final x = size.width * i / (weekCount - 1);
        final y = size.height * (1 - values[i] / maxVal);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, linePaint);

      for (int i = 0; i < values.length; i++) {
        final x = size.width * i / (weekCount - 1);
        final y = size.height * (1 - values[i] / maxVal);
        canvas.drawCircle(Offset(x, y), 3, dotPaint);
      }
    });
  }

  @override
  bool shouldRepaint(covariant _MultiLineChartPainter oldDelegate) => true;
}
