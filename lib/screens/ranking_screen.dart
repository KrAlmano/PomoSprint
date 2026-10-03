import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import '../utils/responsive.dart';
import '../widgets/league_info_sheet.dart';
import '../widgets/social/league_tiers.dart';
import '../widgets/social/load_error_view.dart';
import '../widgets/social/ranking_models.dart';
import '../widgets/social/ranking_widgets.dart';

// Sekmeler: Lig (14 günlük dönemlik oda), Aylık (herkese açık, ayın 1'inde
// sıfırlanır), Arkadaşlar. Ayrı bir "Tüm Zamanlar" sekmesi yok: hiç sıfırlanmayan bir
// liste eski kullanıcılarda donup kalıyordu; kişinin toplam puanı Profil'de
// ve Arkadaşlar sekmesinde zaten görünüyor.
enum _RankingTab { league, monthly, friends }

class _TabData {
  List<RankingEntry> entries = const [];
  bool loaded = false;
  bool loading = false;
  Object? error;
  DateTime? loadedAt;

  // Aynı sekme için üst üste başlayan isteklerde yalnızca sonuncusu yazılır.
  int requestId = 0;

  bool get isStale =>
      loadedAt == null || DateTime.now().difference(loadedAt!) > _RankingScreenState._staleAfter;
}

class RankingScreen extends StatefulWidget {
  final UserModel? currentUser;

  const RankingScreen({
    super.key,
    this.currentUser,
  });

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  static const Duration _staleAfter = Duration(seconds: 30);

  _RankingTab _tab = _RankingTab.league;
  final Map<_RankingTab, _TabData> _data = {for (final t in _RankingTab.values) t: _TabData()};
  LeagueSnapshot? _league;
  bool _isVisible = false;
  bool _leagueInfoChecked = false;

  @override
  void initState() {
    super.initState();
    SupabaseService.instance.addStatsChangedListener(_onStatsChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Shell görünmeyen sekmeleri TickerMode(enabled: false) ile sarar;
    // görünmezken ağ isteği yapılmaz, görünür olunca bayatsa yenilenir.
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _isVisible) return;
    _isVisible = visible;
    if (visible) {
      _loadIfStale(_tab);
      unawaited(_maybeAutoShowLeagueInfo());
    }
  }

  @override
  void dispose() {
    SupabaseService.instance.removeStatsChangedListener(_onStatsChanged);
    super.dispose();
  }

  // Yalnızca bu cihazda seans tamamlanınca/senkron olunca tetiklenir.
  void _onStatsChanged() {
    for (final d in _data.values) {
      d.loadedAt = null;
    }
    if (_isVisible) unawaited(_load(_tab));
  }

  void _loadIfStale(_RankingTab tab) {
    final data = _data[tab]!;
    if (data.isStale && !data.loading) unawaited(_load(tab));
  }

  Future<void> _load(_RankingTab tab) async {
    final data = _data[tab]!;
    final requestId = ++data.requestId;
    setState(() => data.loading = true);
    try {
      final service = SupabaseService.instance;
      LeagueSnapshot? league;
      final List<RankingEntry> entries;
      switch (tab) {
        case _RankingTab.league:
          final rows = await service.getLeagueRanking();
          league = rows.isEmpty ? null : LeagueSnapshot.fromRows(rows);
          entries = [for (final r in rows) RankingEntry.fromRow(r, pointsKey: 'weekly_points')];
        case _RankingTab.monthly:
          final rows = await service.getMonthlyRanking();
          entries = [for (final r in rows) RankingEntry.fromRow(r, pointsKey: 'total_points')];
        case _RankingTab.friends:
          final rows = await service.fetchFriends();
          entries = [for (final r in rows) RankingEntry.fromRow(r, pointsKey: 'lifetime_points')]
            ..sort(RankingEntry.compare);
      }
      if (!mounted || requestId != data.requestId) return;
      setState(() {
        data
          ..entries = entries
          ..loaded = true
          ..loading = false
          ..error = null
          ..loadedAt = DateTime.now();
        if (tab == _RankingTab.league) _league = league;
      });
      if (tab == _RankingTab.league) unawaited(_maybeAutoShowLeagueInfo());
    } catch (e) {
      debugPrint('[RANKING] ${tab.name} yüklenemedi: $e');
      if (!mounted || requestId != data.requestId) return;
      setState(() {
        data
          ..loading = false
          ..error = e;
      });
    }
  }

  void _selectTab(_RankingTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    _loadIfStale(tab);
    unawaited(_maybeAutoShowLeagueInfo());
  }

  // Lig bilgi sheet'i, kullanıcı Sıralama > Lig sekmesindeyken ve gerçek
  // bir lig odasındayken (sunucunun lig-yok satırı değil) bir kez açılır.
  Future<void> _maybeAutoShowLeagueInfo() async {
    final league = _league;
    final user = widget.currentUser;
    final uid = user?.id;
    if (_leagueInfoChecked || !_isVisible || _tab != _RankingTab.league) return;
    if (league == null || league.memberCount < 2 || uid == null || uid.isEmpty) return;
    _leagueInfoChecked = true;

    final prefs = await SharedPreferences.getInstance();
    final key = 'league_info_shown_$uid';
    // Eski sürüm anahtarı e-postaya bağlıydı; onu görmüş kullanıcıya tekrar açılmaz.
    final legacyKey = 'league_info_shown_${user!.email}';
    if ((prefs.getBool(key) ?? false) || (prefs.getBool(legacyKey) ?? false)) return;
    if (!mounted || !_isVisible || _tab != _RankingTab.league) {
      _leagueInfoChecked = false;
      return;
    }
    await prefs.setBool(key, true);
    if (mounted) unawaited(showLeagueInfoSheet(context, league: league));
  }

  // Arkadaşlar sekmesine kullanıcının kendi satırı yerel profilden eklenir
  // (get_my_friends kendini içermez). Lig ve aylık sekmelerde liste olduğu
  // gibi gösterilir; kendi satırı yalnızca sunucunun is_me alanıyla bilinir
  // (isimle eşleme yapılmaz). Aylık listede yalnızca ilk 50'deyse görünür.
  List<RankingEntry> _visibleEntries() {
    final entries = _data[_tab]!.entries;
    final me = widget.currentUser;
    if (_tab != _RankingTab.friends || me == null) return entries;
    return [
      ...entries,
      RankingEntry(
        name: me.name,
        avatarId: me.avatarId,
        points: me.lifetimePoints,
        minutes: me.totalMinutes,
        isMe: true,
      ),
    ]..sort(RankingEntry.compare);
  }

  // Düzen: sekme çubuğu, geri sayım ve durum mesajları okunabilir genişlikte
  // ortalanır; podyum ve liste geniş ekranda (tablet yatay) iki sütuna
  // bölünür (bkz. RankingStandings). Yatay telefonda dikey alan kıt olduğu
  // için podyum küçülür ve her şey tek kaydırmada kalır.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final data = _data[_tab]!;
    final compact = Responsive.of(context).isShortHeight;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _load(_tab),
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: compact ? 12 : 20),
            child: ContentWidth(
              maxWidth: ContentWidth.dashboard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContentWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTabBar(l10n),
                        SizedBox(height: compact ? 12 : 16),
                        ..._buildBanner(l10n),
                        if (!data.loaded)
                          data.error != null
                              ? LoadErrorView(message: l10n.rankingLoadError, onRetry: () => _load(_tab))
                              : const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(40.0),
                                    child: CircularProgressIndicator(color: AppColors.primary),
                                  ),
                                )
                        else if (data.error != null)
                          StaleDataNotice(onRetry: () => _load(_tab)),
                      ],
                    ),
                  ),
                  if (data.loaded)
                    RankingStandings(
                      entries: _visibleEntries(),
                      league: _tab == _RankingTab.league ? _league : null,
                      compact: compact,
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labels = {
      _RankingTab.league: l10n.rankingTabLeague,
      _RankingTab.monthly: l10n.rankingTabMonthly,
      _RankingTab.friends: l10n.rankingTabFriends,
    };
    return Container(
      width: double.infinity,
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          for (final entry in labels.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => _selectTab(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _tab == entry.key ? AppColors.primaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  // Dar sekmede ya da büyük metin ölçeğinde etiket tek satırda
                  // küçülür; çubuk sabit yükseklikte kalır, taşmaz.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      entry.value,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _tab == entry.key
                            ? Colors.white
                            : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Lig: sunucunun döndürdüğü dönem sonu. Aylık: ayın 1'i (Türkiye saati).
  List<Widget> _buildBanner(AppLocalizations l10n) {
    final RankingCountdownBanner banner;
    switch (_tab) {
      case _RankingTab.league:
        final league = _league;
        if (league == null) return const [];
        banner = RankingCountdownBanner(
          title: leagueTitle(l10n, league.tier),
          target: league.endDate,
          onHelp: () => showLeagueInfoSheet(context, league: league),
        );
      case _RankingTab.monthly:
        banner = RankingCountdownBanner(
          title: l10n.rankingMonthlyResetIn,
          target: nextMonthlyLeaderboardReset(DateTime.now()),
        );
      case _RankingTab.friends:
        return const [];
    }
    return [banner, const SizedBox(height: 12)];
  }
}
