import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/language_service.dart';
import '../../services/supabase_service.dart';
import '../../theme.dart';
import '../../utils/responsive.dart';
import '../../utils/stats_calculator.dart';
import 'stats_layout.dart';
import 'stats_text.dart';

const int kMinDailyGoalMinutes = kPomodoroMinutes;
const int kMaxDailyGoalMinutes = 600;
const List<int> _presetGoalMinutes = [60, 120, 180, 240, 300];

/// Günlük hedef sayfası (Günlük ve Haftalık sekmelerin ortak sayfası).
/// Hedef dakika cinsinden profile (profiles.daily_goal_minutes) yazılır;
/// ekranlar SupabaseService.currentUser üzerinden güncellenir.
Future<void> showDailyGoalSheet(BuildContext context, {required int initialGoalMinutes}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Tablette tam genişliğe yayılmaz.
    constraints: const BoxConstraints(maxWidth: kStatsSheetMaxWidth),
    backgroundColor: isDark ? AppColors.darkSurfaceContainerLowest : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _DailyGoalSheet(initialGoalMinutes: initialGoalMinutes),
  );
}

class _DailyGoalSheet extends StatefulWidget {
  const _DailyGoalSheet({required this.initialGoalMinutes});

  final int initialGoalMinutes;

  @override
  State<_DailyGoalSheet> createState() => _DailyGoalSheetState();
}

class _DailyGoalSheetState extends State<_DailyGoalSheet> {
  late int _goal = widget.initialGoalMinutes.clamp(kMinDailyGoalMinutes, kMaxDailyGoalMinutes);
  bool _saving = false;
  bool _saveFailed = false;

  // Bir pomodoro (25 dk) adım; onboarding'den gelen 60 gibi değerler en
  // yakın 25'in katına oturur.
  void _step(int direction) {
    final next = direction > 0
        ? (_goal ~/ kPomodoroMinutes + 1) * kPomodoroMinutes
        : ((_goal - 1) ~/ kPomodoroMinutes) * kPomodoroMinutes;
    setState(() {
      _goal = next.clamp(kMinDailyGoalMinutes, kMaxDailyGoalMinutes);
      _saveFailed = false;
    });
  }

  Future<void> _save() async {
    if (_goal == widget.initialGoalMinutes) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await SupabaseService.instance.updateDailyGoalMinutes(_goal);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Günlük hedef kaydedilemedi: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.darkPrimary : AppColors.primary;
    final pomodoros = (_goal / kPomodoroMinutes).round();
    // Yatay telefonda dikey alan kıt: boşluklar sıkılaşır, içerik kaydırılır.
    final short = Responsive.of(context).isShortHeight;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 16, 24, (short ? 16 : 24) + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceContainerHighest : AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: short ? 12 : 20),
            Text(
              lang.translate('set_daily_goal_title'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.statsGoalSheetSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: short ? 16 : 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepButton(
                  icon: Icons.remove_rounded,
                  enabled: !_saving && _goal > kMinDailyGoalMinutes,
                  onTap: () => _step(-1),
                ),
                const SizedBox(width: 24),
                Flexible(
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            StatsText.duration(_goal),
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              color: accent,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.statsGoalPomodoroApprox(pomodoros),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                _StepButton(
                  icon: Icons.add_rounded,
                  enabled: !_saving && _goal < kMaxDailyGoalMinutes,
                  onTap: () => _step(1),
                ),
              ],
            ),
            SizedBox(height: short ? 12 : 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: _presetGoalMinutes.map((preset) {
                final isSelected = _goal == preset;
                return Semantics(
                  button: true,
                  selected: isSelected,
                  child: GestureDetector(
                    onTap: _saving
                        ? null
                        : () => setState(() {
                              _goal = preset;
                              _saveFailed = false;
                            }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accent
                            : (isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        StatsText.duration(preset),
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
            if (_saveFailed) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: Text(
                  l10n.statsGoalSaveFailed,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
            SizedBox(height: short ? 16 : 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: accent.withValues(alpha: 0.6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(
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
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.darkPrimary : AppColors.primary;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
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
          child: Icon(icon, color: enabled ? accent : accent.withValues(alpha: 0.35), size: 24),
        ),
      ),
    );
  }
}
