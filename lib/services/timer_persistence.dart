import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/async_lock.dart';
import '../models/marathon_progress.dart';

/// Eski çağıranlarla uyumluluk için korunur. Derleme bayrakları uygulamanın
/// gerçek 25/50 dakikalık sayacını artık kısaltamaz.
const bool kQuickTimer = false;

/// Sayacın saniye cinsinden uzunluğu. Varsayılan HER derlemede (debug dahil)
/// gerçek süre. [quick] yalnızca açıkça verilen birim/widget simülasyonudur;
/// uygulama başlatma yapılandırmasından etkinleştirilemez.
int timerDurationSeconds(int minutes, {bool quick = false}) {
  if (quick) return minutes == 25 ? 5 : 10;
  return minutes * 60;
}

/// Süren ya da duraklatılmış bir odaklanma seansının cihazda saklanan hali.
///
/// Uygulama arka planda öldürülse, Android geri hareketiyle kapansa ya da
/// kullanıcı çıkış yapsa bile seans bu kayıttan geri yüklenir. Sayaç
/// çalışırken [endsAt] doludur; duraklatılmışken [pausedRemainingSeconds].
@immutable
class ActiveTimerSession {
  const ActiveTimerSession({
    required this.clientUuid,
    required this.categoryId,
    required this.categoryName,
    this.categoryColorHex,
    required this.durationMinutes,
    required this.totalSeconds,
    required this.startedAt,
    this.endsAt,
    this.pausedRemainingSeconds,
    this.pauseUsedCount = 0,
    this.foregroundSeconds = 0,
    this.recordAccelerated = false,
    this.marathon,
  });

  /// Sunucu, başlangıcı bundan eski seansları reddeder (too_old).
  static const Duration maxSessionAge = Duration(hours: 24);

  final String clientUuid;

  /// Seans boyunca kilitli kategori (yer tutucu kimlik de olabilir; kuyruk
  /// göndermeden önce isimle eşler).
  final String categoryId;
  final String categoryName;

  /// Seans başladığındaki kategori rengi ('#RRGGBB'). Kategori seans
  /// sürerken (ya da uygulama kapalıyken) arşivlenirse sayaç seansı yine bu
  /// ad ve renkle gösterir. Eski kayıtlarda yoktur.
  final String? categoryColorHex;

  /// Sunucuya bildirilen süre (25/50).
  final int durationMinutes;

  /// Sayacın gerçek uzunluğu (hızlı test sayacında kısaltılmıştır).
  final int totalSeconds;
  final DateTime startedAt;
  final DateTime? endsAt;
  final int? pausedRemainingSeconds;
  final int pauseUsedCount;

  /// Uygulamanın ön planda geçirdiği saniye (sunucuda p_is_verified).
  final int foregroundSeconds;

  /// Eski kayıtlı QA seansının işareti. Uyumluluk için okunur ve korunur;
  /// bu işareti taşıyan kayıt hiçbir ortamda normal seans olarak gönderilmez.
  final bool recordAccelerated;

  /// Plan ve mola da aynı sahip anahtarında saklanır. Mola aşamasında bu
  /// kaydın UUID'si son tamamlanan odaktır; mola için yeni UUID üretilmez.
  final MarathonProgress? marathon;

  /// Odak kaydı molanın/onay penceresinin diskteki taşıyıcısıdır; eski
  /// odak bitiş anının bulunması bu aşamaları çalışan seans yapmaz.
  bool get isRunning => endsAt != null && !(marathon?.isResting ?? false);
  bool get wasPaused => pauseUsedCount > 0;

  /// Kısaltılmış simülasyon veya eski kayıtlı QA seansı. Süre alanı sonradan
  /// gerçek süreye çevrilmiş olsa bile eski QA işareti gönderimi engeller.
  bool get isQuickTest =>
      recordAccelerated || totalSeconds < durationMinutes * 60;

  /// Yeni seans: [now] anında başlar, [totalSeconds] sonra biter.
  factory ActiveTimerSession.start({
    required String clientUuid,
    required String categoryId,
    required String categoryName,
    String? categoryColorHex,
    required int durationMinutes,
    required int totalSeconds,
    required DateTime now,
    bool recordAccelerated = false,
    MarathonProgress? marathon,
  }) {
    return ActiveTimerSession(
      clientUuid: clientUuid,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryColorHex: categoryColorHex,
      durationMinutes: durationMinutes,
      totalSeconds: totalSeconds,
      startedAt: now,
      endsAt: now.add(Duration(seconds: totalSeconds)),
      recordAccelerated: recordAccelerated,
      marathon: marathon,
    );
  }

  /// [now] anında kalan saniye (yukarı yuvarlanır, en az 0).
  int remainingSecondsAt(DateTime now) {
    final end = endsAt;
    if (end == null) {
      return (pausedRemainingSeconds ?? totalSeconds).clamp(0, totalSeconds);
    }
    final ms = end.difference(now).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  /// Sayaç çalışıyor ve süre dolmuş mu?
  bool isFinishedAt(DateTime now) => isRunning && remainingSecondsAt(now) == 0;

  /// Duraklatılmış seans artık sunucunun kabul edeceği sürede bitirilemez mi?
  /// (Devam edilse bile bitiş, başlangıçtan [maxSessionAge] sonraya kalır.)
  bool isAbandonedAt(DateTime now) {
    if (isRunning) return false;
    final projectedEnd = now.add(Duration(seconds: remainingSecondsAt(now)));
    return projectedEnd.difference(startedAt) > maxSessionAge;
  }

  ActiveTimerSession pauseAt(DateTime now) {
    if (!isRunning) return this;
    return _copy(
      endsAt: null,
      pausedRemainingSeconds: remainingSecondsAt(now),
      pauseUsedCount: pauseUsedCount + 1,
    );
  }

  ActiveTimerSession resumeAt(DateTime now) {
    if (isRunning) return this;
    return _copy(
      endsAt: now.add(Duration(seconds: remainingSecondsAt(now))),
      pausedRemainingSeconds: null,
    );
  }

  ActiveTimerSession withForegroundSeconds(int seconds) => _copy(
    endsAt: endsAt,
    pausedRemainingSeconds: pausedRemainingSeconds,
    foregroundSeconds: seconds,
  );

  ActiveTimerSession withMarathon(MarathonProgress progress) => _copy(
    endsAt: endsAt,
    pausedRemainingSeconds: pausedRemainingSeconds,
    marathon: progress,
  );

  // endsAt ve pausedRemainingSeconds her zaman açıkça verilir (null anlamlı).
  ActiveTimerSession _copy({
    required DateTime? endsAt,
    required int? pausedRemainingSeconds,
    int? pauseUsedCount,
    int? foregroundSeconds,
    MarathonProgress? marathon,
  }) {
    return ActiveTimerSession(
      clientUuid: clientUuid,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryColorHex: categoryColorHex,
      durationMinutes: durationMinutes,
      totalSeconds: totalSeconds,
      startedAt: startedAt,
      endsAt: endsAt,
      pausedRemainingSeconds: pausedRemainingSeconds,
      pauseUsedCount: pauseUsedCount ?? this.pauseUsedCount,
      foregroundSeconds: foregroundSeconds ?? this.foregroundSeconds,
      recordAccelerated: recordAccelerated,
      marathon: marathon ?? this.marathon,
    );
  }

  Map<String, dynamic> toJson() => {
    'client_uuid': clientUuid,
    'category_id': categoryId,
    'category_name': categoryName,
    if (categoryColorHex != null) 'category_color': categoryColorHex,
    'duration_minutes': durationMinutes,
    'total_seconds': totalSeconds,
    'started_at': startedAt.toUtc().toIso8601String(),
    'ends_at': endsAt?.toUtc().toIso8601String(),
    'paused_remaining_seconds': pausedRemainingSeconds,
    'pause_used_count': pauseUsedCount,
    'foreground_seconds': foregroundSeconds,
    if (recordAccelerated) 'record_accelerated': true,
    if (marathon != null) 'marathon': marathon!.toJson(),
  };

  /// Bozuk ya da eksik kayıtta null döner.
  static ActiveTimerSession? fromJson(Object? json) {
    if (json is! Map) return null;
    final uuid = json['client_uuid'];
    final categoryId = json['category_id'];
    final minutes = json['duration_minutes'];
    final total = json['total_seconds'];
    final startedAt = DateTime.tryParse(json['started_at']?.toString() ?? '');
    if (uuid is! String ||
        uuid.isEmpty ||
        categoryId is! String ||
        minutes is! int ||
        minutes <= 0) {
      return null;
    }
    if (total is! int || total <= 0 || startedAt == null) return null;
    final endsRaw = json['ends_at'];
    final endsAt = endsRaw == null
        ? null
        : DateTime.tryParse(endsRaw.toString());
    final paused = json['paused_remaining_seconds'];
    if (endsAt == null && paused is! int) return null;
    return ActiveTimerSession(
      clientUuid: uuid,
      categoryId: categoryId,
      categoryName: json['category_name']?.toString() ?? '',
      categoryColorHex: json['category_color'] is String
          ? json['category_color'] as String
          : null,
      durationMinutes: minutes,
      totalSeconds: total,
      startedAt: startedAt.toLocal(),
      endsAt: endsAt?.toLocal(),
      pausedRemainingSeconds: endsAt == null ? paused as int : null,
      pauseUsedCount: json['pause_used_count'] is int
          ? json['pause_used_count'] as int
          : 0,
      foregroundSeconds: json['foreground_seconds'] is int
          ? json['foreground_seconds'] as int
          : 0,
      recordAccelerated: json['record_accelerated'] == true,
      marathon: MarathonProgress.fromJson(json['marathon']),
    );
  }
}

/// [ActiveTimerSession] kaydını kullanıcıya bağlı anahtarda saklar.
/// Yazma ve silmeler sırayla uygulanır (geç kalan bir silme yeni seansı
/// ezmesin diye).
class TimerPersistence {
  TimerPersistence._();

  static final TimerPersistence instance = TimerPersistence._();

  static String keyFor(String ownerKey) => 'active_session_uid_$ownerKey';

  final AsyncLock _lock = AsyncLock();

  /// [ownerKey] altındaki kaydı okur. Bulunamazsa [legacyOwnerKey] altındaki
  /// kayıt [ownerKey]'e taşınarak döndürülür (kimlik sonradan öğrenildiyse).
  Future<ActiveTimerSession?> load(String ownerKey, {String? legacyOwnerKey}) {
    return _lock.synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        var session = _decode(prefs.getString(keyFor(ownerKey)));
        if (session == null &&
            legacyOwnerKey != null &&
            legacyOwnerKey.isNotEmpty &&
            legacyOwnerKey != ownerKey) {
          final legacyKey = keyFor(legacyOwnerKey);
          session = _decode(prefs.getString(legacyKey));
          if (session != null) {
            await prefs.setString(
              keyFor(ownerKey),
              jsonEncode(session.toJson()),
            );
            await prefs.remove(legacyKey);
          }
        }
        return session;
      } catch (e) {
        debugPrint('[TIMER] Kayıtlı seans okunamadı: $e');
        return null;
      }
    });
  }

  // Hesabı silinmiş sahipler. Hesap silinince Shell kapanırken sayaç ekranı
  // dispose'da süren seansı yeniden yazıyordu; bu süreç boyunca bu
  // sahiplere yazma yapılmaz (yeni hesabın kimliği farklıdır).
  final Set<String> _retiredOwners = {};

  /// Hesabı silinen kullanıcının süren seans kaydını siler ve bu süreçte
  /// o sahibe yeniden yazılmasını engeller.
  Future<void> retireOwner(String ownerKey) {
    _retiredOwners.add(ownerKey);
    return clear(ownerKey);
  }

  Future<void> save(String ownerKey, ActiveTimerSession session) {
    return saveChecked(ownerKey, session).then((_) {});
  }

  /// Maraton geçişi diske güvenle yazılmadan bir sonraki odak başlamaz.
  /// Normal sayaç için [save] eski, hata fırlatmayan API'yi korur.
  Future<bool> saveChecked(
    String ownerKey,
    ActiveTimerSession session, {
    bool Function()? canCommit,
  }) {
    if (_retiredOwners.contains(ownerKey)) return Future.value(false);
    return _lock.synchronized(() async {
      if (_retiredOwners.contains(ownerKey)) return false;
      try {
        final prefs = await SharedPreferences.getInstance();
        return await _writeIfAllowed(
          prefs,
          ownerKey,
          jsonEncode(session.toJson()),
          canCommit,
        );
      } catch (e) {
        debugPrint('[TIMER] Seans kaydedilemedi: $e');
        return false;
      }
    });
  }

  /// Eski bir ekranın geciken gönderim yanıtı daha yeni molayı/odağı
  /// ezmesin. Kontrol, dönüştürme ve yazma aynı kilit altında gerçekleşir.
  /// null: kayıt ilerlemiş, silinmiş ya da yazılamamıştır.
  Future<ActiveTimerSession?> compareAndUpdateMarathon(
    String ownerKey, {
    required String clientUuid,
    required int completedSessions,
    required Set<MarathonPhase> phases,
    required ActiveTimerSession Function(ActiveTimerSession current) update,
    bool Function()? canCommit,
  }) {
    return _lock.synchronized(() async {
      if (_retiredOwners.contains(ownerKey)) return null;
      try {
        final prefs = await SharedPreferences.getInstance();
        final stored = _decode(prefs.getString(keyFor(ownerKey)));
        final plan = stored?.marathon;
        if (stored == null ||
            stored.clientUuid != clientUuid ||
            plan == null ||
            plan.completedSessions != completedSessions ||
            !phases.contains(plan.phase)) {
          return null;
        }
        if (canCommit != null && !canCommit()) return null;
        final next = update(stored);
        return await _writeIfAllowed(
              prefs,
              ownerKey,
              jsonEncode(next.toJson()),
              canCommit,
            )
            ? next
            : null;
      } catch (error) {
        debugPrint('[MARATHON] Koşullu sayaç kaydı yazılamadı: $error');
        return null;
      }
    });
  }

  /// Yeni odağın disk yazısı beklerken çıkış/arka plan başlayabilir. Önceki
  /// JSON aynı kilitte geri alınır; [load] ve yeni ekran bu aradaki, henüz
  /// başlatılmamış odağı görmez. Hesap silinmişse eski kayıt da geri gelmez.
  Future<bool> _writeIfAllowed(
    SharedPreferences prefs,
    String ownerKey,
    String nextJson,
    bool Function()? canCommit,
  ) async {
    if (_retiredOwners.contains(ownerKey) ||
        (canCommit != null && !canCommit())) {
      return false;
    }
    final key = keyFor(ownerKey);
    final previousJson = prefs.getString(key);
    Future<void> restorePrevious() async {
      if (previousJson == null || _retiredOwners.contains(ownerKey)) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, previousJson);
      }
    }

    final bool saved;
    try {
      saved = await prefs.setString(key, nextJson);
    } catch (error) {
      // Legacy SharedPreferences önce kendi önbelleğini değiştirir;
      // native yazının hata vermesi bu değişikliği kendiliğinden geri almaz.
      try {
        await restorePrevious();
      } catch (rollbackError) {
        debugPrint(
          '[TIMER] Başarısız yazının geri alınması tamamlanamadı: $rollbackError',
        );
      }
      rethrow;
    }
    if (!saved ||
        _retiredOwners.contains(ownerKey) ||
        (canCommit != null && !canCommit())) {
      await restorePrevious();
      return false;
    }
    return saved;
  }

  /// Durdurma, o planda henüz ekrana uygulanmamış yeni odak UUID'sini de
  /// kapsar; sonradan başlatılmış farklı planı veya tek seansı silmez.
  Future<void> clearMarathon(String ownerKey, {required String marathonUuid}) {
    return _lock.synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = keyFor(ownerKey);
        final current = _decode(prefs.getString(key));
        if (current?.marathon?.marathonUuid == marathonUuid) {
          await prefs.remove(key);
        }
      } catch (error) {
        debugPrint('[MARATHON] Plan kaydı silinemedi: $error');
      }
    });
  }

  /// Kaydı siler. [onlyClientUuid] verilirse yalnızca kayıt o seansa aitse
  /// silinir (bu arada başlatılmış yeni seans korunur).
  Future<void> clear(String ownerKey, {String? onlyClientUuid}) {
    return _lock.synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final key = keyFor(ownerKey);
        if (onlyClientUuid != null) {
          final stored = _decode(prefs.getString(key));
          if (stored != null && stored.clientUuid != onlyClientUuid) return;
        }
        await prefs.remove(key);
      } catch (e) {
        debugPrint('[TIMER] Seans kaydı silinemedi: $e');
      }
    });
  }

  static ActiveTimerSession? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return ActiveTimerSession.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}
