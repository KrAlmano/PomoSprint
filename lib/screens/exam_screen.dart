import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/exam_insights.dart';
import '../models/exam_model.dart';
import '../models/study_session.dart';
import '../services/exam_persistence.dart';
import '../services/exam_service.dart';
import '../utils/responsive.dart';
import '../utils/exam_format.dart';
import '../widgets/exam_results_dialog.dart';
import '../widgets/social/league_tiers.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({
    super.key,
    this.service,
    this.canStart,
    this.canStartAsync,
    this.loadStudySessions,
  });
  final ExamService? service;
  final bool Function()? canStart;
  final Future<bool> Function()? canStartAsync;
  final Future<List<StudySession>> Function()? loadStudySessions;
  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  ExamService get _service => widget.service ?? ExamService.instance;
  int _tab = 0;
  String? _group;
  bool _starting = false;
  List<StudySession> _studies = [];
  bool _studiesLoaded = false;
  bool _studiesStale = false;
  int _studyLoadRevision = 0;
  String? _owner;
  String? _previousActiveUuid;
  int _leagueRefreshRevision = 0;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _owner = _service.backend.ownerId;
    _service.addListener(_changed);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (_owner != _service.backend.ownerId) {
      _owner = _service.backend.ownerId;
      _studies = [];
      _studiesLoaded = false;
      _studiesStale = false;
      _studyLoadRevision++;
      _leagueRefreshRevision++;
    }
    final previous = _previousActiveUuid;
    _previousActiveUuid = _service.activeRecord?.clientUuid;
    if (previous != null &&
        _previousActiveUuid == null &&
        _service.attempts.any(
          (a) => a.clientUuid == previous && a.isCompleted,
        )) {
      // Completion reveals the score entry action without an unsolicited modal
      // over another tab or after a cold launch into unrelated history.
      _tab = 1;
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _service.setForeground(state == AppLifecycleState.resumed);
    if (mounted) {
      setState(() {
        _foreground = state == AppLifecycleState.resumed;
        if (_foreground) _leagueRefreshRevision++;
      });
    }
    if (state == AppLifecycleState.resumed) unawaited(_loadStudies());
  }

  Future<void> _load() async {
    await _service.initialize();
    await _loadStudies();
  }

  Future<void> _loadStudies() async {
    final owner = _service.backend.ownerId;
    final load = widget.loadStudySessions;
    if (load == null || owner == null) return;
    final revision = ++_studyLoadRevision;
    bool current() =>
        mounted &&
        owner == _service.backend.ownerId &&
        revision == _studyLoadRevision;
    try {
      final rows = await load();
      if (current()) {
        setState(() {
          _studies = rows;
          _studiesLoaded = true;
          _studiesStale = false;
        });
      }
    } catch (_) {
      if (current()) setState(() => _studiesStale = true);
    }
  }

  Future<void> _refresh() async {
    final owner = _service.backend.ownerId;
    await _service.refresh();
    await _loadStudies();
    if (mounted && owner == _service.backend.ownerId) {
      setState(() => _leagueRefreshRevision++);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _start(ExamDefinition exam) async {
    if (_starting) return;
    final l10n = AppLocalizations.of(context)!;
    if (widget.canStart?.call() == false || _service.activeRecord != null) {
      _message(l10n.examConflict);
      return;
    }
    final owner = _service.backend.ownerId;
    setState(() => _starting = true);
    try {
      if (!await _canStartNow(owner)) {
        if (mounted) _message(AppLocalizations.of(context)!.examConflict);
        return;
      }
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) {
          final l10n = AppLocalizations.of(context)!;
          return AlertDialog(
            scrollable: true,
            title: Text(l10n.examRulesTitle),
            content: Text(l10n.examRulesBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.examReady),
              ),
            ],
          );
        },
      );
      if (!mounted || accepted != true || owner != _service.backend.ownerId) {
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _ExamCountdown(),
      );
      if (!await _canStartNow(owner)) {
        if (mounted) _message(AppLocalizations.of(context)!.examConflict);
        return;
      }
      await _service.start(exam);
    } catch (_) {
      if (mounted) _message(AppLocalizations.of(context)!.examError);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<bool> _canStartNow(String? owner) async {
    bool current() {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      return mounted &&
          owner != null &&
          owner == _service.backend.ownerId &&
          (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
          widget.canStart?.call() != false;
    }

    if (!current()) return false;
    final allowed = await widget.canStartAsync?.call() ?? true;
    return allowed && current();
  }

  Future<void> _abandon(ExamLocalRecord record) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          scrollable: true,
          title: Text(l10n.examAbandonTitle),
          content: Text(l10n.examAbandonBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.examAbandon),
            ),
          ],
        );
      },
    );
    if (accepted == true) await _service.abandon(record.clientUuid);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final active = _service.activeRecord;
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(Responsive.of(context).pagePadding),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.examTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(l10n.examIntro),
                const SizedBox(height: 16),
                if (active != null) _activeCard(active, l10n),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < 3; i++)
                      ChoiceChip(
                        label: Text(
                          [l10n.examNew, l10n.examHistory, l10n.examLeague][i],
                        ),
                        selected: _tab == i,
                        onSelected: (_) {
                          setState(() => _tab = i);
                          if (i == 1) unawaited(_loadStudies());
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_service.errorCode != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      l10n.examError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (_tab == 0) ..._catalog(l10n),
                if (_tab == 1) ..._history(l10n),
                if (_tab == 2)
                  _ExamLeagueView(
                    service: _service,
                    available: _service.catalog.available,
                    refreshRevision: _leagueRefreshRevision,
                    foreground: _foreground,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _turkish => Localizations.localeOf(context).languageCode == 'tr';
  List<Widget> _catalog(AppLocalizations l10n) => [
    if (!_service.catalog.available)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.examUnavailable,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(l10n.examUnavailableBody),
              if (!_service.catalog.fromServer) ...[
                const SizedBox(height: 8),
                Text(l10n.examCatalogFallback),
              ],
              TextButton(onPressed: _refresh, child: Text(l10n.examRetry)),
            ],
          ),
        ),
      ),
    Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: Text(l10n.examAllGroups),
          selected: _group == null,
          onSelected: (_) => setState(() => _group = null),
        ),
        for (final group
            in _service.catalog.exams.map((e) => e.segment).toSet())
          ChoiceChip(
            label: Text(group.toUpperCase()),
            selected: _group == group,
            onSelected: (_) => setState(() => _group = group),
          ),
      ],
    ),
    for (final exam in _service.catalog.exams.where(
      (e) => _group == null || e.segment == _group,
    ))
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                exam.name(_turkish),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.examQuestionsMinutes(
                  exam.totalQuestions,
                  exam.durationSeconds ~/ 60,
                ),
              ),
              Text(l10n.examNetRule(exam.wrongAnswerDivisor)),
              const SizedBox(height: 8),
              Text(exam.subjects.map((s) => s.name(_turkish)).join(' · ')),
              if (exam.segment == 'lgs') ...[
                const SizedBox(height: 8),
                Text(l10n.examLgsBreakInfo),
              ],
              const SizedBox(height: 12),
              FilledButton(
                key: ValueKey('exam-start-${exam.id}'),
                onPressed:
                    _service.catalog.available &&
                        !_starting &&
                        _service.activeRecord == null
                    ? () => _start(exam)
                    : null,
                child: Text(_starting ? l10n.examStarting : l10n.examStart),
              ),
            ],
          ),
        ),
      ),
  ];
  Widget _activeCard(ExamLocalRecord record, AppLocalizations l10n) {
    final attempt = record.attempt;
    final seconds = attempt?.remainingSecondsAt(_service.now()) ?? 0;
    final pending =
        record.pendingAction != null &&
        (record.pendingAction != ExamPendingAction.start || attempt == null);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              record.definition.name(_turkish),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              attempt == null
                  ? l10n.examStartPending
                  : pending && seconds == 0
                  ? l10n.examPending
                  : l10n.examRunning,
            ),
            const SizedBox(height: 12),
            if (attempt != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _clock(seconds),
                  key: const ValueKey('exam-countdown'),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            Text(l10n.examNoPause),
            const SizedBox(height: 12),
            if (pending)
              Text(
                attempt == null
                    ? l10n.examStartPendingBody
                    : l10n.examPendingBody,
              ),
            if (record.pendingAction != null)
              TextButton(
                onPressed: _service.busy
                    ? null
                    : () => _service.retry(record.clientUuid),
                child: Text(l10n.examRetry),
              ),
            if (attempt != null &&
                seconds > 0 &&
                record.pendingAction != ExamPendingAction.abandon)
              TextButton(
                onPressed: _service.busy ? null : () => _abandon(record),
                child: Text(l10n.examAbandon),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _history(AppLocalizations l10n) {
    final attempts = _service.attempts;
    final insights = _studiesLoaded
        ? buildExamTimeInsights(
            attempts: attempts,
            studySessions: _studies,
            definitionFor: _service.definitionFor,
            now: _service.now(),
          )
        : const <ExamTimeInsight>[];
    return [
      if (attempts.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  l10n.examNoHistory,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(l10n.examNoHistoryBody),
              ],
            ),
          ),
        ),
      for (final attempt in attempts) _historyCard(attempt, l10n),
      for (final record in _service.records.where(
        (r) =>
            r.attempt == null && r.errorCode != null && r.pendingAction == null,
      ))
        Card(
          child: ListTile(
            title: Text(record.definition.name(_turkish)),
            subtitle: Text(l10n.examError),
          ),
        ),
      const SizedBox(height: 20),
      Text(l10n.examInsights, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (_studiesStale) ...[
        Text(
          _studiesLoaded ? l10n.statsStaleNotice : l10n.statsLoadErrorGeneric,
        ),
        TextButton(onPressed: _loadStudies, child: Text(l10n.examRetry)),
      ],
      if (_studiesLoaded && insights.isEmpty) Text(l10n.examInsightsEmpty),
      for (final insight in insights)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.examInsightsChange(
                insight.subject.name(_turkish),
                insight.studyMinutes,
                formatExamNet(insight.before, l10n.localeName),
                formatExamNet(insight.after, l10n.localeName),
              ),
            ),
          ),
        ),
      if (insights.isNotEmpty) Text(l10n.examInsightsDisclaimer),
    ];
  }

  Widget _historyCard(ExamAttempt attempt, AppLocalizations l10n) {
    final exam = _service.definitionFor(attempt);
    final localizations = MaterialLocalizations.of(context);
    String date(DateTime at) {
      final local = at.toLocal();
      return '${localizations.formatShortDate(local)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              exam?.name(_turkish) ?? l10n.examTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('${l10n.examStartTime}: ${date(attempt.startedAt)}'),
            Text(
              '${l10n.examEndTime}: ${date(attempt.completedAt ?? attempt.endsAt)}',
            ),
            Text(
              l10n.examQuestionsMinutes(
                attempt.totalQuestions,
                attempt.durationSeconds ~/ 60,
              ),
            ),
            Text(switch (attempt.status) {
              ExamAttemptStatus.completed => l10n.examCompleted,
              ExamAttemptStatus.abandoned => l10n.examAbandoned,
              ExamAttemptStatus.active => l10n.examRunning,
            }),
            if (attempt.isCompleted) ...[
              Text(
                l10n.examRewardSummary(
                  attempt.pointsEarned,
                  attempt.examCoinsEarned,
                ),
              ),
              if (attempt.subjectResults.isEmpty)
                Text(l10n.examFinishedNoResults),
              if (attempt.subjectResults.isNotEmpty && exam != null)
                ExpansionTile(
                  title: Text(l10n.examResultsTitle),
                  children: [
                    for (final subject in exam.subjects)
                      if (attempt.subjectResults.any(
                        (r) => r.subjectId == subject.id,
                      ))
                        ListTile(
                          title: Text(subject.name(_turkish)),
                          subtitle: Text(
                            '${l10n.examCorrect}: ${attempt.subjectResults.firstWhere((r) => r.subjectId == subject.id).correct} · '
                            '${l10n.examWrong}: ${attempt.subjectResults.firstWhere((r) => r.subjectId == subject.id).wrong} · '
                            '${l10n.examBlank}: ${attempt.subjectResults.firstWhere((r) => r.subjectId == subject.id).blank}',
                          ),
                          trailing: Text(
                            formatExamNet(
                              attempt.subjectResults
                                  .firstWhere((r) => r.subjectId == subject.id)
                                  .net(exam.wrongAnswerDivisor),
                              l10n.localeName,
                            ),
                          ),
                        ),
                  ],
                ),
              TextButton(
                onPressed: exam == null
                    ? null
                    : () => showExamResultsDialog(
                        context,
                        service: _service,
                        attempt: attempt,
                      ),
                child: Text(
                  attempt.subjectResults.isEmpty
                      ? l10n.examEnterResults
                      : l10n.examEditResults,
                ),
              ),
            ] else if (attempt.status == ExamAttemptStatus.abandoned)
              Text(l10n.examNoAward),
          ],
        ),
      ),
    );
  }

  static String _clock(int seconds) =>
      '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${((seconds % 3600) ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _ExamCountdown extends StatefulWidget {
  const _ExamCountdown();
  @override
  State<_ExamCountdown> createState() => _ExamCountdownState();
}

class _ExamCountdownState extends State<_ExamCountdown> {
  int _count = 3;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_count == 1) {
        _timer?.cancel();
        Navigator.pop(context);
      } else {
        setState(() => _count--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      content: Semantics(
        liveRegion: true,
        child: Text(
          '$_count',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayLarge,
        ),
      ),
    ),
  );
}

class _ExamLeagueView extends StatefulWidget {
  const _ExamLeagueView({
    required this.service,
    required this.available,
    required this.refreshRevision,
    required this.foreground,
  });
  final ExamService service;
  final bool available;
  final int refreshRevision;
  final bool foreground;
  @override
  State<_ExamLeagueView> createState() => _ExamLeagueViewState();
}

class _ExamLeagueViewState extends State<_ExamLeagueView>
    with WidgetsBindingObserver {
  String _scope = 'segment';
  ExamLeagueSnapshot? _league;
  bool _loading = false;
  bool _failed = false;
  int _revision = 0;
  bool _visible = false;
  Timer? _periodTimer;
  DateTime? _lastRefreshedPeriod;
  String? _loadedOwner;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    // Paused apps need not rebuild immediately, so stop the timer directly.
    // The parent's explicit revision performs one refresh on foreground return.
    if (!_foreground) _periodTimer?.cancel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible == _visible) return;
    _visible = visible;
    if (visible) {
      unawaited(_load());
    } else {
      _periodTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _revision++;
    WidgetsBinding.instance.removeObserver(this);
    _periodTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ExamLeagueView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.foreground || !widget.available) _periodTimer?.cancel();
    if (oldWidget.available != widget.available ||
        oldWidget.refreshRevision != widget.refreshRevision ||
        oldWidget.foreground != widget.foreground) {
      unawaited(_load());
    }
  }

  void _reloadExpiredPeriod() {
    final target = _league?.periodEnd;
    if (!mounted ||
        !_visible ||
        !_foreground ||
        !widget.foreground ||
        !widget.available ||
        target == null ||
        target.isAfter(widget.service.now()) ||
        target == _lastRefreshedPeriod) {
      return;
    }
    _lastRefreshedPeriod = target;
    unawaited(_load());
  }

  void _schedulePeriodRefresh() {
    _periodTimer?.cancel();
    final target = _league?.periodEnd;
    if (!_visible ||
        !_foreground ||
        !widget.foreground ||
        !widget.available ||
        target == null) {
      return;
    }
    final delay = target.difference(widget.service.now());
    if (delay <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _reloadExpiredPeriod(),
      );
    } else {
      _periodTimer = Timer(delay, _reloadExpiredPeriod);
    }
  }

  Future<void> _load() async {
    final revision = ++_revision;
    final owner = widget.service.backend.ownerId;
    if (owner != _loadedOwner) {
      _loadedOwner = owner;
      _league = null;
      _lastRefreshedPeriod = null;
    }
    if (!widget.available) {
      _periodTimer?.cancel();
      _league = null;
      _loading = false;
      _failed = false;
      return;
    }
    if (!_visible || !_foreground || !widget.foreground) {
      _loading = false;
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final league = await widget.service.loadLeague(scope: _scope);
      if (mounted &&
          revision == _revision &&
          owner == widget.service.backend.ownerId) {
        setState(() => _league = league);
        _schedulePeriodRefresh();
      }
    } catch (_) {
      if (mounted && revision == _revision) setState(() => _failed = true);
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final league = _league;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final scope in ['segment', 'global'])
              ChoiceChip(
                label: Text(
                  scope == 'global' ? l10n.examGlobal : l10n.examTargetGroup,
                ),
                selected: scope == _scope,
                onSelected: (_) {
                  setState(() {
                    _scope = scope;
                    _league = null;
                  });
                  unawaited(_load());
                },
              ),
          ],
        ),
        if (_loading) const LinearProgressIndicator(),
        if (!widget.available) Text(l10n.examUnavailableBody),
        if (_failed) TextButton(onPressed: _load, child: Text(l10n.examRetry)),
        if (league != null) ...[
          Text(
            leagueTitle(l10n, league.tier),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text('${l10n.examPracticeSand}: ${league.examCoins}'),
          if (league.periodEnd != null)
            Text(
              l10n.examMonthlyReset(
                MaterialLocalizations.of(
                  context,
                ).formatShortDate(league.periodEnd!.toLocal()),
              ),
            ),
          if (league.phase != 'active') Text(l10n.examLeaguePreparing),
          if (league.rows.isEmpty) Text(l10n.examLeagueEmpty),
          for (var i = 0; i < league.rows.length; i++)
            ListTile(
              leading: Text('${league.rows[i]['rank'] ?? i + 1}'),
              title: Text(
                league.rows[i]['name']?.toString() ?? l10n.userDefault,
              ),
              trailing: Text('${league.rows[i]['points'] ?? 0}'),
              selected: league.rows[i]['is_me'] == true,
            ),
        ],
        const Divider(height: 32),
        Text(
          l10n.examRewardAvatars,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(l10n.examRewardAvatarsPending),
      ],
    );
  }
}
