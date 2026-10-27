import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/marathon_progress.dart';
import '../utils/responsive.dart';
import 'marathon_progress_card.dart';

/// A selection only. The timer validates and starts the plan after the modal
/// closes; dismissing the modal never changes the active session or persistence.
@immutable
class MarathonPlanChoice {
  const MarathonPlanChoice({
    required this.totalSessions,
    required this.durationMinutes,
  }) : assert(totalSessions >= 2 && totalSessions <= 4),
       assert(durationMinutes == 25 || durationMinutes == 50);

  final int totalSessions;
  final int durationMinutes;
}

/// Keeps the full marathon planner outside the normal hourglass layout.
class MarathonPlanDialog extends StatefulWidget {
  const MarathonPlanDialog({
    super.key,
    this.initialTotalSessions = 2,
    this.initialDurationMinutes = 25,
    this.marathonBonuses,
    this.onInfo,
  }) : assert(initialTotalSessions >= 2 && initialTotalSessions <= 4),
       assert(initialDurationMinutes == 25 || initialDurationMinutes == 50);

  final int initialTotalSessions;
  final int initialDurationMinutes;
  final Map<int, Map<int, int>>? marathonBonuses;
  final VoidCallback? onInfo;

  @override
  State<MarathonPlanDialog> createState() => _MarathonPlanDialogState();
}

class _MarathonPlanDialogState extends State<MarathonPlanDialog> {
  late int _sessions;
  late int _minutes;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _sessions = widget.initialTotalSessions;
    _minutes = widget.initialDurationMinutes;
  }

  void _close({bool start = false}) {
    // A popped route remains visible during its exit animation. A second tap
    // must not pop the owning timer (or a countdown opened after this result).
    if (_submitted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    _submitted = true;
    Navigator.of(context).pop(
      start
          ? MarathonPlanChoice(
              totalSessions: _sessions,
              durationMinutes: _minutes,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final responsive = Responsive.of(context);
    final media = MediaQuery.of(context);
    final availableHeight =
        media.size.height -
        media.viewInsets.vertical -
        media.padding.vertical -
        32;
    final bonus =
        widget.marathonBonuses?[_minutes]?[_sessions] ??
        marathonBonusPreview(
          totalSessions: _sessions,
          durationMinutes: _minutes,
        );

    return Dialog(
      key: const ValueKey('marathon-planner-dialog'),
      insetPadding: EdgeInsets.symmetric(
        horizontal: responsive.isCompact ? 16 : 24,
        vertical: 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: math.max(0, availableHeight),
        ),
        child: Padding(
          padding: EdgeInsets.all(responsive.isCompact ? 16 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  key: const ValueKey('marathon-plan-scroll'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.marathonChooseCount,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontSize: responsive.isShortHeight
                                        ? 16
                                        : 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          IconButton(
                            key: const ValueKey('marathon-plan-cancel'),
                            onPressed: _close,
                            tooltip: l10n.cancel,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        key: const ValueKey('marathon-count-row'),
                        children: [
                          for (final count in [2, 3, 4])
                            Expanded(
                              child: Center(
                                child: Tooltip(
                                  message: l10n.marathonSessionCount(count),
                                  excludeFromSemantics: true,
                                  child: Semantics(
                                    key: ValueKey(
                                      'marathon-count-semantics-$count',
                                    ),
                                    label: l10n.marathonSessionCount(count),
                                    selected: _sessions == count,
                                    child: OutlinedButton(
                                      key: ValueKey('marathon-count-$count'),
                                      onPressed: () =>
                                          setState(() => _sessions = count),
                                      style: OutlinedButton.styleFrom(
                                        fixedSize: const Size.square(56),
                                        minimumSize: const Size.square(56),
                                        maximumSize: const Size.square(56),
                                        padding: const EdgeInsets.all(8),
                                        shape: const CircleBorder(),
                                        backgroundColor: _sessions == count
                                            ? colors.primary
                                            : colors.surface,
                                        foregroundColor: _sessions == count
                                            ? colors.onPrimary
                                            : colors.onSurfaceVariant,
                                        side: BorderSide(
                                          color: _sessions == count
                                              ? colors.primary
                                              : colors.outlineVariant,
                                          width: _sessions == count ? 2 : 1.5,
                                        ),
                                      ),
                                      child: ExcludeSemantics(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '$count',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _label(l10n.marathonDurationLabel),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final minutes in [25, 50]) ...[
                            if (minutes == 50) const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                key: ValueKey('marathon-duration-$minutes'),
                                onPressed: () =>
                                    setState(() => _minutes = minutes),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 12,
                                  ),
                                  foregroundColor: _minutes == minutes
                                      ? colors.onPrimaryContainer
                                      : colors.onSurfaceVariant,
                                  backgroundColor: _minutes == minutes
                                      ? colors.primaryContainer
                                      : colors.surface,
                                  side: BorderSide(
                                    color: _minutes == minutes
                                        ? colors.primary
                                        : colors.outlineVariant,
                                  ),
                                ),
                                child: Semantics(
                                  selected: _minutes == minutes,
                                  child: Text(
                                    '$minutes ${l10n.minAbbr}',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      MarathonProgressCard(
                        totalSessions: _sessions,
                        completedSessions: 0,
                        durationMinutes: _minutes,
                        stage: MarathonCardStage.preview,
                        statusText: l10n.marathonMinutesSummary(
                          _sessions * _minutes,
                          _sessions * _minutes + (_sessions - 1) * 5,
                        ),
                        onInfo: widget.onInfo,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.marathonBonusHint(bonus),
                        key: const ValueKey('marathon-plan-bonus'),
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.marathonBreakHint,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('marathon-start'),
                  onPressed: () => _close(start: true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                  ),
                  child: Text(l10n.marathonStart, textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
  );
}
