import 'dart:async';

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
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../services/timer_persistence.dart';
import '../theme.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/league_info_sheet.dart';
import '../widgets/shell_pending_banner.dart';
import '../widgets/shell_stat_pill.dart';
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

class _MainNavigationShellState extends State<MainNavigationShell> {
  final SupabaseService _service = SupabaseService.instance;
  int _currentIndex = 0;
  late List<CourseCategory> _categories;
  bool _isTimerRunning = false;
  bool _wasOffline = false;
  bool _categorySeedAttempted = false;

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  UserModel get _user => widget.user;

  bool get _needsCategoryReload =>
      _categories.isEmpty || _categories.any((c) => !SupabaseService.isServerCategoryId(c.id));

  @override
  void initState() {
    super.initState();
    _categories = List.of(widget.initialCategories);
    // Kategori ekleme/düzenleme/arşiv/sıralama sonrası liste yeniden yüklenir.
    _service.categoriesRevision.addListener(_loadCategories);
    _listenAuthChanges();
    _listenConnectivity();
    // Açılışta bulut erişilemediyse yer tutucu kategorilerle başlamış olabiliriz.
    if (_needsCategoryReload) unawaited(_loadCategories());
    unawaited(_syncPendingSessions());
  }

  @override
  void dispose() {
    _service.categoriesRevision.removeListener(_loadCategories);
    _authSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
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
    try {
      final before = await _service.getPendingSessionCount();
      final remaining = await _service.syncPendingSessions();
      // Gönderilen seansların puan/kum/dakika etkisi sunucudan taze okunur.
      if (remaining < before) await _refreshUser();
    } catch (e) {
      debugPrint('[SHELL] Bekleyen seanslar gönderilemedi: $e');
    }
    await _showRejectedNotices();
  }

  Future<void> _showRejectedNotices() async {
    final count = await _service.takeRejectedSessionNoticeCount();
    if (count > 0 && mounted) showRejectedSessionsNotice(context, count);
  }

  /// Kategoriler: bulut asıl kaynak; erişilemezse cihazdaki önbellek, o da
  /// yoksa yer tutucular. Buluta yerel veri yazılmaz (başka cihazdaki
  /// değişiklikleri ezebilir); tek istisna hiç aktif kategorisi olmayan hesap.
  Future<void> _loadCategories() async {
    final email = _user.email;
    var categories = await _fetchCloudCategories();
    if (categories != null && categories.isNotEmpty) {
      await CategoryCache.write(email, categories);
    } else {
      categories = await CategoryCache.read(email) ?? CourseCategory.initialCategories();
    }
    if (mounted) setState(() => _categories = categories!);
  }

  Future<List<CourseCategory>?> _fetchCloudCategories() async {
    if (!_service.isCloudActive) return null;
    try {
      final cloud = await _service.fetchUserCategories();
      if (cloud.isNotEmpty || _categorySeedAttempted) return cloud;
      // Onboarding'i bitmiş kullanıcının bulutta aktif kategorisi yoksa yerel
      // liste sunucuda oluşturulur (kimlikleri sunucu üretir); yer tutucu
      // kimliklerle kalınmaz. Tur başına bir kez denenir.
      _categorySeedAttempted = true;
      return await _service.ensureServerCategories(await CategoryCache.read(_user.email) ?? const []);
    } catch (e) {
      debugPrint('[SHELL] Kategoriler buluttan alınamadı, önbelleğe düşülüyor: $e');
      return null;
    }
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
    await _showRejectedNotices();
  }

  Future<void> _logout() async {
    // Süren seans kullanıcıya bağlı olarak cihazda kalır (aynı hesapla
    // girişte sürer); canlı listeden çıkılır ve bekleyen bildirim iptal edilir.
    if (_isTimerRunning) await _service.cancelStudySession();
    await NotificationService.instance.cancelSessionEndNotification();
    await _service.signOutFully();
  }

  void _openFriendsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FriendsSheet(),
    );
  }

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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
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
        final l10n = AppLocalizations.of(context)!;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return PopScope(
          canPop: _currentIndex == 0 && !_isTimerRunning,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_onBackPressed());
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: hideUI
                ? null
                : AppBar(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    toolbarHeight: 76,
                    titleSpacing: 16,
                    // Seri yalnızca Pomo sekmesinde gösterilir.
                    title: _currentIndex == 0
                        ? FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 24),
                                const SizedBox(width: 6),
                                Text(
                                  '${user.streakDays}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkPrimary : AppColors.primary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                    actions: [
                      // Puan + Kum Tanesi rozetleri: dar ekranda kendi içinde
                      // yatay kaydırılır; arkadaş/profil düğmeleri etkilenmez.
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ShellStatPill(
                                label: l10n.pointsCaption,
                                value: user.lifetimePoints,
                                background: AppColors.primaryFixed,
                                foreground: AppColors.onPrimaryFixed,
                                onTap: () => showLeagueInfoSheet(context),
                              ),
                              const SizedBox(width: 8),
                              ShellStatPill(
                                label: l10n.coinsCaption,
                                value: user.coins,
                                background: const Color(0xFFFFE7A8),
                                foreground: const Color(0xFF7A5A00),
                                onTap: () => showLeagueInfoSheet(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Arkadaş Ekle/Görüntüle Butonu (Dairesel, avatardan biraz büyük)
                      InkWell(
                        onTap: _openFriendsSheet,
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          width: 63,
                          height: 63,
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryContainer.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.people_alt_rounded,
                            color: AppColors.primaryContainer,
                            size: 33,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Profil avatarı (Profil & Ayarlar'ı açar)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: GestureDetector(
                          onTap: _openProfile,
                          child: AvatarWidget(
                            avatar: AvatarCharacter.byId(user.avatarId),
                            size: 60,
                          ),
                        ),
                      ),
                    ],
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
            bottomNavigationBar: hideUI
                ? null
                : NavigationBar(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) {
                      if (index == _currentIndex) return;
                      setState(() => _currentIndex = index);
                    },
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    indicatorColor: AppColors.primaryFixed,
                    elevation: 4,
                    height: 68,
                    destinations: [
                      const NavigationDestination(
                        icon: Icon(Icons.timer_outlined),
                        selectedIcon: Icon(Icons.timer, color: AppColors.onPrimaryFixed),
                        label: 'Pomo',
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.analytics_outlined),
                        selectedIcon: const Icon(Icons.analytics, color: AppColors.onPrimaryFixed),
                        label: lang.translate('nav_reports'),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.leaderboard_outlined),
                        selectedIcon: const Icon(Icons.leaderboard, color: AppColors.onPrimaryFixed),
                        label: lang.translate('nav_ranking'),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.groups_outlined),
                        selectedIcon: const Icon(Icons.groups, color: AppColors.onPrimaryFixed),
                        label: lang.translate('nav_social'),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
