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
  
  // Weekly Data (Last 7 Days)
  List<Map<String, dynamic>> _weeklyData = [];
  int _activeDayIndex = 6; // Default to today (last index in 7 days)
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
    
    // Create last 7 days array
    _weeklyData = List.generate(7, (index) {
      final d = today.subtract(Duration(days: 6 - index));
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
      final diff = today.difference(sDate).inDays;
      
      // Process Weekly Data (Last 7 days only)
      if (diff >= 0 && diff < 7) {
        final index = 6 - diff;
        _weeklyData[index]['minutes'] += s.minutes;
        _weeklyData[index]['pomodoros'] += s.pomodoros;
        _totalWeeklyMinutes += s.minutes;
        
        // Track most efficient day
        if (_weeklyData[index]['minutes'] > _mostEfficientMinutes) {
          _mostEfficientMinutes = _weeklyData[index]['minutes'] as int;
          _mostEfficientDay = DateFormat('EEEE', _dateLocale).format(sDate);
        }
      }

      // Process Subject Data (All time or last 7 days depending on requirement)
      if (diff >= 0 && diff < 7) {
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
