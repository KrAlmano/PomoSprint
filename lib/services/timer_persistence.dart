import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/async_lock.dart';

/// Hızlı test sayacı: yalnızca `--dart-define=QUICK_TIMER=true` ile
/// derlenince açıktır (VS Code: "PomoSprint (hızlı test sayacı,
/// kaydedilmez)"). Sayaç 25 dk → 5 sn, 50 dk → 10 sn sürer, ekranda TEST
/// rozeti görünür ve bu seanslar sunucuya da kuyruğa da gönderilmez
/// (bkz. [ActiveTimerSession.isQuickTest]).
const bool kQuickTimer = bool.fromEnvironment('QUICK_TIMER');

/// Sayacın saniye cinsinden uzunluğu. Varsayılan HER derlemede (debug dahil)
/// gerçek süre; yalnızca hızlı test sayacında kısalır.
///
/// Eskiden debug derlemede kendiliğinden kısalıyordu: 5 sn'lik seans
/// sunucuya 25 dk diye gidiyor, `session_not_finished` ile reddediliyor ve
/// kullanıcı "cihazının saati ileri" uyarısı görüyordu.
int timerDurationSeconds(int minutes, {bool quick = kQuickTimer}) {
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

  bool get isRunning => endsAt != null;
  bool get wasPaused => pauseUsedCount > 0;

  /// Kısaltılmış sayaçla (hızlı test sayacı ya da eski debug derlemesi)
  /// başlatılmış test seansı. Sunucu böyle bir seansı zaten reddeder
  /// (`session_not_finished`); sunucuya ve kuyruğa gönderilmez. Seansın
  /// kendisine bakılır, derleme bayrağına değil: hızlı test derlemesinde
  /// geri yüklenen gerçek seans yine gönderilir, normal derlemede geri
  /// yüklenen test seansı gönderilmez.
  bool get isQuickTest => totalSeconds < durationMinutes * 60;

  /// Yeni seans: [now] anında başlar, [totalSeconds] sonra biter.
  factory ActiveTimerSession.start({
    required String clientUuid,
    required String categoryId,
    required String categoryName,
    String? categoryColorHex,
    required int durationMinutes,
    required int totalSeconds,
    required DateTime now,
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
    );
  }

  /// [now] anında kalan saniye (yukarı yuvarlanır, en az 0).
  int remainingSecondsAt(DateTime now) {
    final end = endsAt;
    if (end == null) return (pausedRemainingSeconds ?? totalSeconds).clamp(0, totalSeconds);
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

  // endsAt ve pausedRemainingSeconds her zaman açıkça verilir (null anlamlı).
  ActiveTimerSession _copy({
    required DateTime? endsAt,
    required int? pausedRemainingSeconds,
    int? pauseUsedCount,
    int? foregroundSeconds,
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
      };

  /// Bozuk ya da eksik kayıtta null döner.
  static ActiveTimerSession? fromJson(Object? json) {
    if (json is! Map) return null;
    final uuid = json['client_uuid'];
    final categoryId = json['category_id'];
    final minutes = json['duration_minutes'];
    final total = json['total_seconds'];
    final startedAt = DateTime.tryParse(json['started_at']?.toString() ?? '');
    if (uuid is! String || uuid.isEmpty || categoryId is! String || minutes is! int || minutes <= 0) return null;
    if (total is! int || total <= 0 || startedAt == null) return null;
    final endsRaw = json['ends_at'];
    final endsAt = endsRaw == null ? null : DateTime.tryParse(endsRaw.toString());
    final paused = json['paused_remaining_seconds'];
    if (endsAt == null && paused is! int) return null;
    return ActiveTimerSession(
      clientUuid: uuid,
      categoryId: categoryId,
      categoryName: json['category_name']?.toString() ?? '',
      categoryColorHex: json['category_color'] is String ? json['category_color'] as String : null,
      durationMinutes: minutes,
      totalSeconds: total,
      startedAt: startedAt.toLocal(),
      endsAt: endsAt?.toLocal(),
      pausedRemainingSeconds: endsAt == null ? paused as int : null,
      pauseUsedCount: json['pause_used_count'] is int ? json['pause_used_count'] as int : 0,
      foregroundSeconds: json['foreground_seconds'] is int ? json['foreground_seconds'] as int : 0,
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
        if (session == null && legacyOwnerKey != null && legacyOwnerKey.isNotEmpty && legacyOwnerKey != ownerKey) {
          final legacyKey = keyFor(legacyOwnerKey);
          session = _decode(prefs.getString(legacyKey));
          if (session != null) {
            await prefs.setString(keyFor(ownerKey), jsonEncode(session.toJson()));
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
    if (_retiredOwners.contains(ownerKey)) return Future.value();
    return _lock.synchronized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(keyFor(ownerKey), jsonEncode(session.toJson()));
      } catch (e) {
        debugPrint('[TIMER] Seans kaydedilemedi: $e');
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
