import 'dart:io' show Platform;

/// `flutter test` altında mı çalışıyoruz? (flutter test, test sürecinin
/// ortamına FLUTTER_TEST koyar; testte gerçek platform kanalları yoktur.)
bool get isFlutterTestEnvironment {
  try {
    return Platform.environment.containsKey('FLUTTER_TEST');
  } catch (_) {
    return false;
  }
}
