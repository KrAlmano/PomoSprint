// Takvim hesapları cihazın saat diliminden bağımsız olmalı. Yaz saati
// geçişlerini de doğrulamak için farklı dilimlerle çalıştırın:
//   TZ=Europe/Berlin flutter test test/stats_calculator_test.dart
//   TZ=America/New_York flutter test test/stats_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/study_session.dart';
import 'package:pomodoro/services/session_queue.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:pomodoro/utils/stats_format.dart';

StatSession _s(DateTime day, int minutes, {String cat = 'Matematik', String? hex, bool pending = false}) =>
    StatSession(day: day, minutes: minutes, categoryName: cat, colorHex: hex, pending: pending);

/// [from]..[to] arasındaki her güne [minutes] dakikalık bir seans.
List<StatSession> _everyDay(DateTime from, DateTime to, int minutes) => [
      for (var d = from; dayKeyOf(d) <= dayKeyOf(to); d = addDays(d, 1)) _s(d, minutes),
    ];

void main() {
  group('takvim yardımcıları', () {
    test('addDays ve mondayOf yaz saati geçişlerinde gün kaydırmaz', () {
      // Avrupa: 29 Mart / 25 Ekim 2026, ABD: 8 Mart / 1 Kasım 2026.
      expect(addDays(DateTime(2026, 3, 29), 1), DateTime(2026, 3, 30));
      expect(addDays(DateTime(2026, 10, 25), 1), DateTime(2026, 10, 26));
      expect(addDays(DateTime(2026, 3, 8), 1), DateTime(2026, 3, 9));
      expect(addDays(DateTime(2026, 11, 1), 1), DateTime(2026, 11, 2));
      expect(addDays(DateTime(2026, 10, 19), 7), DateTime(2026, 10, 26));
      expect(addDays(DateTime(2026, 3, 1), -7), DateTime(2026, 2, 22));
      expect(mondayOf(DateTime(2026, 11, 1)), DateTime(2026, 10, 26));
      expect(mondayOf(DateTime(2026, 3, 30)), DateTime(2026, 3, 30));
      expect(mondayOf(DateTime(2026, 3, 29)), DateTime(2026, 3, 23));
      expect(mondayOf(DateTime(2026, 10, 3)), DateTime(2026, 9, 28));
    });

    test('dayKeyOf saat bilgisini yok sayar', () {
      expect(dayKeyOf(DateTime(2026, 10, 3, 23, 59)), 20261003);
      expect(isSameDay(DateTime(2026, 10, 3), DateTime(2026, 10, 3, 12)), isTrue);
      expect(earlierDay(DateTime(2026, 10, 4), DateTime(2026, 10, 3)), DateTime(2026, 10, 3));
    });
  });

  group('weeksOfMonth', () {
    test('Ekim 2026: ay dışına taşan ilk/son hafta kırpılır, gün kaybolmaz', () {
      final weeks = weeksOfMonth(DateTime(2026, 10, 1), DateTime(2026, 10, 31));
      expect(weeks.map((w) => w.start).toList(), [
        DateTime(2026, 9, 28),
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 26),
      ]);
      expect(weeks.first.rangeStart, DateTime(2026, 10, 1));
      expect(weeks.first.rangeEnd, DateTime(2026, 10, 4));
      expect(weeks.last.end, DateTime(2026, 11, 1));
      expect(weeks.last.rangeEnd, DateTime(2026, 10, 31));
    });

    test('Mart 2026: 30 Mart son haftaya düşer (Berlin DST senaryosu)', () {
      final weeks = weeksOfMonth(DateTime(2026, 3, 1), DateTime(2026, 3, 31));
      expect(weeks.first.rangeStart, DateTime(2026, 3, 1));
      expect(weeks.first.rangeEnd, DateTime(2026, 3, 1));
      expect(weeks.last.rangeStart, DateTime(2026, 3, 30));
      expect(weeks.last.rangeEnd, DateTime(2026, 3, 31));
    });

    test('ayın her günü tam olarak bir haftaya düşer', () {
      for (var year = 2026; year <= 2027; year++) {
        for (var month = 1; month <= 12; month++) {
          final start = DateTime(year, month, 1);
          final end = monthEndOf(start);
          final weeks = weeksOfMonth(start, end);
          final covered = <int>[];
          for (final w in weeks) {
            for (var d = w.rangeStart; dayKeyOf(d) <= dayKeyOf(w.rangeEnd); d = addDays(d, 1)) {
              covered.add(dayKeyOf(d));
            }
          }
          expect(covered, [for (var d = 1; d <= end.day; d++) dayKeyOf(DateTime(year, month, d))],
              reason: '$year-$month');
        }
      }
    });

    test('yalnızca bugüne kadar başlamış haftalar listelenir', () {
      final weeks = weeksOfMonth(DateTime(2026, 10, 1), DateTime(2026, 10, 3));
      expect(weeks, hasLength(1));
      expect(weeksOfMonth(DateTime(2026, 10, 1), DateTime(2026, 10, 12)), hasLength(3));
    });
  });

  group('compareWithPreviousWeek', () {
    test('kırpılmış ve devam eden hafta eşit pencereyle kıyaslanır', () {
      // Her gün 2 saat çalışan kullanıcı; bugün 3 Ekim 2026 Cumartesi.
      final today = DateTime(2026, 10, 3);
      final sessions = _everyDay(DateTime(2026, 9, 1), today, 120);
      final week = weeksOfMonth(DateTime(2026, 10, 1), today).single;
      final c = compareWithPreviousWeek(sessions, week, today);
      expect(c.from, DateTime(2026, 10, 1));
      expect(c.to, today);
      expect(c.minutes, 360);
      expect(c.previousMinutes, 360);
      expect(c.percentChange, 0);
    });

    test('devam eden ortadaki hafta da aynı günlerle kıyaslanır', () {
      final today = DateTime(2026, 10, 13); // Salı
      final sessions = _everyDay(DateTime(2026, 9, 1), today, 60);
      final week = weeksOfMonth(DateTime(2026, 10, 1), today).last;
      final c = compareWithPreviousWeek(sessions, week, today);
      expect(c.minutes, 120);
      expect(c.previousMinutes, 120);
      expect(c.percentChange, 0);
    });

    test('kıyas değeri yoksa yüzde yok', () {
      final today = DateTime(2026, 10, 3);
      final week = weeksOfMonth(DateTime(2026, 10, 1), today).single;
      final c = compareWithPreviousWeek([_s(today, 50)], week, today);
      expect(c.percentChange, isNull);
    });
  });

  group('toplamlar', () {
    test('dailyTotals her takvim günü için bir kayıt üretir', () {
      final days = dailyTotals(
        [
          _s(DateTime(2026, 10, 25), 50),
          _s(DateTime(2026, 10, 25), 25, pending: true),
          _s(DateTime(2026, 10, 27), 10),
          _s(DateTime(2026, 11, 2), 99),
        ],
        DateTime(2026, 10, 25),
        DateTime(2026, 11, 1),
      );
      expect(days, hasLength(8));
      expect(days.first.minutes, 75);
      expect(days.first.pomodoros, 3);
      expect(days.first.pendingSessions, 1);
      expect(days[2].minutes, 10);
      expect(days.last.day, DateTime(2026, 11, 1));
      expect(days.last.minutes, 0);
      expect(busiestDay(days)!.day, DateTime(2026, 10, 25));
      expect(busiestDay(dailyTotals(const [], DateTime(2026, 10, 1), DateTime(2026, 10, 7))), isNull);
    });

    test('totalsByCategory çoktan aza sıralar ve rengi korur', () {
      final stats = totalsByCategory([
        _s(DateTime(2026, 10, 3), 25, cat: 'Fizik'),
        _s(DateTime(2026, 10, 3), 50, cat: 'Kimya', hex: '#10B981'),
        _s(DateTime(2026, 10, 3), 25, cat: 'Fizik', hex: '#3B82F6', pending: true),
        _s(DateTime(2026, 10, 3), 50, cat: 'Biyoloji'),
      ]);
      expect(stats.map((c) => c.name).toList(), ['Biyoloji', 'Fizik', 'Kimya']);
      final physics = stats[1];
      expect(physics.minutes, 50);
      expect(physics.sessions, 2);
      expect(physics.pendingSessions, 1);
      expect(physics.colorHex, '#3B82F6');
    });

    test('goalPercent hedefe ulaşmadan %100 göstermez', () {
      expect(goalPercent(199, 200), 99);
      expect(goalPercent(200, 200), 100);
      expect(goalPercent(500, 200), 100);
      expect(goalPercent(75, 60), 100);
      expect(goalPercent(10, 0), 0);
    });

    test('percentChangeOf', () {
      expect(percentChangeOf(150, 100), 50);
      expect(percentChangeOf(60, 140), -57);
      expect(percentChangeOf(10, 0), isNull);
    });

    test('effectiveDailyGoalMinutes', () {
      expect(effectiveDailyGoalMinutes(null), kDefaultDailyGoalMinutes);
      expect(effectiveDailyGoalMinutes(0), kDefaultDailyGoalMinutes);
      expect(effectiveDailyGoalMinutes(60), 60);
    });
  });

  group('monthToDateComparison', () {
    test('önceki ayın aynı dönemiyle kıyaslar', () {
      final sessions = _everyDay(DateTime(2026, 9, 1), DateTime(2026, 10, 10), 30);
      final c = monthToDateComparison(sessions, DateTime(2026, 10, 10));
      expect(c.current, 300);
      expect(c.previous, 300);
    });

    test('önceki ay kısaysa ay sonuna kırpılır', () {
      final sessions = _everyDay(DateTime(2026, 2, 1), DateTime(2026, 3, 31), 10);
      final c = monthToDateComparison(sessions, DateTime(2026, 3, 31));
      expect(c.current, 310);
      expect(c.previous, 280);
    });

    test('ocakta önceki yılın aralığına bakar', () {
      final sessions = _everyDay(DateTime(2026, 12, 1), DateTime(2027, 1, 5), 10);
      final c = monthToDateComparison(sessions, DateTime(2027, 1, 5));
      expect(c.current, 50);
      expect(c.previous, 50);
    });
  });

  group('weeklyCategorySeries', () {
    test('lejantsız seri kalmaz: fazlası "diğer"de toplanır', () {
      final today = DateTime(2026, 10, 31);
      final weeks = weeksOfMonth(DateTime(2026, 10, 1), today);
      final sessions = [
        for (var i = 0; i < 8; i++) _s(DateTime(2026, 10, 1 + i), 100 - i, cat: 'K$i'),
        _s(DateTime(2026, 9, 30), 500, cat: 'EylülDersi'),
      ];
      final series = weeklyCategorySeries(sessions, weeks);
      expect(series, hasLength(6));
      expect(series.take(5).map((s) => s.name).toList(), ['K0', 'K1', 'K2', 'K3', 'K4']);
      expect(series.last.isOther, isTrue);
      expect(series.every((s) => s.weeklyMinutes.length == weeks.length), isTrue);
      // K5..K7 (6, 7, 8 Ekim) 5-11 Ekim haftasında; Eylül'deki ders ay dışında.
      expect(series.last.weeklyMinutes, [0, 95 + 94 + 93, 0, 0, 0]);
      final total = series.fold<int>(0, (sum, s) => sum + s.weeklyMinutes.fold(0, (a, b) => a + b));
      expect(total, sumMinutesBetween(sessions, DateTime(2026, 10, 1), today));
    });

    test('az kategoride hepsi ayrı seri', () {
      final today = DateTime(2026, 10, 10);
      final weeks = weeksOfMonth(DateTime(2026, 10, 1), today);
      final series = weeklyCategorySeries([_s(DateTime(2026, 10, 2), 25), _s(DateTime(2026, 10, 6), 50)], weeks);
      expect(series, hasLength(1));
      expect(series.single.weeklyMinutes, [25, 50]);
    });
  });

  group('StatSession', () {
    test('sunucu seansı 04:00 kuralıyla başlangıç gününe atanır', () {
      final session = StudySession(
        id: 'x',
        userId: 'u',
        categoryName: 'Fizik',
        minutes: 50,
        pomodoros: 2,
        startedAt: DateTime(2026, 10, 3, 2, 30),
        completedAt: DateTime(2026, 10, 5, 12),
      );
      final stat = StatSession.fromStudySession(session);
      expect(stat.day, DateTime(2026, 10, 2));
      expect(stat.pending, isFalse);
      expect(stat.pomodoros, 2);
    });

    test('kuyruktaki seans bekleyen olarak işaretlenir', () {
      final pending = PendingSession(
        clientUuid: 'c',
        categoryId: '1',
        categoryName: 'Matematik',
        minutes: 25,
        wasPaused: false,
        foregroundSeconds: 1500,
        startedAt: DateTime(2026, 10, 3, 9).toUtc(),
        queuedAt: DateTime(2026, 10, 3, 9, 25).toUtc(),
      );
      final stat = StatSession.fromPending(pending);
      expect(stat.day, DateTime(2026, 10, 3));
      expect(stat.pending, isTrue);
    });
  });

  group('biçimler', () {
    test('formatStudyMinutes tek biçim kullanır', () {
      String f(int m) => formatStudyMinutes(m, hourAbbr: 'sa', minAbbr: 'dk');
      expect(f(0), '0dk');
      expect(f(50), '50dk');
      expect(f(60), '1sa');
      expect(f(75), '1sa 15dk');
      expect(f(605), '10sa 5dk');
    });

    test('formatPercent yerel ayara uyar', () {
      expect(formatPercent(50, 'tr'), '%50');
      expect(formatPercent(50, 'en'), '50%');
    });
  });
}
