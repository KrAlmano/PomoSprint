// Yalnızca yerel QA: işletim sisteminin süreç öldürmesi ve gerçek yeniden
// açılışta kalıcı seansın tamamlanması. Normal main'den import edilmez.
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../main.dart' as app;
import '../services/local_test_mode.dart';
import '../services/supabase_service.dart';
import '../services/timer_persistence.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!recordLocalQuickSessions || !kQuickTimer) {
    throw StateError(
      'Süreç testi yalnızca yerel kısa debug kayıt modunda çalışır.',
    );
  }
  const email = String.fromEnvironment('LOCAL_QA_EMAIL');
  const password = String.fromEnvironment('LOCAL_QA_PASSWORD');
  const run = String.fromEnvironment('LOCAL_QA_PROCESS_RUN');
  // Native sürücü kalıcı tercihlerdeki kaydı görüp süreç öldürür. iOS'un
  // dosyaya yazma gecikmesine pay vermek için bu fikstür 30 sn seçebilir;
  // ürünün QUICK_TIMER 5/10 saniye davranışını değiştirmez.
  const seconds = int.fromEnvironment(
    'LOCAL_QA_PROCESS_SECONDS',
    defaultValue: 10,
  );
  if (seconds < 10 || seconds > 60) {
    throw StateError('Yerel süreç fikstürü 10–60 saniye olmalı.');
  }
  if (email.isEmpty || password.isEmpty || run.isEmpty) {
    throw StateError('Yerel süreç testi hesabı/koşu gerekli.');
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('notifications_enabled', false);
  final service = SupabaseService.instance;
  if (!await service.ensureCloud()) {
    throw StateError('Yerel backend hazır değil.');
  }
  if (service.currentUser.value?.email != email) {
    await service.loginUser(email, password);
  }
  final user = service.currentUser.value!;
  await prefs.setBool('league_info_shown_${user.id}', true);
  final seeded = prefs.getBool('qa_process_seed_$run') ?? false;
  if (!seeded) {
    final categories = await service.fetchUserCategories();
    final category = categories.first;
    final session = ActiveTimerSession.start(
      clientUuid: const Uuid().v4(),
      categoryId: category.id,
      categoryName: category.name,
      durationMinutes: 50,
      totalSeconds: seconds,
      now: DateTime.now(),
      recordAccelerated: true,
    );
    await service.startStudySession(
      durationMinutes: 50,
      categoryName: category.name,
    );
    await TimerPersistence.instance.save(user.id!, session);
    await prefs.setBool('qa_process_seed_$run', true);
    debugPrint('[QA_OS] SEEDED ${session.clientUuid}');
  } else {
    debugPrint('[QA_OS] RELAUNCH existing state');
  }
  await app.main();
  Timer(const Duration(seconds: 2), () => debugPrint('[QA_OS] APP_READY'));
}
