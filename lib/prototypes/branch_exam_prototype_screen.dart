import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/exam_catalog_defaults.dart';
import '../utils/exam_format.dart';
import 'branch_exam_plan_dialog.dart';

/// An isolated preview. It never initializes a backend or writes user data.
class BranchExamPrototypeScreen extends StatefulWidget {
  const BranchExamPrototypeScreen({super.key});

  @override
  State<BranchExamPrototypeScreen> createState() =>
      _BranchExamPrototypeScreenState();
}

class _BranchExamPrototypeScreenState extends State<BranchExamPrototypeScreen> {
  final _form = GlobalKey<FormState>();
  final _correct = TextEditingController(text: '0');
  final _wrong = TextEditingController(text: '0');
  BranchExamPlan? _plan;
  Timer? _timer;
  int? _sampleSeconds;
  bool _finished = false;
  bool _showResult = false;

  @override
  void dispose() {
    _timer?.cancel();
    _correct.dispose();
    _wrong.dispose();
    super.dispose();
  }

  Future<void> _configure() async {
    final exams = offlineExamCatalog.exams
        .where((exam) => exam.isValid && exam.subjects.isNotEmpty)
        .toList(growable: false);
    if (exams.isEmpty) return;
    final plan = await showDialog<BranchExamPlan>(
      context: context,
      builder: (_) => BranchExamPlanDialog(exams: exams),
    );
    if (!mounted || plan == null) return;
    _timer?.cancel();
    setState(() {
      _plan = plan;
      _sampleSeconds = null;
      _finished = false;
      _showResult = false;
      _correct.text = '0';
      _wrong.text = '0';
    });
  }

  void _startSample() {
    _timer?.cancel();
    setState(() {
      _sampleSeconds = 5;
      _finished = false;
      _showResult = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        final remaining = (_sampleSeconds ?? 1) - 1;
        _sampleSeconds = remaining;
        if (remaining <= 0) {
          timer.cancel();
          _finished = true;
        }
      });
    });
  }

  Widget _durationOptions(BuildContext context, AppLocalizations l10n) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 350 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        Widget card(int minutes) => Container(
          key: ValueKey('branch-prototype-option-$minutes'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: stacked
              ? Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 19,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$minutes ${l10n.minutesUnit}',
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      l10n.branchPrototypeSand(minutes * 4 ~/ 5),
                      style: text.labelLarge?.copyWith(color: colors.primary),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 19,
                      color: colors.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$minutes ${l10n.minutesUnit}',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.branchPrototypeSand(minutes * 4 ~/ 5),
                      style: text.labelLarge?.copyWith(color: colors.primary),
                    ),
                  ],
                ),
        );
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final minutes in const [25, 50, 75]) ...[
                if (minutes != 25) const SizedBox(height: 8),
                card(minutes),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final minutes in const [25, 50, 75]) ...[
              if (minutes != 25) const SizedBox(width: 8),
              Expanded(child: card(minutes)),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final turkish = Localizations.localeOf(context).languageCode == 'tr';
    final plan = _plan;
    final exam = plan == null
        ? null
        : offlineExamCatalog.byId(plan.catalogExamId);
    final subject = plan == null || exam == null
        ? null
        : exam.subjects.where((s) => s.id == plan.subjectId).firstOrNull;
    final correct = int.tryParse(_correct.text) ?? 0;
    final wrong = int.tryParse(_wrong.text) ?? 0;
    final blanks = plan == null
        ? 0
        : (plan.questionCount - correct - wrong).clamp(0, plan.questionCount);
    final net = exam == null ? 0.0 : correct - wrong / exam.wrongAnswerDivisor;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.branchExamTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.branchPrototypeBadge,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.branchPrototypeNotice,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (plan == null || exam == null || subject == null) ...[
                    Text(
                      l10n.branchPrototypeOverviewTitle,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.branchExamIntro,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.branchPrototypeDurationOptions,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _durationOptions(context, l10n),
                    const SizedBox(height: 10),
                    Text(
                      l10n.branchPrototypeNoLeague,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      key: const ValueKey('branch-prototype-configure'),
                      onPressed: _configure,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(l10n.branchPrototypeConfigure),
                    ),
                  ] else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject.name(turkish),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(exam.name(turkish)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                Chip(
                                  label: Text(
                                    l10n.examSubjectQuestions(
                                      plan.questionCount,
                                    ),
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    '${plan.durationMinutes} ${l10n.minutesUnit}',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.branchExamReward(
                                plan.durationMinutes * 4 ~/ 5,
                              ),
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(l10n.branchPrototypeNoLeague),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_sampleSeconds == null)
                      FilledButton.icon(
                        key: const ValueKey('branch-prototype-start'),
                        onPressed: _startSample,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(l10n.branchPrototypeStart),
                      )
                    else if (!_finished) ...[
                      Text(
                        l10n.branchPrototypeRunning,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '00:${_sampleSeconds!.toString().padLeft(2, '0')}',
                        key: const ValueKey('branch-prototype-timer'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                    ] else ...[
                      Text(
                        l10n.branchPrototypeResults,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Form(
                        key: _form,
                        child: Column(
                          children: [
                            for (final field in [
                              (
                                _correct,
                                l10n.examCorrect,
                                'branch-prototype-correct',
                              ),
                              (
                                _wrong,
                                l10n.examWrong,
                                'branch-prototype-wrong',
                              ),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: TextFormField(
                                  key: ValueKey(field.$3),
                                  controller: field.$1,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    labelText: field.$2,
                                  ),
                                  onChanged: (_) =>
                                      setState(() => _showResult = false),
                                  validator: (_) {
                                    final c = int.tryParse(_correct.text);
                                    final w = int.tryParse(_wrong.text);
                                    return c == null ||
                                            w == null ||
                                            c + w > plan.questionCount
                                        ? l10n.branchPrototypeResultInvalid
                                        : null;
                                  },
                                ),
                              ),
                            Text('${l10n.examBlank}: $blanks'),
                            const SizedBox(height: 8),
                            FilledButton(
                              key: const ValueKey(
                                'branch-prototype-show-result',
                              ),
                              onPressed: () {
                                if (_form.currentState!.validate()) {
                                  setState(() => _showResult = true);
                                }
                              },
                              child: Text(l10n.branchPrototypeResultAction),
                            ),
                          ],
                        ),
                      ),
                      if (_showResult) ...[
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.branchPrototypeResultTitle,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${l10n.examNet}: ${formatExamNet(net, l10n.localeName)}',
                                ),
                                Text(
                                  l10n.branchExamReward(
                                    plan.durationMinutes * 4 ~/ 5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(l10n.branchPrototypeNoSave),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _configure,
                      child: Text(l10n.branchPrototypeReset),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
