import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../utils/async_lock.dart';
import 'language_service.dart';
import 'notification_service.dart';
import 'platform_env.dart' if (dart.library.io) 'platform_env_io.dart';
import 'timer_persistence.dart';

/// Kilit ekranında gösterilecek sayaç içeriği. Platformdan bağımsızdır;
/// metinler uygulamanın o anki dilinde hazır gelir (iOS widget'ı kendi
/// yerelleştirmesini taşımaz).
@immutable
class LockScreenTimerContent {
  const LockScreenTimerContent({
    required this.sessionId,
    required this.isPaused,
    required this.categoryName,
    required this.endsAt,
    required this.rangeStart,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.expiresIn,
    required this.title,
    required this.body,
    required this.channelName,
    required this.channelDescription,
    required this.runningLabel,
    required this.pausedLabel,
    required this.finishedLabel,
    required this.finishedHint,
  });

  /// Seansın `client_uuid`'i.
  final String sessionId;
  final bool isPaused;

  /// Gösterilen kategori adı (çevrilmiş).
  final String categoryName;

  /// Geri sayımın bittiği an. Duraklatılmışken "şimdi + kalan"dır ve yalnızca
  /// bilgi amaçlıdır (sayaç akmaz).
  final DateTime endsAt;

  /// İlerleme çubuğunun başlangıcı (endsAt - toplam süre): çubuk duraklatma
  /// sonrasında da kalan/toplam oranını gösterir.
  final DateTime rangeStart;
  final int remainingSeconds;
  final int totalSeconds;

  /// Bu süre sonunda içerik geçersizdir: çalışırken bitiş anı, duraklatılmışken
  /// seansın sunucunun kabul etmeyeceği yaşa geldiği an. Android bildirimi bu
  /// sürede kendiliğinden kalkar (uygulama öldürülse bile).
  final Duration expiresIn;

  /// Android bildirim başlığı ve gövdesi.
  final String title;
  final String body;
  final String channelName;
  final String channelDescription;

  /// iOS Canlı Etkinlik etiketleri.
  final String runningLabel;
  final String pausedLabel;
  final String finishedLabel;
  final String finishedHint;

  /// Aynı içerik platforma tekrar gönderilmesin diye karşılaştırma anahtarı
  /// (zamanla değişen alanlar hariç; dil değişince değişir).
  String get key => [
        if (isPaused) 'p' else 'r',
        sessionId,
        if (isPaused) remainingSeconds else endsAt.millisecondsSinceEpoch,
        totalSeconds,
        categoryName,
        title,
        body,
        runningLabel,
        pausedLabel,
        finishedLabel,
        finishedHint,
      ].join('|');

  /// iOS kanalına giden argümanlar (ios/Runner/LiveActivityChannel.swift).
  Map<String, Object> toLiveActivityArguments() => {
        'sessionId': sessionId,
        'isPaused': isPaused,
        'categoryName': categoryName,
        'endsAtMs': endsAt.millisecondsSinceEpoch,
        'startedAtMs': rangeStart.millisecondsSinceEpoch,
        'remainingSeconds': remainingSeconds,
        'totalSeconds': totalSeconds,
        'runningLabel': runningLabel,
        'pausedLabel': pausedLabel,
        'finishedLabel': finishedLabel,
        'finishedHint': finishedHint,
      };
}

/// Kilit ekranı sayacının platform katmanı (testte sahtesi enjekte edilir).
abstract class LockScreenTimerPlatform {
  const LockScreenTimerPlatform();

  /// false ise cephe hiçbir şey yapmaz (desteklenmeyen platform, test).
  bool get isSupported => true;

  /// İçeriği gösterir ya da günceller; gösterildiyse true. [isNewSession]:
  /// önceden hiçbir şey gösterilmiyordu ya da başka bir seans gösteriliyordu
  /// (iOS'ta artakalan etkinlikler bitirilip yenisi başlatılır).
  Future<bool> show(LockScreenTimerContent content, {required bool isNewSession});

  /// Gösterilen sayacı kaldırır (yoksa bir şey yapmaz).
  Future<void> clear();
}

/// Desteklenmeyen platform ve test: hiçbir şey yapmaz.
class NoopLockScreenTimerPlatform extends LockScreenTimerPlatform {
  const NoopLockScreenTimerPlatform();

  @override
  bool get isSupported => false;

  @override
  Future<bool> show(LockScreenTimerContent content, {required bool isNewSession}) async => false;

  @override
  Future<void> clear() async {}
}

/// Android: kilit ekranında görünen, geri sayan kalıcı bildirim.
class AndroidLockScreenTimerPlatform extends LockScreenTimerPlatform {
  const AndroidLockScreenTimerPlatform();

  @override
  Future<bool> show(LockScreenTimerContent content, {required bool isNewSession}) {
    return NotificationService.instance.showOngoingTimer(
      title: content.title,
      body: content.body,
      channelName: content.channelName,
      channelDescription: content.channelDescription,
      timeout: content.expiresIn,
      countdownTo: content.isPaused ? null : content.endsAt,
    );
  }

  @override
  Future<void> clear() => NotificationService.instance.cancelOngoingTimer();
}

/// iOS 16.2+: kilit ekranı ve Dynamic Island'da Canlı Etkinlik (Live
/// Activity). Yerel taraf: ios/Runner/LiveActivityChannel.swift.
class IosLiveActivityPlatform extends LockScreenTimerPlatform {
  const IosLiveActivityPlatform();

  static const MethodChannel channel = MethodChannel('com.pomosprint.app/live_activity');

  @override
  Future<bool> show(LockScreenTimerContent content, {required bool isNewSession}) async {
    final shown = await channel.invokeMethod<bool>(isNewSession ? 'start' : 'update', content.toLiveActivityArguments());
    return shown ?? false;
  }

  @override
  Future<void> clear() => channel.invokeMethod<void>('end');
}

enum _Display { unknown, none, shown }

/// Süren ya da duraklatılmış seansı kilit ekranında gösterir: Android'de
/// geri sayan kalıcı bildirim, iPhone'da Canlı Etkinlik. Dart'ın arka planda
/// çalışmasına gerek yoktur; geri sayımı sistem kendisi yürütür.
///
/// Çağrılar sırayla uygulanır, idempotenttir ve asla hata fırlatmaz.
/// Kullanıcının bildirim tercihi ([NotificationService.isEnabled]) kapalıysa
/// hiçbir şey gösterilmez.
class LockScreenTimer {
  LockScreenTimer({
    required this.platform,
    Future<bool> Function()? isEnabled,
    DateTime Function()? clock,
    AppLocalizations Function()? localizations,
    String Function(String categoryName)? categoryLabel,
  })  : _isEnabled = isEnabled ?? NotificationService.instance.isEnabled,
        _clock = clock ?? DateTime.now,
        _localizations = localizations ?? _currentLocalizations,
        _categoryLabel = categoryLabel ?? NotificationService.displayCategoryName;

  static final LockScreenTimer instance = _createDefault();

  static LockScreenTimer _createDefault() {
    final timer = LockScreenTimer(platform: _defaultPlatform());
    if (timer.platform.isSupported) {
      // Tercih ya da dil değişince gösterilen içerik yenilenir.
      NotificationService.instance.preferenceRevision.addListener(timer._onEnvironmentChanged);
      LanguageService.instance.addListener(timer._onEnvironmentChanged);
    }
    return timer;
  }

  static LockScreenTimerPlatform _defaultPlatform() {
    if (kIsWeb || isFlutterTestEnvironment) return const NoopLockScreenTimerPlatform();
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => const AndroidLockScreenTimerPlatform(),
      TargetPlatform.iOS => const IosLiveActivityPlatform(),
      _ => const NoopLockScreenTimerPlatform(),
    };
  }

  static AppLocalizations _currentLocalizations() => lookupAppLocalizations(LanguageService.instance.currentLocale);

  /// Platform katmanı (Android bildirimi, iOS Canlı Etkinlik ya da no-op).
  final LockScreenTimerPlatform platform;
  final Future<bool> Function() _isEnabled;
  final DateTime Function() _clock;
  final AppLocalizations Function() _localizations;
  final String Function(String categoryName) _categoryLabel;
  final AsyncLock _lock = AsyncLock();

  // Son istenen durum (null: sayaç yok); tercih/dil değişince yeniden uygulanır.
  ActiveTimerSession? _requested;
  bool _hasRequest = false;

  // Platformda gerçekte gösterilen. Açılışta bilinmez: önceki süreçten kalan
  // bildirim ya da Canlı Etkinlik olabilir.
  _Display _display = _Display.unknown;
  String? _shownKey;
  String? _shownSessionId;

  /// Çalışan seansı gösterir (seans duraklatılmışsa duraklatılmış hali).
  /// [force]: içerik aynı olsa da yeniden gönderilir (ör. ön plana dönüşte;
  /// kullanıcı bildirimi kapatmış ya da sistem etkinliği bitirmiş olabilir).
  Future<void> showRunning(ActiveTimerSession session, {bool force = false}) => show(session, force: force);

  /// Duraklatılmış seansı sabit kalan süreyle gösterir.
  Future<void> showPaused(ActiveTimerSession session, {bool force = false}) => show(session, force: force);

  /// Seansı gerçek durumuna göre gösterir. Süresi dolmuş ya da artık
  /// kaydedilemeyecek seans için gösterilen sayaç kaldırılır.
  Future<void> show(ActiveTimerSession session, {bool force = false}) => _enqueue(session, force: force);

  /// Gösterilen sayacı kaldırır.
  Future<void> clear() => _enqueue(null, force: false);

  /// Son istenen durumu yeniden uygular (bildirim tercihi ya da dil değişti).
  Future<void> refresh() {
    if (!_hasRequest) return Future<void>.value();
    return _enqueue(_requested, force: false);
  }

  void _onEnvironmentChanged() => unawaited(refresh());

  Future<void> _enqueue(ActiveTimerSession? session, {required bool force}) {
    if (!platform.isSupported) return Future<void>.value();
    _requested = session;
    _hasRequest = true;
    return _lock.synchronized(() => _apply(session, force: force));
  }

  Future<void> _apply(ActiveTimerSession? session, {required bool force}) async {
    try {
      final content = session == null || !await _isEnabled() ? null : contentFor(session, _clock());
      if (content == null) {
        await _clearPlatform();
        return;
      }
      final key = content.key;
      if (!force && _display == _Display.shown && _shownKey == key) return;
      final isNewSession = switch (_display) {
        _Display.none => true,
        _Display.shown => _shownSessionId != content.sessionId,
        // Önceki süreçten aynı seansın etkinliği kalmış olabilir: güncellenir
        // (iOS tarafı bulamazsa yenisini başlatır).
        _Display.unknown => false,
      };
      final shown = await platform.show(content, isNewSession: isNewSession);
      if (shown) {
        _display = _Display.shown;
        _shownKey = key;
        _shownSessionId = content.sessionId;
      } else {
        _markUnknown();
      }
    } catch (e) {
      debugPrint('[LOCK] Kilit ekranı sayacı güncellenemedi: $e');
      _markUnknown();
    }
  }

  Future<void> _clearPlatform() async {
    if (_display == _Display.none) return;
    try {
      await platform.clear();
      _display = _Display.none;
      _shownKey = null;
      _shownSessionId = null;
    } catch (e) {
      debugPrint('[LOCK] Kilit ekranı sayacı kaldırılamadı: $e');
      _markUnknown();
    }
  }

  void _markUnknown() {
    _display = _Display.unknown;
    _shownKey = null;
    _shownSessionId = null;
  }

  /// [now] anında [session] için gösterilecek içerik; gösterilecek bir şey
  /// yoksa (süre dolmuş, duraklatılmış seans artık kaydedilemez) null.
  @visibleForTesting
  LockScreenTimerContent? contentFor(ActiveTimerSession session, DateTime now) {
    final remaining = session.remainingSecondsAt(now);
    if (remaining <= 0) return null;
    final total = math.max(session.totalSeconds, remaining);
    final DateTime endsAt;
    final Duration expiresIn;
    if (session.isRunning) {
      endsAt = session.endsAt!;
      expiresIn = endsAt.difference(now);
    } else {
      // Sunucu, başlangıcı 24 saatten eski seansı kabul etmez; devam edilse
      // bile o sınırı aşacak duraklatılmış seans açılışta silinir.
      endsAt = now.add(Duration(seconds: remaining));
      expiresIn = session.startedAt.add(ActiveTimerSession.maxSessionAge).difference(endsAt);
    }
    if (expiresIn <= Duration.zero) return null;

    final l10n = _localizations();
    final category = _categoryLabel(session.categoryName);
    return LockScreenTimerContent(
      sessionId: session.clientUuid,
      isPaused: !session.isRunning,
      categoryName: category,
      endsAt: endsAt,
      rangeStart: endsAt.subtract(Duration(seconds: total)),
      remainingSeconds: remaining,
      totalSeconds: total,
      expiresIn: expiresIn,
      title: category,
      body: session.isRunning
          ? l10n.lockTimerRunningBody(formatClockTime(endsAt))
          : l10n.lockTimerPausedBody(formatRemaining(remaining)),
      channelName: l10n.lockTimerChannelName,
      channelDescription: l10n.lockTimerChannelDescription,
      runningLabel: l10n.lockTimerStatusRunning,
      pausedLabel: l10n.lockTimerStatusPaused,
      finishedLabel: l10n.lockTimerStatusDone,
      finishedHint: l10n.lockTimerDoneHint,
    );
  }

  /// Kalan süre: sayaç ekranındaki gibi "MM:SS" (bir saati aşarsa "S:MM:SS").
  static String formatRemaining(int seconds) {
    final s = math.max(0, seconds);
    final hours = s ~/ 3600;
    final minutes = (s % 3600) ~/ 60;
    final secs = s % 60;
    return hours > 0 ? '$hours:${_two(minutes)}:${_two(secs)}' : '${_two(minutes)}:${_two(secs)}';
  }

  /// Saat: "HH:mm" (yerel saat).
  static String formatClockTime(DateTime time) {
    final local = time.toLocal();
    return '${_two(local.hour)}:${_two(local.minute)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
