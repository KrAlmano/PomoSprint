import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../services/supabase_service.dart';
import 'social/league_tiers.dart';
import 'social/ranking_models.dart';

// Lig bilgilendirme popup'ı. İçerikteki sayılar sunucudan okunur:
// - Tier, üye sayısı, yükselme/düşme eşiği ve dönem sonu -> sıralama
//   ekranının zaten yüklediği [LeagueSnapshot] (verilmezse
//   get_my_league_ranking ile çekilir).
// - Puan değerleri, seri bonus yüzdeleri, duraklatma cezası, günlük sınır
//   -> get_points_config RPC'si.
// Dönem uzunluğu (14 gün) metinde sabitlenmez; bitiş tarihi sunucudan
// gösterilir.
Future<void> showLeagueInfoSheet(BuildContext context, {LeagueSnapshot? league}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LeagueInfoSheet(league: league),
  );
}

class LeagueInfoSheet extends StatefulWidget {
  final LeagueSnapshot? league;

  const LeagueInfoSheet({super.key, this.league});

  @override
  State<LeagueInfoSheet> createState() => _LeagueInfoSheetState();
}

class _LeagueInfoSheetState extends State<LeagueInfoSheet> {
  bool _isLoading = true;
  LeagueSnapshot? _league;
  Map<String, dynamic> _pointsConfig = {};

  @override
  void initState() {
    super.initState();
    _league = widget.league;
    unawaited(_load());
  }

  Future<void> _load() async {
    final service = SupabaseService.instance;
    final configFuture = service.getPointsConfig();
    if (_league == null) {
      try {
        final rows = await service.getLeagueRanking();
        if (rows.isNotEmpty) _league = LeagueSnapshot.fromRows(rows);
      } catch (e) {
        // Lig bilgisi alınamazsa kurallar genel metinle gösterilir.
        debugPrint('[RANKING] Lig bilgisi alınamadı: $e');
      }
    }
    final config = await configFuture;
    if (mounted) {
      setState(() {
        _pointsConfig = config;
        _isLoading = false;
      });
    }
  }

  String _config(String key, Object fallback) => '${_pointsConfig[key] ?? fallback}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest;
    final cardBg = isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow;
    final onSurface = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final onSurfaceVariant = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final dailyLimit = _config('daily_league_session_limit', 16);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: onSurfaceVariant.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.hourglass_bottom_rounded, color: AppColors.primaryContainer, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.leagueInfoTitle,
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: onSurface),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _sectionTitle(l10n.leagueInfoWhatTitle, onSurface),
                    _card(
                      cardBg,
                      Text(
                        l10n.leagueInfoWhatBody,
                        style: TextStyle(fontSize: 14, height: 1.5, color: onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _sectionTitle(l10n.leagueInfoTiersTitle, onSurface),
                    _card(cardBg, _buildTierList(l10n, onSurface)),
                    const SizedBox(height: 20),

                    _sectionTitle(l10n.leagueInfoPointsTitle, onSurface),
                    _card(
                      cardBg,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _pointRow(Icons.timer_outlined, l10n.leagueInfoPoints25(_config('base_points_25min', 5)), onSurface),
                          const SizedBox(height: 8),
                          _pointRow(Icons.timer, l10n.leagueInfoPoints50(_config('base_points_50min', 12)), onSurface),
                          const SizedBox(height: 8),
                          _pointRow(Icons.local_fire_department_outlined, l10n.leagueInfoStreakBonus, onSurface),
                          const SizedBox(height: 6),
                          ..._buildStreakTiers(l10n, onSurfaceVariant),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              l10n.leagueInfoStreakKeep,
                              style: TextStyle(fontSize: 12, color: onSurfaceVariant),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _pointRow(
                            Icons.pause_circle_outline,
                            l10n.leagueInfoPausePenalty(_config('pause_penalty_pct', 20)),
                            onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          _pointRow(
                            Icons.savings_outlined,
                            l10n.leagueInfoCoins(_config('coins_per_session', 20)),
                            onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    _sectionTitle(l10n.leagueInfoPromotionTitle, onSurface),
                    _card(
                      cardBg,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _periodText(l10n),
                            style: TextStyle(fontSize: 13, color: onSurfaceVariant, height: 1.5),
                          ),
                          if (_league != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              promotionDemotionText(l10n, _league!),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface, height: 1.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    _sectionTitle(l10n.leagueInfoDailyLimitTitle, onSurface),
                    _card(
                      cardBg,
                      Text(
                        l10n.leagueInfoDailyLimitBody(dailyLimit),
                        style: TextStyle(fontSize: 14, height: 1.5, color: onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _sectionTitle(l10n.leagueInfoFaqTitle, onSurface),
                    _card(
                      cardBg,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _faqRow(l10n.leagueInfoFaqLimit(dailyLimit), onSurfaceVariant),
                          const SizedBox(height: 8),
                          _faqRow(l10n.leagueInfoFaqCancelled, onSurfaceVariant),
                          const SizedBox(height: 8),
                          _faqRow(l10n.leagueInfoFaqPending, onSurfaceVariant),
                          const SizedBox(height: 8),
                          _faqRow(l10n.leagueInfoFaqReset, onSurfaceVariant),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildTierList(AppLocalizations l10n, Color onSurface) {
    final currentTier = _league?.tier;
    return Column(
      children: List.generate(kLeagueTierCount, (i) {
        final tier = i + 1;
        final isCurrent = tier == currentTier;
        return Padding(
          padding: EdgeInsets.only(bottom: i == kLeagueTierCount - 1 ? 0 : 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isCurrent ? AppColors.primaryContainer.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isCurrent ? Border.all(color: AppColors.primaryContainer, width: 1.5) : null,
            ),
            child: Row(
              children: [
                Text(leagueTierEmoji(tier), style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    leagueTierName(l10n, tier),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? AppColors.primary : onSurface,
                    ),
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      l10n.leagueInfoYouAreHere,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  String _periodText(AppLocalizations l10n) {
    final end = _league?.endDate;
    if (end == null) return l10n.leagueInfoPeriodGeneric;
    final formatted = DateFormat.MMMMEEEEd(l10n.localeName).add_Hm().format(end.toLocal());
    return l10n.leagueInfoPeriodEnds(formatted);
  }

  List<Widget> _buildStreakTiers(AppLocalizations l10n, Color color) {
    final tiers = (_pointsConfig['streak_bonus_tiers'] as List?)?.whereType<Map>().toList() ??
        const [
          {'min_days': 3, 'bonus_pct': 10},
          {'min_days': 7, 'bonus_pct': 20},
          {'min_days': 14, 'bonus_pct': 30},
        ];
    // 3-6/7-13/14+ gün aralıkları: her kademe bir sonraki eşiğin bir altına
    // kadar geçerli.
    return [
      for (var i = 0; i < tiers.length; i++)
        Padding(
          padding: const EdgeInsets.only(left: 28, bottom: 4),
          child: Text(
            _streakRangeText(l10n, tiers[i], i + 1 < tiers.length ? tiers[i + 1] : null),
            style: TextStyle(fontSize: 13, color: color),
          ),
        ),
    ];
  }

  String _streakRangeText(AppLocalizations l10n, Map tier, Map? next) {
    final from = '${tier['min_days']}';
    final pct = '${tier['bonus_pct']}';
    final nextMin = next?['min_days'];
    if (nextMin is num) return l10n.leagueInfoStreakRange(from, '${nextMin.toInt() - 1}', pct);
    return l10n.leagueInfoStreakRangeOpen(from, pct);
  }

  Widget _sectionTitle(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _card(Color bg, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _pointRow(IconData icon, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryContainer),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 14, color: color, height: 1.4)),
        ),
      ],
    );
  }

  Widget _faqRow(String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('•  ', style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 14, color: color, height: 1.4)),
        ),
      ],
    );
  }
}

/// Yükselme ve düşme kuralı; her durum ayrı tam cümleyle yazılır. Kullanıcı
/// henüz bir odada değilse (sunucunun lig-yok satırı: tek kişi, bölge 1/999)
/// oda kuralı yerine yerleştirme bilgisi gösterilir.
@visibleForTesting
String promotionDemotionText(AppLocalizations l10n, LeagueSnapshot league) {
  if (league.awaitingPlacement) return l10n.leagueAwaitingPlacementBody;
  final promotion = league.isTopTier ? l10n.leagueInfoTopTier : l10n.leagueInfoPromote(league.promotionZoneEnd);
  final String demotion;
  if (league.isBottomTier) {
    demotion = l10n.leagueInfoNoDemotionBronze;
  } else if (league.demotionCount <= 0) {
    demotion = l10n.leagueInfoNoDemotionThisPeriod;
  } else {
    demotion = l10n.leagueInfoDemote(league.demotionCount);
  }
  return '$promotion\n$demotion';
}
