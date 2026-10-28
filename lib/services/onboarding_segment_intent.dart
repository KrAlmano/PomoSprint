import 'package:shared_preferences/shared_preferences.dart';

import '../utils/async_lock.dart';

/// Only explicit onboarding CHECK fallbacks are stored here. This is not a
/// general profile override: a non-null server choice always wins on replay.
class OnboardingSegmentIntentStore {
  final AsyncLock _lock = AsyncLock();
  final Set<String> _retired = {};
  static const segments = {
    'lgs',
    'yks',
    'tus',
    'dus',
    'kpss',
    'language',
    'university',
    'work',
  };
  static String keyFor(String owner) => 'onboarding_segment_intent_uid_$owner';

  Future<String?> read(String owner) => _lock.synchronized(() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(keyFor(owner));
    return segments.contains(value) ? value : null;
  });

  Future<bool> remember(
    String owner,
    String segment, {
    required bool Function() isCurrent,
  }) => _lock.synchronized(() async {
    if (_retired.contains(owner) ||
        !isCurrent() ||
        !segments.contains(segment)) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final key = keyFor(owner);
    final previous = prefs.getString(key);
    final saved = await prefs.setString(key, segment);
    if (saved && !_retired.contains(owner) && isCurrent()) return true;
    if (previous == null || _retired.contains(owner)) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, previous);
    }
    return false;
  });

  Future<void> clear(String owner, {required bool Function() isCurrent}) =>
      _lock.synchronized(() async {
        if (!isCurrent()) return;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(keyFor(owner));
      });

  /// A failed/unsupported write keeps the intent for the next profile load.
  /// The lock makes concurrent profile refreshes share one successful replay.
  Future<String?> replay(
    String owner, {
    required String? serverSegment,
    required bool Function() isCurrent,
    required Future<bool> Function(String segment) writeIfStillNull,
  }) => _lock.synchronized(() async {
    if (_retired.contains(owner) || !isCurrent()) return serverSegment;
    final prefs = await SharedPreferences.getInstance();
    final key = keyFor(owner);
    final pending = prefs.getString(key);
    if (!segments.contains(pending)) return serverSegment;
    if (serverSegment != null) {
      // Another accepted server/profile choice supersedes this old fallback.
      if (isCurrent()) await prefs.remove(key);
      return serverSegment;
    }
    bool accepted;
    try {
      accepted = await writeIfStillNull(pending!);
    } catch (_) {
      return serverSegment;
    }
    if (!accepted || _retired.contains(owner) || !isCurrent()) {
      return serverSegment;
    }
    await prefs.remove(key);
    return pending;
  });

  Future<void> retireOwner(String owner) {
    _retired.add(owner);
    return _lock.synchronized(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyFor(owner));
    });
  }
}
