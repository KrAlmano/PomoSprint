import '../utils/study_day.dart';
import 'avatar_model.dart' show kDefaultAvatarId;

class UserModel {
  /// Supabase Auth kullanıcı kimliği (UUID). Eski sürümlerin önbelleğinden
  /// okunan kayıtlarda boş olabilir.
  final String? id;
  final String name;
  final String email;
  final String avatarId;
  final int totalMinutes;
  final int lifetimePoints;
  final int coins;

  /// Sunucudaki ham seri (profiles.current_streak). Ekranda gösterilecek
  /// değer için [streakDays] kullanılmalı.
  final int currentStreak;
  final int longestStreak;

  /// Son çalışma günü ('YYYY-MM-DD', sunucunun 04:00 gün sınırına göre).
  final String? lastStudyDate;
  final bool isPremium;

  /// Sahip olunan avatarlar (avatar_unlocks). Değiştirilemez liste;
  /// güncellemek için [copyWith] kullanılır.
  final List<String> unlockedAvatars;
  final String? userSegment;
  final int? dailyGoalMinutes;
  final int? birthYear;
  final DateTime? onboardingCompletedAt;

  /// Profilin saat dilimi (profiles.timezone, IANA adı). Sunucu çalışma
  /// gününü (04:00 sınırı), seriyi ve günlük seans tavanını bu dilimde
  /// hesaplar; istemci de aynısını kullanır (bkz. study_day.dart).
  final String timezone;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    this.avatarId = kDefaultAvatarId,
    this.totalMinutes = 0,
    this.lifetimePoints = 0,
    this.coins = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastStudyDate,
    this.isPremium = false,
    Iterable<String> unlockedAvatars = const <String>[],
    this.userSegment,
    this.dailyGoalMinutes,
    this.birthYear,
    this.onboardingCompletedAt,
    this.timezone = kDefaultStudyTimeZone,
  }) : unlockedAvatars = List.unmodifiable(unlockedAvatars);

  /// Ekranda gösterilecek (normalize edilmiş) seri: son çalışma günü bugün
  /// ya da dün (profil diliminde) değilse 0. Kural tek yerde: [effectiveStreak].
  int get streakDays => streakOn(DateTime.now());

  int streakOn(DateTime now) => effectiveStreak(
        storedStreak: currentStreak,
        lastStudyDate: lastStudyDate,
        now: now,
        timeZone: timezone,
      );

  /// [fromMap] ile birebir simetrik. 'saved_user' önbelleği bu biçimde
  /// yazılır ve okunur.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar_id': avatarId,
      'total_minutes': totalMinutes,
      'lifetime_points': lifetimePoints,
      'coins': coins,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_study_date': lastStudyDate,
      'is_premium': isPremium,
      'unlocked_avatars': unlockedAvatars,
      'user_segment': userSegment,
      'daily_goal_minutes': dailyGoalMinutes,
      'birth_year': birthYear,
      'onboarding_completed_at': onboardingCompletedAt?.toUtc().toIso8601String(),
      'timezone': timezone,
    };
  }

  static int? _parseInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  static String? _nonEmpty(dynamic val) {
    final s = val?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  /// Profil satırından (ownProfileColumns + 'email' + 'unlocked_avatars')
  /// ya da [toMap] çıktısından kurar.
  factory UserModel.fromMap(Map<String, dynamic> map) {
    final onboardingRaw = _nonEmpty(map['onboarding_completed_at']);
    return UserModel(
      id: _nonEmpty(map['id']),
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      avatarId: _nonEmpty(map['avatar_id']) ?? _nonEmpty(map['equipped_avatar_id']) ?? kDefaultAvatarId,
      totalMinutes: _parseInt(map['total_minutes']) ?? 0,
      lifetimePoints: _parseInt(map['lifetime_points']) ?? 0,
      coins: _parseInt(map['coins']) ?? 0,
      currentStreak: _parseInt(map['current_streak']) ?? 0,
      longestStreak: _parseInt(map['longest_streak']) ?? 0,
      lastStudyDate: _nonEmpty(map['last_study_date']),
      isPremium: map['is_premium'] == true,
      unlockedAvatars: (map['unlocked_avatars'] as List<dynamic>?)?.map((e) => e.toString()) ?? const <String>[],
      userSegment: _nonEmpty(map['user_segment']),
      dailyGoalMinutes: _parseInt(map['daily_goal_minutes']),
      birthYear: _parseInt(map['birth_year']),
      onboardingCompletedAt: onboardingRaw == null ? null : DateTime.tryParse(onboardingRaw)?.toLocal(),
      timezone: _nonEmpty(map['timezone']) ?? kDefaultStudyTimeZone,
    );
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarId,
    int? totalMinutes,
    int? lifetimePoints,
    int? coins,
    int? currentStreak,
    int? longestStreak,
    String? lastStudyDate,
    bool? isPremium,
    List<String>? unlockedAvatars,
    String? userSegment,
    int? dailyGoalMinutes,
    int? birthYear,
    DateTime? onboardingCompletedAt,
    String? timezone,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarId: avatarId ?? this.avatarId,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      lifetimePoints: lifetimePoints ?? this.lifetimePoints,
      coins: coins ?? this.coins,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      isPremium: isPremium ?? this.isPremium,
      unlockedAvatars: unlockedAvatars ?? this.unlockedAvatars,
      userSegment: userSegment ?? this.userSegment,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      birthYear: birthYear ?? this.birthYear,
      onboardingCompletedAt: onboardingCompletedAt ?? this.onboardingCompletedAt,
      timezone: timezone ?? this.timezone,
    );
  }
}
