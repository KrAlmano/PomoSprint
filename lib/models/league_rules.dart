import 'package:flutter/foundation.dart';

/// Lig dönem sonu ödül ve terfi kuralı. proposed/20 bunları ürün düğmesi
/// yapar (app_config, herkese açık get_app_config()):
/// `league_award_min_members`, `league_award_min_points`,
/// `league_promotion_min_points`; varsayılanları 1/1/1 = bugünkü kural.
///
/// Canlıda get_app_config yok (proposed/13; çağrı PGRST202 verir) ve
/// process_weekly_leagues bugünkü kuralla çalışır: puanı > 0 olan ilk 3 ödül
/// alır, terfi kotasındaki puanı > 0 olan terfi eder, oda büyüklüğü şartı
/// yok. Değer okunamadığında istemci de bu kuralla ([standard]) çalışır.
@immutable
class LeagueRules {
  const LeagueRules({
    this.awardMinMembers = 1,
    this.awardMinPoints = 1,
    this.promotionMinPoints = 1,
    this.fromServer = false,
  });

  /// Bugünkü (canlı) kural.
  static const LeagueRules standard = LeagueRules();

  /// Ödül için dönem sonunda odadaki en az üye sayısı.
  final int awardMinMembers;

  /// Ödül için en az dönem puanı (1 = puanı > 0).
  final int awardMinPoints;

  /// Terfi için en az dönem puanı (1 = puanı > 0).
  final int promotionMinPoints;

  /// Değerler sunucunun get_app_config yanıtındaki lig anahtarlarından
  /// geldi: proposed/20 uygulanmış. 20 ligsiz kullanıcının satırını
  /// member_count 0 ile bildirir; tek kişilik gerçek oda 1 döner.
  final bool fromServer;

  static const String _awardMinMembersKey = 'league_award_min_members';
  static const String _awardMinPointsKey = 'league_award_min_points';
  static const String _promotionMinPointsKey = 'league_promotion_min_points';

  /// get_app_config() yanıtından. Sunucuyla aynı okuma:
  /// `greatest(coalesce(app_config_int(key), 1), 1)`; sayı olmayan değer 1.
  factory LeagueRules.fromAppConfig(Map<String, dynamic> config) {
    int read(String key) {
      final value = config[key];
      if (value is! num || !value.isFinite) return 1;
      final floored = value.floor();
      return floored < 1 ? 1 : floored;
    }

    return LeagueRules(
      awardMinMembers: read(_awardMinMembersKey),
      awardMinPoints: read(_awardMinPointsKey),
      promotionMinPoints: read(_promotionMinPointsKey),
      fromServer: config.containsKey(_awardMinMembersKey) ||
          config.containsKey(_awardMinPointsKey) ||
          config.containsKey(_promotionMinPointsKey),
    );
  }

  /// get_app_config çağrısının yanıtı (hatasız): Map değilse bugünkü kural.
  static LeagueRules fromAppConfigResponse(Object? response) =>
      response is Map ? LeagueRules.fromAppConfig(Map<String, dynamic>.from(response)) : standard;

  @override
  bool operator ==(Object other) =>
      other is LeagueRules &&
      other.awardMinMembers == awardMinMembers &&
      other.awardMinPoints == awardMinPoints &&
      other.promotionMinPoints == promotionMinPoints &&
      other.fromServer == fromServer;

  @override
  int get hashCode => Object.hash(awardMinMembers, awardMinPoints, promotionMinPoints, fromServer);

  @override
  String toString() => 'LeagueRules(awardMinMembers: $awardMinMembers, awardMinPoints: $awardMinPoints, '
      'promotionMinPoints: $promotionMinPoints, fromServer: $fromServer)';
}
