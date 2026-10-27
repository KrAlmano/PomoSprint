import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/avatar_model.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/social/load_error_view.dart';
import '../widgets/social/presence_dot.dart';
import '../widgets/social/user_safety.dart';
import '../services/hidden_users.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import '../utils/responsive.dart';

class SocialScreen extends StatefulWidget {
  final SupabaseService? service;
  const SocialScreen({super.key, this.service});

  @visibleForTesting
  static bool isOnBreak(Map<String, dynamic> user) => user['status'] == 'break';

  static bool isTakingExam(Map<String, dynamic> user) =>
      user['status'] == 'exam';

  /// Eski focus-only RPC'de status yoktur. Odak ve mola aynı listede
  /// görünür; bilinmeyen durumlar görünür bir çalışma gibi yorumlanmaz.
  @visibleForTesting
  static List<Map<String, dynamic>> visibleFriends(
    List<Map<String, dynamic>> rows,
  ) => [
    for (final row in rows)
      if (row['status'] == null ||
          row['status'] == 'focus' ||
          isOnBreak(row) ||
          isTakingExam(row))
        row,
  ];

  /// Canlı akıştan kullanıcının gizlediği kişiler çıkarılır.
  @visibleForTesting
  static List<Map<String, dynamic>> withoutHidden(
    List<Map<String, dynamic>> rows,
    HiddenUserList hidden,
  ) {
    if (hidden.isEmpty) return rows;
    return [
      for (final r in rows)
        if (!hidden.isHidden(
          id: r['id']?.toString(),
          name: r['name']?.toString(),
        ))
          r,
    ];
  }

  /// Tek seans ve Maraton odağı aynı etiketi kullanır. Mola yalnız
  /// sunucunun açık break durumunda gösterilir; eski yanıtlar odaktır.
  @visibleForTesting
  static String liveStatusText(
    Map<String, dynamic> user,
    AppLocalizations l10n,
  ) => isOnBreak(user)
      ? l10n.socialOnBreak
      : isTakingExam(user)
      ? l10n.socialTakingExam
      : l10n.socialFocusing;

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen>
    with WidgetsBindingObserver {
  SupabaseService get _service => widget.service ?? SupabaseService.instance;
  static const Duration _pollInterval = Duration(seconds: 30);

  List<Map<String, dynamic>> _activeUsers = const [];
  Timer? _pollingTimer;
  bool _loaded = false;
  Object? _error;
  int _requestId = 0;
  bool _isVisible = false;
  bool _isResumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service.addStatsChangedListener(_onStatsChanged);
    HiddenUsersStore.instance.hidden.addListener(_onHiddenUsersChanged);
  }

  void _onStatsChanged() {
    if (_isVisible && _isResumed) unawaited(_fetchData());
  }

  void _onHiddenUsersChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Shell görünmeyen sekmeyi TickerMode(enabled: false) ile sarar.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _isVisible) {
      _isVisible = visible;
      _updatePolling();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isResumed = state == AppLifecycleState.resumed;
    _updatePolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.removeStatsChangedListener(_onStatsChanged);
    HiddenUsersStore.instance.hidden.removeListener(_onHiddenUsersChanged);
    _pollingTimer?.cancel();
    super.dispose();
  }

  // Canlı liste yalnızca sekme görünür ve uygulama ön plandayken yoklanır;
  // geri dönüldüğünde hemen yenilenir (kısa seanslar da görünür).
  void _updatePolling() {
    if (!_isVisible || !_isResumed) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
      return;
    }
    if (_pollingTimer != null) return;
    unawaited(_fetchData());
    _pollingTimer = Timer.periodic(_pollInterval, (_) => _fetchData());
  }

  Future<void> _fetchData() async {
    final requestId = ++_requestId;
    // Gizlenen kullanıcılar oturumdaki hesaba bağlı.
    unawaited(HiddenUsersStore.instance.load(_service.currentUser.value?.id));
    try {
      final live = await _service.getLiveFriends();
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _activeUsers = _dedupeById(live);
        _loaded = true;
        _error = null;
      });
    } catch (e) {
      debugPrint('[SOCIAL] Canlı liste alınamadı: $e');
      if (!mounted || requestId != _requestId) return;
      // Yenileme başarısız: mevcut liste korunur.
      setState(() => _error = e);
    }
  }

  // Eski get_live_friends iki yönlü arkadaşlıkta aynı kişiyi iki kez döndürebiliyordu.
  static List<Map<String, dynamic>> _dedupeById(
    List<Map<String, dynamic>> rows,
  ) {
    final seen = <String>{};
    return [
      for (final r in rows)
        if (r['id'] == null || seen.add(r['id'].toString())) r,
    ];
  }

  void _openUserActions(Map<String, dynamic> user, AppLocalizations l10n) {
    unawaited(
      showUserSafetySheet(
        context,
        target: UserSafetyTarget(
          name: user['name']?.toString() ?? l10n.userDefault,
          userId: user['id']?.toString(),
          avatarId: user['avatar_id']?.toString(),
        ),
        place: UserReportPlace.liveFeed,
        service: _service,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppColors.darkSurface : AppColors.surface;

    if (!_loaded && _error == null) {
      return Scaffold(
        backgroundColor: background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        // Liste tam genişlikte kaydırılır (kenarlardan da kaydırma ve
        // yenileme çalışır); içerik geniş ekranda okunabilir genişlikte
        // ortalanır.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(
              20.0,
              (constraints.maxWidth - ContentWidth.reading) / 2,
            );
            // Yatay telefonda büyük yazı başlığın tüm yüksekliği
            // almasına yol açabilir. Bu düzende başlık da listeyle kayar;
            // arkadaş satırları kullanılabilir ekranın tamamını kullanır.
            final scrollHeader = Responsive.of(context).isShortHeight;
            final header = _buildHeader(l10n, isDark, side);
            return Column(
              children: [
                if (!scrollHeader) header,
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchData,
                    color: AppColors.primary,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        if (scrollHeader) SliverToBoxAdapter(child: header),
                        ..._buildSlivers(l10n, isDark, side),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, bool isDark, double side) =>
      Padding(
        padding: EdgeInsets.fromLTRB(side, 20, side, 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.socialYourFriends,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ),
          ),
        ),
      );

  List<Widget> _buildSlivers(AppLocalizations l10n, bool isDark, double side) {
    if (!_loaded) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: side, vertical: 20),
              child: LoadErrorView(
                message: l10n.socialLoadError,
                onRetry: _fetchData,
              ),
            ),
          ),
        ),
      ];
    }

    final staleNotice = SliverPadding(
      padding: EdgeInsets.fromLTRB(side, 8, side, 0),
      sliver: SliverToBoxAdapter(child: StaleDataNotice(onRetry: _fetchData)),
    );

    final users = SocialScreen.visibleFriends(
      SocialScreen.withoutHidden(
        _activeUsers,
        HiddenUsersStore.instance.hidden.value,
      ),
    );
    if (users.isEmpty) {
      return [
        if (_error != null) staleNotice,
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyState(l10n, isDark),
        ),
      ];
    }

    return [
      if (_error != null) staleNotice,
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: side),
        sliver: SliverList.builder(
          itemCount: users.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildActiveUserItem(users[index], l10n, isDark),
          ),
        ),
      ),
      const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
    ];
  }

  Widget _buildActiveUserItem(
    Map<String, dynamic> user,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final name = user['name']?.toString() ?? l10n.userDefault;

    final card = Container(
      key: ValueKey('social-friend-${user['id'] ?? name}'),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLowest
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          AvatarWidget(
            avatar: AvatarCharacter.byId(user['avatar_id']?.toString()),
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark
                        ? AppColors.darkOnSurface
                        : AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        SocialScreen.liveStatusText(user, l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkOnSurfaceVariant
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SocialPresenceDot(onBreak: SocialScreen.isOnBreak(user)),
                  ],
                ),
              ],
            ),
          ),
          UserActionsButton(onPressed: () => _openUserActions(user, l10n)),
        ],
      ),
    );
    return GestureDetector(
      onLongPress: () => _openUserActions(user, l10n),
      child: card,
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_outlined,
                size: 48,
                color: isDark
                    ? AppColors.darkPrimary
                    : AppColors.primaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.socialNoLiveFriends,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
