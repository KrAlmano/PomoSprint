import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/l10n/app_localizations.dart';
import 'package:pomodoro/services/lock_screen_timer.dart';
import 'package:pomodoro/services/timer_persistence.dart';

import 'support/fake_lock_screen_platform.dart';

ActiveTimerSession _running(DateTime startedAt, {String id = 's1', int totalSeconds = 25 * 60}) => ActiveTimerSession.start(
      clientUuid: id,
      categoryId: 'cat-1',
      categoryName: 'Matematik',
      durationMinutes: 25,
      totalSeconds: totalSeconds,
      now: startedAt,
    );

void main() {
  final tr = lookupAppLocalizations(const Locale('tr'));
  final en = lookupAppLocalizations(const Locale('en'));
  final t0 = DateTime(2026, 10, 3, 14, 0);

  late FakeLockScreenPlatform platform;
  late DateTime now;
  late bool enabled;
  late AppLocalizations l10n;
  var enabledReads = 0;

  LockScreenTimer build({LockScreenTimerPlatform? withPlatform}) => LockScreenTimer(
        platform: withPlatform ?? platform,
        isEnabled: () async {
          enabledReads++;
          return enabled;
        },
        clock: () => now,
        localizations: () => l10n,
        categoryLabel: (name) => name,
      );

  setUp(() {
    platform = FakeLockScreenPlatform();
    now = t0;
    enabled = true;
    l10n = tr;
    enabledReads = 0;
  });

  group('içerik', () {
    test('çalışan seans: canlı geri sayım bitiş anına, bildirim bitişte kalkar', () async {
      final timer = build();
      final session = _running(t0);
      now = t0.add(const Duration(minutes: 10));

      await timer.showRunning(session);

      expect(platform.calls, ['show:running:s1:same']);
      final c = platform.shown.single;
      expect(c.isPaused, isFalse);
      expect(c.endsAt, t0.add(const Duration(minutes: 25)));
      expect(c.rangeStart, t0);
      expect(c.remainingSeconds, 15 * 60);
      expect(c.totalSeconds, 25 * 60);
      expect(c.expiresIn, const Duration(minutes: 15));
      expect(c.title, 'Matematik');
      expect(c.body, tr.lockTimerRunningBody('14:25'));
      expect(c.channelName, tr.lockTimerChannelName);
      expect(c.runningLabel, tr.lockTimerStatusRunning);
      expect(c.finishedLabel, tr.lockTimerStatusDone);
    });

    test('duraklatılmış seans: sabit kalan süre, 24 saat sınırında kalkar', () async {
      final timer = build();
      final paused = _running(t0).pauseAt(t0.add(const Duration(minutes: 20)));
      now = t0.add(const Duration(hours: 1));

      await timer.showPaused(paused);

      expect(platform.calls, ['show:paused:s1:same']);
      final c = platform.shown.single;
      expect(c.isPaused, isTrue);
      expect(c.remainingSeconds, 5 * 60);
      expect(c.body, tr.lockTimerPausedBody('05:00'));
      expect(c.body, 'Duraklatıldı · 05:00 kaldı');
      // 24 saat - (geçen 1 sa + kalan 5 dk)
      expect(c.expiresIn, const Duration(hours: 22, minutes: 55));
      // İlerleme oranı korunur: aralık başı = bitiş - toplam.
      expect(c.endsAt.difference(c.rangeStart), const Duration(minutes: 25));
    });

    test('devam ettirilen seans: yeni bitiş anı ve aynı seans güncellenir', () async {
      final timer = build();
      final paused = _running(t0).pauseAt(t0.add(const Duration(minutes: 20)));
      now = t0.add(const Duration(minutes: 30));
      await timer.showPaused(paused);
      final resumed = paused.resumeAt(now);

      await timer.showRunning(resumed);

      expect(platform.calls, ['show:paused:s1:same', 'show:running:s1:same']);
      expect(platform.shown.last.endsAt, t0.add(const Duration(minutes: 35)));
      expect(platform.shown.last.expiresIn, const Duration(minutes: 5));
    });

    test('iOS argümanları tam ve ms cinsinden', () {
      final timer = build();
      final c = timer.contentFor(_running(t0), t0)!;
      final args = c.toLiveActivityArguments();
      expect(args['sessionId'], 's1');
      expect(args['isPaused'], false);
      expect(args['endsAtMs'], t0.add(const Duration(minutes: 25)).millisecondsSinceEpoch);
      expect(args['startedAtMs'], t0.millisecondsSinceEpoch);
      expect(args['remainingSeconds'], 25 * 60);
      expect(args['totalSeconds'], 25 * 60);
      expect(args.keys, containsAll(['categoryName', 'runningLabel', 'pausedLabel', 'finishedLabel', 'finishedHint']));
    });

    test('süresi dolmuş ya da artık kaydedilemeyecek seans gösterilmez', () {
      final timer = build();
      expect(timer.contentFor(_running(t0), t0.add(const Duration(minutes: 25))), isNull);
      final paused = _running(t0).pauseAt(t0.add(const Duration(minutes: 1)));
      // Başlangıçtan 24 saat sonra devam edilse bile sunucu kabul etmez.
      expect(timer.contentFor(paused, t0.add(const Duration(hours: 23, minutes: 40))), isNull);
      expect(timer.contentFor(paused, t0.add(const Duration(hours: 23))), isNotNull);
    });

    test('süre biçimleri', () {
      expect(LockScreenTimer.formatRemaining(0), '00:00');
      expect(LockScreenTimer.formatRemaining(5), '00:05');
      expect(LockScreenTimer.formatRemaining(25 * 60), '25:00');
      expect(LockScreenTimer.formatRemaining(3600 + 61), '1:01:01');
      expect(LockScreenTimer.formatClockTime(DateTime(2026, 1, 1, 9, 5)), '09:05');
    });
  });

  group('durum geçişleri', () {
    test('aynı içerik tekrar gönderilmez; force ile yeniden gönderilir', () async {
      final timer = build();
      final session = _running(t0);

      await timer.showRunning(session);
      now = now.add(const Duration(seconds: 30));
      await timer.showRunning(session);
      expect(platform.calls, ['show:running:s1:same']);

      await timer.showRunning(session, force: true);
      expect(platform.calls, ['show:running:s1:same', 'show:running:s1:same']);
    });

    test('kaldırma idempotent; açılıştaki ilk kaldırma platforma gider', () async {
      final timer = build();
      await timer.clear();
      await timer.clear();
      expect(platform.calls, ['clear']);

      await timer.showRunning(_running(t0));
      await timer.clear();
      await timer.clear();
      expect(platform.calls, ['clear', 'show:running:s1:new', 'clear']);
    });

    test('başka seans başlayınca yeni etkinlik istenir', () async {
      final timer = build();
      await timer.showRunning(_running(t0));
      await timer.showRunning(_running(t0.add(const Duration(minutes: 30)), id: 's2'));
      expect(platform.calls, ['show:running:s1:same', 'show:running:s2:new']);
    });

    test('süresi dolmuş seans istenince gösterilen sayaç kaldırılır', () async {
      final timer = build();
      final session = _running(t0);
      await timer.showRunning(session);
      now = t0.add(const Duration(minutes: 26));
      await timer.showRunning(session);
      expect(platform.calls, ['show:running:s1:same', 'clear']);
    });

    test('çağrılar geliş sırasıyla uygulanır', () async {
      final timer = build();
      final session = _running(t0);
      final paused = session.pauseAt(t0.add(const Duration(minutes: 1)));
      await Future.wait([
        timer.showRunning(session),
        timer.showPaused(paused),
        timer.clear(),
      ]);
      expect(platform.calls, ['show:running:s1:same', 'show:paused:s1:same', 'clear']);
    });
  });

  group('tercih ve dil', () {
    test('bildirimler kapalıysa gösterilmez, açılınca refresh ile gösterilir', () async {
      enabled = false;
      final timer = build();
      final session = _running(t0);

      await timer.showRunning(session);
      expect(platform.calls, ['clear']);

      enabled = true;
      await timer.refresh();
      expect(platform.calls, ['clear', 'show:running:s1:new']);

      enabled = false;
      await timer.refresh();
      expect(platform.calls, ['clear', 'show:running:s1:new', 'clear']);
    });

    test('hiç istek yokken refresh bir şey yapmaz', () async {
      final timer = build();
      await timer.refresh();
      expect(platform.calls, isEmpty);
    });

    test('dil değişince içerik yeni dilde yeniden gönderilir', () async {
      final timer = build();
      final session = _running(t0);
      await timer.showRunning(session);
      l10n = en;
      await timer.refresh();
      expect(platform.calls, ['show:running:s1:same', 'show:running:s1:same']);
      expect(platform.shown.last.body, en.lockTimerRunningBody('14:25'));
      expect(platform.shown.last.runningLabel, en.lockTimerStatusRunning);
    });
  });

  group('hata dayanıklılığı', () {
    test('platform hatası dışarı sızmaz; sonraki çağrı yeniden dener', () async {
      final timer = build();
      final session = _running(t0);
      platform.showError = PlatformException(code: 'boom');

      await expectLater(timer.showRunning(session), completes);
      expect(platform.calls, isEmpty);

      platform.showError = null;
      await timer.showRunning(session);
      expect(platform.calls, ['show:running:s1:same']);
    });

    test('gösterilemezse (ör. Canlı Etkinlikler kapalı) durum bilinmez kalır ve tekrar denenir', () async {
      final timer = build();
      final session = _running(t0);
      platform.showResult = false;
      await timer.showRunning(session);
      platform.showResult = true;
      await timer.showRunning(session);
      expect(platform.calls, ['show:running:s1:same', 'show:running:s1:same']);
    });

    test('kaldırma hatası sızmaz; sonraki kaldırma yeniden dener', () async {
      final timer = build();
      platform.clearError = MissingPluginException();
      await expectLater(timer.clear(), completes);
      platform.clearError = null;
      await timer.clear();
      expect(platform.calls, ['clear']);
    });

    test('desteklenmeyen platformda hiçbir şey yapılmaz (tercih bile okunmaz)', () async {
      final timer = build(withPlatform: const NoopLockScreenTimerPlatform());
      await timer.showRunning(_running(t0));
      await timer.showPaused(_running(t0).pauseAt(t0));
      await timer.clear();
      await timer.refresh();
      expect(enabledReads, 0);
    });

    test('test ortamında varsayılan örnek no-op', () {
      expect(LockScreenTimer.instance.platform.isSupported, isFalse);
    });
  });
}
