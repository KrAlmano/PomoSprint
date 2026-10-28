import 'package:flutter/foundation.dart';

import 'exam_model.dart';

/// Missing keys preserve server values; explicit null clears only title/note.
@immutable
class ExamDetailsPatch {
  ExamDetailsPatch(Map<String, Object?> values)
    : values = Map.unmodifiable({
        for (final entry in values.entries)
          entry.key: entry.value is List
              ? List<String>.unmodifiable((entry.value as List).cast<String>())
              : entry.value,
      });
  final Map<String, Object?> values;
  bool get isEmpty => values.isEmpty;
  bool get isValid => values.entries.every(
    (entry) => switch (entry.key) {
      'title' =>
        entry.value == null ||
            (entry.value is String &&
                validExamText(entry.value as String, title: true)),
      'note' =>
        entry.value == null ||
            (entry.value is String &&
                validExamText(entry.value as String, title: false)),
      'selected_module_ids' =>
        entry.value is List<String> &&
            (entry.value as List<String>).isNotEmpty &&
            (entry.value as List<String>).length <= 4 &&
            (entry.value as List<String>).toSet().length ==
                (entry.value as List<String>).length,
      _ => false,
    },
  );
  Map<String, Object?> toJson() => Map.of(values);
  static ExamDetailsPatch? fromJson(Object? value) {
    if (value is! Map || value.keys.any((key) => key is! String)) return null;
    try {
      final patch = ExamDetailsPatch(Map<String, Object?>.from(value));
      return patch.isValid ? patch : null;
    } catch (_) {
      return null;
    }
  }
}

/// Once queued, this exact request is retried unchanged, including revision.
@immutable
class ExamDetailsMutation {
  ExamDetailsMutation({
    required this.patch,
    required this.expectedRevision,
    List<ExamSubjectResult>? results,
  }) : results = results == null ? null : List.unmodifiable(results);
  final ExamDetailsPatch patch;
  final int expectedRevision;
  final List<ExamSubjectResult>? results;
  Map<String, dynamic> toJson() => {
    'patch': patch.toJson(),
    'expected_revision': expectedRevision,
    'results': results?.map((r) => r.toJson()).toList(),
  };
  static ExamDetailsMutation? fromJson(Object? value) {
    if (value is! Map ||
        value['expected_revision'] is! int ||
        (value['expected_revision'] as int) < 0) {
      return null;
    }
    final patch = ExamDetailsPatch.fromJson(value['patch']);
    final raw = value['results'];
    if (patch == null || (raw != null && raw is! List)) return null;
    final parsed = (raw as List?)?.map(ExamSubjectResult.fromJson).toList();
    if (parsed != null &&
        (parsed.any((r) => r == null) ||
            parsed.map((r) => r!.subjectId).toSet().length != parsed.length)) {
      return null;
    }
    return ExamDetailsMutation(
      patch: patch,
      expectedRevision: value['expected_revision'] as int,
      results: parsed?.cast<ExamSubjectResult>(),
    );
  }
}

/// Unsubmitted form text, separate from the immutable outbound mutation.
@immutable
class ExamDetailsDraft {
  ExamDetailsDraft({
    required this.revision,
    required this.title,
    required this.note,
    required Set<String> dirtyKeys,
    List<String>? modules,
    required Map<String, List<String>> fields,
    required Set<String> dirtySubjects,
  }) : dirtyKeys = Set.unmodifiable(dirtyKeys),
       modules = modules == null ? null : List.unmodifiable(modules),
       fields = Map.unmodifiable({
         for (final e in fields.entries)
           e.key: List<String>.unmodifiable(e.value),
       }),
       dirtySubjects = Set.unmodifiable(dirtySubjects);
  final int revision;
  final String title, note;
  final Set<String> dirtyKeys, dirtySubjects;
  final List<String>? modules;
  final Map<String, List<String>> fields;
  bool get hasSupportedTextLengths =>
      title.runes.length <= 120 && note.runes.length <= 2000;
  ExamDetailsDraft atRevision(int value) => ExamDetailsDraft(
    revision: value,
    title: title,
    note: note,
    dirtyKeys: dirtyKeys,
    modules: modules,
    fields: fields,
    dirtySubjects: dirtySubjects,
  );
  Map<String, dynamic> toJson() => {
    'revision': revision,
    'title': title,
    'note': note,
    'dirty_keys': dirtyKeys.toList(),
    'modules': modules,
    'fields': fields,
    'dirty_subjects': dirtySubjects.toList(),
  };
  static ExamDetailsDraft? fromJson(Object? value) {
    if (value is! Map ||
        value['revision'] is! int ||
        (value['revision'] as int) < 0 ||
        value['title'] is! String ||
        value['note'] is! String ||
        (value['title'] as String).length > 5000 ||
        (value['note'] as String).length > 20000 ||
        value['fields'] is! Map ||
        value['dirty_keys'] is! List ||
        value['dirty_subjects'] is! List ||
        (value['modules'] != null && value['modules'] is! List)) {
      return null;
    }
    try {
      final fields = {
        for (final e in (value['fields'] as Map).entries)
          e.key as String: (e.value as List).cast<String>(),
      };
      if (fields.length > 32 ||
          fields.values.any(
            (row) =>
                row.length != 3 ||
                row.any((s) => !RegExp(r'^-?\d{0,3}$').hasMatch(s)),
          )) {
        return null;
      }
      final keys = (value['dirty_keys'] as List).cast<String>().toSet();
      if (!{'title', 'note', 'selected_module_ids'}.containsAll(keys)) {
        return null;
      }
      return ExamDetailsDraft(
        revision: value['revision'] as int,
        title: value['title'] as String,
        note: value['note'] as String,
        dirtyKeys: keys,
        modules: (value['modules'] as List?)?.cast<String>(),
        fields: fields,
        dirtySubjects: (value['dirty_subjects'] as List).cast<String>().toSet(),
      );
    } catch (_) {
      return null;
    }
  }
}
