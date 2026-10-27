import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/services/session_queue.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

void main() {
  test('start UUID duration conflict keeps the existing permanent reason', () {
    final failure = classifySessionError(
      const PostgrestException(
        code: 'P0001',
        message: 'invalid duration: session_start_metadata_conflict',
      ),
    );
    expect(failure.kind, SessionFailureKind.permanent);
    expect(failure.reasonCode, SessionReason.invalidDuration);
  });

  test('missing start owner remains an auth retry, not a data deletion', () {
    final failure = classifySessionError(
      const PostgrestException(
        code: 'P0001',
        message: 'not authenticated: profile_not_found',
      ),
    );
    expect(failure.kind, SessionFailureKind.offline);
    expect(failure.reasonCode, SessionReason.auth);
  });
}
