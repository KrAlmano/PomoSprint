import '../../l10n/app_localizations.dart';
import 'ranking_models.dart';

// Lig kademe adları/ikonları sunucudan değişmeyen kozmetik etiketlerdir;
// sıralama ekranı ve lig bilgi sheet'i bu tek kaynaktan okur.
const List<String> _tierEmojis = ['🥉', '🥈', '🥇', '💎', '👑'];

int _normalize(int tier) => tier.clamp(1, kLeagueTierCount);

String leagueTierEmoji(int tier) => _tierEmojis[_normalize(tier) - 1];

String leagueTierName(AppLocalizations l10n, int tier) {
  switch (_normalize(tier)) {
    case 2:
      return l10n.leagueTierSilver;
    case 3:
      return l10n.leagueTierGold;
    case 4:
      return l10n.leagueTierSapphire;
    case 5:
      return l10n.leagueTierDiamond;
    default:
      return l10n.leagueTierBronze;
  }
}

/// Örn. "🥉 Bronz Kum Saati Ligi".
String leagueTitle(AppLocalizations l10n, int tier) =>
    '${leagueTierEmoji(tier)} ${l10n.leagueTierLeagueName(leagueTierName(l10n, tier))}';
