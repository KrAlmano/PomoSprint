import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../models/competition_target.dart';
import '../models/league_rules.dart';
import '../models/user_model.dart';
import '../services/hidden_users.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import '../utils/responsive.dart';
import '../widgets/league_info_sheet.dart';
import '../widgets/competition_target_dialog.dart';
import '../widgets/social/league_tiers.dart';
import '../widgets/social/load_error_view.dart';
import '../widgets/social/ranking_models.dart';
import '../widgets/social/ranking_widgets.dart';
import '../widgets/social/user_safety.dart';

// Version 2: monthly target room, global monthly view, friends.
// Older servers retain their existing league/monthly behavior.
// Ayrı bir "Tüm Zamanlar" sekmesi yok: hiç sıfırlanmayan bir
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
      loadedAt == null ||
      DateTime.now().difference(loadedAt!) > _RankingScreenState._staleAfter;
}

class RankingScreen extends StatefulWidget {
  final UserModel? currentUser;
  final SupabaseService? service;

  /// Optional clock for deterministic rollover tests; production uses DateTime.now.
  final DateTime Function()? now;

  const RankingScreen({super.key, this.currentUser, this.service, this.now});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with WidgetsBindingObserver {
  static const Duration _staleAfter = Duration(seconds: 30);

  _RankingTab _tab = _RankingTab.league;
  final Map<_RankingTab, _TabData> _data = {
    for (final t in _RankingTab.values) t: _TabData(),
  };
  LeagueSnapshot? _league;
  LeagueRules _rules = LeagueRules.standard;
  CompetitionTarget? _target;
  DateTime? _globalPeriodEnd;
  bool _editingTarget = false;
  bool _isVisible = false;
  bool _leagueInfoChecked = false;
  bool _foreground = true;
  final Set<DateTime> _refreshedPeriods = {};
  SupabaseService get _service => widget.service ?? SupabaseService.instance;
  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _service.addStatsChangedListener(_onStatsChanged);
    HiddenUsersStore.instance.hidden.addListener(_onHiddenUsersChanged);
    unawaited(HiddenUsersStore.instance.load(widget.currentUser?.id));
  }

  @override
  void didUpdateWidget(RankingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser?.id != widget.currentUser?.id) {
      for (final data in _data.values) {
        data.requestId++;
        data.entries = const [];
        data.loaded = false;
        data.loading = false;
        data.error = null;
        data.loadedAt = null;
      }
      _league = null;
      _target = null;
      _globalPeriodEnd = null;
      _leagueInfoChecked = false;
      _refreshedPeriods.clear();
      unawaited(HiddenUsersStore.instance.load(widget.currentUser?.id));
      if (_isVisible && _foreground) unawaited(_load(_tab));
    }
  }

  void _onHiddenUsersChanged() {
    if (mounted) setState(() {});
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
      if (!_refreshExpiredPeriod()) _loadIfStale(_tab);
      unawaited(_maybeAutoShowLeagueInfo());
    }
  }

  @override
  void dispose() {
    _service.removeStatsChangedListener(_onStatsChanged);
    HiddenUsersStore.instance.hidden.removeListener(_onHiddenUsersChanged);
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  // Yalnızca bu cihazda seans tamamlanınca/senkron olunca tetiklenir.
  void _onStatsChanged() {
    for (final d in _data.values) {
      d.loadedAt = null;
    }
    if (_isVisible && _foreground) unawaited(_load(_tab));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && _isVisible && !_refreshExpiredPeriod()) {
      _loadIfStale(_tab);
    }
  }

  DateTime? _resetTarget() {
    switch (_tab) {
      case _RankingTab.league:
        final league = _league;
        if (league == null) return null;
        return league.rules.isCalendarMonthly
            ? league.rules.periodEnd ?? league.endDate
            : league.rules.isCompetitionActive
            ? league.endDate
            : league.rules.competitionPhase == 'scheduled'
            ? league.rules.competitionStartsAt
            : null;
      case _RankingTab.monthly:
        return _rules.isCalendarMonthly
            ? _globalPeriodEnd ?? _rules.periodEnd
            : nextMonthlyLeaderboardReset(_now);
      case _RankingTab.friends:
        return null;
    }
  }

  bool _refreshExpiredPeriod() {
    final target = _resetTarget();
    if (!_isVisible ||
        !_foreground ||
        target == null ||
        target.isAfter(_now) ||
        !_refreshedPeriods.add(target)) {
      return false;
    }
    // Other tabs must not keep the previous month's cached rows either. This
    // one boundary reload bypasses normal freshness checks, without polling.
    for (final data in _data.values) {
      data.loadedAt = null;
    }
    unawaited(_load(_tab));
    return true;
  }

  void _loadIfStale(_RankingTab tab) {
    if (!_isVisible || !_foreground) return;
    final data = _data[tab]!;
    if (data.isStale && !data.loading) unawaited(_load(tab));
  }

  Future<void> _load(_RankingTab tab) async {
    if (!mounted || !_isVisible || !_foreground) return;
    final data = _data[tab]!;
    final requestId = ++data.requestId;
    final owner = widget.currentUser?.id;
    setState(() => data.loading = true);
    try {
      final service = _service;
      final rules = await service.getLeagueRules();
      LeagueSnapshot? league;
      CompetitionTarget? target = _target;
      DateTime? globalEnd;
      final List<RankingEntry> entries;
      switch (tab) {
        case _RankingTab.league:
          // Son başarılı kurallar korunur; yeni satır kendi güncel yapılandırmasını taşır.
          final rows = await service.getLeagueRanking();
          league = rows.isEmpty
              ? null
              : LeagueSnapshot.fromRows(
                  rows,
                  rules: rules,
                  hasLeagueHistory: hasLeagueHistory(
                    service.currentUser.value ?? widget.currentUser,
                  ),
                );
          entries = [
            for (final r in rows)
              RankingEntry.fromRow(r, pointsKey: 'weekly_points'),
          ];
          if (rules.isCalendarMonthly ||
              league?.rules.isCalendarMonthly == true) {
            target = await service.getCompetitionTarget();
          }
        case _RankingTab.monthly:
          final rows = await service.getMonthlyRanking();
          globalEnd = rows.isEmpty
              ? null
              : DateTime.tryParse(rows.first['period_end']?.toString() ?? '');
          entries = [
            for (final r in rows)
              RankingEntry.fromRow(r, pointsKey: 'total_points'),
          ];
        case _RankingTab.friends:
          final rows = await service.fetchFriends();
          entries = [
            for (final r in rows)
              RankingEntry.fromRow(r, pointsKey: 'lifetime_points'),
          ]..sort(RankingEntry.compare);
      }
      if (!mounted ||
          requestId != data.requestId ||
          owner != widget.currentUser?.id) {
        return;
      }
      setState(() {
        _rules = league?.rules ?? rules;
        _target = target;
        data
          ..entries = entries
          ..loaded = true
          ..loading = false
          ..error = null
          ..loadedAt = DateTime.now();
        if (tab == _RankingTab.league) _league = league;
        if (tab == _RankingTab.monthly) _globalPeriodEnd = globalEnd;
      });
      if (tab == _RankingTab.league) unawaited(_maybeAutoShowLeagueInfo());
    } catch (e) {
      debugPrint('[RANKING] ${tab.name} yüklenemedi: $e');
      if (!mounted ||
          requestId != data.requestId ||
          owner != widget.currentUser?.id) {
        return;
      }
      setState(() {
        data
          ..loading = false
          ..error = e;
      });
    }
  }

  Future<void> _editTarget() async {
    final target = _target;
    if (target == null || _editingTarget) return;
    final owner = widget.currentUser?.id;
    setState(() => _editingTarget = true);
    try {
      final result = await showCompetitionTargetDialog(
        context,
        target: target,
        save: _service.setCompetitionTarget,
      );
      if (!mounted || owner != widget.currentUser?.id || result == null) return;
      setState(() => _target = result);
      await _load(_RankingTab.league);
    } finally {
      if (mounted) setState(() => _editingTarget = false);
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
    if (league == null ||
        league.memberCount < 2 ||
        uid == null ||
        uid.isEmpty) {
      return;
    }
    _leagueInfoChecked = true;

    final prefs = await SharedPreferences.getInstance();
    final key = 'league_info_shown_$uid';
    // Eski sürüm anahtarı e-postaya bağlıydı; onu görmüş kullanıcıya tekrar açılmaz.
    final legacyKey = 'league_info_shown_${user!.email}';
    if ((prefs.getBool(key) ?? false) || (prefs.getBool(legacyKey) ?? false)) {
      return;
    }
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
  // Kullanıcının gizlediği kişilerin satırı listeden çıkarılmaz (sıra ve lig
  // bölgeleri bozulmasın); adı ve avatarı gösterilmez.
  List<RankingEntry> _visibleEntries() {
    final hidden = HiddenUsersStore.instance.hidden.value;
    final entries = [
      for (final e in _data[_tab]!.entries)
        (!e.isMe && hidden.isHidden(id: e.userId, name: e.name))
            ? e.asHidden()
            : e,
    ];
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

  // Başka kullanıcının satırı: bildir / gizle.
  void _openEntryActions(RankingEntry entry) {
    final l10n = AppLocalizations.of(context)!;
    unawaited(
      showUserSafetySheet(
        context,
        target: UserSafetyTarget(
          name: entry.name ?? l10n.userDefault,
          userId: entry.userId,
          avatarId: entry.avatarId,
        ),
        place: switch (_tab) {
          _RankingTab.league => UserReportPlace.league,
          _RankingTab.monthly => UserReportPlace.monthly,
          _RankingTab.friends => UserReportPlace.friendsRanking,
        },
      ),
    );
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
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: compact ? 12 : 20,
            ),
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
                              ? LoadErrorView(
                                  message: l10n.rankingLoadError,
                                  onRetry: () => _load(_tab),
                                )
                              : const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(40.0),
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
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
                      onEntryActions: _openEntryActions,
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
      _RankingTab.monthly: _rules.isCalendarMonthly
          ? l10n.rankingTabGlobal
          : l10n.rankingTabMonthly,
      _RankingTab.friends: l10n.rankingTabFriends,
    };
    return Container(
      width: double.infinity,
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerHigh
            : AppColors.surfaceContainerHigh,
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
                    color: _tab == entry.key
                        ? AppColors.primaryContainer
                        : Colors.transparent,
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
                            : (isDark
                                  ? AppColors.darkOnSurfaceVariant
                                  : AppColors.onSurfaceVariant),
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
          target: _resetTarget(),
          onElapsed: _refreshExpiredPeriod,
          now: widget.now,
          message: league.rules.isCompetitionActive
              ? null
              : league.rules.competitionPhase == 'scheduled'
              ? l10n.leagueLaunchScheduledShort
              : l10n.leagueLaunchPreparingShort,
          onHelp: () => showLeagueInfoSheet(context, league: league),
        );
      case _RankingTab.monthly:
        banner = RankingCountdownBanner(
          title: _rules.isCalendarMonthly
              ? l10n.rankingGlobalResetIn
              : l10n.rankingMonthlyResetIn,
          target: _rules.isCalendarMonthly
              ? _globalPeriodEnd ??
                    _rules.periodEnd ??
                    nextCalendarMonthReset(_now)
              : nextMonthlyLeaderboardReset(_now),
          onElapsed: _refreshExpiredPeriod,
          now: widget.now,
        );
      case _RankingTab.friends:
        return const [];
    }
    return [
      banner,
      const SizedBox(height: 12),
      if (_rules.isCalendarMonthly && _tab == _RankingTab.monthly) ...[
        Text(l10n.leagueGlobalScopeBody),
        const SizedBox(height: 12),
      ],
      if (_rules.isCalendarMonthly &&
          _tab == _RankingTab.league &&
          _target != null) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.leagueTargetTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.leagueTargetCurrent(
                    competitionTargetLabel(l10n, _target!.currentSegment),
                  ),
                ),
                if (_target!.pendingSegment != null &&
                    _target!.effectiveAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.leagueTargetPending(
                      competitionTargetLabel(l10n, _target!.pendingSegment!),
                      competitionDate(l10n, _target!.effectiveAt!),
                    ),
                  ),
                ],
                TextButton.icon(
                  key: const ValueKey('league-change-target'),
                  onPressed: _editingTarget ? null : _editTarget,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.leagueTargetChange),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }
}
