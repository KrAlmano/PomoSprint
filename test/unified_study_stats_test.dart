import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoro/models/exam_model.dart';
import 'package:pomodoro/models/study_session.dart';
import 'package:pomodoro/services/session_queue.dart';
import 'package:pomodoro/utils/stats_calculator.dart';
import 'package:pomodoro/utils/study_day.dart';

DateTime _ist(int month, int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, month, day, hour - 3, minute);
ExamAttempt _exam(
  String id,
  DateTime start, {
  int minutes = 165,
  ExamAttemptStatus status = ExamAttemptStatus.completed,
}) => ExamAttempt(
  id: id,
  clientUuid: id,
  examId: 'tyt',
  startedAt: start,
  endsAt: start.add(Duration(minutes: minutes)),
  durationSeconds: minutes * 60,
  totalQuestions: 120,
  status: status,
);
StatSession _study(
  String id,
  DateTime start,
  int minutes, {
  StudySessionKind kind = StudySessionKind.normal,
  String? run,
  DateTime? completedRun,
}) => StatSession(
  day: studyDayOf(start),
  minutes: minutes,
  categoryName: 'Matematik',
  clientUuid: id,
  kind: kind,
  marathonUuid: run,
  marathonCompletedAt: completedRun,
);

void main() {
  setUp(() => setStudyTimeZone('Europe/Istanbul'));
  tearDown(() => setStudyTimeZone('Europe/Istanbul'));
  test(
    'mixed time counts focus sessions, completed runs and exams independently',
    () {
      final day = DateTime(2026, 10, 27),
          start = _ist(10, 27, 10),
          end = _ist(10, 27, 13);
      final study = [
        _study('n1', start, 25),
        _study('n2', start, 50),
        _study(
          'm1',
          start,
          25,
          kind: StudySessionKind.marathon,
          run: 'run1',
          completedRun: end,
        ),
        _study(
          'm2',
          start,
          25,
          kind: StudySessionKind.marathon,
          run: 'run1',
          completedRun: end,
        ),
        _study(
          'p1',
          start,
          50,
          kind: StudySessionKind.marathon,
          run: 'partial',
        ),
      ];
      final exams = [
        _exam('e1', start),
        _exam('e1', start),
        _exam('abandoned', start, status: ExamAttemptStatus.abandoned),
      ];
      final combined = combineStudyAndExamSessions(study: study, exams: exams);
      expect(sumMinutes(combined), 340);
      final c = sessionTypeCounts(combined, day, day);
      expect(c.normalSessions, 2);
      expect(c.marathonFocusSessions, 3);
      expect(c.completedMarathons, 1);
      expect(c.completedExams, 1);
      expect(c.focusEquivalents, 7);
      expect(c.pendingSessions, 0);
      expect(
        totalsByCategory(
          combined,
        ).singleWhere((c) => c.categoryId == kExamStatsCategoryId).minutes,
        165,
      );
    },
  );
  test(
    'normal 50 minutes is one real session but two 25-minute equivalents',
    () {
      final day = DateTime(2026, 10, 27);
      final sessions = [_study('n', _ist(10, 27, 12), 50)];
      final c = sessionTypeCounts(sessions, day, day);
      expect(c.normalSessions, 1);
      expect(c.focusEquivalents, 2);
      expect(c.completedExams, 0);
    },
  );
  test(
    'UUID namespace separates exams from study while duplicate snapshots collapse',
    () {
      final start = _ist(10, 27, 12);
      final study = [_study('same', start, 25), _study('SAME', start, 25)];
      final result = combineStudyAndExamSessions(
        study: study,
        exams: [_exam('same', start), _exam('same', start)],
      );
      expect(result, hasLength(2));
      expect(sumMinutes(result), 190);
    },
  );
  test(
    'offline normal and marathon outbox deduplicate against server and never complete a run early',
    () {
      final start = _ist(10, 27, 12), day = DateTime(2026, 10, 27);
      PendingSession pending(String id, String? run) => PendingSession(
        clientUuid: id,
        categoryId: null,
        categoryName: 'Matematik',
        minutes: 25,
        wasPaused: false,
        foregroundSeconds: 1500,
        startedAt: start,
        queuedAt: start.add(const Duration(minutes: 25)),
        clockOffsetMs: 0,
        marathonUuid: run,
        marathonTargetSessions: run == null ? null : 2,
        marathonSessionIndex: run == null ? null : 2,
      );
      final merged = mergeStatSessions(
        remote: [_study('accepted', start, 25)],
        pending: pendingStatSessions([
          pending('accepted', null),
          pending('queued', 'unfinished'),
        ]),
      );
      final result = combineStudyAndExamSessions(study: merged, exams: []);
      expect(sumMinutes(result), 50);
      final c = sessionTypeCounts(result, day, day);
      expect(c.normalSessions, 1);
      expect(c.marathonFocusSessions, 1);
      expect(c.completedMarathons, 0);
      expect(c.pendingSessions, 1);
    },
  );
  test(
    'legacy server retains time without inventing a normal or marathon classification',
    () {
      final session = StudySession.fromJson({
        'id': 'legacy',
        'user_id': 'owner',
        'category': 'Fizik',
        'duration_minutes': 50,
        'started_at': _ist(10, 27, 12).toIso8601String(),
        'completed_at': _ist(10, 27, 12, 50).toIso8601String(),
      });
      final s = StatSession.fromStudySession(session),
          day = DateTime(2026, 10, 27);
      expect(s.minutes, 50);
      expect(s.pomodoros, 2);
      final c = sessionTypeCounts([s], day, day);
      expect(c.unknownSessions, 1);
      expect(c.normalSessions, 0);
      expect(c.marathonFocusSessions, 0);
    },
  );
  test(
    'exam start before 04:00 stays in previous working month; marathon completion uses end working day',
    () {
      final start = _ist(11, 1, 3, 30), end = _ist(11, 1, 4, 15);
      final result = combineStudyAndExamSessions(
        study: [
          _study(
            'm',
            start,
            50,
            kind: StudySessionKind.marathon,
            run: 'run',
            completedRun: end,
          ),
        ],
        exams: [_exam('exam', start)],
      );
      expect(
        sumMinutesBetween(
          result,
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 31),
        ),
        215,
      );
      expect(
        sumMinutesBetween(
          result,
          DateTime(2026, 11, 1),
          DateTime(2026, 11, 30),
        ),
        0,
      );
      expect(
        sessionTypeCounts(
          result,
          DateTime(2026, 10, 31),
          DateTime(2026, 10, 31),
        ).completedMarathons,
        0,
      );
      final counts = sessionTypeCounts(
        result,
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 1),
      );
      expect(counts.completedMarathons, 1);
      expect(counts.marathonFocusSessions, 0);
    },
  );
  test(
    'New York repeated DST hour and 04:00 use profile timezone rather than device zone',
    () {
      setStudyTimeZone('America/New_York');
      final before = StatSession.fromExamAttempt(
        _exam('a', DateTime.utc(2026, 11, 1, 5, 30)),
      )!;
      final repeated = StatSession.fromExamAttempt(
        _exam('b', DateTime.utc(2026, 11, 1, 6, 30)),
      )!;
      final after = StatSession.fromExamAttempt(
        _exam('c', DateTime.utc(2026, 11, 1, 9)),
      )!;
      expect(before.day, DateTime(2026, 10, 31));
      expect(repeated.day, before.day);
      expect(after.day, DateTime(2026, 11, 1));
      expect(
        sumMinutesBetween(
          [before, repeated, after],
          DateTime(2026, 10, 31),
          DateTime(2026, 10, 31),
        ),
        330,
      );
    },
  );
  test(
    'pending or abandoned exams never enter total time or equivalent pomodoros',
    () {
      final start = _ist(10, 27, 12);
      final result = combineStudyAndExamSessions(
        study: [],
        exams: [
          _exam('active', start, status: ExamAttemptStatus.active),
          _exam('quit', start, status: ExamAttemptStatus.abandoned),
        ],
      );
      expect(result, isEmpty);
      final accepted = StatSession.fromExamAttempt(_exam('done', start))!;
      expect(accepted.minutes, 165);
      expect(accepted.pomodoros, 0);
    },
  );
  test(
    'exam category cannot merge with a user-created category named Deneme',
    () {
      final start = _ist(10, 27, 12);
      final result = combineStudyAndExamSessions(
        study: [
          StatSession(
            day: studyDayOf(start),
            minutes: 25,
            categoryName: 'Deneme',
            clientUuid: 'personal',
          ),
        ],
        exams: [_exam('e', start)],
      );
      final groups = totalsByCategory(result);
      expect(groups, hasLength(2));
      expect(
        groups
            .singleWhere((c) => c.categoryId == kExamStatsCategoryId)
            .pomodoros,
        0,
      );
    },
  );
  test('condensed cards and monthly series retain a separate exam slot', () {
    final day = DateTime(2026, 10, 27);
    final sessions = [
      for (var i = 0; i < 8; i++)
        StatSession(
          day: day,
          minutes: 200 + i,
          categoryName: 'Category $i',
          clientUuid: 's$i',
        ),
      StatSession.fromExamAttempt(_exam('e', _ist(10, 27, 12), minutes: 75))!,
    ];
    final partition = categoryCardPartition(totalsByCategory(sessions));
    expect(
      partition.visible.any((c) => c.categoryId == kExamStatsCategoryId),
      isTrue,
    );
    expect(
      partition.remaining.any((c) => c.categoryId == kExamStatsCategoryId),
      isFalse,
    );
    expect(partition.visible.length + 1, 4);
    final weeks = weeksOfMonth(day, day);
    final series = weeklyCategorySeries(sessions, weeks);
    expect(
      series.any((s) => s.categoryId == kExamStatsCategoryId && !s.isOther),
      isTrue,
    );
    expect(series, hasLength(6));
    expect(
      series.fold<int>(
        0,
        (sum, s) => sum + s.weeklyMinutes.fold<int>(0, (a, b) => a + b),
      ),
      sumMinutes(sessions),
    );
  });
  test(
    'daily sums match weekly and monthly sums without double counting a completed marathon',
    () {
      final sessions = [
        for (var i = 0; i < 7; i++)
          _study(
            'm$i',
            _ist(10, 19 + i, 12),
            25,
            kind: StudySessionKind.marathon,
            run: i < 2 ? 'done' : 'partial',
            completedRun: i < 2 ? _ist(10, 20, 15) : null,
          ),
        StatSession.fromExamAttempt(_exam('e', _ist(10, 20, 18)))!,
      ];
      final days = dailyTotals(
        sessions,
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 25),
      );
      expect(days.fold<int>(0, (n, d) => n + d.minutes), 340);
      expect(
        sumMinutesBetween(
          sessions,
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 31),
        ),
        340,
      );
      expect(
        sessionTypeCounts(
          sessions,
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 31),
        ).completedMarathons,
        1,
      );
    },
  );
}
