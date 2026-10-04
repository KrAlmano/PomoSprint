import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, PostgrestException;
import 'package:uuid/uuid.dart';

import '../utils/async_lock.dart';
import '../utils/category_names.dart';
import 'server_clock.dart';
import 'service_errors.dart' show ServiceErrorCode, ServiceException, isNetworkError;

// Tamamlanan seanslar için kalıcı giden kutusu (outbox).
//
// Akış: seans önce diske yazılır (write-ahead), ardından kuyruktaki tüm
// seanslar started_at sırasıyla, zaman aşımlı RPC ile gönderilir. Başarılı
// olanlar silinir; geçici hatada seans kuyrukta kalır; kalıcı reddedilenler
// ayrı bir listeye taşınır ve kullanıcıya bir kez bildirilir. Seans hiçbir
// durumda sessizce silinmez.

final RegExp _uuidPattern =
    RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);

/// Sunucuda gerçekten var olabilecek (UUID biçiminde) bir kategori kimliği mi?
/// Yerel yer tutucu kategorilerin kimlikleri ('1', '2', ...) bu kontrolü geçmez.
bool isUuidCategoryId(String? id) => id != null && _uuidPattern.hasMatch(id);

int? _asInt(Object? value) => value is num ? value.toInt() : null;

/// Kuyrukta bekleyen (sunucuya henüz ulaşmamış) tamamlanmış seans.
@immutable
class PendingSession {
  const PendingSession({
    required this.clientUuid,
    required this.categoryId,
    required this.categoryName,
    required this.minutes,
    required this.wasPaused,
    required this.foregroundSeconds,
    required this.startedAt,
    required this.queuedAt,
    this.clockOffsetMs,
    this.categoryRemaps = 0,
    this.lastError,
  });

  final String clientUuid;

  /// Yer tutucu ya da boş olabilir; gönderimden önce isimle eşlenir.
  final String? categoryId;
  final String categoryName;
  final int minutes;
  final bool wasPaused;

  /// Uygulamanın ön planda geçirdiği saniye (RPC'de p_is_verified).
  final int foregroundSeconds;

  /// Cihaz saatiyle kaydedilmiş başlangıç (UTC).
  final DateTime startedAt;
  final DateTime queuedAt;

  /// Kuyruğa yazılırken bilinen sunucu-cihaz saat farkı (ms).
  final int? clockOffsetMs;

  /// Kategori yüzünden kaç kez yeniden eşlendiği.
  final int categoryRemaps;

  /// Son başarısız denemenin neden kodu (bkz. [SessionReason]).
  final String? lastError;

  PendingSession copyWith({
    String? categoryId,
    bool clearCategoryId = false,
    int? categoryRemaps,
    String? lastError,
  }) {
    return PendingSession(
      clientUuid: clientUuid,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      categoryName: categoryName,
      minutes: minutes,
      wasPaused: wasPaused,
      foregroundSeconds: foregroundSeconds,
      startedAt: startedAt,
      queuedAt: queuedAt,
      clockOffsetMs: clockOffsetMs,
      categoryRemaps: categoryRemaps ?? this.categoryRemaps,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() => {
        'client_uuid': clientUuid,
        'category_id': categoryId,
        'category_name': categoryName,
        'minutes': minutes,
        'was_paused': wasPaused,
        'is_verified': foregroundSeconds,
        'started_at': startedAt.toUtc().toIso8601String(),
        'queued_at': queuedAt.toUtc().toIso8601String(),
        if (clockOffsetMs != null) 'clock_offset_ms': clockOffsetMs,
        'category_remaps': categoryRemaps,
        if (lastError != null) 'last_error': lastError,
      };

  /// Eski sürümlerin kayıtlarını da okur. Zorunlu alanlar eksik ya da
  /// bozuksa null döner.
  static PendingSession? fromJson(Map<String, dynamic> json) {
    final uuid = json['client_uuid'];
    final started = json['started_at'];
    final minutes = json['minutes'];
    if (uuid is! String || uuid.isEmpty || started is! String || minutes is! num) return null;
    // Eski sürümler started_at'i saat dilimsiz yerel saatle yazıyordu;
    // DateTime.parse bunu yerel saat olarak okur, toUtc doğru çevirir.
    final startedAt = DateTime.tryParse(started);
    if (startedAt == null) return null;
    final queued = json['queued_at'];
    final categoryId = json['category_id'];
    return PendingSession(
      clientUuid: uuid,
      categoryId: categoryId is String && categoryId.isNotEmpty ? categoryId : null,
      categoryName: json['category_name']?.toString() ?? '',
      minutes: minutes.toInt(),
      wasPaused: json['was_paused'] == true,
      foregroundSeconds: _asInt(json['is_verified']) ?? 0,
      startedAt: startedAt.toUtc(),
      queuedAt: (queued is String ? DateTime.tryParse(queued) : null)?.toUtc() ?? startedAt.toUtc(),
      clockOffsetMs: _asInt(json['clock_offset_ms']),
      categoryRemaps: _asInt(json['category_remaps']) ?? 0,
      lastError: json['last_error']?.toString(),
    );
  }
}

/// Sunucunun kalıcı olarak reddettiği seansın kaydı.
@immutable
class RejectedSession {
  const RejectedSession({
    required this.clientUuid,
    required this.startedAt,
    required this.minutes,
    required this.categoryName,
    required this.reasonCode,
    required this.rejectedAt,
  });

  final String clientUuid;
  final DateTime startedAt;
  final int minutes;
  final String categoryName;
  final String reasonCode;
  final DateTime rejectedAt;

  Map<String, dynamic> toJson() => {
        'client_uuid': clientUuid,
        'started_at': startedAt.toUtc().toIso8601String(),
        'minutes': minutes,
        'category_name': categoryName,
        'reason': reasonCode,
        'rejected_at': rejectedAt.toUtc().toIso8601String(),
      };

  static RejectedSession? fromJson(Map<String, dynamic> json) {
    final started = DateTime.tryParse(json['started_at']?.toString() ?? '');
    final rejectedAt = DateTime.tryParse(json['rejected_at']?.toString() ?? '');
    if (started == null || rejectedAt == null) return null;
    return RejectedSession(
      clientUuid: json['client_uuid']?.toString() ?? '',
      startedAt: started.toUtc(),
      minutes: _asInt(json['minutes']) ?? 0,
      categoryName: json['category_name']?.toString() ?? '',
      reasonCode: json['reason']?.toString() ?? SessionReason.serverRejected,
      rejectedAt: rejectedAt.toUtc(),
    );
  }
}

/// Seans gönderiminin neden kodları. UI bunları yerelleştirir.
abstract final class SessionReason {
  // Kalıcı (seans reddedilenlere taşınır)
  static const String overlap = 'overlap';
  static const String tooOld = 'too_old';
  static const String invalidDuration = 'invalid_duration';

  /// Sunucu: 'session_not_finished' (saat farkı bunu açıklamıyorsa). Kod
  /// değeri reddedilenler listesinde kalıcı tutulduğu için değiştirilmez.
  /// Saat farkı ölçülemediyse aynı kodla GEÇİCİ döner (bkz.
  /// [classifySessionError]); kullanıcıya saat suçlaması yapılmaz.
  static const String notElapsed = 'not_elapsed';
  static const String futureStart = 'future_start';
  static const String invalidData = 'invalid_data';
  static const String corrupt = 'corrupt';
  static const String categoryInvalid = 'category_invalid';
  static const String serverRejected = 'server_rejected';
  // Geçici (seans kuyrukta kalır)
  static const String offline = 'offline';
  static const String network = 'network';
  static const String timeout = 'timeout';
  static const String auth = 'auth';

  /// Ölçülen saat farkı [ServerClock.significantSkew]'i aşıyor: "cihazının
  /// saati farklı" metni yalnızca bu kodla gösterilir.
  static const String clockSkew = 'clock_skew';
  static const String serverError = 'server_error';
}

/// Bir seans gönderiminin sonucu.
sealed class SessionSubmitResult {
  const SessionSubmitResult();
}

/// Sunucu seansı kaydetti (ya da daha önce kaydetmişti: [duplicate]).
final class SessionSubmitSuccess extends SessionSubmitResult {
  const SessionSubmitSuccess({
    required this.minutes,
    this.basePoints = 0,
    this.bonusPoints = 0,
    this.totalPoints = 0,
    this.bonusPct = 0,
    this.coinsEarned = 0,
    this.streak,
    this.dailyLimitReached = false,
    this.duplicate = false,
  });

  final int minutes;
  final int basePoints;
  final int bonusPoints;
  final int totalPoints;
  final int bonusPct;
  final int coinsEarned;

  /// Sunucunun hesapladığı güncel seri (yanıtta yoksa null).
  final int? streak;
  final bool dailyLimitReached;

  /// Seans zaten kayıtlıydı (önceki denemenin yanıtı kaybolmuş). Deltalar
  /// kullanıcıya ikinci kez eklenmemelidir.
  final bool duplicate;

  factory SessionSubmitSuccess.fromResponse(Object? response, {required int minutes}) {
    final map = response is Map ? response : const <String, dynamic>{};
    int asInt(Object? v) => v is num ? v.toInt() : 0;
    final total = asInt(map['total_points']);
    return SessionSubmitSuccess(
      minutes: minutes,
      basePoints: asInt(map['base_points']),
      bonusPoints: asInt(map['bonus_points']),
      totalPoints: total,
      bonusPct: asInt(map['bonus_pct']),
      // Canlı RPC kum tanesini puandan bağımsız 'coins_earned' ile döndürüyor;
      // eski gövdede yoktu, o durumda puan kadar verilirdi.
      coinsEarned: map.containsKey('coins_earned') ? asInt(map['coins_earned']) : total,
      streak: map['streak'] is num ? (map['streak'] as num).toInt() : null,
      dailyLimitReached: map['daily_limit_reached'] == true,
      duplicate: map['duplicate'] == true,
    );
  }
}

/// Seans kuyrukta; sonraki senkronda yeniden denenecek.
final class SessionSubmitQueued extends SessionSubmitResult {
  const SessionSubmitQueued({required this.reasonCode, required this.pendingCount});
  final String reasonCode;
  final int pendingCount;
}

/// Sunucu seansı kalıcı olarak reddetti; reddedilenler listesine taşındı.
final class SessionSubmitRejected extends SessionSubmitResult {
  const SessionSubmitRejected(this.reasonCode);
  final String reasonCode;
}

enum SessionFailureKind {
  /// Geçici; seans kalır, sıradaki seanslar denenmeye devam eder.
  transient,

  /// Bağlantı/oturum yok; seans kalır ve bu senkron durdurulur.
  offline,

  /// Cihaz saati sapmış olabilir (ölçülen fark eşiği aşıyor ya da fark
  /// ölçülemedi); seans kalır, düzeltmeyle yeniden denenir.
  clockSkew,

  /// Kategori geçersiz; kategori yeniden eşlenip denenir.
  categoryInvalid,

  /// Çakışma; seans 24 saat dolana kadar kuyrukta kalır.
  overlap,

  /// Kalıcı; seans reddedilenlere taşınır.
  permanent,
}

@immutable
class SessionFailure {
  const SessionFailure(this.kind, this.reasonCode);
  final SessionFailureKind kind;
  final String reasonCode;

  @override
  String toString() => 'SessionFailure(${kind.name}, $reasonCode)';
}

/// RPC'nin fırlattığı hatayı sınıflandırır.
///
/// Canlı complete_study_session'ın (P0001) hata metinleri:
/// - 'not authenticated' → oturum yok (tur durur, seans kalır)
/// - 'invalid duration: only 25 or 50 allowed' → kalıcı
/// - 'started_at cannot be in the future' → saat sapması
/// - 'started_at is older than 24 hours' → kalıcı
/// - 'session_not_finished' (started_at + süre > now() + 5 dk) → saat sapması
/// - 'category does not belong to this user' → kategori yeniden eşlenir
/// Gerçek aralık çakışması hata değil `{'error': 'overlap'}` yanıtıdır (bkz.
/// [classifySessionResponse]). 'session_not_elapsed' / 'session_overlap'
/// canlıda yok; uygulanmamış eski bir trigger'ın metinleri, uyumluluk için
/// tanınır.
///
/// [offsetNow] o an bilinen sunucu-cihaz saat farkı, [appliedCorrection]
/// gönderilen started_at'e uygulanmış düzeltmedir. Zaman hataları ("bitmedi
/// / gelecekte"):
/// - Ölçülen, düzeltilmemiş fark [ServerClock.significantSkew]'i aşıyorsa
///   geçici, neden 'clock_skew' (yalnızca bu durumda "cihazının saati
///   farklı" denir).
/// - Fark ölçülemediyse geçici (yeniden denenir) ama neden sunucunun
///   söylediği ('not_elapsed' / 'future_start'): saat suçlanmaz.
/// - Aksi halde seans gerçekten erkendir (ör. kısaltılmış test sayacı) ve
///   aynı nedenle kalıcı reddedilir.
SessionFailure classifySessionError(
  Object error, {
  Duration? offsetNow,
  Duration appliedCorrection = Duration.zero,
}) {
  SessionFailure timing(String reason) {
    if (offsetNow == null) return SessionFailure(SessionFailureKind.clockSkew, reason);
    if ((offsetNow - appliedCorrection).abs() >= ServerClock.significantSkew) {
      return const SessionFailure(SessionFailureKind.clockSkew, SessionReason.clockSkew);
    }
    return SessionFailure(SessionFailureKind.permanent, reason);
  }

  if (error is ServiceException) {
    final cause = error.cause;
    if (cause != null) {
      return classifySessionError(cause, offsetNow: offsetNow, appliedCorrection: appliedCorrection);
    }
    return switch (error.code) {
      ServiceErrorCode.timeout => const SessionFailure(SessionFailureKind.offline, SessionReason.timeout),
      ServiceErrorCode.network => const SessionFailure(SessionFailureKind.offline, SessionReason.network),
      ServiceErrorCode.cloudUnavailable ||
      ServiceErrorCode.notSignedIn =>
        const SessionFailure(SessionFailureKind.offline, SessionReason.auth),
      _ => const SessionFailure(SessionFailureKind.transient, SessionReason.serverError),
    };
  }
  if (error is PostgrestException) {
    final code = error.code ?? '';
    final msg = '${error.message} ${error.details ?? ''}'.toLowerCase();
    if (msg.contains('not authenticated')) {
      return const SessionFailure(SessionFailureKind.offline, SessionReason.auth);
    }
    if (code == 'P0001') {
      if (msg.contains('session_overlap') || msg.contains('overlap')) {
        return const SessionFailure(SessionFailureKind.overlap, SessionReason.overlap);
      }
      if (msg.contains('session_not_finished') || msg.contains('session_not_elapsed')) {
        return timing(SessionReason.notElapsed);
      }
      if (msg.contains('in the future')) return timing(SessionReason.futureStart);
      if (msg.contains('older than')) {
        return const SessionFailure(SessionFailureKind.permanent, SessionReason.tooOld);
      }
      if (msg.contains('invalid duration')) {
        return const SessionFailure(SessionFailureKind.permanent, SessionReason.invalidDuration);
      }
      if (msg.contains('category')) {
        return const SessionFailure(SessionFailureKind.categoryInvalid, SessionReason.categoryInvalid);
      }
      if (msg.contains('session_missing_start')) {
        return const SessionFailure(SessionFailureKind.permanent, SessionReason.invalidData);
      }
      return const SessionFailure(SessionFailureKind.permanent, SessionReason.serverRejected);
    }
    // Geçersiz kategori kimliği (uuid biçimi) ya da kategori yabancı anahtarı.
    if ((code == '22P02' && msg.contains('uuid')) || (code == '23503' && msg.contains('categor'))) {
      return const SessionFailure(SessionFailureKind.categoryInvalid, SessionReason.categoryInvalid);
    }
    // 23505: aynı client_uuid ile yarış; bir sonraki denemede RPC 'duplicate' döner.
    // 23503: profil satırı henüz yok olabilir; profil oluşturulunca geçer.
    if (code == '23505' || code == '23503') {
      return const SessionFailure(SessionFailureKind.transient, SessionReason.serverError);
    }
    if (code.startsWith('22') || code.startsWith('23')) {
      return const SessionFailure(SessionFailureKind.permanent, SessionReason.invalidData);
    }
    if (code == 'PGRST301' || code == '42501') {
      return const SessionFailure(SessionFailureKind.offline, SessionReason.auth);
    }
    return const SessionFailure(SessionFailureKind.transient, SessionReason.serverError);
  }
  if (error is AuthException) {
    return const SessionFailure(SessionFailureKind.offline, SessionReason.auth);
  }
  if (error is TimeoutException) {
    return const SessionFailure(SessionFailureKind.offline, SessionReason.timeout);
  }
  if (isNetworkError(error)) {
    return const SessionFailure(SessionFailureKind.offline, SessionReason.network);
  }
  return const SessionFailure(SessionFailureKind.transient, SessionReason.serverError);
}

/// RPC'nin hata fırlatmadan döndürdüğü yanıtı sınıflandırır. Seans kabul
/// edildiyse null döner. Canlı gövde gerçek aralık çakışmasını
/// `{'error': 'overlap'}` olarak döndürür; bilinmeyen diğer `{'error': ...}`
/// yanıtları kalıcı sayılır.
SessionFailure? classifySessionResponse(Object? response) {
  if (response is! Map || response['error'] == null) return null;
  final raw = response['error'].toString().toLowerCase();
  if (raw.contains('overlap')) {
    return const SessionFailure(SessionFailureKind.overlap, SessionReason.overlap);
  }
  final code = raw.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
  return SessionFailure(
    SessionFailureKind.permanent,
    code.isEmpty ? SessionReason.serverRejected : (code.length > 40 ? code.substring(0, 40) : code),
  );
}

/// Sunucudaki bir kategori (kuyruk eşlemesi için yeterli alanlar).
typedef CategoryRef = ({String id, String name, bool isArchived});

/// Yer tutucu/geçersiz kategoriyle tamamlanmış seans için sunucu kategorisi
/// seçer: önce isimle (aktifler öncelikli, sonra arşivlenmiş), eşleşme yoksa
/// ilk aktif kategori. Hiç kategori yoksa null. İsim eşlemesi dilden
/// bağımsızdır: yer tutucu 'Fizik', İngilizce saklanmış 'Physics' ile eşleşir.
String? resolveCategoryId(String categoryName, List<CategoryRef> categories) {
  final wanted = categoryName.trim().isEmpty ? '' : categoryMatchKey(categoryName);
  CategoryRef? archivedMatch;
  CategoryRef? firstActive;
  CategoryRef? firstAny;
  for (final c in categories) {
    if (wanted.isNotEmpty && categoryMatchKey(c.name) == wanted) {
      if (!c.isArchived) return c.id;
      archivedMatch ??= c;
    }
    if (!c.isArchived) firstActive ??= c;
    firstAny ??= c;
  }
  return (archivedMatch ?? firstActive ?? firstAny)?.id;
}

/// Kuyruğun ağ/sunucu bağımlılıkları (testte sahtesiyle değiştirilir).
abstract class SessionQueueBackend {
  /// Oturumdaki kullanıcı. Gönderim yalnızca kuyruğun sahibi oturumdayken
  /// yapılır; bekleyen seans asla başka hesaba gönderilmez.
  String? get signedInUserId;

  /// complete_study_session RPC'si.
  Future<Object?> completeSession(
    PendingSession session, {
    required String categoryId,
    required DateTime startedAtForServer,
  });

  /// Kullanıcının arşivlenmişler dahil tüm kategorileri.
  Future<List<CategoryRef>> fetchCategories();

  /// Hiç kategorisi olmayan kullanıcı için varsayılan kategorileri oluşturur.
  Future<void> createDefaultCategories();
}

/// Bir senkron turunun özeti.
@immutable
class SessionSyncReport {
  const SessionSyncReport({
    this.sent = 0,
    this.rejected = 0,
    this.remaining = 0,
    this.outcomes = const {},
    this.stopReason,
  });

  final int sent;
  final int rejected;
  final int remaining;

  /// client_uuid → bu turda o seans için sonuç.
  final Map<String, SessionSubmitResult> outcomes;

  /// Tur erken durduysa nedeni (ör. 'network').
  final String? stopReason;

  /// Kuyrukta, kendiliğinden yeniden denemeye değer (ağ, zaman aşımı,
  /// sunucu ya da oturum hatası gibi geçici bir nedenle bekleyen) seans
  /// kaldı mı? Yalnızca çakışma ('overlap') nedeniyle bekleyenler için
  /// false: onlar tekrar gönderilince yine çakışır.
  bool get hasRetryableFailure =>
      remaining > 0 &&
      (stopReason != null ||
          outcomes.values.any((o) => o is SessionSubmitQueued && o.reasonCode != SessionReason.overlap));

  SessionSyncReport _merge(SessionSyncReport later) => SessionSyncReport(
        sent: sent + later.sent,
        rejected: rejected + later.rejected,
        remaining: later.remaining,
        outcomes: {...outcomes, ...later.outcomes},
        stopReason: later.stopReason,
      );
}

class SessionQueue {
  SessionQueue({
    required this.backend,
    required this.clock,
    this.rpcTimeout = const Duration(seconds: 15),
    this.onAccepted,
    this.onQueueChanged,
  });

  final SessionQueueBackend backend;
  final ServerClock clock;
  final Duration rpcTimeout;

  /// Her kabul edilen seansta çağrılır (kullanıcı modelini güncellemek için).
  final void Function(String userId, PendingSession session, SessionSubmitSuccess result)? onAccepted;

  /// Kuyruk uzunluğu değiştiğinde çağrılır.
  final void Function(String userId, int pendingCount)? onQueueChanged;

  /// Sunucunun kabul ettiği en eski started_at.
  static const Duration serverMaxAge = Duration(hours: 24);

  /// Bundan eski seanslar hiç gönderilmeden reddedilir (sunucu zaten reddeder).
  static const Duration giveUpAge = Duration(hours: 48);
  static const int maxRejectedHistory = 50;

  static String queueKey(String userId) => 'pending_sessions_uid_$userId';
  static String legacyQueueKey(String email) => 'pending_sessions_${email.trim().toLowerCase()}';
  static String rejectedKey(String userId) => 'rejected_sessions_uid_$userId';
  static String rejectedNoticeKey(String userId) => 'rejected_sessions_unseen_uid_$userId';

  // Diskteki listeye yapılan her oku-değiştir-yaz bu kilitle serileşir.
  final AsyncLock _storageLock = AsyncLock();
  // Aynı anda tek senkron turu çalışır.
  final AsyncLock _syncLock = AsyncLock();
  Future<SessionSyncReport>? _scheduled;
  String? _scheduledUserId;

  /// Kullanıcının bekleyen seansları (started_at sırasıyla).
  Future<List<PendingSession>> pending(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decode(prefs, queueKey(userId))
        .map(PendingSession.fromJson)
        .whereType<PendingSession>()
        .toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return list;
  }

  Future<int> pendingCount(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs, queueKey(userId)).length;
  }

  /// E-posta anahtarlı eski kuyruktaki kayıt sayısı (kimlik henüz bilinmezken).
  Future<int> legacyPendingCount(String email) async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs, legacyQueueKey(email)).length;
  }

  /// Seansı kalıcı kuyruğa yazar (aynı client_uuid varsa günceller).
  Future<void> enqueue(String userId, PendingSession session) async {
    final count = await _storageLock.synchronized(() => _upsert(queueKey(userId), session));
    onQueueChanged?.call(userId, count);
  }

  /// Kullanıcı kimliği bilinmezken (eski önbellek, çevrimdışı açılış) seansı
  /// e-posta anahtarlı eski kuyruğa yazar; kimlik öğrenilince
  /// [adoptLegacyQueue] ile taşınır.
  Future<void> enqueueLegacy(String email, PendingSession session) =>
      _storageLock.synchronized(() => _upsert(legacyQueueKey(email), session));

  /// E-posta anahtarlı eski kuyruktaki kayıtları kullanıcı kimliğine taşır.
  Future<void> adoptLegacyQueue({required String userId, required String email}) async {
    if (email.trim().isEmpty) return;
    final count = await _storageLock.synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      final legacyKey = legacyQueueKey(email);
      final legacy = _decode(prefs, legacyKey);
      final current = _decode(prefs, queueKey(userId));
      if (legacy.isEmpty) return current.length;
      final known = current.map((e) => e['client_uuid']).whereType<String>().toSet();
      for (final entry in legacy) {
        final uuid = entry['client_uuid'];
        if (uuid is String && known.contains(uuid)) continue;
        current.add(entry);
      }
      await _write(prefs, queueKey(userId), current);
      await prefs.remove(legacyKey);
      return current.length;
    });
    onQueueChanged?.call(userId, count);
  }

  /// Bekleyen seansları göndermeyi dener. Devam eden bir tur varsa onun
  /// sonucunu paylaşır.
  Future<SessionSyncReport> sync(String userId) {
    final scheduled = _scheduled;
    if (scheduled != null && _scheduledUserId == userId) return scheduled;
    return _schedulePass(userId);
  }

  /// Seansı önce diske yazar, sonra kuyruğu (bu seans dahil) gönderir ve bu
  /// seansın sonucunu döndürür.
  Future<SessionSubmitResult> submit(String userId, PendingSession session) async {
    await enqueue(userId, session);
    if (backend.signedInUserId != userId) {
      return SessionSubmitQueued(reasonCode: SessionReason.offline, pendingCount: await pendingCount(userId));
    }
    // Devam eden tur bu seansı görmemiş olabilir: her zaman yeni bir tur.
    final report = await _schedulePass(userId, foregroundUuid: session.clientUuid);
    return report.outcomes[session.clientUuid] ??
        SessionSubmitQueued(
          reasonCode: report.stopReason ?? SessionReason.network,
          pendingCount: report.remaining,
        );
  }

  /// Bildirilmemiş reddedilen seans sayısını döndürür ve sıfırlar.
  Future<int> takeRejectedNoticeCount(String userId) => _storageLock.synchronized(() async {
        final prefs = await SharedPreferences.getInstance();
        final count = prefs.getInt(rejectedNoticeKey(userId)) ?? 0;
        if (count != 0) await prefs.remove(rejectedNoticeKey(userId));
        return count;
      });

  Future<List<RejectedSession>> rejectedSessions(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs, rejectedKey(userId)).map(RejectedSession.fromJson).whereType<RejectedSession>().toList();
  }

  /// Hesap silindiğinde kullanıcının kuyruk verisini tamamen kaldırır.
  Future<void> clearUser(String userId, {String? email}) async {
    await _storageLock.synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(queueKey(userId));
      await prefs.remove(rejectedKey(userId));
      await prefs.remove(rejectedNoticeKey(userId));
      if (email != null && email.trim().isNotEmpty) await prefs.remove(legacyQueueKey(email));
    });
    onQueueChanged?.call(userId, 0);
  }

  Future<SessionSyncReport> _schedulePass(String userId, {String? foregroundUuid}) {
    final future = _syncLock.synchronized(() => _runPass(userId, foregroundUuid: foregroundUuid));
    _scheduled = future;
    _scheduledUserId = userId;
    future.whenComplete(() {
      if (identical(_scheduled, future)) {
        _scheduled = null;
        _scheduledUserId = null;
      }
    }).ignore();
    return future;
  }

  Future<SessionSyncReport> _runPass(
    String userId, {
    String? foregroundUuid,
    bool allowRemapRetry = true,
  }) async {
    final outcomes = <String, SessionSubmitResult>{};
    var sent = 0;
    var rejected = 0;
    String? stopReason;
    var remapRequested = false;

    try {
      final snapshot = await _storageLock.synchronized(() => _prepareSnapshot(userId));
      rejected += snapshot.corruptCount;
      final entries = snapshot.entries;

      if (entries.isNotEmpty && backend.signedInUserId != userId) {
        stopReason = SessionReason.offline;
      } else if (entries.isNotEmpty) {
        // 1) Yer tutucu kategorileri sunucu kategorilerine eşle.
        final resolved = <String, String>{};
        SessionFailure? categoryFailure;
        final needsMapping = entries.where((e) => !isUuidCategoryId(e.categoryId)).toList();
        if (needsMapping.isNotEmpty) {
          try {
            var categories = await backend.fetchCategories().timeout(rpcTimeout);
            if (categories.isEmpty) {
              await backend.createDefaultCategories().timeout(rpcTimeout);
              categories = await backend.fetchCategories().timeout(rpcTimeout);
            }
            for (final e in needsMapping) {
              final id = resolveCategoryId(e.categoryName, categories);
              if (id != null) resolved[e.clientUuid] = id;
            }
          } catch (e) {
            debugPrint('[QUEUE] Kategoriler alınamadı, eşlenemeyen seanslar bekleyecek: $e');
            categoryFailure = classifySessionError(e);
          }
        }

        // 2) Saat farkı bilinmeden kuyruğa girmiş seanslar, fark öğrenilmeden
        // gönderilmez. Farksız (cihaz saatiyle) giden bir seans sunucuya
        // kaydırılmış aralıkla yazılır; fark o yanıttan öğrenilince sıradaki
        // seans düzeltilmiş saatle gider ve öncekiyle çakışır ('overlap').
        // Ucuz bir istek (kategoriler) yanıtının 'date' başlığıyla farkı
        // öğretir. İstek başarısızsa tur durur; hiçbir seans gönderilmez.
        // (İstek başarılı olup başlık yine de okunamadıysa düzeltmesiz
        // gönderilir: başka bir yol yok.)
        if (clock.offset == null && entries.any((e) => e.clockOffsetMs == null)) {
          if (categoryFailure != null) {
            stopReason = categoryFailure.reasonCode;
          } else {
            try {
              await backend.fetchCategories().timeout(rpcTimeout);
            } catch (e) {
              stopReason = classifySessionError(e).reasonCode;
              debugPrint('[QUEUE] Saat farkı öğrenilemedi, seanslar bekleyecek: $e');
            }
          }
        }

        // Fark kaydı olmayan seansların hepsi bu turda AYNI farkla düzeltilir
        // (yanıtlarla gelen her yeni ölçüm araya girmez).
        var passOffset = clock.offset;

        // 3) started_at sırasıyla gönder.
        if (stopReason == null) {
          sendLoop:
          for (final entry in entries) {
            if (backend.signedInUserId != userId) {
              stopReason = SessionReason.offline;
              break;
            }
            final isForeground = entry.clientUuid == foregroundUuid;
            final entryOffset = entry.clockOffsetMs != null ? Duration(milliseconds: entry.clockOffsetMs!) : null;

            if (_serverAge(entry, entryOffset) > giveUpAge) {
              await _reject(userId, entry, SessionReason.tooOld, notify: !isForeground);
              rejected++;
              outcomes[entry.clientUuid] = const SessionSubmitRejected(SessionReason.tooOld);
              continue;
            }

            final categoryId = isUuidCategoryId(entry.categoryId) ? entry.categoryId! : resolved[entry.clientUuid];
            if (categoryId == null) {
              // Kategori eşlenemedi (çoğunlukla ağ yok). Sıra bozulmasın diye tur durur.
              final reason = categoryFailure?.reasonCode ?? SessionReason.categoryInvalid;
              outcomes[entry.clientUuid] = SessionSubmitQueued(reasonCode: reason, pendingCount: 0);
              stopReason = reason;
              break;
            }

            SessionSubmitSuccess? success;
            SessionFailure? failure;
            // Saat farkı bu denemede ilk kez öğrenildiyse bir kez düzeltilmiş
            // started_at ile yeniden denenir.
            for (var attempt = 0; attempt < 2; attempt++) {
              final correction = ServerClock.correctionFor(entryOffset ?? passOffset);
              try {
                final response = await backend
                    .completeSession(entry, categoryId: categoryId, startedAtForServer: entry.startedAt.add(correction))
                    .timeout(rpcTimeout);
                failure = classifySessionResponse(response);
                if (failure == null) success = SessionSubmitSuccess.fromResponse(response, minutes: entry.minutes);
              } catch (e) {
                failure = classifySessionError(
                  e,
                  // Kuyruğa yazılırken fark biliniyorsa o fark esas alınır.
                  offsetNow: entryOffset ?? clock.offset,
                  appliedCorrection: correction,
                );
                debugPrint('[QUEUE] Seans gönderilemedi (${failure.kind.name}/${failure.reasonCode}): $e');
              }
              final retryWithNewClock = failure?.kind == SessionFailureKind.clockSkew &&
                  entryOffset == null &&
                  ServerClock.correctionFor(clock.offset) != correction;
              if (!retryWithNewClock) break;
              // Fark bu turda değişti (ör. cihaz saati ayarlandı): sonraki
              // kayıtlar da yeni farkla, tutarlı gönderilir.
              passOffset = clock.offset;
            }

            if (success != null) {
              await _storageLock.synchronized(() => _remove(queueKey(userId), entry.clientUuid));
              sent++;
              outcomes[entry.clientUuid] = success;
              onAccepted?.call(userId, entry, success);
              continue;
            }

            final f = failure!;
            switch (f.kind) {
              case SessionFailureKind.permanent:
                await _reject(userId, entry, f.reasonCode, notify: !isForeground);
                rejected++;
                outcomes[entry.clientUuid] = SessionSubmitRejected(f.reasonCode);
              case SessionFailureKind.overlap:
                if (_serverAge(entry, entryOffset) >= serverMaxAge) {
                  await _reject(userId, entry, SessionReason.overlap, notify: !isForeground);
                  rejected++;
                  outcomes[entry.clientUuid] = const SessionSubmitRejected(SessionReason.overlap);
                } else {
                  await _keep(userId, entry.copyWith(lastError: f.reasonCode));
                  outcomes[entry.clientUuid] = SessionSubmitQueued(reasonCode: f.reasonCode, pendingCount: 0);
                }
              case SessionFailureKind.categoryInvalid:
                if (entry.categoryRemaps >= 1) {
                  await _reject(userId, entry, SessionReason.categoryInvalid, notify: !isForeground);
                  rejected++;
                  outcomes[entry.clientUuid] = const SessionSubmitRejected(SessionReason.categoryInvalid);
                } else {
                  await _keep(
                    userId,
                    entry.copyWith(clearCategoryId: true, categoryRemaps: entry.categoryRemaps + 1, lastError: f.reasonCode),
                  );
                  remapRequested = true;
                  outcomes[entry.clientUuid] = SessionSubmitQueued(reasonCode: f.reasonCode, pendingCount: 0);
                }
              case SessionFailureKind.offline:
                await _keep(userId, entry.copyWith(lastError: f.reasonCode));
                outcomes[entry.clientUuid] = SessionSubmitQueued(reasonCode: f.reasonCode, pendingCount: 0);
                stopReason = f.reasonCode;
                break sendLoop;
              case SessionFailureKind.transient:
              case SessionFailureKind.clockSkew:
                await _keep(userId, entry.copyWith(lastError: f.reasonCode));
                outcomes[entry.clientUuid] = SessionSubmitQueued(reasonCode: f.reasonCode, pendingCount: 0);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[QUEUE] Senkron turu beklenmedik hatayla durdu: $e');
      stopReason ??= SessionReason.serverError;
    }

    final remaining = await pendingCount(userId);
    onQueueChanged?.call(userId, remaining);
    final report = SessionSyncReport(
      sent: sent,
      rejected: rejected,
      remaining: remaining,
      outcomes: {
        for (final e in outcomes.entries)
          e.key: e.value is SessionSubmitQueued
              ? SessionSubmitQueued(reasonCode: (e.value as SessionSubmitQueued).reasonCode, pendingCount: remaining)
              : e.value,
      },
      stopReason: stopReason,
    );
    if (remapRequested && allowRemapRetry && stopReason == null) {
      return report._merge(await _runPass(userId, foregroundUuid: foregroundUuid, allowRemapRetry: false));
    }
    return report;
  }

  /// Seansın sunucu saatine göre yaşı (başlangıcından bu yana geçen süre).
  Duration _serverAge(PendingSession entry, Duration? entryOffset) => clock
      .serverNow()
      .difference(entry.startedAt.add(ServerClock.correctionFor(entryOffset ?? clock.offset)));

  // ---- Depolama ----
  // _decode/_write/_upsert/_remove/_appendRejected/_prepareSnapshot yalnızca
  // _storageLock içinden çağrılır; _keep ve _reject kilidi kendileri alır.

  List<Map<String, dynamic>> _decode(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(SharedPreferences prefs, String key, List<Map<String, dynamic>> list) async {
    if (list.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, jsonEncode(list));
    }
  }

  Future<int> _upsert(String key, PendingSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decode(prefs, key)..removeWhere((e) => e['client_uuid'] == session.clientUuid);
    list.add(session.toJson());
    await _write(prefs, key, list);
    return list.length;
  }

  Future<void> _remove(String key, String clientUuid) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decode(prefs, key);
    final before = list.length;
    list.removeWhere((e) => e['client_uuid'] == clientUuid);
    if (list.length != before) await _write(prefs, key, list);
  }

  Future<void> _keep(String userId, PendingSession updated) => _storageLock.synchronized(() async {
        final prefs = await SharedPreferences.getInstance();
        final list = _decode(prefs, queueKey(userId));
        final index = list.indexWhere((e) => e['client_uuid'] == updated.clientUuid);
        if (index == -1) return;
        list[index] = updated.toJson();
        await _write(prefs, queueKey(userId), list);
      });

  Future<void> _reject(String userId, PendingSession entry, String reason, {required bool notify}) =>
      _storageLock.synchronized(() async {
        final prefs = await SharedPreferences.getInstance();
        await _remove(queueKey(userId), entry.clientUuid);
        await _appendRejected(
          prefs,
          userId,
          RejectedSession(
            clientUuid: entry.clientUuid,
            startedAt: entry.startedAt,
            minutes: entry.minutes,
            categoryName: entry.categoryName,
            reasonCode: reason,
            rejectedAt: DateTime.now().toUtc(),
          ),
          notify: notify,
        );
      });

  Future<void> _appendRejected(SharedPreferences prefs, String userId, RejectedSession rejected, {required bool notify}) async {
    final list = _decode(prefs, rejectedKey(userId))..add(rejected.toJson());
    final trimmed = list.length > maxRejectedHistory ? list.sublist(list.length - maxRejectedHistory) : list;
    await _write(prefs, rejectedKey(userId), trimmed);
    if (notify) {
      await prefs.setInt(rejectedNoticeKey(userId), (prefs.getInt(rejectedNoticeKey(userId)) ?? 0) + 1);
    }
  }

  /// Kuyruğu okur; client_uuid'i olmayan eski kayıtlara BİR KEZ kimlik
  /// üretip geri yazar (her denemede yeni kimlik çift kayıt yaratırdı),
  /// okunamayan kayıtları reddedilenlere taşır.
  Future<({List<PendingSession> entries, int corruptCount})> _prepareSnapshot(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = queueKey(userId);
    final raw = _decode(prefs, key);
    var dirty = false;
    var corrupt = 0;
    final kept = <Map<String, dynamic>>[];
    final entries = <PendingSession>[];
    for (final map in raw) {
      final uuid = map['client_uuid'];
      if (uuid is! String || uuid.isEmpty) {
        map['client_uuid'] = const Uuid().v4();
        dirty = true;
      }
      final parsed = PendingSession.fromJson(map);
      if (parsed == null) {
        corrupt++;
        dirty = true;
        await _appendRejected(
          prefs,
          userId,
          RejectedSession(
            clientUuid: map['client_uuid'].toString(),
            startedAt: DateTime.tryParse(map['started_at']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc(),
            minutes: _asInt(map['minutes']) ?? 0,
            categoryName: map['category_name']?.toString() ?? '',
            reasonCode: SessionReason.corrupt,
            rejectedAt: DateTime.now().toUtc(),
          ),
          notify: true,
        );
        continue;
      }
      kept.add(map);
      entries.add(parsed);
    }
    if (dirty) await _write(prefs, key, kept);
    entries.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return (entries: entries, corruptCount: corrupt);
  }
}
