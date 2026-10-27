import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app/session_feedback.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../utils/category_names.dart';
import '../utils/color_hex.dart';
import '../utils/responsive.dart';
import '../models/category_model.dart';
import '../models/marathon_progress.dart';
import '../widgets/hourglass_widget.dart';
import '../widgets/marathon_progress_card.dart';
import '../widgets/marathon_plan_dialog.dart';
import '../widgets/marathon_break_indicator.dart';
import '../services/language_service.dart';
import '../services/lock_screen_timer.dart';
import '../services/notification_service.dart';
import '../services/session_queue.dart';
import '../services/timer_persistence.dart';
import 'rejected_sessions_screen.dart';

/// Sayaç diyalogları geniş ekranda tam genişliğe yayılmaz.
const BoxConstraints kTimerDialogConstraints = BoxConstraints(
  minWidth: 280,
  maxWidth: 440,
);

class TimerScreen extends StatefulWidget {
  final List<CourseCategory> categories;

  /// Süren seansın cihazda saklandığı anahtar (kullanıcı kimliği).
  final String sessionOwnerKey;

  /// Kimlik bilinmeden önce kullanılmış anahtar (e-posta); oradaki kayıt taşınır.
  final String? legacySessionOwnerKey;
  final VoidCallback onOpenSettings;

  /// Süre dolunca çağrılır; seans gönderilince sunucunun sonucuyla
  /// tamamlanır (null: sonuç bilinmiyor). Sonuç seans sonu diyaloğunda
  /// gösterilir, ardından cihazdaki seans kaydı silinir.
  final Future<SessionSubmitResult?> Function(ActiveTimerSession session)
  onSessionCompleted;

  /// Sayaç başlayınca/devam edince (kalan dakikayla) ve durunca çağrılır.
  final void Function(bool isRunning, String categoryName, int minutesLeft)?
  onTimerStateChanged;

  /// Molalar odak RPC'sine/seans kaydına gönderilmez. Kabuk sosyal mola
  /// durumunu ayrı yönetir; bitişte/iptalde false gönderilir.
  final void Function(bool isOnBreak, int secondsLeft)? onMarathonBreakChanged;

  /// Kayıtlı Maraton için kullanıcı onayının sunucudan kabulü. UUID yalnız
  /// dokunma anında üretilir; aynı pencere içindeki retry onu korur.
  final Future<bool> Function(
    ActiveTimerSession previous,
    String nextClientUuid,
  )?
  onConfirmMarathonPresence;

  /// Kabuk sunucudaki Maraton desteğini salt okunarak doğrular. Yarım
  /// planlar bu bayrak değişse de kurtarılır; yeni planlar kapalıdır.
  final bool marathonAvailable;
  final Map<int, Map<int, int>>? marathonBonuses;

  /// Oturum kapanışı başlamış olabilir; native çıkış sürerken ekran henüz
  /// mounted olsa da yeni sayaç, alarm veya RPC başlatılmaz.
  final bool Function()? isSessionActive;
  final String? userSegment;

  /// Kilit ekranı sayacı (varsayılan: [LockScreenTimer.instance]; testte sahtesi).
  final LockScreenTimer? lockScreenTimer;

  /// Birim/widget testlerinde açıkça verilen kısa sayaç simülasyonu.
  /// Varsayılan her derlemede gerçek süredir; kısa seans kaydedilmez.
  @visibleForTesting
  final bool quickTimer;

  /// Saat kaynağı (testte sahtesi). Varsayılan [DateTime.now].
  @visibleForTesting
  final DateTime Function()? clock;

  const TimerScreen({
    super.key,
    required this.categories,
    required this.sessionOwnerKey,
    this.legacySessionOwnerKey,
    required this.onOpenSettings,
    required this.onSessionCompleted,
    this.onTimerStateChanged,
    this.onMarathonBreakChanged,
    this.onConfirmMarathonPresence,
    this.marathonAvailable = true,
    this.marathonBonuses,
    this.isSessionActive,
    this.userSegment,
    this.lockScreenTimer,
    this.quickTimer = false,
    this.clock,
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  static const int _maxPauses = 1;

  /// 25/50 seçim satırının en büyük genişliği (tablette de kompakt kalır).
  static const double _durationRowMaxWidth = 320;

  int loggedMinutes = 25;
  late int totalSeconds = timerDurationSeconds(
    loggedMinutes,
    quick: widget.quickTimer,
  );
  late int remaining = totalSeconds;
  bool isRunning = false;
  bool _isStarting = false; // BAŞLAT butonuna çift tıklama koruması
  Timer? _timer;
  String selectedCategoryId = '';
  String selectedCategoryName = '';

  // Süren ya da duraklatılmış seans (null: seans yok). Başlat, duraklat ve
  // devamda cihaza yazılır; uygulama öldürülse bile açılışta geri yüklenir.
  // Kalan süre her tick'te bitiş anından hesaplanır.
  ActiveTimerSession? _session;
  int _foregroundSeconds = 0;
  int _marathonCount = 0;
  int _lastPlannedMarathonCount = 2;
  bool _planningMarathon = false;
  final ValueNotifier<int> _marathonDialogRevision = ValueNotifier(0);
  DialogRoute<void>? _marathonProgressRoute;
  String? _completingUuid;
  bool _completionFailed = false;
  bool _confirmingDiscard = false;
  bool _persistingMarathonStart = false;
  bool _transitioningPresence = false;
  bool _expiringPresence = false;
  String? _presenceCandidateUuid;
  bool _presenceRequestFailed = false;
  MarathonProgress? _lastMarathonForDisplay;
  bool _lastMarathonTimedOut = false;
  bool _lastMarathonRejected = false;
  bool _lastMarathonValidationFailed = false;

  bool get _hasSession => _session != null;
  MarathonProgress? get _marathon => _session?.marathon;
  bool get _isBreak => _marathon?.isOnBreak ?? false;
  bool get _isAwaitingPresence => _marathon?.isAwaitingPresence ?? false;
  bool get _isResting => _marathon?.isResting ?? false;
  bool get _isCompleting =>
      _marathon?.phase == MarathonPhase.completing ||
      (_marathon?.isFinished ?? false);

  int get _pauseCreditsLeft => _maxPauses - (_session?.pauseUsedCount ?? 0);
  TimerPersistence get _store => TimerPersistence.instance;
  LockScreenTimer get _lockScreen =>
      widget.lockScreenTimer ?? LockScreenTimer.instance;
  bool get _sessionIsActive => widget.isSessionActive?.call() ?? true;

  static bool get _isInForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  static int _minutesLeft(int seconds) => (seconds / 60).ceil();

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _validateSelectedCategory();
    unawaited(_restoreSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _dismissMarathonProgress();
    _marathonDialogRevision.dispose();
    // Seans cihazda saklı olduğu için ekran kapanınca (ör. çıkış) iptal
    // edilmez; aynı hesapla açılınca kaldığı yerden sürer. Kilit ekranından
    // ise kalkar (kabuk yalnızca çıkışta ya da hesap değişince kapanır).
    _persistSession();
    unawaited(NotificationService.instance.cancelSessionEndNotification());
    unawaited(NotificationService.instance.cancelMarathonBreakEnd());
    unawaited(_lockScreen.clear());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Arka planda periyodik timer durmuş olabilir; kalan süreyi bitiş
      // anından yeniden hesapla (süre dolduysa seans tamamlanır).
      if (_isResting) {
        _tickBreak(forceSocial: true);
      } else if (isRunning) {
        _tick(countForeground: false);
      }
      // Uygulama açıkken duraklatılmış seans artık 24 saat içinde
      // bitirilemiyorsa (sunucu too_old ile reddeder) şimdi bırakılır.
      if (_expireStalePausedSession()) return;
      // Kullanıcı kilit ekranı bildirimini kapatmış ya da sistem Canlı
      // Etkinliği bitirmiş olabilir: süren seans yeniden gösterilir.
      if (_hasSession && !_isResting && !_isCompleting) {
        _syncLockScreen(force: true);
      }
    } else if (state == AppLifecycleState.paused) {
      _persistSession();
    }
  }

  @override
  void didUpdateWidget(TimerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionOwnerKey != widget.sessionOwnerKey) {
      // Sahip değişimi eski planı yeni hesaba taşımaz. Shell normalde UID
      // anahtarıyla ekranı değiştirir; yeniden kullanılan ekran da güvenlidir.
      final oldSession = _session;
      if (oldSession != null && _completingUuid != oldSession.clientUuid) {
        _persistSpecificSession(
          oldWidget.sessionOwnerKey,
          oldSession,
          _foregroundSeconds,
        );
      }
      _timer?.cancel();
      unawaited(NotificationService.instance.cancelSessionEndNotification());
      unawaited(NotificationService.instance.cancelMarathonBreakEnd());
      unawaited(_lockScreen.clear());
      _session = null;
      _foregroundSeconds = 0;
      _marathonCount = 0;
      _lastPlannedMarathonCount = 2;
      _planningMarathon = false;
      _dismissMarathonProgress();
      _completionFailed = false;
      _persistingMarathonStart = false;
      _transitioningPresence = false;
      _expiringPresence = false;
      _presenceCandidateUuid = null;
      _presenceRequestFailed = false;
      _lastMarathonForDisplay = null;
      _lastMarathonTimedOut = false;
      _lastMarathonRejected = false;
      _lastMarathonValidationFailed = false;
      isRunning = false;
      _isStarting = false;
      totalSeconds = timerDurationSeconds(
        loggedMinutes,
        quick: widget.quickTimer,
      );
      remaining = totalSeconds;
      unawaited(_restoreSession());
    }
    _validateSelectedCategory();
  }

  /// Kilit ekranı sayacını (Android kalıcı bildirim, iPhone Canlı Etkinlik)
  /// mevcut seansla eşitler; seans yoksa kaldırır.
  void _syncLockScreen({bool force = false}) {
    final session = _session;
    unawaited(
      session == null || _isResting || _isCompleting || !_sessionIsActive
          ? _lockScreen.clear()
          : _lockScreen.show(session, force: force),
    );
  }

  void _persistSession() {
    final session = _session;
    if (session == null || _completingUuid == session.clientUuid) return;
    _persistSpecificSession(
      widget.sessionOwnerKey,
      session,
      _foregroundSeconds,
    );
  }

  void _persistSpecificSession(
    String owner,
    ActiveTimerSession session,
    int foregroundSeconds,
  ) {
    final plan = session.marathon;
    if (plan == null) {
      unawaited(
        _store.save(owner, session.withForegroundSeconds(foregroundSeconds)),
      );
      return;
    }
    // Dispose/ön plan kaydı da bir geçiştir. Eski ekran daha yeni fazı
    // ezemez; durma isteği ve duraklatma kullanımı geriye alınamaz.
    unawaited(
      _store.compareAndUpdateMarathon(
        owner,
        clientUuid: session.clientUuid,
        completedSessions: plan.completedSessions,
        phases: {plan.phase},
        update: (stored) {
          if (stored.pauseUsedCount > session.pauseUsedCount) return stored;
          if (stored.pauseUsedCount == session.pauseUsedCount &&
              ((stored.isRunning && !session.isRunning) ||
                  (stored.endsAt != null &&
                      session.endsAt != null &&
                      stored.endsAt!.isAfter(session.endsAt!)))) {
            return stored;
          }
          var nextPlan = stored.marathon!.stopRequested
              ? plan.withStopRequested()
              : plan;
          if (stored.marathon!.presenceClientUuid != null) {
            nextPlan = nextPlan.withPresenceCandidate(
              stored.marathon!.presenceClientUuid!,
            );
          }
          return session
              .withMarathon(nextPlan)
              .withForegroundSeconds(
                math.max(foregroundSeconds, stored.foregroundSeconds),
              );
        },
      ),
    );
  }

  Future<void> _restoreSession() async {
    final owner = widget.sessionOwnerKey;
    final saved = await _store.load(
      owner,
      legacyOwnerKey: widget.legacySessionOwnerKey,
    );
    if (!mounted ||
        owner != widget.sessionOwnerKey ||
        _hasSession ||
        _isStarting) {
      return;
    }
    await _restoreSavedSession(saved, owner);
  }

  Future<void> _restoreSavedSession(
    ActiveTimerSession? saved,
    String owner,
  ) async {
    if (!_sameOwner(owner)) return;
    _timer?.cancel();
    if (saved == null) {
      // Bu hesabın süren seansı yok: önceki süreçten kalmış kilit ekranı
      // sayacı varsa kaldırılır.
      unawaited(_lockScreen.clear());
      _resetToIdle();
      return;
    }

    // Eski kayıtlı QA seansı gerçek odak/mola/onay olarak geri yüklenemez.
    // İşaret diskte korunur; normal süreli seansa dönüştürülmez.
    if (saved.recordAccelerated) {
      await _store.clear(owner, onlyClientUuid: saved.clientUuid);
      if (!_sameOwner(owner) || _hasSession || _isStarting) return;
      unawaited(NotificationService.instance.cancelSessionEndNotification());
      unawaited(NotificationService.instance.cancelMarathonBreakEnd());
      unawaited(_lockScreen.clear());
      _resetToIdle();
      return;
    }

    final now = _now();
    _foregroundSeconds = saved.foregroundSeconds;
    setState(() {
      loggedMinutes = saved.durationMinutes;
      totalSeconds = saved.totalSeconds;
      selectedCategoryId = saved.categoryId;
      selectedCategoryName = saved.categoryName;
      _marathonCount = saved.marathon?.totalSessions ?? 0;
      _lastPlannedMarathonCount =
          saved.marathon?.totalSessions ?? _lastPlannedMarathonCount;
      _session = saved;
      _lastMarathonForDisplay = null;
      _lastMarathonTimedOut = false;
      _lastMarathonRejected = false;
      _lastMarathonValidationFailed = false;
    });

    if (saved.marathon?.isFinished ?? false) {
      await _store.clear(owner, onlyClientUuid: saved.clientUuid);
      if (!_sameOwner(owner)) return;
      _resetToIdle();
      _showMarathonCompletedDialog(
        saved.marathon!,
        saved.durationMinutes,
        testOnly: saved.isQuickTest,
      );
      return;
    }
    if ((saved.marathon?.stopRequested ?? false) &&
        saved.marathon?.phase != MarathonPhase.completing) {
      await _store.clear(owner, onlyClientUuid: saved.clientUuid);
      if (!_sameOwner(owner)) return;
      _resetToIdle();
      return;
    }
    if (saved.marathon?.isResting ?? false) {
      _runBreak(saved, restore: true);
      return;
    }
    if (saved.marathon?.phase == MarathonPhase.completing) {
      unawaited(_completeSession(saved));
      return;
    }

    if (saved.isRunning) {
      if (saved.isFinishedAt(now)) {
        // Uygulama kapalıyken süre doldu: seans hemen tamamlanıp gönderilir.
        unawaited(_completeSession(saved));
      } else {
        _runSession(saved, now, persist: false);
      }
    } else if (saved.isAbandonedAt(now)) {
      _dropExpiredPausedSession(saved);
    } else {
      setState(() {
        _session = saved;
        remaining = saved.remainingSecondsAt(now);
      });
      unawaited(_lockScreen.showPaused(saved));
    }
  }

  /// Sunucu başlangıcı 24 saatten eski seansı kabul etmez (too_old).
  /// Duraklatılmış seans devam ettirilse bile o süre içinde bitemeyecekse
  /// kayıt silinir ve kullanıcı uyarılır (açılışta, devamda ve ön plana
  /// dönüşte). Seans yoksa ya da sürüyorsa bir şey yapmaz; bıraktıysa true.
  bool _expireStalePausedSession() {
    final session = _session;
    if (session == null ||
        _isResting ||
        _isCompleting ||
        isRunning ||
        !session.isAbandonedAt(_now())) {
      return false;
    }
    _timer?.cancel();
    unawaited(NotificationService.instance.cancelSessionEndNotification());
    _resetToIdle();
    _dropExpiredPausedSession(session);
    return true;
  }

  void _dropExpiredPausedSession(ActiveTimerSession session) {
    unawaited(
      _store.clear(widget.sessionOwnerKey, onlyClientUuid: session.clientUuid),
    );
    unawaited(_lockScreen.clear());
    _foregroundSeconds = 0;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pausedSessionExpired),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _tick({bool countForeground = true}) {
    final session = _session;
    if (!isRunning || session == null || !mounted || !_sessionIsActive) return;
    final left = session.remainingSecondsAt(_now());
    if (left > 0) {
      // Android'de süreç arka planda da tick atabilir; yalnızca ön plan sayılır.
      if (countForeground && _isInForeground) _foregroundSeconds++;
      setState(() => remaining = left);
    } else {
      unawaited(_completeSession(session));
    }
  }

  /// Süre dolduğunda seansı kapatır, sonucu üst bileşene bildirir ve
  /// gönderim bitince cihazdaki kaydı siler.
  Future<void> _completeSession(ActiveTimerSession session) async {
    if (_completingUuid == session.clientUuid) return;
    _completingUuid = session.clientUuid;
    _timer?.cancel();
    final completed = session.withForegroundSeconds(_foregroundSeconds);
    final owner = widget.sessionOwnerKey;
    if (completed.marathon != null) {
      try {
        await _completeMarathonFocus(completed, owner);
      } finally {
        if (_completingUuid == completed.clientUuid) _completingUuid = null;
      }
      return;
    }
    unawaited(_lockScreen.clear());
    if (_isInForeground) {
      // Sistem bitiş bildirimi kaldırılır. Bitiş kullanıcıya kısa titreşimle (bildirimler
      // açıksa bildirim sesiyle de) duyurulur.
      unawaited(NotificationService.instance.cancelSessionEndNotification());
      unawaited(NotificationService.instance.alertSessionEndInForeground());
    } else {
      // Android'de süreç arka planda yaşıyorsa seans burada biter; alarmın
      // gecikmesini beklemeden bildirim hemen gösterilir.
      unawaited(
        NotificationService.instance.showSessionEndNow(
          categoryName: completed.categoryName,
        ),
      );
    }

    _resetToIdle();
    widget.onTimerStateChanged?.call(false, completed.categoryName, 0);

    if (completed.isQuickTest) {
      // Hızlı test seansı sunucuya ve kuyruğa gönderilmez (sunucu kısa
      // seansı zaten reddeder).
      _showSessionCompletedDialog(
        completed.durationMinutes,
        null,
        testSession: true,
      );
      await _store.clear(owner, onlyClientUuid: completed.clientUuid);
      if (_completingUuid == completed.clientUuid) _completingUuid = null;
      return;
    }
    // Diyalog gönderimin sonucunu bekler: kaydediliyor → puan/kum/seri,
    // kuyruk ya da ret nedeni.
    final submission = widget.onSessionCompleted(completed);
    _showSessionCompletedDialog(completed.durationMinutes, submission);
    try {
      await submission;
      await _store.clear(owner, onlyClientUuid: completed.clientUuid);
    } catch (e) {
      // Kayıt silinmez: sonraki açılışta süresi dolmuş seans olarak yeniden gönderilir.
      debugPrint('[TIMER] Seans gönderimi tamamlanamadı: $e');
    } finally {
      if (_completingUuid == completed.clientUuid) _completingUuid = null;
    }
  }

  bool _sameOwner(String owner) =>
      mounted && widget.sessionOwnerKey == owner && _sessionIsActive;

  Future<void> _completeMarathonFocus(
    ActiveTimerSession completed,
    String owner,
  ) async {
    final submit = widget.onSessionCompleted;
    final completing = completed.withMarathon(
      completed.marathon!.beginCompletion(),
    );
    if (_sameOwner(owner)) {
      setState(() {
        _session = completing;
        isRunning = false;
        _completionFailed = false;
        remaining = 0;
      });
      widget.onTimerStateChanged?.call(false, completed.categoryName, 0);
    }
    unawaited(_lockScreen.clear());
    if (_isInForeground) {
      unawaited(NotificationService.instance.cancelSessionEndNotification());
      unawaited(NotificationService.instance.alertSessionEndInForeground());
    } else {
      unawaited(
        NotificationService.instance.showSessionEndNow(
          categoryName: completed.categoryName,
        ),
      );
    }

    // Yazmadan gönderme: süreç kesilirse aynı UUID ile yeniden denenecek.
    final claimed = await _store.compareAndUpdateMarathon(
      owner,
      clientUuid: completing.clientUuid,
      completedSessions: completing.marathon!.completedSessions,
      phases: const {MarathonPhase.focus, MarathonPhase.completing},
      update: (stored) =>
          completing.withMarathon(stored.marathon!.beginCompletion()),
    );
    if (claimed == null) {
      await _handleMarathonWriteFailure(
        owner,
        completing.clientUuid,
        phases: const {MarathonPhase.focus, MarathonPhase.completing},
      );
      return;
    }
    // Sahip/ekran ilk diske yazma sırasında değişmiş olabilir. Eski
    // seans yeni hesabın callback'ine teslim edilmez; eski hesap geri
    // açıldığında completing kaydından güvenle gönderilir.
    if (!_sameOwner(owner)) return;
    SessionSubmitResult? result;
    final testOnly = completing.isQuickTest;
    if (!testOnly) {
      try {
        result = await submit(claimed);
      } catch (error) {
        debugPrint('[MARATHON] Odak kaydı tamamlanamadı: $error');
        _marathonCompletionFailed(owner);
        return;
      }
      if (result == null) {
        _marathonCompletionFailed(owner);
        return;
      }
    }

    final needsBreak =
        completing.marathon!.sessionIndex < completing.marathon!.totalSessions;
    final receiptEnd = result is SessionSubmitSuccess
        ? result.marathonBreakEndsAt
        : null;
    final receiptDeadline = result is SessionSubmitSuccess
        ? result.marathonConfirmationDeadline
        : null;
    final receiptInvalid =
        !testOnly &&
        result is SessionSubmitSuccess &&
        needsBreak &&
        (receiptEnd == null ||
            receiptDeadline == null ||
            receiptDeadline !=
                receiptEnd.add(
                  const Duration(
                    seconds: MarathonProgress.presenceWindowSeconds,
                  ),
                ));
    if (result is SessionSubmitRejected ||
        (result is SessionSubmitSuccess &&
            (result.marathonInvalid || receiptInvalid))) {
      // Ret geçmişi veri katmanında saklanır; yeni seans başlatıp hatayı
      // zincir boyunca çoğaltma. Tamamlanan önceki odaklar korunur.
      final stopped = await _store.compareAndUpdateMarathon(
        owner,
        clientUuid: completing.clientUuid,
        completedSessions: completing.marathon!.completedSessions,
        phases: const {MarathonPhase.completing},
        update: (stored) {
          var stoppedPlan = stored.marathon!;
          if (result is SessionSubmitSuccess) {
            stoppedPlan = stoppedPlan.finishFocus(stored.endsAt ?? _now());
          }
          return stored.withMarathon(stoppedPlan.withStopRequested());
        },
      );
      if (stopped == null) {
        await _handleMarathonWriteFailure(
          owner,
          completing.clientUuid,
          phases: const {MarathonPhase.completing},
        );
        return;
      }
      await _store.clear(owner, onlyClientUuid: stopped.clientUuid);
      if (!_sameOwner(owner)) return;
      _lastMarathonForDisplay = stopped.marathon;
      _lastMarathonTimedOut = false;
      _lastMarathonRejected = true;
      _lastMarathonValidationFailed = result is SessionSubmitSuccess;
      _resetToIdle();
      if (!mounted) return;
      _showMarathonFeedback(
        result is SessionSubmitSuccess
            ? AppLocalizations.of(context)!.marathonStoppedInvalid
            : AppLocalizations.of(context)!.marathonStoppedRejected,
      );
      return;
    }

    // Geç açılış / yavaş bağlantı mola veya onay penceresini uzatmaz.
    // Yeni odak yalnız kullanıcı onayı ve sunucu kabulünden sonra başlar.
    final next = await _store.compareAndUpdateMarathon(
      owner,
      clientUuid: completing.clientUuid,
      completedSessions: completing.marathon!.completedSessions,
      phases: const {MarathonPhase.completing},
      update: (stored) {
        // Başarılı sunucu yanıtındaki pencere ilk kabulde oluşturulur;
        // duplicate de aynı pencereyi verir. Kuyruk halinde gerçek odak
        // bitişi kullanılır; sonradan senkron pencereyi yeniden başlatmaz.
        final focusEnd =
            result is SessionSubmitSuccess && needsBreak && receiptEnd != null
            ? receiptEnd.subtract(
                Duration(seconds: stored.marathon!.breakSeconds),
              )
            : stored.endsAt ?? _now();
        var progress = stored.marathon!.finishFocus(focusEnd);
        if (progress.isFinished) {
          progress = progress.withBonusResult(
            points: result is SessionSubmitSuccess
                ? result.marathonBonusPoints
                : 0,
            pending: result is SessionSubmitQueued,
          );
        }
        return stored.withMarathon(progress);
      },
    );
    if (next == null) {
      // Eski completing kaydı hâlâ durur. Retry aynı UUID'yi gönderir;
      // sunucu/outbox idempotency sayesinde yeniden ödül verilmez.
      await _handleMarathonWriteFailure(
        owner,
        completing.clientUuid,
        phases: const {MarathonPhase.completing},
      );
      return;
    }
    if (next.marathon!.stopRequested && !next.marathon!.isFinished) {
      await _store.clear(owner, onlyClientUuid: next.clientUuid);
      if (!_sameOwner(owner)) return;
      _resetToIdle();
      _showMarathonSessionFeedback(result, testOnly: testOnly);
      return;
    }
    if (!_sameOwner(owner)) return;
    setState(() => _session = next);
    _showMarathonSessionFeedback(result, testOnly: testOnly);
    if (next.marathon!.isFinished) {
      await _store.clear(owner, onlyClientUuid: next.clientUuid);
      if (!_sameOwner(owner)) return;
      _resetToIdle();
      _showMarathonCompletedDialog(
        next.marathon!,
        next.durationMinutes,
        testOnly: testOnly,
      );
    } else {
      _runBreak(next);
    }
  }

  Future<void> _handleMarathonWriteFailure(
    String owner,
    String uuid, {
    required Set<MarathonPhase> phases,
  }) async {
    if (!_sameOwner(owner)) return;
    final current = await _store.load(owner);
    if (!_sameOwner(owner)) return;
    if (current?.clientUuid == uuid &&
        phases.contains(current?.marathon?.phase)) {
      _marathonCompletionFailed(owner);
      return;
    }
    await _restoreSavedSession(current, owner);
  }

  void _marathonCompletionFailed(String owner) {
    if (!_sameOwner(owner)) return;
    setState(() => _completionFailed = true);
    _showMarathonFeedback(AppLocalizations.of(context)!.marathonSaveFailed);
  }

  void _showMarathonFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  void _showMarathonSessionFeedback(
    SessionSubmitResult? result, {
    required bool testOnly,
  }) {
    if (testOnly) return;
    final l10n = AppLocalizations.of(context)!;
    _showMarathonFeedback(switch (result) {
      SessionSubmitQueued(:final reasonCode) => sessionQueuedMessage(
        l10n,
        reasonCode,
      ),
      SessionSubmitSuccess(:final totalPoints) =>
        totalPoints > 0
            ? l10n.sessionResultPoints(totalPoints)
            : l10n.sessionCompletedBody(loggedMinutes),
      _ => l10n.sessionResultDuplicate,
    });
  }

  void _runBreak(ActiveTimerSession session, {bool restore = false}) {
    _timer?.cancel();
    final plan = session.marathon!;
    final left = plan.isAwaitingPresence
        ? plan.presenceRemainingAt(_now())
        : plan.breakRemainingAt(_now());
    setState(() {
      _session = session;
      isRunning = false;
      _isStarting = false;
      _completionFailed = false;
      totalSeconds = plan.isAwaitingPresence
          ? MarathonProgress.presenceWindowSeconds
          : plan.breakSeconds;
      remaining = left;
      _foregroundSeconds = 0;
      _presenceCandidateUuid = plan.presenceClientUuid;
    });
    unawaited(_lockScreen.clear());
    widget.onMarathonBreakChanged?.call(
      plan.isOnBreak && left > 0,
      plan.isOnBreak ? left : 0,
    );
    if (plan.isOnBreak && left > 0) {
      unawaited(
        NotificationService.instance.scheduleMarathonBreakEnd(
          seconds: left,
          nextSession: plan.currentSession,
          totalSessions: plan.totalSessions,
        ),
      );
    } else {
      unawaited(NotificationService.instance.cancelMarathonBreakEnd());
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tickBreak());
    if (restore || left == 0) _tickBreak();
  }

  void _tickBreak({bool forceSocial = false}) {
    final plan = _marathon;
    if (!mounted ||
        !_sessionIsActive ||
        plan == null ||
        !plan.isResting ||
        _expiringPresence) {
      return;
    }
    final now = _now();
    // Bir RPC/disk yazısı veya Durdur diyaloğu süre sınırını donduramaz.
    if (plan.isPresenceExpiredAt(now)) {
      unawaited(_expireMarathonPresence());
      return;
    }
    final left = plan.isAwaitingPresence
        ? plan.presenceRemainingAt(now)
        : plan.breakRemainingAt(now);
    if (left != remaining) setState(() => remaining = left);
    if (forceSocial) {
      widget.onMarathonBreakChanged?.call(
        plan.isOnBreak && left > 0,
        plan.isOnBreak ? left : 0,
      );
    }
    if (!plan.isOnBreak || left > 0 || _transitioningPresence) return;
    _transitioningPresence = true;
    unawaited(_beginMarathonPresenceCheck());
  }

  Future<void> _beginMarathonPresenceCheck() async {
    final previous = _session;
    final owner = widget.sessionOwnerKey;
    final plan = previous?.marathon;
    if (previous == null || plan == null || !plan.isOnBreak) return;
    final next = await _store.compareAndUpdateMarathon(
      owner,
      clientUuid: previous.clientUuid,
      completedSessions: plan.completedSessions,
      phases: const {MarathonPhase.breakTime},
      update: (stored) =>
          stored.withMarathon(stored.marathon!.beginPresenceCheck()),
      canCommit: () =>
          _sameOwner(owner) &&
          _session?.clientUuid == previous.clientUuid &&
          _isBreak,
    );
    if (!_sameOwner(owner) || _session?.clientUuid != previous.clientUuid) {
      return;
    }
    _transitioningPresence = false;
    if (next == null) {
      await _handleMarathonWriteFailure(
        owner,
        previous.clientUuid,
        phases: const {MarathonPhase.breakTime},
      );
      return;
    }
    _presenceCandidateUuid = null;
    _presenceRequestFailed = false;
    _runBreak(next);
    // Onay yalnız kullanıcı dokunmasıyla yapılır; restore/tick/lifecycle
    // hiçbir zaman yeni odak UUID'si veya çalışma başlangıcı üretmez.
    _tickBreak();
  }

  Future<void> _expireMarathonPresence() async {
    final previous = _session;
    final owner = widget.sessionOwnerKey;
    final plan = previous?.marathon;
    if (previous == null ||
        plan == null ||
        !plan.isResting ||
        _expiringPresence) {
      return;
    }
    _expiringPresence = true;
    _timer?.cancel();
    final stopped = await _store.compareAndUpdateMarathon(
      owner,
      clientUuid: previous.clientUuid,
      completedSessions: plan.completedSessions,
      phases: const {MarathonPhase.breakTime, MarathonPhase.awaitingPresence},
      update: (stored) =>
          stored.withMarathon(stored.marathon!.withStopRequested()),
    );
    if (stopped != null) {
      // Burada yalnız aktif plan taşıyıcısı temizlenir. Önceki tamamlanan
      // seanslar ve güvenli outbox kayıtları aynen tutulur.
      await _store.clearMarathon(owner, marathonUuid: plan.marathonUuid);
    }
    if (!_sameOwner(owner) || _marathon?.marathonUuid != plan.marathonUuid) {
      return;
    }
    _expiringPresence = false;
    if (stopped == null) {
      await _handleMarathonWriteFailure(
        owner,
        previous.clientUuid,
        phases: const {MarathonPhase.breakTime, MarathonPhase.awaitingPresence},
      );
      return;
    }
    unawaited(NotificationService.instance.cancelMarathonBreakEnd());
    unawaited(_lockScreen.clear());
    widget.onMarathonBreakChanged?.call(false, 0);
    widget.onTimerStateChanged?.call(false, previous.categoryName, 0);
    _lastMarathonForDisplay = plan;
    _lastMarathonTimedOut = true;
    _lastMarathonRejected = false;
    _lastMarathonValidationFailed = false;
    _resetToIdle();
    if (!mounted) return;
    _showMarathonFeedback(
      AppLocalizations.of(context)!.marathonPresenceExpired,
    );
  }

  Future<void> _confirmMarathonPresence() async {
    final previous = _session;
    final owner = widget.sessionOwnerKey;
    final plan = previous?.marathon;
    if (previous == null ||
        plan == null ||
        !plan.canConfirmPresenceAt(_now()) ||
        !_sameOwner(owner) ||
        !_isInForeground ||
        _isStarting ||
        _confirmingDiscard ||
        _expiringPresence) {
      _tickBreak();
      return;
    }
    var nextUuid =
        plan.presenceClientUuid ?? _presenceCandidateUuid ?? const Uuid().v4();
    _presenceCandidateUuid = nextUuid;
    setState(() {
      _isStarting = true;
      _presenceRequestFailed = false;
    });
    bool canStartNext() =>
        _sameOwner(owner) &&
        _isInForeground &&
        !_confirmingDiscard &&
        !_expiringPresence &&
        _session?.clientUuid == previous.clientUuid &&
        _isAwaitingPresence &&
        (_marathon?.canConfirmPresenceAt(_now()) ?? false);
    final candidateRecord = await _store.compareAndUpdateMarathon(
      owner,
      clientUuid: previous.clientUuid,
      completedSessions: plan.completedSessions,
      phases: const {MarathonPhase.awaitingPresence},
      update: (stored) => stored.marathon!.presenceClientUuid == null
          ? stored.withMarathon(
              stored.marathon!.withPresenceCandidate(nextUuid),
            )
          : stored,
      canCommit: canStartNext,
    );
    if (candidateRecord == null || !canStartNext()) {
      if (_sameOwner(owner) &&
          _session?.clientUuid == previous.clientUuid &&
          _isResting) {
        setState(() => _isStarting = false);
        if (_marathon?.isPresenceExpiredAt(_now()) ?? false) {
          _tickBreak();
        } else {
          await _handleMarathonWriteFailure(
            owner,
            previous.clientUuid,
            phases: const {MarathonPhase.awaitingPresence},
          );
        }
      }
      return;
    }
    nextUuid = candidateRecord.marathon!.presenceClientUuid!;
    _presenceCandidateUuid = nextUuid;
    setState(() => _session = candidateRecord);
    final testOnly = previous.isQuickTest;
    await NotificationService.instance.cancelMarathonBreakEnd();
    if (!canStartNext()) {
      if (_sameOwner(owner) &&
          _session?.clientUuid == previous.clientUuid &&
          _isResting) {
        setState(() => _isStarting = false);
        _tickBreak();
      }
      return;
    }
    var accepted = testOnly;
    if (!testOnly) {
      try {
        accepted =
            await widget.onConfirmMarathonPresence?.call(
              candidateRecord,
              nextUuid,
            ) ??
            false;
      } catch (error) {
        debugPrint('[MARATHON] Devam onayı kabul edilemedi: $error');
        accepted = false;
      }
    }
    if (!canStartNext()) {
      if (_sameOwner(owner) &&
          _session?.clientUuid == previous.clientUuid &&
          _isResting) {
        setState(() => _isStarting = false);
        _tickBreak();
      }
      return;
    }
    if (!accepted) {
      setState(() {
        _isStarting = false;
        _presenceRequestFailed = true;
      });
      if (!mounted) return;
      _showMarathonFeedback(
        AppLocalizations.of(context)!.marathonPresenceConnectionNeeded,
      );
      return;
    }
    // Sunucu ACK öncesine tarihlenmiş odak oluşturulmaz. UUID aynı
    // penceredeki retry'larda sabit; başlangıç yalnız şimdi verilir.
    final now = _now();
    final next = ActiveTimerSession.start(
      clientUuid: nextUuid,
      categoryId: previous.categoryId,
      categoryName: previous.categoryName,
      categoryColorHex: previous.categoryColorHex,
      durationMinutes: previous.durationMinutes,
      totalSeconds: previous.totalSeconds,
      recordAccelerated: previous.recordAccelerated,
      marathon: plan.nextFocus(),
      now: now,
    );
    bool canCommitStartedFocus() {
      final elapsed = _now().difference(now);
      return canStartNext() &&
          !elapsed.isNegative &&
          elapsed <= const Duration(seconds: 2);
    }

    final storedNext = await _store.compareAndUpdateMarathon(
      owner,
      clientUuid: previous.clientUuid,
      completedSessions: plan.completedSessions,
      phases: const {MarathonPhase.awaitingPresence},
      update: (stored) => stored.marathon!.stopRequested ? stored : next,
      canCommit: canCommitStartedFocus,
    );
    if (storedNext == null) {
      if (_sameOwner(owner) &&
          _session?.clientUuid == previous.clientUuid &&
          _isResting) {
        setState(() => _isStarting = false);
        if (_marathon?.isPresenceExpiredAt(_now()) ?? false) {
          _tickBreak();
        } else if (canStartNext()) {
          await _handleMarathonWriteFailure(
            owner,
            previous.clientUuid,
            phases: const {MarathonPhase.awaitingPresence},
          );
        }
      }
      return;
    }
    if (storedNext.marathon!.stopRequested) {
      if (_sameOwner(owner)) {
        _isStarting = false;
        await _restoreSavedSession(storedNext, owner);
      }
      return;
    }
    if (!canCommitStartedFocus()) {
      // ACK/disk yazısının ardından lifecycle/deadline değiştiyse henüz
      // çalıştırılmamış odak restore edilip tamamlanamaz.
      await _store.compareAndUpdateMarathon(
        owner,
        clientUuid: nextUuid,
        completedSessions: plan.completedSessions,
        phases: const {MarathonPhase.focus},
        update: (_) => previous,
      );
      if (_sameOwner(owner) && _session?.clientUuid == previous.clientUuid) {
        setState(() => _isStarting = false);
        _tickBreak();
      }
      return;
    }
    _presenceCandidateUuid = null;
    _presenceRequestFailed = false;
    widget.onMarathonBreakChanged?.call(false, 0);
    unawaited(NotificationService.instance.cancelMarathonBreakEnd());
    _foregroundSeconds = 0;
    loggedMinutes = next.durationMinutes;
    totalSeconds = next.totalSeconds;
    _runSession(storedNext, now, persist: false);
  }

  void _showMarathonCompletedDialog(
    MarathonProgress plan,
    int minutes, {
    bool testOnly = false,
  }) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('marathon-completed-dialog'),
        scrollable: true,
        constraints: kTimerDialogConstraints,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(l10n.marathonCompletedTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.marathonCompletedBody(
                plan.completedSessions,
                plan.completedSessions * minutes,
              ),
            ),
            if (!testOnly && plan.awardedBonusPoints > 0) ...[
              const SizedBox(height: 12),
              Text(
                l10n.marathonBonusPoints(plan.awardedBonusPoints),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ] else if (!testOnly && plan.bonusPending) ...[
              const SizedBox(height: 12),
              Text(l10n.marathonBonusPending),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('marathon-completed-close'),
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.sessionCompletedOk),
          ),
        ],
      ),
    );
  }

  void _resetToIdle() {
    final plan = _marathon;
    if ((plan?.isFinished ?? false) && !(plan?.stopRequested ?? false)) {
      _lastMarathonForDisplay = plan;
      _lastMarathonTimedOut = false;
      _lastMarathonRejected = false;
      _lastMarathonValidationFailed = false;
    }
    if (_isResting) {
      widget.onMarathonBreakChanged?.call(false, 0);
      unawaited(NotificationService.instance.cancelMarathonBreakEnd());
    }
    _foregroundSeconds = 0;
    setState(() {
      isRunning = false;
      _isStarting = false;
      _session = null;
      _marathonCount = 0;
      _completionFailed = false;
      _transitioningPresence = false;
      _expiringPresence = false;
      _presenceCandidateUuid = null;
      _presenceRequestFailed = false;
      // Geri yüklenen seansın uzunluğu (ör. eski test seansı) sonraki
      // seansa taşınmaz.
      totalSeconds = timerDurationSeconds(
        loggedMinutes,
        quick: widget.quickTimer,
      );
      remaining = totalSeconds;
      _validateSelectedCategory();
    });
  }

  /// Aktif kategorilerde önce kimlikle, yoksa dilden bağımsız adla arar
  /// ('Fizik' = 'Physics'): yer tutucudan sunucu kategorisine geçişte
  /// İngilizce kullanıcının seçimi ilk kategoriye atlamaz.
  CourseCategory? _resolveCategory(String id, String name) {
    final active = widget.categories.where((c) => !c.isArchived);
    final byId = active.where((c) => c.id == id).firstOrNull;
    if (byId != null || name.trim().isEmpty) return byId;
    final key = categoryMatchKey(name);
    return active.where((c) => categoryMatchKey(c.name) == key).firstOrNull;
  }

  /// Sayaçta gösterilen kategori. Seans varken seansın kategorisi: aktif
  /// listede yoksa (seans sürerken ya da uygulama kapalıyken arşivlendi)
  /// seans kaydındaki ad ve renkle gösterilir.
  CourseCategory? _displayCategory() {
    final session = _session;
    if (session == null) {
      return _resolveCategory(selectedCategoryId, selectedCategoryName);
    }
    return _resolveCategory(session.categoryId, session.categoryName) ??
        CourseCategory(
          id: session.categoryId,
          name: session.categoryName,
          color: colorFromHex(
            session.categoryColorHex,
            fallback: AppColors.primaryContainer,
          ),
          icon: Icons.book_outlined,
        );
  }

  // Seans sürerken ya da duraklatılmışken seçim KİLİTLİDİR: kategori listesi
  // yenilense bile seans başladığı kategoriyle kaydedilir. Seans yokken
  // seçili kategori listede yoksa (ör. yer tutucudan sunucu kategorisine
  // geçiş) önce aynı isimli kategoriye, yoksa ilk aktif kategoriye geçilir.
  void _validateSelectedCategory() {
    if (_hasSession) return;
    final active = widget.categories.where((c) => !c.isArchived);
    if (active.isEmpty) return;
    final match =
        _resolveCategory(selectedCategoryId, selectedCategoryName) ??
        active.first;
    selectedCategoryId = match.id;
    selectedCategoryName = match.name;
  }

  void _toggleTimer() {
    if (!_sessionIsActive) return;
    if (_isCompleting) {
      if (_completionFailed && _session != null) {
        unawaited(_completeSession(_session!));
      }
      return;
    }
    if (_isAwaitingPresence) {
      if (_completionFailed) setState(() => _completionFailed = false);
      unawaited(_confirmMarathonPresence());
      return;
    }
    if (_isBreak) {
      if (_completionFailed) {
        setState(() => _completionFailed = false);
        _tickBreak();
      }
      return;
    }
    if (isRunning) {
      if (_pauseCreditsLeft > 0) {
        _pause();
      } else {
        _showPauseLimitDialog();
      }
    } else {
      if (_isStarting) return; // çift tıklama koruması
      // Süresi dolmuş duraklatılmış seans için geri sayım başlatılmaz.
      if (_expireStalePausedSession()) return;
      _isStarting = true;
      unawaited(_show321CountdownAndStart());
    }
  }

  void _pause() {
    final session = _session;
    if (session == null) return;
    _timer?.cancel();
    unawaited(NotificationService.instance.cancelSessionEndNotification());
    final now = _now();
    final paused = session.pauseAt(now);
    setState(() {
      _session = paused;
      isRunning = false;
      remaining = paused.remainingSecondsAt(now);
    });
    _persistSession();
    unawaited(_lockScreen.showPaused(paused));
    widget.onTimerStateChanged?.call(
      false,
      paused.categoryName,
      _minutesLeft(remaining),
    );
    ScaffoldMessenger.of(context).clearSnackBars();
    // Yatay odak ekranındaki oynat kontrolünü, özellikle büyük yazıda,
    // alttan gelen bilgilendirme kutusuyla örtme. Durum simgede görünür.
    if (MediaQuery.orientationOf(context) == Orientation.landscape) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                LanguageService.instance.translate('pause_used_snackbar'),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryContainer,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Seansı kaydetmeden bırakır (Sıfırla & Durdur / Sıfırla). [expectedUuid]
  /// verilirse yalnızca o seans hâlâ sürüyorsa bırakılır: onay diyaloğu
  /// açıkken süre dolup seans tamamlandıysa tamamlanan kayıt silinmez.
  void _discardSession({String? expectedUuid}) {
    if (expectedUuid != null && _session?.clientUuid != expectedUuid) return;
    if (_isCompleting || _completingUuid == _session?.clientUuid) return;
    _timer?.cancel();
    unawaited(NotificationService.instance.cancelSessionEndNotification());
    unawaited(NotificationService.instance.cancelMarathonBreakEnd());
    unawaited(_lockScreen.clear());
    widget.onMarathonBreakChanged?.call(false, 0);
    final categoryName = _session?.categoryName ?? selectedCategoryName;
    final planUuid = _marathon?.marathonUuid;
    _resetToIdle();
    unawaited(
      planUuid == null
          ? _store.clear(widget.sessionOwnerKey)
          : _store.clearMarathon(
              widget.sessionOwnerKey,
              marathonUuid: planUuid,
            ),
    );
    widget.onTimerStateChanged?.call(false, categoryName, 0);
  }

  // Süre yalnızca seans yokken seçilir. Seans sürerken ya da
  // duraklatılmışken süre çipleri (kategori çipleri gibi) kilitlidir;
  // seansı bırakmanın tek yolu onaylı "Sıfırla"dır. Eskiden duraklatılmış
  // seans, süre çipine (seçili olana bile) tek dokunuşla onaysız siliniyordu.
  void _selectDuration(int minutes) {
    if (_hasSession || _isStarting) {
      if (minutes != loggedMinutes) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.timerDurationLocked),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
      return;
    }
    if (minutes == loggedMinutes) return;
    setState(() {
      loggedMinutes = minutes;
      _lastMarathonForDisplay = null;
      _lastMarathonTimedOut = false;
      _lastMarathonRejected = false;
      _lastMarathonValidationFailed = false;
      totalSeconds = timerDurationSeconds(minutes, quick: widget.quickTimer);
      remaining = totalSeconds;
      _validateSelectedCategory();
    });
  }

  /// Süren ya da duraklatılmış seansı onayla bırakır.
  Future<void> _confirmDiscardSession() async {
    final target = _session?.clientUuid;
    if (target == null || _confirmingDiscard) return;
    final owner = widget.sessionOwnerKey;
    final plan = _marathon;
    _confirmingDiscard = true;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        constraints: kTimerDialogConstraints,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          plan == null
              ? l10n.timerResetConfirmTitle
              : l10n.marathonStopConfirmTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          plan == null
              ? l10n.timerResetConfirmBody
              : l10n.marathonStopConfirmBody(
                  plan.completedSessions,
                  plan.totalSessions,
                ),
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              plan == null
                  ? l10n.timerResetConfirmAction
                  : l10n.marathonStopConfirmAction,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted || owner != widget.sessionOwnerKey) {
      _confirmingDiscard = false;
      return;
    }
    if (confirmed != true) {
      _confirmingDiscard = false;
      if (_isResting) _tickBreak();
      return;
    }
    if (plan != null &&
        _marathon?.marathonUuid == plan.marathonUuid &&
        _isCompleting &&
        !(_marathon?.isFinished ?? false)) {
      // Onay açıkken odak bitti. Kaydı silmeden önce gönderimi bitir;
      // durma isteği de aynı kayıtta saklanır ve sonraki odak başlamaz.
      final pending = _session!.withMarathon(_marathon!.withStopRequested());
      setState(() => _session = pending);
      final stored = await _store.compareAndUpdateMarathon(
        owner,
        clientUuid: pending.clientUuid,
        completedSessions: pending.marathon!.completedSessions,
        phases: const {MarathonPhase.completing},
        update: (current) =>
            current.withMarathon(current.marathon!.withStopRequested()),
      );
      _confirmingDiscard = false;
      if (stored == null &&
          _sameOwner(owner) &&
          _session?.clientUuid == target &&
          _isResting) {
        _discardSession(expectedUuid: target);
      }
      return;
    }
    _confirmingDiscard = false;
    if (_session?.clientUuid != target || _isCompleting) return;
    _discardSession(expectedUuid: target);
    if (plan != null) {
      _showMarathonFeedback(l10n.marathonStopped);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LanguageService.instance.translate('session_reset')),
        backgroundColor: AppColors.outline,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // İzin yokken uyarı her BAŞLAT'ta değil, uygulama açılışı başına bir kez.
  static bool _notificationNoticeShown = false;

  /// Bildirim tercihi açık ama sistem izni yoksa seans sessiz geçmesin:
  /// kısa bir uyarı ve sistem ayarlarını açan eylem gösterilir.
  Future<void> _maybeShowNotificationNotice() async {
    if (_notificationNoticeShown) return;
    final notifications = NotificationService.instance;
    final preference = await notifications.isEnabled();
    final permission = await notifications.permissionStatus();
    if (!mounted ||
        !NotificationService.isBlockedBySystem(
          preference: preference,
          permission: permission,
        )) {
      return;
    }
    _notificationNoticeShown = true;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.timerNotificationsDenied),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: l10n.profileOpenSettings,
          onPressed: () => unawaited(notifications.openSystemSettings()),
        ),
      ),
    );
  }

  Future<void> _show321CountdownAndStart() async {
    if (!_sessionIsActive) return;
    final owner = widget.sessionOwnerKey;
    // Bildirim izni ilk BAŞLAT'ta, bağlamıyla birlikte istenir (bir kez sorulur).
    final notificationsAllowed = await NotificationService.instance
        .ensurePermission();
    if (!mounted || !_sameOwner(owner)) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) {
        return TimerCountdownDialog(
          onComplete: () {
            if (ctx.mounted && Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
            if (_sameOwner(owner) && _isStarting) _startOrResume();
          },
        );
      },
    );
    // Geri tuşuyla kapatılan geri sayım BAŞLAT'ı kilitli bırakmaz.
    if (_sameOwner(owner) && !isRunning && !_persistingMarathonStart) {
      setState(() {
        _isStarting = false;
        if (!_hasSession) _marathonCount = 0;
      });
    }
    if (_sameOwner(owner) && isRunning && !notificationsAllowed) {
      unawaited(_maybeShowNotificationNotice());
    }
  }

  void _startOrResume() {
    if (!mounted || !_sessionIsActive) return;
    final now = _now();
    final current = _session;
    if (current != null) {
      // Geri sayım sırasında da sınır aşılmış olabilir.
      if (_expireStalePausedSession()) return;
      _runSession(current.resumeAt(now), now);
      return;
    }
    if (_marathonCount > 0 && !widget.marathonAvailable) {
      setState(() {
        _isStarting = false;
        _marathonCount = 0;
      });
      return;
    }
    final category = _resolveCategory(selectedCategoryId, selectedCategoryName);
    _lastMarathonForDisplay = null;
    _lastMarathonTimedOut = false;
    _lastMarathonRejected = false;
    _lastMarathonValidationFailed = false;
    final fresh = ActiveTimerSession.start(
      clientUuid: const Uuid().v4(),
      categoryId: category?.id ?? selectedCategoryId,
      categoryName: category?.name ?? selectedCategoryName,
      categoryColorHex: category?.colorHex,
      durationMinutes: loggedMinutes,
      totalSeconds: totalSeconds,
      marathon: _marathonCount == 0
          ? null
          : MarathonProgress(
              totalSessions: _marathonCount,
              marathonUuid: const Uuid().v4(),
              breakSeconds: widget.quickTimer ? 3 : 300,
            ),
      now: now,
    );
    if (fresh.marathon == null) {
      _runSession(fresh, now);
    } else {
      _persistingMarathonStart = true;
      unawaited(_startMarathonAfterPersisting(fresh, now));
    }
  }

  Future<void> _startMarathonAfterPersisting(
    ActiveTimerSession fresh,
    DateTime now,
  ) async {
    final owner = widget.sessionOwnerKey;
    bool canStart() =>
        _sameOwner(owner) &&
        _isInForeground &&
        !_hasSession &&
        _persistingMarathonStart;
    final saved = await _store.saveChecked(owner, fresh, canCommit: canStart);
    if (!_sameOwner(owner)) return;
    _persistingMarathonStart = false;
    if (!saved) {
      setState(() {
        _isStarting = false;
        _marathonCount = 0;
      });
      if (!_isInForeground || _hasSession) return;
      if (!mounted) return;
      _showMarathonFeedback(AppLocalizations.of(context)!.marathonStartFailed);
      return;
    }
    if (_hasSession) return;
    _runSession(fresh, now, persist: false);
    if (!mounted) return;
    if (isRunning && _session?.clientUuid == fresh.clientUuid) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            key: const ValueKey('marathon-started-message'),
            content: Text(
              AppLocalizations.of(context)!.marathonStartingWelcome,
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }

  void _runSession(
    ActiveTimerSession session,
    DateTime now, {
    bool persist = true,
  }) {
    if (!mounted || !_sessionIsActive) return;
    _timer?.cancel();
    final left = session.remainingSecondsAt(now);
    setState(() {
      _session = session;
      isRunning = true;
      _isStarting = false;
      _completionFailed = false;
      remaining = left;
      loggedMinutes = session.durationMinutes;
      totalSeconds = session.totalSeconds;
    });
    if (persist) _persistSession();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    unawaited(
      NotificationService.instance.scheduleSessionEnd(
        after: Duration(seconds: left),
        categoryName: session.categoryName,
      ),
    );
    unawaited(_lockScreen.showRunning(session));
    widget.onTimerStateChanged?.call(
      true,
      session.categoryName,
      _minutesLeft(left),
    );
  }

  void _showPauseLimitDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final target = _session?.clientUuid;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        constraints: kTimerDialogConstraints,
        backgroundColor: isDark
            ? AppColors.darkSurfaceContainerHigh
            : AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                LanguageService.instance.translate('pause_limit_title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          LanguageService.instance.translate('pause_limit_content'),
          style: TextStyle(
            fontSize: 14,
            color: isDark
                ? AppColors.darkOnSurfaceVariant
                : AppColors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (target == null || _session?.clientUuid != target) return;
              _discardSession(expectedUuid: target);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    LanguageService.instance.translate('session_reset'),
                  ),
                  backgroundColor: AppColors.outline,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(
              LanguageService.instance.translate('reset_and_stop'),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              LanguageService.instance.translate('continue_btn'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSessionCompletedDialog(
    int displayMinutes,
    Future<SessionSubmitResult?>? result, {
    bool testSession = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => SessionCompletedDialog(
        minutes: displayMinutes,
        result: result,
        testSession: testSession,
      ),
    );
  }

  String _marathonCardStatus(AppLocalizations l10n) {
    final plan = _marathon ?? _lastMarathonForDisplay;
    return _isAwaitingPresence
        ? _isStarting
              ? l10n.marathonPresenceChecking
              : _presenceRequestFailed
              ? l10n.marathonPresenceConnectionNeeded
              : l10n.marathonPresenceHint
        : _isCompleting
        ? l10n.marathonSaving
        : _isBreak
        ? l10n.marathonBreakHint
        : _lastMarathonRejected
        ? _lastMarathonValidationFailed
              ? l10n.marathonStoppedInvalid
              : l10n.marathonStoppedRejected
        : _lastMarathonTimedOut
        ? l10n.marathonPresenceExpired
        : plan?.isFinished == true
        ? l10n.marathonCompletedBody(
            plan!.completedSessions,
            plan.completedSessions * loggedMinutes,
          )
        : !widget.marathonAvailable && !_hasSession
        ? l10n.marathonUnavailable
        : _marathonCount == 0
        ? l10n.marathonSingle
        : l10n.marathonMinutesSummary(
            _marathonCount * loggedMinutes,
            _marathonCount * loggedMinutes + (_marathonCount - 1) * 5,
          );
  }

  void _showMarathonInfo() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    int bonus(int minutes, int count) =>
        widget.marathonBonuses?[minutes]?[count] ??
        marathonBonusPreview(totalSessions: count, durationMinutes: minutes);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('marathon-info-dialog'),
        scrollable: true,
        constraints: kTimerDialogConstraints,
        title: Text(l10n.marathonInfoTitle),
        content: Text(
          '${l10n.marathonAutomaticHint}\n\n'
          '${l10n.marathonInfoBonusMatrix(bonus(25, 2), bonus(25, 3), bonus(25, 4), bonus(50, 2), bonus(50, 3), bonus(50, 4))}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (ModalRoute.of(ctx)?.isCurrent ?? false) Navigator.pop(ctx);
            },
            child: Text(l10n.sessionResultOk),
          ),
        ],
      ),
    );
  }

  Future<void> _openMarathonPlanner() async {
    if (!widget.marathonAvailable ||
        _hasSession ||
        _isStarting ||
        _planningMarathon ||
        !_sessionIsActive ||
        !_isInForeground) {
      return;
    }
    final owner = widget.sessionOwnerKey;
    _planningMarathon = true;
    MarathonPlanChoice? choice;
    try {
      choice = await showDialog<MarathonPlanChoice>(
        context: context,
        builder: (_) => MarathonPlanDialog(
          initialTotalSessions: _lastPlannedMarathonCount,
          initialDurationMinutes: loggedMinutes,
          marathonBonuses: widget.marathonBonuses,
          onInfo: _showMarathonInfo,
        ),
      );
    } finally {
      if (mounted && widget.sessionOwnerKey == owner) {
        _planningMarathon = false;
      }
    }
    // The popup is a draft. Cancellation, an owner change or a late result
    // cannot change the normal timer or create a new plan.
    if (!_sameOwner(owner) ||
        choice == null ||
        !_isInForeground ||
        !widget.marathonAvailable ||
        _hasSession ||
        _isStarting ||
        !const [2, 3, 4].contains(choice.totalSessions) ||
        !const [25, 50].contains(choice.durationMinutes)) {
      return;
    }
    setState(() {
      _lastPlannedMarathonCount = choice!.totalSessions;
      _marathonCount = choice.totalSessions;
      loggedMinutes = choice.durationMinutes;
      totalSeconds = timerDurationSeconds(
        loggedMinutes,
        quick: widget.quickTimer,
      );
      remaining = totalSeconds;
      _lastMarathonForDisplay = null;
      _lastMarathonTimedOut = false;
      _lastMarathonRejected = false;
      _lastMarathonValidationFailed = false;
      _validateSelectedCategory();
    });
    _toggleTimer();
  }

  MarathonCardStage get _marathonCardStage => _isAwaitingPresence
      ? MarathonCardStage.checkIn
      : _isCompleting
      ? MarathonCardStage.saving
      : _isBreak
      ? MarathonCardStage.breakTime
      : _lastMarathonTimedOut || _lastMarathonRejected
      ? MarathonCardStage.timedOut
      : (_marathon ?? _lastMarathonForDisplay)?.isFinished == true
      ? MarathonCardStage.finished
      : _hasSession
      ? MarathonCardStage.focus
      : MarathonCardStage.preview;

  void _dismissMarathonProgress() {
    final route = _marathonProgressRoute;
    _marathonProgressRoute = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  Future<void> _showMarathonProgress() async {
    if (_marathon == null ||
        _marathonProgressRoute != null ||
        !_sessionIsActive) {
      return;
    }
    final owner = widget.sessionOwnerKey;
    final route = DialogRoute<void>(
      context: context,
      builder: (ctx) => ValueListenableBuilder<int>(
        valueListenable: _marathonDialogRevision,
        builder: (ctx, _, _) {
          if (!_sameOwner(owner)) return const SizedBox.shrink();
          final l10n = AppLocalizations.of(ctx)!;
          final plan = _marathon ?? _lastMarathonForDisplay;
          return AlertDialog(
            key: const ValueKey('marathon-progress-dialog'),
            constraints: const BoxConstraints(maxWidth: 520),
            scrollable: true,
            title: Text(l10n.marathonViewProgress),
            content: plan == null
                ? Text(l10n.marathonPresenceExpired)
                : MarathonProgressCard(
                    key: const ValueKey('marathon-progress'),
                    totalSessions: plan.totalSessions,
                    completedSessions: plan.completedSessions,
                    durationMinutes: loggedMinutes,
                    stage: _marathonCardStage,
                    statusText: _marathonCardStatus(l10n),
                    progressIdentity: plan.marathonUuid,
                    onInfo: _showMarathonInfo,
                  ),
            actions: [
              TextButton(
                key: const ValueKey('marathon-progress-close'),
                onPressed: () {
                  if (ModalRoute.of(ctx)?.isCurrent ?? false) {
                    Navigator.pop(ctx);
                  }
                },
                child: Text(l10n.sessionResultOk),
              ),
            ],
          );
        },
      ),
    );
    _marathonProgressRoute = route;
    try {
      await Navigator.of(context).push(route);
    } finally {
      if (identical(_marathonProgressRoute, route)) {
        _marathonProgressRoute = null;
      }
    }
  }

  /// A smaller visible pill keeps the same row and accessible tap height.
  /// The help action lives inside the shared box, separate from planning.
  /// No plan/phase changes the hourglass geometry or control-stack budget.
  Widget _marathonEntry(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final plan = _marathon;
    final active = plan != null;
    final colors = Theme.of(context).colorScheme;
    final enabled =
        active ||
        (widget.marathonAvailable &&
            !_hasSession &&
            !_isStarting &&
            !_planningMarathon);
    final label = active
        ? '${l10n.marathonTitle} · ${l10n.marathonProgress(plan.completedSessions, plan.totalSessions)}'
        : l10n.marathonStart;
    final reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final onPressed = enabled
        ? active
              ? _showMarathonProgress
              : _openMarathonPlanner
        : null;
    return SizedBox(
      height: kMinInteractiveDimension,
      width: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 4,
            bottom: 4,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('marathon-entry-surface'),
                decoration: BoxDecoration(
                  color: enabled
                      ? colors.primaryContainer.withValues(alpha: 0.22)
                      : colors.surfaceContainerHigh,
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: active
                      ? '$label. ${_marathonCardStatus(l10n)}'
                      : label,
                  excludeSemantics: true,
                  button: true,
                  enabled: enabled,
                  onTap: onPressed,
                  child: TextButton.icon(
                    key: ValueKey(
                      active
                          ? 'marathon-active-progress'
                          : 'marathon-open-planner',
                    ),
                    onPressed: onPressed,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, kMinInteractiveDimension),
                      maximumSize: const Size(
                        double.infinity,
                        kMinInteractiveDimension,
                      ),
                      padding: const EdgeInsets.only(left: 12),
                      foregroundColor: colors.primary,
                      disabledForegroundColor: colors.onSurface.withValues(
                        alpha: 0.38,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    icon: Icon(
                      active && plan.completedSessions > 0
                          ? Icons.check_circle_outline_rounded
                          : Icons.flag_rounded,
                      size: 16,
                    ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: AnimatedSwitcher(
                        duration: reducedMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 450),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        ),
                        child: Text(
                          label,
                          key: ValueKey(label),
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('marathon-info'),
                onPressed: _showMarathonInfo,
                tooltip: l10n.marathonInfoTitle,
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(kMinInteractiveDimension),
                  padding: EdgeInsets.zero,
                  foregroundColor: colors.primary,
                  shape: const CircleBorder(),
                ),
                icon: Container(
                  key: const ValueKey('marathon-info-circle'),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.question_mark_rounded, size: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
        final seconds = (remaining % 60).toString().padLeft(2, '0');
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final activeCategories = widget.categories
            .where((c) => !c.isArchived)
            .toList();
        final displayCategory = _displayCategory();
        final hasPauseCredit = _pauseCreditsLeft > 0;
        // Hareketi Azalt açıkken yerleşim değişimleri canlandırılmaz.
        final layoutAnimation =
            (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
            ? Duration.zero
            : const Duration(milliseconds: 600);

        Widget pauseCreditIndicator({bool compact = false}) {
          final label = Text(
            hasPauseCredit ? l10n.pauseCreditAvailable : l10n.pauseCreditUsed,
            maxLines: compact ? 1 : null,
            softWrap: !compact,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: hasPauseCredit
                  ? (isDark
                        ? AppColors.darkOnSurfaceVariant
                        : AppColors.onSurfaceVariant)
                  : AppColors.primary,
            ),
          );
          return Container(
            key: const ValueKey('timer-pause-credit'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: hasPauseCredit
                  ? (isDark
                        ? AppColors.darkSurfaceContainerHigh
                        : AppColors.surfaceContainerHigh)
                  : AppColors.primaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasPauseCredit
                    ? (isDark
                          ? AppColors.darkOutlineVariant
                          : AppColors.outlineVariant)
                    : AppColors.primary,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasPauseCredit
                      ? Icons.pause_circle_outline
                      : Icons.block_outlined,
                  size: 13,
                  color: hasPauseCredit
                      ? (isDark
                            ? AppColors.darkOnSurfaceVariant
                            : AppColors.onSurfaceVariant)
                      : AppColors.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  // The long used-credit label must not push the clock/control
                  // outside a short landscape viewport at large text scales.
                  child: compact
                      ? FittedBox(fit: BoxFit.scaleDown, child: label)
                      : label,
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final lineHeight = _lineHeightMeasurer(context);
                // The planner and step card live in dialogs. Keep the exact
                // pre-Maraton hourglass geometry; the compact entry uses the
                // normal control stack, without changing the size budget.
                final layout = _TimerLayout.of(
                  constraints,
                  lineHeight: lineHeight,
                );
                if (_marathonProgressRoute != null) {
                  final route = _marathonProgressRoute;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && identical(route, _marathonProgressRoute)) {
                      _marathonDialogRevision.value++;
                    }
                  });
                }
                final dense = layout.dense;
                final large = layout.large;
                // Dikey boşluklar: alçak ekran / dikey telefon / diğerleri.
                // Dikey telefonda eski boyut hesabını korurken kompakt
                // Maraton satırı için aralıkların bir kısmını kullanırız.
                double gap(
                  double whenDense,
                  double whenCompact,
                  double otherwise,
                ) => dense
                    ? whenDense
                    : (layout.compact ? whenCompact : otherwise);

                final hourglass = HourglassWidget(
                  size: layout.hourglassSize,
                  isRunning: isRunning,
                  totalSeconds: totalSeconds,
                  remainingSeconds: _isAwaitingPresence
                      ? totalSeconds
                      : remaining,
                  sandColor:
                      displayCategory?.color ??
                      activeCategories.firstOrNull?.color,
                );
                final hourglassWidget = _isBreak
                    ? Center(
                        key: const ValueKey('marathon-break'),
                        child: MarathonBreakIndicator(
                          size: layout.hourglassSize * 0.65,
                        ),
                      )
                    : _isAwaitingPresence
                    ? Center(
                        key: const ValueKey('marathon-presence'),
                        child: hourglass,
                      )
                    : hourglass;
                final landscape =
                    MediaQuery.orientationOf(context) == Orientation.landscape;

                Widget landscapeControls() {
                  final canToggle =
                      !_isStarting &&
                      !_expiringPresence &&
                      !((_isCompleting || _isBreak) && !_completionFailed);
                  final label = _isAwaitingPresence
                      ? (_isStarting
                            ? l10n.marathonPresenceChecking
                            : l10n.marathonPresenceConfirm)
                      : _completionFailed
                      ? l10n.marathonRetrySave
                      : isRunning
                      ? LanguageService.instance.translate('btn_pause')
                      : LanguageService.instance.translate('btn_start');
                  final stop = _isBreak;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        key: const ValueKey('timer-landscape-clock'),
                        label: _isAwaitingPresence
                            ? l10n.marathonPresenceRemainingSemantics(
                                remaining ~/ 60,
                                remaining % 60,
                              )
                            : _isBreak
                            ? l10n.marathonBreakRemainingSemantics(
                                remaining ~/ 60,
                                remaining % 60,
                              )
                            : l10n.timerRemainingSemantics(
                                remaining ~/ 60,
                                remaining % 60,
                              ),
                        excludeSemantics: true,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$minutes:$seconds',
                            style: TextStyle(
                              fontSize: 80,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -1.5,
                              color: _isBreak
                                  ? Colors.teal
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      if (!_isResting && !_isCompleting) ...[
                        const SizedBox(height: 8),
                        pauseCreditIndicator(compact: true),
                        const SizedBox(height: 8),
                      ] else
                        const SizedBox(height: 16),
                      Row(
                        key: const ValueKey('timer-landscape-control'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: ElevatedButton(
                              key: ValueKey(
                                stop
                                    ? 'marathon-stop'
                                    : _isAwaitingPresence
                                    ? 'marathon-presence-confirm'
                                    : _completionFailed
                                    ? 'marathon-retry-save'
                                    : 'timer-start-pause',
                              ),
                              onPressed: stop
                                  ? _confirmDiscardSession
                                  : canToggle
                                  ? _toggleTimer
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryContainer,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(56, 56),
                                padding: const EdgeInsets.all(16),
                                shape: _isAwaitingPresence || _completionFailed
                                    ? const StadiumBorder()
                                    : const CircleBorder(),
                              ),
                              child: _isAwaitingPresence || _completionFailed
                                  ? FittedBox(child: Text(label))
                                  : Tooltip(
                                      message: stop ? l10n.marathonStop : label,
                                      child: Icon(
                                        stop
                                            ? Icons.stop_rounded
                                            : isRunning
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        semanticLabel: stop
                                            ? l10n.marathonStop
                                            : label,
                                      ),
                                    ),
                            ),
                          ),
                          if (_hasSession && !stop) ...[
                            const SizedBox(width: 12),
                            IconButton(
                              key: ValueKey(
                                _marathon == null
                                    ? 'timer-landscape-reset'
                                    : 'marathon-stop',
                              ),
                              onPressed: (_marathon?.isFinished ?? false)
                                  ? null
                                  : _confirmDiscardSession,
                              tooltip: _marathon == null
                                  ? l10n.timerResetBtn
                                  : l10n.marathonStop,
                              icon: const Icon(Icons.stop_rounded),
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                }

                Widget categoryChip(CourseCategory cat) {
                  final isSelected = cat.id == displayCategory?.id;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(
                        LanguageService.instance.translateCatName(cat.name),
                      ),
                      selected: isSelected,
                      // Seans sürerken/duraklatılmışken kategori kilitli.
                      onSelected: _hasSession || _isStarting
                          ? null
                          : (val) {
                              if (val) {
                                setState(() {
                                  selectedCategoryId = cat.id;
                                  selectedCategoryName = cat.name;
                                });
                              }
                            },
                      avatar: CircleAvatar(
                        backgroundColor: cat.color,
                        radius: 5,
                      ),
                      showCheckmark: false,
                      selectedColor: cat.color.withValues(alpha: 0.2),
                      backgroundColor: isDark
                          ? AppColors.darkSurfaceContainerLow
                          : AppColors.surfaceContainerLow,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? cat.color
                            : (isDark
                                  ? AppColors.darkOnSurfaceVariant
                                  : AppColors.onSurfaceVariant),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected ? cat.color : Colors.transparent,
                        ),
                      ),
                    ),
                  );
                }

                // Seansın kategorisi arşivlendiyse kilitli, seçili çip olarak başta kalır.
                final categoryChips = [
                  if (displayCategory != null &&
                      !activeCategories.any((c) => c.id == displayCategory.id))
                    categoryChip(displayCategory),
                  for (final cat in activeCategories) categoryChip(cat),
                ];

                Widget durationOption(int mins) {
                  final isSel = loggedMinutes == mins;
                  final foreground = isSel
                      ? Colors.white
                      : (isDark
                                ? AppColors.darkOnSurfaceVariant
                                : AppColors.onSurfaceVariant)
                            .withValues(alpha: _hasSession ? 0.45 : 1);
                  return Semantics(
                    key: ValueKey('timer-duration-$mins'),
                    button: true,
                    selected: isSel,
                    label: l10n.timerDurationOption(mins),
                    onTap: () => _selectDuration(mins),
                    excludeSemantics: true,
                    child: GestureDetector(
                      // Seans varken kilitli (bkz. _selectDuration).
                      onTap: () => _selectDuration(mins),
                      behavior: HitTestBehavior.opaque,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: kMinInteractiveDimension,
                        ),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: dense ? 6 : 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? AppColors.primaryContainer
                                  : (isDark
                                        ? AppColors.darkSurfaceContainerLow
                                        : AppColors.surfaceContainerLow),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSel
                                    ? AppColors.primaryContainer
                                    : (isDark
                                          ? AppColors.darkOutlineVariant
                                          : AppColors.outlineVariant),
                              ),
                            ),
                            // Büyük yazı ölçeğinde satır kırmadan küçülür.
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSel) ...[
                                      Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: foreground,
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      '$mins ${LanguageService.instance.translate('minutes_unit_short')}',
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: foreground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final controlsWidget = landscape
                    ? landscapeControls()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Active Category Pills: telefonda yatay kaydırılır,
                          // tablette ortalanmış satırlara sarılır.
                          if (large)
                            Wrap(
                              alignment: WrapAlignment.center,
                              runSpacing: 4,
                              children: categoryChips,
                            )
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [...categoryChips],
                              ),
                            ),
                          SizedBox(height: gap(2, 8, 16)),

                          // Time Display (yalnızca sütuna sığmazsa satır kırmadan
                          // küçülür). Ekran okuyucu "X dakika Y saniye kaldı" okur.
                          Semantics(
                            label: _isAwaitingPresence
                                ? l10n.marathonPresenceRemainingSemantics(
                                    remaining ~/ 60,
                                    remaining % 60,
                                  )
                                : _isBreak
                                ? l10n.marathonBreakRemainingSemantics(
                                    remaining ~/ 60,
                                    remaining % 60,
                                  )
                                : l10n.timerRemainingSemantics(
                                    remaining ~/ 60,
                                    remaining % 60,
                                  ),
                            excludeSemantics: true,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$minutes:$seconds',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: large ? 60 : (dense ? 42 : 52),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1.5,
                                  color: _isResting
                                      ? Colors.teal
                                      : (isDark
                                            ? AppColors.darkOnSurface
                                            : AppColors.onSurface),
                                ),
                              ),
                            ),
                          ),
                          _marathonEntry(context),
                          // Süre çiplerinin 48 dp dokunma alanı bu boşluğun bir kısmını alır.
                          SizedBox(height: gap(0, 2, 6)),

                          // Süre Seçimi: 25 dk / 50 dk tek satırda, eşit genişlikte
                          // iki seçenek. Her biri en az 48 dp yüksek dokunma alanı
                          // ve ekran okuyucuda seçili durumuyla düğme olarak
                          // duyurulur; seçili olan dolgu rengi ve onay işaretiyle
                          // (yalnızca renge dayanmadan) ayrılır. Eskiden Wrap
                          // içindeki hizalı Container satırın tüm genişliğini
                          // alıyordu: 50 dk her ekranda alt satıra düşüyordu.
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _durationRowMaxWidth,
                            ),
                            child: Row(
                              children: [
                                for (final mins in const [25, 50]) ...[
                                  if (mins != 25) const SizedBox(width: 12),
                                  Expanded(child: durationOption(mins)),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: gap(2, 6, 16)),

                          pauseCreditIndicator(),
                          SizedBox(height: gap(2, 8, 14)),

                          // Primary Start/Pause Button
                          ElevatedButton(
                            key: ValueKey(
                              _isAwaitingPresence
                                  ? 'marathon-presence-confirm'
                                  : _completionFailed
                                  ? 'marathon-retry-save'
                                  : 'timer-start-pause',
                            ),
                            onPressed:
                                _isStarting ||
                                    _expiringPresence ||
                                    ((_isCompleting || _isBreak) &&
                                        !_completionFailed) ||
                                    (!widget.marathonAvailable &&
                                        _marathonCount > 0 &&
                                        !_hasSession)
                                ? null
                                : _toggleTimer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isRunning
                                  ? (isDark
                                        ? AppColors.darkSurfaceContainerHighest
                                        : AppColors.surfaceContainerHighest)
                                  : AppColors.primaryContainer,
                              foregroundColor: isRunning
                                  ? (isDark
                                        ? AppColors.darkOnSurface
                                        : AppColors.onSurface)
                                  : Colors.white,
                              minimumSize: large
                                  ? const Size(240, 52)
                                  : Size(200, dense ? 44 : 48),
                              elevation: isRunning ? 0 : 4,
                              shadowColor: const Color(0x40FF5C4D),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _isAwaitingPresence
                                    ? _isStarting
                                          ? l10n.marathonPresenceChecking
                                          : l10n.marathonPresenceConfirm
                                    : _completionFailed
                                    ? l10n.marathonRetrySave
                                    : _isCompleting
                                    ? l10n.marathonSaving
                                    : _isBreak
                                    ? l10n.marathonBreakTitle
                                    : isRunning
                                    ? LanguageService.instance.translate(
                                        'btn_pause',
                                      )
                                    : LanguageService.instance.translate(
                                        'btn_start',
                                      ),
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: large ? 18 : 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // Süren ya da duraklatılmış seansı onayla bırakma.
                          if (_hasSession) ...[
                            SizedBox(height: gap(2, 2, 6)),
                            TextButton.icon(
                              key: _marathon == null
                                  ? null
                                  : const ValueKey('marathon-stop'),
                              onPressed: (_marathon?.isFinished ?? false)
                                  ? null
                                  : _confirmDiscardSession,
                              icon: Icon(
                                _marathon == null
                                    ? Icons.restart_alt_rounded
                                    : Icons.stop_circle_outlined,
                                size: 18,
                              ),
                              label: Text(
                                _marathon == null
                                    ? l10n.timerResetBtn
                                    : l10n.marathonStop,
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: isDark
                                    ? AppColors.darkOnSurfaceVariant
                                    : AppColors.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: gap(4, 4, 12)),
                          ] else
                            SizedBox(height: gap(8, 12, 24)),
                        ],
                      );

                // Konumlar canlandırılır: telefon döndürülünce kum saati ve
                // kontroller yeni yerlerine kayar.
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedPositioned(
                      duration: layoutAnimation,
                      curve: Curves.easeInOutCubic,
                      top: layout.hourglassTop,
                      left: layout.hourglassLeft,
                      width: layout.hourglassSize,
                      height: layout.hourglassHeight,
                      child: hourglassWidget,
                    ),
                    AnimatedPositioned(
                      duration: layoutAnimation,
                      curve: Curves.easeInOutCubic,
                      top: layout.controlsTop,
                      bottom: 0.0,
                      left: layout.controlsLeft,
                      width: layout.controlsWidth,
                      child: Align(
                        alignment: layout.controlsAlignment,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: controlsWidget,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Verilen yazı boyutu ve kalınlığında bir satırın ekrandaki yüksekliği.
typedef _LineHeight = double Function(double fontSize, FontWeight fontWeight);

/// Ekranın varsayılan yazı stili ve yazı ölçeğiyle satır yüksekliği ölçer
/// (cihazın gerçek yazı tipi; Text widget'ı da aynı stili birleştirir).
_LineHeight _lineHeightMeasurer(BuildContext context) {
  final base = DefaultTextStyle.of(context).style;
  final textScaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  return (fontSize, fontWeight) {
    final painter = TextPainter(
      text: TextSpan(
        text: '0',
        style: base.merge(
          TextStyle(fontSize: fontSize, fontWeight: fontWeight),
        ),
      ),
      textDirection: direction,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  };
}

/// Sayaç ekranının yerleşimi; ekranın değil sayaca kalan alanın (yan
/// gezinme ve güvenli alan düşülmüş) ölçüsünden hesaplanır.
///
/// * Dikey telefon: kum saati üstte, kontroller hemen altında. Kum saati
///   kontrollerin (seans sürerken görünen Sıfırla dahil) tahmini
///   yüksekliğinden kalan alana sığacak kadar büyür, en çok
///   [_phoneHourglass]; BAŞLAT/DURAKLAT kaydırmadan görünür. Alan çok
///   kısaysa kum saati eski boyutunun altına inmez, kontroller kayar.
///   Fazla alan varsa grup dikeyde ortalanır.
/// * Yatay (genişlik > yükseklik): kum saati solda, kontroller sağda; sağ
///   sütun sığmazsa kendi içinde kayar. Geniş ekranda iki sütun ortalanmış
///   bir grup olarak kalır.
/// * Tablet dikey: kum saati ve kontroller ortada, ekrana göre ölçekli ama
///   [_maxHourglass]'ı aşmadan.
@immutable
class _TimerLayout {
  const _TimerLayout({
    required this.dense,
    required this.large,
    required this.compact,
    required this.hourglassSize,
    required this.hourglassHeight,
    required this.hourglassTop,
    required this.hourglassLeft,
    required this.controlsTop,
    required this.controlsLeft,
    required this.controlsWidth,
    required this.controlsAlignment,
  });

  /// Kum saati önceki sürüme göre bu oranda büyütüldü (yer olan yerlerde).
  static const double _growth = 1.25;

  /// Önceki dikey telefon boyutu; kısa ekranda kum saati bunun altına inmez.
  static const double _legacyPhoneHourglass = 220;
  static const double _phoneHourglass = _legacyPhoneHourglass * _growth;
  static const double _maxHourglass = 300 * _growth;
  static const double _minHourglass = 64;
  static const double _shortPortraitHeight = 540;
  static const double _denseHeight = 420;
  static const double _maxTwoColumnWidth = 960;
  static const double _maxCenteredControlsWidth = 560;

  /// Dikey telefonda kum saatinin üstündeki en az boşluk ve kum saati ile
  /// kontroller arası.
  static const double _phoneTop = 8;
  static const double _phoneGap = 8;

  /// Tablet dikeyde kum saati ve kontrolleri dikeyde ortalamak için
  /// kontrollerin yaklaşık yüksekliği (yanılırsa yalnızca ortalama kayar).
  static const double _estimatedControlsHeight = 420;

  /// Dikey telefonda kontrol sütununun (seans varken: Sıfırla dahil)
  /// yaklaşık yüksekliği. Yazı satırları ekrandaki yazı tipi ve ölçeğiyle
  /// ölçülür ([lineHeight]). Maraton öncesi boyut bütçesidir; kompakt giriş
  /// satırı mevcut aralık ve boşta ayrılan Sıfırla alanını kullanır. Ana
  /// ekranın gerçek aralıkları daha kısadır, kum saati küçültülmez.
  static double phoneControlsHeight({
    required bool dense,
    required _LineHeight lineHeight,
  }) {
    const tap = kMinInteractiveDimension;
    final chips = math.max(
      tap,
      lineHeight(13, FontWeight.bold) + 24,
    ); // başlık satır içinde
    final time = lineHeight(dense ? 42 : 52, FontWeight.bold);
    final duration = math.max(
      tap,
      lineHeight(16, FontWeight.bold) + (dense ? 14 : 22),
    );
    final pause = math.max(13.0, lineHeight(11, FontWeight.w600)) + 12;
    final button = math.max(
      dense ? 44.0 : 48.0,
      lineHeight(17, FontWeight.bold) + 16,
    );
    final reset = math.max(tap, lineHeight(14, FontWeight.w500) + 16);
    final gaps = dense ? (8 + 0 + 4 + 8 + 2 + 4) : (12 + 2 + 10 + 12 + 2 + 4);
    return chips + time + duration + pause + button + reset + gaps;
  }

  factory _TimerLayout.of(
    BoxConstraints constraints, {
    required _LineHeight lineHeight,
  }) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;
    final large = math.min(w, h) >= Responsive.mediumMinWidth;

    if (w > h) {
      final groupWidth = math.min(w, _maxTwoColumnWidth);
      final groupLeft = (w - groupWidth) / 2;
      // Kontroller (çipler, süre seçimi) biraz daha geniş sütun alır.
      final columnWidth = groupWidth * 0.45;
      // Yükseklik çoğunlukla sınırlar; sütun kenarlarına dayanmaz.
      final size = math.max(
        _minHourglass,
        math.min(_maxHourglass, math.min(columnWidth * 0.9, (h - 24) / 1.05)),
      );
      final dense = h < _denseHeight;
      return _TimerLayout(
        dense: dense,
        large: large,
        compact: false,
        hourglassSize: size,
        hourglassHeight: size * 1.05,
        hourglassTop: (h - size * 1.05) / 2,
        hourglassLeft: groupLeft + (columnWidth - size) / 2,
        controlsTop: 0,
        controlsLeft: groupLeft + columnWidth,
        controlsWidth: groupWidth - columnWidth,
        controlsAlignment: Alignment.center,
      );
    }

    if (w < Responsive.mediumMinWidth) {
      final dense = h < _shortPortraitHeight;
      final controls = phoneControlsHeight(
        dense: dense,
        lineHeight: lineHeight,
      );
      final ceiling = math.min(_phoneHourglass, w - 32);
      // Plan selection never reduces the normal hourglass floor. The
      // compact entry takes the same space for a single session or marathon.
      final floor = math.min(
        ceiling,
        dense
            ? (h * 0.34).clamp(120.0, _legacyPhoneHourglass)
            : _legacyPhoneHourglass,
      );
      final size = ((h - _phoneTop - _phoneGap - controls) / 1.05).clamp(
        floor,
        ceiling,
      );
      final hourglassHeight = size * 1.05;
      final spare = h - (_phoneTop + hourglassHeight + _phoneGap + controls);
      final top = _phoneTop + math.max(0.0, spare / 2);
      return _TimerLayout(
        dense: dense,
        large: false,
        compact: true,
        hourglassSize: size,
        hourglassHeight: hourglassHeight,
        hourglassTop: top,
        hourglassLeft: (w - size) / 2,
        controlsTop: top + hourglassHeight + _phoneGap,
        controlsLeft: 0,
        controlsWidth: w,
        controlsAlignment: Alignment.topCenter,
      );
    }

    final size = (math.min(w, h) * 0.36 * _growth).clamp(
      _phoneHourglass,
      _maxHourglass,
    );
    final hourglassHeight = size * 1.05;
    const gap = 20.0;
    final top = math.max(
      32.0,
      (h - hourglassHeight - gap - _estimatedControlsHeight) / 2,
    );
    final controlsWidth = math.min(w, _maxCenteredControlsWidth);
    return _TimerLayout(
      dense: false,
      large: large,
      compact: false,
      hourglassSize: size,
      hourglassHeight: hourglassHeight,
      hourglassTop: top,
      hourglassLeft: (w - size) / 2,
      controlsTop: top + hourglassHeight + gap,
      controlsLeft: (w - controlsWidth) / 2,
      controlsWidth: controlsWidth,
      controlsAlignment: Alignment.topCenter,
    );
  }

  /// Dikey alan kıt: kontrollerin aralıkları sıkışır.
  final bool dense;

  /// Tablet: süre ve düğme biraz büyür, kategori çipleri satırlara sarılır.
  final bool large;

  /// Dikey telefon: aralıklar dense ile tablet arasında (BAŞLAT kaydırmadan
  /// görünsün, kum saati büyük kalsın).
  final bool compact;

  final double hourglassSize;
  final double hourglassHeight;
  final double hourglassTop;
  final double hourglassLeft;
  final double controlsTop;
  final double controlsLeft;
  final double controlsWidth;
  final Alignment controlsAlignment;
}

/// Seans tamamlanınca gösterilen diyalog. [result] verilirse sunucunun
/// sonucunu bekler: önce "kaydediliyor", sonra kazanılan puan, kum ve seri
/// (yalnızca RPC sonucundan; istemcide formül yok), kuyruk ya da ret
/// nedeni. Sonuç [resultTimeout] içinde gelmezse "cihazda kayıtlı, bağlantı
/// gelince gönderilecek" gösterilir; sonuç sonradan gelirse güncellenir.
class SessionCompletedDialog extends StatefulWidget {
  final int minutes;

  /// Gönderimin sonucu (null değer: sonuç bilinmiyor, seans cihazda).
  final Future<SessionSubmitResult?>? result;
  final Duration resultTimeout;

  /// Gönderilmeyen kısa seans: sunucu sonucu gösterilmez.
  final bool testSession;

  const SessionCompletedDialog({
    super.key,
    required this.minutes,
    this.result,
    this.resultTimeout = const Duration(seconds: 8),
    this.testSession = false,
  });

  @override
  State<SessionCompletedDialog> createState() => _SessionCompletedDialogState();
}

class _SessionCompletedDialogState extends State<SessionCompletedDialog> {
  bool _waiting = false;
  bool _timedOut = false;
  SessionSubmitResult? _result;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    final future = widget.result;
    if (future == null) return;
    _waiting = true;
    _timeoutTimer = Timer(widget.resultTimeout, () {
      if (mounted && _waiting) setState(() => _timedOut = true);
    });
    future.then<void>(
      _finish,
      // Gönderim hata verdiyse seans cihazda kalır ve sonra yeniden
      // gönderilir (bkz. TimerScreen._completeSession).
      onError: (Object _) => _finish(null),
    );
  }

  void _finish(SessionSubmitResult? result) {
    _timeoutTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _waiting = false;
      _result = result;
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _openRejectedSessions() {
    final navigator = Navigator.of(context);
    navigator.pop();
    unawaited(navigator.push(rejectedSessionsRoute()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.onSurfaceVariant;
    final accent = isDark ? AppColors.darkPrimary : AppColors.primary;
    final rejected = _result is SessionSubmitRejected;

    Widget message(String text, IconData icon, Color color) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, height: 1.4, color: muted),
          ),
        ),
      ],
    );

    Widget chip(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );

    final queuedOffline = message(
      l10n.sessionQueuedOffline,
      Icons.cloud_upload_outlined,
      muted,
    );
    final List<Widget> status = switch (_result) {
      _ when widget.testSession => const [],
      _ when widget.result == null => const [],
      _ when _waiting && !_timedOut => [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                l10n.sessionResultSaving,
                style: TextStyle(fontSize: 13, color: muted),
              ),
            ),
          ],
        ),
      ],
      null => [queuedOffline],
      SessionSubmitSuccess(duplicate: true) => [
        message(
          l10n.sessionResultDuplicate,
          Icons.check_circle_outline_rounded,
          accent,
        ),
      ],
      SessionSubmitSuccess(
        :final basePoints,
        :final bonusPoints,
        :final bonusPct,
        :final totalPoints,
        :final coinsEarned,
        :final streak,
        :final dailyLimitReached,
      ) =>
        [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (totalPoints > 0)
                chip(Icons.star_rounded, l10n.sessionResultPoints(totalPoints)),
              if (coinsEarned > 0)
                chip(
                  Icons.hourglass_bottom_rounded,
                  l10n.sessionResultCoins(coinsEarned),
                ),
              if (streak != null && streak > 0)
                chip(
                  Icons.local_fire_department_rounded,
                  l10n.sessionResultStreak(streak),
                ),
            ],
          ),
          if (bonusPoints > 0 && !dailyLimitReached) ...[
            const SizedBox(height: 10),
            Text(
              l10n.sessionPointsBreakdown(
                basePoints,
                bonusPoints,
                bonusPct,
                totalPoints,
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
          if (dailyLimitReached) ...[
            const SizedBox(height: 10),
            message(
              l10n.sessionDailyLimitReached(sessionDailyLimit()),
              Icons.info_outline_rounded,
              accent,
            ),
          ],
        ],
      SessionSubmitQueued(:final reasonCode) => [
        message(
          sessionQueuedMessage(l10n, reasonCode),
          Icons.cloud_upload_outlined,
          muted,
        ),
      ],
      SessionSubmitRejected(:final reasonCode) => [
        message(
          sessionRejectionMessage(l10n, reasonCode),
          Icons.error_outline_rounded,
          Colors.orange.shade800,
        ),
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: _openRejectedSessions,
            child: Text(l10n.rejectedSessionsTitle),
          ),
        ),
      ],
    };

    return AlertDialog(
      // Yatay telefonda dikeyde sığmazsa kayar; tablette makul genişlikte kalır.
      scrollable: true,
      constraints: kTimerDialogConstraints,
      backgroundColor: isDark
          ? AppColors.darkSurfaceContainerHigh
          : AppColors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Column(
        children: [
          rejected
              ? Icon(
                  Icons.cloud_off_rounded,
                  color: Colors.orange.shade800,
                  size: 48,
                )
              : const Icon(Icons.stars_rounded, color: Colors.amber, size: 48),
          const SizedBox(height: 16),
          Text(
            rejected ? l10n.sessionNotSavedTitle : l10n.sessionCompletedTitle,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!rejected)
            Text(
              l10n.sessionCompletedBody(widget.minutes),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: muted, height: 1.5),
            ),
          if (status.isNotEmpty) ...[
            if (!rejected) const SizedBox(height: 16),
            // Sonuç geldiğinde içerik yumuşakça değişir.
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: Column(mainAxisSize: MainAxisSize.min, children: status),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              rejected ? l10n.sessionResultOk : l10n.sessionCompletedOk,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

/// Separate StatefulWidget for the 3-2-1 countdown to properly
/// manage its own Timer lifecycle without spawning duplicates.
class TimerCountdownDialog extends StatefulWidget {
  final VoidCallback onComplete;

  const TimerCountdownDialog({super.key, required this.onComplete});

  @override
  State<TimerCountdownDialog> createState() => _TimerCountdownDialogState();
}

class _TimerCountdownDialogState extends State<TimerCountdownDialog> {
  int _count = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_count > 1) {
        setState(() => _count--);
      } else {
        timer.cancel();
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      // Yatay telefonda ya da büyük yazı ölçeğinde sığmazsa orantılı küçülür.
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                // Hareketi Azalt açıkken rakamlar büyüyerek değil doğrudan değişir.
                duration:
                    (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Text(
                  '$_count',
                  key: ValueKey(_count),
                  style: const TextStyle(
                    fontSize: 110,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: AppColors.primaryContainer, blurRadius: 30),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.timerGetReady,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
