class UserModel {
  final int? id;
  final String name;
  final String email;
  final String password;
  final String avatarId;
  final int totalMinutes;
  final int points;
  final int streakDays;
  final String? lastStudyDate;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    this.avatarId = 'tomato_basic',
    this.totalMinutes = 0,
    this.points = 0,
    this.streakDays = 0,
    this.lastStudyDate,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'email': email,
      'avatar_id': avatarId,
      'total_minutes': totalMinutes,
      'points': points,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      email: map['email'] as String,
      password: '', // Güvenlik: Şifre önbelleğe kaydedilmez
      avatarId: map['avatar_id'] as String? ?? 'tomato_basic',
      totalMinutes: map['total_minutes'] as int? ?? 0,
      points: map['points'] as int? ?? 0,
      streakDays: map['current_streak'] as int? ?? 0,
      lastStudyDate: map['last_study_date'] as String?,
    );
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? password,
    String? avatarId,
    int? totalMinutes,
    int? points,
    int? streakDays,
    String? lastStudyDate,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      avatarId: avatarId ?? this.avatarId,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      points: points ?? this.points,
      streakDays: streakDays ?? this.streakDays,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
    );
  }
}
