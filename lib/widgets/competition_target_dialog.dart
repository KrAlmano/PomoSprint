import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/competition_target.dart';
import '../utils/responsive.dart';

String competitionTargetLabel(AppLocalizations l10n, String segment) =>
    switch (segment) {
      'lgs' => l10n.onboardingSegmentLgs,
      'yks' => l10n.onboardingSegmentYks,
      'tus' => l10n.onboardingSegmentTus,
      'kpss' => l10n.onboardingSegmentKpss,
      'language' => l10n.onboardingSegmentLanguage,
      'university' => l10n.onboardingSegmentUniversity,
      'work' => l10n.onboardingSegmentWork,
      _ => l10n.leagueTargetOther,
    };

String competitionDate(AppLocalizations l10n, DateTime at) => DateFormat.yMMMd(
  l10n.localeName,
).add_Hm().format(at.toUtc().add(const Duration(hours: 3)));

Future<CompetitionTarget?> showCompetitionTargetDialog(
  BuildContext context, {
  required CompetitionTarget target,
  required Future<CompetitionTarget> Function(String) save,
}) => showDialog<CompetitionTarget>(
  context: context,
  builder: (_) => CompetitionTargetDialog(target: target, save: save),
);

class CompetitionTargetDialog extends StatefulWidget {
  const CompetitionTargetDialog({
    super.key,
    required this.target,
    required this.save,
  });
  final CompetitionTarget target;
  final Future<CompetitionTarget> Function(String) save;
  @override
  State<CompetitionTargetDialog> createState() =>
      _CompetitionTargetDialogState();
}

class _CompetitionTargetDialogState extends State<CompetitionTargetDialog> {
  late String _selected =
      widget.target.pendingSegment ?? widget.target.currentSegment;
  bool _saving = false;
  bool _failed = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final result = await widget.save(_selected);
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text(l10n.leagueTargetDialogTitle),
        content: SizedBox(
          width: ContentWidth.form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.leagueTargetPolicy),
              const SizedBox(height: 12),
              for (final segment in CompetitionTarget.segments)
                ListTile(
                  key: ValueKey('competition-target-$segment'),
                  contentPadding: EdgeInsets.zero,
                  selected: segment == _selected,
                  enabled: !_saving,
                  title: Text(competitionTargetLabel(l10n, segment)),
                  trailing: Icon(
                    segment == _selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  onTap: () => setState(() => _selected = segment),
                ),
              if (_failed)
                Text(
                  l10n.leagueTargetSaveError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('competition-target-save'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.leagueTargetSave),
          ),
        ],
      ),
    );
  }
}
