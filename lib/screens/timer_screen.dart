import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/category_model.dart';
import '../widgets/hourglass_widget.dart';
import '../services/language_service.dart';
import '../utils/points.dart';

class TimerScreen extends StatefulWidget {
  final List<CourseCategory> categories;
  final VoidCallback onOpenSettings;
  final Function(String categoryId, int minutes)? onSessionCompleted;
  final ValueChanged<bool>? onTimerStateChanged;
  final int userPoints;
  final int streakDays;

  const TimerScreen({
    super.key,
    required this.categories,
    required this.onOpenSettings,
    this.onSessionCompleted,
    this.onTimerStateChanged,
    this.userPoints = 0,
    this.streakDays = 0,
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  // GEÇİCİ TEST MODU: 25 dk -> 5 sn, 50 dk -> 10 sn olarak sayılıyor
  // (gerçek süre yerine hızlı test için). loggedMinutes, seans bittiğinde
  // sanki gerçek 25/50 dakika çalışılmış gibi puan/kayıt için kullanılır.
  int totalSeconds = 5; // Varsayılan: 25 dk (test: 5 sn)
  int remaining = 5;
  int loggedMinutes = 25;
  bool isRunning = false;
  bool _isStarting = false; // BAŞLAT butonuna çift tıklama koruması
  Timer? _timer;
  String selectedCategoryId = '1';

  // 1-Pause Rule Credit (Per session)
  int pauseCredits = 1;
  int pauseUsedCount = 0;

  @override
  void initState() {
    super.initState();
    _validateSelectedCategory();
  }

  @override
  void didUpdateWidget(TimerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validateSelectedCategory();
  }

  void _validateSelectedCategory() {
    if (widget.categories.isNotEmpty && !widget.categories.any((c) => c.id == selectedCategoryId)) {
      setState(() {
        selectedCategoryId = widget.categories.first.id;
      });
    }
  }

  void _toggleTimer() {
    if (isRunning) {
      // Trying to PAUSE
      if (pauseCredits > 0) {
        // 1st Pause allowed!
        _timer?.cancel();
        setState(() {
          isRunning = false;
          pauseCredits--;
          pauseUsedCount++;
        });
        widget.onTimerStateChanged?.call(false);
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
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        if (remaining > 0) {
          remaining--;
        } else {
          t.cancel();
          isRunning = false;
          widget.onTimerStateChanged?.call(false);
          remaining = totalSeconds;
          pauseCredits = 1; // Reset pause credit on finish
          pauseUsedCount = 0;
          widget.onSessionCompleted?.call(selectedCategoryId, loggedMinutes);
          _showSessionCompletedDialog();
        }
      });
    });

    setState(() {
      isRunning = true;
      _isStarting = false;
    });
    widget.onTimerStateChanged?.call(true);
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
              setState(() {
                isRunning = false;
                remaining = totalSeconds;
                pauseCredits = 1;
                pauseUsedCount = 0;
              });
              widget.onTimerStateChanged?.call(false);
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
    final earnedPoints = pointsForMinutes(displayMinutes);
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
              ? '$displayMinutes dakikalık odaklanma seansını\nbaşarıyla tamamladın ve +$earnedPoints Puan kazandın!'
              : 'You successfully completed a $displayMinutes-minute\nfocus session and earned +$earnedPoints Points!',
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
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
        child: Stack(
          children: [
            // Not: Streak ve Puan göstergeleri artık üst AppBar'da (main.dart)
            // tek yerden gösteriliyor; burada tekrar etmesin diye kaldırıldı.

            // Content Fitted on Single Screen
            Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(top: 48, bottom: 16, left: 16, right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Hourglass Container (Yukarı Çekilmiş ve Uyumlu Boyutlandırılmış)
                    SizedBox(
                      width: 220,
                      height: 230,
                      child: HourglassWidget(
                        size: 220,
                        progress: progress,
                        isRunning: isRunning,
                        totalSeconds: totalSeconds,
                        remainingSeconds: remaining,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Subject Chips Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          LanguageService.instance.translate('select_subject'),
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

                    // Active Category Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: widget.categories.map((cat) {
                          final isSelected = cat.id == selectedCategoryId;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: FilterChip(
                              label: Text(LanguageService.instance.translateCatName(cat.name)),
                              selected: isSelected,
                              onSelected: isRunning
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
                                  color: isSelected
                                      ? cat.color
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [25, 50].map((mins) {
                        final isSel = loggedMinutes == mins;
                        // GEÇİCİ TEST: gerçek süre yerine 25dk->5sn, 50dk->10sn
                        final testSeconds = mins == 25 ? 5 : 10;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: GestureDetector(
                            onTap: isRunning
                                ? null
                                : () {
                                    setState(() {
                                      loggedMinutes = mins;
                                      totalSeconds = testSeconds;
                                      remaining = testSeconds;
                                      pauseCredits = 1;
                                      pauseUsedCount = 0;
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
                                '$mins ${LanguageService.instance.translate('minutes_unit')}',
                                style: TextStyle(
                                  fontSize: 14,
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

                    const SizedBox(height: 10),

                    // Pause Limit Indicator Badge
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

                    // Primary Start/Pause Button (Tek Sayfaya Tam Oturan Buton)
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
                  ],
                ),
              ),
            ),
          ],
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
