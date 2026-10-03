import 'package:flutter/material.dart';

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
    return AvatarCharacter(
      id: map['id'] as String,
      nameTr: map['name_tr'] as String,
      nameEn: map['name_en'] as String,
      imagePath: map['asset_key'] as String,
      requiredCoins: map['cost_coins'] as int? ?? 0,
      isPremiumOnly: map['is_premium_only'] as bool? ?? false,
      isDefault: map['is_default'] as bool? ?? false,
      isLeagueAward: map['is_league_award'] as bool? ?? false,
    );
  }

  String getName(bool isTurkish) => isTurkish ? nameTr : nameEn;

  bool isUnlocked(int userCoins, bool isPremium, List<String> unlockedAvatars) {
    if (unlockedAvatars.contains(id)) return true;
    // Lig ödülü avatarları jetonla/premium ile ASLA açılmaz — cost_coins=0
    // olduğu için aşağıdaki "userCoins >= requiredCoins" kontrolü herkes
    // için yanlışlıkla true dönerdi. Bu yüzden erken çıkış şart.
    if (isLeagueAward) return false;
    if (isPremiumOnly && !isPremium) return false;
    return userCoins >= requiredCoins;
  }

  String unlockLabel(bool isPremium) {
    if (isLeagueAward) return '';
    if (isPremiumOnly && !isPremium) return 'Premium';
    return '$requiredCoins';
  }

  // Caching mechanism to prevent breaking existing synchronous code
  static List<AvatarCharacter> _cachedAvatars = [];
  
  static void setCachedAvatars(List<AvatarCharacter> avatars) {
    _cachedAvatars = avatars;
  }

  static List<AvatarCharacter> allAvatars() {
    return _cachedAvatars;
  }

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
