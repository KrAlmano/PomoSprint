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

  const RankingEntry({
    this.name,
    this.avatarId,
    required this.points,
    this.minutes,
    this.isMe = false,
  });

  factory RankingEntry.fromRow(Map<String, dynamic> row, {required String pointsKey}) {
    return RankingEntry(
      name: row['name']?.toString(),
      avatarId: row['avatar_id']?.toString(),
      points: _asInt(row[pointsKey]),
      minutes: row['total_minutes'] == null ? null : _asInt(row['total_minutes']),
      isMe: row['is_me'] == true,
    );
  }

  /// Puana, sonra dakikaya göre azalan sıralama.
  static int compare(RankingEntry a, RankingEntry b) {
    final byPoints = b.points.compareTo(a.points);
    if (byPoints != 0) return byPoints;
    return (b.minutes ?? 0).compareTo(a.minutes ?? 0);
  }
}

/// Kullanıcının içinde bulunduğu lig odasının sunucudan gelen özeti
/// (get_my_league_ranking). Kural sayıları istemcide sabitlenmez.
///
/// Kullanıcı henüz bir lig odasında değilse sunucu tek satır döndürür:
/// is_me=true, weekly_points 0, member_count 1, promotion_zone_end 1,
/// demotion_zone_start 999 ve end_date 14 günlük dönemin sonu. Bu durum
/// [awaitingPlacement] ile ayırt edilir; ekran "#1 · 0 puan" yerine
/// yerleştirme bilgisini gösterir.
class LeagueSnapshot {
  final int tier;
  final DateTime? endDate;
  final int promotionZoneEnd;
  final int demotionZoneStart;
  final int memberCount;

  /// Kullanıcının bu dönemki lig puanı (kendi satırının weekly_points'i).
  final int myPoints;

  const LeagueSnapshot({
    required this.tier,
    required this.endDate,
    required this.promotionZoneEnd,
    required this.demotionZoneStart,
    required this.memberCount,
    this.myPoints = 0,
  });

  /// [rows] boş olmamalı. Tier/bitiş/bölge değerleri her satırda aynıdır;
  /// varsa kullanıcının kendi satırı esas alınır. Sunucu end_date
  /// döndürmezse 14 günlük dönem varsayımıyla tahmin edilir
  /// ([assumedLeaguePeriodEnd]).
  factory LeagueSnapshot.fromRows(List<Map<String, dynamic>> rows, {DateTime? now}) {
    final myRow = rows.where((r) => r['is_me'] == true).firstOrNull;
    final me = myRow ?? rows.first;
    return LeagueSnapshot(
      tier: _asInt(me['tier'], fallback: 1).clamp(1, kLeagueTierCount),
      endDate: DateTime.tryParse(me['end_date']?.toString() ?? '') ?? assumedLeaguePeriodEnd(now ?? DateTime.now()),
      promotionZoneEnd: _asInt(me['promotion_zone_end'], fallback: 0),
      demotionZoneStart: _asInt(me['demotion_zone_start'], fallback: 999),
      memberCount: _asInt(me['member_count'], fallback: rows.length),
      myPoints: myRow == null ? 0 : _asInt(myRow['weekly_points']),
    );
  }

  bool get isTopTier => tier >= kLeagueTierCount;
  bool get isBottomTier => tier <= 1;

  /// Kullanıcı henüz bir lig odasına yerleşmedi (ya da odada tek başına ve
  /// puansız): kıyaslanacak kimse yok, terfi/düşme bölgesi gösterilmez.
  /// Sunucu ilk puanlı seansta kullanıcıyı bir odaya yerleştirir.
  bool get awaitingPlacement => memberCount <= 1 && myPoints <= 0;

  int get demotionCount =>
      demotionZoneStart > memberCount ? 0 : memberCount - demotionZoneStart + 1;

  // Sunucu 0 puanla terfi ettirmez (process_weekly_leagues).
  bool isPromotionRank(int rank, int points) => !isTopTier && points > 0 && rank <= promotionZoneEnd;

  bool isDemotionRank(int rank) => !isBottomTier && rank >= demotionZoneStart;
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
  final monday = DateTime.utc(istanbul.year, istanbul.month, istanbul.day - (istanbul.weekday - DateTime.monday));
  return DateTime.utc(monday.year, monday.month, monday.day + kLeaguePeriod.inDays - 1, 23, 59, 59)
      .subtract(istanbulOffset);
}

/// Aylık sıralama ayın 1'inde Türkiye saatiyle (UTC+3, yaz saati yok)
/// sıfırlanır (get_public_monthly_leaderboard). Cihazın saat diliminden
/// bağımsız olarak bir sonraki sıfırlanma anını döndürür.
DateTime nextMonthlyLeaderboardReset(DateTime now) {
  const istanbulOffset = Duration(hours: 3);
  final istanbul = now.toUtc().add(istanbulOffset);
  return DateTime.utc(istanbul.year, istanbul.month + 1, 1).subtract(istanbulOffset);
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
