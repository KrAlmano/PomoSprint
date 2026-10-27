import 'package:flutter/foundation.dart';

/// Her odak seansının kendi kaydı vardır. Bu plan sadece geçişi saklar;
/// molalar hiçbir zaman odak seansı olarak gönderilmez.
enum MarathonPhase { focus, completing, breakTime, awaitingPresence, finished }

/// Yalnızca seçim ekranındaki açıklama. Kazanılan bonus her zaman
/// sunucunun SessionSubmitSuccess.marathonBonusPoints sonucundan okunur.
int marathonBonusPreview({
  required int totalSessions,
  required int durationMinutes,
}) {
  final base = switch (totalSessions) {
    2 => 2,
    3 => 3,
    4 => 5,
    _ => 0,
  };
  return durationMinutes == 50
      ? base * 2
      : durationMinutes == 25
      ? base
      : 0;
}

@immutable
class MarathonProgress {
  const MarathonProgress({
    required this.totalSessions,
    required this.marathonUuid,
    this.completedSessions = 0,
    this.phase = MarathonPhase.focus,
    this.breakEndsAt,
    this.breakSeconds = 300,
    this.awardedBonusPoints = 0,
    this.bonusPending = false,
    this.stopRequested = false,
    this.presenceClientUuid,
  }) : assert(totalSessions >= 2 && totalSessions <= 4),
       assert(completedSessions >= 0 && completedSessions <= totalSessions),
       assert(breakSeconds > 0);

  final int totalSessions;

  /// Plan boyunca değişmez; seans UUID'sinden ayrıdır.
  final String marathonUuid;
  final int completedSessions;
  final MarathonPhase phase;
  final DateTime? breakEndsAt;
  final int breakSeconds;
  final int awardedBonusPoints;
  final bool bonusPending;
  final bool stopRequested;

  /// Sunucu devam onayını bu sonraki odak UUID'sine bağlar. ACK sonrası
  /// süreç kaybında aynı pencere yeni bir aday kimliği üretmez.
  final String? presenceClientUuid;

  /// Mola bitiminden sonra yalnızca bu sabit pencere içinde kullanıcı
  /// açıkça devam edebilir. Yeniden açılış bu süreyi baştan başlatmaz.
  static const int presenceWindowSeconds = 60;

  int get currentSession => (completedSessions + 1).clamp(1, totalSessions);
  int get sessionIndex => currentSession;
  bool get isOnBreak => phase == MarathonPhase.breakTime;
  bool get isAwaitingPresence => phase == MarathonPhase.awaitingPresence;
  bool get isResting => isOnBreak || isAwaitingPresence;
  bool get isFinished => phase == MarathonPhase.finished;
  DateTime? get presenceDeadline =>
      breakEndsAt?.add(const Duration(seconds: presenceWindowSeconds));

  int breakRemainingAt(DateTime now) {
    final end = breakEndsAt;
    if (!isOnBreak || end == null) return 0;
    final milliseconds = end.difference(now).inMilliseconds;
    return milliseconds <= 0
        ? 0
        : (milliseconds / 1000).ceil().clamp(0, breakSeconds);
  }

  int presenceRemainingAt(DateTime now) {
    final deadline = presenceDeadline;
    if (!isResting || deadline == null) return 0;
    final milliseconds = deadline.difference(now).inMilliseconds;
    return milliseconds <= 0
        ? 0
        : (milliseconds / 1000).ceil().clamp(0, presenceWindowSeconds);
  }

  bool isPresenceExpiredAt(DateTime now) =>
      isResting && presenceDeadline != null && !now.isBefore(presenceDeadline!);

  bool canConfirmPresenceAt(DateTime now) =>
      isAwaitingPresence &&
      !stopRequested &&
      breakEndsAt != null &&
      !now.isBefore(breakEndsAt!) &&
      !isPresenceExpiredAt(now);

  /// Mola çıpası korunur; gecikmiş tick, restore veya tekrar dokunma
  /// kullanıcıya yeni bir dakika kazandırmaz.
  MarathonProgress beginPresenceCheck() => MarathonProgress(
    totalSessions: totalSessions,
    marathonUuid: marathonUuid,
    completedSessions: completedSessions,
    phase: MarathonPhase.awaitingPresence,
    breakEndsAt: breakEndsAt,
    breakSeconds: breakSeconds,
    awardedBonusPoints: awardedBonusPoints,
    bonusPending: bonusPending,
    stopRequested: stopRequested,
    presenceClientUuid: presenceClientUuid,
  );

  MarathonProgress withPresenceCandidate(String uuid) => MarathonProgress(
    totalSessions: totalSessions,
    marathonUuid: marathonUuid,
    completedSessions: completedSessions,
    phase: phase,
    breakEndsAt: breakEndsAt,
    breakSeconds: breakSeconds,
    awardedBonusPoints: awardedBonusPoints,
    bonusPending: bonusPending,
    stopRequested: stopRequested,
    presenceClientUuid: uuid,
  );

  /// Gönderimden önce bu aşama diske yazılır. Süreç burada kapanırsa aynı
  /// client_uuid yeniden gönderilir; yeni seansa geçilmez.
  MarathonProgress beginCompletion() => MarathonProgress(
    totalSessions: totalSessions,
    marathonUuid: marathonUuid,
    completedSessions: completedSessions,
    phase: MarathonPhase.completing,
    breakSeconds: breakSeconds,
    awardedBonusPoints: awardedBonusPoints,
    bonusPending: bonusPending,
    stopRequested: stopRequested,
  );

  /// Yalnızca odak kaydı outbox'a/sunucuya güvenle yazıldıktan sonra çağrılır.
  MarathonProgress finishFocus(DateTime now) {
    final completed = (completedSessions + 1).clamp(0, totalSessions);
    return MarathonProgress(
      totalSessions: totalSessions,
      marathonUuid: marathonUuid,
      completedSessions: completed,
      phase: completed == totalSessions
          ? MarathonPhase.finished
          : MarathonPhase.breakTime,
      breakEndsAt: completed == totalSessions
          ? null
          : now.add(Duration(seconds: breakSeconds)),
      breakSeconds: breakSeconds,
      awardedBonusPoints: awardedBonusPoints,
      bonusPending: bonusPending,
      stopRequested: stopRequested,
    );
  }

  /// Yeni UUID ve başlangıç anını ekran üretir. Bu metot gelecekteki odak
  /// seanslarını kendiliğinden üretmez veya geriye doğru tarih oluşturmaz.
  MarathonProgress nextFocus() => MarathonProgress(
    totalSessions: totalSessions,
    marathonUuid: marathonUuid,
    completedSessions: completedSessions,
    breakSeconds: breakSeconds,
    awardedBonusPoints: awardedBonusPoints,
    bonusPending: bonusPending,
    stopRequested: stopRequested,
  );

  MarathonProgress withBonusResult({
    required int points,
    required bool pending,
  }) => MarathonProgress(
    totalSessions: totalSessions,
    marathonUuid: marathonUuid,
    completedSessions: completedSessions,
    phase: phase,
    breakEndsAt: breakEndsAt,
    breakSeconds: breakSeconds,
    awardedBonusPoints: points,
    bonusPending: pending,
    stopRequested: stopRequested,
    presenceClientUuid: presenceClientUuid,
  );

  MarathonProgress withStopRequested() => MarathonProgress(
    totalSessions: totalSessions,
    marathonUuid: marathonUuid,
    completedSessions: completedSessions,
    phase: phase,
    breakEndsAt: breakEndsAt,
    breakSeconds: breakSeconds,
    awardedBonusPoints: awardedBonusPoints,
    bonusPending: bonusPending,
    stopRequested: true,
    presenceClientUuid: presenceClientUuid,
  );

  Map<String, dynamic> toJson() => {
    'total_sessions': totalSessions,
    if (marathonUuid.isNotEmpty) 'marathon_uuid': marathonUuid,
    'completed_sessions': completedSessions,
    'phase': phase.name,
    'break_seconds': breakSeconds,
    'awarded_bonus_points': awardedBonusPoints,
    'bonus_pending': bonusPending,
    if (stopRequested) 'stop_requested': true,
    if (presenceClientUuid != null) 'presence_client_uuid': presenceClientUuid,
    if (breakEndsAt != null)
      'break_ends_at': breakEndsAt!.toUtc().toIso8601String(),
  };

  static MarathonProgress? fromJson(Object? value) {
    if (value is! Map) return null;
    final total = value['total_sessions'];
    final completed = value['completed_sessions'];
    final seconds = value['break_seconds'];
    final uuid = value['marathon_uuid'];
    final candidate = value['presence_client_uuid'];
    final phase = MarathonPhase.values
        .where((p) => p.name == value['phase'])
        .firstOrNull;
    if (total is! int ||
        total < 2 ||
        total > 4 ||
        completed is! int ||
        completed < 0 ||
        completed > total ||
        seconds is! int ||
        seconds <= 0 ||
        seconds > 300 ||
        phase == null ||
        uuid is! String ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
          caseSensitive: false,
        ).hasMatch(uuid)) {
      return null;
    }
    if (candidate != null &&
        (candidate is! String ||
            !RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
              caseSensitive: false,
            ).hasMatch(candidate))) {
      return null;
    }
    final end = DateTime.tryParse(value['break_ends_at']?.toString() ?? '');
    if ((phase == MarathonPhase.breakTime ||
            phase == MarathonPhase.awaitingPresence) &&
        (end == null || completed <= 0 || completed >= total)) {
      return null;
    }
    if (phase == MarathonPhase.finished && completed != total) return null;
    if ((phase == MarathonPhase.focus || phase == MarathonPhase.completing) &&
        completed >= total) {
      return null;
    }
    return MarathonProgress(
      totalSessions: total,
      marathonUuid: uuid,
      completedSessions: completed,
      phase: phase,
      breakEndsAt: end?.toLocal(),
      breakSeconds: seconds,
      awardedBonusPoints: value['awarded_bonus_points'] is int
          ? (value['awarded_bonus_points'] as int).clamp(0, 100)
          : 0,
      bonusPending: value['bonus_pending'] == true,
      stopRequested: value['stop_requested'] == true,
      presenceClientUuid: candidate as String?,
    );
  }
}
