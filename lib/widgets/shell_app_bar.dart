import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../utils/responsive.dart';
import 'shell_stat_pill.dart';
import 'study_day_builder.dart';

/// Ana kabuğun üst çubuğu: seri (yalnızca Pomo sekmesinde), Puan ve Kum
/// rozetleri, arkadaşlar ve profil düğmeleri.
///
/// Yatay telefonda (dikey alan kıtken) çubuk ve düğmeler küçülür; dikey
/// telefonda ve tablette bugünkü ölçüler korunur.
AppBar buildShellAppBar(
  BuildContext context, {
  required int? streakDays,
  /// Verilirse seri bununla ve her çalışma günü dönümünde (04:00) yeniden
  /// hesaplanır; [streakDays] yok sayılır.
  int Function(DateTime now)? streakAt,
  required int points,
  required int coins,
  required VoidCallback onStatsTap,
  required VoidCallback onFriendsTap,
  required VoidCallback onProfileTap,
  required Widget Function(double size) avatarBuilder,
}) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final compact = Responsive.of(context).isShortHeight;
  final toolbarHeight = compact ? 56.0 : 76.0;
  final friendsSize = compact ? 44.0 : 63.0;
  final avatarSize = compact ? 42.0 : 60.0;

  return AppBar(
    backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    toolbarHeight: toolbarHeight,
    titleSpacing: 16,
    // Seri yalnızca Pomo sekmesinde gösterilir (streakDays/streakAt null değilse).
    title: (streakDays != null || streakAt != null)
        ? FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 24),
                const SizedBox(width: 6),
                StudyDayBuilder(
                  builder: (context, now) => Text(
                    '${streakAt != null ? streakAt(now) : streakDays}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkPrimary : AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          )
        : const SizedBox.shrink(),
    actions: [
      // Puan + Kum Tanesi rozetleri: dar ekranda kendi içinde yatay
      // kaydırılır, alçak çubukta orantılı küçülür; arkadaş/profil
      // düğmeleri etkilenmez.
      Flexible(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShellStatPill(
                label: l10n.pointsCaption,
                value: points,
                background: AppColors.primaryFixed,
                foreground: AppColors.onPrimaryFixed,
                dense: compact,
                onTap: onStatsTap,
              ),
              const SizedBox(width: 8),
              ShellStatPill(
                label: l10n.coinsCaption,
                value: coins,
                background: const Color(0xFFFFE7A8),
                foreground: const Color(0xFF7A5A00),
                dense: compact,
                onTap: onStatsTap,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 10),

      // Arkadaş Ekle/Görüntüle Butonu (Dairesel, avatardan biraz büyük)
      InkWell(
        onTap: onFriendsTap,
        borderRadius: BorderRadius.circular(compact ? 22 : 32),
        child: Container(
          width: friendsSize,
          height: friendsSize,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primaryContainer.withValues(alpha: 0.4),
            ),
          ),
          child: Icon(
            Icons.people_alt_rounded,
            color: AppColors.primaryContainer,
            size: friendsSize * 33 / 63,
          ),
        ),
      ),
      const SizedBox(width: 10),

      // Profil avatarı (Profil & Ayarlar'ı açar)
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: GestureDetector(
          onTap: onProfileTap,
          child: avatarBuilder(avatarSize),
        ),
      ),
    ],
  );
}
