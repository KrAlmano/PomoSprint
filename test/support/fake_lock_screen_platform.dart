import 'package:pomodoro/services/lock_screen_timer.dart';

/// Hangi durumda platforma hangi çağrının gittiğini kaydeder.
class FakeLockScreenPlatform extends LockScreenTimerPlatform {
  final List<String> calls = [];
  final List<LockScreenTimerContent> shown = [];
  bool showResult = true;
  Object? showError;
  Object? clearError;

  @override
  Future<bool> show(LockScreenTimerContent content, {required bool isNewSession}) async {
    final error = showError;
    if (error != null) throw error;
    calls.add('show:${content.isPaused ? 'paused' : 'running'}:${content.sessionId}:${isNewSession ? 'new' : 'same'}');
    shown.add(content);
    return showResult;
  }

  @override
  Future<void> clear() async {
    final error = clearError;
    if (error != null) throw error;
    calls.add('clear');
  }
}
