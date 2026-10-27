import '../../models/league_rules.dart';
import '../../models/user_model.dart';
import '../../utils/study_day.dart';

/// Sıralama ekranlarının ortak satır modeli. Her sekme kendi puan anahtarını
/// açıkça eşler (lig: weekly_points, aylık: total_points, arkadaşlar:
/// lifetime_points); aynı anahtara farklı anlamlar yüklenmez.
class RankingEntry {
  final String? name;
  final String? avatarId;
  final int points;
  final int? minutes;

  /// Yalnızca sunucunun döndürdüğü is_me (lig, aylık ve tüm zamanlar
  /// RPC'lerinin hepsi döndürür) ya da yerel kullanıcıdan kurulan satır
  /// (arkadaşlar sekmesi) ile belirlenir; isimle eşleştirme yapılmaz.
  final bool isMe;

  /// Oturumlu arkadaşlar, lig ve aylık RPC'lerinin döndürdüğü kimlik.
  /// Oturumsuz aylık listede kimlik gönderilmez.
  final String? userId;

  /// Kullanıcının gizlediği biri: sıra ve puan korunur (lig bölgeleri
  /// bozulmasın), ad ve avatar gösterilmez.
  final bool hidden;

  /// Yeni lig RPC'sinin tam dönem sonu uygunluğu; null eski sözleşmedir.
  final bool? promotionEligible;
  final bool? awardEligible;
  final bool? demotionEligible;

  const RankingEntry({
    this.name,
    this.avatarId,
    required this.points,
    this.minutes,
    this.isMe = false,
    this.userId,
    this.hidden = false,
    this.promotionEligible,
    this.awardEligible,
    this.demotionEligible,
  });

  factory RankingEntry.fromRow(
    Map<String, dynamic> row, {
    required String pointsKey,
  }) {
    final id = row['id']?.toString();
    return RankingEntry(
      name: row['name']?.toString(),
      hidden: row['is_blocked'] == true,
      promotionEligible: row['promotion_eligible'] is bool
          ? row['promotion_eligible'] as bool
          : null,
      awardEligible: row['award_eligible'] is bool
          ? row['award_eligible'] as bool
          : null,
      demotionEligible: row['demotion_eligible'] is bool
          ? row['demotion_eligible'] as bool
          : null,
      avatarId: row['avatar_id']?.toString(),
      points: _asInt(row[pointsKey]),
      minutes: row['total_minutes'] == null
          ? null
          : _asInt(row['total_minutes']),
      isMe: row['is_me'] == true,
      userId: (id == null || id.isEmpty) ? null : id,
    );
  }

  /// Gizlenmiş hali: ad, kimlik ve avatar çıkarılır; sıra ve puan aynı kalır.
  RankingEntry asHidden() => RankingEntry(
    points: points,
    minutes: minutes,
    isMe: isMe,
    hidden: true,
    promotionEligible: promotionEligible,
    awardEligible: awardEligible,
    demotionEligible: demotionEligible,
  );

  /// Puana, sonra dakikaya göre azalan sıralama.
  static int compare(RankingEntry a, RankingEntry b) {
    final byPoints = b.points.compareTo(a.points);
    if (byPoints != 0) return byPoints;
    return (b.minutes ?? 0).compareTo(a.minutes ?? 0);
  }
}

/// Kullanıcının lig odası ve sunucunun hesapladığı dönem sonu uygunluğu.
/// V2 yanıtında has_league yerleşmeyi, active_member_count dönem içinde
/// seans tamamlayanları belirtir. Hazırlık/planlama sırasında ödül ve
/// terfi önizlemesi gösterilmez. Eski RPC yanıtları da desteklenir.
class LeagueSnapshot {
  final int tier;
  final DateTime? endDate;
  final int promotionZoneEnd;
  final int demotionZoneStart;
  final int memberCount;
  final int activeMemberCount;

  /// RPC sırası korunur; gizlenen kullanıcının sıra/uygunluğu kaybolmaz.
  final List<RankingEntry> eligibilityEntries;

  /// Kullanıcının bu dönemki lig puanı (kendi satırının weekly_points'i).
  final int myPoints;

  /// Sunucunun oda ve dönem sonu kuralları; eski yanıt da desteklenir.
  final LeagueRules rules;

  /// Kullanıcı gerçekten bir odada mı? null: bilinmiyor; o zaman satırdan
  /// eski kuralla tahmin edilir (tek kişi ve puansız = odada değil).
  final bool? inRoom;

  const LeagueSnapshot({
    required this.tier,
    required this.endDate,
    required this.promotionZoneEnd,
    required this.demotionZoneStart,
    required this.memberCount,
    this.activeMemberCount = 0,
    this.eligibilityEntries = const [],
    this.myPoints = 0,
    this.rules = LeagueRules.standard,
    this.inRoom,
  });

  /// [rows] boş olmamalı. Oda özeti için kendi satırı, yapılandırma için
  /// yanıtın league_config nesnesi esas alınır. Yeni RPC uygunluğu her
  /// satırda tam olarak hesaplar; istemci puandan gün/dakika tahmini yapmaz.
  /// Eski yanıtın has_league alanı yoksa üye sayısı, puan ve sunucunun
  /// kural sürümüyle ayırt edilir. Daha eski tek kişilik puansız yanıtta
  /// [hasLeagueHistory] yedek bilgidir. Yalnız eski yanıtta eksik dönem
  /// tarihi [assumedLeaguePeriodEnd] ile tahmin edilir.
  factory LeagueSnapshot.fromRows(
    List<Map<String, dynamic>> rows, {
    DateTime? now,
    LeagueRules rules = LeagueRules.standard,
    bool? hasLeagueHistory,
  }) {
    final myRow = rows.where((r) => r['is_me'] == true).firstOrNull;
    final me = myRow ?? rows.first;
    final memberCount = _asInt(me['member_count'], fallback: rows.length);
    final myPoints = myRow == null ? 0 : _asInt(myRow['weekly_points']);
    final embeddedConfig = rows
        .map((row) => row['league_config'])
        .whereType<Map>()
        .firstOrNull;
    final currentRules = rules.withRankingStatus({
      ...me,
      'league_config': ?embeddedConfig,
    });
    final hasLeague = me['has_league'];
    final bool? inRoom;
    if (hasLeague is bool) {
      inRoom = hasLeague;
    } else if (memberCount <= 0) {
      inRoom = false;
    } else if (memberCount > 1 || myPoints > 0 || rules.fromServer) {
      inRoom = true;
    } else {
      inRoom = hasLeagueHistory;
    }
    return LeagueSnapshot(
      tier: _asInt(me['tier'], fallback: 1).clamp(1, kLeagueTierCount),
      endDate:
          DateTime.tryParse(me['end_date']?.toString() ?? '') ??
          currentRules.periodEnd ??
          (currentRules.isCalendarMonthly
              ? nextCalendarMonthReset(now ?? DateTime.now())
              : assumedLeaguePeriodEnd(now ?? DateTime.now())),
      promotionZoneEnd: _asInt(me['promotion_zone_end'], fallback: 0),
      demotionZoneStart: _asInt(me['demotion_zone_start'], fallback: 999),
      memberCount: memberCount,
      activeMemberCount: _asInt(
        me['active_member_count'],
        fallback: currentRules.hasLaunchPolicy ? 0 : memberCount,
      ),
      eligibilityEntries: [
        for (final row in rows)
          RankingEntry.fromRow(row, pointsKey: 'weekly_points'),
      ],
      myPoints: myPoints,
      rules: currentRules,
      inRoom: inRoom,
    );
  }

  bool get isTopTier => tier >= kLeagueTierCount;
  bool get isBottomTier => tier <= 1;

  /// Kullanıcı henüz bir lig odasına yerleşmedi: kıyaslanacak kimse yok,
  /// terfi/düşme bölgesi gösterilmez. Sunucu ilk puanlı seansta kullanıcıyı
  /// bir odaya yerleştirir. [inRoom] bilinmiyorsa eski kural: tek kişi ve
  /// puansız.
  bool get awaitingPlacement =>
      inRoom == null ? memberCount <= 1 && myPoints <= 0 : !inRoom!;

  /// Kullanıcı bir odada ama odada şimdilik yalnız (ör. terfi edip yeni
  /// odasında tek kalan; t4-F6).
  bool get isAloneInRoom => !awaitingPlacement && memberCount <= 1;

  int get demotionCount =>
      !rules.isCompetitionActive || demotionZoneStart > memberCount
      ? 0
      : memberCount - demotionZoneStart + 1;

  RankingEntry? _entryAt(int rank, RankingEntry? entry) =>
      entry ??
      (rank >= 1 && rank <= eligibilityEntries.length
          ? eligibilityEntries[rank - 1]
          : null);

  bool isPromotionRank(int rank, int points, {RankingEntry? entry}) {
    if (awaitingPlacement ||
        !rules.isCompetitionActive ||
        isTopTier ||
        rank < 1) {
      return false;
    }
    if (rules.hasLaunchPolicy) {
      return _entryAt(rank, entry)?.promotionEligible == true;
    }
    return points >= rules.promotionMinPoints && rank <= promotionZoneEnd;
  }

  bool isDemotionRank(int rank, {RankingEntry? entry}) {
    if (awaitingPlacement ||
        !rules.isCompetitionActive ||
        isBottomTier ||
        rank < 1) {
      return false;
    }
    if (rules.hasLaunchPolicy) {
      return _entryAt(rank, entry)?.demotionEligible == true;
    }
    return rank >= demotionZoneStart;
  }

  /// Yeni politikada puan veya sıra tek başına ödül hakkı göstermez;
  /// aktif rakip, farklı gün ve dakika şartları sunucuda hesaplanır.
  bool earnsAward(int rank, int points, {RankingEntry? entry}) {
    if (awaitingPlacement ||
        !rules.isCompetitionActive ||
        rank < 1 ||
        rank > 3) {
      return false;
    }
    if (rules.hasLaunchPolicy) {
      return _entryAt(rank, entry)?.awardEligible == true;
    }
    return points >= rules.awardMinPoints &&
        memberCount >= rules.awardMinMembers;
  }

  LeagueZone zoneOf(int rank, int points, {RankingEntry? entry}) {
    if (awaitingPlacement || !rules.isCompetitionActive) return LeagueZone.none;
    if (isPromotionRank(rank, points, entry: entry)) {
      return LeagueZone.promotion;
    }
    if (isDemotionRank(rank, entry: entry)) return LeagueZone.demotion;
    if (!rules.hasLaunchPolicy && !isTopTier && rank <= promotionZoneEnd) {
      return LeagueZone.promotionNeedsPoints;
    }
    return LeagueZone.none;
  }
}

/// Kullanıcı daha önce bir lig odasına yerleşti mi ([LeagueSnapshot.fromRows]
/// `hasLeagueHistory`)? Canlıda puan kazandıran her seans kullanıcıyı bir
/// odaya yerleştirir (ensure_user_in_league) ve üyelik silinmez: ömür boyu
/// puanı olan kullanıcı bir odadadır. Kullanıcı bilinmiyorsa null.
bool? hasLeagueHistory(UserModel? user) =>
    user == null ? null : user.lifetimePoints > 0;

/// Lig odasındaki bir sıranın dönem sonu durumu.
enum LeagueZone {
  /// Terfi eder (terfi bölgesinde ve puanı var).
  promotion,

  /// Terfi bölgesinde ama puanı terfi için yetmiyor (bugünkü kural: 0
  /// puan; bkz. [LeagueRules.promotionMinPoints]): sunucu terfi ettirmez.
  promotionNeedsPoints,

  /// Bir alt lige düşer.
  demotion,

  /// Kalır.
  none,
}

const int kLeagueTierCount = 5;

/// Lig dönemi uzunluğu (sunucu: leagues.end_date, process_weekly_leagues).
const Duration kLeaguePeriod = Duration(days: 14);

/// Sunucu end_date döndürmediğinde kullanılan TAHMİN: get_league_ranking'in
/// lig-yok satırıyla aynı kural, yani içinde bulunulan haftanın Pazartesi'si
/// (Türkiye saati) + 13 gün, 23:59:59 (Türkiye saati). Gerçek odanın dönem
/// sonu bundan bir hafta önce olabilir; sunucu değeri her zaman önceliklidir.
DateTime assumedLeaguePeriodEnd(DateTime now) {
  const istanbulOffset = Duration(hours: 3);
  final istanbul = now.toUtc().add(istanbulOffset);
  final monday = DateTime.utc(
    istanbul.year,
    istanbul.month,
    istanbul.day - (istanbul.weekday - DateTime.monday),
  );
  return DateTime.utc(
    monday.year,
    monday.month,
    monday.day + kLeaguePeriod.inDays - 1,
    23,
    59,
    59,
  ).subtract(istanbulOffset);
}

/// Aylık sıralama çalışma ayıyla döner (get_public_monthly_leaderboard,
/// proposed/15): ayın 1'i, profil saat diliminde 04:00. Raporlar > Aylık ile
/// aynı kural ([studyDayOf], [studyDayStart]); cihazın saat diliminden
/// bağımsız olarak bir sonraki sıfırlanma anını döndürür.
DateTime nextMonthlyLeaderboardReset(DateTime now, {String? timeZone}) {
  final day = studyDayOf(now, timeZone: timeZone);
  return studyDayStart(
    DateTime(day.year, day.month + 1, 1),
    timeZone: timeZone,
  );
}

/// Competition months always change at 00:00 Europe/Istanbul, independently
/// of the profile's 04:00 study day and the device's display time zone.
DateTime nextCalendarMonthReset(DateTime now) {
  final istanbul = now.toUtc().add(const Duration(hours: 3));
  return DateTime.utc(
    istanbul.year,
    istanbul.month + 1,
    1,
  ).subtract(const Duration(hours: 3));
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
