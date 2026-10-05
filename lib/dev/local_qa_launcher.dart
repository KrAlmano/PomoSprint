// Yalnızca açıkça seçilen yerel debug QA için giriş yardımcısı.
// Uygulamanın normal giriş noktasından import edilmez.
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' as app;
import '../services/language_service.dart';
import '../services/local_test_mode.dart';
import '../services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!recordLocalQuickSessions) {
    throw StateError(
      'Yerel QA başlatıcısı yerel debug kayıt modunu gerektirir.',
    );
  }
  final prefs = await SharedPreferences.getInstance();
  // İzin verilmesi gereken sistem penceresi ilk seans testini engellemesin.
  // Kullanıcı Profil'den bildirimleri açabilir.
  if (!prefs.containsKey('notifications_enabled')) {
    await prefs.setBool('notifications_enabled', false);
  }
  await app.main();
  await LanguageService.instance.setLanguage(AppLanguage.tr);
  const email = String.fromEnvironment('LOCAL_QA_EMAIL');
  const password = String.fromEnvironment('LOCAL_QA_PASSWORD');
  if (email.isNotEmpty && password.isNotEmpty) {
    final service = SupabaseService.instance;
    if (!await service.ensureCloud()) return;
    if (service.currentUser.value?.email != email) {
      if (service.currentUser.value != null) await service.signOutFully();
      await service.loginUser(email, password);
    }
  }
}
