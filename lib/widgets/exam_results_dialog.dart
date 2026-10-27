import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/exam_model.dart';
import '../services/exam_service.dart';
import '../utils/responsive.dart';
import '../utils/exam_format.dart';

Future<void> showExamResultsDialog(
  BuildContext context, {
  required ExamService service,
  required ExamAttempt attempt,
}) async {
  final definition = service.definitionFor(attempt);
  if (definition == null || !attempt.isCompleted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _ResultsDialog(
      service: service,
      attempt: attempt,
      definition: definition,
    ),
  );
}

class _ResultsDialog extends StatefulWidget {
  const _ResultsDialog({
    required this.service,
    required this.attempt,
    required this.definition,
  });
  final ExamService service;
  final ExamAttempt attempt;
  final ExamDefinition definition;
  @override
  State<_ResultsDialog> createState() => _ResultsDialogState();
}

class _ResultsDialogState extends State<_ResultsDialog> {
  final Map<String, List<TextEditingController>> _fields = {};
  bool _saving = false;
  bool _invalid = false;
  bool _saveFailed = false;
  @override
  void initState() {
    super.initState();
    final pending = widget.service.records
        .where((r) => r.clientUuid == widget.attempt.clientUuid)
        .firstOrNull;
    final results = pending?.pendingResults ?? widget.attempt.subjectResults;
    for (final subject in widget.definition.subjects) {
      final value = results.where((r) => r.subjectId == subject.id).firstOrNull;
      _fields[subject.id] = [
        value?.correct ?? 0,
        value?.wrong ?? 0,
        value?.blank ?? subject.questionCount,
      ].map((n) => TextEditingController(text: '$n')).toList();
    }
  }

  @override
  void dispose() {
    for (final row in _fields.values) {
      for (final field in row) {
        field.dispose();
      }
    }
    super.dispose();
  }

  ExamSubjectResult _result(ExamSubject subject) {
    final fields = _fields[subject.id]!;
    return ExamSubjectResult(
      subjectId: subject.id,
      correct: int.tryParse(fields[0].text) ?? -1,
      wrong: int.tryParse(fields[1].text) ?? -1,
      blank: int.tryParse(fields[2].text) ?? -1,
    );
  }

  Future<void> _save() async {
    final results = widget.definition.subjects.map(_result).toList();
    if (!widget.definition.subjects.every(
      (s) => results.any((r) => r.isValidFor(s)),
    )) {
      setState(() => _invalid = true);
      return;
    }
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await widget.service.saveResults(widget.attempt, results);
      if (!mounted) return;
      final pending =
          widget.service.records
              .where((r) => r.clientUuid == widget.attempt.clientUuid)
              .firstOrNull
              ?.pendingAction !=
          null;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pending ? l10n.examQueuedResults : l10n.examResultsSaved,
          ),
        ),
      );
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final turkish = Localizations.localeOf(context).languageCode == 'tr';
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(l10n.examResultsTitle),
        content: SizedBox(
          width: ContentWidth.form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.examResultsInfo),
                const SizedBox(height: 12),
                Text(l10n.examNetRule(widget.definition.wrongAnswerDivisor)),
                for (final subject in widget.definition.subjects) ...[
                  const Divider(height: 28),
                  Text(
                    subject.name(turkish),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(l10n.examSubjectQuestions(subject.questionCount)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var index = 0; index < 3; index++) ...[
                        if (index > 0) const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  l10n.examCorrect,
                                  l10n.examWrong,
                                  l10n.examBlank,
                                ][index],
                              ),
                              TextField(
                                key: ValueKey(
                                  'exam-result-${subject.id}-$index',
                                ),
                                controller: _fields[subject.id]![index],
                                enabled: !_saving,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  semanticCounterText: [
                                    l10n.examCorrect,
                                    l10n.examWrong,
                                    l10n.examBlank,
                                  ][index],
                                ),
                                onChanged: (_) =>
                                    setState(() => _invalid = false),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${l10n.examNet}: ${formatExamNet(_result(subject).net(widget.definition.wrongAnswerDivisor), l10n.localeName)}',
                  ),
                  Text(
                    l10n.examResultsQuestionTotal(
                      _result(subject).answeredTotal,
                      subject.questionCount,
                    ),
                  ),
                ],
                if (_invalid)
                  Text(
                    l10n.examResultsInvalid,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_saveFailed)
                  Text(
                    l10n.examResultsSaveError,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? l10n.examSaving : l10n.examSaveResults),
          ),
        ],
      ),
    );
  }
}
