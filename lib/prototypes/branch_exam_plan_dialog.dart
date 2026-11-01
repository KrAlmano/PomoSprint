import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/exam_model.dart';

/// A preview plan only. Any future production version must validate it server-side.
class BranchExamPlan {
  const BranchExamPlan({
    required this.catalogExamId,
    required this.subjectId,
    required this.questionCount,
    required this.durationMinutes,
  });

  final String catalogExamId;
  final String subjectId;
  final int questionCount;
  final int durationMinutes;
}

class BranchExamPlanDialog extends StatefulWidget {
  const BranchExamPlanDialog({super.key, required this.exams});

  final List<ExamDefinition> exams;

  @override
  State<BranchExamPlanDialog> createState() => _BranchExamPlanDialogState();
}

class _BranchExamPlanDialogState extends State<BranchExamPlanDialog> {
  final _form = GlobalKey<FormState>();
  late ExamDefinition _exam;
  late ExamSubject _subject;
  late final TextEditingController _questions;
  int _minutes = 25;

  @override
  void initState() {
    super.initState();
    assert(widget.exams.isNotEmpty);
    _exam = widget.exams.first;
    _subject = _exam.subjects.first;
    _questions = TextEditingController(text: '${_subject.questionCount}');
  }

  @override
  void dispose() {
    _questions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final turkish = Localizations.localeOf(context).languageCode == 'tr';
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      key: const ValueKey('branch-exam-plan-dialog'),
      scrollable: true,
      title: Text(l10n.branchExamTitle),
      content: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.branchPrototypeNotice,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(l10n.branchExamIntro),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('branch-exam-source-${_exam.id}'),
              initialValue: _exam.id,
              decoration: InputDecoration(labelText: l10n.branchExamSource),
              isExpanded: true,
              items: [
                for (final exam in widget.exams)
                  DropdownMenuItem(
                    value: exam.id,
                    child: Text(
                      exam.name(turkish),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) {
                if (id == null) return;
                setState(() {
                  _exam = widget.exams.firstWhere((exam) => exam.id == id);
                  _subject = _exam.subjects.first;
                  _questions.text = '${_subject.questionCount}';
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('branch-exam-subject-${_exam.id}'),
              initialValue: _subject.id,
              decoration: InputDecoration(labelText: l10n.branchExamSubject),
              isExpanded: true,
              items: [
                for (final subject in _exam.subjects)
                  DropdownMenuItem(
                    value: subject.id,
                    child: Text(
                      subject.name(turkish),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) {
                if (id == null) return;
                setState(() {
                  _subject = _exam.subjects.firstWhere((s) => s.id == id);
                  _questions.text = '${_subject.questionCount}';
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('branch-exam-questions'),
              controller: _questions,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 3,
              decoration: InputDecoration(labelText: l10n.branchExamQuestions),
              validator: (value) {
                final number = int.tryParse(value ?? '');
                return number == null || number < 1 || number > 200
                    ? l10n.branchExamQuestionsInvalid
                    : null;
              },
            ),
            const SizedBox(height: 8),
            Text(
              l10n.branchExamDuration,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in const [25, 50, 75])
                  ChoiceChip(
                    key: ValueKey('branch-exam-duration-$minutes'),
                    label: Text('$minutes ${l10n.minutesUnit}'),
                    selected: _minutes == minutes,
                    selectedColor: colors.primary,
                    labelStyle: _minutes == minutes
                        ? TextStyle(color: colors.onPrimary)
                        : null,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _minutes = minutes),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.branchExamReward(_minutes * 4 ~/ 5),
              key: const ValueKey('branch-exam-reward'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('branch-exam-confirm'),
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(
              context,
              BranchExamPlan(
                catalogExamId: _exam.id,
                subjectId: _subject.id,
                questionCount: int.parse(_questions.text),
                durationMinutes: _minutes,
              ),
            );
          },
          child: Text(l10n.branchPrototypePlanContinue),
        ),
      ],
    );
  }
}
