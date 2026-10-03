import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/supabase_service.dart';
import '../services/language_service.dart';

// Lig bilgilendirme popup'ı. İçerikteki tüm sayılar (grup büyüklüğü,
// yükselme/düşme sayısı, puan değerleri, günlük sınır) sunucudan okunur:
// - Tier, üye sayısı, yükselme/düşme eşiği -> get_league_ranking RPC'si
//   (bu da içeride get_league_zones(member_count) çağırır).
// - Puan değerleri, seri bonus yüzdeleri, duraklatma cezası, günlük sınır
//   -> get_points_config RPC'si (complete_study_session'daki sabitlerle
//   aynı tutulması gereken, salt-okunur bir config kaynağı).
// Lig kademe adları/ikonları (Bronz/Gümüş/Altın/Safir/Elmas) sabit UI
// kopyasıdır, sunucudan değişmeyen kozmetik etiketlerdir.
Future<void> showLeagueInfoSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const LeagueInfoSheet(),
  );
}

class LeagueInfoSheet extends StatefulWidget {
  const LeagueInfoSheet({super.key});

  @override
  State<LeagueInfoSheet> createState() => _LeagueInfoSheetState();
}

class _LeagueInfoSheetState extends State<LeagueInfoSheet> {
  bool _isLoading = true;
  int _tier = 1;
  int _memberCount = 1;
  int _promotionZoneEnd = 3;
  int _demotionZoneStart = 999;
  Map<String, dynamic> _pointsConfig = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SupabaseService.instance.getLeagueRanking(),
        SupabaseService.instance.getPointsConfig(),
      ]);
      final ranking = results[0] as List<Map<String, dynamic>>;
      final config = results[1] as Map<String, dynamic>;

      if (ranking.isNotEmpty) {
        final me = ranking.firstWhere(
          (u) => u['is_me'] == true,
          orElse: () => ranking.first,
        );
        _tier = (me['tier'] as int?) ?? 1;
        _memberCount = (me['member_count'] as int?) ?? ranking.length;
        _promotionZoneEnd = (me['promotion_zone_end'] as int?) ?? 3;
        _demotionZoneStart = (me['demotion_zone_start'] as int?) ?? 999;
      }
      _pointsConfig = config;
    } catch (_) {
      // Sunucudan veri alınamazsa varsayılan (güvenli) değerlerle devam edilir.
    }
    if (mounted) setState(() => _isLoading = false);
  }

  static const List<Map<String, String>> _tiers = [
    {'emoji': '🥉', 'tr': 'Bronz Kum Saati', 'en': 'Bronze Hourglass'},
    {'emoji': '🥈', 'tr': 'Gümüş Kum Saati', 'en': 'Silver Hourglass'},
    {'emoji': '🥇', 'tr': 'Altın Kum Saati', 'en': 'Gold Hourglass'},
    {'emoji': '💎', 'tr': 'Safir Kum Saati', 'en': 'Sapphire Hourglass'},
    {'emoji': '👑', 'tr': 'Elmas Kum Saati', 'en': 'Diamond Hourglass'},
  ];

  @override
  Widget build(BuildContext context) {
    final lang = LanguageService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest;
    final cardBg = isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow;
    final onSurface = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final onSurfaceVariant = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;

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
                            lang.isTurkish ? 'Lig Sistemi Nasıl Çalışır?' : 'How the League System Works',
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: onSurface),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _sectionTitle(lang.isTurkish ? 'Lig Nedir?' : 'What is a League?', onSurface),
                    _card(
                      cardBg,
                      Text(
                        lang.isTurkish
                            ? 'Her 14 günde bir seninle benzer seviyedeki en fazla 30 kişiyle aynı gruba düşersin. Dönem boyunca kim daha çok odaklanırsa üst sıraya çıkar.'
                            : 'Every 14 days you\'re grouped with up to 30 people at a similar level. Whoever focuses the most during the period climbs to the top.',
                        style: TextStyle(fontSize: 14, height: 1.5, color: onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _sectionTitle(lang.isTurkish ? 'Lig Kademeleri' : 'League Tiers', onSurface),
                    _card(
                      cardBg,
                      Column(
                        children: List.generate(_tiers.length, (i) {
                          final tierNum = i + 1;
                          final isCurrent = tierNum == _tier;
                          final t = _tiers[i];
                          return Padding(
                            padding: EdgeInsets.only(bottom: i == _tiers.length - 1 ? 0 : 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isCurrent ? AppColors.primaryContainer.withValues(alpha: 0.15) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isCurrent ? Border.all(color: AppColors.primaryContainer, width: 1.5) : null,
                              ),
                              child: Row(
                                children: [
                                  Text(t['emoji']!, style: const TextStyle(fontSize: 22)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      lang.isTurkish ? t['tr']! : t['en']!,
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
                                        lang.isTurkish ? 'Şu an buradasın' : 'You are here',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _sectionTitle(lang.isTurkish ? 'Puan Nasıl Kazanılır?' : 'How Do You Earn Points?', onSurface),
                    _card(
                      cardBg,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _pointRow(
                            Icons.timer_outlined,
                            lang.isTurkish
                                ? '25 dakikalık odak: ${_pointsConfig['base_points_25min'] ?? 5} puan'
                                : '25-minute focus: ${_pointsConfig['base_points_25min'] ?? 5} pts',
                            onSurface,
                          ),
                          const SizedBox(height: 8),
                          _pointRow(
                            Icons.timer,
                            lang.isTurkish
                                ? '50 dakikalık odak: ${_pointsConfig['base_points_50min'] ?? 12} puan'
                                : '50-minute focus: ${_pointsConfig['base_points_50min'] ?? 12} pts',
                            onSurface,
                          ),
                          const SizedBox(height: 8),
                          _pointRow(
                            Icons.local_fire_department_outlined,
                            lang.isTurkish ? 'Seri bonusu:' : 'Streak bonus:',
                            onSurface,
                          ),
                          const SizedBox(height: 6),
                          ..._buildStreakTiers(onSurfaceVariant, lang.isTurkish),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              lang.isTurkish
                                  ? 'Her gün en az 1 pomodoro tamamlayarak serini canlı tut.'
                                  : 'Keep your streak alive by completing at least 1 pomodoro every day.',
                              style: TextStyle(fontSize: 12, color: onSurfaceVariant),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _pointRow(
                            Icons.pause_circle_outline,
                            lang.isTurkish
                                ? 'Seansı duraklatırsan puan %${_pointsConfig['pause_penalty_pct'] ?? 20} azalır.'
                                : 'Pausing a session reduces its points by ${_pointsConfig['pause_penalty_pct'] ?? 20}%.',
                            onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          _pointRow(
                            Icons.savings_outlined,
                            lang.isTurkish
                                ? '🪙 Kum Tanesi: Tamamladığın her pomodorodan ${_pointsConfig['coins_per_session'] ?? 20} kum tanesi kazanırsın. Karakter koleksiyonundan yeni kum saatleri açmak için kullanılır.'
                                : '🪙 Sand Grains: You earn ${_pointsConfig['coins_per_session'] ?? 20} sand grains from every completed pomodoro. Spend them to unlock new hourglass characters.',
                            onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    _sectionTitle(lang.isTurkish ? 'Yükselme ve Düşme' : 'Promotion & Demotion', onSurface),
                    _card(
                      cardBg,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.isTurkish
                                ? 'Lig dönemi 14 günde bir, Pazar 23:59\'da (Türkiye saati) sona erer.'
                                : 'The league period ends every 14 days, Sunday 23:59 (Turkey time).',
                            style: TextStyle(fontSize: 13, color: onSurfaceVariant, height: 1.5),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _promotionDemotionText(lang.isTurkish),
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    _sectionTitle(lang.isTurkish ? 'Günlük Sınır' : 'Daily Limit', onSurface),
                    _card(
                      cardBg,
                      Text(
                        lang.isTurkish
                            ? 'Günde en fazla ${_pointsConfig['daily_league_session_limit'] ?? 16} pomodoro lig puanına sayılır. Üstü kişisel istatistiklerine ve serine eklenmeye devam eder ama lig sıralamasını etkilemez.'
                            : 'Up to ${_pointsConfig['daily_league_session_limit'] ?? 16} pomodoros per day count toward league points. Anything beyond that keeps adding to your personal stats and streak, but won\'t affect the league ranking.',
                        style: TextStyle(fontSize: 14, height: 1.5, color: onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _sectionTitle(lang.isTurkish ? 'Puanım Neden Artmadı?' : 'Why Didn\'t My Points Go Up?', onSurface),
                    _card(
                      cardBg,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _faqRow(
                            lang.isTurkish
                                ? 'Günlük ${_pointsConfig['daily_league_session_limit'] ?? 16} pomodoro sınırına ulaşmış olabilirsin.'
                                : 'You may have hit the daily ${_pointsConfig['daily_league_session_limit'] ?? 16}-pomodoro limit.',
                            onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          _faqRow(
                            lang.isTurkish
                                ? 'Seansı çok erken iptal etmiş olabilirsin.'
                                : 'The session may have been cancelled too early.',
                            onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          _faqRow(
                            lang.isTurkish
                                ? 'Lig dönemi yeni sıfırlanmış olabilir.'
                                : 'The league period may have just reset.',
                            onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  List<Widget> _buildStreakTiers(Color color, bool isTurkish) {
    final tiers = (_pointsConfig['streak_bonus_tiers'] as List?) ?? [
      {'min_days': 3, 'bonus_pct': 10},
      {'min_days': 7, 'bonus_pct': 20},
      {'min_days': 14, 'bonus_pct': 30},
    ];
    // Rapor için 3-6/7-13/14+ gün aralık gösterimi: bir sonraki eşiğin
    // bir altına kadar geçerli olduğundan aralığı buradan türetiyoruz.
    final widgets = <Widget>[];
    for (int i = 0; i < tiers.length; i++) {
      final t = tiers[i] as Map;
      final minDays = t['min_days'];
      final pct = t['bonus_pct'];
      final nextMin = i + 1 < tiers.length ? (tiers[i + 1] as Map)['min_days'] : null;
      final rangeText = nextMin != null
          ? '$minDays-${(nextMin as int) - 1} ${isTurkish ? "gün" : "days"}'
          : '$minDays+ ${isTurkish ? "gün" : "days"}';
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 28, bottom: 4),
          child: Text(
            '$rangeText: %$pct',
            style: TextStyle(fontSize: 13, color: color),
          ),
        ),
      );
    }
    return widgets;
  }

  String _promotionDemotionText(bool isTurkish) {
    final promoText = _tier >= 5
        ? (isTurkish ? 'En üst ligdesin, yükselecek yer yok.' : 'You\'re in the top league, there\'s nowhere higher to go.')
        : (isTurkish ? 'Bu dönem ilk $_promotionZoneEnd yükseliyor' : 'This period the top $_promotionZoneEnd get promoted');

    final demoteCount = _demotionZoneStart > _memberCount ? 0 : (_memberCount - _demotionZoneStart + 1);
    final demoText = (_tier <= 1 || demoteCount <= 0)
        ? (isTurkish ? 'Bronz ligde düşme yoktur.' : 'There\'s no demotion from the Bronze league.')
        : (isTurkish ? 'son $demoteCount düşüyor.' : ', the bottom $demoteCount get demoted.');

    if (_tier >= 5) {
      return '$promoText\n$demoText';
    }
    return '$promoText, $demoText';
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
