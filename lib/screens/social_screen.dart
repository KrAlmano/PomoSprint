import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/avatar_model.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/social/load_error_view.dart';
import '../widgets/social/user_safety.dart';
import '../services/hidden_users.dart';
import '../services/language_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import '../utils/responsive.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  /// Canlı akıştan kullanıcının gizlediği kişiler çıkarılır.
  @visibleForTesting
  static List<Map<String, dynamic>> withoutHidden(List<Map<String, dynamic>> rows, HiddenUserList hidden) {
    if (hidden.isEmpty) return rows;
    return [
      for (final r in rows)
        if (!hidden.isHidden(id: r['id']?.toString(), name: r['name']?.toString())) r,
    ];
  }

  /// Canlı çalışan satırının alt yazısı; hazır kategori adı arayüz dilinde
  /// ('Fizik' İngilizce arayüzde 'Physics').
  @visibleForTesting
  static String liveStatusText(Map<String, dynamic> user, AppLocalizations l10n) {
    final category = (user['category_name'] ?? user['active_session_category_name'])?.toString().trim() ?? '';
    return category.isEmpty
        ? l10n.socialFocusing
        : l10n.socialFocusingOn(LanguageService.instance.translateCatName(category));
  }

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> with WidgetsBindingObserver {
  static const Duration _pollInterval = Duration(seconds: 30);

  List<Map<String, dynamic>> _activeUsers = const [];
  Timer? _pollingTimer;
  bool _loaded = false;
  Object? _error;
  DateTime? _loadedAt;
  int _requestId = 0;
  bool _isVisible = false;
  bool _isResumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HiddenUsersStore.instance.hidden.addListener(_onHiddenUsersChanged);
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
    HiddenUsersStore.instance.hidden.removeListener(_onHiddenUsersChanged);
    _pollingTimer?.cancel();
    super.dispose();
  }

  // Canlı liste yalnızca sekme görünür ve uygulama ön plandayken yoklanır;
  // geri dönüldüğünde veri bayatsa hemen yenilenir.
  void _updatePolling() {
    if (!_isVisible || !_isResumed) {
      _pollingTimer?.cancel();
      _pollingTimer = null;
      return;
    }
    if (_pollingTimer != null) return;
    final loadedAt = _loadedAt;
    if (loadedAt == null || DateTime.now().difference(loadedAt) > _pollInterval) {
      unawaited(_fetchData());
    }
    _pollingTimer = Timer.periodic(_pollInterval, (_) => _fetchData());
  }

  Future<void> _fetchData() async {
    final requestId = ++_requestId;
    // Gizlenen kullanıcılar oturumdaki hesaba bağlı.
    unawaited(HiddenUsersStore.instance.load(SupabaseService.instance.currentUser.value?.id));
    try {
      final live = await SupabaseService.instance.getLiveFriends();
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _activeUsers = _dedupeById(live);
        _loaded = true;
        _error = null;
        _loadedAt = DateTime.now();
      });
    } catch (e) {
      debugPrint('[SOCIAL] Canlı liste alınamadı: $e');
      if (!mounted || requestId != _requestId) return;
      // Yenileme başarısız: mevcut liste korunur.
      setState(() => _error = e);
    }
  }

  // Eski get_live_friends iki yönlü arkadaşlıkta aynı kişiyi iki kez döndürebiliyordu.
  static List<Map<String, dynamic>> _dedupeById(List<Map<String, dynamic>> rows) {
    final seen = <String>{};
    return [
      for (final r in rows)
        if (r['id'] == null || seen.add(r['id'].toString())) r,
    ];
  }

  void _openUserActions(Map<String, dynamic> user, AppLocalizations l10n) {
    unawaited(showUserSafetySheet(
      context,
      target: UserSafetyTarget(
        name: user['name']?.toString() ?? l10n.userDefault,
        userId: user['id']?.toString(),
        avatarId: user['avatar_id']?.toString(),
      ),
      place: UserReportPlace.liveFeed,
    ));
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
            final side = math.max(20.0, (constraints.maxWidth - ContentWidth.reading) / 2);
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(side, 20, side, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.socialYourFriends,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchData,
                    color: AppColors.primary,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      slivers: _buildSlivers(l10n, isDark, side),
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

  List<Widget> _buildSlivers(AppLocalizations l10n, bool isDark, double side) {
    if (!_loaded) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: side, vertical: 20),
              child: LoadErrorView(message: l10n.socialLoadError, onRetry: _fetchData),
            ),
          ),
        ),
      ];
    }

    final staleNotice = SliverPadding(
      padding: EdgeInsets.fromLTRB(side, 8, side, 0),
      sliver: SliverToBoxAdapter(child: StaleDataNotice(onRetry: _fetchData)),
    );

    final users = SocialScreen.withoutHidden(_activeUsers, HiddenUsersStore.instance.hidden.value);
    if (users.isEmpty) {
      return [
        if (_error != null) staleNotice,
        SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState(l10n, isDark)),
      ];
    }

    return [
      if (_error != null) staleNotice,
      SliverPadding(
        padding: EdgeInsets.fromLTRB(side, 24, side, 8),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.socialFocusingNow,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildActiveUserItem(Map<String, dynamic> user, AppLocalizations l10n, bool isDark) {
    final name = user['name']?.toString() ?? l10n.userDefault;

    final card = Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerLowest : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          AvatarWidget(avatar: AvatarCharacter.byId(user['avatar_id']?.toString()), size: 44),
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
                    color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  SocialScreen.liveStatusText(user, l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.local_fire_department_rounded,
            color: isDark ? AppColors.darkPrimary : AppColors.primary,
            size: 20,
          ),
          UserActionsButton(onPressed: () => _openUserActions(user, l10n)),
        ],
      ),
    );
    return GestureDetector(onLongPress: () => _openUserActions(user, l10n), child: card);
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
                color: isDark ? AppColors.darkPrimary : AppColors.primaryContainer,
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
