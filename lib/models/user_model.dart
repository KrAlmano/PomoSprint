class UserModel {
  final int? id;
  final String name;
  final String email;
  final String avatarId;
  final int totalMinutes;
  final int lifetimePoints;
  final int coins;
  final int streakDays;
  final String? lastStudyDate;
  final bool isPremium;
  final List<String> unlockedAvatars;
  final String? userSegment;
  final int? dailyGoalMinutes;
  final int? birthYear;
  final DateTime? onboardingCompletedAt;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    this.avatarId = 'avatar_16_basic',
    this.totalMinutes = 0,
    this.lifetimePoints = 0,
    this.coins = 0,
    this.streakDays = 0,
    this.lastStudyDate,
    this.isPremium = false,
    this.unlockedAvatars = const [],
    this.userSegment,
    this.dailyGoalMinutes,
    this.birthYear,
    this.onboardingCompletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'email': email,
      'avatar_id': avatarId,
      'total_minutes': totalMinutes,
      'lifetime_points': lifetimePoints,
      'coins': coins,
      'is_premium': isPremium,
      'unlocked_avatars': unlockedAvatars,
      'user_segment': userSegment,
      'daily_goal_minutes': dailyGoalMinutes,
      'birth_year': birthYear,
      'onboarding_completed_at': onboardingCompletedAt?.toIso8601String(),
    };
  }

  static int? _parseInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: _parseInt(map['id']),
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      avatarId: map['equipped_avatar_id']?.toString() ?? map['avatar_id']?.toString() ?? 'avatar_16_basic',
      totalMinutes: _parseInt(map['total_minutes']) ?? 0,
      lifetimePoints: _parseInt(map['lifetime_points']) ?? 0,
      coins: _parseInt(map['coins']) ?? _parseInt(map['lifetime_points']) ?? 0,
      streakDays: _parseInt(map['current_streak']) ?? 0,
      lastStudyDate: map['last_study_date']?.toString(),
      isPremium: map['is_premium'] as bool? ?? false,
      unlockedAvatars: (map['unlocked_avatars'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      userSegment: map['user_segment']?.toString(),
      dailyGoalMinutes: _parseInt(map['daily_goal_minutes']),
      birthYear: _parseInt(map['birth_year']),
      onboardingCompletedAt: map['onboarding_completed_at'] != null ? DateTime.parse(map['onboarding_completed_at'].toString()).toLocal() : null,
    );
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? avatarId,
    int? totalMinutes,
    int? lifetimePoints,
    int? coins,
    int? streakDays,
    String? lastStudyDate,
    bool? isPremium,
    List<String>? unlockedAvatars,
    String? userSegment,
    int? dailyGoalMinutes,
    int? birthYear,
    DateTime? onboardingCompletedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarId: avatarId ?? this.avatarId,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      lifetimePoints: lifetimePoints ?? this.lifetimePoints,
      coins: coins ?? this.coins,
      streakDays: streakDays ?? this.streakDays,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      isPremium: isPremium ?? this.isPremium,
      unlockedAvatars: unlockedAvatars ?? this.unlockedAvatars,
      userSegment: userSegment ?? this.userSegment,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      birthYear: birthYear ?? this.birthYear,
      onboardingCompletedAt: onboardingCompletedAt ?? this.onboardingCompletedAt,
    );
  }
}
