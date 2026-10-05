import 'package:flutter/foundation.dart';

/// Kayıtlı hızlı sayaç yalnızca açıkça seçilmiş yerel backend + debug'da.
/// Üretim sunucusuna kısa seans gönderilmez.
bool localQuickRecordingAllowed({
  bool debug = kDebugMode,
  bool requested = const bool.fromEnvironment('QUICK_TIMER_SAVE'),
  String url = const String.fromEnvironment('SUPABASE_URL'),
}) {
  final uri = Uri.tryParse(url);
  return debug &&
      requested &&
      uri?.scheme == 'http' &&
      const {'127.0.0.1', 'localhost', '::1', '10.0.2.2'}.contains(uri?.host);
}

final bool recordLocalQuickSessions = localQuickRecordingAllowed();
