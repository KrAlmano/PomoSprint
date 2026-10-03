import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../utils/text_util.dart';
import '../models/category_model.dart';
import '../widgets/hourglass_widget.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';
import '../services/timer_persistence.dart';

class TimerScreen extends StatefulWidget {
  final List<CourseCategory> categories;

  /// Süren seansın cihazda saklandığı anahtar (kullanıcı kimliği).
  final String sessionOwnerKey;

  /// Kimlik bilinmeden önce kullanılmış anahtar (e-posta); oradaki kayıt taşınır.
  final String? legacySessionOwnerKey;
  final VoidCallback onOpenSettings;

  /// Süre dolunca çağrılır; seans gönderilip sonuç bildirilince tamamlanır.
  /// Ardından cihazdaki seans kaydı silinir.
  final Future<void> Function(ActiveTimerSession session) onSessionCompleted;

  /// Sayaç başlayınca/devam edince (kalan dakikayla) ve durunca çağrılır.
  final void Function(bool isRunning, String categoryName, int minutesLeft)? onTimerStateChanged;
  final String? userSegment;

  const TimerScreen({
    super.key,
    required this.categories,
    required this.sessionOwnerKey,
    this.legacySessionOwnerKey,
    required this.onOpenSettings,
    required this.onSessionCompleted,
    this.onTimerStateChanged,
    this.userSegment,
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  static const int _maxPauses = 1;

  int totalSeconds = timerDurationSeconds(25);
  int remaining = timerDurationSeconds(25);
  int loggedMinutes = 25;
  bool isRunning = false;
  bool _isStarting = false; // BAŞLAT butonuna çift tıklama koruması
  Timer? _timer;
  String selectedCategoryId = '';
  String selectedCategoryName = '';

  // Süren ya da duraklatılmış seans (null: seans yok). Başlat, duraklat ve
  // devamda cihaza yazılır; uygulama öldürülse bile açılışta geri yüklenir.
  // Kalan süre her tick'te bitiş anından hesaplanır.
  ActiveTimerSession? _session;
  int _foregroundSeconds = 0;

  bool get _hasSession => _session != null;
  int get _pauseCreditsLeft => _maxPauses - (_session?.pauseUsedCount ?? 0);
  TimerPersistence get _store => TimerPersistence.instance;

  static bool get _isInForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  static int _minutesLeft(int seconds) => (seconds / 60).ceil();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _validateSelectedCategory();
    unawaited(_restoreSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    // Seans cihazda saklı olduğu için ekran kapanınca (ör. çıkış) iptal
    // edilmez; aynı hesapla açılınca kaldığı yerden sürer.
    _persistSession();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Arka planda periyodik timer durmuş olabilir; kalan süreyi bitiş
      // anından yeniden hesapla (süre dolduysa seans tamamlanır).
      if (isRunning) _tick(countForeground: false);
    } else if (state == AppLifecycleState.paused) {
      _persistSession();
    }
  }

  @override
  void didUpdateWidget(TimerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionOwnerKey != widget.sessionOwnerKey && _hasSession) {
      unawaited(_store.clear(oldWidget.sessionOwnerKey));
      _persistSession();
    }
    _validateSelectedCategory();
  }

  void _persistSession() {
    final session = _session;
    if (session == null) return;
    unawaited(_store.save(widget.sessionOwnerKey, session.withForegroundSeconds(_foregroundSeconds)));
  }

  Future<void> _restoreSession() async {
    final saved = await _store.load(widget.sessionOwnerKey, legacyOwnerKey: widget.legacySessionOwnerKey);
    if (saved == null || !mounted || _hasSession || _isStarting) return;

    final now = DateTime.now();
    _foregroundSeconds = saved.foregroundSeconds;
    setState(() {
      loggedMinutes = saved.durationMinutes;
      totalSeconds = saved.totalSeconds;
      selectedCategoryId = saved.categoryId;
      selectedCategoryName = saved.categoryName;
    });

    if (saved.isRunning) {
      if (saved.isFinishedAt(now)) {
        // Uygulama kapalıyken süre doldu: seans hemen tamamlanıp gönderilir.
        unawaited(_completeSession(saved));
      } else {
        _runSession(saved, now);
      }
    } else if (saved.isAbandonedAt(now)) {
      // Sunucu 24 saatten eski seansı kabul etmez; kayıt silinir.
      unawaited(_store.clear(widget.sessionOwnerKey, onlyClientUuid: saved.clientUuid));
      _foregroundSeconds = 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pausedSessionExpired),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _session = saved;
        remaining = saved.remainingSecondsAt(now);
      });
    }
  }

  void _tick({bool countForeground = true}) {
    final session = _session;
    if (!isRunning || session == null || !mounted) return;
    final left = session.remainingSecondsAt(DateTime.now());
    if (left > 0) {
      // Android'de süreç arka planda da tick atabilir; yalnızca ön plan sayılır.
      if (countForeground && _isInForeground) _foregroundSeconds++;
      setState(() => remaining = left);
    } else {
      unawaited(_completeSession(session));
    }
  }

  /// Süre dolduğunda seansı kapatır, sonucu üst bileşene bildirir ve
  /// gönderim bitince cihazdaki kaydı siler.
  Future<void> _completeSession(ActiveTimerSession session) async {
    _timer?.cancel();
    final completed = session.withForegroundSeconds(_foregroundSeconds);
    if (_isInForeground) {
      // Gösterilmiş bildirime dokunulmaz; yalnızca bekleyen iptal edilir.
      unawaited(NotificationService.instance.cancelSessionEndNotification());
    } else {
      // Android'de süreç arka planda yaşıyorsa seans burada biter; alarmın
      // gecikmesini beklemeden bildirim hemen gösterilir.
      unawaited(NotificationService.instance.showSessionEndNow(categoryName: completed.categoryName));
    }

    _resetToIdle();
    widget.onTimerStateChanged?.call(false, completed.categoryName, 0);
    _showSessionCompletedDialog(completed.durationMinutes);

    final owner = widget.sessionOwnerKey;
    final onCompleted = widget.onSessionCompleted;
    try {
      await onCompleted(completed);
      await _store.clear(owner, onlyClientUuid: completed.clientUuid);
    } catch (e) {
      // Kayıt silinmez: sonraki açılışta süresi dolmuş seans olarak yeniden gönderilir.
      debugPrint('[TIMER] Seans gönderimi tamamlanamadı: $e');
    }
  }

  void _resetToIdle() {
    _foregroundSeconds = 0;
    setState(() {
      isRunning = false;
      _isStarting = false;
      _session = null;
      remaining = totalSeconds;
      _validateSelectedCategory();
    });
  }

  CourseCategory? _resolveCategory(String id, String name) {
    final active = widget.categories.where((c) => !c.isArchived);
    return active.where((c) => c.id == id).firstOrNull ??
        (name.isEmpty ? null : active.where((c) => c.name == name).firstOrNull);
  }

  // Seans sürerken ya da duraklatılmışken seçim KİLİTLİDİR: kategori listesi
  // yenilense bile seans başladığı kategoriyle kaydedilir. Seans yokken
  // seçili kategori listede yoksa (ör. yer tutucudan sunucu kategorisine
  // geçiş) önce aynı isimli kategoriye, yoksa ilk aktif kategoriye geçilir.
  void _validateSelectedCategory() {
    if (_hasSession) return;
    final active = widget.categories.where((c) => !c.isArchived);
    if (active.isEmpty) return;
    final match = _resolveCategory(selectedCategoryId, selectedCategoryName) ?? active.first;
    selectedCategoryId = match.id;
    selectedCategoryName = match.name;
  }

  void _toggleTimer() {
    if (isRunning) {
      if (_pauseCreditsLeft > 0) {
        _pause();
      } else {
        _showPauseLimitDialog();
      }
    } else {
      if (_isStarting) return; // çift tıklama koruması
      _isStarting = true;
      unawaited(_show321CountdownAndStart());
    }
  }

  void _pause() {
    final session = _session;
    if (session == null) return;
    _timer?.cancel();
    unawaited(NotificationService.instance.cancelSessionEndNotification());
    final now = DateTime.now();
    final paused = session.pauseAt(now);
    setState(() {
      _session = paused;
      isRunning = false;
      remaining = paused.remainingSecondsAt(now);
    });
    _persistSession();
    widget.onTimerStateChanged?.call(false, paused.categoryName, _minutesLeft(remaining));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(LanguageService.instance.translate('pause_used_snackbar')),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryContainer,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Seansı kaydetmeden bırakır (Sıfırla & Durdur).
  void _discardSession() {
    _timer?.cancel();
    unawaited(NotificationService.instance.cancelSessionEndNotification());
    final categoryName = _session?.categoryName ?? selectedCategoryName;
    _resetToIdle();
    unawaited(_store.clear(widget.sessionOwnerKey));
    widget.onTimerStateChanged?.call(false, categoryName, 0);
  }

  void _selectDuration(int minutes) {
    // Duraklatılmış bir seans varsa süre değişince sıfırlanır.
    if (_hasSession) unawaited(_store.clear(widget.sessionOwnerKey));
    _foregroundSeconds = 0;
    setState(() {
      loggedMinutes = minutes;
      totalSeconds = timerDurationSeconds(minutes);
      remaining = totalSeconds;
      _session = null;
      _validateSelectedCategory();
    });
  }

  Future<void> _show321CountdownAndStart() async {
    // Bildirim izni ilk BAŞLAT'ta, bağlamıyla birlikte istenir (bir kez sorulur).
    await NotificationService.instance.ensurePermission();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) {
        return _CountdownDialog(
          onComplete: () {
            if (ctx.mounted && Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
            _startOrResume();
          },
        );
      },
    );
    // Geri tuşuyla kapatılan geri sayım BAŞLAT'ı kilitli bırakmaz.
    if (mounted && !isRunning) setState(() => _isStarting = false);
  }

  void _startOrResume() {
    if (!mounted) return;
    final now = DateTime.now();
    final current = _session;
    if (current != null) {
      _runSession(current.resumeAt(now), now);
      return;
    }
    final category = _resolveCategory(selectedCategoryId, selectedCategoryName);
    _runSession(
      ActiveTimerSession.start(
        clientUuid: const Uuid().v4(),
        categoryId: category?.id ?? selectedCategoryId,
        categoryName: category?.name ?? selectedCategoryName,
        durationMinutes: loggedMinutes,
        totalSeconds: totalSeconds,
        now: now,
      ),
      now,
    );
  }

  void _runSession(ActiveTimerSession session, DateTime now) {
    _timer?.cancel();
    final left = session.remainingSecondsAt(now);
    setState(() {
      _session = session;
      isRunning = true;
      _isStarting = false;
      remaining = left;
    });
    _persistSession();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    unawaited(NotificationService.instance.scheduleSessionEnd(after: Duration(seconds: left), categoryName: session.categoryName));
    widget.onTimerStateChanged?.call(true, session.categoryName, _minutesLeft(left));
  }

  void _showPauseLimitDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 8),
            Text(
              LanguageService.instance.translate('pause_limit_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          LanguageService.instance.translate('pause_limit_content'),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _discardSession();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(LanguageService.instance.translate('session_reset')),
                  backgroundColor: AppColors.outline,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(
              LanguageService.instance.translate('reset_and_stop'),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              LanguageService.instance.translate('continue_btn'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSessionCompletedDialog(int displayMinutes) {
    final isTurkish = LanguageService.instance.isTurkish;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            const Icon(Icons.stars_rounded, color: Colors.amber, size: 48),
            const SizedBox(height: 16),
            Text(
              isTurkish ? 'Tebrikler! 🎉' : 'Congratulations! 🎉',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          isTurkish
              ? '$displayMinutes dakikalık odaklanma seansını\nbaşarıyla tamamladın! ⏳'
              : 'You successfully completed a $displayMinutes-minute\nfocus session! ⏳',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                isTurkish ? 'Harika!' : 'Awesome!',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
        final seconds = (remaining % 60).toString().padLeft(2, '0');
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final activeCategories = widget.categories.where((c) => !c.isArchived).toList();
        final displayCategory = _resolveCategory(selectedCategoryId, selectedCategoryName);
        final hasPauseCredit = _pauseCreditsLeft > 0;

        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

                final hourglassWidget = HourglassWidget(
                  size: 220,
                  isRunning: isRunning,
                  totalSeconds: totalSeconds,
                  remainingSeconds: remaining,
                  sandColor: displayCategory?.color ?? activeCategories.firstOrNull?.color,
                );

                final controlsWidget = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Subject Chips Section
                    if (!isLandscape) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            TextUtil.getCategorySelectionLabel(widget.userSegment),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                              color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: widget.onOpenSettings,
                            child: const Icon(
                              Icons.edit_outlined,
                              size: 13,
                              color: AppColors.primaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Active Category Pills
                    if (!isLandscape) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: activeCategories.map((cat) {
                            final isSelected = cat.id == displayCategory?.id;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FilterChip(
                                label: Text(LanguageService.instance.translateCatName(cat.name)),
                                selected: isSelected,
                                // Seans sürerken/duraklatılmışken kategori kilitli.
                                onSelected: _hasSession
                                    ? null
                                    : (val) {
                                        if (val) {
                                          setState(() {
                                            selectedCategoryId = cat.id;
                                            selectedCategoryName = cat.name;
                                          });
                                        }
                                      },
                                avatar: CircleAvatar(
                                  backgroundColor: cat.color,
                                  radius: 5,
                                ),
                                showCheckmark: false,
                                selectedColor: cat.color.withValues(alpha: 0.2),
                                backgroundColor: isDark
                                    ? AppColors.darkSurfaceContainerLow
                                    : AppColors.surfaceContainerLow,
                                labelStyle: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected
                                      ? cat.color
                                      : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isSelected ? cat.color : Colors.transparent,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Time Display
                    Text(
                      '$minutes:$seconds',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1.5,
                        color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Süre Seçimi: 25 dk / 50 dk
                    if (!isLandscape) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [25, 50].map((mins) {
                          final isSel = loggedMinutes == mins;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: GestureDetector(
                              onTap: isRunning ? null : () => _selectDuration(mins),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? AppColors.primaryContainer
                                      : (isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSel
                                        ? AppColors.primaryContainer
                                        : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
                                  ),
                                ),
                                child: Text(
                                  '$mins ${LanguageService.instance.translate('minutes_unit_short')}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isSel
                                        ? Colors.white
                                        : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Duraklatma Hakkı (Pause Limit)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: hasPauseCredit
                            ? (isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh)
                            : AppColors.primaryContainer.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: hasPauseCredit
                              ? (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant)
                              : AppColors.primary,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasPauseCredit ? Icons.pause_circle_outline : Icons.block_outlined,
                            size: 13,
                            color: hasPauseCredit
                                ? (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant)
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasPauseCredit ? l10n.pauseCreditAvailable : l10n.pauseCreditUsed,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: hasPauseCredit
                                  ? (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant)
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Primary Start/Pause Button
                    ElevatedButton(
                      onPressed: _toggleTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRunning
                            ? (isDark ? AppColors.darkSurfaceContainerHighest : AppColors.surfaceContainerHighest)
                            : AppColors.primaryContainer,
                        foregroundColor: isRunning
                            ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                            : Colors.white,
                        minimumSize: const Size(200, 48),
                        elevation: isRunning ? 0 : 4,
                        shadowColor: const Color(0x40FF5C4D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        isRunning
                            ? LanguageService.instance.translate('btn_pause')
                            : LanguageService.instance.translate('btn_start'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );

                final double hourglassTop = isLandscape ? (constraints.maxHeight - 230) / 2 : 48.0;
                final double hourglassLeft = isLandscape ? (constraints.maxWidth * 0.25 - 110) : (constraints.maxWidth - 220) / 2;

                final double controlsTop = isLandscape ? 16.0 : 300.0;
                final double controlsLeft = isLandscape ? constraints.maxWidth * 0.5 : 0.0;
                final double controlsWidth = isLandscape ? constraints.maxWidth * 0.5 : constraints.maxWidth;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOutCubic,
                      top: hourglassTop,
                      left: hourglassLeft,
                      child: SizedBox(
                        width: 220,
                        height: 230,
                        child: hourglassWidget,
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOutCubic,
                      top: controlsTop,
                      bottom: 0.0,
                      left: controlsLeft,
                      width: controlsWidth,
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: controlsWidget,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Separate StatefulWidget for the 3-2-1 countdown to properly
/// manage its own Timer lifecycle without spawning duplicates.
class _CountdownDialog extends StatefulWidget {
  final VoidCallback onComplete;

  const _CountdownDialog({required this.onComplete});

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  int _count = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_count > 1) {
        setState(() => _count--);
      } else {
        timer.cancel();
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Text(
                '$_count',
                key: ValueKey(_count),
                style: const TextStyle(
                  fontSize: 110,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: AppColors.primaryContainer, blurRadius: 30),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              LanguageService.instance.isTurkish ? 'Hazırlan! Odaklanıyorsun...' : 'Get Ready! Focusing...',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
