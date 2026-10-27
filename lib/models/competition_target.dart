import 'package:flutter/foundation.dart';

@immutable
class CompetitionTarget {
  const CompetitionTarget({
    required this.currentSegment,
    this.pendingSegment,
    this.effectiveAt,
  });

  static const segments = [
    'lgs',
    'yks',
    'tus',
    'kpss',
    'language',
    'university',
    'work',
    'other',
  ];
  final String currentSegment;
  final String? pendingSegment;
  final DateTime? effectiveAt;

  static CompetitionTarget? fromJson(Object? value) {
    if (value is! Map) return null;
    final current = value['current_segment'];
    final pending = value['pending_segment'];
    final effective = value['effective_at'];
    final date = effective == null
        ? null
        : DateTime.tryParse(effective.toString());
    if (!segments.contains(current) ||
        (pending != null && !segments.contains(pending)) ||
        (pending != null && date == null) ||
        (pending == null && effective != null)) {
      return null;
    }
    return CompetitionTarget(
      currentSegment: current as String,
      pendingSegment: pending as String?,
      effectiveAt: date,
    );
  }
}
