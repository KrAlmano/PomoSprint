import '../utils/study_day.dart';

enum StudySessionKind { normal, marathon, exam, unknown }

class StudySession {
  final String id;
  final String userId;
  final String categoryName;
  final String? categoryId;
  final String? colorHex;

  /// Kategorinin sunucudaki ikonu (arşivlenmiş kategoriler dahil).
  final String? iconName;

  /// İstemcinin seansa verdiği kimlik (idempotency anahtarı). Kuyrukta hâlâ
  /// bekleyen bir kayıtla aynı seans olup olmadığını anlamak için.
  final String? clientUuid;
  final int minutes; // Maps to 'duration_minutes' in DB
  final int pomodoros; // Computed locally from minutes

  /// Seansın gerçek başlangıcı (yerel saat). Çok eski kayıtlarda boş olabilir.
  final DateTime? startedAt;

  /// Sunucunun completed_at değeri (yerel saat). Canlı sunucu bunu
  /// started_at + süre olarak yazar; eski kayıtlarda senkronun anı
  /// olabileceği için gösterimde [createdAt] / [studyDay] kullanılır.
  final DateTime completedAt;
  final StudySessionKind kind;
  final String? marathonUuid;
  final int? marathonTargetSessions;
  final int? marathonSessionIndex;
  final DateTime? marathonCompletedAt;

  StudySession({
    required this.id,
    required this.userId,
    required this.categoryName,
    this.categoryId,
    this.colorHex,
    this.iconName,
    this.clientUuid,
    required this.minutes,
    required this.pomodoros,
    this.startedAt,
    required this.completedAt,
    this.kind = StudySessionKind.normal,
    this.marathonUuid,
    this.marathonTargetSessions,
    this.marathonSessionIndex,
    this.marathonCompletedAt,
  });

  /// Gösterim zamanı: seansın gerçek bitişi (started_at + süre). started_at
  /// yoksa completed_at'e düşülür.
  DateTime get createdAt =>
      startedAt?.add(Duration(minutes: minutes)) ?? completedAt;

  /// Seansın sunucu kuralına göre ait olduğu çalışma günü (04:00 sınırı,
  /// başlangıç anına göre).
  DateTime get studyDay => studyDayOf(startedAt ?? completedAt);

  factory StudySession.fromJson(Map<String, dynamic> json) {
    final int duration = (json['duration_minutes'] as num?)?.toInt() ?? 0;
    final categories = json['categories'];
    final joinedName = categories is Map ? categories['name'] as String? : null;
    final startedRaw = json['started_at'] as String?;
    final marathonUuid = json['marathon_uuid'] as String?;
    return StudySession(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      // category sütunu NOT NULL; boş ad yalnızca bozuk kayıtta (ekranda 'Diğer').
      categoryName: joinedName ?? json['category'] as String? ?? '',
      categoryId: json['category_id'] as String?,
      colorHex: categories is Map ? categories['color_hex'] as String? : null,
      iconName: categories is Map ? categories['icon_name'] as String? : null,
      clientUuid: json['client_uuid'] as String?,
      minutes: duration,
      pomodoros: duration > 0 ? (duration ~/ 25) : 0,
      startedAt: startedRaw == null
          ? null
          : DateTime.parse(startedRaw).toLocal(),
      completedAt: DateTime.parse(json['completed_at'] as String).toLocal(),
      kind: switch (json['session_kind']) {
        'normal' => StudySessionKind.normal,
        'marathon' => StudySessionKind.marathon,
        _ =>
          marathonUuid == null
              ? StudySessionKind.unknown
              : StudySessionKind.marathon,
      },
      marathonUuid: marathonUuid,
      marathonTargetSessions: (json['marathon_target_sessions'] as num?)
          ?.toInt(),
      marathonSessionIndex: (json['marathon_session_index'] as num?)?.toInt(),
      marathonCompletedAt: DateTime.tryParse(
        json['marathon_completed_at']?.toString() ?? '',
      ),
    );
  }
}
