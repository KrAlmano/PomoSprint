import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/study_session.dart';
import '../services/supabase_service.dart';
import '../services/language_service.dart';
import '../theme.dart';

class HistoryScreen extends StatefulWidget {
  final int totalMinutes;
  final VoidCallback? onStartTimer;

  const HistoryScreen({
    super.key,
    this.totalMinutes = 0,
    this.onStartTimer,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  List<StudySession> _sessions = [];
  
  // Weekly Data (İçinde bulunulan hafta: Pazartesi-Pazar)
  List<Map<String, dynamic>> _weeklyData = [];
  int _activeDayIndex = DateTime.now().weekday - 1; // Varsayılan: bugün (Pzt=0..Paz=6)
  int _totalWeeklyMinutes = 0;
  String _mostEfficientDay = '-';
  int _mostEfficientMinutes = 0;
  int _dailyGoal = 8;
  
  // Subject Data
  List<Map<String, dynamic>> _topSubjects = [];

  @override
  void initState() {
    super.initState();
    Future.wait([
      initializeDateFormatting('tr_TR', null),
      initializeDateFormatting('en_US', null),
    ]).then((_) {
      _fetchAndProcessSessions();
    });
    LanguageService.instance.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    LanguageService.instance.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    // Dil değişince gün isimleri (Pzt/Mon vb.) yeniden hesaplanmalı.
    if (_sessions.isNotEmpty || !_isLoading) _processData();
    if (mounted) setState(() {});
  }

  String get _dateLocale => LanguageService.instance.isTurkish ? 'tr_TR' : 'en_US';



  Future<void> _fetchAndProcessSessions() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _dailyGoal = prefs.getInt('daily_pomo_goal') ?? 8;

      // 1. Fetch real sessions
      final realSessions = await SupabaseService.instance.fetchStudySessions();
      _sessions = realSessions;
      
      _processData();
    } catch (e) {
      debugPrint("Error fetching sessions: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // İçinde bulunulan haftanın Pazartesi'si (Türkiye standardı: Pzt-Paz).
    final monday = today.subtract(Duration(days: today.weekday - 1));

    // Create current Mon-Sun week array
    _weeklyData = List.generate(7, (index) {
      final d = monday.add(Duration(days: index));
      return {
        'date': d,
        'label': DateFormat('E', _dateLocale).format(d), // Pzt, Sal vb. / Mon, Tue etc.
        'minutes': 0,
        'pomodoros': 0,
      };
    });

    _totalWeeklyMinutes = 0;
    _mostEfficientMinutes = 0;
    _mostEfficientDay = '-';

    Map<String, int> subjectMinutes = {};

    for (var s in _sessions) {
      final localDate = s.createdAt.toLocal();
      final sDate = DateTime(localDate.year, localDate.month, localDate.day);
      final daysSinceMonday = sDate.difference(monday).inDays;

      // Process Weekly Data (bu Pazartesi-Pazar haftası)
      if (daysSinceMonday >= 0 && daysSinceMonday < 7) {
        final index = daysSinceMonday;
        _weeklyData[index]['minutes'] += s.minutes;
        _weeklyData[index]['pomodoros'] += s.pomodoros;
        _totalWeeklyMinutes += s.minutes;

        // Track most efficient day
        if (_weeklyData[index]['minutes'] > _mostEfficientMinutes) {
          _mostEfficientMinutes = _weeklyData[index]['minutes'] as int;
          _mostEfficientDay = DateFormat('EEEE', _dateLocale).format(sDate);
        }

        subjectMinutes[s.categoryName] = (subjectMinutes[s.categoryName] ?? 0) + s.minutes;
      }
    }

    // Process Top Subjects
    _topSubjects = subjectMinutes.entries.map((e) => {
      'name': e.key,
      'minutes': e.value,
    }).toList();
    _topSubjects.sort((a, b) => (b['minutes'] as int).compareTo(a['minutes'] as int));
    // Sınırlama kaldırıldı: tüm dersler gösterilecek
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: isDark ? AppColors.darkPrimary : AppColors.primary));
    }

    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, _) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Weekly Focus Trend (Bar Chart)
              _buildWeeklyTrendChart(),
              const SizedBox(height: 24),

              // 2. Focus Efficiency
              _buildEfficiencyCard(),
              const SizedBox(height: 16),
              
              // 2.5 Weekly Goal Setting
              _buildWeeklyGoalSetting(),
              const SizedBox(height: 16),

              // 3. Stats Bento
              _buildStatsBento(),
              const SizedBox(height: 24),

              // 4. Weekly Analysis
              _buildWeeklyAnalysis(),
              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  // --- 1. WEEKLY FOCUS TREND ---
  Widget _buildWeeklyTrendChart() {
    if (_weeklyData.isEmpty) return const SizedBox.shrink();
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hourAbbr = lang.translate('hour_abbr');
    final minAbbr = lang.translate('min_abbr');

    // Find max minutes for scaling
    int maxMins = _weeklyData.map((e) => e['minutes'] as int).reduce(max);
    if (maxMins < 60) maxMins = 60; // minimum scale

    final activeDayData = _weeklyData[_activeDayIndex];
    final activeHours = (activeDayData['minutes'] as int) ~/ 60;
    final activeMins = (activeDayData['minutes'] as int) % 60;
    final activeTimeStr = activeHours > 0 ? '$activeHours$hourAbbr $activeMins$minAbbr' : '$activeMins$minAbbr';
    final activeDateStr = DateFormat('d MMM', _dateLocale).format(activeDayData['date']);

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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
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
                    activeDateStr,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_rounded, size: 16, color: isDark ? AppColors.darkPrimary : AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      activeTimeStr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkPrimary : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Chart
          SizedBox(
            height: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final dayData = _weeklyData[index];
                final mins = dayData['minutes'] as int;
                final heightFactor = (mins / maxMins).clamp(0.0, 1.0);
                final isSelected = index == _activeDayIndex;

                return GestureDetector(
                  onTap: () => setState(() => _activeDayIndex = index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Sütun
                      Container(
                        width: 32,
                        height: 120 * heightFactor + 4, // min height 4
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                              : (isDark ? AppColors.darkPrimary : AppColors.primary).withValues(alpha: 0.2),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: (isDark ? AppColors.darkPrimary : AppColors.primary).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ] : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Gün Etiketi
                      Text(
                        dayData['label'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                              : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. FOCUS EFFICIENCY ---
  Widget _buildEfficiencyCard() {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Toplam Haftalık Hedef = Günlük Hedef * 7
    final weeklyGoalPomodoros = _dailyGoal * 7;
    final totalWeeklyPomodoros = _totalWeeklyMinutes ~/ 25;

    final efficiency = weeklyGoalPomodoros > 0
      ? ((totalWeeklyPomodoros / weeklyGoalPomodoros) * 100).clamp(0, 100).round()
      : 0;

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
          Column(
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
                '%$efficiency',
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
          SizedBox(
            width: 72,
            height: 72,
            child: CustomPaint(
              painter: _RingPainter(
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
        ],
      ),
    );
  }

  // --- 3. STATS BENTO ---
  Widget _buildStatsBento() {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hourAbbr = lang.translate('hour_abbr');
    final minAbbr = lang.translate('min_abbr');
    final hours = _totalWeeklyMinutes ~/ 60;
    final mins = _totalWeeklyMinutes % 60;

    return Row(
      children: [
        // Total Time
        Expanded(
          child: Container(
            height: 120,
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$hours',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4, left: 2, right: 4),
                          child: Text(
                            hourAbbr,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (mins > 0) ...[
                          Text(
                            '$mins',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4, left: 2),
                            child: Text(
                              minAbbr,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Most Efficient Day
        Expanded(
          child: Container(
            height: 120,
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
                  _mostEfficientDay,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    height: 1.1,
                  ),
                ),
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
                          widthFactor: 0.85,
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
                    Text(
                      '${_mostEfficientMinutes ~/ 60}$hourAbbr',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0055D4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- 4. WEEKLY ANALYSIS ---
  Widget _buildWeeklyAnalysis() {
    if (_topSubjects.isEmpty) return const SizedBox.shrink();
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hourAbbr = lang.translate('hour_abbr');
    final minAbbr = lang.translate('min_abbr');

    final maxSubjectMins = _topSubjects.isNotEmpty ? _topSubjects[0]['minutes'] as int : 1;

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
              Column(
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bar_chart_rounded, color: isDark ? AppColors.darkPrimary : AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          ..._topSubjects.map((sub) {
            final name = sub['name'] as String;
            final mins = sub['minutes'] as int;
            final hours = mins ~/ 60;
            final factor = (mins / maxSubjectMins).clamp(0.0, 1.0);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ),
                      ),
                      Text(
                        hours > 0 ? '$hours$hourAbbr ${mins % 60}$minAbbr' : '${mins % 60}$minAbbr',
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
                          color: isDark ? AppColors.darkPrimary : AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWeeklyGoalSetting() {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final weeklyGoal = _dailyGoal * 7;
    final goalMinutes = weeklyGoal * 25;
    final goalHours = goalMinutes ~/ 60;
    final goalMins = goalMinutes % 60;
    
    final hourAbbr = lang.translate('hour_abbr');
    final minAbbr = lang.translate('min_abbr');
    final goalTimeStr = goalHours > 0
        ? '$goalHours$hourAbbr${goalMins > 0 ? ' $goalMins$minAbbr' : ''}'
        : '$goalMins$minAbbr';

    return GestureDetector(
      onTap: _showGoalSettingSheet,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.isTurkish ? 'Haftalık Hedef' : 'Weekly Goal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$weeklyGoal Pomodoro ($goalTimeStr)',
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
    );
  }

  void _showGoalSettingSheet() {
    int tempGoal = _dailyGoal;
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hourAbbr = lang.translate('hour_abbr');
    final minAbbr = lang.translate('min_abbr');

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurfaceContainerLowest : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final goalMinutes = tempGoal * 25;
            final goalHours = goalMinutes ~/ 60;
            final goalMins = goalMinutes % 60;
            final goalTimeStr = goalHours > 0
                ? '$goalHours$hourAbbr${goalMins > 0 ? ' $goalMins$minAbbr' : ''}'
                : '$goalMins$minAbbr';

            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceContainerHighest : AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    lang.translate('set_daily_goal_title'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lang.translate('set_daily_goal_sub'),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Pomodoro counter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _goalButton(
                        icon: Icons.remove_rounded,
                        onTap: () {
                          if (tempGoal > 1) {
                            setSheetState(() => tempGoal--);
                          }
                        },
                      ),
                      const SizedBox(width: 32),
                      Column(
                        children: [
                          Text(
                            '$tempGoal',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkPrimary : AppColors.primary,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            goalTimeStr,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 32),
                      _goalButton(
                        icon: Icons.add_rounded,
                        onTap: () {
                          if (tempGoal < 20) {
                            setSheetState(() => tempGoal++);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick presets
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [4, 6, 8, 10, 12].map((preset) {
                      final isSelected = tempGoal == preset;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setSheetState(() => tempGoal = preset),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? AppColors.darkPrimary : AppColors.primary)
                                  : (isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$preset',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? AppColors.darkOnSurface : AppColors.onSurface),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt('daily_pomo_goal', tempGoal);
                        if (mounted) {
                          setState(() {
                            _dailyGoal = tempGoal;
                          });
                        }
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.darkPrimary : AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        lang.translate('save_goal_btn'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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

  Widget _goalButton({required IconData icon, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant).withValues(alpha: 0.3),
          ),
        ),
        child: Icon(icon, color: isDark ? AppColors.darkPrimary : AppColors.primary, size: 24),
      ),
    );
  }
}

// --- CUSTOM PAINTER FOR RING ---
class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
