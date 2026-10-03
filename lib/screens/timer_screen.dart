import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../theme.dart';
import '../utils/text_util.dart';
import '../models/category_model.dart';
import '../widgets/hourglass_widget.dart';
import '../services/language_service.dart';
import '../services/notification_service.dart';

class TimerScreen extends StatefulWidget {
  final List<CourseCategory> categories;
  final VoidCallback onOpenSettings;
  final Function(String categoryId, int minutes, bool wasPaused, int isVerified, DateTime startedAt, String clientUuid)? onSessionCompleted;
  final void Function(bool isRunning, String categoryName, int loggedMinutes)? onTimerStateChanged;
  final int userPoints;
  final int streakDays;
  final String? userSegment;

  const TimerScreen({
    super.key,
    required this.categories,
    required this.onOpenSettings,
    this.onSessionCompleted,
    this.onTimerStateChanged,
    this.userSegment,
    this.userPoints = 0,
    this.streakDays = 0,
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  // Sadece debug build'lerde (flutter run, --release DEĞİL) test için süre
  // kısaltılır; gerçek kullanıcılara giden release build'de her zaman
  // gerçek 25/50 dakika çalışır. Bkz. _durationSeconds.
  static int _durationSeconds(int minutes) {
    if (kDebugMode) {
      return minutes == 25 ? 5 : 10;
    }
    return minutes * 60;
  }

  int totalSeconds = _durationSeconds(25);
  int remaining = _durationSeconds(25);
  int loggedMinutes = 25;
  bool isRunning = false;
  bool _isStarting = false; // BAŞLAT butonuna çift tıklama koruması
  Timer? _timer;
  String selectedCategoryId = '1';

  // 1-Pause Rule Credit (Per session)
  int pauseCredits = 1;
  int pauseUsedCount = 0;

  // Sayaç çalışırken seansın biteceği an. Kalan süre her tick'te bundan
  // hesaplanır; böylece Timer.periodic kayması veya uygulamanın arka
  // planda askıya alınması süreyi bozmaz.
  DateTime? _endsAt;

  // Session tracking for server-side scoring
  DateTime? _sessionStartedAt;
  String? _sessionClientUuid;
  int _foregroundSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _validateSelectedCategory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Arka plandayken periyodik timer durur; öne gelince kalan süreyi
    // bitiş anından yeniden hesapla (süre dolduysa seans tamamlanır).
    if (state == AppLifecycleState.resumed && isRunning) {
      _tick(countForeground: false);
    }
  }

  int _secondsUntilEnd() {
    final ms = _endsAt!.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  void _tick({bool countForeground = true}) {
    if (!isRunning || _endsAt == null || !mounted) return;
    final left = _secondsUntilEnd();
    if (left > 0) {
      setState(() {
        remaining = left;
        if (countForeground) _foregroundSeconds++; // Track active time
      });
    } else {
      _completeSession();
    }
  }

  /// Süre dolduğunda seansı kapatır ve sonucu üst bileşene bildirir.
  void _completeSession() {
    _timer?.cancel();
    NotificationService.instance.cancelAllNotifications();

    final catId = selectedCategoryId;
    final categoryName = _selectedCategoryName;
    final minsLogged = loggedMinutes;
    final wasPaused = pauseUsedCount > 0;
    final isVerified = _foregroundSeconds; // Pass total foreground time
    final startedAt = _sessionStartedAt ?? DateTime.now().subtract(Duration(minutes: minsLogged));
    final clientUuid = _sessionClientUuid ?? const Uuid().v4();

    setState(() {
      isRunning = false;
      remaining = totalSeconds;
      pauseCredits = 1; // Reset pause credit on finish
      pauseUsedCount = 0;
      _resetSessionTracking();
    });

    widget.onTimerStateChanged?.call(false, categoryName, minsLogged);
    widget.onSessionCompleted?.call(catId, minsLogged, wasPaused, isVerified, startedAt, clientUuid);
    _showSessionCompletedDialog();
  }

  void _resetSessionTracking() {
    _endsAt = null;
    _sessionStartedAt = null;
    _sessionClientUuid = null;
    _foregroundSeconds = 0;
  }

  @override
  void didUpdateWidget(TimerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validateSelectedCategory();
  }

  void _validateSelectedCategory() {
    final activeCategories = widget.categories.where((c) => !c.isArchived).toList();
    if (activeCategories.isNotEmpty && !activeCategories.any((c) => c.id == selectedCategoryId)) {
      setState(() {
        selectedCategoryId = activeCategories.first.id;
      });
    }
  }

  String get _selectedCategoryName {
    final match = widget.categories.where((c) => c.id == selectedCategoryId);
    return match.isNotEmpty ? match.first.name : '';
  }

  void _toggleTimer() {
    if (isRunning) {
      // Trying to PAUSE
      if (pauseCredits > 0) {
        // 1st Pause allowed!
        _timer?.cancel();
        NotificationService.instance.cancelAllNotifications();
        setState(() {
          if (_endsAt != null) remaining = _secondsUntilEnd();
          _endsAt = null;
          isRunning = false;
          pauseCredits--;
          pauseUsedCount++;
        });
        widget.onTimerStateChanged?.call(false, _selectedCategoryName, loggedMinutes);
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
      } else {
        // 2nd Pause Attempt -> Blocked! Show Confirmation Dialog
        _showPauseLimitDialog();
      }
    } else {
      // START / RESUME TIMER with 3-2-1 Countdown Animation
      if (_isStarting) return; // çift tıklama koruması
      _isStarting = true;
      _show321CountdownAndStart();
    }
  }

  void _show321CountdownAndStart() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) {
        return _CountdownDialog(
          onComplete: () {
            if (ctx.mounted && Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
            _startTimerPeriodic();
          },
        );
      },
    );
  }

  void _startTimerPeriodic() {
    _timer?.cancel();

    setState(() {
      isRunning = true;
      _isStarting = false;
      _endsAt = DateTime.now().add(Duration(seconds: remaining));
      // Başlangıç zamanı ve seans kimliği yalnızca YENİ bir seansta
      // atanır. Duraklatıp devam edince korunmalı: aksi halde sunucuya
      // giden başlangıç zamanı devam etme anı olur ve seans, gerçekte
      // geçen süreden kısa görünür.
      _sessionStartedAt ??= DateTime.now();
      _sessionClientUuid ??= const Uuid().v4();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    NotificationService.instance.scheduleTimerCompletionNotification(remaining, _selectedCategoryName);
    widget.onTimerStateChanged?.call(true, _selectedCategoryName, loggedMinutes);
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
              // Option A: Reset Progress completely
              _timer?.cancel();
              NotificationService.instance.cancelAllNotifications();
              setState(() {
                isRunning = false;
                remaining = totalSeconds;
                pauseCredits = 1;
                pauseUsedCount = 0;
                _resetSessionTracking();
              });
              widget.onTimerStateChanged?.call(false, _selectedCategoryName, loggedMinutes);
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
            onPressed: () {
              Navigator.pop(ctx);
              // Option B: Continue session running
            },
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

  void _showSessionCompletedDialog() {
    final displayMinutes = loggedMinutes;
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

  // dispose removed since it is handled above in the chunks

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, _) {
        final progress = 1 - (remaining / totalSeconds);
        final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
        final seconds = (remaining % 60).toString().padLeft(2, '0');
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

                final hourglassWidget = HourglassWidget(
                  size: 220,
                  progress: progress,
                  isRunning: isRunning,
                  totalSeconds: totalSeconds,
                  remainingSeconds: remaining,
                  sandColor: widget.categories.where((c) => !c.isArchived).isNotEmpty 
                      ? widget.categories.firstWhere(
                          (c) => c.id == selectedCategoryId, 
                          orElse: () => widget.categories.where((c) => !c.isArchived).first,
                        ).color 
                      : null,
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
                          children: widget.categories.where((cat) => !cat.isArchived).map((cat) {
                            final isSelected = cat.id == selectedCategoryId;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FilterChip(
                                label: Text(LanguageService.instance.translateCatName(cat.name)),
                                selected: isSelected,
                                onSelected: (isRunning || (remaining < totalSeconds && remaining > 0))
                                    ? null
                                    : (val) {
                                        if (val) {
                                          setState(() => selectedCategoryId = cat.id);
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
                          final durationSeconds = _durationSeconds(mins);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: GestureDetector(
                              onTap: isRunning
                                  ? null
                                  : () {
                                      setState(() {
                                        loggedMinutes = mins;
                                        totalSeconds = durationSeconds;
                                        remaining = durationSeconds;
                                        pauseCredits = 1;
                                        pauseUsedCount = 0;
                                        // Duraklatılmış bir seans varsa süre değişince sıfırlanır.
                                        _resetSessionTracking();
                                      });
                                    },
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
                        color: pauseCredits > 0
                            ? (isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh)
                            : AppColors.primaryContainer.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: pauseCredits > 0
                              ? (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant)
                              : AppColors.primary,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            pauseCredits > 0 ? Icons.pause_circle_outline : Icons.block_outlined,
                            size: 13,
                            color: pauseCredits > 0
                                ? (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant)
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            pauseCredits > 0
                                ? (LanguageService.instance.isTurkish ? '1/1 Duraklatma Hakkı' : '1/1 Pause Credit')
                                : (LanguageService.instance.isTurkish ? '0/1 Duraklatma Hakkı (Hakkın Bitti)' : '0/1 Pause Credit (Limit Reached)'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: pauseCredits > 0
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
              }
            )
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
