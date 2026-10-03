import '../models/study_session.dart';
import '../services/session_queue.dart' show PendingSession;
import 'study_day.dart';

// İstatistik ekranlarının (Günlük / Haftalık / Aylık) ortak, saf hesapları.
//
// - Seanslar sunucunun gün kuralıyla (yerel 04:00 sınırı, bkz. studyDayOf)
//   çalışma gününe atanır.
// - Tüm gün adımları takvim aritmetiğiyle yapılır (DateTime(y, m, d + n));
//   Duration eklenmez, böylece yaz saati geçişlerinde gün kaymaz.
// - Gün karşılaştırmaları 'yyyymmdd' tamsayı anahtarıyla yapılır.

const int kPomodoroMinutes = 25;

/// Profilde günlük hedef yoksa kullanılan hedef (8 pomodoro).
const int kDefaultDailyGoalMinutes = 200;

int effectiveDailyGoalMinutes(int? minutes) =>
    (minutes == null || minutes <= 0) ? kDefaultDailyGoalMinutes : minutes;

/// İstatistiğe giren tek seans: sunucudan gelen ya da çevrimdışı kuyrukta
/// senkron bekleyen ([pending]).
class StatSession {
  const StatSession({
    required this.day,
    required this.minutes,
    required this.categoryName,
    this.categoryId,
    this.colorHex,
    this.pending = false,
  });

  factory StatSession.fromStudySession(StudySession s) => StatSession(
        day: s.studyDay,
        minutes: s.minutes,
        categoryName: s.categoryName,
        categoryId: s.categoryId,
        colorHex: s.colorHex,
      );

  factory StatSession.fromPending(PendingSession p) => StatSession(
        day: studyDayOf(p.startedAt.toLocal()),
        minutes: p.minutes,
        categoryName: p.categoryName,
        categoryId: p.categoryId,
        pending: true,
      );

  /// Çalışma günü (yerel gece yarısı).
  final DateTime day;
  final int minutes;
  final String categoryName;
  final String? categoryId;
  final String? colorHex;
  final bool pending;

  int get pomodoros => minutes ~/ kPomodoroMinutes;
}

// ---- Takvim yardımcıları ----

int dayKeyOf(DateTime day) => day.year * 10000 + day.month * 100 + day.day;

DateTime addDays(DateTime day, int days) => DateTime(day.year, day.month, day.day + days);

/// [day]'in içinde bulunduğu Pazartesi-Pazar haftasının Pazartesi'si.
DateTime mondayOf(DateTime day) => DateTime(day.year, day.month, day.day - (day.weekday - 1));

bool isSameDay(DateTime a, DateTime b) => dayKeyOf(a) == dayKeyOf(b);

DateTime earlierDay(DateTime a, DateTime b) => dayKeyOf(a) <= dayKeyOf(b) ? a : b;

// ---- Toplamlar ----

/// Çalışma günü [from]..[to] (dahil) aralığındaki seanslar.
Iterable<StatSession> sessionsBetween(Iterable<StatSession> sessions, DateTime from, DateTime to) {
  final fromKey = dayKeyOf(from);
  final toKey = dayKeyOf(to);
  return sessions.where((s) {
    final key = dayKeyOf(s.day);
    return key >= fromKey && key <= toKey;
  });
}

int sumMinutes(Iterable<StatSession> sessions) => sessions.fold(0, (sum, s) => sum + s.minutes);

int sumMinutesBetween(Iterable<StatSession> sessions, DateTime from, DateTime to) =>
    sumMinutes(sessionsBetween(sessions, from, to));

class DayStat {
  const DayStat({
    required this.day,
    required this.minutes,
    required this.pomodoros,
    required this.pendingSessions,
  });

  final DateTime day;
  final int minutes;
  final int pomodoros;
  final int pendingSessions;
}

/// [from]..[to] (dahil) aralığındaki HER takvim günü için bir [DayStat].
List<DayStat> dailyTotals(Iterable<StatSession> sessions, DateTime from, DateTime to) {
  final minutes = <int, int>{};
  final pomodoros = <int, int>{};
  final pending = <int, int>{};
  for (final s in sessionsBetween(sessions, from, to)) {
    final key = dayKeyOf(s.day);
    minutes[key] = (minutes[key] ?? 0) + s.minutes;
    pomodoros[key] = (pomodoros[key] ?? 0) + s.pomodoros;
    if (s.pending) pending[key] = (pending[key] ?? 0) + 1;
  }
  final toKey = dayKeyOf(to);
  return [
    for (var d = DateTime(from.year, from.month, from.day); dayKeyOf(d) <= toKey; d = addDays(d, 1))
      DayStat(
        day: d,
        minutes: minutes[dayKeyOf(d)] ?? 0,
        pomodoros: pomodoros[dayKeyOf(d)] ?? 0,
        pendingSessions: pending[dayKeyOf(d)] ?? 0,
      ),
  ];
}

/// En çok çalışılan gün; hiç çalışma yoksa null. Eşitlikte önceki gün.
DayStat? busiestDay(Iterable<DayStat> days) {
  DayStat? best;
  for (final d in days) {
    if (d.minutes > (best?.minutes ?? 0)) best = d;
  }
  return best;
}

class CategoryStat {
  const CategoryStat({
    required this.name,
    required this.minutes,
    required this.sessions,
    required this.pomodoros,
    required this.pendingSessions,
    this.categoryId,
    this.colorHex,
  });

  final String name;
  final String? categoryId;
  final String? colorHex;
  final int minutes;
  final int sessions;
  final int pomodoros;
  final int pendingSessions;
}

/// Kategori toplamları, çoktan aza (eşitlikte ada göre). Gruplama adla
/// yapılır: sunucu birleşimi kategorinin güncel adını verir.
List<CategoryStat> totalsByCategory(Iterable<StatSession> sessions) {
  final byName = <String, List<StatSession>>{};
  for (final s in sessions) {
    byName.putIfAbsent(s.categoryName, () => []).add(s);
  }
  final stats = byName.entries.map((e) {
    final list = e.value;
    return CategoryStat(
      name: e.key,
      categoryId: list.map((s) => s.categoryId).whereType<String>().firstOrNull,
      colorHex: list.map((s) => s.colorHex).whereType<String>().firstOrNull,
      minutes: sumMinutes(list),
      sessions: list.length,
      pomodoros: list.fold(0, (sum, s) => sum + s.pomodoros),
      pendingSessions: list.where((s) => s.pending).length,
    );
  }).toList()
    ..sort((a, b) {
      final byMinutes = b.minutes.compareTo(a.minutes);
      return byMinutes != 0 ? byMinutes : a.name.compareTo(b.name);
    });
  return stats;
}

/// Hedefin yüzde kaçı tamamlandı (0..100, aşağı yuvarlanır: hedefe
/// ulaşılmadan %100 görünmez).
int goalPercent(int minutes, int goalMinutes) {
  if (goalMinutes <= 0) return 0;
  return (minutes * 100 ~/ goalMinutes).clamp(0, 100);
}

/// Yüzde değişim; kıyas değeri yoksa null.
int? percentChangeOf(int current, int previous) {
  if (previous <= 0) return null;
  return ((current - previous) * 100 / previous).round();
}

// ---- Aylık ----

/// Ay içinde görüntülenen Pazartesi-Pazar haftası. [start]/[end] haftanın
/// gerçek sınırları (ay dışına taşabilir); [rangeStart]/[rangeEnd] ay
/// içine kırpılmış, GÖRÜNTÜLENEN aralık.
class MonthWeek {
  const MonthWeek({
    required this.start,
    required this.end,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final DateTime start;
  final DateTime end;
  final DateTime rangeStart;
  final DateTime rangeEnd;
}

DateTime monthStartOf(DateTime day) => DateTime(day.year, day.month, 1);

DateTime monthEndOf(DateTime day) => DateTime(day.year, day.month + 1, 0);

/// [month] ayının [today]'e kadar başlamış haftaları (eskiden yeniye).
List<MonthWeek> weeksOfMonth(DateTime month, DateTime today) {
  final monthStart = monthStartOf(month);
  final monthEnd = monthEndOf(month);
  final monthStartKey = dayKeyOf(monthStart);
  final monthEndKey = dayKeyOf(monthEnd);
  final todayKey = dayKeyOf(today);
  final weeks = <MonthWeek>[];
  for (var monday = mondayOf(monthStart);
      dayKeyOf(monday) <= monthEndKey && dayKeyOf(monday) <= todayKey;
      monday = addDays(monday, 7)) {
    final sunday = addDays(monday, 6);
    weeks.add(MonthWeek(
      start: monday,
      end: sunday,
      rangeStart: dayKeyOf(monday) < monthStartKey ? monthStart : monday,
      rangeEnd: dayKeyOf(sunday) > monthEndKey ? monthEnd : sunday,
    ));
  }
  return weeks;
}

/// Hafta kartının kıyası. Eşit uzunlukta pencereler: bu haftanın ay içindeki
/// ve bugüne kadarki günleri ([from]..[to]) ile 7 gün önceki AYNI günler.
/// Böylece ayın kırpılmış ilk/son haftası ve devam eden hafta tam bir
/// haftayla kıyaslanmaz.
class WeekComparison {
  const WeekComparison({
    required this.from,
    required this.to,
    required this.minutes,
    required this.previousMinutes,
  });

  final DateTime from;
  final DateTime to;
  final int minutes;
  final int previousMinutes;

  int? get percentChange => percentChangeOf(minutes, previousMinutes);
}

WeekComparison compareWithPreviousWeek(Iterable<StatSession> sessions, MonthWeek week, DateTime today) {
  final from = week.rangeStart;
  final to = earlierDay(week.rangeEnd, today);
  return WeekComparison(
    from: from,
    to: to,
    minutes: sumMinutesBetween(sessions, from, to),
    previousMinutes: sumMinutesBetween(sessions, addDays(from, -7), addDays(to, -7)),
  );
}

/// Ayın başından [today]'e kadarki toplam ile önceki ayın aynı dönemi
/// (önceki ay daha kısaysa ay sonuna kırpılır).
({int current, int previous}) monthToDateComparison(Iterable<StatSession> sessions, DateTime today) {
  final previousMonthEnd = DateTime(today.year, today.month, 0);
  var previousTo = DateTime(today.year, today.month - 1, today.day);
  if (dayKeyOf(previousTo) > dayKeyOf(previousMonthEnd)) previousTo = previousMonthEnd;
  return (
    current: sumMinutesBetween(sessions, monthStartOf(today), today),
    previous: sumMinutesBetween(sessions, DateTime(today.year, today.month - 1, 1), previousTo),
  );
}

/// Konu karşılaştırma grafiğinin bir serisi (hafta başına dakika).
/// [isOther] ise gösterilmeyen kategorilerin toplamıdır.
class CategorySeries {
  const CategorySeries({
    required this.name,
    required this.weeklyMinutes,
    this.categoryId,
    this.colorHex,
    this.isOther = false,
  });

  final String name;
  final String? categoryId;
  final String? colorHex;
  final List<int> weeklyMinutes;
  final bool isOther;
}

/// En çok çalışılan kategoriler için haftalık seriler. Kategori sayısı
/// [maxSeries]'i aşarsa ilk (maxSeries - 1) kategori ayrı, kalanlar tek bir
/// "diğer" serisinde toplanır; böylece lejantsız çizgi kalmaz.
List<CategorySeries> weeklyCategorySeries(
  Iterable<StatSession> sessions,
  List<MonthWeek> weeks, {
  int maxSeries = 6,
}) {
  if (weeks.isEmpty || maxSeries <= 0) return const [];
  final inMonth = sessionsBetween(sessions, weeks.first.rangeStart, weeks.last.rangeEnd).toList();
  final totals = totalsByCategory(inMonth);
  final needsOther = totals.length > maxSeries;
  final shown = needsOther ? totals.take(maxSeries - 1).toList() : totals;
  final shownNames = {for (final c in shown) c.name};

  List<int> perWeek(bool Function(StatSession s) test) => [
        for (final w in weeks) sumMinutes(sessionsBetween(inMonth, w.rangeStart, w.rangeEnd).where(test)),
      ];

  return [
    for (final c in shown)
      CategorySeries(
        name: c.name,
        categoryId: c.categoryId,
        colorHex: c.colorHex,
        weeklyMinutes: perWeek((s) => s.categoryName == c.name),
      ),
    if (needsOther)
      CategorySeries(
        name: '',
        isOther: true,
        weeklyMinutes: perWeek((s) => !shownNames.contains(s.categoryName)),
      ),
  ];
}
