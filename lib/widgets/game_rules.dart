import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import '../utils/responsive.dart';

/// Oyunun temel kuralları: tek duraklatma hakkı, günlük seans sınırı, puan
/// ve kum. Onboarding'in son adımlarında ve Profil > Yardım > "Nasıl
/// çalışır?"ta gösterilir. Sayılar get_points_config'ten okunur (istemci puan
/// hesaplamaz); alınamazsa lig bilgi sayfasıyla aynı yedekler kullanılır.
class GameRulesList extends StatefulWidget {
  /// Test ya da önceden yüklenmiş yapılandırma; verilmezse sunucudan okunur.
  final Map<String, dynamic>? config;

  const GameRulesList({super.key, this.config});

  /// Kurallarda kullanılan yapılandırma değeri ya da yedeği.
  static String configValue(Map<String, dynamic> config, String key, Object fallback) =>
      '${config[key] ?? fallback}';

  @override
  State<GameRulesList> createState() => _GameRulesListState();
}

class _GameRulesListState extends State<GameRulesList> {
  late Map<String, dynamic> _config = widget.config ?? const {};

  @override
  void initState() {
    super.initState();
    if (widget.config == null) unawaited(_load());
  }

  Future<void> _load() async {
    final config = await SupabaseService.instance.getPointsConfig();
    if (mounted && config.isNotEmpty) setState(() => _config = config);
  }

  String _value(String key, Object fallback) => GameRulesList.configValue(_config, key, fallback);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow;
    final onSurface = isDark ? AppColors.darkOnSurface : AppColors.onSurface;
    final accent = Theme.of(context).colorScheme.primary;
    final rules = [
      (Icons.pause_circle_outline_rounded, l10n.gameRulesSessions(_value('pause_penalty_pct', 20))),
      (
        Icons.emoji_events_outlined,
        l10n.gameRulesPoints(
          _value('base_points_25min', 5),
          _value('base_points_50min', 12),
          _value('coins_per_session', 20),
          _value('daily_league_session_limit', 16),
        ),
      ),
      (Icons.trending_up_rounded, l10n.gameRulesLeague),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (icon, text) in rules)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text, style: TextStyle(fontSize: 14, height: 1.4, color: onSurface)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Profil'deki "Nasıl çalışır?" sayfası.
Future<void> showGameRulesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: ContentWidth.form),
    builder: (sheetContext) {
      final l10n = AppLocalizations.of(sheetContext)!;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.gameRulesTitle,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const GameRulesList(),
              ],
            ),
          ),
        ),
      );
    },
  );
}
