import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../utils/stats_calculator.dart';

class SessionTypeSummary extends StatelessWidget {
  const SessionTypeSummary({super.key, required this.counts, this.onOpenExams});
  final SessionTypeCounts counts;
  final VoidCallback? onOpenExams;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.statsSessionTypesTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final row in [
                  (l10n.statsNormalSessions, counts.normalSessions),
                  (l10n.statsCompletedMarathons, counts.completedMarathons),
                  (l10n.statsCompletedExams, counts.completedExams),
                ])
                  Chip(label: Text('${row.$1}: ${row.$2}')),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.statsMarathonFocusCount(counts.marathonFocusSessions)),
            Text(l10n.statsFocusEquivalent(counts.focusEquivalents)),
            if (counts.pendingSessions > 0)
              Text(l10n.statsCountsPending(counts.pendingSessions)),
            if (counts.unknownSessions > 0) Text(l10n.statsUnknownSessionTypes),
            if (counts.completedExams > 0) Text(l10n.statsExamTotalsInfo),
            if (onOpenExams != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onOpenExams,
                  icon: const Icon(Icons.assignment_outlined),
                  label: Text(l10n.statsOpenExamDetails),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
