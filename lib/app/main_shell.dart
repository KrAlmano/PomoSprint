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
import '../services/language_service.dart';
import '../services/lock_screen_timer.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../services/timer_persistence.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/league_info_sheet.dart';
import '../widgets/shell_app_bar.dart';
import '../widgets/shell_navigation.dart';
import '../widgets/shell_pending_banner.dart';
import 'category_cache.dart';
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

class _MainNavigationShellState extends State<MainNavigationShell> with WidgetsBindingObserver {
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
  int _currentIndex = 0;
  late List<CourseCategory> _categories;
  bool _isTimerRunning = false;
  bool _wasOffline = false;
  bool _categorySeedAttempted = false;

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncRetryTimer;
  int _syncRetryAttempt = 0;

  UserModel get _user => widget.user;

  bool get _needsCategoryReload =>
      _categories.isEmpty || _categories.any((c) => !SupabaseService.isServerCategoryId(c.id));

  @override
  void initState() {
    super.initState();
    _categories = List.of(widget.initialCategories);
    WidgetsBinding.instance.addObserver(this);
    // Kategori ekleme/düzenleme/arşiv/sıralama sonrası liste yeniden yüklenir.
    _service.categoriesRevision.addListener(_loadCategories);
    _listenAuthChanges();
    _listenConnectivity();
    // Açılışta bulut erişilemediyse yer tutucu kategorilerle başlamış olabiliriz.
    if (_needsCategoryReload) unawaited(_loadCategories());
    unawaited(_syncPendingSessions());
    // Günlük sınır metni (seans sonucu) için puan kuralları önceden okunur.
    unawaited(_service.getPointsConfig());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.categoriesRevision.removeListener(_loadCategories);
    _authSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _cancelSyncRetry();
    super.dispose();
  }

  static bool get _isInForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Ön plana dönüş: askıdayken kaçan bağlantı olayı yerine bekleyenler denenir.
        _syncRetryAttempt = 0;
        if (_service.pendingSessionCount.value > 0) unawaited(_syncPendingSessions());
      case AppLifecycleState.paused || AppLifecycleState.hidden || AppLifecycleState.detached:
        _cancelSyncRetry();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _listenAuthChanges() {
    if (!_service.isCloudActive) return;
    // Oturumun düşmesi (signedOut) serviste işlenir: kullanıcı null olur ve
    // AppGate giriş ekranını gösterir.
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final session = data.session;
        if (session == null) return;
        // Girişte zaten yüklenmiş kullanıcı için yeniden okuma yapılmaz.
        final isNewSignIn = data.event == AuthChangeEvent.signedIn && session.user.id != _user.id;
        if (isNewSignIn || data.event == AuthChangeEvent.tokenRefreshed) {
          unawaited(_refreshUser());
          unawaited(_loadCategories());
          // Süresi dolmuş oturum yüzünden ('auth') bekleyen seanslar artık gönderilebilir.
          if (_service.pendingSessionCount.value > 0) unawaited(_syncPendingSessions());
        }
      },
      onError: (Object e) => debugPrint('[AUTH] onAuthStateChange hatası: $e'),
    );
  }

  void _listenConnectivity() {
    final connectivity = Connectivity();
    _connectivitySubscription = connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    unawaited(_readInitialConnectivity(connectivity));
  }

  Future<void> _readInitialConnectivity(Connectivity connectivity) async {
    try {
      _wasOffline = (await connectivity.checkConnectivity()).contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('[SHELL] Bağlantı durumu okunamadı: $e');
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final offline = results.contains(ConnectivityResult.none);
    final cameOnline = !offline && _wasOffline;
    _wasOffline = offline;
    if (offline) return;
    if (_needsCategoryReload) unawaited(_loadCategories());
    if (cameOnline) _syncRetryAttempt = 0;
    unawaited(_syncPendingSessions());
    if (cameOnline) {
      unawaited(_refreshUser());
      unawaited(_service.refreshAvatarCatalog());
    }
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

  Future<void> _syncPendingSessions() async {
    if (!_service.isCloudActive) return;
    _cancelSyncRetry();
    var retry = false;
    try {
      final before = await _service.getPendingSessionCount();
      final result = await _service.syncPendingSessions();
      // İlerleme olduysa (ya da kuyruk boşaldıysa) bekleme aralığı baştan başlar.
      if (result.remaining < before || result.remaining == 0) _syncRetryAttempt = 0;
      // Gönderilen seansların puan/kum/dakika etkisi sunucudan taze okunur.
      if (result.remaining < before) await _refreshUser();
      retry = result.retryable;
    } catch (e) {
      debugPrint('[SHELL] Bekleyen seanslar gönderilemedi: $e');
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
    final delay = _syncRetryDelays[math.min(_syncRetryAttempt, _syncRetryDelays.length - 1)];
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
    final count = await _service.takeRejectedSessionNoticeCount();
    if (count > 0 && mounted) showRejectedSessionsNotice(context, count);
  }

  /// Kategoriler: bulut asıl kaynak; erişilemezse cihazdaki önbellek, o da
  /// yoksa yer tutucular (bkz. [loadShellCategories]).
  Future<void> _loadCategories() async {
    final result = await loadShellCategories(
      _service,
      email: _user.email,
      seedAttempted: _categorySeedAttempted,
    );
    _categorySeedAttempted = result.seedAttempted;
    if (mounted) setState(() => _categories = result.categories);
  }

  void _onTimerStateChanged(bool isRunning, String categoryName, int minutesLeft) {
    if (mounted && _isTimerRunning != isRunning) setState(() => _isTimerRunning = isRunning);
    if (isRunning) {
      unawaited(_service.startStudySession(durationMinutes: minutesLeft, categoryName: categoryName));
    } else {
      unawaited(_service.cancelStudySession());
    }
  }

  /// Seans önce cihazdaki kuyruğa yazılır, sonra (bekleyen eski seanslarla
  /// birlikte, başlangıç sırasıyla) gönderilir. Başarıda servis kullanıcıyı
  /// günceller.
  Future<void> _onSessionCompleted(ActiveTimerSession session) async {
    final result = await _service.submitCompletedSession(
      clientUuid: session.clientUuid,
      categoryId: session.categoryId,
      categoryName: session.categoryName,
      durationMinutes: session.durationMinutes,
      wasPaused: session.wasPaused,
      foregroundSeconds: session.foregroundSeconds,
      startedAt: session.startedAt,
    );
    if (!mounted) return;
    showSessionResult(context, result);
    // Ağ/sunucu yüzünden kuyrukta kaldıysa kendiliğinden yeniden denenir
    // (yalnızca çakışma nedeniyle bekleyen seans için anlamsız).
    if (result is SessionSubmitQueued && result.reasonCode != SessionReason.overlap) _scheduleSyncRetry();
    await _showRejectedNotices();
  }

  Future<void> _logout() async {
    // Süren seans kullanıcıya bağlı olarak cihazda kalır (aynı hesapla
    // girişte sürer); canlı listeden çıkılır, bekleyen bildirim iptal edilir
    // ve kilit ekranı sayacı kaldırılır.
    if (_isTimerRunning) await _service.cancelStudySession();
    await NotificationService.instance.cancelSessionEndNotification();
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
    if (!_isTimerRunning) return;
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
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final hideUI = isLandscape && _isTimerRunning && _currentIndex == 0;
    final ownerEmail = user.email.toLowerCase();

    final screens = [
      TimerScreen(
        categories: _categories,
        sessionOwnerKey: user.id ?? ownerEmail,
        legacySessionOwnerKey: ownerEmail,
        onOpenSettings: _openProfile,
        onTimerStateChanged: _onTimerStateChanged,
        onSessionCompleted: _onSessionCompleted,
        userSegment: user.userSegment,
      ),
      ReportsScreen(
        categories: _categories,
        onStartTimer: () => setState(() => _currentIndex = 0),
      ),
      RankingScreen(currentUser: user),
      const SocialScreen(),
    ];

    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, _) {
        final lang = LanguageService.instance;

        return PopScope(
          canPop: _currentIndex == 0 && !_isTimerRunning,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_onBackPressed());
          },
          // Dikey telefonda alt çubuk; tablette ve yatay telefonda solda ray.
          child: ShellNavigationScaffold(
            showNavigation: !hideUI,
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            destinations: [
              const ShellDestination(icon: Icons.timer_outlined, selectedIcon: Icons.timer, label: 'Pomo'),
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
                  builder: (context, count, _) => count > 0
                      ? ShellPendingBanner(count: count, onTap: _syncPendingSessions)
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  // Sekmeler canlı tutulur (sayaç kesilmez); görünmeyen
                  // sekmelerde animasyon ve periyodik yenileme durur.
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      for (var i = 0; i < screens.length; i++)
                        TickerMode(enabled: i == _currentIndex, child: screens[i]),
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
Future<({List<CourseCategory> categories, bool seedAttempted})> loadShellCategories(
  SupabaseService service, {
  required String email,
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
            : await service.ensureServerCategories(await CategoryCache.read(email) ?? const []);
      }
    } catch (e) {
      debugPrint('[SHELL] Kategoriler buluttan alınamadı, önbelleğe düşülüyor: $e');
      cloud = null;
    }
  }
  final List<CourseCategory> categories;
  if (cloud != null) {
    // Başarılı bulut yanıtı (boş olsa da) önbelleği ezer: önbellekte aktif
    // görünen ama sunucuda arşivlenmiş kategori sayaçta seçilemez.
    await CategoryCache.write(email, cloud);
    categories = cloud;
  } else {
    categories = await CategoryCache.read(email) ?? CourseCategory.initialCategories();
  }
  return (categories: categories, seedAttempted: attempted);
}
