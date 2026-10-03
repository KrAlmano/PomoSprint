import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category_model.dart';
import '../models/study_session.dart';
import '../services/language_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import 'history_screen.dart';
import 'monthly_tracking_screen.dart';

class ReportsScreen extends StatefulWidget {
  final List<CourseCategory> categories;
  final VoidCallback? onStartTimer;

  const ReportsScreen({
    super.key,
    required this.categories,
    this.onStartTimer,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _activeTab = 0; // 0: Günlük Çalışma, 1: Haftalık Çalışma, 2: Aylık Takip
  int _dailyGoal = 8; // Varsayılan günlük hedef: 8 pomodoro
  
  bool _isLoading = true;
  List<StudySession> _todaySessions = [];

  @override
  void initState() {
    super.initState();
    _loadDailyGoal();
    _fetchSessions();
    SupabaseService.instance.addRankingListener(_onStatsUpdated);
  }

  @override
  void dispose() {
    SupabaseService.instance.removeRankingListener(_onStatsUpdated);
    super.dispose();
  }

  void _onStatsUpdated() {
    // When a pomodoro finishes, stats are updated. We re-fetch sessions.
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {
    try {
      final sessions = await SupabaseService.instance.fetchStudySessions();
      
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      
      final todayList = sessions.where((s) {
        final localDate = s.createdAt.toLocal();
        return localDate.isAfter(todayStart) || localDate.isAtSameMomentAs(todayStart);
      }).toList();

      if (mounted) {
        setState(() {
          _todaySessions = todayList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching sessions in ReportsScreen: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDailyGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('daily_pomo_goal');
    if (saved != null && mounted) {
      setState(() => _dailyGoal = saved);
    }
  }

  Future<void> _saveDailyGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_pomo_goal', goal);
    if (mounted) {
      setState(() => _dailyGoal = goal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Supabase tablosundan gelen bugünün oturumlarını (StudySession) grupla
    final categoryMap = <String, CourseCategory>{};

    for (var session in _todaySessions) {
      final catName = session.categoryName;
      if (!categoryMap.containsKey(catName)) {
        // Renk ve ikonu main'den (widget.categories) bulmaya çalış
        final match = widget.categories.where((c) => c.name == catName).toList();
        Color catColor = AppColors.primary;
        IconData catIcon = Icons.book;
        String catId = catName;
        
        // Use color from session directly (it comes from the DB JOIN)
        if (session.colorHex != null) {
          String hexStr = session.colorHex!;
          if (hexStr.startsWith('#')) hexStr = hexStr.substring(1);
          if (hexStr.length == 6) hexStr = 'FF$hexStr';
          int colorValue = int.tryParse(hexStr, radix: 16) ?? AppColors.primary.toARGB32();
          catColor = Color(colorValue);
        } else if (match.isNotEmpty) {
          catColor = match.first.color;
          catIcon = match.first.icon;
          catId = match.first.id;
        }

        categoryMap[catName] = CourseCategory(
          id: catId,
          name: catName,
          color: catColor,
          icon: catIcon,
          sessionsCount: 0,
          totalMinutes: 0,
        );
      }

      categoryMap[catName]!.sessionsCount += session.pomodoros;
      categoryMap[catName]!.totalMinutes += session.minutes;
    }

    final activeCategories = categoryMap.values.toList();
    activeCategories.sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));

    final effectiveTotalMinutes = activeCategories.fold<int>(
      0, (sum, cat) => sum + cat.totalMinutes,
    );

    return ListenableBuilder(
      listenable: lang,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          body: SafeArea(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: isDark ? AppColors.darkPrimary : AppColors.primary))
                : Column(
                    children: [
                      // Tab Bar
                      _buildTabBar(lang),
                      // Tab Content
                      Expanded(
                        child: switch (_activeTab) {
                          0 => _buildReportsBody(activeCategories, effectiveTotalMinutes, lang),
                          1 => HistoryScreen(onStartTimer: widget.onStartTimer),
                          _ => MonthlyTrackingScreen(categories: widget.categories),
                        },
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildTabBar(LanguageService lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildTabItem(
              label: lang.translate('reports_tab_subject'),
              isActive: _activeTab == 0,
              onTap: () => setState(() => _activeTab = 0),
            ),
            const SizedBox(width: 24),
            _buildTabItem(
              label: lang.translate('reports_tab_history'),
              isActive: _activeTab == 1,
              onTap: () => setState(() => _activeTab = 1),
            ),
            const SizedBox(width: 24),
            _buildTabItem(
              label: lang.translate('reports_tab_monthly'),
              isActive: _activeTab == 2,
              onTap: () => setState(() => _activeTab = 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.darkPrimary : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive
                ? accent
                : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }

  Widget _buildReportsBody(
    List<CourseCategory> activeCategories,
    int effectiveTotalMinutes,
    LanguageService lang,
  ) {
    // Boş durum
    if (effectiveTotalMinutes <= 0) {
      return _buildEmptyState(lang);
    }

    // Verimlilik skoru hesabı: bugünkü pomo / kullanıcı hedefi
    final totalSessions = activeCategories.fold<int>(0, (s, c) => s + c.sessionsCount);
    final efficiencyScore = ((_dailyGoal > 0) ? (totalSessions / _dailyGoal) * 100 : 0.0).clamp(0, 100).round();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 0. Günlük Hedef Belirleme
          _buildDailyGoalCard(totalSessions),
          const SizedBox(height: 16),

          // 1. Verimlilik Skoru Kartı
          _buildEfficiencyCard(efficiencyScore),
          const SizedBox(height: 24),

          // 2. Bugünkü Çalışmalar Grid
          _buildTodayHeader(lang),
          const SizedBox(height: 12),
          _buildSubjectGrid(activeCategories),
          const SizedBox(height: 24),

          // 3. Haftalık Dağılım (Donut Chart)
          _buildWeeklyDistribution(activeCategories, effectiveTotalMinutes),
          const SizedBox(height: 24),

          // 4. Verimlilik İpucu
          _buildEfficiencyTip(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── 0. GÜNLÜK HEDEF BELİRLEME KARTI ───
  Widget _buildDailyGoalCard(int completedSessions) {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hourAbbr = lang.translate('hour_abbr');
    final minAbbr = lang.translate('min_abbr');
    final goalMinutes = _dailyGoal * 25;
    final goalHours = goalMinutes ~/ 60;
    final goalMins = goalMinutes % 60;
    final goalTimeStr = goalHours > 0
        ? '$goalHours$hourAbbr${goalMins > 0 ? ' $goalMins$minAbbr' : ''}'
        : '$goalMins$minAbbr';

    return GestureDetector(
      onTap: _showGoalSettingSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant).withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Progress indicator
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _dailyGoal > 0
                        ? (completedSessions / _dailyGoal).clamp(0.0, 1.0)
                        : 0,
                    strokeWidth: 4,
                    backgroundColor: (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant).withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppColors.darkPrimary : AppColors.primary),
                  ),
                  Text(
                    '$completedSessions/$_dailyGoal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Text info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.translate('daily_goal_label'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_dailyGoal Pomodoro ($goalTimeStr)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Edit icon
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
                      onPressed: () {
                        _saveDailyGoal(tempGoal);
                        Navigator.pop(ctx);
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

  // ─── 1. VERİMLİLİK SKORU KARTI ───
  Widget _buildEfficiencyCard(int score) {
    final lang = LanguageService.instance;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFB4261F),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB4261F).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Sol kısım: Skor bilgisi
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.translate('efficiency_score_caption'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$score%',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Icon(
                      score >= 50 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                score >= 100
                    ? lang.translate('efficiency_msg_exceeded')
                    : score >= 50
                        ? lang.translate('efficiency_msg_close')
                        : lang.translate('efficiency_msg_low'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),

          // Sağ kısım: Progress Ring
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _ProgressRingPainter(
                progress: score / 100,
                trackColor: Colors.white.withValues(alpha: 0.2),
                progressColor: Colors.white,
                strokeWidth: 6,
              ),
              child: Center(
                child: Icon(
                  Icons.bolt_rounded,
                  size: 32,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 2. BUGÜNKÜ ÇALIŞMALAR HEADER ───
  Widget _buildTodayHeader(LanguageService lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          lang.translate('today_studies_header'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _activeTab = 1),
          child: Text(
            lang.translate('details_link'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkPrimary : AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ─── 2b. DERS KARTLARI GRİD'İ ───
  Widget _buildSubjectGrid(List<CourseCategory> categories) {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hourAbbr = lang.translate('hour_abbr');
    final minAbbr = lang.translate('min_abbr');
    // En fazla 4 ders göster
    final displayCats = categories.take(4).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: displayCats.length,
      itemBuilder: (context, index) {
        final cat = displayCats[index];
        final totalMins = cat.sessionsCount * 25;
        final hours = totalMins ~/ 60;
        final mins = totalMins % 60;
        final timeStr = hours > 0 ? '$hours$hourAbbr $mins$minAbbr' : '$mins$minAbbr';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(cat.icon, size: 18, color: cat.color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  height: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── 3. HAFTALIK DAĞILIM (DONUT CHART) ───
  Widget _buildWeeklyDistribution(
    List<CourseCategory> categories,
    int totalMinutes,
  ) {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hourAbbr = lang.translate('hour_abbr');
    final minAbbr = lang.translate('min_abbr');
    final totalHours = totalMinutes ~/ 60;
    final totalMins = totalMinutes % 60;
    final totalStr = totalHours > 0
        ? '$totalHours$hourAbbr${totalMins > 0 ? ' $totalMins$minAbbr' : ''}'
        : '$totalMins$minAbbr';

    // Yüzde hesapla
    final segments = categories.map((cat) {
      final pct = totalMinutes > 0 ? (cat.totalMinutes / totalMinutes) : 0.0;
      return _DonutSegment(
        label: cat.name,
        percentage: pct,
        color: cat.color,
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.translate('weekly_dist_title'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lang.translate('weekly_dist_sub'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              // Saat / % toggle (görsel)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceContainerLowest : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Text(
                        lang.translate('hour_toggle'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text(
                        '%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Donut + Legend
          Row(
            children: [
              // Donut Chart
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    segments: segments,
                    emptyColor: isDark ? AppColors.darkSurfaceContainerHighest : AppColors.surfaceContainerHighest,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lang.translate('total_label'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ),
                        ),
                        Text(
                          totalStr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 32),

              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: segments.map((seg) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: seg.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                seg.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${(seg.percentage * 100).round()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 4. VERİMLİLİK İPUCU ───
  Widget _buildEfficiencyTip() {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tips = [
      lang.translate('tip_1'),
      lang.translate('tip_2'),
      lang.translate('tip_3'),
      lang.translate('tip_4'),
    ];
    final tip = tips[DateTime.now().day % tips.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant).withValues(alpha: 0.3),
          width: 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
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
                  lang.translate('efficiency_tip_header'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── BOŞ DURUM ───
  Widget _buildEmptyState(LanguageService lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                Icons.analytics_outlined,
                size: 48,
                color: isDark ? AppColors.darkPrimary : AppColors.primaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              lang.translate('no_reports_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              lang.translate('no_reports_desc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: widget.onStartTimer,
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: Text(
                  lang.translate('start_studying_now'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5C4D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PROGRESS RING PAINTer ───
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
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
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// ─── DONUT CHART DATA ───
class _DonutSegment {
  final String label;
  final double percentage;
  final Color color;

  _DonutSegment({
    required this.label,
    required this.percentage,
    required this.color,
  });
}

// ─── DONUT CHART PAINTER ───
class _DonutChartPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final Color emptyColor;

  _DonutChartPainter({required this.segments, required this.emptyColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;
    const gapAngle = 0.03; // Small gap between segments

    var startAngle = -pi / 2;

    for (final seg in segments) {
      if (seg.percentage <= 0) continue;

      final sweepAngle = 2 * pi * seg.percentage - gapAngle;
      if (sweepAngle <= 0) continue;

      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle + gapAngle;
    }

    // Eğer hiç segment yoksa boş halka çiz
    if (segments.every((s) => s.percentage <= 0)) {
      final emptyPaint = Paint()
        ..color = emptyColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius - strokeWidth / 2, emptyPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}
