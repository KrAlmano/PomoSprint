import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/avatar_model.dart';
import '../../theme.dart';
import '../../utils/responsive.dart';
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

/// Terfi bölgesi rengi (podyum çipi, liste satırı, kendi durum kartı).
const Color kPromotionZoneColor = Color(0xFF2E7D32);

/// Düşme bölgesi rengi.
const Color kDemotionZoneColor = Color(0xFFC62828);

/// Kullanıcının listedeki yeri. Liste ezilmez; bu ayrı bir göstergedir.
/// Lig sekmesinde [zone] verilirse dönem sonu durumu da yazılır.
class MyRankCard extends StatelessWidget {
  final int rank;
  final int points;
  final LeagueZone? zone;

  const MyRankCard({super.key, required this.rank, required this.points, this.zone});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (String? zoneText, Color zoneColor, IconData zoneIcon) = switch (zone) {
      LeagueZone.promotion => (l10n.rankingZonePromotionMe, kPromotionZoneColor, Icons.arrow_upward_rounded),
      LeagueZone.promotionNeedsPoints => (l10n.rankingZoneNeedsPointsMe, Colors.orange.shade800, Icons.info_outline),
      LeagueZone.demotion => (l10n.rankingZoneDemotionMe, kDemotionZoneColor, Icons.arrow_downward_rounded),
      _ => (null, AppColors.primary, Icons.info_outline),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          if (zoneText != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(zoneIcon, color: zoneColor, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    zoneText,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: zoneColor, height: 1.3),
                  ),
                ),
              ],
            ),
          ],
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
        mainAxisSize: MainAxisSize.min,
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
        mainAxisSize: MainAxisSize.min,
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

/// Bir sıralama sekmesinin gövdesi: kullanıcının durum kartı, podyum ve 4.
/// sıradan itibaren liste.
///
/// Dar alanda (telefon, tablet dikey) bugünkü tek sütun düzeni okunabilir
/// genişlikte ortalanır. Yeterince geniş alanda (tablet yatay, yatay telefon)
/// durum kartı ve podyum solda, liste sağda iki sütuna bölünür; böylece
/// liste kaydırmadan görünür.
class RankingStandings extends StatelessWidget {
  final List<RankingEntry> entries;

  /// Lig sekmesinde odanın özeti (terfi/düşme bölgeleri); diğer sekmelerde null.
  final LeagueSnapshot? league;

  /// Dikey alanı kıt ekranlar (yatay telefon): küçük podyum.
  final bool compact;

  const RankingStandings({super.key, required this.entries, this.league, this.compact = false});

  /// İki sütuna geçilen en dar genişlik.
  static const double splitMinWidth = 800;

  /// Küçük podyumla (yatay telefon) iki sütuna geçilen en dar genişlik.
  static const double compactSplitMinWidth = 600;

  static const double _gap = 20;

  @override
  Widget build(BuildContext context) {
    final league = this.league;
    // Lig-yok satırı (tek kişi, 0 puan): sahte "#1" podyumu gösterilmez.
    if (league != null && league.awaitingPlacement) return const ContentWidth(child: LeaguePlacementView());
    if (entries.isEmpty) return const ContentWidth(child: RankingEmptyView());

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myIndex = entries.indexWhere((e) => e.isMe);

    // Terfi/düşme bölgesi podyum dahil her sıra için aynı kuralla gösterilir.
    LeagueZone zoneOf(RankingEntry entry, int rank) => league?.zoneOf(rank, entry.points) ?? LeagueZone.none;

    Color? zoneColor(RankingEntry entry, int rank) => switch (zoneOf(entry, rank)) {
          LeagueZone.promotion => Colors.green.withValues(alpha: 0.15),
          LeagueZone.demotion => Colors.red.withValues(alpha: 0.15),
          _ => null,
        };

    final myRank = myIndex == -1
        ? null
        : MyRankCard(
            rank: myIndex + 1,
            points: entries[myIndex].points,
            zone: league == null ? null : zoneOf(entries[myIndex], myIndex + 1),
          );
    final podium = RankingPodium(
      top: entries.take(3).toList(),
      zoneOf: league == null ? null : zoneOf,
      compact: compact,
    );
    final list = entries.length <= 3
        ? null
        : Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                for (var i = 3; i < entries.length; i++) ...[
                  if (i > 3)
                    Divider(
                      height: 1,
                      color: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow,
                    ),
                  RankingRow(entry: entries[i], rank: i + 1, zoneColor: zoneColor(entries[i], i + 1)),
                ],
              ],
            ),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (list == null || width < (compact ? compactSplitMinWidth : splitMinWidth)) {
          return ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (myRank != null) ...[myRank, const SizedBox(height: 12)],
                podium,
                const SizedBox(height: 20),
                ?list,
              ],
            ),
          );
        }
        // Sol sütun podyumun tam (ya da küçük) boyuna yetecek kadar geniş
        // tutulur; kalan alan listeye kalır.
        final leftWidth = math.max(compact ? 280.0 : 360.0, (width - _gap) * 0.42);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: leftWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (myRank != null) ...[myRank, const SizedBox(height: 12)],
                  podium,
                ],
              ),
            ),
            const SizedBox(width: _gap),
            Expanded(child: list),
          ],
        );
      },
    );
  }
}

/// İlk üç: ortada 1. (en büyük), solda 2., sağda 3.
class RankingPodium extends StatelessWidget {
  final List<RankingEntry> top;

  /// Lig sekmesinde koltuğun dönem sonu durumu (sıra 1'den başlar). Küçük
  /// odalarda terfi bölgesi tamamen podyumda kaldığı için burada da
  /// gösterilir.
  final LeagueZone Function(RankingEntry entry, int rank)? zoneOf;

  /// Dikey alanı kıt ekranlar (yatay telefon) için küçültülmüş podyum.
  /// Tam boy koltuklar sığmayacak kadar dar alanda da kendiliğinden
  /// küçülür.
  final bool compact;

  const RankingPodium({super.key, required this.top, this.zoneOf, this.compact = false});

  static const double _compactScale = 0.75;
  static const double _horizontalPadding = 12;

  // Tam boy üç koltuğun (altın halka dahil en geniş koltuk 104 px) yan yana
  // sığdığı en dar podyum.
  static const double _fullSizeMinWidth = 3 * 104 + 2 * _horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final small = compact || constraints.maxWidth < _fullSizeMinWidth;
        final scale = small ? _compactScale : 1.0;
        // Koltuklar Flexible: metin ölçeği büyüse ya da alan daralsa da satır
        // taşmaz; sığdığında yerleşim eskisiyle aynıdır (spaceEvenly).
        Widget seat(int index) => Flexible(
              child: _PodiumSeat(
                entry: top[index],
                rank: index + 1,
                zone: zoneOf?.call(top[index], index + 1),
                scale: scale,
              ),
            );
        final placeholder = SizedBox(width: 80 * scale);
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: small ? 12 : 20, horizontal: _horizontalPadding),
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
              if (top.length >= 2) seat(1) else placeholder,
              if (top.isNotEmpty) seat(0),
              if (top.length >= 3) seat(2) else placeholder,
            ],
          ),
        );
      },
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
  final LeagueZone? zone;

  /// Avatar, madalya ve isim genişliği çarpanı (küçük podyumda < 1).
  final double scale;

  const _PodiumSeat({required this.entry, required this.rank, this.zone, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final style = _PodiumStyle.forRank(rank);
    final small = scale < 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: small ? 4 : 6),
          child: Icon(Icons.workspace_premium, color: style.medal, size: style.medalSize * scale),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: EdgeInsets.all(rank == 1 ? 4 : 3),
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: style.ring)),
              child: AvatarWidget(avatar: AvatarCharacter.byId(entry.avatarId), size: style.avatarSize * scale),
            ),
            Positioned(
              bottom: -6,
              left: 0,
              right: 0,
              // Rozet avatar genişliğini aşacaksa (küçük podyum, büyük metin
              // ölçeği) bütünüyle küçülür.
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
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
            ),
          ],
        ),
        SizedBox(height: small ? 10 : 12),
        SizedBox(
          width: small ? 80 : 90,
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
        if (zone == LeagueZone.promotion) ...[
          const SizedBox(height: 4),
          _ZoneChip(label: l10n.rankingZonePromotionChip, color: kPromotionZoneColor),
        ] else if (zone == LeagueZone.demotion) ...[
          const SizedBox(height: 4),
          _ZoneChip(label: l10n.rankingZoneDemotionChip, color: kDemotionZoneColor),
        ],
      ],
    );
  }
}

/// Podyum koltuğunun altındaki terfi/düşme etiketi.
class _ZoneChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ZoneChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
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
    // Satırın iç genişliği (yatay dolgu ve kendi satırındaki sol çizgi hariç);
    // puan rozeti bunun en fazla ~üçte birini alır, isme yer kalır.
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = constraints.maxWidth - 32 - (entry.isMe ? 4 : 0);
        return Container(
          decoration: BoxDecoration(
            color: background,
            border: entry.isMe ? const Border(left: BorderSide(color: AppColors.primary, width: 4)) : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // En az 28 px daire; büyük metin ölçeğinde sıra numarası kesilmez.
              Container(
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
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
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: math.max(0.0, rowWidth * 0.35)),
                child: _PointsBadge(points: entry.points),
              ),
            ],
          ),
        );
      },
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
      // Sınırlı alanda (podyum koltuğu, liste satırı) büyük metin ölçeğinde
      // rozet tek satırda küçülür; sığdığında boyutu değişmez.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          AppLocalizations.of(context)!.rankingPoints(points),
          maxLines: 1,
          style: TextStyle(
            fontSize: small ? 11 : 13,
            fontWeight: FontWeight.bold,
            color: AppColors.onPrimaryFixed,
          ),
        ),
      ),
    );
  }
}
