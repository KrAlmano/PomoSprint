class StudySession {
  final String id;
  final String userId;
  final String categoryName;
  final String? categoryId;
  final String? colorHex;
  final int minutes;         // Maps to 'duration_minutes' in DB
  final int pomodoros;       // Computed locally from minutes
  final DateTime createdAt;  // Maps to 'completed_at' in DB

  StudySession({
    required this.id,
    required this.userId,
    required this.categoryName,
    this.categoryId,
    this.colorHex,
    required this.minutes,
    required this.pomodoros,
    required this.createdAt,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    final int duration = json['duration_minutes'] as int? ?? 0;
    return StudySession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      categoryName: (json['categories'] != null && json['categories']['name'] != null) ? json['categories']['name'] : (json['category'] ?? 'Diğer'),
      categoryId: json['category_id'] as String?,
      colorHex: (json['categories'] != null) ? json['categories']['color_hex'] : null,
      minutes: duration,
      pomodoros: duration > 0 ? (duration ~/ 25) : 0,
      createdAt: DateTime.parse(json['completed_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category': categoryName,
      'duration_minutes': minutes,
      'completed_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
