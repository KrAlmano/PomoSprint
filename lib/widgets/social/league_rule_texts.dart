import '../../l10n/app_localizations.dart';
import '../../models/avatar_model.dart';
import '../../models/league_rules.dart';

// Lig açıklamaları sunucunun güncel kurallarını kullanır. Eski RPC
// yanıtında eski ödül metinleri korunur.

/// "Bu dönem (en az N puan) toplayan ilk [count] kişi bir üst lige yükselir."
String leagueInfoPromoteText(
  AppLocalizations l10n,
  int count,
  LeagueRules rules,
) => rules.promotionMinPoints > 1
    ? l10n.leagueInfoPromoteMinPoints(count, rules.promotionMinPoints)
    : l10n.leagueInfoPromote(count);

/// Terfi bölgesinde ama puanı terfi için yetmeyen kullanıcıya.
String promotionNeedsPointsText(AppLocalizations l10n, LeagueRules rules) =>
    rules.promotionMinPoints > 1
    ? l10n.rankingZoneNeedsMinPointsMe(rules.promotionMinPoints)
    : l10n.rankingZoneNeedsPointsMe;

String _withMinMembers(AppLocalizations l10n, String text, LeagueRules rules) {
  if (rules.hasLaunchPolicy) {
    return '$text ${l10n.leagueAwardActiveRequirements(rules.awardMinMembers, rules.qualificationMinDays, rules.qualificationMinMinutes, rules.awardMinPoints)}';
  }
  return rules.awardMinMembers > 1
      ? '$text ${l10n.leagueAwardMinMembersNote(rules.awardMinMembers)}'
      : text;
}

/// Koleksiyondaki "Lig Kazanımları" açıklaması.
String leagueAwardsSubText(AppLocalizations l10n, LeagueRules rules) =>
    _withMinMembers(
      l10n,
      rules.awardMinPoints > 1
          ? l10n.leagueAwardsSubMinPoints(rules.awardMinPoints)
          : l10n.leagueAwardsSub,
      rules,
    );

/// Kilitli lig ödülü avatarına dokununca gösterilen açıklama. Canlı ödül
/// kuralı: 1. → *_monthly (Şampiyonluk), 2.-3. → *_weekly (Podyum).
String leagueAwardLockedText(
  AppLocalizations l10n,
  AvatarCharacter avatar,
  LeagueRules rules,
) {
  final points = rules.awardMinPoints;
  final String body;
  if (avatar.isChampionAward) {
    body = points > 1
        ? l10n.leagueAwardLockedBodyChampionMinPoints(points)
        : l10n.leagueAwardLockedBodyChampion;
  } else if (avatar.isPodiumAward) {
    body = points > 1
        ? l10n.leagueAwardLockedBodyPodiumMinPoints(points)
        : l10n.leagueAwardLockedBodyPodium;
  } else {
    body = points > 1
        ? l10n.leagueAwardLockedBodyMinPoints(points)
        : l10n.leagueAwardLockedBody;
  }
  return _withMinMembers(l10n, body, rules);
}
