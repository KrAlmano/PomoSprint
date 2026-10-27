import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/responsive.dart';

/// Presentation only: the timer owns deadlines, confirmations and saved sessions.
enum MarathonCardStage {
  preview,
  focus,
  saving,
  breakTime,
  checkIn,
  finished,
  timedOut,
  unavailable,
}

/// Compact marathon route. Only a newly completed session animates; restoring a
/// saved plan or changing its identity never replays completion celebrations.
class MarathonProgressCard extends StatefulWidget {
  const MarathonProgressCard({
    super.key,
    required this.totalSessions,
    required this.completedSessions,
    required this.durationMinutes,
    required this.stage,
    required this.statusText,
    this.progressIdentity,
    this.onInfo,
    this.footer,
  }) : assert(totalSessions >= 2 && totalSessions <= 4),
       assert(completedSessions >= 0 && completedSessions <= totalSessions),
       assert(durationMinutes == 25 || durationMinutes == 50);

  final int totalSessions;
  final int completedSessions;
  final int durationMinutes;
  final MarathonCardStage stage;
  final String statusText;
  final String? progressIdentity;
  final VoidCallback? onInfo;
  final Widget? footer;

  /// Matches the card's wrapped typography so a phone timer can reserve room
  /// for its controls before sizing the hourglass. The host still scrolls when
  /// accessibility text makes the controls taller than the viewport.
  static double estimatedHeight(
    BuildContext context, {
    required double width,
    bool hasFooter = true,
    String statusText = '',
    int totalSessions = 4,
    int durationMinutes = 25,
  }) {
    final responsive = Responsive.of(context);
    final l10n = AppLocalizations.of(context)!;
    final padding = responsive.isCompact ? 12.0 : 16.0;
    final inner = (math.min(width, 520) - padding * 2).clamp(
      1.0,
      double.infinity,
    );
    final defaults = DefaultTextStyle.of(context).style;
    double textHeight(String text, TextStyle style, double maxWidth) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: defaults.merge(style)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: math.max(1, maxWidth));
      final height = painter.height;
      painter.dispose();
      return height;
    }

    double textWidth(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: defaults.merge(style)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    const titleStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w800);
    const countStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w500);
    final title = l10n.marathonTitle.toUpperCase();
    final count = l10n.marathonSessionCount(totalSessions);
    final headerWidth = math.max(1.0, inner - 32 - 8 - 48);
    final titleHeight = textHeight(title, titleStyle, headerWidth);
    final countHeight = textHeight(count, countStyle, headerWidth - 16) + 8;
    final wrapsHeader =
        textWidth(title, titleStyle) + 8 + textWidth(count, countStyle) + 16 >
        headerWidth;
    final header = math.max(
      48.0,
      wrapsHeader
          ? titleHeight + 4 + countHeight
          : math.max(titleHeight, countHeight),
    );
    const captionStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w600);
    final captions = [
      l10n.marathonStepStart,
      l10n.marathonStepGoal,
      for (var index = 1; index < totalSessions - 1; index++)
        '${(index + 1) * durationMinutes} ${l10n.minAbbr}',
    ];
    final captionHeight = captions
        .map(
          (label) => textHeight(label, captionStyle, inner / totalSessions - 4),
        )
        .reduce(math.max);
    final status = statusText.isEmpty
        ? 0.0
        : 12 +
              18 +
              math.max(
                17,
                textHeight(
                  statusText,
                  const TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                  inner - 46,
                ),
              );
    final nodeSize = responsive.isCompact ? 40.0 : 44.0;
    // A small margin covers fractional text/border rounding at unusual scales.
    return padding * 2 +
        header +
        8 +
        nodeSize +
        6 +
        captionHeight +
        status +
        (hasFooter ? 10 + 48 : 0) +
        4;
  }

  @override
  State<MarathonProgressCard> createState() => _MarathonProgressCardState();
}

class _MarathonProgressCardState extends State<MarathonProgressCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _completion;
  late int _previousCompleted;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _previousCompleted = widget.completedSessions;
    _completion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      value: 1,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reducedMotion) {
      _completion.stop();
      _completion.value = 1;
    }
  }

  @override
  void didUpdateWidget(MarathonProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final samePlan =
        oldWidget.progressIdentity == widget.progressIdentity &&
        oldWidget.totalSessions == widget.totalSessions &&
        oldWidget.durationMinutes == widget.durationMinutes;
    if (samePlan && widget.completedSessions > oldWidget.completedSessions) {
      _previousCompleted = oldWidget.completedSessions;
      if (!_reducedMotion) {
        _completion.forward(from: 0);
      } else {
        _completion.value = 1;
      }
    } else if (!samePlan ||
        widget.completedSessions < oldWidget.completedSessions) {
      _previousCompleted = widget.completedSessions;
      _completion.stop();
      _completion.value = 1;
    }
  }

  @override
  void dispose() {
    _completion.dispose();
    super.dispose();
  }

  IconData get _statusIcon => switch (widget.stage) {
    MarathonCardStage.preview => Icons.route_rounded,
    MarathonCardStage.focus => Icons.timer_outlined,
    MarathonCardStage.saving => Icons.cloud_upload_outlined,
    MarathonCardStage.breakTime => Icons.coffee_outlined,
    MarathonCardStage.checkIn => Icons.timer_outlined,
    MarathonCardStage.finished => Icons.emoji_events_outlined,
    MarathonCardStage.timedOut => Icons.pause_circle_outline_rounded,
    MarathonCardStage.unavailable => Icons.info_outline_rounded,
  };

  Color _accent(ColorScheme colors) => switch (widget.stage) {
    MarathonCardStage.breakTime => colors.tertiary,
    MarathonCardStage.unavailable ||
    MarathonCardStage.timedOut => colors.onSurfaceVariant,
    _ => colors.primary,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final responsive = Responsive.of(context);
    final padding = responsive.isCompact ? 12.0 : 16.0;
    final accent = _accent(colors);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        Icons.flag_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          l10n.marathonTitle.toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: colors.onSurface,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest.withValues(
                              alpha: 0.55,
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            l10n.marathonSessionCount(widget.totalSessions),
                            key: const ValueKey('marathon-card-session-count'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('marathon-card-info'),
                    onPressed: widget.onInfo,
                    tooltip: l10n.marathonAutomaticHint,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _completion,
                builder: (context, _) => _buildSteps(context, accent),
              ),
              if (widget.statusText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Semantics(
                  key: const ValueKey('marathon-card-status'),
                  // The owning timer exposes deadline semantics. Do not repeat
                  // screen-reader announcements for every countdown rebuild.
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.055),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: accent.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Icon(_statusIcon, size: 17, color: accent),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            widget.statusText,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (widget.footer != null) ...[
                const SizedBox(height: 10),
                widget.footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSteps(BuildContext context, Color accent) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final nodeSize = Responsive.of(context).isCompact ? 40.0 : 44.0;
    final count = widget.totalSessions;
    final t = Curves.easeOutCubic.transform(_completion.value);
    final animatedCompleted =
        _previousCompleted +
        (widget.completedSessions - _previousCompleted) * t;
    return Semantics(
      key: const ValueKey('marathon-card-route'),
      label: l10n.marathonProgress(widget.completedSessions, count),
      explicitChildNodes: true,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: nodeSize,
            child: ExcludeSemantics(
              child: CustomPaint(
                key: const ValueKey('marathon-card-connectors'),
                painter: _MarathonConnectors(
                  count: count,
                  nodeSize: nodeSize,
                  completed: animatedCompleted,
                  background: colors.outlineVariant.withValues(alpha: 0.5),
                  foreground: accent,
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < count; index++)
                Expanded(child: _buildStep(context, index, nodeSize, accent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    int index,
    double nodeSize,
    Color accent,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final completed = index < widget.completedSessions;
    final active =
        index == widget.completedSessions &&
        widget.stage != MarathonCardStage.unavailable &&
        widget.stage != MarathonCardStage.timedOut &&
        widget.stage != MarathonCardStage.finished;
    final focusing =
        active &&
        (widget.stage == MarathonCardStage.focus ||
            widget.stage == MarathonCardStage.preview);
    final newlyCompleted = completed && index >= _previousCompleted;
    final wave = newlyCompleted && !_reducedMotion
        ? math.sin(math.pi * _completion.value)
        : 0.0;
    final stateLabel = completed
        ? l10n.marathonStepCompleted
        : active
        ? l10n.marathonStepCurrent
        : l10n.marathonStepUpcoming;
    final label = index == 0
        ? l10n.marathonStepStart
        : index == widget.totalSessions - 1
        ? l10n.marathonStepGoal
        : '${(index + 1) * widget.durationMinutes} ${l10n.minAbbr}';
    final fill = completed
        ? accent
        : focusing
        ? colors.onSurface
        : colors.surface;
    final foreground = completed
        ? colors.surface
        : focusing
        ? colors.surface
        : active
        ? accent
        : colors.onSurfaceVariant;
    return Semantics(
      key: ValueKey('marathon-card-step-${index + 1}'),
      label: '${index + 1}. $label, $stateLabel',
      selected: active,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              key: ValueKey('marathon-card-pop-${index + 1}'),
              scale: 1 + 0.13 * wave,
              child: Container(
                key: ValueKey('marathon-card-node-${index + 1}'),
                width: nodeSize,
                height: nodeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: Border.all(
                    color: completed || active ? accent : colors.outlineVariant,
                    width: active ? 2 : 1.5,
                  ),
                  boxShadow: wave > 0
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.2 * wave),
                            blurRadius: 14 * wave,
                            spreadRadius: 3 * wave,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: completed
                    ? Icon(
                        Icons.check_rounded,
                        key: ValueKey('marathon-card-check-${index + 1}'),
                        size: 23,
                        color: foreground,
                      )
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: completed || active
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarathonConnectors extends CustomPainter {
  const _MarathonConnectors({
    required this.count,
    required this.nodeSize,
    required this.completed,
    required this.background,
    required this.foreground,
  });

  final int count;
  final double nodeSize;
  final double completed;
  final Color background;
  final Color foreground;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / count;
    final paint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < count - 1; index++) {
      final start = Offset(
        cell * (index + 0.5) + nodeSize / 2 + 5,
        size.height / 2,
      );
      final end = Offset(
        cell * (index + 1.5) - nodeSize / 2 - 5,
        size.height / 2,
      );
      if (end.dx <= start.dx) continue;
      paint.color = background;
      canvas.drawLine(start, end, paint);
      final fill = (completed - index).clamp(0.0, 1.0);
      if (fill > 0) {
        paint.color = foreground;
        canvas.drawLine(
          start,
          Offset(start.dx + (end.dx - start.dx) * fill, end.dy),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_MarathonConnectors oldDelegate) =>
      count != oldDelegate.count ||
      nodeSize != oldDelegate.nodeSize ||
      completed != oldDelegate.completed ||
      background != oldDelegate.background ||
      foreground != oldDelegate.foreground;
}
