import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../l10n/app_localizations.dart';
import '../models/category_model.dart';
import '../services/language_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import '../utils/stats_calculator.dart';
import '../utils/study_day.dart';
import '../widgets/stats/category_style.dart';
import '../widgets/stats/daily_goal_sheet.dart';
import '../widgets/stats/progress_ring.dart';
import '../widgets/stats/stats_empty_card.dart';
import '../widgets/stats/stats_load_state.dart';
import '../widgets/stats/stats_text.dart';
import 'history_screen.dart';
import 'monthly_tracking_screen.dart';

/// Raporlar sekmesi: Günlük / Haftalık / Aylık. Seans verisi tek yerde (bu
/// ekranda) yüklenir ve alt sekmelere parametre olarak verilir.
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

class _ReportsScreenState extends State<ReportsScreen> with WidgetsBindingObserver {
  // Sekme yeniden görünür olduğunda veriler bu süreden eskiyse yenilenir.
  static const Duration _staleAfter = Duration(seconds: 30);
  static final Future<void> _dateFormatting = Future.wait([
    initializeDateFormatting('tr_TR', null),
    initializeDateFormatting('en_US', null),
  ]);

  int _activeTab = 0; // 0: Günlük Çalışma, 1: Haftalık Çalışma, 2: Aylık Takip
  bool _showDistributionPercent = false;

  List<StatSession> _remoteSessions = const [];
  List<StatSession> _pendingSessions = const [];
  bool _hasLoaded = false;
  ServiceErrorCode? _loadError;
  DateTime? _loadedAt;
  Future<void>? _inflight;
  bool _reloadQueued = false;
  bool _dirty = false;

  bool _visible = false;
  DateTime _today = studyDayOf(DateTime.now());
  Timer? _dayTimer;
  String? _userId = SupabaseService.instance.currentUser.value?.id;

  bool get _isLoading => _inflight != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final service = SupabaseService.instance;
    service.addStatsChangedListener(_onStatsChanged);
    service.pendingSessionCount.addListener(_onPendingCountChanged);
    service.currentUser.addListener(_onUserChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Shell, görünmeyen sekmeleri TickerMode(enabled: false) ile sarar; o
    // sırada yenileme ve gün dönümü zamanlayıcısı çalışmaz.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _visible) return;
    _visible = visible;
    if (visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _visible) _onBecameVisible();
      });
    } else {
      _cancelDayTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final service = SupabaseService.instance;
    service.removeStatsChangedListener(_onStatsChanged);
    service.pendingSessionCount.removeListener(_onPendingCountChanged);
    service.currentUser.removeListener(_onUserChanged);
    _cancelDayTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_visible) _onBecameVisible();
    } else if (state == AppLifecycleState.paused) {
      _cancelDayTimer();
    }
  }

  void _onBecameVisible() {
    _syncToday();
    _scheduleDayRollover();
    final loadedAt = _loadedAt;
    final stale = loadedAt == null || DateTime.now().difference(loadedAt) > _staleAfter;
    if (_dirty || stale || _loadError != null) unawaited(_refresh());
  }

  void _syncToday() {
    final today = studyDayOf(DateTime.now());
    if (!isSameDay(today, _today) && mounted) setState(() => _today = today);
  }

  // Yeni çalışma günü (profil diliminde 04:00) başlayınca 'bugün' ve 'bu
  // hafta' tazelenir.
  void _scheduleDayRollover() {
    _cancelDayTimer();
    final nextDayStart = studyDayStart(addDays(_today, 1));
    var wait = nextDayStart.difference(DateTime.now());
    if (wait.isNegative) wait = Duration.zero;
    _dayTimer = Timer(wait + const Duration(seconds: 1), () {
      _dayTimer = null;
      if (!mounted || !_visible) return;
      _syncToday();
      _scheduleDayRollover();
    });
  }

  void _cancelDayTimer() {
    _dayTimer?.cancel();
    _dayTimer = null;
  }

  // Yalnızca bu cihazda seans tamamlanınca / kuyruk gönderilince tetiklenir.
  void _onStatsChanged() {
    if (_visible) {
      unawaited(_refresh());
    } else {
      _dirty = true;
    }
  }

  void _onPendingCountChanged() {
    if (_visible && _hasLoaded) {
      unawaited(_reloadPending());
    } else {
      _dirty = true;
    }
  }

  void _onUserChanged() {
    if (!mounted) return;
    final userId = SupabaseService.instance.currentUser.value?.id;
    if (userId != _userId) {
      // Hesap değişti: önceki kullanıcının verisi gösterilmez.
      _userId = userId;
      _remoteSessions = const [];
      _pendingSessions = const [];
      _hasLoaded = false;
      _loadError = null;
      _loadedAt = null;
      _dirty = true;
      if (_visible) unawaited(_refresh());
    }
    // Günlük hedef ya da toplam süre değişmiş olabilir.
    setState(() {});
  }

  /// Verileri yeniler. Eşzamanlı çağrılar tek yüklemede birleşir; yükleme
  /// sürerken gelen istek, bitince bir kez daha yükletir.
  Future<void> _refresh() {
    final inflight = _inflight;
    if (inflight != null) {
      _reloadQueued = true;
      return inflight;
    }
    final load = _load().whenComplete(() {
      _inflight = null;
      if (!mounted) return;
      setState(() {});
      if (_reloadQueued) {
        _reloadQueued = false;
        if (_visible) {
          unawaited(_refresh());
        } else {
          _dirty = true;
        }
      }
    });
    _inflight = load;
    if (mounted) setState(() {});
    return load;
  }

  Future<void> _load() async {
    _dirty = false;
    final userId = _userId;
    final today = studyDayOf(DateTime.now());
    try {
      await _dateFormatting;
      // Aylık sekme önceki ayın aynı dönemini ve ayın ilk haftasının
      // kıyasını da kullandığı için önceki ayın başından itibaren çekilir.
      final since = studyDayStart(DateTime(today.year, today.month - 1, 1));
      final remote = await SupabaseService.instance.fetchStudySessions(since: since);
      final pending = await _readPending();
      if (!mounted) return;
      if (userId != _userId) {
        _reloadQueued = true;
        return;
      }
      setState(() {
        _remoteSessions = remote.map(StatSession.fromStudySession).toList(growable: false);
        _pendingSessions = pending;
        _hasLoaded = true;
        _loadError = null;
        _loadedAt = DateTime.now();
        _today = today;
      });
    } catch (e) {
      // Mevcut veriler silinmez; hata durumu ve 'Tekrar Dene' gösterilir.
      debugPrint('İstatistikler yüklenemedi: $e');
      if (mounted && userId == _userId) setState(() => _loadError = serviceErrorCodeOf(e));
    }
  }

  Future<List<StatSession>> _readPending() async {
    try {
      final pending = await SupabaseService.instance.getPendingSessions();
      return pending.map(StatSession.fromPending).toList(growable: false);
    } catch (e) {
      debugPrint('Bekleyen seanslar okunamadı: $e');
      return const [];
    }
  }

  Future<void> _reloadPending() async {
    final userId = _userId;
    final pending = await _readPending();
    if (mounted && userId == _userId) setState(() => _pendingSessions = pending);
  }

  int get _dailyGoalMinutes =>
      effectiveDailyGoalMinutes(SupabaseService.instance.currentUser.value?.dailyGoalMinutes);

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: lang,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          body: SafeArea(
            child: Column(
              children: [
                _buildTabBar(lang),
                SizedBox(
                  height: 2,
                  child: (_isLoading && _hasLoaded)
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            color: isDark ? AppColors.darkPrimary : AppColors.primary,
                            backgroundColor: Colors.transparent,
                          ),
                        )
                      : null,
                ),
                if (_hasLoaded && _loadError != null && !_isLoading) StatsStaleBanner(onRetry: _refresh),
                Expanded(child: _buildTabContent(lang)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabContent(LanguageService lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!_hasLoaded) {
      final error = _loadError;
      if (error != null && !_isLoading) return StatsErrorView(code: error, onRetry: _refresh);
      return Center(child: CircularProgressIndicator(color: isDark ? AppColors.darkPrimary : AppColors.primary));
    }

    final sessions = [..._remoteSessions, ..._pendingSessions];
    final goalMinutes = _dailyGoalMinutes;
    return switch (_activeTab) {
      0 => _buildDailyTab(sessions, goalMinutes, lang),
      1 => HistoryScreen(
          sessions: sessions,
          today: _today,
          dailyGoalMinutes: goalMinutes,
          categories: widget.categories,
          onRefresh: _refresh,
          onStartTimer: widget.onStartTimer,
        ),
      _ => MonthlyTrackingScreen(
          sessions: sessions,
          today: _today,
          categories: widget.categories,
          onRefresh: _refresh,
        ),
    };
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
    return Semantics(
      button: true,
      selected: isActive,
      child: GestureDetector(
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
      ),
    );
  }

  Widget _buildDailyTab(List<StatSession> sessions, int goalMinutes, LanguageService lang) {
    final todaySessions = sessionsBetween(sessions, _today, _today).toList();
    final user = SupabaseService.instance.currentUser.value;
    // Tam boş durum yalnızca hiç çalışmamış kullanıcıya gösterilir.
    final hasHistory = sessions.isNotEmpty || (user?.totalMinutes ?? 0) > 0;
    if (!hasHistory) return _buildFirstRunState(lang);

    final categories = totalsByCategory(todaySessions);
    final todayMinutes = sumMinutes(todaySessions);
    final todayPomodoros = todaySessions.fold<int>(0, (sum, s) => sum + s.pomodoros);
    final pendingToday = todaySessions.where((s) => s.pending).length;
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 0. Günlük Hedef
            _buildDailyGoalCard(todayMinutes, todayPomodoros, goalMinutes, pendingToday),
            const SizedBox(height: 16),

            // 1. Verimlilik Skoru
            _buildEfficiencyCard(goalPercent(todayMinutes, goalMinutes)),
            const SizedBox(height: 24),

            // 2. Bugünkü Çalışmalar
            _buildTodayHeader(lang),
            const SizedBox(height: 12),
            if (categories.isEmpty)
              StatsEmptyCard(
                icon: Icons.wb_sunny_outlined,
                title: l10n.statsNoStudyTodayTitle,
                description: l10n.statsNoStudyTodayDesc,
                actionLabel: lang.translate('start_studying_now'),
                onAction: widget.onStartTimer,
              )
            else ...[
              _buildSubjectGrid(categories),
              const SizedBox(height: 24),

              // 3. Bugünün Dağılımı (Donut)
              _buildTodayDistribution(categories, todayMinutes),
            ],
            const SizedBox(height: 24),

            // 4. Verimlilik İpucu
            _buildEfficiencyTip(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── 0. GÜNLÜK HEDEF KARTI ───
  Widget _buildDailyGoalCard(int todayMinutes, int todayPomodoros, int goalMinutes, int pendingToday) {
    final lang = LanguageService.instance;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final variant = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: () => showDailyGoalSheet(context, initialGoalMinutes: goalMinutes),
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
                Semantics(
                  label: l10n.statsTodayPomodoros(todayPomodoros),
                  excludeSemantics: true,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: (todayMinutes / goalMinutes).clamp(0.0, 1.0),
                          strokeWidth: 4,
                          backgroundColor: (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant).withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppColors.darkPrimary : AppColors.primary),
                        ),
                        Text(
                          '$todayPomodoros',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
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
                        '${StatsText.duration(todayMinutes)} / ${StatsText.duration(goalMinutes)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: variant),
                      ),
                      if (pendingToday > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 14, color: variant),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                l10n.statsPendingSessions(pendingToday),
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: variant),
                              ),
                            ),
                          ],
                        ),
                      ],
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
          Expanded(
            child: Column(
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
                      StatsText.percent(context, score),
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
          ),
          const SizedBox(width: 12),
          ExcludeSemantics(
            child: SizedBox(
              width: 80,
              height: 80,
              child: CustomPaint(
                painter: ProgressRingPainter(
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
          ),
        ],
      ),
    );
  }

  // ─── 2. BUGÜNKÜ ÇALIŞMALAR BAŞLIĞI ───
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
        Semantics(
          button: true,
          child: GestureDetector(
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
        ),
      ],
    );
  }

  CategoryStyle _styleOf(CategoryStat cat) => categoryStyleFor(
        name: cat.name,
        categoryId: cat.categoryId,
        colorHex: cat.colorHex,
        categories: widget.categories,
      );

  // ─── 2b. DERS KARTLARI ───
  Widget _buildSubjectGrid(List<CategoryStat> categories) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayCats = categories.take(4).toList(); // En fazla 4 ders

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
        final style = _styleOf(cat);

        return MergeSemantics(
          child: Container(
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
                        color: style.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(style.icon, size: 18, color: style.color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        StatsText.categoryName(context, cat.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                        ),
                      ),
                    ),
                    if (cat.pendingSessions > 0)
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 16,
                        color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                        semanticLabel: AppLocalizations.of(context)!.statsPendingSessions(cat.pendingSessions),
                      ),
                  ],
                ),
                Text(
                  StatsText.duration(cat.minutes),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── 3. BUGÜNÜN DAĞILIMI (DONUT) ───
  Widget _buildTodayDistribution(List<CategoryStat> categories, int totalMinutes) {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final segments = categories
        .map((cat) => _DonutSegment(
              label: StatsText.categoryName(context, cat.name),
              minutes: cat.minutes,
              percentage: totalMinutes > 0 ? cat.minutes / totalMinutes : 0.0,
              color: _styleOf(cat).color,
            ))
        .toList();
    String valueOf(_DonutSegment seg) => _showDistributionPercent
        ? StatsText.percent(context, (seg.percentage * 100).round())
        : StatsText.duration(seg.minutes);
    final title = lang.translate('weekly_dist_title');
    final summary = '$title, ${lang.translate('total_label')} ${StatsText.duration(totalMinutes)}: '
        '${segments.map((s) => '${s.label} ${StatsText.duration(s.minutes)} '
            '${StatsText.percent(context, (s.percentage * 100).round())}').join(', ')}';

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
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
              ),
              _buildDistributionToggle(),
            ],
          ),
          const SizedBox(height: 20),
          Semantics(
            label: summary,
            excludeSemantics: true,
            child: Row(
              children: [
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
                            StatsText.duration(totalMinutes),
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
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: segments.map((seg) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: seg.color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                seg.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              valueOf(seg),
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
          ),
        ],
      ),
    );
  }

  // Lejantı süre ya da yüzde olarak gösterir.
  Widget _buildDistributionToggle() {
    final lang = LanguageService.instance;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget option({required String text, required String semanticLabel, required bool percent}) {
      final selected = _showDistributionPercent == percent;
      return Semantics(
        button: true,
        selected: selected,
        label: semanticLabel,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => setState(() => _showDistributionPercent = percent),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: selected
                ? BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceContainerLowest : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
                  )
                : null,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected
                    ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                    : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainer : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(text: lang.translate('hour_toggle'), semanticLabel: l10n.statsShowAsDuration, percent: false),
          option(text: '%', semanticLabel: l10n.statsShowAsPercent, percent: true),
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
    final tip = tips[_today.day % tips.length];

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

  // ─── İLK KULLANIM (hiç seans yok) ───
  Widget _buildFirstRunState(LanguageService lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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

// ─── DONUT GRAFİK VERİSİ ───
class _DonutSegment {
  final String label;
  final int minutes;
  final double percentage;
  final Color color;

  const _DonutSegment({
    required this.label,
    required this.minutes,
    required this.percentage,
    required this.color,
  });
}

// ─── DONUT GRAFİK ───
class _DonutChartPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final Color emptyColor;

  _DonutChartPainter({required this.segments, required this.emptyColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;
    const gapAngle = 0.03; // Dilimler arası küçük boşluk

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

    // Hiç dilim yoksa boş halka çiz
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
