import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app/session_feedback.dart';
import '../l10n/app_localizations.dart';
import '../theme.dart';
import '../utils/category_names.dart';
import '../utils/color_hex.dart';
import '../utils/responsive.dart';
import '../utils/text_util.dart';
import '../models/category_model.dart';
import '../widgets/hourglass_widget.dart';
import '../services/language_service.dart';
import '../services/lock_screen_timer.dart';
import '../services/notification_service.dart';
import '../services/session_queue.dart';
import '../services/timer_persistence.dart';
import 'rejected_sessions_screen.dart';

/// Sayaç diyalogları geniş ekranda tam genişliğe yayılmaz.
const BoxConstraints kTimerDialogConstraints = BoxConstraints(minWidth: 280, maxWidth: 440);

class TimerScreen extends StatefulWidget {
  final List<CourseCategory> categories;

  /// Süren seansın cihazda saklandığı anahtar (kullanıcı kimliği).
  final String sessionOwnerKey;

  /// Kimlik bilinmeden önce kullanılmış anahtar (e-posta); oradaki kayıt taşınır.
  final String? legacySessionOwnerKey;
  final VoidCallback onOpenSettings;

  /// Süre dolunca çağrılır; seans gönderilince sunucunun sonucuyla
  /// tamamlanır (null: sonuç bilinmiyor). Sonuç seans sonu diyaloğunda
  /// gösterilir, ardından cihazdaki seans kaydı silinir.
  final Future<SessionSubmitResult?> Function(ActiveTimerSession session) onSessionCompleted;

  /// Sayaç başlayınca/devam edince (kalan dakikayla) ve durunca çağrılır.
  final void Function(bool isRunning, String categoryName, int minutesLeft)? onTimerStateChanged;
  final String? userSegment;

  /// Kilit ekranı sayacı (varsayılan: [LockScreenTimer.instance]; testte sahtesi).
  final LockScreenTimer? lockScreenTimer;

  /// Hızlı test sayacı (varsayılan: `--dart-define=QUICK_TIMER=true`, bkz.
  /// [kQuickTimer]). Açıkken yeni seanslar 5/10 sn sürer, ekranda TEST
  /// rozeti görünür ve biten test seansı [onSessionCompleted]'e verilmez.
  final bool quickTimer;

  const TimerScreen({
    super.key,
    required this.categories,
    required this.sessionOwnerKey,
    this.legacySessionOwnerKey,
    required this.onOpenSettings,
    required this.onSessionCompleted,
    this.onTimerStateChanged,
    this.userSegment,
    this.lockScreenTimer,
    this.quickTimer = kQuickTimer,
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  static const int _maxPauses = 1;

  /// 25/50 seçim satırının en büyük genişliği (tablette de kompakt kalır).
  static const double _durationRowMaxWidth = 320;

  int loggedMinutes = 25;
  late int totalSeconds = timerDurationSeconds(loggedMinutes, quick: widget.quickTimer);
  late int remaining = totalSeconds;
  bool isRunning = false;
  bool _isStarting = false; // BAŞLAT butonuna çift tıklama koruması
  Timer? _timer;
  String selectedCategoryId = '';
  String selectedCategoryName = '';

  // Süren ya da duraklatılmış seans (null: seans yok). Başlat, duraklat ve
  // devamda cihaza yazılır; uygulama öldürülse bile açılışta geri yüklenir.
  // Kalan süre her tick'te bitiş anından hesaplanır.
  ActiveTimerSession? _session;
  int _foregroundSeconds = 0;

  bool get _hasSession => _session != null;

  /// Gösterilen (ya da bir sonraki) seans kısaltılmış test seansı mı?
  bool get _isQuickTest => totalSeconds < loggedMinutes * 60;
  int get _pauseCreditsLeft => _maxPauses - (_session?.pauseUsedCount ?? 0);
  TimerPersistence get _store => TimerPersistence.instance;
  LockScreenTimer get _lockScreen => widget.lockScreenTimer ?? LockScreenTimer.instance;

  static bool get _isInForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  static int _minutesLeft(int seconds) => (seconds / 60).ceil();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _validateSelectedCategory();
    unawaited(_restoreSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    // Seans cihazda saklı olduğu için ekran kapanınca (ör. çıkış) iptal
    // edilmez; aynı hesapla açılınca kaldığı yerden sürer. Kilit ekranından
    // ise kalkar (kabuk yalnızca çıkışta ya da hesap değişince kapanır).
    _persistSession();
    unawaited(_lockScreen.clear());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Arka planda periyodik timer durmuş olabilir; kalan süreyi bitiş
      // anından yeniden hesapla (süre dolduysa seans tamamlanır).
      if (isRunning) _tick(countForeground: false);
      // Kullanıcı kilit ekranı bildirimini kapatmış ya da sistem Canlı
      // Etkinliği bitirmiş olabilir: süren seans yeniden gösterilir.
      if (_hasSession) _syncLockScreen(force: true);
    } else if (state == AppLifecycleState.paused) {
      _persistSession();
    }
  }

  @override
  void didUpdateWidget(TimerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionOwnerKey != widget.sessionOwnerKey && _hasSession) {
      unawaited(_store.clear(oldWidget.sessionOwnerKey));
      _persistSession();
      _syncLockScreen();
    }
    _validateSelectedCategory();
  }

  /// Kilit ekranı sayacını (Android kalıcı bildirim, iPhone Canlı Etkinlik)
  /// mevcut seansla eşitler; seans yoksa kaldırır.
  void _syncLockScreen({bool force = false}) {
    final session = _session;
    unawaited(session == null ? _lockScreen.clear() : _lockScreen.show(session, force: force));
  }

  void _persistSession() {
    final session = _session;
    if (session == null) return;
    unawaited(_store.save(widget.sessionOwnerKey, session.withForegroundSeconds(_foregroundSeconds)));
  }

  Future<void> _restoreSession() async {
    final saved = await _store.load(widget.sessionOwnerKey, legacyOwnerKey: widget.legacySessionOwnerKey);
    if (!mounted || _hasSession || _isStarting) return;
    if (saved == null) {
      // Bu hesabın süren seansı yok: önceki süreçten kalmış kilit ekranı
      // sayacı varsa kaldırılır.
      unawaited(_lockScreen.clear());
      return;
    }

    final now = DateTime.now();
    _foregroundSeconds = saved.foregroundSeconds;
    setState(() {
      loggedMinutes = saved.durationMinutes;
      totalSeconds = saved.totalSeconds;
      selectedCategoryId = saved.categoryId;
      selectedCategoryName = saved.categoryName;
    });

    if (saved.isRunning) {
      if (saved.isFinishedAt(now)) {
        // Uygulama kapalıyken süre doldu: seans hemen tamamlanıp gönderilir.
        unawaited(_completeSession(saved));
      } else {
        _runSession(saved, now);
      }
    } else if (saved.isAbandonedAt(now)) {
      // Sunucu 24 saatten eski seansı kabul etmez; kayıt silinir.
      unawaited(_store.clear(widget.sessionOwnerKey, onlyClientUuid: saved.clientUuid));
      unawaited(_lockScreen.clear());
      _foregroundSeconds = 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pausedSessionExpired),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _session = saved;
        remaining = saved.remainingSecondsAt(now);
      });
      unawaited(_lockScreen.showPaused(saved));
    }
  }

  void _tick({bool countForeground = true}) {
    final session = _session;
    if (!isRunning || session == null || !mounted) return;
    final left = session.remainingSecondsAt(DateTime.now());
    if (left > 0) {
      // Android'de süreç arka planda da tick atabilir; yalnızca ön plan sayılır.
      if (countForeground && _isInForeground) _foregroundSeconds++;
      setState(() => remaining = left);
    } else {
      unawaited(_completeSession(session));
    }
  }

  /// Süre dolduğunda seansı kapatır, sonucu üst bileşene bildirir ve
  /// gönderim bitince cihazdaki kaydı siler.
  Future<void> _completeSession(ActiveTimerSession session) async {
    _timer?.cancel();
    final completed = session.withForegroundSeconds(_foregroundSeconds);
    unawaited(_lockScreen.clear());
    if (_isInForeground) {
      // Gösterilmiş bildirime dokunulmaz; yalnızca bekleyen iptal edilir.
      // Bitiş, ekrana bakmayan kullanıcıya kısa titreşimle (bildirimler
      // açıksa bildirim sesiyle de) duyurulur.
      unawaited(NotificationService.instance.cancelSessionEndNotification());
      unawaited(NotificationService.instance.alertSessionEndInForeground());
    } else {
      // Android'de süreç arka planda yaşıyorsa seans burada biter; alarmın
      // gecikmesini beklemeden bildirim hemen gösterilir.
      unawaited(NotificationService.instance.showSessionEndNow(categoryName: completed.categoryName));
    }

    _resetToIdle();
    widget.onTimerStateChanged?.call(false, completed.categoryName, 0);

    final owner = widget.sessionOwnerKey;
    if (completed.isQuickTest) {
      // Hızlı test seansı sunucuya ve kuyruğa gönderilmez (sunucu kısa
      // seansı zaten reddeder); diyalog "kaydedilmez" der.
      _showSessionCompletedDialog(completed.durationMinutes, null, testSession: true);
      await _store.clear(owner, onlyClientUuid: completed.clientUuid);
      return;
    }
    // Diyalog gönderimin sonucunu bekler: kaydediliyor → puan/kum/seri,
    // kuyruk ya da ret nedeni.
    final submission = widget.onSessionCompleted(completed);
    _showSessionCompletedDialog(completed.durationMinutes, submission);
    try {
      await submission;
      await _store.clear(owner, onlyClientUuid: completed.clientUuid);
    } catch (e) {
      // Kayıt silinmez: sonraki açılışta süresi dolmuş seans olarak yeniden gönderilir.
      debugPrint('[TIMER] Seans gönderimi tamamlanamadı: $e');
    }
  }

  void _resetToIdle() {
    _foregroundSeconds = 0;
    setState(() {
      isRunning = false;
      _isStarting = false;
      _session = null;
      // Geri yüklenen seansın uzunluğu (ör. eski test seansı) sonraki
      // seansa taşınmaz.
      totalSeconds = timerDurationSeconds(loggedMinutes, quick: widget.quickTimer);
      remaining = totalSeconds;
      _validateSelectedCategory();
    });
  }

  /// Aktif kategorilerde önce kimlikle, yoksa dilden bağımsız adla arar
  /// ('Fizik' = 'Physics'): yer tutucudan sunucu kategorisine geçişte
  /// İngilizce kullanıcının seçimi ilk kategoriye atlamaz.
  CourseCategory? _resolveCategory(String id, String name) {
    final active = widget.categories.where((c) => !c.isArchived);
    final byId = active.where((c) => c.id == id).firstOrNull;
    if (byId != null || name.trim().isEmpty) return byId;
    final key = categoryMatchKey(name);
    return active.where((c) => categoryMatchKey(c.name) == key).firstOrNull;
  }

  /// Sayaçta gösterilen kategori. Seans varken seansın kategorisi: aktif
  /// listede yoksa (seans sürerken ya da uygulama kapalıyken arşivlendi)
  /// seans kaydındaki ad ve renkle gösterilir.
  CourseCategory? _displayCategory() {
    final session = _session;
    if (session == null) return _resolveCategory(selectedCategoryId, selectedCategoryName);
    return _resolveCategory(session.categoryId, session.categoryName) ??
        CourseCategory(
          id: session.categoryId,
          name: session.categoryName,
          color: colorFromHex(session.categoryColorHex, fallback: AppColors.primaryContainer),
          icon: Icons.book_outlined,
        );
  }

  // Seans sürerken ya da duraklatılmışken seçim KİLİTLİDİR: kategori listesi
  // yenilense bile seans başladığı kategoriyle kaydedilir. Seans yokken
  // seçili kategori listede yoksa (ör. yer tutucudan sunucu kategorisine
  // geçiş) önce aynı isimli kategoriye, yoksa ilk aktif kategoriye geçilir.
  void _validateSelectedCategory() {
    if (_hasSession) return;
    final active = widget.categories.where((c) => !c.isArchived);
    if (active.isEmpty) return;
    final match = _resolveCategory(selectedCategoryId, selectedCategoryName) ?? active.first;
    selectedCategoryId = match.id;
    selectedCategoryName = match.name;
  }

  void _toggleTimer() {
    if (isRunning) {
      if (_pauseCreditsLeft > 0) {
        _pause();
      } else {
        _showPauseLimitDialog();
      }
    } else {
      if (_isStarting) return; // çift tıklama koruması
      _isStarting = true;
      unawaited(_show321CountdownAndStart());
    }
  }

  void _pause() {
    final session = _session;
    if (session == null) return;
    _timer?.cancel();
    unawaited(NotificationService.instance.cancelSessionEndNotification());
    final now = DateTime.now();
    final paused = session.pauseAt(now);
    setState(() {
      _session = paused;
      isRunning = false;
      remaining = paused.remainingSecondsAt(now);
    });
    _persistSession();
    unawaited(_lockScreen.showPaused(paused));
    widget.onTimerStateChanged?.call(false, paused.categoryName, _minutesLeft(remaining));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(LanguageService.instance.translate('pause_used_snackbar')),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryContainer,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Seansı kaydetmeden bırakır (Sıfırla & Durdur / Sıfırla). [expectedUuid]
  /// verilirse yalnızca o seans hâlâ sürüyorsa bırakılır: onay diyaloğu
  /// açıkken süre dolup seans tamamlandıysa tamamlanan kayıt silinmez.
  void _discardSession({String? expectedUuid}) {
    if (expectedUuid != null && _session?.clientUuid != expectedUuid) return;
    _timer?.cancel();
    unawaited(NotificationService.instance.cancelSessionEndNotification());
    unawaited(_lockScreen.clear());
    final categoryName = _session?.categoryName ?? selectedCategoryName;
    _resetToIdle();
    unawaited(_store.clear(widget.sessionOwnerKey));
    widget.onTimerStateChanged?.call(false, categoryName, 0);
  }

  // Süre yalnızca seans yokken seçilir. Seans sürerken ya da
  // duraklatılmışken süre çipleri (kategori çipleri gibi) kilitlidir;
  // seansı bırakmanın tek yolu onaylı "Sıfırla"dır. Eskiden duraklatılmış
  // seans, süre çipine (seçili olana bile) tek dokunuşla onaysız siliniyordu.
  void _selectDuration(int minutes) {
    if (_hasSession) {
      if (minutes != loggedMinutes) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.timerDurationLocked),
            behavior: SnackBarBehavior.floating,
          ));
      }
      return;
    }
    if (minutes == loggedMinutes) return;
    setState(() {
      loggedMinutes = minutes;
      totalSeconds = timerDurationSeconds(minutes, quick: widget.quickTimer);
      remaining = totalSeconds;
      _validateSelectedCategory();
    });
  }

  /// Süren ya da duraklatılmış seansı onayla bırakır.
  Future<void> _confirmDiscardSession() async {
    final target = _session?.clientUuid;
    if (target == null) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        constraints: kTimerDialogConstraints,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.timerResetConfirmTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(l10n.timerResetConfirmBody, style: const TextStyle(fontSize: 14, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.timerResetConfirmAction,
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _session?.clientUuid != target) return;
    _discardSession(expectedUuid: target);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LanguageService.instance.translate('session_reset')),
        backgroundColor: AppColors.outline,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // İzin yokken uyarı her BAŞLAT'ta değil, uygulama açılışı başına bir kez.
  static bool _notificationNoticeShown = false;

  /// Bildirim tercihi açık ama sistem izni yoksa seans sessiz geçmesin:
  /// kısa bir uyarı ve sistem ayarlarını açan eylem gösterilir.
  Future<void> _maybeShowNotificationNotice() async {
    if (_notificationNoticeShown) return;
    final notifications = NotificationService.instance;
    final preference = await notifications.isEnabled();
    final permission = await notifications.hasSystemPermission();
    if (!mounted || !NotificationService.isBlockedBySystem(preference: preference, permission: permission)) return;
    _notificationNoticeShown = true;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l10n.timerNotificationsDenied),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: l10n.profileOpenSettings,
        onPressed: () => unawaited(notifications.openSystemSettings()),
      ),
    ));
  }

  Future<void> _show321CountdownAndStart() async {
    // Bildirim izni ilk BAŞLAT'ta, bağlamıyla birlikte istenir (bir kez sorulur).
    final notificationsAllowed = await NotificationService.instance.ensurePermission();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) {
        return TimerCountdownDialog(
          onComplete: () {
            if (ctx.mounted && Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }
            _startOrResume();
          },
        );
      },
    );
    // Geri tuşuyla kapatılan geri sayım BAŞLAT'ı kilitli bırakmaz.
    if (mounted && !isRunning) setState(() => _isStarting = false);
    if (mounted && isRunning && !notificationsAllowed) unawaited(_maybeShowNotificationNotice());
  }

  void _startOrResume() {
    if (!mounted) return;
    final now = DateTime.now();
    final current = _session;
    if (current != null) {
      _runSession(current.resumeAt(now), now);
      return;
    }
    final category = _resolveCategory(selectedCategoryId, selectedCategoryName);
    _runSession(
      ActiveTimerSession.start(
        clientUuid: const Uuid().v4(),
        categoryId: category?.id ?? selectedCategoryId,
        categoryName: category?.name ?? selectedCategoryName,
        categoryColorHex: category?.colorHex,
        durationMinutes: loggedMinutes,
        totalSeconds: totalSeconds,
        now: now,
      ),
      now,
    );
  }

  void _runSession(ActiveTimerSession session, DateTime now) {
    _timer?.cancel();
    final left = session.remainingSecondsAt(now);
    setState(() {
      _session = session;
      isRunning = true;
      _isStarting = false;
      remaining = left;
    });
    _persistSession();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    unawaited(NotificationService.instance.scheduleSessionEnd(after: Duration(seconds: left), categoryName: session.categoryName));
    unawaited(_lockScreen.showRunning(session));
    widget.onTimerStateChanged?.call(true, session.categoryName, _minutesLeft(left));
  }

  void _showPauseLimitDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final target = _session?.clientUuid;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        constraints: kTimerDialogConstraints,
        backgroundColor: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                LanguageService.instance.translate('pause_limit_title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          LanguageService.instance.translate('pause_limit_content'),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (target == null || _session?.clientUuid != target) return;
              _discardSession(expectedUuid: target);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(LanguageService.instance.translate('session_reset')),
                  backgroundColor: AppColors.outline,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(
              LanguageService.instance.translate('reset_and_stop'),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              LanguageService.instance.translate('continue_btn'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSessionCompletedDialog(int displayMinutes, Future<SessionSubmitResult?>? result, {bool testSession = false}) {
    showDialog(
      context: context,
      builder: (ctx) => SessionCompletedDialog(minutes: displayMinutes, result: result, testSession: testSession),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
        final seconds = (remaining % 60).toString().padLeft(2, '0');
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final activeCategories = widget.categories.where((c) => !c.isArchived).toList();
        final displayCategory = _displayCategory();
        final hasPauseCredit = _pauseCreditsLeft > 0;
        // Hareketi Azalt açıkken yerleşim değişimleri canlandırılmaz.
        final layoutAnimation = (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
            ? Duration.zero
            : const Duration(milliseconds: 600);

        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = _TimerLayout.of(constraints, lineHeight: _lineHeightMeasurer(context));
                final dense = layout.dense;
                final large = layout.large;
                // Dikey boşluklar: alçak ekran / dikey telefon / diğerleri.
                // Dikey telefondaki değerler _TimerLayout.phoneControlsHeight
                // tahminiyle aynı tutulmalı.
                double gap(double whenDense, double whenCompact, double otherwise) =>
                    dense ? whenDense : (layout.compact ? whenCompact : otherwise);

                final hourglassWidget = HourglassWidget(
                  size: layout.hourglassSize,
                  isRunning: isRunning,
                  totalSeconds: totalSeconds,
                  remainingSeconds: remaining,
                  sandColor: displayCategory?.color ?? activeCategories.firstOrNull?.color,
                );

                Widget categoryChip(CourseCategory cat) {
                  final isSelected = cat.id == displayCategory?.id;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(LanguageService.instance.translateCatName(cat.name)),
                      selected: isSelected,
                      // Seans sürerken/duraklatılmışken kategori kilitli.
                      onSelected: _hasSession
                          ? null
                          : (val) {
                              if (val) {
                                setState(() {
                                  selectedCategoryId = cat.id;
                                  selectedCategoryName = cat.name;
                                });
                              }
                            },
                      avatar: CircleAvatar(backgroundColor: cat.color, radius: 5),
                      showCheckmark: false,
                      selectedColor: cat.color.withValues(alpha: 0.2),
                      backgroundColor: isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? cat.color
                            : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isSelected ? cat.color : Colors.transparent),
                      ),
                    ),
                  );
                }

                // Seansın kategorisi arşivlendiyse kilitli, seçili çip olarak başta kalır.
                final categoryChips = [
                  if (displayCategory != null && !activeCategories.any((c) => c.id == displayCategory.id))
                    categoryChip(displayCategory),
                  for (final cat in activeCategories) categoryChip(cat),
                ];

                // Ders/kategori başlığı ve düzenleme kısayolu. [inline]: yatay
                // kaydırılan çip satırının başında (genişlik sınırsız).
                Widget categoryHeader({required bool inline}) {
                  final label = Text(
                    TextUtil.getCategorySelectionLabel(l10n, widget.userSegment),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                    ),
                  );
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: inline ? MainAxisSize.min : MainAxisSize.max,
                    children: [
                      if (inline) label else Flexible(child: label),
                      const SizedBox(width: 2),
                      // Kategori düzenleme kısayolu: etiketli, 48 dp dokunma alanı.
                      IconButton(
                        onPressed: widget.onOpenSettings,
                        tooltip: l10n.timerEditCategories,
                        iconSize: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: kMinInteractiveDimension,
                          minHeight: kMinInteractiveDimension,
                        ),
                        icon: const Icon(Icons.edit_outlined, color: AppColors.primaryContainer),
                      ),
                    ],
                  );
                }

                Widget durationOption(int mins) {
                  final isSel = loggedMinutes == mins;
                  final foreground = isSel
                      ? Colors.white
                      : (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant)
                          .withValues(alpha: _hasSession ? 0.45 : 1);
                  return Semantics(
                    button: true,
                    selected: isSel,
                    label: l10n.timerDurationOption(mins),
                    onTap: () => _selectDuration(mins),
                    excludeSemantics: true,
                    child: GestureDetector(
                      // Seans varken kilitli (bkz. _selectDuration).
                      onTap: () => _selectDuration(mins),
                      behavior: HitTestBehavior.opaque,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 6 : 10),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? AppColors.primaryContainer
                                  : (isDark ? AppColors.darkSurfaceContainerLow : AppColors.surfaceContainerLow),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSel
                                    ? AppColors.primaryContainer
                                    : (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant),
                              ),
                            ),
                            // Büyük yazı ölçeğinde satır kırmadan küçülür.
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSel) ...[
                                      Icon(Icons.check_rounded, size: 18, color: foreground),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      '$mins ${LanguageService.instance.translate('minutes_unit_short')}',
                                      maxLines: 1,
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: foreground),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final controlsWidget = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Subject Chips Section. Dikey alanı kıt ekranda ve dikey
                    // telefonda başlık ayrı satır yerine çiplerin başında durur.
                    // Kalem düğmesinin dokunma alanı başlıkla çipler arasındaki
                    // boşluğu karşılar.
                    if (!layout.inlineHeader) categoryHeader(inline: false),

                    // Active Category Pills: telefonda yatay kaydırılır,
                    // tablette ortalanmış satırlara sarılır.
                    if (large)
                      Wrap(alignment: WrapAlignment.center, runSpacing: 4, children: categoryChips)
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (layout.inlineHeader)
                              Padding(padding: const EdgeInsets.only(left: 4, right: 6), child: categoryHeader(inline: true)),
                            ...categoryChips,
                          ],
                        ),
                      ),
                    SizedBox(height: gap(8, 12, 16)),

                    // Time Display (yalnızca sütuna sığmazsa satır kırmadan
                    // küçülür). Ekran okuyucu "X dakika Y saniye kaldı" okur.
                    Semantics(
                      label: l10n.timerRemainingSemantics(remaining ~/ 60, remaining % 60),
                      excludeSemantics: true,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$minutes:$seconds',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: large ? 60 : (dense ? 42 : 52),
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1.5,
                            color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
                          ),
                        ),
                      ),
                    ),
                    // Süre çiplerinin 48 dp dokunma alanı bu boşluğun bir kısmını alır.
                    SizedBox(height: gap(0, 2, 6)),

                    // Süre Seçimi: 25 dk / 50 dk tek satırda, eşit genişlikte
                    // iki seçenek. Her biri en az 48 dp yüksek dokunma alanı
                    // ve ekran okuyucuda seçili durumuyla düğme olarak
                    // duyurulur; seçili olan dolgu rengi ve onay işaretiyle
                    // (yalnızca renge dayanmadan) ayrılır. Eskiden Wrap
                    // içindeki hizalı Container satırın tüm genişliğini
                    // alıyordu: 50 dk her ekranda alt satıra düşüyordu.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _durationRowMaxWidth),
                      child: Row(
                        children: [
                          for (final mins in const [25, 50]) ...[
                            if (mins != 25) const SizedBox(width: 12),
                            Expanded(child: durationOption(mins)),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: gap(4, 10, 16)),

                    // Duraklatma Hakkı (Pause Limit)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: hasPauseCredit
                            ? (isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh)
                            : AppColors.primaryContainer.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: hasPauseCredit
                              ? (isDark ? AppColors.darkOutlineVariant : AppColors.outlineVariant)
                              : AppColors.primary,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasPauseCredit ? Icons.pause_circle_outline : Icons.block_outlined,
                            size: 13,
                            color: hasPauseCredit
                                ? (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant)
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              hasPauseCredit ? l10n.pauseCreditAvailable : l10n.pauseCreditUsed,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: hasPauseCredit
                                    ? (isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant)
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: gap(8, 12, 14)),

                    // Primary Start/Pause Button
                    ElevatedButton(
                      onPressed: _toggleTimer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRunning
                            ? (isDark ? AppColors.darkSurfaceContainerHighest : AppColors.surfaceContainerHighest)
                            : AppColors.primaryContainer,
                        foregroundColor: isRunning
                            ? (isDark ? AppColors.darkOnSurface : AppColors.onSurface)
                            : Colors.white,
                        minimumSize: large ? const Size(240, 52) : Size(200, dense ? 44 : 48),
                        elevation: isRunning ? 0 : 4,
                        shadowColor: const Color(0x40FF5C4D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: Text(
                        isRunning
                            ? LanguageService.instance.translate('btn_pause')
                            : LanguageService.instance.translate('btn_start'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: large ? 18 : 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Süren ya da duraklatılmış seansı onayla bırakma.
                    if (_hasSession) ...[
                      SizedBox(height: gap(2, 2, 6)),
                      TextButton.icon(
                        onPressed: _confirmDiscardSession,
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: Text(l10n.timerResetBtn),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: gap(4, 4, 12)),
                    ] else
                      SizedBox(height: gap(8, 12, 24)),
                  ],
                );

                // Konumlar canlandırılır: telefon döndürülünce kum saati ve
                // kontroller yeni yerlerine kayar.
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedPositioned(
                      duration: layoutAnimation,
                      curve: Curves.easeInOutCubic,
                      top: layout.hourglassTop,
                      left: layout.hourglassLeft,
                      width: layout.hourglassSize,
                      height: layout.hourglassHeight,
                      child: hourglassWidget,
                    ),
                    AnimatedPositioned(
                      duration: layoutAnimation,
                      curve: Curves.easeInOutCubic,
                      top: layout.controlsTop,
                      bottom: 0.0,
                      left: layout.controlsLeft,
                      width: layout.controlsWidth,
                      child: Align(
                        alignment: layout.controlsAlignment,
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: controlsWidget),
                        ),
                      ),
                    ),
                    // Hızlı test sayacı: bu seanslar kaydedilmez.
                    if (_isQuickTest)
                      PositionedDirectional(
                        top: 8,
                        end: 8,
                        child: IgnorePointer(child: _QuickTestBadge(label: l10n.timerQuickTestBadge, semanticsLabel: l10n.timerQuickTestSemantics)),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Verilen yazı boyutu ve kalınlığında bir satırın ekrandaki yüksekliği.
typedef _LineHeight = double Function(double fontSize, FontWeight fontWeight);

/// Ekranın varsayılan yazı stili ve yazı ölçeğiyle satır yüksekliği ölçer
/// (cihazın gerçek yazı tipi; Text widget'ı da aynı stili birleştirir).
_LineHeight _lineHeightMeasurer(BuildContext context) {
  final base = DefaultTextStyle.of(context).style;
  final textScaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  return (fontSize, fontWeight) {
    final painter = TextPainter(
      text: TextSpan(text: '0', style: base.merge(TextStyle(fontSize: fontSize, fontWeight: fontWeight))),
      textDirection: direction,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  };
}

/// Sayaç ekranının yerleşimi; ekranın değil sayaca kalan alanın (yan
/// gezinme ve güvenli alan düşülmüş) ölçüsünden hesaplanır.
///
/// * Dikey telefon: kum saati üstte, kontroller hemen altında. Kum saati
///   kontrollerin (seans sürerken görünen Sıfırla dahil) tahmini
///   yüksekliğinden kalan alana sığacak kadar büyür, en çok
///   [_phoneHourglass]; BAŞLAT/DURAKLAT kaydırmadan görünür. Alan çok
///   kısaysa kum saati eski boyutunun altına inmez, kontroller kayar.
///   Fazla alan varsa grup dikeyde ortalanır.
/// * Yatay (genişlik > yükseklik): kum saati solda, kontroller sağda; sağ
///   sütun sığmazsa kendi içinde kayar. Geniş ekranda iki sütun ortalanmış
///   bir grup olarak kalır.
/// * Tablet dikey: kum saati ve kontroller ortada, ekrana göre ölçekli ama
///   [_maxHourglass]'ı aşmadan.
@immutable
class _TimerLayout {
  const _TimerLayout({
    required this.dense,
    required this.large,
    required this.compact,
    required this.inlineHeader,
    required this.hourglassSize,
    required this.hourglassHeight,
    required this.hourglassTop,
    required this.hourglassLeft,
    required this.controlsTop,
    required this.controlsLeft,
    required this.controlsWidth,
    required this.controlsAlignment,
  });

  /// Kum saati önceki sürüme göre bu oranda büyütüldü (yer olan yerlerde).
  static const double _growth = 1.25;

  /// Önceki dikey telefon boyutu; kısa ekranda kum saati bunun altına inmez.
  static const double _legacyPhoneHourglass = 220;
  static const double _phoneHourglass = _legacyPhoneHourglass * _growth;
  static const double _maxHourglass = 300 * _growth;
  static const double _minHourglass = 64;
  static const double _shortPortraitHeight = 540;
  static const double _denseHeight = 420;
  static const double _maxTwoColumnWidth = 960;
  static const double _maxCenteredControlsWidth = 560;

  /// Dikey telefonda kum saatinin üstündeki en az boşluk ve kum saati ile
  /// kontroller arası.
  static const double _phoneTop = 8;
  static const double _phoneGap = 8;

  /// Tablet dikeyde kum saati ve kontrolleri dikeyde ortalamak için
  /// kontrollerin yaklaşık yüksekliği (yanılırsa yalnızca ortalama kayar).
  static const double _estimatedControlsHeight = 420;

  /// Dikey telefonda kontrol sütununun (seans varken: Sıfırla dahil)
  /// yaklaşık yüksekliği. Yazı satırları ekrandaki yazı tipi ve ölçeğiyle
  /// ölçülür ([lineHeight]); aralıklar sayaç ekranındaki `gap(...)`
  /// değerleriyle aynıdır: dense / compact.
  static double phoneControlsHeight({required bool dense, required _LineHeight lineHeight}) {
    const tap = kMinInteractiveDimension;
    final chips = math.max(tap, lineHeight(13, FontWeight.bold) + 24); // başlık satır içinde
    final time = lineHeight(dense ? 42 : 52, FontWeight.bold);
    final duration = math.max(tap, lineHeight(16, FontWeight.bold) + (dense ? 14 : 22));
    final pause = math.max(13.0, lineHeight(11, FontWeight.w600)) + 12;
    final button = math.max(dense ? 44.0 : 48.0, lineHeight(17, FontWeight.bold) + 16);
    final reset = math.max(tap, lineHeight(14, FontWeight.w500) + 16);
    final gaps = dense ? (8 + 0 + 4 + 8 + 2 + 4) : (12 + 2 + 10 + 12 + 2 + 4);
    return chips + time + duration + pause + button + reset + gaps;
  }

  factory _TimerLayout.of(BoxConstraints constraints, {required _LineHeight lineHeight}) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;
    final large = math.min(w, h) >= Responsive.mediumMinWidth;

    if (w > h) {
      final groupWidth = math.min(w, _maxTwoColumnWidth);
      final groupLeft = (w - groupWidth) / 2;
      // Kontroller (çipler, süre seçimi) biraz daha geniş sütun alır.
      final columnWidth = groupWidth * 0.45;
      // Yükseklik çoğunlukla sınırlar; sütun kenarlarına dayanmaz.
      final size = math.max(_minHourglass, math.min(_maxHourglass, math.min(columnWidth * 0.9, (h - 24) / 1.05)));
      final dense = h < _denseHeight;
      return _TimerLayout(
        dense: dense,
        large: large,
        compact: false,
        inlineHeader: dense,
        hourglassSize: size,
        hourglassHeight: size * 1.05,
        hourglassTop: (h - size * 1.05) / 2,
        hourglassLeft: groupLeft + (columnWidth - size) / 2,
        controlsTop: 0,
        controlsLeft: groupLeft + columnWidth,
        controlsWidth: groupWidth - columnWidth,
        controlsAlignment: Alignment.center,
      );
    }

    if (w < Responsive.mediumMinWidth) {
      final dense = h < _shortPortraitHeight;
      final controls = phoneControlsHeight(dense: dense, lineHeight: lineHeight);
      final ceiling = math.min(_phoneHourglass, w - 32);
      final floor = math.min(
        ceiling,
        dense ? (h * 0.34).clamp(120.0, _legacyPhoneHourglass) : _legacyPhoneHourglass,
      );
      final size = ((h - _phoneTop - _phoneGap - controls) / 1.05).clamp(floor, ceiling);
      final hourglassHeight = size * 1.05;
      final spare = h - (_phoneTop + hourglassHeight + _phoneGap + controls);
      final top = _phoneTop + math.max(0.0, spare / 2);
      return _TimerLayout(
        dense: dense,
        large: false,
        compact: true,
        inlineHeader: true,
        hourglassSize: size,
        hourglassHeight: hourglassHeight,
        hourglassTop: top,
        hourglassLeft: (w - size) / 2,
        controlsTop: top + hourglassHeight + _phoneGap,
        controlsLeft: 0,
        controlsWidth: w,
        controlsAlignment: Alignment.topCenter,
      );
    }

    final size = (math.min(w, h) * 0.36 * _growth).clamp(_phoneHourglass, _maxHourglass);
    final hourglassHeight = size * 1.05;
    const gap = 20.0;
    final top = math.max(32.0, (h - hourglassHeight - gap - _estimatedControlsHeight) / 2);
    final controlsWidth = math.min(w, _maxCenteredControlsWidth);
    return _TimerLayout(
      dense: false,
      large: large,
      compact: false,
      inlineHeader: false,
      hourglassSize: size,
      hourglassHeight: hourglassHeight,
      hourglassTop: top,
      hourglassLeft: (w - size) / 2,
      controlsTop: top + hourglassHeight + gap,
      controlsLeft: (w - controlsWidth) / 2,
      controlsWidth: controlsWidth,
      controlsAlignment: Alignment.topCenter,
    );
  }

  /// Dikey alan kıt: kontrollerin aralıkları sıkışır.
  final bool dense;

  /// Tablet: süre ve düğme biraz büyür, kategori çipleri satırlara sarılır.
  final bool large;

  /// Dikey telefon: aralıklar dense ile tablet arasında (BAŞLAT kaydırmadan
  /// görünsün, kum saati büyük kalsın).
  final bool compact;

  /// Kategori başlığı ayrı satır yerine çip satırının başında.
  final bool inlineHeader;

  final double hourglassSize;
  final double hourglassHeight;
  final double hourglassTop;
  final double hourglassLeft;
  final double controlsTop;
  final double controlsLeft;
  final double controlsWidth;
  final Alignment controlsAlignment;
}

/// Hızlı test sayacında sayaç ekranının köşesindeki "TEST" rozeti.
class _QuickTestBadge extends StatelessWidget {
  const _QuickTestBadge({required this.label, required this.semanticsLabel});

  final String label;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.science_outlined, size: 14, color: Colors.black87),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seans tamamlanınca gösterilen diyalog. [result] verilirse sunucunun
/// sonucunu bekler: önce "kaydediliyor", sonra kazanılan puan, kum ve seri
/// (yalnızca RPC sonucundan; istemcide formül yok), kuyruk ya da ret
/// nedeni. Sonuç [resultTimeout] içinde gelmezse "cihazda kayıtlı, bağlantı
/// gelince gönderilecek" gösterilir; sonuç sonradan gelirse güncellenir.
class SessionCompletedDialog extends StatefulWidget {
  final int minutes;

  /// Gönderimin sonucu (null değer: sonuç bilinmiyor, seans cihazda).
  final Future<SessionSubmitResult?>? result;
  final Duration resultTimeout;

  /// Hızlı test sayacının seansı: gönderilmedi, "kaydedilmez" denir.
  final bool testSession;

  const SessionCompletedDialog({
    super.key,
    required this.minutes,
    this.result,
    this.resultTimeout = const Duration(seconds: 8),
    this.testSession = false,
  });

  @override
  State<SessionCompletedDialog> createState() => _SessionCompletedDialogState();
}

class _SessionCompletedDialogState extends State<SessionCompletedDialog> {
  bool _waiting = false;
  bool _timedOut = false;
  SessionSubmitResult? _result;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    final future = widget.result;
    if (future == null) return;
    _waiting = true;
    _timeoutTimer = Timer(widget.resultTimeout, () {
      if (mounted && _waiting) setState(() => _timedOut = true);
    });
    future.then<void>(
      _finish,
      // Gönderim hata verdiyse seans cihazda kalır ve sonra yeniden
      // gönderilir (bkz. TimerScreen._completeSession).
      onError: (Object _) => _finish(null),
    );
  }

  void _finish(SessionSubmitResult? result) {
    _timeoutTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _waiting = false;
      _result = result;
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _openRejectedSessions() {
    final navigator = Navigator.of(context);
    navigator.pop();
    unawaited(navigator.push(rejectedSessionsRoute()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? AppColors.darkOnSurfaceVariant : AppColors.onSurfaceVariant;
    final accent = isDark ? AppColors.darkPrimary : AppColors.primary;
    final rejected = _result is SessionSubmitRejected;

    Widget message(String text, IconData icon, Color color) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 13, height: 1.4, color: muted))),
          ],
        );

    Widget chip(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 4),
              Flexible(
                child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accent)),
              ),
            ],
          ),
        );

    final queuedOffline = message(l10n.sessionQueuedOffline, Icons.cloud_upload_outlined, muted);
    final List<Widget> status = switch (_result) {
      _ when widget.testSession => [
          message(l10n.sessionResultTestNotSaved, Icons.science_outlined, accent),
        ],
      _ when widget.result == null => const [],
      _ when _waiting && !_timedOut => [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: accent)),
              const SizedBox(width: 10),
              Flexible(child: Text(l10n.sessionResultSaving, style: TextStyle(fontSize: 13, color: muted))),
            ],
          ),
        ],
      null => [queuedOffline],
      SessionSubmitSuccess(duplicate: true) => [
          message(l10n.sessionResultDuplicate, Icons.check_circle_outline_rounded, accent),
        ],
      SessionSubmitSuccess(
        :final basePoints,
        :final bonusPoints,
        :final bonusPct,
        :final totalPoints,
        :final coinsEarned,
        :final streak,
        :final dailyLimitReached,
      ) =>
        [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (totalPoints > 0) chip(Icons.star_rounded, l10n.sessionResultPoints(totalPoints)),
              if (coinsEarned > 0) chip(Icons.hourglass_bottom_rounded, l10n.sessionResultCoins(coinsEarned)),
              if (streak != null && streak > 0) chip(Icons.local_fire_department_rounded, l10n.sessionResultStreak(streak)),
            ],
          ),
          if (bonusPoints > 0 && !dailyLimitReached) ...[
            const SizedBox(height: 10),
            Text(
              l10n.sessionPointsBreakdown(basePoints, bonusPoints, bonusPct, totalPoints),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
          if (dailyLimitReached) ...[
            const SizedBox(height: 10),
            message(l10n.sessionDailyLimitReached(sessionDailyLimit()), Icons.info_outline_rounded, accent),
          ],
        ],
      SessionSubmitQueued(:final reasonCode) => [
          message(sessionQueuedMessage(l10n, reasonCode), Icons.cloud_upload_outlined, muted),
        ],
      SessionSubmitRejected(:final reasonCode) => [
          message(sessionRejectionMessage(l10n, reasonCode), Icons.error_outline_rounded, Colors.orange.shade800),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(onPressed: _openRejectedSessions, child: Text(l10n.rejectedSessionsTitle)),
          ),
        ],
    };

    return AlertDialog(
      // Yatay telefonda dikeyde sığmazsa kayar; tablette makul genişlikte kalır.
      scrollable: true,
      constraints: kTimerDialogConstraints,
      backgroundColor: isDark ? AppColors.darkSurfaceContainerHigh : AppColors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Column(
        children: [
          rejected
              ? Icon(Icons.cloud_off_rounded, color: Colors.orange.shade800, size: 48)
              : const Icon(Icons.stars_rounded, color: Colors.amber, size: 48),
          const SizedBox(height: 16),
          Text(
            rejected ? l10n.sessionNotSavedTitle : l10n.sessionCompletedTitle,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: isDark ? AppColors.darkOnSurface : AppColors.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!rejected)
            Text(
              l10n.sessionCompletedBody(widget.minutes),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: muted, height: 1.5),
            ),
          if (status.isNotEmpty) ...[
            if (!rejected) const SizedBox(height: 16),
            // Sonuç geldiğinde içerik yumuşakça değişir.
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: Column(mainAxisSize: MainAxisSize.min, children: status),
            ),
          ],
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Text(
              rejected ? l10n.sessionResultOk : l10n.sessionCompletedOk,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

/// Separate StatefulWidget for the 3-2-1 countdown to properly
/// manage its own Timer lifecycle without spawning duplicates.
class TimerCountdownDialog extends StatefulWidget {
  final VoidCallback onComplete;

  const TimerCountdownDialog({super.key, required this.onComplete});

  @override
  State<TimerCountdownDialog> createState() => _TimerCountdownDialogState();
}

class _TimerCountdownDialogState extends State<TimerCountdownDialog> {
  int _count = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_count > 1) {
        setState(() => _count--);
      } else {
        timer.cancel();
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      // Yatay telefonda ya da büyük yazı ölçeğinde sığmazsa orantılı küçülür.
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                // Hareketi Azalt açıkken rakamlar büyüyerek değil doğrudan değişir.
                duration: (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Text(
                  '$_count',
                  key: ValueKey(_count),
                  style: const TextStyle(
                    fontSize: 110,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(color: AppColors.primaryContainer, blurRadius: 30)],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.timerGetReady,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
