// Geliştirici önizlemesi: kilit ekranı sayacını (Android kalıcı bildirim,
// iPhone Canlı Etkinlik) ve bitiş bildirimini giriş yapmadan denemek için.
// Uygulamanın hiçbir yerinden import EDİLMEZ, bu yüzden release paketine
// girmez. Metinler yalnızca geliştiriciye yönelik olduğundan ARB'de değil.
//
//   flutter run -t lib/dev/lock_screen_preview.dart
//
// "1 dk başlat"a bas, ekranı kilitle: kalan süre kilit ekranında akar,
// süre bitince bitiş bildirimi gelir.
//
// Dokunmadan (betikle) denemek için:
//   --dart-define=PREVIEW_AUTOSTART=true          açılışta başlatır
//   --dart-define=PREVIEW_AUTOPAUSE_AFTER=8       başlattıktan 8 sn sonra duraklatır

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../l10n/app_localizations.dart';
import '../services/language_service.dart';
import '../services/lock_screen_timer.dart';
import '../services/notification_service.dart';
import '../services/timer_persistence.dart';
import '../theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await LanguageService.instance.init();
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('[PREVIEW] Başlatma hatası: $e');
  }
  runApp(const LockScreenPreviewApp());
}

class LockScreenPreviewApp extends StatelessWidget {
  const LockScreenPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, _) => MaterialApp(
        title: 'Kilit ekranı önizleme',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        locale: LanguageService.instance.currentLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LockScreenPreviewPage(),
      ),
    );
  }
}

class LockScreenPreviewPage extends StatefulWidget {
  const LockScreenPreviewPage({super.key});

  @override
  State<LockScreenPreviewPage> createState() => _LockScreenPreviewPageState();
}

class _LockScreenPreviewPageState extends State<LockScreenPreviewPage> with WidgetsBindingObserver {
  static const int _previewSeconds = 60;
  static const bool _autoStart = bool.fromEnvironment('PREVIEW_AUTOSTART');
  static const int _autoPauseAfter = int.fromEnvironment('PREVIEW_AUTOPAUSE_AFTER');

  final LockScreenTimer _lockScreen = LockScreenTimer.instance;
  final NotificationService _notifications = NotificationService.instance;
  ActiveTimerSession? _session;
  Timer? _ticker;
  String _status = 'Hazır';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Önceki denemeden kalmış sayaç varsa kaldırılır.
    unawaited(_lockScreen.clear());
    if (_autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _start();
        if (_autoPauseAfter > 0) {
          await Future<void>.delayed(const Duration(seconds: _autoPauseAfter));
          if (mounted) await _pause();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _tick();
    final session = _session;
    if (session != null) unawaited(_lockScreen.show(session, force: true));
  }

  int get _remaining => _session?.remainingSecondsAt(DateTime.now()) ?? 0;

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final session = _session;
    if (!mounted || session == null || !session.isRunning) return;
    if (session.isFinishedAt(DateTime.now())) {
      _ticker?.cancel();
      unawaited(_lockScreen.clear());
      setState(() {
        _session = null;
        _status = 'Süre doldu: kilit ekranı sayacı kaldırıldı';
      });
      return;
    }
    setState(() {});
  }

  Future<void> _start() async {
    // İzin diyaloğu beklenmez: Canlı Etkinlik bildirim izni istemez, kilit
    // ekranı sayacı hemen görünür.
    unawaited(_notifications.ensurePermission(force: true));
    final now = DateTime.now();
    final session = ActiveTimerSession.start(
      clientUuid: const Uuid().v4(),
      categoryId: 'preview',
      categoryName: 'Matematik',
      durationMinutes: 25,
      totalSeconds: _previewSeconds,
      now: now,
    );
    setState(() {
      _session = session;
      _status = 'Çalışıyor';
    });
    _startTicker();
    await _notifications.scheduleSessionEnd(after: const Duration(seconds: _previewSeconds), categoryName: session.categoryName);
    await _lockScreen.showRunning(session);
  }

  Future<void> _pause() async {
    final session = _session;
    if (session == null || !session.isRunning) return;
    final paused = session.pauseAt(DateTime.now());
    _ticker?.cancel();
    setState(() {
      _session = paused;
      _status = 'Duraklatıldı';
    });
    await _notifications.cancelSessionEndNotification();
    await _lockScreen.showPaused(paused);
  }

  Future<void> _resume() async {
    final session = _session;
    if (session == null || session.isRunning) return;
    final now = DateTime.now();
    final resumed = session.resumeAt(now);
    setState(() {
      _session = resumed;
      _status = 'Çalışıyor';
    });
    _startTicker();
    await _notifications.scheduleSessionEnd(
      after: Duration(seconds: resumed.remainingSecondsAt(now)),
      categoryName: resumed.categoryName,
    );
    await _lockScreen.showRunning(resumed);
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    setState(() {
      _session = null;
      _status = 'Bitirildi';
    });
    await _notifications.cancelSessionEndNotification();
    await _lockScreen.clear();
  }

  Future<void> _toggleLanguage() async {
    final lang = LanguageService.instance;
    await lang.setLanguage(lang.isTurkish ? AppLanguage.en : AppLanguage.tr);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final running = session?.isRunning ?? false;
    final paused = session != null && !running;
    final remaining = _remaining;
    final clock = LockScreenTimer.formatRemaining(session == null ? _previewSeconds : remaining);

    return Scaffold(
      appBar: AppBar(title: const Text('Kilit ekranı önizleme')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              clock,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
            ),
            const SizedBox(height: 8),
            Text(_status, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(
              'Platform: ${_lockScreen.platform.runtimeType} · ${defaultTargetPlatform.name}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: session == null ? _start : null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('1 dk başlat'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primaryContainer),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: running ? _pause : null,
              icon: const Icon(Icons.pause_rounded),
              label: const Text('Duraklat'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: paused ? _resume : null,
              icon: const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Devam'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: session != null ? _finish : null,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Bitir'),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _toggleLanguage,
              child: Text('Dil: ${LanguageService.instance.currentLocale.languageCode.toUpperCase()} (değiştir)'),
            ),
            const SizedBox(height: 8),
            Text(
              'Başlattıktan sonra ekranı kilitle. Android: kalıcı bildirimde geri '
              'sayım, iPhone (iOS 16.2+): Canlı Etkinlik ve Dynamic Island. '
              'Süre bitince bitiş bildirimi gelir.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
