import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/utils/study_day.dart';

void main() {
  group('studyDayOf (04:00 sınırı)', () {
    test('04:00 öncesi bir önceki güne sayılır', () {
      expect(studyDayOf(DateTime(2026, 10, 3, 0, 30)), DateTime(2026, 10, 2));
      expect(studyDayOf(DateTime(2026, 10, 3, 3, 59, 59)), DateTime(2026, 10, 2));
    });

    test('04:00 ve sonrası aynı gün', () {
      expect(studyDayOf(DateTime(2026, 10, 3, 4)), DateTime(2026, 10, 3));
      expect(studyDayOf(DateTime(2026, 10, 3, 23, 59)), DateTime(2026, 10, 3));
    });

    test('ay ve yıl sınırında takvim aritmetiği', () {
      expect(studyDayOf(DateTime(2026, 11, 1, 2)), DateTime(2026, 10, 31));
      expect(studyDayOf(DateTime(2027, 1, 1, 1)), DateTime(2026, 12, 31));
      expect(studyDayOf(DateTime(2028, 3, 1, 3)), DateTime(2028, 2, 29));
    });

    test('UTC değer yerel saate çevrilir', () {
      final local = DateTime(2026, 10, 3, 2);
      expect(studyDayOf(local.toUtc()), studyDayOf(local));
    });

    // Yaz saati geçiş günleri (Avrupa: 29 Mart 2026, 25 Ekim 2026; ABD: 8 Mart,
    // 1 Kasım 2026). Hesap takvim alanlarıyla yapıldığı için cihazın saat
    // dilimi ne olursa olsun sonuç aynıdır.
    test('yaz saati geçiş günlerinde gün kayması yok', () {
      for (final day in [DateTime(2026, 3, 29), DateTime(2026, 10, 25), DateTime(2026, 3, 8), DateTime(2026, 11, 1)]) {
        expect(studyDayOf(DateTime(day.year, day.month, day.day, 3, 30)),
            DateTime(day.year, day.month, day.day - 1), reason: '$day 03:30');
        expect(studyDayOf(DateTime(day.year, day.month, day.day, 4, 30)), DateTime(day.year, day.month, day.day),
            reason: '$day 04:30');
        expect(studyDayOf(DateTime(day.year, day.month, day.day, 23, 30)), DateTime(day.year, day.month, day.day),
            reason: '$day 23:30');
      }
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
    int streak(String? last, DateTime now, {int stored = 5}) =>
        effectiveStreak(storedStreak: stored, lastStudyDate: last, now: now);

    test('bugün ya da dün çalışıldıysa seri korunur', () {
      expect(streak('2026-10-03', DateTime(2026, 10, 3, 12)), 5);
      expect(streak('2026-10-02', DateTime(2026, 10, 3, 12)), 5);
    });

    test('iki gün ve fazlası boşlukta seri 0', () {
      expect(streak('2026-10-01', DateTime(2026, 10, 3, 12)), 0);
    });

    test('gece 04:00 öncesi hâlâ önceki çalışma günü sayılır', () {
      // Sunucuya göre 3 Ekim 02:00 hâlâ 2 Ekim; 1 Ekim'den beri seri sürüyor.
      expect(streak('2026-10-01', DateTime(2026, 10, 3, 2)), 5);
    });

    test('son çalışma günü yoksa ya da seri 0 ise 0', () {
      expect(streak(null, DateTime(2026, 10, 3)), 0);
      expect(streak('2026-10-03', DateTime(2026, 10, 3), stored: 0), 0);
    });

    test('gelecekteki gün (saat dilimi farkı) seriyi bozmaz', () {
      expect(streak('2026-10-04', DateTime(2026, 10, 3, 12)), 5);
    });
  });
}
