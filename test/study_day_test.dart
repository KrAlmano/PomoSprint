import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/utils/study_day.dart';
import 'package:timezone/timezone.dart' as tz;

// Testler cihazın saat diliminden bağımsızdır: anlar açık bir dilimde (ya da
// UTC) kurulur, çalışma günü profil diliminde hesaplanır (sunucu kuralı:
// ((started_at AT TIME ZONE profil_tz) - 4 saat)::date).
void main() {
  const istanbul = 'Europe/Istanbul';

  setUpAll(() => setStudyTimeZone(istanbul));
  tearDown(() => setStudyTimeZone(istanbul));

  /// [zone] diliminde duvar saatiyle verilen an (UTC).
  DateTime at(String zone, int y, int m, int d, [int h = 0, int min = 0, int s = 0]) =>
      tz.TZDateTime(tz.getLocation(zone), y, m, d, h, min, s).toUtc();

  group('studyDayOf (profil diliminde 04:00 sınırı)', () {
    test('04:00 öncesi bir önceki güne sayılır', () {
      expect(studyDayOf(at(istanbul, 2026, 10, 3, 0, 30)), DateTime(2026, 10, 2));
      expect(studyDayOf(at(istanbul, 2026, 10, 3, 3, 59, 59)), DateTime(2026, 10, 2));
    });

    test('04:00 ve sonrası aynı gün', () {
      expect(studyDayOf(at(istanbul, 2026, 10, 3, 4)), DateTime(2026, 10, 3));
      expect(studyDayOf(at(istanbul, 2026, 10, 3, 23, 59)), DateTime(2026, 10, 3));
    });

    test('ay ve yıl sınırında takvim aritmetiği', () {
      expect(studyDayOf(at(istanbul, 2026, 11, 1, 2)), DateTime(2026, 10, 31));
      expect(studyDayOf(at(istanbul, 2027, 1, 1, 1)), DateTime(2026, 12, 31));
      expect(studyDayOf(at(istanbul, 2028, 3, 1, 3)), DateTime(2028, 2, 29));
    });

    test('yalnızca an önemlidir: yerel ve UTC aynı an aynı gün', () {
      final local = DateTime(2026, 10, 3, 2);
      expect(studyDayOf(local.toUtc()), studyDayOf(local));
    });

    // Yaz saati geçiş günleri (Avrupa: 29 Mart 2026, 25 Ekim 2026; ABD: 8 Mart,
    // 1 Kasım 2026). Hesap takvim alanlarıyla yapıldığı için gün kaymaz.
    test('yaz saati geçiş günlerinde gün kayması yok', () {
      for (final (zone, day) in [
        ('Europe/Berlin', DateTime(2026, 3, 29)),
        ('Europe/Berlin', DateTime(2026, 10, 25)),
        ('America/New_York', DateTime(2026, 3, 8)),
        ('America/New_York', DateTime(2026, 11, 1)),
      ]) {
        DateTime of(int h, int m) => studyDayOf(at(zone, day.year, day.month, day.day, h, m), timeZone: zone);
        expect(of(3, 30), DateTime(day.year, day.month, day.day - 1), reason: '$zone $day 03:30');
        expect(of(4, 30), DateTime(day.year, day.month, day.day), reason: '$zone $day 04:30');
        expect(of(23, 30), DateTime(day.year, day.month, day.day), reason: '$zone $day 23:30');
      }
    });

    test('gün cihazın değil profilin diliminde hesaplanır', () {
      // Berlin'de 4 Ekim 03:30 = İstanbul'da 04:30: sunucu (profil İstanbul) 4 Ekim sayar.
      final berlinNight = at('Europe/Berlin', 2026, 10, 4, 3, 30);
      expect(studyDayOf(berlinNight), DateTime(2026, 10, 4));
      expect(studyDayOf(berlinNight, timeZone: 'Europe/Berlin'), DateTime(2026, 10, 3));
      // Singapur'da 4 Ekim 05:00 = İstanbul'da 4 Ekim 00:00: hâlâ 3 Ekim.
      expect(studyDayOf(at('Asia/Singapore', 2026, 10, 4, 5)), DateTime(2026, 10, 3));
      // New York'ta 3 Ekim 22:00 = İstanbul'da 4 Ekim 05:00.
      expect(studyDayOf(at('America/New_York', 2026, 10, 3, 22)), DateTime(2026, 10, 4));
    });

    test('etkin dilim profilden ayarlanır; boş/bilinmeyen değerde varsayılan', () {
      setStudyTimeZone('Europe/Berlin');
      expect(activeStudyTimeZone, 'Europe/Berlin');
      expect(studyDayOf(at('Europe/Berlin', 2026, 10, 4, 3, 30)), DateTime(2026, 10, 3));
      setStudyTimeZone('Mars/Olympus');
      expect(activeStudyTimeZone, kDefaultStudyTimeZone);
      setStudyTimeZone(null);
      expect(activeStudyTimeZone, kDefaultStudyTimeZone);
    });
  });

  group('studyDayStart', () {
    test('çalışma gününün başladığı an profil diliminde 04:00', () {
      expect(studyDayStart(DateTime(2026, 10, 4)).isAtSameMomentAs(DateTime.utc(2026, 10, 4, 1)), isTrue);
      expect(
        studyDayStart(DateTime(2026, 10, 4), timeZone: 'America/New_York').isAtSameMomentAs(DateTime.utc(2026, 10, 4, 8)),
        isTrue,
      );
      // Başlangıç anı o güne, bir saniye öncesi bir önceki güne aittir.
      final start = studyDayStart(DateTime(2026, 10, 4));
      expect(studyDayOf(start), DateTime(2026, 10, 4));
      expect(studyDayOf(start.subtract(const Duration(seconds: 1))), DateTime(2026, 10, 3));
    });
  });

  group('studyDaysBetween', () {
    test('saat bilgisinden ve yaz saatinden bağımsız gün farkı', () {
      expect(studyDaysBetween(DateTime(2026, 3, 28, 23), DateTime(2026, 3, 30, 1)), 2);
      expect(studyDaysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2);
      expect(studyDaysBetween(DateTime(2026, 10, 3), DateTime(2026, 10, 1)), -2);
    });
  });

  group('studyDayKey / parseStudyDayKey', () {
    test('gidiş-dönüş', () {
      final day = DateTime(2026, 1, 5);
      expect(studyDayKey(day), '2026-01-05');
      expect(parseStudyDayKey('2026-01-05'), day);
      expect(parseStudyDayKey('2026-01-05T00:00:00'), day);
      expect(parseStudyDayKey('bozuk'), isNull);
      expect(parseStudyDayKey(null), isNull);
    });
  });

  group('effectiveStreak', () {
    int streak(String? last, DateTime now, {int stored = 5, String? timeZone}) =>
        effectiveStreak(storedStreak: stored, lastStudyDate: last, now: now, timeZone: timeZone);

    test('bugün ya da dün çalışıldıysa seri korunur', () {
      expect(streak('2026-10-03', at(istanbul, 2026, 10, 3, 12)), 5);
      expect(streak('2026-10-02', at(istanbul, 2026, 10, 3, 12)), 5);
    });

    test('iki gün ve fazlası boşlukta seri 0', () {
      expect(streak('2026-10-01', at(istanbul, 2026, 10, 3, 12)), 0);
    });

    test('gece 04:00 öncesi hâlâ önceki çalışma günü sayılır', () {
      // Sunucuya göre 3 Ekim 02:00 hâlâ 2 Ekim; 1 Ekim'den beri seri sürüyor.
      expect(streak('2026-10-01', at(istanbul, 2026, 10, 3, 2)), 5);
    });

    test('son çalışma günü yoksa ya da seri 0 ise 0', () {
      expect(streak(null, at(istanbul, 2026, 10, 3)), 0);
      expect(streak('2026-10-03', at(istanbul, 2026, 10, 3), stored: 0), 0);
    });

    test('gelecekteki gün (saat dilimi farkı) seriyi bozmaz', () {
      expect(streak('2026-10-04', at(istanbul, 2026, 10, 3, 12)), 5);
    });

    test('seri sunucunun (profilin) gün sınırıyla kırılır, cihazınkiyle değil', () {
      // Berlin'deki cihaz, 4 Ekim 03:30: profil İstanbul'a göre 4 Ekim, son gün 2 Ekim → kırık.
      final berlinNight = at('Europe/Berlin', 2026, 10, 4, 3, 30);
      expect(streak('2026-10-02', berlinNight, timeZone: istanbul), 0);
      expect(streak('2026-10-02', berlinNight, timeZone: 'Europe/Berlin'), 5);
    });
  });
}
