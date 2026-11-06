import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/exam_insights.dart';
import '../models/exam_model.dart';
import '../models/kpss_catalog.dart';
import '../models/study_session.dart';
import '../services/exam_persistence.dart';
import '../services/exam_service.dart';
import '../theme.dart';
import '../utils/responsive.dart';
import '../utils/exam_format.dart';
import '../widgets/exam_results_dialog.dart';
import '../widgets/social/league_tiers.dart';
import '../widgets/social/ranking_models.dart';
import '../widgets/social/ranking_widgets.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({
    super.key,
    this.service,
    this.canStart,
    this.canStartAsync,
    this.loadStudySessions,
    this.userSegment,
    this.openHistoryRequest = 0,
    this.historyOnly = false,
  });
  final ExamService? service;
  final bool Function()? canStart;
  final Future<bool> Function()? canStartAsync;
  final Future<List<StudySession>> Function()? loadStudySessions;

  /// Current profile goal, independent of the league's next-period target.
  final String? userSegment;

  /// A new request opens history even when this screen is already mounted.
  final int openHistoryRequest;

  /// Renders the shared history inside Reports without starting another exam.
  final bool historyOnly;
  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> with WidgetsBindingObserver {
  Color get _outlineColor => Theme.of(context).brightness == Brightness.dark
      ? AppColors.darkOutlineVariant
      : AppColors.outlineVariant;
  String _errorMessage(AppLocalizations l10n, String? code) => switch (code) {
    'exam_start_rate_limited' => l10n.examStartRateLimited,
    'exam_history_cursor_ambiguous' => l10n.examHistoryIncomplete,
    _ => l10n.examError,
  };
  ExamService get _service => widget.service ?? ExamService.instance;
  int _tab = 0;
  String? _group;
  bool _extraExams = false;
  KpssExamTrack? _selectedKpssTrack;
  bool _starting = false;
  bool _finishingEarly = false;
  List<StudySession> _studies = [];
  bool _studiesLoaded = false;
  bool _studiesStale = false;
  int _studyLoadRevision = 0;
  String? _owner;
  String? _previousActiveUuid;
  int _leagueRefreshRevision = 0;
  bool _foreground = true;
  bool? _historyVisible;
  @override
  void initState() {
    super.initState();
    _group = _goalSegment;
    if (widget.openHistoryRequest > 0) _tab = 1;
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _owner = _service.backend.ownerId;
    _service.addListener(_changed);
    unawaited(_load());
  }

  static const _examSegments = ['yks', 'lgs', 'tus', 'dus', 'kpss'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.historyOnly) return;
    final visible = TickerMode.valuesOf(context).enabled;
    final wasVisible = _historyVisible;
    _historyVisible = visible;
    if (wasVisible == false && visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _historyVisible == true) unawaited(_loadStudies());
      });
    }
  }

  String? get _goalSegment =>
      _examSegments.contains(widget.userSegment) ? widget.userSegment : null;

  @override
  void didUpdateWidget(covariant ExamScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userSegment != widget.userSegment) {
      _group = _goalSegment;
      _extraExams = false;
      _selectedKpssTrack = null;
    }
    if (oldWidget.openHistoryRequest != widget.openHistoryRequest) {
      _tab = 1;
      unawaited(_loadStudies());
    }
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
      _selectedKpssTrack = null;
      _studies = [];
      _studiesLoaded = false;
      _studiesStale = false;
      _studyLoadRevision++;
      _leagueRefreshRevision++;
      if (widget.historyOnly && _owner != null) unawaited(_loadStudies());
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
    if (!widget.historyOnly) {
      _service.setForeground(state == AppLifecycleState.resumed);
    }
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

  Future<void> _finishEarly(ExamLocalRecord record) async {
    if (_finishingEarly || !_service.canFinishEarly(record)) return;
    final owner = _service.backend.ownerId;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          scrollable: true,
          title: Text(l10n.examFinishEarlyTitle),
          content: Text(l10n.examFinishEarlyBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.examFinishEarly),
            ),
          ],
        );
      },
    );
    if (!mounted || accepted != true || owner != _service.backend.ownerId) {
      return;
    }
    setState(() => _finishingEarly = true);
    try {
      await _service.finishEarly(record.clientUuid);
      if (!mounted ||
          owner != _service.backend.ownerId ||
          !_foreground ||
          !TickerMode.valuesOf(context).enabled ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final completed = _service.attempts
          .where((a) => a.clientUuid == record.clientUuid && a.isCompleted)
          .firstOrNull;
      if (completed != null) {
        await showExamResultsDialog(
          context,
          service: _service,
          attempt: completed,
        );
      }
    } catch (error) {
      if (mounted && owner == _service.backend.ownerId) {
        final l10n = AppLocalizations.of(context)!;
        _message(
          error is ExamFailure && error.code == 'exam_early_finish_too_soon'
              ? l10n.examEarlyTooSoon
              : l10n.examEarlyUnavailable,
        );
      }
    } finally {
      if (mounted) setState(() => _finishingEarly = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.historyOnly) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(Responsive.of(context).pagePadding),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_service.errorCode != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage(l10n, _service.errorCode),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ..._history(l10n),
              ],
            ),
          ),
        ),
      );
    }
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
                if (active != null) _activeCard(active, l10n),
                _tabs(l10n),
                const SizedBox(height: 16),
                if (_service.errorCode != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage(l10n, _service.errorCode),
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

  Iterable<ExamDefinition> get _visibleExams => _service.catalog.exams.where(
    (exam) =>
        (_group == null || exam.segment == _group) &&
        (!(_extraExams && _goalSegment != null) ||
            exam.segment != _goalSegment) &&
        (_group != 'kpss' ||
            (_selectedKpssTrack != null &&
                kpssTrackForExam(exam.id) == _selectedKpssTrack)),
  );

  String _kpssTrackLabel(KpssExamTrack track, AppLocalizations l10n) =>
      switch (track) {
        KpssExamTrack.bachelor => l10n.examKpssBachelor,
        KpssExamTrack.associate => l10n.examKpssAssociate,
        KpssExamTrack.secondary => l10n.examKpssSecondary,
        KpssExamTrack.field => l10n.examKpssField,
      };

  Widget _kpssTrackPicker(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.examKpssChooseTrack,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final track in KpssExamTrack.values)
              ChoiceChip(
                key: ValueKey('exam-kpss-track-${track.name}'),
                label: Text(_kpssTrackLabel(track, l10n)),
                selected: _selectedKpssTrack == track,
                side: BorderSide(color: _outlineColor),
                selectedColor: Theme.of(context).colorScheme.primary,
                labelStyle: _selectedKpssTrack == track
                    ? TextStyle(color: Theme.of(context).colorScheme.onPrimary)
                    : null,
                onSelected: (_) => setState(() => _selectedKpssTrack = track),
                showCheckmark: false,
                materialTapTargetSize: MaterialTapTargetSize.padded,
              ),
          ],
        ),
      ],
    ),
  );

  Widget _tabs(AppLocalizations l10n) {
    final colors = Theme.of(context).colorScheme;
    final labels = [l10n.examTabNew, l10n.examTabHistory, l10n.examTabLeague];
    const ids = ['new', 'history', 'league'];
    Widget tab(int index) => Semantics(
      button: true,
      selected: _tab == index,
      child: Material(
        color: _tab == index ? colors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('exam-tab-${ids[index]}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() => _tab = index);
            if (index == 1) unawaited(_loadStudies());
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Center(
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _tab == index
                        ? colors.onPrimary
                        : colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scroll =
              constraints.maxWidth < 240 ||
              MediaQuery.textScalerOf(context).scale(14) > 18;
          if (scroll) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < labels.length; i++) ...[
                      if (i != 0) const SizedBox(width: 4),
                      tab(i),
                    ],
                  ],
                ),
              ),
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  if (i != 0) const SizedBox(width: 4),
                  Expanded(child: tab(i)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _metadata(IconData icon, String text) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyStatus(ExamAttemptStatus status, String label) {
    final theme = Theme.of(context);
    final isCompleted = status == ExamAttemptStatus.completed;
    final isDark = theme.brightness == Brightness.dark;
    final color = isCompleted
        ? (isDark ? const Color(0xFF8ED9AA) : const Color(0xFF167443))
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      key: ValueKey('exam-history-status-${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted
            ? color.withValues(alpha: isDark ? .16 : .10)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle_rounded : Icons.info_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalTabs(AppLocalizations l10n) {
    Widget choice({
      required Key key,
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) => SizedBox(
      width: double.infinity,
      child: ChoiceChip(
        key: key,
        label: Text(label, textAlign: TextAlign.center),
        selected: selected,
        side: BorderSide(color: _outlineColor),
        selectedColor: Theme.of(context).colorScheme.primary,
        labelStyle: selected
            ? TextStyle(color: Theme.of(context).colorScheme.onPrimary)
            : null,
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        onSelected: (_) => onTap(),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(14) > 18;
        final goal = choice(
          key: const ValueKey('exam-goal-tab'),
          label: l10n.examMyGoal(widget.userSegment!.toUpperCase()),
          selected: !_extraExams,
          onTap: () => setState(() {
            _extraExams = false;
            _group = _goalSegment;
            _selectedKpssTrack = null;
          }),
        );
        final extra = choice(
          key: const ValueKey('exam-extra-tab'),
          label: l10n.examExtraExams,
          selected: _extraExams,
          onTap: () => setState(() {
            _extraExams = true;
            _group = null;
            _selectedKpssTrack = null;
          }),
        );
        if (stacked) {
          return Column(children: [goal, const SizedBox(height: 8), extra]);
        }
        return Row(
          children: [
            Expanded(child: goal),
            const SizedBox(width: 8),
            Expanded(child: extra),
          ],
        );
      },
    );
  }

  List<Widget> _catalog(AppLocalizations l10n) => [
    Container(
      key: const ValueKey('exam-net-info'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              l10n.examNetInfo,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
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
    if (_goalSegment != null) ...[_goalTabs(l10n), const SizedBox(height: 8)],
    if (_goalSegment == null || _extraExams)
      Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          ChoiceChip(
            key: const ValueKey('exam-filter-all'),
            label: Text(l10n.examFilterAll),
            showCheckmark: false,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -1),
            materialTapTargetSize: MaterialTapTargetSize.padded,
            selected: _group == null,
            side: BorderSide(color: _outlineColor),
            selectedColor: Theme.of(context).colorScheme.primary,
            labelStyle: _group == null
                ? TextStyle(color: Theme.of(context).colorScheme.onPrimary)
                : null,
            onSelected: (_) => setState(() => _group = null),
          ),
          for (final group in _examSegments.where(
            (group) =>
                (!_extraExams || group != _goalSegment) &&
                _service.catalog.exams.any((e) => e.segment == group),
          ))
            ChoiceChip(
              key: ValueKey('exam-filter-$group'),
              label: Text(group.toUpperCase()),
              showCheckmark: false,
              visualDensity: const VisualDensity(horizontal: -2, vertical: -1),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              selected: _group == group,
              side: BorderSide(color: _outlineColor),
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: _group == group
                  ? TextStyle(color: Theme.of(context).colorScheme.onPrimary)
                  : null,
              onSelected: (_) => setState(() => _group = group),
            ),
        ],
      ),
    if (_group == 'kpss') _kpssTrackPicker(l10n),
    if (_service.catalog.available &&
        _visibleExams.isEmpty &&
        (_group != 'kpss' || _selectedKpssTrack != null))
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(l10n.examEmptyFilter),
      ),
    for (final exam in _visibleExams)
      Card(
        key: ValueKey('exam-card-${exam.id}'),
        margin: const EdgeInsets.only(top: 10),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _outlineColor),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                exam.name(_turkish),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _metadata(
                    Icons.description_outlined,
                    l10n.examSubjectQuestions(exam.totalQuestions),
                  ),
                  _metadata(
                    Icons.schedule_rounded,
                    '${exam.durationSeconds ~/ 60} ${l10n.minutesUnit}',
                  ),
                  if (exam.id == 'ayt')
                    _metadata(Icons.layers_outlined, l10n.examAytTestCount),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: ValueKey('exam-start-${exam.id}'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
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
    final pendingEarly =
        record.pendingAction == ExamPendingAction.completeEarly;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _outlineColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              record.definition.name(_turkish),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              pendingEarly
                  ? l10n.examEarlyPendingTitle
                  : attempt == null
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
                pendingEarly
                    ? l10n.examEarlyPendingBody
                    : attempt == null
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
            if (_service.canFinishEarly(record))
              FilledButton.tonal(
                key: const ValueKey('exam-finish-early'),
                onPressed: _finishingEarly ? null : () => _finishEarly(record),
                child: Text(l10n.examFinishEarly),
              ),
            if (attempt != null && seconds > 0 && record.pendingAction == null)
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final insights = _studiesLoaded
        ? buildExamTimeInsights(
                attempts: attempts,
                studySessions: _studies,
                definitionFor: _service.definitionFor,
                now: _service.now(),
              )
              .where(
                (insight) =>
                    insight.studyMinutes != 0 || insight.hasAnsweredQuestions,
              )
              .toList()
        : const <ExamTimeInsight>[];
    return [
      Container(
        key: const ValueKey('exam-insights-section'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceContainerLow
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _outlineColor.withValues(alpha: .65)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.examInsights,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (_studiesStale) ...[
              Text(
                _studiesLoaded
                    ? l10n.statsStaleNotice
                    : l10n.statsLoadErrorGeneric,
                style: theme.textTheme.bodyMedium,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _loadStudies,
                  child: Text(l10n.examRetry),
                ),
              ),
            ],
            if (_studiesLoaded && insights.isEmpty)
              Text(
                l10n.examInsightsEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            for (final insight in insights)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainerHigh
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.examInsightsChange(
                    insight.subject.name(_turkish),
                    insight.studyMinutes,
                    formatExamNet(insight.before, l10n.localeName),
                    formatExamNet(insight.after, l10n.localeName),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
              ),
            if (insights.isNotEmpty)
              Text(
                l10n.examInsightsDisclaimer,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      if (attempts.isNotEmpty) ...[
        Text(
          l10n.examTabHistory,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
      ],
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
            subtitle: Text(_errorMessage(l10n, record.errorCode)),
          ),
        ),
    ];
  }

  Widget _historyCard(ExamAttempt attempt, AppLocalizations l10n) {
    final exam = _service.definitionFor(attempt);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final localizations = MaterialLocalizations.of(context);
    String date(DateTime at) {
      final local = at.toLocal();
      return '${localizations.formatShortDate(local)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
    }

    final status = switch (attempt.status) {
      ExamAttemptStatus.completed => l10n.examCompleted,
      ExamAttemptStatus.abandoned => l10n.examAbandoned,
      ExamAttemptStatus.active => l10n.examRunning,
    };
    final net = exam == null || attempt.subjectResults.isEmpty
        ? null
        : attempt.subjectResults.fold<double>(
            0,
            (sum, result) => sum + result.net(exam.wrongAnswerDivisor),
          );
    final selected = attempt.selectedModuleIds;
    final modules = exam?.effectiveModules ?? const <ExamModule>[];
    final scopeKnown =
        selected != null &&
        modules.isNotEmpty &&
        selected.every((id) => modules.any((module) => module.id == id));
    final selectedScopeQuestions = scopeKnown && exam != null
        ? exam.subjects
              .where(
                (subject) =>
                    exam.subjectIdsForModules(selected).contains(subject.id),
              )
              .fold<int>(0, (sum, subject) => sum + subject.questionCount)
        : null;
    return Card(
      key: ValueKey('exam-history-card-${attempt.clientUuid}'),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: _outlineColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  attempt.title ?? exam?.name(_turkish) ?? l10n.examTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (attempt.title != null && exam != null)
                  Text(exam.name(_turkish), style: theme.textTheme.bodyMedium),
                _historyStatus(attempt.status, status),
                if (attempt.finishedEarly)
                  _metadata(Icons.schedule_rounded, l10n.examCompletedEarly),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              date(attempt.startedAt),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceContainerHigh
                    : AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DefaultTextStyle.merge(
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    if (attempt.examId == 'ayt') ...[
                      Text(
                        selectedScopeQuestions != null
                            ? l10n.examSelectedQuestions(
                                selectedScopeQuestions,
                                attempt.totalQuestions,
                              )
                            : selected == null
                            ? l10n.examModuleUnknown
                            : l10n.examScopeUnavailable,
                      ),
                      if (attempt.isCompleted)
                        Text(l10n.examCreditedMinutes(attempt.reportMinutes)),
                    ] else
                      Text(
                        attempt.isCompleted
                            ? l10n.examQuestionsMinutes(
                                attempt.totalQuestions,
                                attempt.reportMinutes,
                              )
                            : l10n.examSubjectQuestions(attempt.totalQuestions),
                      ),
                    if (net != null)
                      Text(
                        '${l10n.examNet}: ${formatExamNet(net, l10n.localeName)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    if (attempt.isCompleted)
                      Text(
                        l10n.examRewardSummary(
                          attempt.pointsEarned,
                          attempt.examCoinsEarned,
                        ),
                        style: TextStyle(color: colors.primary),
                      ),
                    if (attempt.status == ExamAttemptStatus.abandoned)
                      Text(l10n.examNoAward),
                  ],
                ),
              ),
            ),
            if (attempt.isCompleted) ...[
              if (attempt.subjectResults.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.examFinishedNoResults,
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (attempt.subjectResults.isNotEmpty && exam != null)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(l10n.examResultsTitle),
                  children: [
                    for (final subject in exam.subjects)
                      if (attempt.subjectResults.any(
                        (r) => r.subjectId == subject.id,
                      ))
                        Builder(
                          builder: (context) {
                            final result = attempt.subjectResults.firstWhere(
                              (r) => r.subjectId == subject.id,
                            );
                            return ListTile(
                              title: Text(subject.name(_turkish)),
                              subtitle: Text(
                                '${l10n.examCorrect}: ${result.correct} · ${l10n.examWrong}: ${result.wrong} · ${l10n.examBlank}: ${result.blank}',
                              ),
                              trailing: Text(
                                formatExamNet(
                                  result.net(exam.wrongAnswerDivisor),
                                  l10n.localeName,
                                ),
                              ),
                            );
                          },
                        ),
                  ],
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: exam == null
                      ? null
                      : () => showExamResultsDialog(
                          context,
                          service: _service,
                          attempt: attempt,
                        ),
                  child: Text(
                    _service.supportsDetails
                        ? l10n.examDetailsEdit
                        : attempt.subjectResults.isEmpty
                        ? l10n.examEnterResults
                        : l10n.examEditResults,
                  ),
                ),
              ),
            ],
            ExpansionTile(
              key: ValueKey('exam-history-details-${attempt.clientUuid}'),
              tilePadding: EdgeInsets.zero,
              title: Text(
                l10n.examHistoryDetails,
                style: theme.textTheme.bodyMedium,
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${l10n.examStartTime}: ${date(attempt.startedAt)}'),
                      Text(
                        '${l10n.examEndTime}: ${date(attempt.completedAt ?? attempt.endsAt)}',
                      ),
                      if (attempt.finishedEarly) ...[
                        Text(
                          l10n.examActualPlanned(
                            attempt.actualSeconds < 60
                                ? l10n.examSeconds(attempt.actualSeconds)
                                : '${attempt.actualSeconds ~/ 60} ${l10n.minutesUnit}',
                            '${attempt.plannedSeconds ~/ 60} ${l10n.minutesUnit}',
                          ),
                        ),
                        Text(l10n.examCreditedMinutes(attempt.reportMinutes)),
                      ],
                      if (attempt.note != null) Text(attempt.note!),
                      if (attempt.examId == 'ayt' && attempt.isCompleted) ...[
                        if (attempt.selectedModuleIds == null)
                          Text(l10n.examModuleUnknown)
                        else ...[
                          if (selectedScopeQuestions == null)
                            Text(l10n.examScopeUnavailable)
                          else ...[
                            Text(
                              modules
                                  .where((m) => selected!.contains(m.id))
                                  .map((m) => m.name(_turkish))
                                  .join(' · '),
                            ),
                            Text(
                              l10n.examSelectedQuestions(
                                selectedScopeQuestions,
                                attempt.totalQuestions,
                              ),
                            ),
                          ],
                        ],
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // The server uses one synthetic is_me/has_league:false row when no room
    // or global standings exist. It is not an actual first-place result.
    final placeholder =
        league != null &&
        league.rows.length == 1 &&
        league.rows.single['is_me'] == true &&
        league.rows.single['has_league'] == false;
    final entries =
        league?.rows
            .map((row) {
              // Segment standings can redact identity even when is_blocked is
              // false (a user has disabled social visibility).
              final redacted =
                  row.containsKey('id') &&
                  row['id'] == null &&
                  row['name'] == null &&
                  row['is_me'] != true;
              return RankingEntry.fromRow(
                redacted ? {...row, 'is_blocked': true} : row,
                pointsKey: 'points',
              );
            })
            .toList(growable: false) ??
        const <RankingEntry>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceContainerHigh
                : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              for (final scope in ['segment', 'global'])
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: scope == _scope,
                    child: InkWell(
                      key: ValueKey('exam-league-scope-$scope'),
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        if (scope == _scope) return;
                        setState(() {
                          _scope = scope;
                          _league = null;
                        });
                        unawaited(_load());
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        constraints: const BoxConstraints(minHeight: 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scope == _scope
                              ? AppColors.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          scope == 'global'
                              ? l10n.examGlobal
                              : l10n.examTargetGroup,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: scope == _scope
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
        ),
        const SizedBox(height: 16),
        if (_loading) const LinearProgressIndicator(),
        if (!widget.available) Text(l10n.examUnavailableBody),
        if (_failed) ...[
          Text(
            l10n.examError,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton(onPressed: _load, child: Text(l10n.examRetry)),
        ],
        if (league != null) ...[
          RankingCountdownBanner(
            title: _scope == 'global'
                ? l10n.examGlobal
                : leagueTitle(l10n, league.tier),
            target: league.periodEnd,
            now: widget.service.now,
            message: league.phase == 'active' ? null : l10n.examLeaguePreparing,
          ),
          const SizedBox(height: 12),
          Text('${l10n.examPracticeSand}: ${league.examCoins}'),
          const SizedBox(height: 16),
          if ((entries.isEmpty || placeholder) && _scope == 'global')
            const RankingEmptyView()
          else if (entries.isEmpty || placeholder)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.examLeagueEmpty, textAlign: TextAlign.center),
              ),
            )
          else ...[
            RankingPodium(
              top: entries.take(3).toList(),
              compact: Responsive.of(context).isShortHeight,
              // Exam avatars are not ready; do not imply an awarded medal.
              showMedal: (_, _) => false,
            ),
            if (entries.length > 3) ...[
              const SizedBox(height: 20),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainerLowest
                      : AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    for (var i = 3; i < entries.length; i++)
                      RankingRow(entry: entries[i], rank: i + 1),
                  ],
                ),
              ),
            ],
          ],
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
