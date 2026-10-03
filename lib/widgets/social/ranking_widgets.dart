import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/avatar_model.dart';
import '../../theme.dart';
import '../avatar_widget.dart';
import 'countdown_text.dart';
import 'ranking_models.dart';

Color _muted(bool isDark) => isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;

/// Lig/aylık sekmesindeki başlık ve geri sayım kartı.
class RankingCountdownBanner extends StatelessWidget {
  final String title;
  final DateTime? target;
  final VoidCallback? onHelp;

  const RankingCountdownBanner({super.key, required this.title, this.target, this.onHelp});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.timer_outlined, color: AppColors.primaryContainer, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _muted(isDark)),
                ),
                if (target != null) ...[
                  const SizedBox(height: 2),
                  CountdownText(
                    target: target!,
                    prefix: '⏱️ ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkPrimary : AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onHelp != null)
            IconButton(
              onPressed: onHelp,
              tooltip: l10n.leagueInfoTitle,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.15),
              ),
              icon: Icon(
                Icons.question_mark_rounded,
                size: 15,
                color: isDark ? AppColors.darkPrimary : AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Kullanıcının listedeki yeri. Liste ezilmez; bu ayrı bir göstergedir.
class MyRankCard extends StatelessWidget {
  final int rank;
  final int points;

  const MyRankCard({super.key, required this.rank, required this.points});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin_circle_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.rankingMyStatus(rank, points),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Boş liste kartı.
class RankingEmptyView extends StatelessWidget {
  const RankingEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.leaderboard_outlined, size: 48, color: _muted(isDark)),
          const SizedBox(height: 12),
          Text(
            l10n.noUsersInRanking,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: _muted(isDark)),
          ),
        ],
      ),
    );
  }
}

/// Lig sekmesi: kullanıcı henüz bir lig odasında değil
/// ([LeagueSnapshot.awaitingPlacement]). Tek kişilik "#1 · 0 puan" podyumu
/// yerine gösterilir.
class LeaguePlacementView extends StatelessWidget {
  const LeaguePlacementView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.hourglass_empty_rounded, size: 48, color: AppColors.primaryContainer),
          const SizedBox(height: 12),
          Text(
            l10n.leagueAwaitingPlacementTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.leagueAwaitingPlacementBody,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.4, color: _muted(isDark)),
          ),
        ],
      ),
    );
  }
}

/// İlk üç: ortada 1. (en büyük), solda 2., sağda 3.
class RankingPodium extends StatelessWidget {
  final List<RankingEntry> top;

  const RankingPodium({super.key, required this.top});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (top.length >= 2) _PodiumSeat(entry: top[1], rank: 2) else const SizedBox(width: 80),
          if (top.isNotEmpty) _PodiumSeat(entry: top[0], rank: 1),
          if (top.length >= 3) _PodiumSeat(entry: top[2], rank: 3) else const SizedBox(width: 80),
        ],
      ),
    );
  }
}

class _PodiumStyle {
  final double avatarSize;
  final double medalSize;
  final Color medal;
  final List<Color> ring;
  final Color badgeText;
  final IconData badgeIcon;

  const _PodiumStyle(this.avatarSize, this.medalSize, this.medal, this.ring, this.badgeText, this.badgeIcon);

  static const gold = _PodiumStyle(96, 36, Color(0xFFFFD700), [Color(0xFFFFD700), Color(0xFFFFA500)], Colors.black, Icons.workspace_premium);
  static const silver = _PodiumStyle(76, 30, Color(0xFFC0C0C0), [Color(0xFFE0E0E0), Color(0xFF9E9E9E)], Colors.black87, Icons.looks_two_rounded);
  static const bronze = _PodiumStyle(60, 26, Color(0xFFCD7F32), [Color(0xFFD7CCC8), Color(0xFF8D6E63)], Colors.white, Icons.looks_3_rounded);

  static _PodiumStyle forRank(int rank) => rank == 1 ? gold : (rank == 2 ? silver : bronze);
}

class _PodiumSeat extends StatelessWidget {
  final RankingEntry entry;
  final int rank;

  const _PodiumSeat({required this.entry, required this.rank});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final style = _PodiumStyle.forRank(rank);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Icon(Icons.workspace_premium, color: style.medal, size: style.medalSize),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: EdgeInsets.all(rank == 1 ? 4 : 3),
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: style.ring)),
              child: AvatarWidget(avatar: AvatarCharacter.byId(entry.avatarId), size: style.avatarSize),
            ),
            Positioned(
              bottom: -6,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: style.medal,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.badgeIcon, size: 12, color: style.badgeText),
                      const SizedBox(width: 2),
                      Text(
                        '#$rank',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: style.badgeText),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 90,
          child: Text(
            entry.name ?? l10n.userDefault,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: rank == 1 ? 15 : 13,
              fontWeight: rank == 1 || entry.isMe ? FontWeight.bold : FontWeight.w600,
              color: entry.isMe ? AppColors.primary : null,
            ),
          ),
        ),
        if (entry.isMe)
          Text(
            l10n.youBadge,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
        const SizedBox(height: 2),
        _PointsBadge(points: entry.points, small: true),
      ],
    );
  }
}

/// 4. sıradan itibaren liste satırı.
class RankingRow extends StatelessWidget {
  final RankingEntry entry;
  final int rank;

  /// Lig sekmesinde terfi/düşme bölgesi rengi (yoksa null).
  final Color? zoneColor;

  const RankingRow({super.key, required this.entry, required this.rank, this.zoneColor});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = zoneColor ??
        (entry.isMe ? AppColors.primaryContainer.withValues(alpha: 0.12) : Colors.transparent);
    final name = entry.name ?? l10n.userDefault;
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: entry.isMe ? const Border(left: BorderSide(color: AppColors.primary, width: 4)) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _muted(isDark)),
            ),
          ),
          const SizedBox(width: 12),
          AvatarWidget(avatar: AvatarCharacter.byId(entry.avatarId), size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.isMe ? '$name ${l10n.youBadge}' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: entry.isMe ? AppColors.primary : null,
                  ),
                ),
                if (entry.minutes != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    l10n.minutesStudy(entry.minutes!),
                    style: TextStyle(fontSize: 12, color: _muted(isDark)),
                  ),
                ],
              ],
            ),
          ),
          _PointsBadge(points: entry.points),
        ],
      ),
    );
  }
}

class _PointsBadge extends StatelessWidget {
  final int points;
  final bool small;

  const _PointsBadge({required this.points, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10, vertical: small ? 3 : 4),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(small ? 10 : 12),
      ),
      child: Text(
        AppLocalizations.of(context)!.rankingPoints(points),
        style: TextStyle(
          fontSize: small ? 11 : 13,
          fontWeight: FontWeight.bold,
          color: AppColors.onPrimaryFixed,
        ),
      ),
    );
  }
}
