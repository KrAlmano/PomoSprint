import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/avatar_model.dart';
import '../models/category_model.dart';
import '../models/user_model.dart';
import '../screens/friends_sheet.dart';
import '../screens/profile_screen.dart';
import '../screens/ranking_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/social_screen.dart';
import '../screens/timer_screen.dart';
import '../screens/exam_screen.dart';
import '../services/exam_service.dart';
import '../services/language_service.dart';
import '../services/lock_screen_timer.dart';
import '../services/marathon_presence.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../services/timer_persistence.dart';
import '../utils/async_lock.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/league_info_sheet.dart';
import '../widgets/shell_app_bar.dart';
import '../widgets/shell_navigation.dart';
import '../widgets/shell_pending_banner.dart';
import 'category_cache.dart';
import 'connection_watcher.dart';
import 'session_feedback.dart';
import 'theme_controller.dart';

/// Ana kabuk: sekmeler, üst çubuk ve oturumdaki kullanıcının kategorileri,
/// bekleyen seans senkronu. Kullanıcı AppGate'ten gelir (tek kaynak:
/// SupabaseService.currentUser).
class MainNavigationShell extends StatefulWidget {
  final UserModel user;
  final List<CourseCategory> initialCategories;

  const MainNavigationShell({
    super.key,
    required this.user,
    required this.initialCategories,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell>
    with WidgetsBindingObserver {
  // Kuyrukta geçici bir nedenle (ağ, zaman aşımı, sunucu, oturum) kalan
  // seanslar, uygulama ön plandayken artan aralıklarla yeniden denenir.
  // Bağlantı türü değişmeden ağ düzelirse ya da ilk istek ölü sokete
  // denk gelirse bağlantı olayı gelmez; bu zamanlayıcı olmadan seans
  // 24 saati aşıp kaybolabiliyordu.
  static const List<Duration> _syncRetryDelays = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 4),
    Duration(minutes: 8),
    Duration(minutes: 15),
  ];

  final SupabaseService _service = SupabaseService.instance;
  final ExamService _exams = ExamService.instance;
  int _currentIndex = 0;
  int _examHistoryRequest = 0;
  late List<CourseCategory> _categories;
  bool _isTimerRunning = false;
  bool _isMarathonBreak = false;
  bool _isLoggingOut = false;
  bool _focusWasReserved = false;
  final AsyncLock _presenceLock = AsyncLock();
  int _presenceRevision = 0;
  DateTime? _marathonConfirmedAt;
  String? _marathonConfirmedUuid;
  bool _marathonAvailable = false;
  bool _loadingMarathonConfig = false;
  Map<int, Map<int, int>>? _marathonBonuses;
  bool _categorySeedAttempted = false;
  // Bulut hazırken yapılan açılış işleri (auth dinleyicisi, profil,
  // kategoriler) bu kabukta yapıldı mı? Bulut açılıştan sonra gelirse
  // (başlatma hatası ya da splash zaman aşımı) bir kez yapılır.
  late bool _cloudSeen;

  StreamSubscription<AuthState>? _authSubscription;
  late final ConnectionWatcher _connection = ConnectionWatcher(
    onOnline: _onConnectivityOnline,
  );
  Timer? _syncRetryTimer;
  int _syncRetryAttempt = 0;
  String? _queueWarningOwner;

  UserModel get _user => widget.user;

  bool get _needsCategoryReload =>
      _categories.isEmpty ||
      _categories.any((c) => !SupabaseService.isServerCategoryId(c.id));

  @override
  void initState() {
    super.initState();
    _categories = List.of(widget.initialCategories);
    _cloudSeen = _service.isCloudActive;
    WidgetsBinding.instance.addObserver(this);
    _exams.blocksOtherSessions.addListener(_onExamStateChanged);
    unawaited(_exams.initialize());
    // Kategori ekleme/düzenleme/arşiv/sıralama sonrası liste yeniden yüklenir.
    _service.categoriesRevision.addListener(_loadCategories);
    _listenAuthChanges();
    _listenConnectivity();
    // Açılışta bulut erişilemediyse yer tutucu kategorilerle başlamış olabiliriz.
    if (_needsCategoryReload) unawaited(_loadCategories());
    unawaited(_syncPendingSessions());
    // Günlük sınır metni (seans sonucu) için puan kuralları önceden okunur.
    unawaited(_service.getPointsConfig());
    // Apple ile girilmiş oturumda Ayarlar'dan izin kaldırıldıysa tam çıkış.
    unawaited(_service.verifyAppleCredential());
    unawaited(_loadMarathonConfig());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _exams.blocksOtherSessions.removeListener(_onExamStateChanged);
    _service.categoriesRevision.removeListener(_loadCategories);
    _authSubscription?.cancel();
    unawaited(_connection.dispose());
    _cancelSyncRetry();
    super.dispose();
  }

  static bool get _isInForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null ||
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
  }

  // A new timer needs an interactive foreground. `inactive` is retained for
  // existing-session sync but cannot authorize a new focus or exam.
  static bool get _canStartInForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Ön plana dönüş: askıdayken kaçan bağlantı olayı yerine bekleyenler
        // denenir; bulut başlatılamamışsa yeniden denenir.
        _syncRetryAttempt = 0;
        if (_service.pendingSessionCount.value > 0 || !_service.isCloudActive) {
          unawaited(_syncPendingSessions());
        }
        unawaited(_service.verifyAppleCredential());
        unawaited(_service.syncDeviceTimeZone());
        unawaited(_loadMarathonConfig());
        unawaited(_exams.refresh());
      case AppLifecycleState.paused ||
          AppLifecycleState.hidden ||
          AppLifecycleState.detached:
        _cancelSyncRetry();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _listenAuthChanges() {
    if (!_service.isCloudActive || _authSubscription != null) return;
    // Oturumun düşmesi (signedOut) serviste işlenir: kullanıcı null olur ve
    // AppGate giriş ekranını gösterir.
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final session = data.session;
      if (session == null) return;
      // Girişte zaten yüklenmiş kullanıcı için yeniden okuma yapılmaz.
      final isNewSignIn =
          data.event == AuthChangeEvent.signedIn && session.user.id != _user.id;
      if (isNewSignIn || data.event == AuthChangeEvent.tokenRefreshed) {
        unawaited(_refreshUser());
        unawaited(_loadCategories());
        // Süresi dolmuş oturum yüzünden ('auth') bekleyen seanslar artık gönderilebilir.
        if (_service.pendingSessionCount.value > 0) {
          unawaited(_syncPendingSessions());
        }
      }
    }, onError: (Object e) => debugPrint('[AUTH] onAuthStateChange hatası: $e'));
  }

  void _listenConnectivity() {
    final connectivity = Connectivity();
    _connection.start(
      changes: connectivity.onConnectivityChanged,
      check: connectivity.checkConnectivity,
    );
  }

  // Bağlı görünen her olayda kuyruk (ve gerekirse bulut başlatması) denenir;
  // bağlantı geri geldiyse profil, katalog ve bağlantısız yüklenemeyen
  // ekranlar da tazelenir. "none" olayı hiçbir şeyi engellemez (bkz.
  // ConnectionWatcher).
  void _onConnectivityOnline({required bool cameOnline}) {
    if (_needsCategoryReload) unawaited(_loadCategories());
    if (cameOnline) _syncRetryAttempt = 0;
    unawaited(_syncPendingSessions());
    unawaited(_exams.refresh());
    if (cameOnline) {
      unawaited(_loadMarathonConfig());
      unawaited(_refreshUser());
      unawaited(_service.refreshAvatarCatalog());
      _service.notifyConnectionRestored();
    }
  }

  /// Bulut yoksa başlatmayı yeniden dener (bkz. SupabaseService.ensureCloud).
  /// Bulut bu kabuk açıldıktan sonra geldiyse açılışta atlanan işler bir kez
  /// yapılır: auth dinleyicisi, kategoriler, profil, avatar kataloğu ve veri
  /// ekranlarının yenilenmesi. Bulut kullanılabiliyorsa true.
  Future<bool> _ensureCloud() async {
    if (!await _service.ensureCloud()) return false;
    if (!_cloudSeen && mounted) {
      _cloudSeen = true;
      _listenAuthChanges();
      unawaited(_loadCategories());
      unawaited(_refreshUser());
      unawaited(_service.refreshAvatarCatalog());
      _service.notifyConnectionRestored();
      unawaited(_loadMarathonConfig());
    }
    return true;
  }

  /// Profili sunucudan tazeler; sonuç servisteki kullanıcıya (ve AppGate
  /// üzerinden buraya) yansır. Hata olursa mevcut kullanıcıyla devam edilir.
  Future<void> _refreshUser() async {
    if (!_service.isCloudActive) return;
    try {
      await _service.fetchCurrentUserModel();
    } catch (e) {
      debugPrint('[SHELL] Profil tazelenemedi: $e');
    }
  }

  Future<void> _loadMarathonConfig() async {
    if (_loadingMarathonConfig || !mounted || !_ownsCurrentSession) return;
    _loadingMarathonConfig = true;
    final owner = _user.id;
    try {
      final config = await _service.getMarathonConfig();
      final raw = config?['bonuses'];
      final bonuses = <int, Map<int, int>>{};
      if (raw is Map) {
        for (final minutes in [25, 50]) {
          final row = raw[minutes.toString()];
          if (row is! Map) continue;
          bonuses[minutes] = {
            for (final count in [2, 3, 4])
              if (row[count.toString()] is int &&
                  (row[count.toString()] as int) >= 0)
                count: row[count.toString()] as int,
          };
        }
      }
      final available =
          supportsMarathonPresence(config) &&
          bonuses.length == 2 &&
          bonuses.values.every((row) => row.length == 3);
      if (mounted && _ownsCurrentSession && _user.id == owner) {
        setState(() {
          _marathonAvailable = available;
          _marathonBonuses = available ? bonuses : null;
        });
      }
    } catch (e) {
      // Daha önce doğrulanmış sözleşme kısa ağ kesintisinde unutulmaz.
      debugPrint('[SHELL] Maraton ayarları okunamadı: $e');
    } finally {
      _loadingMarathonConfig = false;
    }
  }

  Future<void> _syncPendingSessions() async {
    if (!await _ensureCloud()) {
      // Bulut başlatılamadı: ön plandayken artan aralıklarla yeniden denenir
      // (önceden süreç boyunca çevrimdışı kalınıyordu).
      _scheduleSyncRetry();
      return;
    }
    _cancelSyncRetry();
    var retry = false;
    final owner = _user.id;
    try {
      final before = await _service.getPendingSessionCount();
      final result = await _service.syncPendingSessions();
      if (owner == _user.id) _queueWarningOwner = null;
      // İlerleme olduysa (ya da kuyruk boşaldıysa) bekleme aralığı baştan başlar.
      if (result.remaining < before || result.remaining == 0) {
        _syncRetryAttempt = 0;
      }
      // Gönderilen seansların puan/kum/dakika etkisi sunucudan taze okunur.
      if (result.remaining < before) await _refreshUser();
      retry = result.retryable;
    } catch (e) {
      debugPrint('[SHELL] Bekleyen seanslar gönderilemedi: $e');
      if (e is FormatException && mounted && owner == _user.id && _queueWarningOwner != owner) {
        _queueWarningOwner = owner;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.sessionRecordsUnreadable),
          duration: const Duration(seconds: 8),
        ));
      }
      retry = _service.pendingSessionCount.value > 0;
    }
    if (retry) _scheduleSyncRetry();
    await _showRejectedNotices();
  }

  /// Bekleyen seanslar için bir sonraki denemeyi kurar (30 sn → 1 dk → 2 dk
  /// … en fazla 15 dk). Yalnızca ön plandayken; arka plana geçince iptal
  /// edilir, ön plana dönüşte hemen denenir.
  void _scheduleSyncRetry() {
    if (!mounted || !_isInForeground) return;
    _syncRetryTimer?.cancel();
    final delay =
        _syncRetryDelays[math.min(
          _syncRetryAttempt,
          _syncRetryDelays.length - 1,
        )];
    _syncRetryAttempt++;
    _syncRetryTimer = Timer(delay, () {
      _syncRetryTimer = null;
      if (mounted && _isInForeground) unawaited(_syncPendingSessions());
    });
  }

  void _cancelSyncRetry() {
    _syncRetryTimer?.cancel();
    _syncRetryTimer = null;
  }

  Future<void> _showRejectedNotices() async {
    try {
      final count = await _service.takeRejectedSessionNoticeCount();
      if (count > 0 && mounted) showRejectedSessionsNotice(context, count);
    } catch (e) {
      debugPrint('[SHELL] Reddedilen seans bildirimleri okunamadı: $e');
    }
  }

  /// Kategoriler: bulut asıl kaynak; erişilemezse cihazdaki önbellek, o da
  /// yoksa yer tutucular (bkz. [loadShellCategories]).
  Future<void> _loadCategories() async {
    final result = await loadShellCategories(
      _service,
      email: _user.email,
      uid: _user.id,
      seedAttempted: _categorySeedAttempted,
    );
    _categorySeedAttempted = result.seedAttempted;
    if (mounted) setState(() => _categories = result.categories);
  }

  void _onTimerStateChanged(
    bool isRunning,
    String categoryName,
    int minutesLeft,
  ) {
    if (mounted && _isTimerRunning != isRunning) {
      setState(() => _isTimerRunning = isRunning);
    }
    if (isRunning && _focusWasReserved) {
      _focusWasReserved = false;
      return;
    }
    _queuePresence(
      () => isRunning
          ? _service.startStudySession(
              durationMinutes: minutesLeft,
              categoryName: categoryName,
            )
          : _service.cancelStudySession(),
    );
  }

  bool get _ownsCurrentSession =>
      !_isLoggingOut &&
      !_service.isDeviceSessionEnding &&
      _service.currentUser.value?.id == _user.id;

  void _onExamStateChanged() {
    if (mounted) setState(() {});
  }

  Future<bool> _canStartExam() async {
    if (!_ownsCurrentSession || _isTimerRunning || _isMarathonBreak) {
      return false;
    }
    final owner = _user.id ?? _user.email.toLowerCase();
    final record = await TimerPersistence.instance.load(owner);
    return mounted &&
        _ownsCurrentSession &&
        record == null &&
        !_isTimerRunning &&
        !_isMarathonBreak &&
        _canStartInForeground;
  }

  Future<bool> _authorizeTimerStart(
    String categoryName,
    int minutesLeft,
  ) async {
    await _exams.initialize();
    if (!_ownsCurrentSession ||
        !_canStartInForeground ||
        _exams.blocksOtherSessions.value) {
      return false;
    }
    final owner = _user.id;
    final revision = ++_presenceRevision;
    return _presenceLock.synchronized(() async {
      if (!mounted ||
          !_ownsCurrentSession ||
          _user.id != owner ||
          revision != _presenceRevision ||
          !_canStartInForeground ||
          _exams.blocksOtherSessions.value) {
        return false;
      }
      final result = await _service.authorizeStudySessionStart(
        durationMinutes: minutesLeft,
        categoryName: categoryName,
      );
      if (!mounted || !_ownsCurrentSession || _user.id != owner) return false;
      if (!_canStartInForeground ||
          revision != _presenceRevision ||
          _exams.blocksOtherSessions.value) {
        if (result.reserved) await _service.cancelStudySession();
        return false;
      }
      _focusWasReserved = result.reserved;
      return result.allowed;
    });
  }

  void _onTimerStartAborted() {
    if (!_focusWasReserved) return;
    _focusWasReserved = false;
    _queuePresence(_service.cancelStudySession);
  }

  Future<bool> _registerNewFocus(String clientUuid, int durationMinutes) async {
    final owner = _user.id;
    if (owner == null || !_ownsCurrentSession || !_canStartInForeground) return false;
    return _service.registerFocusSessionStart(
      expectedUserId: owner,
      clientUuid: clientUuid,
      durationMinutes: durationMinutes,
    );
  }

  /// Odak/mola/iptal istekleri sırayla gider. Geç kalan bir iptal, yeni
  /// molayı ya da Pomodoro'yu sunucuda silemez; eski hesap da yeni hesaba
  /// durum yazamaz. Henüz başlamamış bayat istekler atlanır.
  void _queuePresence(Future<void> Function() action) {
    final owner = _user.id;
    final revision = ++_presenceRevision;
    unawaited(
      _presenceLock.synchronized(() async {
        if (!mounted ||
            !_ownsCurrentSession ||
            _user.id != owner ||
            revision != _presenceRevision) {
          return;
        }
        try {
          await action();
        } catch (e) {
          debugPrint('[SHELL] Sosyal çalışma durumu güncellenemedi: $e');
        }
      }),
    );
  }

  void _onMarathonBreakChanged(bool isOnBreak, int secondsLeft) {
    if (mounted && _isMarathonBreak != isOnBreak) {
      setState(() => _isMarathonBreak = isOnBreak);
    }
    if (!isOnBreak && _focusWasReserved) return;
    final endsAt = DateTime.now().add(Duration(seconds: secondsLeft));
    _queuePresence(() async {
      if (isOnBreak && secondsLeft > 0) {
        await _service.startStudyBreak(endsAt: endsAt);
      } else {
        await _service.cancelStudySession();
      }
    });
  }

  /// Seans önce cihazdaki kuyruğa yazılır, sonra (bekleyen eski seanslarla
  /// birlikte, başlangıç sırasıyla) gönderilir. Başarıda servis kullanıcıyı
  /// günceller. Sonucu (puan, kum, seri, kuyruk ya da ret nedeni) sayaç
  /// ekranının seans sonu diyaloğu gösterir.
  Future<SessionSubmitResult?> _onSessionCompleted(
    ActiveTimerSession session,
  ) async {
    if (!_ownsCurrentSession) return null;
    if (session.isQuickTest) {
      return const SessionSubmitRejected(SessionReason.invalidData);
    }
    final result = await _service.submitCompletedSession(
      clientUuid: session.clientUuid,
      categoryId: session.categoryId,
      categoryName: session.categoryName,
      durationMinutes: session.durationMinutes,
      wasPaused: session.wasPaused,
      foregroundSeconds: session.foregroundSeconds,
      startedAt: session.startedAt,
      recordAccelerated: session.recordAccelerated,
      marathonUuid: session.marathon?.marathonUuid,
      marathonTargetSessions: session.marathon?.totalSessions,
      marathonSessionIndex: session.marathon?.sessionIndex,
    );
    if (!mounted) return result;
    // Ağ/sunucu yüzünden kuyrukta kaldıysa kendiliğinden yeniden denenir
    // (yalnızca çakışma nedeniyle bekleyen seans için anlamsız).
    if (result is SessionSubmitQueued &&
        result.reasonCode != SessionReason.overlap) {
      _scheduleSyncRetry();
    }
    unawaited(_showRejectedNotices());
    return result;
  }

  Future<bool> _onConfirmMarathonPresence(
    ActiveTimerSession previous,
    String nextUuid,
  ) async {
    final plan = previous.marathon;
    if (!_ownsCurrentSession || plan == null || !_isInForeground) return false;
    final owner = _user.id;
    _marathonConfirmedAt = null;
    _marathonConfirmedUuid = null;
    if (_exams.blocksOtherSessions.value) return false;
    final confirmed = await _service.confirmMarathonPresence(
      marathonUuid: plan.marathonUuid,
      completedSessionIndex: plan.completedSessions,
      previousClientUuid: previous.clientUuid,
      nextClientUuid: nextUuid,
      onConfirmed: (at) {
        _marathonConfirmedAt = at;
        _marathonConfirmedUuid = nextUuid;
      },
    );
    if (!confirmed || !mounted || !_ownsCurrentSession || !_isInForeground) {
      return false;
    }
    final authorized = await _authorizeTimerStart(
      previous.categoryName,
      previous.durationMinutes,
    );
    return authorized &&
        mounted &&
        _ownsCurrentSession &&
        _user.id == owner &&
        _isInForeground;
  }

  bool _marathonPresenceStillValid(String uuid) {
    final confirmedAt = _marathonConfirmedAt;
    if (confirmedAt == null || _marathonConfirmedUuid != uuid ||
        !_ownsCurrentSession || !_isInForeground) {
      return false;
    }
    final elapsed = _service.marathonServerNow.difference(confirmedAt);
    return !elapsed.isNegative && elapsed < const Duration(seconds: 10);
  }

  Future<void> _logout() async {
    // Süren seans kullanıcıya bağlı olarak cihazda kalır (aynı hesapla
    // girişte sürer); canlı listeden çıkılır, bekleyen bildirim iptal edilir
    // ve kilit ekranı sayacı kaldırılır.
    _isLoggingOut = true;
    _presenceRevision++;
    await _presenceLock.synchronized(_service.cancelStudySession);
    await NotificationService.instance.cancelSessionEndNotification();
    await NotificationService.instance.cancelMarathonBreakEnd();
    await LockScreenTimer.instance.clear();
    await _service.signOutFully();
  }

  // Tablette ve yatay telefonda sayfa genişliğe yayılmaz (bkz. showFriendsSheet).
  void _openFriendsSheet() => unawaited(showFriendsSheet(context));

  // Profil, kullanıcıyı SupabaseService.currentUser'dan okur; isim, avatar ve
  // bakiye değişiklikleri oradan AppGate üzerinden buraya yansır.
  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          onDarkModeChanged: ThemeController.instance.setDarkMode,
          onLogout: _logout,
        ),
      ),
    );
  }

  // Android geri tuşu/hareketi: önce ilk sekmeye dön; seans sürüyorsa
  // uygulamayı uyarısız kapatma.
  Future<void> _onBackPressed() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return;
    }
    if (!_isTimerRunning &&
        !_isMarathonBreak &&
        !_exams.blocksOtherSessions.value) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(l10n.leaveWhileRunningTitle),
        content: Text(l10n.leaveWhileRunningBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.leaveWhileRunningStay),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.leaveWhileRunningLeave),
          ),
        ],
      ),
    );
    // Seans cihazda saklı: uygulama kapansa da açılınca kaldığı yerden sürer.
    if (leave == true) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    // Yatay Pomo yalnız animasyon, sayaç ve seans kontrollerini gösterir.
    // Duraklatma/mola sırasında da kabuk geri gelerek düzeni değiştirmez.
    final hideUI = isLandscape && _currentIndex == 0;
    final ownerEmail = user.email.toLowerCase();

    final screens = [
      TimerScreen(
        categories: _categories,
        sessionOwnerKey: user.id ?? ownerEmail,
        legacySessionOwnerKey: ownerEmail,
        isSessionActive: () => _ownsCurrentSession,
        authorizeStart: _authorizeTimerStart,
        registerNewFocus: _registerNewFocus,
        onStartAborted: _onTimerStartAborted,
        onOpenSettings: _openProfile,
        onTimerStateChanged: _onTimerStateChanged,
        onMarathonBreakChanged: _onMarathonBreakChanged,
        onConfirmMarathonPresence: _onConfirmMarathonPresence,
        marathonPresenceStillValid: _marathonPresenceStillValid,
        marathonAvailable: _marathonAvailable,
        marathonBonuses: _marathonBonuses,
        onSessionCompleted: _onSessionCompleted,
        userSegment: user.userSegment,
      ),
      ReportsScreen(
        categories: _categories,
        examService: _exams,
        loadExamStudySessions: _service.fetchStudySessions,
        onStartTimer: () => setState(() => _currentIndex = 0),
        loadExamAttempts: () async {
          await _exams.refresh();
          return _exams.attempts;
        },
        isExamHistoryStale: () => _exams.historyIsStale,
        onOpenExams: () => setState(() {
          _examHistoryRequest++;
          _currentIndex = 4;
        }),
      ),
      RankingScreen(currentUser: user),
      const SocialScreen(),
      ExamScreen(
        service: _exams,
        userSegment: user.userSegment,
        openHistoryRequest: _examHistoryRequest,
        canStart: () =>
            !_isTimerRunning && !_isMarathonBreak && _ownsCurrentSession,
        canStartAsync: _canStartExam,
        loadStudySessions: _service.fetchStudySessions,
      ),
    ];

    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, _) {
        final lang = LanguageService.instance;

        return PopScope(
          canPop:
              _currentIndex == 0 &&
              !_isTimerRunning &&
              !_isMarathonBreak &&
              !_exams.blocksOtherSessions.value,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_onBackPressed());
          },
          // Dikey telefonda alt çubuk; tablette ve yatay telefonda solda ray.
          child: ShellNavigationScaffold(
            showNavigation: !hideUI,
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) =>
                setState(() => _currentIndex = index),
            destinations: [
              const ShellDestination(
                icon: Icons.timer_outlined,
                selectedIcon: Icons.timer,
                label: 'Pomo',
              ),
              ShellDestination(
                icon: Icons.analytics_outlined,
                selectedIcon: Icons.analytics,
                label: lang.translate('nav_reports'),
              ),
              ShellDestination(
                icon: Icons.leaderboard_outlined,
                selectedIcon: Icons.leaderboard,
                label: lang.translate('nav_ranking'),
              ),
              ShellDestination(
                icon: Icons.groups_outlined,
                selectedIcon: Icons.groups,
                label: lang.translate('nav_social'),
              ),
              ShellDestination(
                icon: Icons.assignment_outlined,
                selectedIcon: Icons.assignment,
                label: AppLocalizations.of(context)!.examTab,
              ),
            ],
            appBar: hideUI
                ? null
                : buildShellAppBar(
                    context,
                    // Seri 04:00 gün dönümünde sekme değişmeden de tazelenir.
                    streakDays: null,
                    streakAt: _currentIndex == 0 ? user.streakOn : null,
                    points: user.lifetimePoints,
                    coins: user.coins,
                    onStatsTap: () => showLeagueInfoSheet(context),
                    onFriendsTap: _openFriendsSheet,
                    onProfileTap: _openProfile,
                    avatarBuilder: (size) => AvatarWidget(
                      avatar: AvatarCharacter.byId(user.avatarId),
                      size: size,
                    ),
                  ),
            body: Column(
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: _service.pendingSessionCount,
                  builder: (context, count, _) => count > 0 && !hideUI
                      ? ShellPendingBanner(
                          count: count,
                          onTap: _syncPendingSessions,
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  // Sekmeler canlı tutulur (sayaç kesilmez); görünmeyen
                  // sekmelerde animasyon ve periyodik yenileme durur.
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      for (var i = 0; i < screens.length; i++)
                        TickerMode(
                          enabled: i == _currentIndex,
                          child: screens[i],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Kabuğun gösterdiği kategoriler: bulut asıl kaynak; erişilemezse cihazdaki
/// önbellek, o da yoksa yer tutucular. Buluta yerel veri yazılmaz (başka
/// cihazdaki değişiklikleri ezebilir); tek istisna HİÇ kategorisi (arşiv
/// dahil) olmayan hesap. [seedAttempted] tur başına tek tohumlama denemesini
/// izler.
@visibleForTesting
Future<({List<CourseCategory> categories, bool seedAttempted})>
loadShellCategories(
  SupabaseService service, {
  required String email,
  String? uid,
  required bool seedAttempted,
}) async {
  var attempted = seedAttempted;
  List<CourseCategory>? cloud;
  if (service.isCloudActive) {
    try {
      final active = await service.fetchUserCategories();
      if (active.isNotEmpty || attempted) {
        cloud = active;
      } else {
        attempted = true;
        // Kategorileri arşivde duran hesapta boş aktif liste geçerlidir:
        // arşivlenen kategori geri getirilmez, kopyası açılmaz. Yalnızca hiç
        // kategorisi olmayan hesapta yerel liste (yoksa varsayılanlar)
        // sunucuda oluşturulur; kimlikleri sunucu üretir. Tur başına bir kez.
        final all = await service.fetchUserCategories(includeArchived: true);
        cloud = all.isNotEmpty
            ? active
            : await service.ensureServerCategories(
                await CategoryCache.read(email, uid: uid) ?? const [],
              );
      }
    } catch (e) {
      debugPrint(
        '[SHELL] Kategoriler buluttan alınamadı, önbelleğe düşülüyor: $e',
      );
      cloud = null;
    }
  }
  final List<CourseCategory> categories;
  if (cloud != null) {
    // Başarılı bulut yanıtı (boş olsa da) önbelleği ezer: önbellekte aktif
    // görünen ama sunucuda arşivlenmiş kategori sayaçta seçilemez.
    await CategoryCache.write(email, cloud, uid: uid);
    categories = cloud;
  } else {
    categories =
        await CategoryCache.read(email, uid: uid) ??
        CourseCategory.initialCategories();
  }
  return (categories: categories, seedAttempted: attempted);
}
