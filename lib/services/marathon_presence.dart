import 'session_queue.dart' show isUuidCategoryId;

/// Enable only a server that enforces the same presence policy as the UI.
bool supportsMarathonPresence(Map<String, dynamic>? config) =>
    config?['available'] == true &&
    config?['break_seconds'] == 300 &&
    config?['presence_required'] == true &&
    config?['presence_seconds'] == 60 &&
    config?['presence_start_grace_seconds'] == 10;

/// Authenticated handshake. The server owns the immutable break window and
/// binds its confirmation to exactly one next-session UUID. No optimistic
/// success, anonymous calls, background retry, or locally fabricated receipt.
Future<bool> requestMarathonPresence({
  required String marathonUuid,
  required int completedSessionIndex,
  required String previousClientUuid,
  required String nextClientUuid,
  required Future<Object?> Function(String name, Map<String, dynamic> params)
  rpc,
  required bool Function() isCurrent,
  required DateTime Function() serverNow,
}) async {
  if (!isUuidCategoryId(marathonUuid) ||
      !isUuidCategoryId(previousClientUuid) ||
      !isUuidCategoryId(nextClientUuid) ||
      nextClientUuid == previousClientUuid ||
      completedSessionIndex < 1 ||
      completedSessionIndex > 3 ||
      !isCurrent()) {
    return false;
  }
  final gate = await rpc('start_marathon_break', {
    'p_marathon_uuid': marathonUuid,
    'p_completed_session_index': completedSessionIndex,
    'p_previous_client_uuid': previousClientUuid,
  });
  if (!isCurrent() || gate is! Map || gate['error'] != null) return false;
  final end = _date(gate['break_ends_at']);
  final deadline = _date(gate['confirmation_deadline']);
  if (end == null || deadline == null || !deadline.isAfter(end)) return false;
  final receipt = await rpc('confirm_marathon_presence', {
    'p_marathon_uuid': marathonUuid,
    'p_next_session_index': completedSessionIndex + 1,
    'p_next_client_uuid': nextClientUuid,
  });
  if (!isCurrent() || receipt is! Map || receipt['error'] != null) return false;
  final confirmed = _date(receipt['confirmed_at']);
  final now = serverNow().toUtc();
  return receipt['confirmed'] == true &&
      receipt['next_client_uuid'] == nextClientUuid &&
      _date(receipt['break_ends_at']) == end &&
      _date(receipt['confirmation_deadline']) == deadline &&
      confirmed != null &&
      !confirmed.isBefore(end) &&
      confirmed.isBefore(deadline) &&
      now.isBefore(deadline) &&
      !now.isBefore(confirmed.subtract(const Duration(seconds: 2))) &&
      !now.isAfter(confirmed.add(const Duration(seconds: 10)));
}

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;
