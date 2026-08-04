class StudySession {
  final String id;
  final String userId;
  final String categoryName; // Maps to 'category' in DB
  final int minutes;         // Maps to 'duration_minutes' in DB
  final int pomodoros;       // Computed locally from minutes
  final DateTime createdAt;  // Maps to 'completed_at' in DB

  StudySession({
    required this.id,
    required this.userId,
    required this.categoryName,
    required this.minutes,
    required this.pomodoros,
    required this.createdAt,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    final int duration = json['duration_minutes'] as int? ?? 0;
    return StudySession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      categoryName: json['category'] as String,
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
