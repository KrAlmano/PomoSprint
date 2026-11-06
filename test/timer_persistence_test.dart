import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/services/timer_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

ActiveTimerSession _start(DateTime now, {int totalSeconds = 25 * 60}) => ActiveTimerSession.start(
      clientUuid: 'uuid-1',
      categoryId: 'cat-1',
      categoryName: 'Fizik',
      durationMinutes: 25,
      totalSeconds: totalSeconds,
      now: now,
    );

void main() {
  final t0 = DateTime(2026, 10, 3, 10);

  test('her derlemede (debug dahil) gerçek süre; kısaltma yalnızca hızlı test sayacında', () {
    // flutter test debug derlemedir: varsayılan artık gerçek süre.
    expect(kQuickTimer, isFalse);
    expect(timerDurationSeconds(25), 25 * 60);
    expect(timerDurationSeconds(50), 50 * 60);
    expect(timerDurationSeconds(25, quick: false), 25 * 60);
    expect(timerDurationSeconds(50, quick: false), 50 * 60);
    expect(timerDurationSeconds(25, quick: true), 5);
    expect(timerDurationSeconds(50, quick: true), 10);
  });

  test('kısaltılmış sayaçla başlatılan seans test seansıdır (gönderilmez)', () {
    expect(_start(t0).isQuickTest, isFalse);
    expect(_start(t0, totalSeconds: timerDurationSeconds(25, quick: true)).isQuickTest, isTrue);
    // Kayıttan geri yüklenince de (eski debug derlemesinin 5 sn'lik seansı dahil) tanınır.
    final restored = ActiveTimerSession.fromJson(_start(t0, totalSeconds: 5).toJson())!;
    expect(restored.isQuickTest, isTrue);
    final real50 = ActiveTimerSession.start(
      clientUuid: 'u',
      categoryId: 'c',
      categoryName: 'Fizik',
      durationMinutes: 50,
      totalSeconds: 50 * 60,
      now: t0,
    );
    expect(real50.isQuickTest, isFalse);
  });

  group('ActiveTimerSession', () {
    test('yeni seans başlangıçtan totalSeconds sonra biter', () {
      final s = _start(t0);
      expect(s.isRunning, isTrue);
      expect(s.endsAt, t0.add(const Duration(minutes: 25)));
      expect(s.remainingSecondsAt(t0), 25 * 60);
      expect(s.remainingSecondsAt(t0.add(const Duration(minutes: 10, milliseconds: 500))), 15 * 60);
      expect(s.isFinishedAt(t0.add(const Duration(minutes: 24, seconds: 59))), isFalse);
      expect(s.isFinishedAt(t0.add(const Duration(minutes: 25))), isTrue);
      expect(s.remainingSecondsAt(t0.add(const Duration(hours: 3))), 0);
    });

    test('duraklat: kalan süre donar, hak kullanılır; devam: bitiş kalan süreye göre', () {
      final paused = _start(t0).pauseAt(t0.add(const Duration(minutes: 20)));
      expect(paused.isRunning, isFalse);
      expect(paused.pausedRemainingSeconds, 5 * 60);
      expect(paused.pauseUsedCount, 1);
      expect(paused.wasPaused, isTrue);
      // Duraklatılmışken zaman geçse de kalan süre değişmez.
      expect(paused.remainingSecondsAt(t0.add(const Duration(hours: 2))), 5 * 60);
      expect(paused.isFinishedAt(t0.add(const Duration(hours: 2))), isFalse);

      final resumeAt = t0.add(const Duration(hours: 1));
      final resumed = paused.resumeAt(resumeAt);
      expect(resumed.isRunning, isTrue);
      expect(resumed.endsAt, resumeAt.add(const Duration(minutes: 5)));
      expect(resumed.pausedRemainingSeconds, isNull);
      expect(resumed.pauseUsedCount, 1);
      // Başlangıç zamanı ve kimlik devamda korunur.
      expect(resumed.startedAt, t0);
      expect(resumed.clientUuid, 'uuid-1');
    });

    test('24 saati aşacak duraklatılmış seans terk edilmiş sayılır', () {
      final paused = _start(t0).pauseAt(t0.add(const Duration(minutes: 20)));
      expect(paused.isAbandonedAt(t0.add(const Duration(hours: 23))), isFalse);
      expect(paused.isAbandonedAt(t0.add(const Duration(hours: 23, minutes: 56))), isTrue);
      // Çalışan seans bu kurala girmez (süresi dolunca hemen gönderilir).
      expect(_start(t0).isAbandonedAt(t0.add(const Duration(days: 3))), isFalse);
    });

    test('JSON gidiş-dönüş (çalışan ve duraklatılmış)', () {
      final running = _start(t0).withForegroundSeconds(42);
      final paused = running.pauseAt(t0.add(const Duration(minutes: 3)));
      for (final s in [running, paused]) {
        final copy = ActiveTimerSession.fromJson(jsonDecode(jsonEncode(s.toJson())))!;
        expect(copy.clientUuid, s.clientUuid);
        expect(copy.categoryId, s.categoryId);
        expect(copy.categoryName, s.categoryName);
        expect(copy.durationMinutes, s.durationMinutes);
        expect(copy.totalSeconds, s.totalSeconds);
        expect(copy.startedAt, s.startedAt);
        expect(copy.endsAt, s.endsAt);
        expect(copy.pausedRemainingSeconds, s.pausedRemainingSeconds);
        expect(copy.pauseUsedCount, s.pauseUsedCount);
        expect(copy.foregroundSeconds, 42);
      }
    });

    test('bozuk kayıt null döner', () {
      expect(ActiveTimerSession.fromJson(null), isNull);
      expect(ActiveTimerSession.fromJson('x'), isNull);
      expect(ActiveTimerSession.fromJson({'client_uuid': 'a'}), isNull);
      final json = _start(t0).toJson()
        ..['ends_at'] = null
        ..['paused_remaining_seconds'] = null;
      expect(ActiveTimerSession.fromJson(json), isNull);
    });
  });

  group('TimerPersistence', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('kaydet, oku, sil', () async {
      final store = TimerPersistence.instance;
      expect(await store.load('u1'), isNull);
      await store.save('u1', _start(t0));
      expect((await store.load('u1'))?.clientUuid, 'uuid-1');
      expect(await store.load('u2'), isNull, reason: 'kayıt kullanıcıya bağlı');
      await store.clear('u1');
      expect(await store.load('u1'), isNull);
    });

    test('clear(onlyClientUuid) sonradan başlatılan seansı silmez', () async {
      final store = TimerPersistence.instance;
      final newer = ActiveTimerSession.start(
        clientUuid: 'uuid-2',
        categoryId: 'cat-1',
        categoryName: 'Fizik',
        durationMinutes: 25,
        totalSeconds: 1500,
        now: t0,
      );
      await store.save('u1', newer);
      await store.clear('u1', onlyClientUuid: 'uuid-1');
      expect((await store.load('u1'))?.clientUuid, 'uuid-2');
      await store.clear('u1', onlyClientUuid: 'uuid-2');
      expect(await store.load('u1'), isNull);
    });

    test('eski anahtardaki kayıt yeni anahtara taşınır', () async {
      final store = TimerPersistence.instance;
      await store.save('mail@example.com', _start(t0));
      final loaded = await store.load('uid-1', legacyOwnerKey: 'mail@example.com');
      expect(loaded?.clientUuid, 'uuid-1');
      expect(await store.load('mail@example.com'), isNull);
      expect((await store.load('uid-1'))?.clientUuid, 'uuid-1');
    });

    test('bozuk JSON okunurken çökmez', () async {
      SharedPreferences.setMockInitialValues({TimerPersistence.keyFor('u1'): '{bozuk'});
      final store = TimerPersistence.instance;
      expect(await store.load('u1'), isNull);
      expect(await store.hasInvalidRecord('u1'), isTrue);
      expect(await store.saveChecked('u1', _start(t0)), isFalse);
      await store.clear('u1', onlyClientUuid: 'uuid-1');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(TimerPersistence.keyFor('u1')), '{bozuk');
      await store.save('legacy', _start(t0));
      expect(await store.load('u1', legacyOwnerKey: 'legacy'), isNull);
      expect((await store.load('legacy'))?.clientUuid, 'uuid-1');
      expect(prefs.getString(TimerPersistence.keyFor('u1')), '{bozuk');
      await prefs.setString(TimerPersistence.keyFor('bad-legacy'), '{legacy-broken');
      expect(await store.hasInvalidRecord('new-owner', legacyOwnerKey: 'bad-legacy'), isTrue);
      expect(await store.load('new-owner', legacyOwnerKey: 'bad-legacy'), isNull);
      expect(prefs.getString(TimerPersistence.keyFor('bad-legacy')), '{legacy-broken');
    });
  });
}
