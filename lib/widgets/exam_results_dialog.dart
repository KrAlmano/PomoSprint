import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/exam_details.dart';
import '../models/exam_model.dart';
import '../services/exam_service.dart';
import '../theme.dart';
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
  final Set<String> _editedSubjects = {}, _dirtyKeys = {};
  late final TextEditingController _title, _note;
  late ExamAttempt _attempt;
  late ExamDefinition _definition;
  late final String? _owner;
  late final bool _detailsMode;
  late int _revision;
  Set<String>? _selected;
  bool _saving = false, _invalid = false, _submitted = false;
  bool _ownerDismissalScheduled = false;
  String? _failure;
  Timer? _draftTimer;
  bool get _moduleMode => _detailsMode && _definition.id == 'ayt';
  bool get _moduleSupported =>
      widget.service.catalog.capabilities.aytModulesVersion == 1 &&
      _definition.effectiveModules.isNotEmpty;
  bool get _hasChanges =>
      _editedSubjects.isNotEmpty || (_detailsMode && _dirtyKeys.isNotEmpty);
  bool get _pending =>
      widget.service.recordFor(_attempt.clientUuid)?.pendingDetails != null;
  List<ExamSubject> get _subjects {
    if (!_moduleMode) return _definition.subjects;
    if (!_moduleSupported) return const [];
    final ids = _definition.subjectIdsForModules(_selected ?? {});
    return _definition.subjects.where((s) => ids.contains(s.id)).toList();
  }

  @override
  void initState() {
    super.initState();
    _owner = widget.service.backend.ownerId;
    _attempt = widget.attempt;
    _definition = widget.definition;
    _detailsMode = widget.service.supportsDetails;
    final record = widget.service.recordFor(_attempt.clientUuid);
    final draft = record?.detailsDraft;
    _revision = draft?.revision ?? _attempt.detailsRevision;
    _selected = (draft?.modules ?? _attempt.selectedModuleIds)?.toSet();
    _title = TextEditingController(text: draft?.title ?? _attempt.title ?? '');
    _note = TextEditingController(text: draft?.note ?? _attempt.note ?? '');
    _dirtyKeys.addAll(draft?.dirtyKeys ?? {});
    _editedSubjects.addAll(draft?.dirtySubjects ?? {});
    final results = {
      for (final result in _attempt.subjectResults) result.subjectId: result,
      for (final result in record?.pendingResults ?? <ExamSubjectResult>[])
        result.subjectId: result,
      for (final result
          in record?.pendingDetails?.results ?? <ExamSubjectResult>[])
        result.subjectId: result,
    };
    for (final subject in _definition.subjects) {
      final value = results[subject.id];
      final raw =
          draft?.fields[subject.id] ??
          [
            '${value?.correct ?? 0}',
            '${value?.wrong ?? 0}',
            '${value?.blank ?? subject.questionCount}',
          ];
      _fields[subject.id] = raw
          .map((s) => TextEditingController(text: s))
          .toList();
    }
    _failure = record?.errorCode;
    widget.service.addListener(_serviceChanged);
  }

  void _serviceChanged() {
    if (!mounted) return;
    if (_owner != widget.service.backend.ownerId) {
      if (_ownerDismissalScheduled) return;
      _ownerDismissalScheduled = true;
      final route = ModalRoute.of(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (route?.isActive == true && route?.navigator != null) {
          route!.navigator!.removeRoute(route);
        }
      });
      return;
    }
    setState(() {});
  }

  ExamDetailsDraft _makeDraft() => ExamDetailsDraft(
    revision: _revision,
    title: _title.text,
    note: _note.text,
    dirtyKeys: _dirtyKeys,
    modules: _selected?.toList(),
    dirtySubjects: _editedSubjects,
    fields: {
      for (final e in _fields.entries)
        e.key: e.value.map((c) => c.text).toList(),
    },
  );

  Future<void> _persistDraft() async {
    final owner = _owner;
    if (!_detailsMode || owner == null || !_hasChanges || _submitted) return;
    final draft = _makeDraft();
    await widget.service.updateDetailsDraft(_attempt, draft, owner: owner);
  }

  void _scheduleDraft() {
    if (!_detailsMode) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        await _persistDraft();
      } catch (error) {
        if (mounted) {
          setState(
            () => _failure = error is ExamFailure ? error.code : 'storage',
          );
        }
      }
    });
  }

  void _textLimitExceeded() {
    if (mounted) setState(() => _failure = 'exam_details_invalid');
  }

  @override
  void dispose() {
    widget.service.removeListener(_serviceChanged);
    _draftTimer?.cancel();
    if (!_submitted && widget.service.backend.ownerId == _owner) {
      unawaited(_persistDraft().catchError((Object _) {}));
    }
    _title.dispose();
    _note.dispose();
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

  void _changed(ExamSubject subject, int index) {
    final fields = _fields[subject.id]!;
    if (index < 2) {
      final correct = int.tryParse(fields[0].text),
          wrong = int.tryParse(fields[1].text);
      if (correct != null && wrong != null && correct >= 0 && wrong >= 0) {
        fields[2].text =
            '${(subject.questionCount - correct - wrong).clamp(0, subject.questionCount)}';
      }
    }
    setState(() {
      _editedSubjects.add(subject.id);
      _invalid = false;
      _failure = null;
    });
    _scheduleDraft();
  }

  void _selectModule(ExamModule module, bool selected) {
    if (!selected &&
        _attempt.subjectResults.any(
          (r) => module.subjectIds.contains(r.subjectId),
        )) {
      setState(() => _failure = 'exam_scope_conflict');
      return;
    }
    setState(() {
      _selected ??= {};
      if (selected) {
        _selected!.add(module.id);
      } else {
        _selected!.remove(module.id);
      }
      _dirtyKeys.add('selected_module_ids');
      _invalid = false;
      _failure = null;
    });
    _scheduleDraft();
  }

  Future<void> _save() async {
    final subjects = _subjects
        .where((s) => _editedSubjects.contains(s.id))
        .toList();
    final results = subjects.map(_result).toList();
    final patch = ExamDetailsPatch({
      if (_dirtyKeys.contains('title'))
        'title': _title.text.trim().isEmpty ? null : _title.text.trim(),
      if (_dirtyKeys.contains('note'))
        'note': _note.text.isEmpty ? null : _note.text,
      if (_dirtyKeys.contains('selected_module_ids'))
        'selected_module_ids': [
          for (final m in _definition.effectiveModules)
            if (_selected?.contains(m.id) == true) m.id,
        ],
    });
    if ((!_detailsMode && results.isEmpty) ||
        !subjects.every((s) => results.any((r) => r.isValidFor(s)))) {
      setState(() => _invalid = true);
      return;
    }
    if (_detailsMode && !patch.isValid) {
      setState(() => _failure = 'exam_details_invalid');
      return;
    }
    _draftTimer?.cancel();
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await _persistDraft();
      if (_detailsMode) {
        await widget.service.saveDetails(
          _attempt,
          patch: patch,
          results: results.isEmpty ? null : results,
          expectedRevision: _revision,
        );
      } else {
        await widget.service.saveResults(_attempt, results);
      }
      if (!mounted || _owner != widget.service.backend.ownerId) return;
      final pending =
          widget.service.recordFor(_attempt.clientUuid)?.pendingAction != null;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _detailsMode
                ? (pending ? l10n.examDetailsQueued : l10n.examDetailsSaved)
                : (pending ? l10n.examQueuedResults : l10n.examResultsSaved),
          ),
        ),
      );
      _submitted = true;
      Navigator.pop(context);
    } catch (error) {
      if (mounted && _owner == widget.service.backend.ownerId) {
        setState(() {
          _saving = false;
          _failure = error is ExamFailure ? error.code : 'connection';
        });
      }
    }
  }

  Future<void> _reload() async {
    setState(() => _saving = true);
    try {
      final latest = await widget.service.reloadDetailsForReview(_attempt);
      if (!mounted || _owner != widget.service.backend.ownerId) return;
      if (!_dirtyKeys.contains('title')) _title.text = latest.title ?? '';
      if (!_dirtyKeys.contains('note')) _note.text = latest.note ?? '';
      if (!_dirtyKeys.contains('selected_module_ids')) {
        _selected = latest.selectedModuleIds?.toSet();
      }
      for (final result in latest.subjectResults) {
        if (_editedSubjects.contains(result.subjectId)) continue;
        final row = _fields[result.subjectId];
        if (row == null) continue;
        row[0].text = '${result.correct}';
        row[1].text = '${result.wrong}';
        row[2].text = '${result.blank}';
      }
      setState(() {
        _attempt = latest;
        _revision = latest.detailsRevision;
        _failure = null;
        _saving = false;
      });
      await _persistDraft();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = 'connection';
        });
      }
    }
  }

  String _errorText(AppLocalizations l10n) => switch (_failure) {
    'exam_details_conflict' => l10n.examDetailsConflict,
    'exam_scope_conflict' => l10n.examScopeConflict,
    'exam_details_invalid' => l10n.examDetailsInvalid,
    'exam_definition_unsupported' => l10n.examDefinitionUnsupported,
    'exam_details_pending' => l10n.examDetailsPending,
    _ => l10n.examResultsSaveError,
  };

  Widget _subjectCard(
    BuildContext context,
    ExamSubject subject,
    AppLocalizations l10n, {
    required bool enabled,
    required bool turkish,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final result = _result(subject);
    final labels = [l10n.examCorrect, l10n.examWrong, l10n.examBlank];
    final stackFields =
        MediaQuery.textScalerOf(context).scale(1) >= 1.5 ||
        MediaQuery.sizeOf(context).width < 280;
    Widget input(int index) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stackFields)
          Text(
            labels[index],
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(32),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                labels[index],
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        const SizedBox(height: 5),
        MergeSemantics(
          child: Semantics(
            label: '${subject.name(turkish)}, ${labels[index]}',
            child: TextField(
              key: ValueKey('exam-result-${subject.id}-$index'),
              controller: _fields[subject.id]![index],
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      RegExp(r'^-?\d{0,3}$').hasMatch(newValue.text)
                      ? newValue
                      : oldValue,
                ),
              ],
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: isDark
                    ? AppColors.darkSurfaceContainerHigh
                    : AppColors.surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (_) => _changed(subject, index),
            ),
          ),
        ),
      ],
    );
    return Container(
      key: ValueKey('exam-result-card-${subject.id}'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceContainerLow
            : AppColors.surfaceContainerLowest,
        border: Border.all(
          color: isDark
              ? AppColors.darkOutlineVariant
              : AppColors.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            subject.name(turkish),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.examSubjectQuestions(subject.questionCount),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (stackFields)
            Column(
              children: [
                for (var index = 0; index < 3; index++) ...[
                  if (index > 0) const SizedBox(height: 10),
                  input(index),
                ],
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var index = 0; index < 3; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(child: input(index)),
                ],
              ],
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${l10n.examNet}: ${formatExamNet(result.net(_definition.wrongAnswerDivisor), l10n.localeName)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                l10n.examResultsQuestionTotal(
                  result.answeredTotal,
                  subject.questionCount,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final turkish = Localizations.localeOf(context).languageCode == 'tr';
    final enabled = !_saving && !_pending;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          _detailsMode ? l10n.examDetailsTitle : l10n.examResultsTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: ContentWidth.form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceContainerHigh
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.examResultsInfo,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.examNetRule(_definition.wrongAnswerDivisor),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_moduleMode) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.examSelectModules,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(l10n.examModuleHint),
                if (!_moduleSupported) Text(l10n.examDefinitionUnsupported),
                for (final module
                    in _moduleSupported
                        ? _definition.effectiveModules
                        : <ExamModule>[])
                  CheckboxListTile(
                    key: ValueKey('exam-module-${module.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(module.name(turkish)),
                    value: _selected?.contains(module.id) == true,
                    onChanged: enabled
                        ? (value) => _selectModule(module, value == true)
                        : null,
                  ),
                Text(l10n.examReligionAlternativeInfo),
              ],
              for (final subject in _subjects)
                _subjectCard(
                  context,
                  subject,
                  l10n,
                  enabled: enabled,
                  turkish: turkish,
                ),
              if (_detailsMode) ...[
                const Divider(height: 28),
                TextField(
                  key: const ValueKey('exam-detail-title'),
                  controller: _title,
                  enabled: enabled,
                  inputFormatters: [
                    _ExamTextLimitFormatter(120, _textLimitExceeded),
                  ],
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l10n.examTitleLabel,
                    border: const OutlineInputBorder(),
                    counterText: '${_title.text.runes.length} / 120',
                    semanticCounterText: l10n.examCharacterCount(
                      _title.text.runes.length,
                      120,
                    ),
                  ),
                  onChanged: (_) {
                    setState(() {
                      _dirtyKeys.add('title');
                      _failure = null;
                    });
                    _scheduleDraft();
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('exam-detail-note'),
                  controller: _note,
                  enabled: enabled,
                  inputFormatters: [
                    _ExamTextLimitFormatter(2000, _textLimitExceeded),
                  ],
                  keyboardType: TextInputType.multiline,
                  minLines: 2,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: l10n.examNoteLabel,
                    border: const OutlineInputBorder(),
                    counterText: '${_note.text.runes.length} / 2000',
                    semanticCounterText: l10n.examCharacterCount(
                      _note.text.runes.length,
                      2000,
                    ),
                  ),
                  onChanged: (_) {
                    setState(() {
                      _dirtyKeys.add('note');
                      _failure = null;
                    });
                    _scheduleDraft();
                  },
                ),
              ],
              if (_invalid)
                Text(
                  l10n.examResultsInvalid,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_failure != null)
                Text(
                  _errorText(l10n),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_pending && _failure == null) Text(l10n.examDetailsPending),
              if (_pending && ExamService.needsUserReview(_failure))
                TextButton(
                  key: const ValueKey('exam-details-reload'),
                  onPressed: _saving ? null : _reload,
                  child: Text(l10n.examDetailsReload),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          if (_pending && !ExamService.needsUserReview(_failure))
            TextButton(
              onPressed: _saving
                  ? null
                  : () async {
                      await widget.service.retry(_attempt.clientUuid);
                      if (mounted &&
                          context.mounted &&
                          _owner == widget.service.backend.ownerId) {
                        final current = widget.service.recordFor(
                          _attempt.clientUuid,
                        );
                        if (current?.pendingDetails == null) {
                          _submitted = true;
                          Navigator.pop(context);
                        } else {
                          setState(() => _failure = current?.errorCode);
                        }
                      }
                    },
              child: Text(l10n.examRetry),
            ),
          FilledButton(
            onPressed: enabled && _hasChanges ? _save : null,
            child: Text(_saving ? l10n.examSaving : l10n.examSaveResults),
          ),
        ],
      ),
    );
  }
}

/// PostgreSQL char_length counts Unicode scalars rather than UTF-16 units or
/// grapheme clusters. Reject an oversized paste visibly instead of truncating
/// the user's title/note or persisting an unreadable draft.
class _ExamTextLimitFormatter extends TextInputFormatter {
  _ExamTextLimitFormatter(this.limit, this.onRejected);
  final int limit;
  final VoidCallback onRejected;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= limit) return newValue;
    onRejected();
    return oldValue;
  }
}
