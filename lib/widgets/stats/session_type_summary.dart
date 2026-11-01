import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/stats_calculator.dart';

/// A compact breakdown shared by the daily, weekly and monthly reports.
/// The figures are supplied by the report calculator; this widget does not
/// recompute or combine session types.
class SessionTypeSummary extends StatelessWidget {
  const SessionTypeSummary({super.key, required this.counts, this.onOpenExams});

  final SessionTypeCounts counts;
  final VoidCallback? onOpenExams;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final figures = [
      (l10n.statsNormalSessions, counts.normalSessions, Icons.timer_outlined),
      (
        l10n.statsCompletedMarathons,
        counts.completedMarathons,
        Icons.flag_outlined,
      ),
      (
        l10n.statsCompletedExams,
        counts.completedExams,
        Icons.assignment_outlined,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.statsSessionTypesTitle, style: textTheme.titleMedium),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                // A single column makes long English labels and large text
                // readable on small phones without clipping.
                final largeText =
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                final stacked = largeText || constraints.maxWidth < 280;
                final tiles = [
                  for (final (label, value, icon) in figures)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.45,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, size: 19, color: colors.primary),
                          const SizedBox(height: 6),
                          Text(
                            '$value',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(label, style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                ];
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < tiles.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        tiles[i],
                      ],
                    ],
                  );
                }
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < tiles.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: tiles[i]),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              '${l10n.statsMarathonFocusCount(counts.marathonFocusSessions)} · ${l10n.statsFocusEquivalent(counts.focusEquivalents)}',
              style: textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (counts.pendingSessions > 0) ...[
              const SizedBox(height: 8),
              Text(
                l10n.statsCountsPending(counts.pendingSessions),
                style: textTheme.bodySmall,
              ),
            ],
            if (counts.unknownSessions > 0) ...[
              const SizedBox(height: 8),
              Text(l10n.statsUnknownSessionTypes, style: textTheme.bodySmall),
            ],
            if (counts.completedExams > 0) ...[
              const SizedBox(height: 8),
              Text(
                l10n.statsExamTotalsInfo,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            if (onOpenExams != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onOpenExams,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(l10n.statsOpenExamDetails),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
