import 'package:flutter/material.dart';

/// Tüm istemci yedeklerinin kullandığı TEK varsayılan avatar; sunucunun da
/// varsayılanı (handle_new_user / sanitize_profile_insert). Sunucu
/// kataloğunda is_default=true olduğu için her yeni profile
/// give_default_avatars trigger'ı ile açılır (sahiplik kaydı vardır).
const String kDefaultAvatarId = 'avatar_16_basic';

/// Lig ödülü avatarlarının kimlik öneki (league_{kademe}_{weekly|monthly}).
const String _leagueAwardIdPrefix = 'league_';

class AvatarCharacter {
  final String id;
  final String nameTr;
  final String nameEn;
  final String imagePath;
  final int requiredCoins;
  final bool isPremiumOnly;
  final bool isDefault;
  final bool isLeagueAward;

  const AvatarCharacter({
    required this.id,
    required this.nameTr,
    required this.nameEn,
    required this.imagePath,
    this.requiredCoins = 0,
    this.isPremiumOnly = false,
    this.isDefault = false,
    this.isLeagueAward = false,
  });

  factory AvatarCharacter.fromMap(Map<String, dynamic> map) {
    final id = map['id'] as String;
    // Sunucu satırında 'is_league_award' kolonu yoksa lig ödülü kimlik
    // önekinden tanınır; aksi halde 0 kum tanesi + Premium değil olduğu için
    // satın alınabilir/ücretsiz görünürdü.
    final leagueAward = map['is_league_award'];
    return AvatarCharacter(
      id: id,
      nameTr: map['name_tr'] as String? ?? id,
      nameEn: map['name_en'] as String? ?? id,
      imagePath: map['asset_key'] as String? ?? 'assets/avatars/$id.png',
      requiredCoins: (map['cost_coins'] as num?)?.toInt() ?? 0,
      isPremiumOnly: map['is_premium_only'] as bool? ?? false,
      isDefault: map['is_default'] as bool? ?? false,
      isLeagueAward: leagueAward is bool ? leagueAward : id.startsWith(_leagueAwardIdPrefix),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name_tr': nameTr,
        'name_en': nameEn,
        'asset_key': imagePath,
        'cost_coins': requiredCoins,
        'is_premium_only': isPremiumOnly,
        'is_default': isDefault,
        'is_league_award': isLeagueAward,
      };

  String getName(bool isTurkish) => isTurkish ? nameTr : nameEn;

  /// Herkese açık (varsayılan) avatar. Sunucuyla aynı kural: yalnızca
  /// is_default avatarlar kayıtta seçilebilir ve her yeni profile
  /// give_default_avatars ile açılır. Diğer her avatar (0 kum tanesi olsa
  /// bile) bir avatar_unlocks kaydı gerektirir; aksi halde set_equipped_avatar
  /// reddeder.
  bool get isFree => isDefault;

  /// Kullanıcı bu avatarın sahibi mi? Sahiplik = avatar_unlocks kaydı ya da
  /// ücretsiz/varsayılan avatar. Bakiyenin yetmesi sahiplik SAYILMAZ; o
  /// durumda satın alma akışı gösterilmelidir (bkz. [canAfford]).
  bool isOwned(List<String> unlockedAvatars) => isFree || unlockedAvatars.contains(id);

  /// Kum tanesiyle satın alınabilir ve bakiye yetiyor mu? Lig ödülü ve
  /// Premium avatarlar kum tanesiyle alınamaz.
  bool canAfford(int userCoins) =>
      !isLeagueAward && !isPremiumOnly && userCoins >= requiredCoins;

  /// Premium kullanıcı bu avatarı ücretsiz açabilir mi (purchase_avatar).
  bool canUnlockWithPremium(bool isPremium) => isPremiumOnly && isPremium && !isLeagueAward;

  String unlockLabel(bool isPremium) {
    if (isLeagueAward) return '';
    if (isPremiumOnly && !isPremium) return 'Premium';
    return '$requiredCoins';
  }

  // Sunucudan gelen son katalog. Boşken (ilk açılış, çevrimdışı) gömülü
  // [fallbackCatalog] kullanılır; böylece katalog yardımcıları asla boş
  // listeyle çalışmaz.
  static List<AvatarCharacter> _cachedAvatars = const [];

  /// Sunucu kataloğunu önbelleğe alır. Boş liste yok sayılır (yedek korunur).
  static void setCachedAvatars(List<AvatarCharacter> avatars) {
    if (avatars.isEmpty) return;
    _cachedAvatars = List.unmodifiable(avatars);
  }

  @visibleForTesting
  static void clearCachedAvatars() => _cachedAvatars = const [];

  /// Önbellekte sunucudan gelmiş bir katalog var mı?
  static bool get hasServerCatalog => _cachedAvatars.isNotEmpty;

  /// Asla boş dönmez: sunucu kataloğu yoksa gömülü yedek katalog döner.
  static List<AvatarCharacter> allAvatars() =>
      _cachedAvatars.isNotEmpty ? _cachedAvatars : fallbackCatalog;

  /// Kimliğe göre avatar; asla fırlatmaz. Sırasıyla sunucu kataloğu, gömülü
  /// katalog ve son olarak [kDefaultAvatarId] denenir.
  static AvatarCharacter byId(String? id) =>
      _find(_cachedAvatars, id) ?? _find(fallbackCatalog, id) ?? _find(fallbackCatalog, kDefaultAvatarId)!;

  /// [id] katalogda bilinen ve varsayılan (ücretsiz) bir avatar mı? Kayıtta
  /// ve profil oluştururken gönderilecek avatar kimliğini doğrulamak için
  /// kullanılır; sunucu başka bir değeri zaten avatar_16_basic'e çeker.
  static bool isFreeAvatarId(String? id) {
    final avatar = _find(_cachedAvatars, id) ?? _find(fallbackCatalog, id);
    return avatar != null && avatar.isFree;
  }

  static AvatarCharacter? _find(List<AvatarCharacter> list, String? id) {
    if (id == null) return null;
    for (final a in list) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Uygulamaya gömülü katalog; canlı avatars tablosuyla aynı:
  /// - varsayılan (ücretsiz): avatar_16_basic, avatar_2_glasses,
  ///   avatar_3_gentleman, avatar_5_flower, avatar_6_cool, avatar_7_scholar,
  ///   avatar_8_striped
  /// - 200 kum tanesi: avatar_1_gamer, avatar_4_bowtie, avatar_9_viking,
  ///   avatar_10_dentist
  /// - Premium (Premium kullanıcıya bedava): avatar_11..avatar_15
  /// - lig ödülleri (satın alınamaz): league_{kademe}_{weekly|monthly}
  /// tomato_basic canlıda pasif olduğu için yok. Sunucu kataloğu
  /// alınamadığında kullanılır.
  static const List<AvatarCharacter> fallbackCatalog = [
    AvatarCharacter(id: 'avatar_1_gamer', nameTr: 'Oyuncu Kum Saati', nameEn: 'Gamer Hourglass', imagePath: 'assets/avatars/avatar_1_gamer.png', requiredCoins: 200),
    AvatarCharacter(id: 'avatar_2_glasses', nameTr: 'Gözlüklü Kum Saati', nameEn: 'Glasses Hourglass', imagePath: 'assets/avatars/avatar_2_glasses.png', isDefault: true),
    AvatarCharacter(id: 'avatar_3_gentleman', nameTr: 'Centilmen Kum Saati', nameEn: 'Gentleman Hourglass', imagePath: 'assets/avatars/avatar_3_gentleman.png', isDefault: true),
    AvatarCharacter(id: 'avatar_4_bowtie', nameTr: 'Hakim Kum Saati', nameEn: 'Judge Hourglass', imagePath: 'assets/avatars/avatar_4_bowtie.png', requiredCoins: 200),
    AvatarCharacter(id: 'avatar_5_flower', nameTr: 'Çiçekli Kum Saati', nameEn: 'Flower Hourglass', imagePath: 'assets/avatars/avatar_5_flower.png', isDefault: true),
    AvatarCharacter(id: 'avatar_6_cool', nameTr: 'Süslü Kum Saati', nameEn: 'Glam Hourglass', imagePath: 'assets/avatars/avatar_6_cool.png', isDefault: true),
    AvatarCharacter(id: 'avatar_7_scholar', nameTr: 'Mezun Kum Saati', nameEn: 'Graduate Hourglass', imagePath: 'assets/avatars/avatar_7_scholar.png', isDefault: true),
    AvatarCharacter(id: 'avatar_8_striped', nameTr: 'Sevimli Kum Saati', nameEn: 'Cute Hourglass', imagePath: 'assets/avatars/avatar_8_striped.png', isDefault: true),
    AvatarCharacter(id: 'avatar_9_viking', nameTr: 'Viking Kum Saati', nameEn: 'Viking Hourglass', imagePath: 'assets/avatars/avatar_9_viking.png', requiredCoins: 200),
    AvatarCharacter(id: 'avatar_10_dentist', nameTr: 'Dişçi Kum Saati', nameEn: 'Dentist Hourglass', imagePath: 'assets/avatars/avatar_10_dentist.png', requiredCoins: 200),
    AvatarCharacter(id: 'avatar_11_doctor', nameTr: 'Doktor Kum Saati', nameEn: 'Doctor Hourglass', imagePath: 'assets/avatars/avatar_11_doctor.png', isPremiumOnly: true),
    AvatarCharacter(id: 'avatar_12_builder', nameTr: 'Mimar Kum Saati', nameEn: 'Architect Hourglass', imagePath: 'assets/avatars/avatar_12_builder.png', isPremiumOnly: true),
    AvatarCharacter(id: 'avatar_13_pilot', nameTr: 'Pilot Kum Saati', nameEn: 'Pilot Hourglass', imagePath: 'assets/avatars/avatar_13_pilot.png', isPremiumOnly: true),
    AvatarCharacter(id: 'avatar_14_teacher', nameTr: 'Öğretmen Kum Saati', nameEn: 'Teacher Hourglass', imagePath: 'assets/avatars/avatar_14_teacher.png', isPremiumOnly: true),
    AvatarCharacter(id: 'avatar_15_athlete', nameTr: 'Sporcu Kum Saati', nameEn: 'Athlete Hourglass', imagePath: 'assets/avatars/avatar_15_athlete.png', isPremiumOnly: true),
    AvatarCharacter(id: 'avatar_16_basic', nameTr: 'Klasik Kum Saati', nameEn: 'Classic Hourglass', imagePath: 'assets/avatars/avatar_16_basic.png', isDefault: true),
    AvatarCharacter(id: 'league_bronze_weekly', nameTr: 'Bronz Lig Haftalık Ödülü', nameEn: 'Bronze League Weekly Award', imagePath: 'assets/avatars/league_bronze_weekly.png', isLeagueAward: true),
    AvatarCharacter(id: 'league_bronze_monthly', nameTr: 'Bronz Lig Aylık Ödülü', nameEn: 'Bronze League Monthly Award', imagePath: 'assets/avatars/league_bronze_monthly.png', isLeagueAward: true),
    AvatarCharacter(id: 'league_silver_weekly', nameTr: 'Gümüş Lig Haftalık Ödülü', nameEn: 'Silver League Weekly Award', imagePath: 'assets/avatars/league_silver_weekly.png', isLeagueAward: true),
    AvatarCharacter(id: 'league_silver_monthly', nameTr: 'Gümüş Lig Aylık Ödülü', nameEn: 'Silver League Monthly Award', imagePath: 'assets/avatars/league_silver_monthly.png', isLeagueAward: true),
    AvatarCharacter(id: 'league_gold_weekly', nameTr: 'Altın Lig Haftalık Ödülü', nameEn: 'Gold League Weekly Award', imagePath: 'assets/avatars/league_gold_weekly.png', isLeagueAward: true),
    AvatarCharacter(id: 'league_gold_monthly', nameTr: 'Altın Lig Aylık Ödülü', nameEn: 'Gold League Monthly Award', imagePath: 'assets/avatars/league_gold_monthly.png', isLeagueAward: true),
    AvatarCharacter(id: 'league_sapphire_weekly', nameTr: 'Safir Lig Haftalık Ödülü', nameEn: 'Sapphire League Weekly Award', imagePath: 'assets/avatars/league_sapphire_weekly.png', isLeagueAward: true),
    AvatarCharacter(id: 'league_sapphire_monthly', nameTr: 'Safir Lig Aylık Ödülü', nameEn: 'Sapphire League Monthly Award', imagePath: 'assets/avatars/league_sapphire_monthly.png', isLeagueAward: true),
    AvatarCharacter(id: 'league_diamond_weekly', nameTr: 'Elmas Lig Haftalık Ödülü', nameEn: 'Diamond League Weekly Award', imagePath: 'assets/avatars/league_diamond_weekly.png', isLeagueAward: true),
    AvatarCharacter(id: 'league_diamond_monthly', nameTr: 'Elmas Lig Aylık Ödülü', nameEn: 'Diamond League Monthly Award', imagePath: 'assets/avatars/league_diamond_monthly.png', isLeagueAward: true),
  ];

  // Fallback visual properties mapped by id
  Color get backgroundColor {
    return _visuals[id]?['color'] as Color? ?? const Color(0xFFF3F4F6);
  }

  String get emoji {
    return _visuals[id]?['emoji'] as String? ?? '⌛';
  }

  static const Map<String, Map<String, dynamic>> _visuals = {
    'avatar_1_gamer': {'color': Color(0xFFE0F2FE), 'emoji': '🎧'},
    'avatar_2_glasses': {'color': Color(0xFFDCFCE7), 'emoji': '👓'},
    'avatar_3_gentleman': {'color': Color(0xFFFFEDD5), 'emoji': '🎩'},
    'avatar_4_bowtie': {'color': Color(0xFFFEF9C3), 'emoji': '⚖️'},
    'avatar_5_flower': {'color': Color(0xFFFCE7F3), 'emoji': '🌸'},
    'avatar_6_cool': {'color': Color(0xFFFEF08A), 'emoji': '💅'},
    'avatar_7_scholar': {'color': Color(0xFFDBEAFE), 'emoji': '🎓'},
    'avatar_8_striped': {'color': Color(0xFFE0E7FF), 'emoji': '👔'},
    'avatar_9_viking': {'color': Color(0xFFFFE4E6), 'emoji': '🛡️'},
    'avatar_10_dentist': {'color': Color(0xFFE0F2FE), 'emoji': '🦷'},
    'avatar_11_doctor': {'color': Color(0xFFCCFBF1), 'emoji': '🩺'},
    'avatar_12_builder': {'color': Color(0xFFFEF3C7), 'emoji': '🪖'},
    'avatar_13_pilot': {'color': Color(0xFFE0F2FE), 'emoji': '✈️'},
    'avatar_14_teacher': {'color': Color(0xFFFDE68A), 'emoji': '📚'},
    'avatar_15_athlete': {'color': Color(0xFFDCFCE7), 'emoji': '⚽'},
    'avatar_16_basic': {'color': Color(0xFFF3F4F6), 'emoji': '⌛'},
    'league_bronze_monthly': {'color': Color(0xFFF0DDC8), 'emoji': '🏆'},
    'league_bronze_weekly': {'color': Color(0xFFF0DDC8), 'emoji': '🥉'},
    'league_silver_monthly': {'color': Color(0xFFE4E7EB), 'emoji': '🏆'},
    'league_silver_weekly': {'color': Color(0xFFE4E7EB), 'emoji': '🥈'},
    'league_gold_monthly': {'color': Color(0xFFFDEBB0), 'emoji': '🏆'},
    'league_gold_weekly': {'color': Color(0xFFFDEBB0), 'emoji': '🥇'},
    'league_sapphire_monthly': {'color': Color(0xFFD3E4FD), 'emoji': '🏆'},
    'league_sapphire_weekly': {'color': Color(0xFFD3E4FD), 'emoji': '💎'},
    'league_diamond_monthly': {'color': Color(0xFFE0F7FA), 'emoji': '🏆'},
    'league_diamond_weekly': {'color': Color(0xFFE0F7FA), 'emoji': '👑'},
  };
}
