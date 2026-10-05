import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/services/local_test_mode.dart';
import 'package:pomodoro/services/timer_persistence.dart';

void main() {
  test(
    'kayıtlı kısa seans yalnızca debug ve açıkça seçilen yerel HTTP backend',
    () {
      for (final host in ['localhost', '127.0.0.1', '[::1]', '10.0.2.2']) {
        expect(
          localQuickRecordingAllowed(
            debug: true,
            requested: true,
            url: 'http://$host:54321',
          ),
          isTrue,
        );
        expect(
          localQuickRecordingAllowed(
            debug: false,
            requested: true,
            url: 'http://$host:54321',
          ),
          isFalse,
        );
        expect(
          localQuickRecordingAllowed(
            debug: true,
            requested: false,
            url: 'http://$host:54321',
          ),
          isFalse,
        );
      }
      for (final url in [
        '',
        'https://eoosnyakvxmifmexpgxa.supabase.co',
        'http://localhost.evil.test',
        'http://127.0.0.1.evil.test',
        'http://localhost@evil.test',
      ]) {
        expect(
          localQuickRecordingAllowed(debug: true, requested: true, url: url),
          isFalse,
        );
      }
    },
  );
  test('yerel QA işareti duraklat/devam ve diskten yüklemede korunur', () {
    final now = DateTime(2026, 10, 5, 12);
    final session = ActiveTimerSession.start(
      clientUuid: 'qa',
      categoryId: 'cat',
      categoryName: 'Matematik',
      durationMinutes: 25,
      totalSeconds: 5,
      now: now,
      recordAccelerated: true,
    );
    final resumed = session
        .pauseAt(now.add(const Duration(seconds: 1)))
        .resumeAt(now.add(const Duration(seconds: 2)));
    final restored = ActiveTimerSession.fromJson(resumed.toJson())!;
    expect(restored.recordAccelerated, isTrue);
    expect(restored.durationMinutes, 25);
    expect(restored.totalSeconds, 5);
    expect(
      ActiveTimerSession.fromJson(
        {...restored.toJson()}..remove('record_accelerated'),
      )!.recordAccelerated,
      isFalse,
    );
  });
}
