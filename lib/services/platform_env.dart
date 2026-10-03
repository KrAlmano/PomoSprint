// dart:io olmayan platformlar (web) için: test ortamı tespit edilmez.

/// `flutter test` altında mı çalışıyoruz?
bool get isFlutterTestEnvironment => false;
