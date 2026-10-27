import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../l10n/app_localizations.dart';
import '../models/category_model.dart';
import '../models/exam_model.dart';
import '../services/language_service.dart';
import '../services/server_clock.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import '../utils/responsive.dart';
import '../utils/stats_calculator.dart';
import '../utils/study_day.dart';
import '../widgets/stats/category_style.dart';
import '../widgets/stats/daily_goal_sheet.dart';
import '../widgets/stats/progress_ring.dart';
import '../widgets/stats/stats_empty_card.dart';
import '../widgets/stats/stats_layout.dart';
import '../widgets/stats/stats_load_state.dart';
import '../widgets/stats/stats_text.dart';
import '../widgets/stats/session_type_summary.dart';
import 'history_screen.dart';
import 'monthly_tracking_screen.dart';
import 'rejected_sessions_screen.dart';

/// Raporlar sekmesi: Günlük / Haftalık / Aylık. Seans verisi tek yerde (bu
/// ekranda) yüklenir ve alt sekmelere parametre olarak verilir.
class ReportsScreen extends StatefulWidget {
  final List<CourseCategory> categories;
  final VoidCallback? onStartTimer;
  final VoidCallback? onOpenExams;
  final Future<List<ExamAttempt>> Function()? loadExamAttempts;
  final bool Function()? isExamHistoryStale;

  /// Testte sahte servis verilir; uygulamada [SupabaseService.instance].
  @visibleForTesting
  final SupabaseService? service;

  const ReportsScreen({
    super.key,
    required this.categories,
    this.onStartTimer,
    this.onOpenExams,
    this.loadExamAttempts,
    this.isExamHistoryStale,
    this.service,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with WidgetsBindingObserver {
  // Sekme yeniden görünür olduğunda veriler bu süreden eskiyse yenilenir.
  static const Duration _staleAfter = Duration(seconds: 30);
  // Tarih biçimleri bir kez yüklenir. (Önbelleğe alınmış tek bir Future
  // yerine bayrak: Future onu oluşturan zone'a bağlı kalıyordu.)
  static bool _dateFormattingReady = false;

  static Future<void> _ensureDateFormatting() async {
    if (_dateFormattingReady) return;
    await Future.wait([
      initializeDateFormatting('tr_TR', null),
      initializeDateFormatting('en_US', null),
    ]);
    _dateFormattingReady = true;
  }

  int _activeTab = 0; // 0: Günlük Çalışma, 1: Haftalık Çalışma, 2: Aylık Takip
  bool _showDistributionPercent = false;

  List<StatSession> _remoteSessions = const [];
  List<ExamAttempt> _examAttempts = const [];
  int _ownerEpoch = 0;

  /// Cihazdaki bekleyen seans kuyruğu (ham). İstatistiğe girenler build'de
  /// [pendingStatSessions] ile seçilir.
  List<PendingSession> _pendingQueue = const [];

  /// Sunucunun kalıcı olarak reddettiği (cihazda listelenen) seans sayısı.
  int _rejectedCount = 0;

  /// Gösterilecek veri var (sunucu verisi ya da en azından bekleyenler).
  bool _hasLoaded = false;

  /// Sunucu verisi en az bir kez yüklendi.
  bool _remoteLoaded = false;
  ServiceErrorCode? _loadError;
  DateTime? _loadedAt;
  Future<void>? _inflight;
  bool _reloadQueued = false;
  bool _dirty = false;

  bool _visible = false;
  late DateTime _today = studyDayOf(_now());
  Timer? _dayTimer;
  String? _userId;

  bool get _isLoading => _inflight != null;

  SupabaseService get _service => widget.service ?? SupabaseService.instance;

  // 'Bugün' sunucu saatiyle: bekleyen seansın günü de kuyruğun gönderdiği
  // düzeltilmiş saatle hesaplanıyor; ikisi aynı saate bakmalı.
  DateTime _now() =>
      DateTime.now().add(ServerClock.correctionFor(_service.serverClockOffset));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final service = _service;
    _userId = service.currentUser.value?.id;
    service.addStatsChangedListener(_onStatsChanged);
    service.pendingSessionCount.addListener(_onPendingCountChanged);
    service.currentUser.addListener(_onUserChanged);
    // Kategori adı/rengi değişince sunucu birleşimi (ad, renk, ikon) bayatlar.
    service.categoriesRevision.addListener(_onCategoriesChanged);
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
    final service = _service;
    service.removeStatsChangedListener(_onStatsChanged);
    service.pendingSessionCount.removeListener(_onPendingCountChanged);
    service.currentUser.removeListener(_onUserChanged);
    service.categoriesRevision.removeListener(_onCategoriesChanged);
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
    final stale =
        loadedAt == null || DateTime.now().difference(loadedAt) > _staleAfter;
    if (_dirty || stale || _loadError != null) unawaited(_refresh());
  }

  void _syncToday() {
    final today = studyDayOf(_now());
    if (!isSameDay(today, _today) && mounted) setState(() => _today = today);
  }

  // Yeni çalışma günü (profil diliminde 04:00) başlayınca 'bugün' ve 'bu
  // hafta' tazelenir.
  void _scheduleDayRollover() {
    _cancelDayTimer();
    final nextDayStart = studyDayStart(addDays(_today, 1));
    var wait = nextDayStart.difference(_now());
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

  // Kategori eklendi, adı/rengi değişti, arşivlendi: görünürse hemen,
  // değilse sekmeye dönüşte (30 sn beklemeden) yenilenir.
  void _onCategoriesChanged() => _onStatsChanged();

  void _onPendingCountChanged() {
    if (_visible && _hasLoaded) {
      unawaited(_reloadPending());
    } else {
      _dirty = true;
    }
  }

  void _onUserChanged() {
    if (!mounted) return;
    final userId = _service.currentUser.value?.id;
    if (userId != _userId) {
      // Hesap değişti: önceki kullanıcının verisi gösterilmez.
      _userId = userId;
      _ownerEpoch++;
      _remoteSessions = const [];
      _examAttempts = const [];
      _pendingQueue = const [];
      _rejectedCount = 0;
      _hasLoaded = false;
      _remoteLoaded = false;
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
    final epoch = _ownerEpoch;
    final today = studyDayOf(_now());
    // Kuyruk uzak okumadan ÖNCE ve ondan bağımsız okunur: (1) çevrimdışıyken
    // de bekleyen seanslar görünür; (2) bu arada gönderilen seans iki listede
    // birden olursa client_uuid ile tekilleşir, hiçbirinde olmama durumu
    // oluşmaz.
    final queue = await _readQueue();
    final rejectedCount = await _readRejectedCount();
    List<ExamAttempt>? nextExams;
    ServiceErrorCode? examError;
    final loadExams = widget.loadExamAttempts;
    if (loadExams != null) {
      try {
        nextExams = await loadExams();
        if (widget.isExamHistoryStale?.call() == true) {
          examError = ServiceErrorCode.network;
        }
      } catch (error) {
        examError = serviceErrorCodeOf(error);
      }
    }
    if (!mounted || epoch != _ownerEpoch || userId != _userId) return;
    try {
      await _ensureDateFormatting();
      // Aylık sekme önceki ayın aynı dönemini ve ayın ilk haftasının
      // kıyasını da kullandığı için önceki ayın başından itibaren çekilir.
      final since = studyDayStart(DateTime(today.year, today.month - 1, 1));
      final remote = await _service.fetchStudySessions(since: since);
      if (!mounted) return;
      if (userId != _userId || epoch != _ownerEpoch) {
        _reloadQueued = true;
        return;
      }
      setState(() {
        _remoteSessions = remote
            .map(StatSession.fromStudySession)
            .toList(growable: false);
        if (nextExams != null) _examAttempts = nextExams;
        _pendingQueue = queue;
        _rejectedCount = rejectedCount;
        _hasLoaded = true;
        _remoteLoaded = true;
        _loadError = examError;
        _loadedAt = DateTime.now();
        _today = today;
      });
    } catch (e) {
      // Mevcut veriler silinmez; hata durumu ve 'Tekrar Dene' gösterilir.
      debugPrint('İstatistikler yüklenemedi: $e');
      if (!mounted || userId != _userId || epoch != _ownerEpoch) return;
      final delivered = await _deliveredSince(queue);
      if (!mounted || userId != _userId || epoch != _ownerEpoch) return;
      setState(() {
        if (nextExams != null) _examAttempts = nextExams;
        _loadError = serviceErrorCodeOf(e);
        _pendingQueue = queue;
        _rejectedCount = rejectedCount;
        if (delivered.isNotEmpty) {
          _remoteSessions = [..._remoteSessions, ...delivered];
        }
        // Sunucu verisi hiç alınamadıysa bekleyenler yine de gösterilir.
        if (!_hasLoaded &&
            (queue.isNotEmpty || _examAttempts.any((a) => a.isCompleted))) {
          _hasLoaded = true;
          _today = today;
        }
      });
    }
  }

  Future<List<PendingSession>> _readQueue() async {
    try {
      return await _service.getPendingSessions();
    } catch (e) {
      debugPrint('Bekleyen seanslar okunamadı: $e');
      return _pendingQueue;
    }
  }

  Future<int> _readRejectedCount() async {
    try {
      return (await _service.getRejectedSessions()).length;
    } catch (e) {
      debugPrint('Reddedilen seanslar okunamadı: $e');
      return _rejectedCount;
    }
  }

  /// Ekranda bekleyen olarak gösterilip artık kuyrukta olmayan seanslar
  /// sunucuya ulaşmıştır (kalıcı reddedilenler hariç). Uzak liste
  /// yenilenemediğinde toplam düşmesin diye bunlar sunucu seansı olarak
  /// tutulur; bir sonraki başarılı yükleme listeyi baştan kurar.
  Future<List<StatSession>> _deliveredSince(
    List<PendingSession> queueNow,
  ) async {
    final stillQueued = {for (final p in queueNow) p.clientUuid};
    final gone = _pendingQueue
        .where((p) => !stillQueued.contains(p.clientUuid))
        .toList();
    if (gone.isEmpty) return const [];
    final Set<String> rejected;
    try {
      rejected = {
        for (final r in await _service.getRejectedSessions()) r.clientUuid,
      };
    } catch (e) {
      debugPrint('Reddedilen seanslar okunamadı: $e');
      return const [];
    }
    final known = {
      for (final s in _remoteSessions)
        if (s.clientUuid != null) s.clientUuid!.toLowerCase(),
    };
    return [
      for (final s in pendingStatSessions(
        gone,
        clockOffset: _service.serverClockOffset,
      ))
        if (!rejected.contains(s.clientUuid) &&
            !known.contains(s.clientUuid!.toLowerCase()))
          s.copyWith(pending: false),
    ];
  }

  /// Kuyruk değişince (yerel, ucuz okuma). Bir seans kuyruktan çıktıysa
  /// gönderilmiştir: bekleyen ve sunucu verisi birlikte yenilenir; aksi
  /// halde toplam önce düşüp uzak okuma bitince geri gelirdi.
  Future<void> _reloadPending() async {
    final userId = _userId;
    final queue = await _readQueue();
    if (!mounted || userId != _userId) return;
    final now = {for (final p in queue) p.clientUuid};
    if (_pendingQueue.any((p) => !now.contains(p.clientUuid))) {
      unawaited(_refresh());
      return;
    }
    setState(() => _pendingQueue = queue);
  }

  int get _dailyGoalMinutes =>
      effectiveDailyGoalMinutes(_service.currentUser.value?.dailyGoalMinutes);

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
                // Sekme çubuğu, yükleme çizgisi ve uyarı geniş ekranda pano
                // genişliğinde ortalanır.
                ContentWidth(
                  maxWidth: ContentWidth.dashboard,
                  child: _buildTabBar(lang),
                ),
                ContentWidth(
                  maxWidth: ContentWidth.dashboard,
                  child: SizedBox(
                    height: 2,
                    child: (_isLoading && _hasLoaded)
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: LinearProgressIndicator(
                              minHeight: 2,
                              color: isDark
                                  ? AppColors.darkPrimary
                                  : AppColors.primary,
                              backgroundColor: Colors.transparent,
                            ),
                          )
                        : null,
                  ),
                ),
                if (_hasLoaded && _loadError != null && !_isLoading)
                  ContentWidth(
                    maxWidth: ContentWidth.dashboard,
                    child: StatsStaleBanner(
                      onRetry: _refresh,
                      message: _remoteLoaded
                          ? null
                          : AppLocalizations.of(
                              context,
                            )!.statsOfflinePendingOnly,
                    ),
                  ),
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
      if (error != null && !_isLoading) {
        return StatsErrorView(code: error, onRetry: _refresh);
      }
      return Center(
        child: CircularProgressIndicator(
          color: isDark ? AppColors.darkPrimary : AppColors.primary,
        ),
      );
    }

    final study = mergeStatSessions(
      remote: _remoteSessions,
      pending: pendingStatSessions(
        _pendingQueue,
        clockOffset: _service.serverClockOffset,
      ),
      categories: widget.categories,
    );
    final sessions = combineStudyAndExamSessions(
      study: study,
      exams: _examAttempts,
    );
    final goalMinutes = _dailyGoalMinutes;
    return switch (_activeTab) {
      0 => DailyReportView(
        sessions: sessions,
        today: _today,
        dailyGoalMinutes: goalMinutes,
        // Tam boş durum yalnızca hiç çalışmamış kullanıcıya gösterilir.
        hasHistory:
            sessions.isNotEmpty ||
            (_service.currentUser.value?.totalMinutes ?? 0) > 0,
        categories: widget.categories,
        onRefresh: _refresh,
        showDistributionPercent: _showDistributionPercent,
        onDistributionModeChanged: (percent) =>
            setState(() => _showDistributionPercent = percent),
        onShowDetails: () => setState(() => _activeTab = 1),
        onStartTimer: widget.onStartTimer,
        onOpenExams: widget.onOpenExams,
      ),
      1 => HistoryScreen(
        sessions: sessions,
        today: _today,
        dailyGoalMinutes: goalMinutes,
        categories: widget.categories,
        onRefresh: _refresh,
        onStartTimer: widget.onStartTimer,
        onOpenExams: widget.onOpenExams,
        rejectedSessionCount: _rejectedCount,
        onShowRejectedSessions: () => openRejectedSessions(context),
      ),
      _ => MonthlyTrackingScreen(
        sessions: sessions,
        today: _today,
        categories: widget.categories,
        onRefresh: _refresh,
        onOpenExams: widget.onOpenExams,
      ),
    };
  }

  Widget _buildTabBar(LanguageService lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Yatay telefonda dikey alan kıt: çubuk daha az yer kaplar.
    final short = Responsive.of(context).isShortHeight;
    return Container(
      margin: EdgeInsets.fromLTRB(24, short ? 4 : 12, 24, short ? 4 : 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                (isDark
                        ? AppColors.darkOutlineVariant
                        : AppColors.outlineVariant)
                    .withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      // Sekmeler sığıyorsa ortalanır (geniş ekran), sığmıyorsa yatay kaydırılır.
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTabItem(
                  label: lang.translate('reports_tab_subject'),
                  isActive: _activeTab == 0,
                  short: short,
                  onTap: () => setState(() => _activeTab = 0),
                ),
                const SizedBox(width: 24),
                _buildTabItem(
                  label: lang.translate('reports_tab_history'),
                  isActive: _activeTab == 1,
                  short: short,
                  onTap: () => setState(() => _activeTab = 1),
                ),
                const SizedBox(width: 24),
                _buildTabItem(
                  label: lang.translate('reports_tab_monthly'),
                  isActive: _activeTab == 2,
                  short: short,
                  onTap: () => setState(() => _activeTab = 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required bool isActive,
    required bool short,
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
          padding: EdgeInsets.only(bottom: short ? 8 : 12),
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
                  : (isDark
                        ? AppColors.darkOnSurfaceVariant
                        : AppColors.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}

/// Raporlar > Günlük Çalışma. Veriler [ReportsScreen]'den gelir; ekran
/// Supabase'e doğrudan bağlı değildir (yalnızca hedef sayfası kaydederken).
///
/// Düzen: dikey telefonda tek sütun (ders kartları 2'li). Orta genişlikte
/// özet kartları 2'li, ders kartları 4'lü; geniş ekranda özet kartları 3'lü,
/// ders kartları ile dağılım grafiği yan yana.
class DailyReportView extends StatelessWidget {
  const DailyReportView({
    super.key,
    required this.sessions,
    required this.today,
    required this.dailyGoalMinutes,
    required this.hasHistory,
    required this.categories,
    required this.onRefresh,
    required this.showDistributionPercent,
    required this.onDistributionModeChanged,
    this.onShowDetails,
    this.onStartTimer,
    this.onOpenExams,
  });

  final List<StatSession> sessions;

  /// Bugünün çalışma günü (04:00 kuralı).
  final DateTime today;
  final int dailyGoalMinutes;

  /// false ise kullanıcı hiç çalışmamıştır: ilk kullanım durumu gösterilir.
  final bool hasHistory;
  final List<CourseCategory> categories;
  final Future<void> Function() onRefresh;

  /// Dağılım lejantı yüzde mi (true) süre mi (false) gösteriyor.
  final bool showDistributionPercent;
  final ValueChanged<bool> onDistributionModeChanged;
  final VoidCallback? onShowDetails;
  final VoidCallback? onStartTimer;
  final VoidCallback? onOpenExams;

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    if (!hasHistory) return _buildFirstRunState(context, lang);

    final todaySessions = sessionsBetween(sessions, today, today).toList();
    final categoryStats = totalsByCategory(todaySessions);
    final todayMinutes = sumMinutes(todaySessions);
    final todayPomodoros = todaySessions.fold<int>(
      0,
      (sum, s) => sum + s.pomodoros,
    );
    final pendingToday = todaySessions.where((s) => s.pending).length;
    final l10n = AppLocalizations.of(context)!;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = StatsLayout.of(context, constraints.maxWidth);

          // 0. Günlük Hedef  1. Verimlilik Skoru  4. Verimlilik İpucu
          final goalCard = _buildDailyGoalCard(
            context,
            todayMinutes,
            todayPomodoros,
            pendingToday,
          );
          final efficiencyCard = _buildEfficiencyCard(context, todayMinutes);
          final tip = _buildEfficiencyTip(context);
          // Geniş ekranda ipucu da özet satırına katılır (3 sütun).
          final tipInSummary = layout.isExpanded;
          final counts = sessionTypeCounts(sessions, today, today);

          // 2-3. Bugünkü çalışmalar ve dağılım
          final Widget todayContent;
          if (categoryStats.isEmpty) {
            todayContent = StatsEmptyCard(
              icon: Icons.wb_sunny_outlined,
              title: l10n.statsNoStudyTodayTitle,
              description: l10n.statsNoStudyTodayDesc,
              actionLabel: lang.translate('start_studying_now'),
              onAction: onStartTimer,
            );
          } else if (layout.isExpanded) {
            // Ders kartları (2x2) ile dağılım grafiği yan yana, eşit yükseklikte.
            todayContent = StatsGrid(
              columns: 2,
              children: [
                _buildSubjectGrid(
                  context,
                  categoryStats,
                  columns: 2,
                  width: statsCellWidth(layout.contentWidth, 2, 16),
                  keepAspect: false,
                ),
                _buildTodayDistribution(context, categoryStats, todayMinutes),
              ],
            );
          } else {
            todayContent = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSubjectGrid(
                  context,
                  categoryStats,
                  columns: layout.columns(compact: 2, medium: 4, expanded: 4),
                  width: layout.contentWidth,
                  keepAspect: !layout.isWide,
                ),
                const SizedBox(height: 24),
                _buildTodayDistribution(context, categoryStats, todayMinutes),
              ],
            );
          }

          return StatsScrollView(
            layout: layout,
            maxWidth: ContentWidth.dashboard,
            children: [
              if (layout.isWide)
                StatsGrid(
                  columns: tipInSummary ? 3 : 2,
                  children: [goalCard, efficiencyCard, if (tipInSummary) tip],
                )
              else ...[
                goalCard,
                const SizedBox(height: 16),
                efficiencyCard,
              ],
              const SizedBox(height: 24),
              _buildTodayHeader(context, lang),
              const SizedBox(height: 12),
              SessionTypeSummary(counts: counts, onOpenExams: onOpenExams),
              const SizedBox(height: 24),
              todayContent,
              if (!tipInSummary) ...[const SizedBox(height: 24), tip],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  // ─── 0. GÜNLÜK HEDEF KARTI ───
  Widget _buildDailyGoalCard(
    BuildContext context,
    int todayMinutes,
    int todayPomodoros,
    int pendingToday,
  ) {
    final lang = LanguageService.instance;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final variant = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.onSurfaceVariant;
    final goalMinutes = dailyGoalMinutes;

    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: () =>
              showDailyGoalSheet(context, initialGoalMinutes: goalMinutes),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceContainerLowest
                  : AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    (isDark
                            ? AppColors.darkOutlineVariant
                            : AppColors.outlineVariant)
                        .withValues(alpha: 0.4),
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
                          backgroundColor:
                              (isDark
                                      ? AppColors.darkOutlineVariant
                                      : AppColors.outlineVariant)
                                  .withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? AppColors.darkPrimary : AppColors.primary,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '$todayPomodoros',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkOnSurface
                                    : AppColors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.translate('daily_goal_label'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkOnSurface
                              : AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${StatsText.duration(todayMinutes)} / ${StatsText.duration(goalMinutes)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: variant,
                        ),
                      ),
                      if (pendingToday > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 14,
                              color: variant,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                l10n.statsPendingSessions(pendingToday),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: variant,
                                ),
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
  // Yüzde hedefin ne kadarının yapıldığıdır ve kırpılmaz (300 / 200 dk →
  // %150); halka %100'de dolar. Önceki dönemle kıyas olmadığı için trend oku
  // yok; hedefe ulaşılınca onay ikonu.
  Widget _buildEfficiencyCard(BuildContext context, int todayMinutes) {
    final lang = LanguageService.instance;
    final l10n = AppLocalizations.of(context)!;
    final score = goalProgressPercent(todayMinutes, dailyGoalMinutes);
    final reached = todayMinutes >= dailyGoalMinutes;
    final message = todayMinutes > dailyGoalMinutes
        ? lang.translate('efficiency_msg_exceeded')
        : reached
        ? l10n.statsGoalReached
        : score >= 50
        ? lang.translate('efficiency_msg_close')
        : lang.translate('efficiency_msg_low');
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
              mainAxisSize: MainAxisSize.min,
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
                // Dar kartta ya da büyük yazı boyutunda sığmazsa küçülür.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
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
                      if (reached) ...[
                        const SizedBox(width: 6),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
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
                  progress: goalPercent(todayMinutes, dailyGoalMinutes) / 100,
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
  Widget _buildTodayHeader(BuildContext context, LanguageService lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            lang.translate('today_studies_header'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          child: GestureDetector(
            onTap: onShowDetails,
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
    iconName: cat.iconName,
    categories: categories,
  );

  // En fazla 4 kart: 4'ten fazla ders varsa ilk 3'ü ve kalanların toplamı
  // ("+N kategori daha"); kartların toplamı her zaman bugünün toplamıdır.
  static const int _maxSubjectCards = 4;

  // ─── 2b. DERS KARTLARI ───
  // [width] ızgaranın genişliği. Telefonda ([keepAspect]) kartlar bugünkü
  // gibi 3:2; geniş ekranda gereksiz uzamaz. Büyük yazı boyutunda kartlar
  // birlikte uzar.
  Widget _buildSubjectGrid(
    BuildContext context,
    List<CategoryStat> categoryStats, {
    required int columns,
    required double width,
    required bool keepAspect,
  }) {
    const spacing = 12.0;
    final partition = categoryCardPartition(
      categoryStats,
      maximum: _maxSubjectCards,
    );
    final displayCats = partition.visible;
    final rest = partition.remaining;
    final cellWidth = statsCellWidth(width, columns, spacing);
    final minHeight = keepAspect
        ? cellWidth / 1.5
        : min(cellWidth / 1.5, 110.0);

    return StatsGrid(
      columns: columns,
      spacing: spacing,
      runSpacing: spacing,
      children: [
        for (final cat in displayCats)
          _buildSubjectCard(context, cat, minHeight),
        if (rest.isNotEmpty)
          _buildSubjectCard(
            context,
            CategoryStat(
              name: AppLocalizations.of(
                context,
              )!.statsMoreCategories(rest.length),
              minutes: _sumOf(rest, (c) => c.minutes),
              sessions: _sumOf(rest, (c) => c.sessions),
              pomodoros: _sumOf(rest, (c) => c.pomodoros),
              pendingSessions: _sumOf(rest, (c) => c.pendingSessions),
            ),
            minHeight,
            aggregate: true,
          ),
      ],
    );
  }

  static int _sumOf(List<CategoryStat> list, int Function(CategoryStat c) f) =>
      list.fold(0, (a, c) => a + f(c));

  Widget _buildSubjectCard(
    BuildContext context,
    CategoryStat cat,
    double minHeight, {
    bool aggregate = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = aggregate
        ? const CategoryStyle(
            color: kStatsNeutralColor,
            icon: Icons.more_horiz_rounded,
          )
        : _styleOf(cat);

    return MergeSemantics(
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainerLow
              : AppColors.surfaceContainerLow,
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
                    aggregate
                        ? cat.name
                        : StatsText.categoryName(
                            context,
                            cat.name,
                            categoryId: cat.categoryId,
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkOnSurface
                          : AppColors.onSurface,
                    ),
                  ),
                ),
                if (cat.pendingSessions > 0)
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 16,
                    color: isDark
                        ? AppColors.darkOnSurfaceVariant
                        : AppColors.onSurfaceVariant,
                    semanticLabel: AppLocalizations.of(
                      context,
                    )!.statsPendingSessions(cat.pendingSessions),
                  ),
              ],
            ),
            const SizedBox(height: 8),
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
  }

  // ─── 3. BUGÜNÜN DAĞILIMI (DONUT) ───
  Widget _buildTodayDistribution(
    BuildContext context,
    List<CategoryStat> categoryStats,
    int totalMinutes,
  ) {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Lejant yüzdeleri tek tek yuvarlanmaz; toplamları tam 100 olur.
    final percents = roundedPercents([
      for (final cat in categoryStats) cat.minutes,
    ]);
    final segments = [
      for (var i = 0; i < categoryStats.length; i++)
        _DonutSegment(
          label: StatsText.categoryName(
            context,
            categoryStats[i].name,
            categoryId: categoryStats[i].categoryId,
          ),
          minutes: categoryStats[i].minutes,
          percentage: totalMinutes > 0
              ? categoryStats[i].minutes / totalMinutes
              : 0.0,
          roundedPercent: percents[i],
          color: _styleOf(categoryStats[i]).color,
        ),
    ];
    String valueOf(_DonutSegment seg) => showDistributionPercent
        ? StatsText.percent(context, seg.roundedPercent)
        : StatsText.duration(seg.minutes);
    final title = lang.translate('weekly_dist_title');
    final summary =
        '$title, ${lang.translate('total_label')} ${StatsText.duration(totalMinutes)}: '
        '${segments.map((s) => '${s.label} ${StatsText.duration(s.minutes)} '
            '${StatsText.percent(context, s.roundedPercent)}').join(', ')}';
    // Çok dar ekranda (320 pt telefon, iPad Slide Over) lejant halkanın yanına
    // sığmıyor; altına iner. Karar ekran genişliğinden: geniş ekranda kart
    // IntrinsicHeight içinde, LayoutBuilder orada kullanılamaz.
    final legendBelow = MediaQuery.sizeOf(context).width < 360;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLowest
            : AppColors.surfaceContainerLowest,
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
                        color: isDark
                            ? AppColors.darkOnSurface
                            : AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lang.translate('weekly_dist_sub'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.darkOnSurfaceVariant
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDistributionToggle(context),
            ],
          ),
          const SizedBox(height: 20),
          Semantics(
            label: summary,
            excludeSemantics: true,
            child: Flex(
              direction: legendBelow ? Axis.vertical : Axis.horizontal,
              mainAxisSize: legendBelow ? MainAxisSize.min : MainAxisSize.max,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    painter: _DonutChartPainter(
                      segments: segments,
                      emptyColor: isDark
                          ? AppColors.darkSurfaceContainerHighest
                          : AppColors.surfaceContainerHighest,
                    ),
                    // Halkanın içine sığmazsa (büyük yazı boyutu) küçülür.
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                lang.translate('total_label'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.darkOnSurface
                                      : AppColors.onSurface,
                                ),
                              ),
                              Text(
                                StatsText.duration(totalMinutes),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 24, height: 16),
                Expanded(
                  // Lejant alttayken esnek değil: dikey kaydırmada yükseklik sınırsız.
                  flex: legendBelow ? 0 : 1,
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
                              decoration: BoxDecoration(
                                color: seg.color,
                                shape: BoxShape.circle,
                              ),
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
                                  color: isDark
                                      ? AppColors.darkOnSurfaceVariant
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Dar kartta ya da büyük yazı boyutunda değer küçülür.
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 100),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  valueOf(seg),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? AppColors.darkOnSurface
                                        : AppColors.onSurface,
                                  ),
                                ),
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
  Widget _buildDistributionToggle(BuildContext context) {
    final lang = LanguageService.instance;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget option({
      required String text,
      required String semanticLabel,
      required bool percent,
    }) {
      final selected = showDistributionPercent == percent;
      return Semantics(
        button: true,
        selected: selected,
        label: semanticLabel,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => onDistributionModeChanged(percent),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: selected
                ? BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceContainerLowest
                        : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                      ),
                    ],
                  )
                : null,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected
                    ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                    : (isDark
                          ? AppColors.darkOnSurfaceVariant
                          : AppColors.onSurfaceVariant),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainer
            : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(
            text: lang.translate('hour_toggle'),
            semanticLabel: l10n.statsShowAsDuration,
            percent: false,
          ),
          option(
            text: '%',
            semanticLabel: l10n.statsShowAsPercent,
            percent: true,
          ),
        ],
      ),
    );
  }

  // ─── 4. VERİMLİLİK İPUCU ───
  Widget _buildEfficiencyTip(BuildContext context) {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // İlk ipucu eskiden kaynaksız bir yüzde iddiası içeriyordu ('tip_1').
    final tips = [
      AppLocalizations.of(context)!.statsTipFocusBlock,
      lang.translate('tip_2'),
      lang.translate('tip_3'),
      lang.translate('tip_4'),
    ];
    final tip = tips[today.day % tips.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color:
              (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant)
                  .withValues(alpha: 0.3),
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.translate('efficiency_tip_header'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkOnSurface
                        : AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.darkOnSurfaceVariant
                        : AppColors.onSurfaceVariant,
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
  Widget _buildFirstRunState(BuildContext context, LanguageService lang) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        // Geniş ekranda düğme ve metin form genişliğinde ortalanır.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ContentWidth.form),
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
                  color: isDark
                      ? AppColors.darkPrimary
                      : AppColors.primaryContainer,
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
                  color: isDark
                      ? AppColors.darkOnSurfaceVariant
                      : AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              // En az 50 px; büyük yazı boyutunda düğme birlikte uzar.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onStartTimer,
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: Text(
                    lang.translate('start_studying_now'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5C4D),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
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
      ),
    );
  }
}

// ─── DONUT GRAFİK VERİSİ ───
class _DonutSegment {
  final String label;
  final int minutes;
  final double percentage;

  /// Lejantta gösterilen tamsayı yüzde (tüm dilimlerin toplamı 100).
  final int roundedPercent;
  final Color color;

  const _DonutSegment({
    required this.label,
    required this.minutes,
    required this.percentage,
    required this.roundedPercent,
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
