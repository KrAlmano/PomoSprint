import 'package:flutter/foundation.dart';

/// Sunucunun dönem, oda kapasitesi ve ödül kuralları. Eski sunucu yanıtı
/// eski davranışı korur; yeni politikada terfi/ödül uygunluğu satırdan okunur.
@immutable
class LeagueRules {
  const LeagueRules({
    this.awardMinMembers = 1,
    this.awardMinPoints = 1,
    this.promotionMinPoints = 1,
    this.roomCapacity = 30,
    this.launchMinActiveUsers = 25,
    this.promotionMinActiveMembers = 3,
    this.qualificationMinDays = 3,
    this.qualificationMinMinutes = 300,
    this.policyVersion = 0,
    this.competitionPhase = 'active',
    this.competitionStartsAt,
    this.fromServer = false,
  });

  /// Yeni RPC bulunmayan sunucunun mevcut kuralları.
  static const LeagueRules standard = LeagueRules();

  /// V2 sıralama geldiği halde yapılandırma geçici olarak okunamıyorsa
  /// eski tek-kişilik ödül şartı gösterilmez. Satırın aşaması yine önceliklidir.
  static const LeagueRules launchPolicyDefaults = LeagueRules(
    awardMinMembers: 10,
    roomCapacity: 25,
    policyVersion: 1,
    competitionPhase: 'preparing',
    fromServer: true,
  );
  final int awardMinMembers;
  final int awardMinPoints;
  final int promotionMinPoints;
  final int roomCapacity;
  final int launchMinActiveUsers;
  final int promotionMinActiveMembers;
  final int qualificationMinDays;
  final int qualificationMinMinutes;
  final int policyVersion;
  final String competitionPhase;
  final DateTime? competitionStartsAt;
  final bool fromServer;

  bool get hasLaunchPolicy => policyVersion >= 1;
  bool get isCompetitionActive =>
      !hasLaunchPolicy || competitionPhase == 'active';

  factory LeagueRules.fromAppConfig(Map<String, dynamic> config) {
    int read(String key, int fallback) {
      final value = config[key];
      if (value is! num || !value.isFinite) return fallback;
      return value.floor().clamp(1, 2147483647);
    }

    final policy = config['policy_version'];
    final version = policy is num && policy.isFinite
        ? policy.floor().clamp(0, 2147483647)
        : 0;
    final phase = config['competition_phase'];
    return LeagueRules(
      awardMinMembers: read('league_award_min_members', version > 0 ? 10 : 1),
      awardMinPoints: read('league_award_min_points', 1),
      promotionMinPoints: read('league_promotion_min_points', 1),
      roomCapacity: read('league_room_capacity', version > 0 ? 25 : 30),
      launchMinActiveUsers: read('league_launch_min_active_users', 25),
      promotionMinActiveMembers: read('league_promotion_min_active_members', 3),
      qualificationMinDays: read('league_qualification_min_days', 3),
      qualificationMinMinutes: read('league_qualification_min_minutes', 300),
      policyVersion: version,
      competitionPhase: version == 0 ? 'active' : _phase(phase),
      competitionStartsAt: DateTime.tryParse(
        config['competition_starts_at']?.toString() ?? '',
      ),
      fromServer:
          version > 0 ||
          const [
            'league_award_min_members',
            'league_award_min_points',
            'league_promotion_min_points',
          ].any(config.containsKey),
    );
  }

  static LeagueRules fromAppConfigResponse(Object? response) => response is Map
      ? LeagueRules.fromAppConfig(Map<String, dynamic>.from(response))
      : standard;

  /// Sıralama anındaki aşama, daha önce okunan yapılandırmadan yenidir.
  LeagueRules withRankingStatus(Map<String, dynamic> row) {
    if (!row.containsKey('competition_phase')) return this;
    final capacity = row['room_capacity'];
    final embedded = row['league_config'];
    final serverRules = embedded is Map
        ? LeagueRules.fromAppConfig(Map<String, dynamic>.from(embedded))
        : null;
    final base = serverRules?.hasLaunchPolicy == true
        ? serverRules!
        : hasLaunchPolicy
        ? this
        : launchPolicyDefaults;
    return LeagueRules(
      awardMinMembers: base.awardMinMembers,
      awardMinPoints: base.awardMinPoints,
      promotionMinPoints: base.promotionMinPoints,
      roomCapacity: capacity is num && capacity.isFinite && capacity >= 1
          ? capacity.toInt()
          : base.roomCapacity,
      launchMinActiveUsers: base.launchMinActiveUsers,
      promotionMinActiveMembers: base.promotionMinActiveMembers,
      qualificationMinDays: base.qualificationMinDays,
      qualificationMinMinutes: base.qualificationMinMinutes,
      policyVersion: base.policyVersion < 1 ? 1 : base.policyVersion,
      competitionPhase: _phase(row['competition_phase']),
      competitionStartsAt: row.containsKey('competition_starts_at')
          ? DateTime.tryParse(row['competition_starts_at']?.toString() ?? '')
          : base.competitionStartsAt,
      fromServer: true,
    );
  }

  static String _phase(Object? phase) => switch (phase) {
    'active' => 'active',
    'scheduled' => 'scheduled',
    _ => 'preparing',
  };

  @override
  bool operator ==(Object other) =>
      other is LeagueRules &&
      other.awardMinMembers == awardMinMembers &&
      other.awardMinPoints == awardMinPoints &&
      other.promotionMinPoints == promotionMinPoints &&
      other.roomCapacity == roomCapacity &&
      other.launchMinActiveUsers == launchMinActiveUsers &&
      other.promotionMinActiveMembers == promotionMinActiveMembers &&
      other.qualificationMinDays == qualificationMinDays &&
      other.qualificationMinMinutes == qualificationMinMinutes &&
      other.policyVersion == policyVersion &&
      other.competitionPhase == competitionPhase &&
      other.competitionStartsAt == competitionStartsAt &&
      other.fromServer == fromServer;

  @override
  int get hashCode => Object.hash(
    awardMinMembers,
    awardMinPoints,
    promotionMinPoints,
    roomCapacity,
    launchMinActiveUsers,
    promotionMinActiveMembers,
    qualificationMinDays,
    qualificationMinMinutes,
    policyVersion,
    competitionPhase,
    competitionStartsAt,
    fromServer,
  );

  @override
  String toString() =>
      'LeagueRules(policy: $policyVersion, phase: $competitionPhase, capacity: $roomCapacity, '
      'awardMinMembers: $awardMinMembers, awardMinPoints: $awardMinPoints, '
      'promotionMinPoints: $promotionMinPoints, fromServer: $fromServer)';
}
