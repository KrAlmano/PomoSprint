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

  /// Genel kullanıcı kimliği. Yalnızca arkadaşlar sekmesi (get_my_friends)
  /// döndürür; lig ve aylık sıralamada yoktur.
  final String? userId;

  /// Kullanıcının gizlediği biri: sıra ve puan korunur (lig bölgeleri
  /// bozulmasın), ad ve avatar gösterilmez.
  final bool hidden;

  const RankingEntry({
    this.name,
    this.avatarId,
    required this.points,
    this.minutes,
    this.isMe = false,
    this.userId,
    this.hidden = false,
  });

  factory RankingEntry.fromRow(Map<String, dynamic> row, {required String pointsKey}) {
    final id = row['id']?.toString();
    return RankingEntry(
      name: row['name']?.toString(),
      avatarId: row['avatar_id']?.toString(),
      points: _asInt(row[pointsKey]),
      minutes: row['total_minutes'] == null ? null : _asInt(row['total_minutes']),
      isMe: row['is_me'] == true,
      userId: (id == null || id.isEmpty) ? null : id,
    );
  }

  /// Gizlenmiş hali: ad, kimlik ve avatar çıkarılır; sıra ve puan aynı kalır.
  RankingEntry asHidden() => RankingEntry(points: points, minutes: minutes, isMe: isMe, hidden: true);

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
/// is_me=true, weekly_points 0, promotion_zone_end 1, demotion_zone_start
/// 999, end_date 14 günlük dönemin sonu ve member_count: canlıda 1 (tek
/// kişilik gerçek odayla aynı satır), proposed/20 sonrası 0. Bu durum
/// [awaitingPlacement] ile ayırt edilir; ekran "#1 · 0 puan" yerine
/// yerleştirme bilgisini gösterir. Odada tek başına olan kullanıcı
/// [isAloneInRoom] (t4-F6).
class LeagueSnapshot {
  final int tier;
  final DateTime? endDate;
  final int promotionZoneEnd;
  final int demotionZoneStart;
  final int memberCount;

  /// Kullanıcının bu dönemki lig puanı (kendi satırının weekly_points'i).
  final int myPoints;

  /// Dönem sonu ödül/terfi kuralı (proposed/20; okunamazsa bugünkü kural).
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
    this.myPoints = 0,
    this.rules = LeagueRules.standard,
    this.inRoom,
  });

  /// [rows] boş olmamalı. Tier/bitiş/bölge değerleri her satırda aynıdır;
  /// varsa kullanıcının kendi satırı esas alınır. Sunucu end_date
  /// döndürmezse 14 günlük dönem varsayımıyla tahmin edilir
  /// ([assumedLeaguePeriodEnd]).
  ///
  /// Odada olup olmadığı ([inRoom]) sırasıyla: satırda has_league varsa o;
  /// member_count 0 → odada değil (proposed/20); birden çok üye ya da puan
  /// → odada; [rules] sunucudan geldiyse (20 uygulanmış, ligsiz satır 0
  /// döner) tek kişilik satır gerçek odadır. Aksi halde (canlı sunucu: ligsiz
  /// satır ile tek kişilik puansız oda aynı) [hasLeagueHistory]: canlıda
  /// puan kazandıran her seans kullanıcıyı bir odaya yerleştirir ve üyelik
  /// silinmez; ömür boyu puanı olan kullanıcı bir odadadır (terfi/düşme
  /// sonrası yeni odasında tek kalan dahil). null ise eski kural.
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
      endDate: DateTime.tryParse(me['end_date']?.toString() ?? '') ?? assumedLeaguePeriodEnd(now ?? DateTime.now()),
      promotionZoneEnd: _asInt(me['promotion_zone_end'], fallback: 0),
      demotionZoneStart: _asInt(me['demotion_zone_start'], fallback: 999),
      memberCount: memberCount,
      myPoints: myPoints,
      rules: rules,
      inRoom: inRoom,
    );
  }

  bool get isTopTier => tier >= kLeagueTierCount;
  bool get isBottomTier => tier <= 1;

  /// Kullanıcı henüz bir lig odasına yerleşmedi: kıyaslanacak kimse yok,
  /// terfi/düşme bölgesi gösterilmez. Sunucu ilk puanlı seansta kullanıcıyı
  /// bir odaya yerleştirir. [inRoom] bilinmiyorsa eski kural: tek kişi ve
  /// puansız.
  bool get awaitingPlacement => inRoom == null ? memberCount <= 1 && myPoints <= 0 : !inRoom!;

  /// Kullanıcı bir odada ama odada şimdilik yalnız (ör. terfi edip yeni
  /// odasında tek kalan; t4-F6).
  bool get isAloneInRoom => !awaitingPlacement && memberCount <= 1;

  int get demotionCount =>
      demotionZoneStart > memberCount ? 0 : memberCount - demotionZoneStart + 1;

  // Sunucu terfi için en az [LeagueRules.promotionMinPoints] puan ister
  // (bugünkü kural: 0 puanla terfi yok; process_weekly_leagues).
  bool isPromotionRank(int rank, int points) =>
      !isTopTier && points >= rules.promotionMinPoints && rank <= promotionZoneEnd;

  bool isDemotionRank(int rank) => !isBottomTier && rank >= demotionZoneStart;

  /// [rank]. sıradaki [points] puanlı üye dönem böyle biterse lig ödülü
  /// (avatar) alır mı? İlk 3, en az [LeagueRules.awardMinPoints] puan ve
  /// odada en az [LeagueRules.awardMinMembers] üye (bugünkü kural: puanı >
  /// 0 olan ilk 3).
  bool earnsAward(int rank, int points) =>
      rank >= 1 && rank <= 3 && points >= rules.awardMinPoints && memberCount >= rules.awardMinMembers;

  /// [rank]. sıradaki [points] puanlı üyenin dönem sonu durumu. Podyum
  /// (1-3) dahil her sıra için aynı kural; küçük odalarda terfi bölgesi
  /// tamamen podyumun içinde kalır.
  LeagueZone zoneOf(int rank, int points) {
    if (awaitingPlacement) return LeagueZone.none;
    if (!isTopTier && rank <= promotionZoneEnd) {
      return points >= rules.promotionMinPoints ? LeagueZone.promotion : LeagueZone.promotionNeedsPoints;
    }
    if (isDemotionRank(rank)) return LeagueZone.demotion;
    return LeagueZone.none;
  }
}

/// Kullanıcı daha önce bir lig odasına yerleşti mi ([LeagueSnapshot.fromRows]
/// `hasLeagueHistory`)? Canlıda puan kazandıran her seans kullanıcıyı bir
/// odaya yerleştirir (ensure_user_in_league) ve üyelik silinmez: ömür boyu
/// puanı olan kullanıcı bir odadadır. Kullanıcı bilinmiyorsa null.
bool? hasLeagueHistory(UserModel? user) => user == null ? null : user.lifetimePoints > 0;

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
  final monday = DateTime.utc(istanbul.year, istanbul.month, istanbul.day - (istanbul.weekday - DateTime.monday));
  return DateTime.utc(monday.year, monday.month, monday.day + kLeaguePeriod.inDays - 1, 23, 59, 59)
      .subtract(istanbulOffset);
}

/// Aylık sıralama çalışma ayıyla döner (get_public_monthly_leaderboard,
/// proposed/15): ayın 1'i, profil saat diliminde 04:00. Raporlar > Aylık ile
/// aynı kural ([studyDayOf], [studyDayStart]); cihazın saat diliminden
/// bağımsız olarak bir sonraki sıfırlanma anını döndürür.
DateTime nextMonthlyLeaderboardReset(DateTime now, {String? timeZone}) {
  final day = studyDayOf(now, timeZone: timeZone);
  return studyDayStart(DateTime(day.year, day.month + 1, 1), timeZone: timeZone);
}

int _asInt(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
