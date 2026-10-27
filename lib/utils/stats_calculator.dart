import '../models/category_model.dart';
import '../models/study_session.dart';
import '../models/exam_model.dart';
import '../services/server_clock.dart';
import '../services/session_queue.dart'
    show PendingSession, SessionReason, isUuidCategoryId;
import 'category_names.dart';
import 'study_day.dart';

// İstatistik ekranlarının (Günlük / Haftalık / Aylık) ortak, saf hesapları.
//
// - Seanslar sunucunun gün kuralıyla (profil saat diliminde 04:00 sınırı,
//   bkz. studyDayOf) çalışma gününe atanır.
// - Tüm gün adımları takvim aritmetiğiyle yapılır (DateTime(y, m, d + n));
//   Duration eklenmez, böylece yaz saati geçişlerinde gün kaymaz.
// - Gün karşılaştırmaları 'yyyymmdd' tamsayı anahtarıyla yapılır.
// - Kategori toplamları kategori KİMLİĞİYLE gruplanır (yeniden adlandırma
//   satırı bölmez); kimliği olmayan seanslar adla gruplanır.

const int kPomodoroMinutes = 25;
const String kExamStatsCategoryId = 'pomosprint:exam';

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
    this.iconName,
    this.clientUuid,
    this.pending = false,
    this.kind = StudySessionKind.normal,
    this.recordId,
    this.marathonUuid,
    this.marathonCompletedAt,
  });

  factory StatSession.fromStudySession(StudySession s) => StatSession(
    day: s.studyDay,
    minutes: s.minutes,
    categoryName: s.categoryName,
    categoryId: s.categoryId,
    colorHex: s.colorHex,
    iconName: s.iconName,
    clientUuid: s.clientUuid,
    kind: s.kind,
    recordId: s.id,
    marathonUuid: s.marathonUuid,
    marathonCompletedAt: s.marathonCompletedAt,
  );

  /// Kuyruktaki seans. Günü, kuyruğun sunucuya göndereceği başlangıçla
  /// (cihaz saati + kayıttaki saat farkı; kayıtta yoksa [clockOffset])
  /// hesaplanır; böylece seans senkrondan sonra gün değiştirmez.
  factory StatSession.fromPending(PendingSession p, {Duration? clockOffset}) {
    final offset = p.clockOffsetMs != null
        ? Duration(milliseconds: p.clockOffsetMs!)
        : clockOffset;
    return StatSession(
      day: studyDayOf(p.startedAt.add(ServerClock.correctionFor(offset))),
      minutes: p.minutes,
      categoryName: p.categoryName,
      categoryId: p.categoryId,
      clientUuid: p.clientUuid,
      pending: true,
      kind: p.isMarathon ? StudySessionKind.marathon : StudySessionKind.normal,
      marathonUuid: p.marathonUuid,
    );
  }

  /// Çalışma günü (yerel gece yarısı).
  final DateTime day;
  final int minutes;
  final String categoryName;
  final String? categoryId;
  final String? colorHex;
  final String? iconName;
  final String? clientUuid;
  final bool pending;
  final StudySessionKind kind;
  final String? recordId;
  final String? marathonUuid;
  final DateTime? marathonCompletedAt;

  int get pomodoros =>
      kind == StudySessionKind.exam ? 0 : minutes ~/ kPomodoroMinutes;

  /// Exam time is admitted only from a completed server snapshot.
  static StatSession? fromExamAttempt(ExamAttempt attempt, {String? timeZone}) {
    if (!attempt.isCompleted || attempt.durationSeconds <= 0) return null;
    return StatSession(
      day: studyDayOf(attempt.startedAt, timeZone: timeZone),
      minutes: attempt.durationSeconds ~/ 60,
      categoryName: '',
      categoryId: kExamStatsCategoryId,
      colorHex: '#0055D4',
      iconName: 'assignment',
      clientUuid: attempt.clientUuid,
      recordId: attempt.id,
      kind: StudySessionKind.exam,
    );
  }

  StatSession copyWith({
    String? categoryName,
    String? categoryId,
    String? colorHex,
    String? iconName,
    bool? pending,
  }) => StatSession(
    day: day,
    minutes: minutes,
    categoryName: categoryName ?? this.categoryName,
    categoryId: categoryId ?? this.categoryId,
    colorHex: colorHex ?? this.colorHex,
    iconName: iconName ?? this.iconName,
    clientUuid: clientUuid,
    pending: pending ?? this.pending,
    kind: kind,
    recordId: recordId,
    marathonUuid: marathonUuid,
    marathonCompletedAt: marathonCompletedAt,
  );
}

/// Kuyruktaki seansların istatistiğe girenleri. Sunucunun 'overlap' ile
/// yanıtladığı seans (aynı aralıkta kayıtlı başka seans var; sunucu onu
/// hiçbir zaman kabul etmez) sayılmaz; kuyrukta kalır ve kabuktaki bekleyen
/// seans bandında görünmeye devam eder.
List<StatSession> pendingStatSessions(
  Iterable<PendingSession> queue, {
  Duration? clockOffset,
}) => [
  for (final p in queue)
    if (p.lastError != SessionReason.overlap)
      StatSession.fromPending(p, clockOffset: clockOffset),
];

typedef _CategoryInfo = ({String name, String? colorHex, String? iconName});

/// Sunucu ve kuyruk seanslarını tek listede birleştirir:
/// - client_uuid'si sunucu listesinde olan bekleyen seans atılır (sunucuya
///   yazılmış ama yanıtı kaybolmuş seans iki kez sayılmaz).
/// - Bekleyen seansın kategorisi kimliğiyle (yer tutucu kimlikte, kuyruk gibi
///   dilden bağımsız adla) çözülür: ad, renk ve ikon önce sunucu
///   seanslarından (güncel birleşim; arşivlenmiş kategoriler dahil), yoksa
///   aktif [categories] listesinden alınır.
List<StatSession> mergeStatSessions({
  required List<StatSession> remote,
  required List<StatSession> pending,
  List<CourseCategory> categories = const [],
}) {
  final remoteUuids = {
    for (final s in remote)
      if (s.clientUuid != null) s.clientUuid!.toLowerCase(),
  };
  final known = <String, _CategoryInfo>{
    for (final c in categories)
      if (isUuidCategoryId(c.id))
        c.id: (name: c.name, colorHex: c.colorHex, iconName: c.iconName),
  };
  for (final s in remote) {
    final id = s.categoryId;
    if (id != null && isUuidCategoryId(id)) {
      known[id] = (
        name: s.categoryName,
        colorHex: s.colorHex,
        iconName: s.iconName,
      );
    }
  }

  String? idByName(String name) {
    if (name.trim().isEmpty) return null;
    final key = categoryMatchKey(name);
    // Kuyruğun eşlemesiyle aynı öncelik: önce aktif kategoriler.
    for (final c in categories) {
      if (isUuidCategoryId(c.id) &&
          !c.isArchived &&
          categoryMatchKey(c.name) == key) {
        return c.id;
      }
    }
    for (final e in known.entries) {
      if (categoryMatchKey(e.value.name) == key) return e.key;
    }
    return null;
  }

  StatSession resolve(StatSession p) {
    final id = isUuidCategoryId(p.categoryId)
        ? p.categoryId
        : idByName(p.categoryName);
    final info = id == null ? null : known[id];
    if (id == null || info == null) return p;
    return p.copyWith(
      categoryId: id,
      categoryName: info.name,
      colorHex: info.colorHex,
      iconName: info.iconName,
    );
  }

  return [
    ...remote,
    for (final p in pending)
      if (p.clientUuid == null ||
          !remoteUuids.contains(p.clientUuid!.toLowerCase()))
        resolve(p),
  ];
}

/// Seansın kategori grubu: UUID kimliği varsa kimlik, yoksa ad.
String statGroupKey(StatSession s) {
  if (s.kind == StudySessionKind.exam) return kExamStatsCategoryId;
  final id = s.categoryId;
  return id != null && isUuidCategoryId(id)
      ? 'id:${id.toLowerCase()}'
      : 'name:${s.categoryName}';
}

/// Different products have different UUID namespaces. A repeated accepted
/// server snapshot is not a second session, while an exam UUID cannot erase
/// an unrelated normal session with the same UUID.
List<StatSession> combineStudyAndExamSessions({
  required List<StatSession> study,
  required Iterable<ExamAttempt> exams,
  String? timeZone,
}) {
  final seen = <String>{};
  final combined = <StatSession>[];
  for (final session in [
    ...study,
    ...exams
        .map((e) => StatSession.fromExamAttempt(e, timeZone: timeZone))
        .whereType<StatSession>(),
  ]) {
    final id = session.clientUuid ?? session.recordId;
    final namespace = session.kind == StudySessionKind.exam ? 'exam' : 'study';
    if (id != null && !seen.add('$namespace:${id.toLowerCase()}')) continue;
    combined.add(session);
  }
  return combined;
}

class SessionTypeCounts {
  const SessionTypeCounts({
    this.normalSessions = 0,
    this.marathonFocusSessions = 0,
    this.completedMarathons = 0,
    this.completedExams = 0,
    this.unknownSessions = 0,
    this.focusEquivalents = 0,
    this.pendingSessions = 0,
  });
  final int normalSessions;
  final int marathonFocusSessions;
  final int completedMarathons;
  final int completedExams;
  final int unknownSessions;
  final int focusEquivalents;
  final int pendingSessions;
}

SessionTypeCounts sessionTypeCounts(
  Iterable<StatSession> sessions,
  DateTime from,
  DateTime to, {
  String? timeZone,
}) {
  final ranged = sessionsBetween(sessions, from, to).toList();
  final runs = <String>{};
  for (final session in sessions) {
    final at = session.marathonCompletedAt;
    final uuid = session.marathonUuid;
    if (session.pending || at == null || uuid == null) continue;
    final key = dayKeyOf(studyDayOf(at, timeZone: timeZone));
    if (key >= dayKeyOf(from) && key <= dayKeyOf(to)) runs.add(uuid);
  }
  return SessionTypeCounts(
    normalSessions: ranged
        .where((s) => s.kind == StudySessionKind.normal)
        .length,
    marathonFocusSessions: ranged
        .where((s) => s.kind == StudySessionKind.marathon)
        .length,
    completedMarathons: runs.length,
    completedExams: ranged.where((s) => s.kind == StudySessionKind.exam).length,
    unknownSessions: ranged
        .where((s) => s.kind == StudySessionKind.unknown)
        .length,
    focusEquivalents: ranged.fold(0, (n, s) => n + s.pomodoros),
    pendingSessions: ranged.where((s) => s.pending).length,
  );
}

// ---- Takvim yardımcıları ----

int dayKeyOf(DateTime day) => day.year * 10000 + day.month * 100 + day.day;

DateTime addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// [day]'in içinde bulunduğu Pazartesi-Pazar haftasının Pazartesi'si.
DateTime mondayOf(DateTime day) =>
    DateTime(day.year, day.month, day.day - (day.weekday - 1));

bool isSameDay(DateTime a, DateTime b) => dayKeyOf(a) == dayKeyOf(b);

DateTime earlierDay(DateTime a, DateTime b) =>
    dayKeyOf(a) <= dayKeyOf(b) ? a : b;

// ---- Toplamlar ----

/// Çalışma günü [from]..[to] (dahil) aralığındaki seanslar.
Iterable<StatSession> sessionsBetween(
  Iterable<StatSession> sessions,
  DateTime from,
  DateTime to,
) {
  final fromKey = dayKeyOf(from);
  final toKey = dayKeyOf(to);
  return sessions.where((s) {
    final key = dayKeyOf(s.day);
    return key >= fromKey && key <= toKey;
  });
}

int sumMinutes(Iterable<StatSession> sessions) =>
    sessions.fold(0, (sum, s) => sum + s.minutes);

int sumMinutesBetween(
  Iterable<StatSession> sessions,
  DateTime from,
  DateTime to,
) => sumMinutes(sessionsBetween(sessions, from, to));

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
List<DayStat> dailyTotals(
  Iterable<StatSession> sessions,
  DateTime from,
  DateTime to,
) {
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
    for (
      var d = DateTime(from.year, from.month, from.day);
      dayKeyOf(d) <= toKey;
      d = addDays(d, 1)
    )
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
    this.key = '',
    this.categoryId,
    this.colorHex,
    this.iconName,
  });

  /// Gruplama anahtarı ([statGroupKey]).
  final String key;
  final String name;
  final String? categoryId;
  final String? colorHex;
  final String? iconName;
  final int minutes;
  final int sessions;
  final int pomodoros;
  final int pendingSessions;
}

/// Preserve an explicit exam row when the screen condenses minor subjects.
({List<CategoryStat> visible, List<CategoryStat> remaining})
categoryCardPartition(List<CategoryStat> categories, {int maximum = 4}) {
  if (categories.length <= maximum) {
    return (visible: categories, remaining: const []);
  }
  final exam = categories
      .where((c) => c.categoryId == kExamStatsCategoryId)
      .firstOrNull;
  final regular = categories
      .where((c) => c.categoryId != kExamStatsCategoryId)
      .toList();
  final keep = (maximum - 1 - (exam == null ? 0 : 1)).clamp(0, maximum);
  return (
    visible: [...regular.take(keep), ?exam],
    remaining: regular.skip(keep).toList(),
  );
}

/// Kategori toplamları, çoktan aza (eşitlikte ada göre). Gruplama kategori
/// kimliğiyle yapılır; ad, renk ve ikon önce sunucu seanslarından (güncel
/// birleşim), yoksa bekleyen seanstan alınır.
List<CategoryStat> totalsByCategory(Iterable<StatSession> sessions) {
  final byKey = <String, List<StatSession>>{};
  for (final s in sessions) {
    byKey.putIfAbsent(statGroupKey(s), () => []).add(s);
  }
  T? pick<T extends Object>(
    List<StatSession> list,
    T? Function(StatSession s) field,
  ) =>
      list.where((s) => !s.pending).map(field).whereType<T>().firstOrNull ??
      list.map(field).whereType<T>().firstOrNull;
  final stats =
      byKey.entries.map((e) {
        final list = e.value;
        return CategoryStat(
          key: e.key,
          name: pick<String>(list, (s) => s.categoryName) ?? '',
          categoryId: pick<String>(list, (s) => s.categoryId),
          colorHex: pick<String>(list, (s) => s.colorHex),
          iconName: pick<String>(list, (s) => s.iconName),
          minutes: sumMinutes(list),
          sessions: list.length,
          pomodoros: list.fold(0, (sum, s) => sum + s.pomodoros),
          pendingSessions: list.where((s) => s.pending).length,
        );
      }).toList()..sort((a, b) {
        final byMinutes = b.minutes.compareTo(a.minutes);
        return byMinutes != 0 ? byMinutes : a.name.compareTo(b.name);
      });
  return stats;
}

/// Payları toplamı tam 100 olan tamsayı yüzdelere çevirir (en büyük kalan
/// yöntemi): önce aşağı yuvarlanır, kalan puanlar ondalık kısmı en büyük
/// paylara dağıtılır (eşitlikte öndeki). Toplam 0 ise hepsi 0.
List<int> roundedPercents(List<int> values) {
  final safe = [for (final v in values) v < 0 ? 0 : v];
  final total = safe.fold<int>(0, (a, b) => a + b);
  if (total <= 0) return List.filled(values.length, 0);
  final percents = [for (final v in safe) v * 100 ~/ total];
  final remainders = [for (final v in safe) v * 100 % total];
  var left = 100 - percents.fold<int>(0, (a, b) => a + b);
  final order = List.generate(safe.length, (i) => i)
    ..sort((a, b) {
      final byRemainder = remainders[b].compareTo(remainders[a]);
      return byRemainder != 0 ? byRemainder : a.compareTo(b);
    });
  for (final i in order) {
    if (left <= 0) break;
    percents[i]++;
    left--;
  }
  return percents;
}

/// Hedefin yüzde kaçı tamamlandı (0..100, aşağı yuvarlanır: hedefe
/// ulaşılmadan %100 görünmez). Dolum halkaları için.
int goalPercent(int minutes, int goalMinutes) {
  if (goalMinutes <= 0) return 0;
  return (minutes * 100 ~/ goalMinutes).clamp(0, 100);
}

/// Hedefin yüzde kaçı yapıldı, KIRPILMADAN (aşağı yuvarlanır): 300 / 200
/// dk → 150.
int goalProgressPercent(int minutes, int goalMinutes) {
  if (goalMinutes <= 0 || minutes <= 0) return 0;
  return minutes * 100 ~/ goalMinutes;
}

/// Haftanın bugüne kadar geçen günlerinin hedefine (günlük hedef × geçen
/// gün) göre yüzde (0..100). Haftalık verimlilik etiketi bununla seçilir;
/// böylece Pazartesi hedefini tutturan kullanıcı 'düşük' görünmez.
int elapsedWeekGoalPercent(
  int weekMinutes,
  int dailyGoalMinutes,
  DateTime monday,
  DateTime today,
) {
  final elapsedDays = (studyDaysBetween(monday, today) + 1).clamp(1, 7);
  return goalPercent(weekMinutes, dailyGoalMinutes * elapsedDays);
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
  for (
    var monday = mondayOf(monthStart);
    dayKeyOf(monday) <= monthEndKey && dayKeyOf(monday) <= todayKey;
    monday = addDays(monday, 7)
  ) {
    final sunday = addDays(monday, 6);
    weeks.add(
      MonthWeek(
        start: monday,
        end: sunday,
        rangeStart: dayKeyOf(monday) < monthStartKey ? monthStart : monday,
        rangeEnd: dayKeyOf(sunday) > monthEndKey ? monthEnd : sunday,
      ),
    );
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

WeekComparison compareWithPreviousWeek(
  Iterable<StatSession> sessions,
  MonthWeek week,
  DateTime today,
) {
  final from = week.rangeStart;
  final to = earlierDay(week.rangeEnd, today);
  return WeekComparison(
    from: from,
    to: to,
    minutes: sumMinutesBetween(sessions, from, to),
    previousMinutes: sumMinutesBetween(
      sessions,
      addDays(from, -7),
      addDays(to, -7),
    ),
  );
}

/// Ayın başından [today]'e kadarki toplam ile önceki ayın aynı dönemi
/// (önceki ay daha kısaysa ay sonuna kırpılır).
({int current, int previous}) monthToDateComparison(
  Iterable<StatSession> sessions,
  DateTime today,
) {
  final previousMonthEnd = DateTime(today.year, today.month, 0);
  var previousTo = DateTime(today.year, today.month - 1, today.day);
  if (dayKeyOf(previousTo) > dayKeyOf(previousMonthEnd)) {
    previousTo = previousMonthEnd;
  }
  return (
    current: sumMinutesBetween(sessions, monthStartOf(today), today),
    previous: sumMinutesBetween(
      sessions,
      DateTime(today.year, today.month - 1, 1),
      previousTo,
    ),
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
  final inMonth = sessionsBetween(
    sessions,
    weeks.first.rangeStart,
    weeks.last.rangeEnd,
  ).toList();
  final totals = totalsByCategory(inMonth);
  final needsOther = totals.length > maxSeries;
  final shown = needsOther
      ? categoryCardPartition(totals, maximum: maxSeries).visible
      : totals;
  final shownKeys = {for (final c in shown) c.key};

  List<int> perWeek(bool Function(StatSession s) test) => [
    for (final w in weeks)
      sumMinutes(
        sessionsBetween(inMonth, w.rangeStart, w.rangeEnd).where(test),
      ),
  ];

  return [
    for (final c in shown)
      CategorySeries(
        name: c.name,
        categoryId: c.categoryId,
        colorHex: c.colorHex,
        weeklyMinutes: perWeek((s) => statGroupKey(s) == c.key),
      ),
    if (needsOther)
      CategorySeries(
        name: '',
        isOther: true,
        weeklyMinutes: perWeek((s) => !shownKeys.contains(statGroupKey(s))),
      ),
  ];
}
